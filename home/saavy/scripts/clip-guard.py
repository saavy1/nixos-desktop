"""Flag clipboard history entries that look like secrets, and optionally expire them.

Classifies each new text entry in cliphist with a Jev-compatible decision
service (Laya on the Spark) and records the result in

    $XDG_STATE_HOME/clip-guard.json
    {"version": 1, "expire_after": 0,
     "entries": {"<cliphist id>": {"secret": bool, "p": float, "hash": "...", "first_seen": epoch}},
     "allow": ["<content hash>", ...]}

The clipboard panel masks flagged entries. With --expire-after N (seconds),
flagged entries older than N seconds are deleted from cliphist unless their
content was marked "not a secret". Each entry is classified once.

Usage:
    clip-guard sweep [--endpoint URL] [--threshold P] [--expire-after SECONDS]
    clip-guard allow <cliphist id>      # mark "not a secret"
    clip-guard disallow <cliphist id>
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "clip-guard.json"
QUESTION = {
    "secret": {
        "type": "noul",
        "instructions": "Does this text contain a secret credential such as a password, "
        "API key, access token, private key or session cookie?",
    }
}


def load_state():
    try:
        state = json.loads(STATE.read_text())
        if state.get("version") == 1:
            return state
    except (OSError, json.JSONDecodeError):
        pass
    return {"version": 1, "expire_after": 0, "entries": {}, "allow": []}


def save_state(state):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=1, sort_keys=True))
    temporary.replace(STATE)


def history():
    """(id, raw line) for every cliphist entry, newest first."""
    output = subprocess.run(["cliphist", "list"], capture_output=True, check=True).stdout
    lines = output.decode("utf-8", errors="replace").splitlines()
    return [(line.partition("\t")[0], line) for line in lines if "\t" in line]


def decode(line):
    result = subprocess.run(["cliphist", "decode"], input=line.encode(), capture_output=True)
    return result.stdout.decode("utf-8", errors="replace")


def classify(endpoint, text):
    body = json.dumps({"state": {"text": text[:1500]}, "questions": QUESTION}).encode()
    request = urllib.request.Request(endpoint, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return float(json.load(response)["answers"]["secret"]["noul"])


def sweep(args):
    state = load_state()
    state["expire_after"] = args.expire_after
    entries = history()
    live = {entry_id for entry_id, _ in entries}
    known = {key: value for key, value in state["entries"].items() if key in live}
    allow = set(state.get("allow", []))
    now = int(time.time())

    reachable = True
    for entry_id, line in entries:
        if entry_id in known:
            continue
        preview = line.partition("\t")[2]
        if preview.startswith("[[ binary data"):
            known[entry_id] = {"secret": False, "p": 0.0, "hash": "", "first_seen": now}
            continue
        if not reachable:
            continue
        text = decode(line)
        digest = hashlib.sha256(text.encode()).hexdigest()[:24]
        try:
            probability = classify(args.endpoint, text) if text.strip() else 0.0
        except (urllib.error.URLError, OSError, KeyError, ValueError) as error:
            print(f"decision service unavailable ({error}); will retry", file=sys.stderr)
            reachable = False
            continue
        known[entry_id] = {
            "secret": probability >= args.threshold,
            "p": round(probability, 3),
            "hash": digest,
            "first_seen": now,
        }

    expired = 0
    if args.expire_after > 0:
        for entry_id, line in entries:
            info = known.get(entry_id)
            if not info or not info["secret"] or info["hash"] in allow:
                continue
            if now - info["first_seen"] >= args.expire_after:
                subprocess.run(["cliphist", "delete"], input=line.encode(), check=False)
                known.pop(entry_id)
                expired += 1

    state["entries"] = known
    save_state(state)
    flagged = sum(1 for info in known.values() if info["secret"] and info["hash"] not in allow)
    print(f"{len(known)} entries tracked, {flagged} masked, {expired} expired")


def set_allowed(entry_id, allowed):
    state = load_state()
    info = state["entries"].get(entry_id)
    if not info or not info.get("hash"):
        sys.exit(f"unknown or unclassified entry {entry_id}")
    allow = set(state.get("allow", []))
    (allow.add if allowed else allow.discard)(info["hash"])
    state["allow"] = sorted(allow)
    save_state(state)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    sweep_parser = commands.add_parser("sweep")
    sweep_parser.add_argument("--endpoint", default=os.environ.get(
        "CLIP_GUARD_ENDPOINT", "http://spark.tailc2db57.ts.net:8001/v1/systemone"))
    sweep_parser.add_argument("--threshold", type=float, default=0.9)
    sweep_parser.add_argument("--expire-after", type=int, default=0)
    for name in ("allow", "disallow"):
        commands.add_parser(name).add_argument("id")
    args = parser.parse_args()

    if args.command == "sweep":
        sweep(args)
    else:
        set_allowed(args.id, args.command == "allow")


if __name__ == "__main__":
    main()
