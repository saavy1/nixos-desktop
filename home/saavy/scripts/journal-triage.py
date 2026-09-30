"""Triage systemd journal warnings with a local model; keep only what matters.

Follows `journalctl -p warning` (after a 24h backfill), collapses lines into
message templates (numbers, hex, ids and Nix store hashes normalised), and
asks an OpenAI-compatible model to rate each new template as noise, minor,
problem or critical. A template is asked again when its 24h count grows by an
order of magnitude, since repetition changes the verdict. Output for the
Lab panel (non-noise templates only):

    $XDG_STATE_HOME/journal-triage.json
    {"version": 1, "items": [{"key", "unit", "verdict", "summary", "count", "last_seen", "dismissed"}]}

Usage:
    journal-triage [--endpoint URL]      # run the service
    journal-triage dismiss <key>         # hide an item (until it gets worse)
    journal-triage undismiss <key>
"""

import argparse
import hashlib
import json
import os
import re
import select
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
OUTPUT = STATE_DIR / "journal-triage.json"
CACHE = STATE_DIR / "journal-triage-cache.json"
DISMISSED = STATE_DIR / "journal-triage-dismissed.json"
WINDOW = 24 * 3600
PRIORITIES = ["emerg", "alert", "crit", "err", "warning"]
VERDICTS = ["noise", "minor", "problem", "critical"]
SYSTEM = (
    "You triage systemd journal warnings on a personal NixOS desktop. For one deduplicated "
    "message template, decide whether the owner should look at it. noise = harmless or expected "
    "(e.g. dbus duplicate service names from NixOS profiles, portal/app ID chatter, Steam "
    "container warnings); minor = worth knowing, not urgent; problem = something is broken and "
    "should be fixed; critical = data loss, hardware failure or a core service down. Repetition "
    "matters: a unit failing thousands of times is a problem. summary = one short plain-English "
    "sentence under 70 characters saying what is wrong, without repeating the unit name."
)


def load(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return default


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=1, sort_keys=True))
    temporary.replace(path)


def normalise(message):
    message = re.sub(r"/nix/store/[a-z0-9]{32}-", "/nix/store/…-", message)
    message = re.sub(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", "<uuid>", message)
    message = re.sub(r"0x[0-9a-fA-F]+", "<hex>", message)
    message = re.sub(r"\b[0-9a-f]{12,}\b", "<id>", message)
    return re.sub(r"\d+", "#", message)[:300]


def unit_of(entry, message):
    unit = entry.get("_SYSTEMD_USER_UNIT") or entry.get("_SYSTEMD_UNIT") or entry.get("SYSLOG_IDENTIFIER") or "?"
    # systemd itself (PID 1 or the user manager) logs about other units as
    # "foo.service: Failed …"; attribute those to the unit they're about.
    if unit in ("init.scope", "?") or unit.startswith("user@"):
        subject = re.match(r"^([\w@.\\-]+\.(?:service|socket|timer|mount|scope|slice|target)): ", message)
        if subject:
            unit = subject.group(1)
    return re.sub(r"@[\d-]+(_\d+)*\.service", "@….service", unit)


def bucket(count):
    """Order of magnitude: 1, 10, 100, 1000, …"""
    return 10 ** (len(str(max(1, count))) - 1)


def request(url, body=None, timeout=60):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if data else {}
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers), timeout=timeout) as response:
        return json.load(response)


class Triage:
    def __init__(self, endpoint):
        self.endpoint = endpoint
        self.model = None
        self.templates = {}  # key -> {unit, sample, priority, hits: [epoch...]}
        cache = load(CACHE, {})
        self.verdicts = cache if isinstance(cache, dict) else {}  # key -> {verdict, summary, bucket}
        self.dirty = False
        self.last_written = None

    def add(self, entry):
        message = entry.get("MESSAGE")
        if not isinstance(message, str) or not message.strip():
            return
        unit = unit_of(entry, message)
        key = hashlib.sha1(f"{unit}\n{normalise(message)}".encode()).hexdigest()[:12]
        stamp = int(entry.get("__REALTIME_TIMESTAMP", time.time() * 1e6)) // 1_000_000
        template = self.templates.setdefault(key, {"unit": unit, "sample": message[:300], "priority": 4, "hits": []})
        template["priority"] = min(template["priority"], int(entry.get("PRIORITY", 4)))
        template["hits"].append(stamp)
        self.dirty = True

    def prune(self):
        cutoff = time.time() - WINDOW
        for key in list(self.templates):
            hits = [stamp for stamp in self.templates[key]["hits"] if stamp >= cutoff]
            if hits:
                self.templates[key]["hits"] = hits
            else:
                del self.templates[key]

    def ask(self, template, count):
        if not self.model:
            self.model = request(f"{self.endpoint}/models", timeout=10)["data"][0]["id"]
        user = (f"unit: {template['unit']}\npriority: {PRIORITIES[min(template['priority'], 4)]}\n"
                f"occurrences in 24h: {count}\nmessage: {template['sample']}")
        body = {
            "model": self.model,
            "temperature": 0,
            "max_tokens": 80,
            "chat_template_kwargs": {"enable_thinking": False},
            "response_format": {"type": "json_schema", "json_schema": {"name": "triage", "strict": True, "schema": {
                "type": "object",
                "properties": {
                    "verdict": {"type": "string", "enum": VERDICTS},
                    "summary": {"type": "string", "maxLength": 120},
                },
                "required": ["verdict", "summary"],
                "additionalProperties": False,
            }}},
            "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": user}],
        }
        reply = request(f"{self.endpoint}/chat/completions", body)
        return json.loads(reply["choices"][0]["message"]["content"])

    def classify(self):
        """Rate new templates and ones whose count jumped a magnitude. Returns False if the model is unreachable."""
        for key, template in sorted(self.templates.items(), key=lambda item: -len(item[1]["hits"])):
            count = len(template["hits"])
            known = self.verdicts.get(key)
            if known and known.get("bucket", 1) >= bucket(count):
                continue
            try:
                answer = self.ask(template, count)
            except (urllib.error.URLError, OSError, KeyError, IndexError, ValueError) as error:
                print(f"model unavailable ({error}); will retry", file=sys.stderr, flush=True)
                self.model = None
                return False
            if answer.get("verdict") in VERDICTS:
                self.verdicts[key] = {"verdict": answer["verdict"], "summary": answer.get("summary", ""), "bucket": bucket(count)}
                self.dirty = True
                if answer["verdict"] != "noise":
                    print(f"{answer['verdict']}: {template['unit']}: {answer.get('summary', '')}", flush=True)
        save(CACHE, self.verdicts)
        return True

    def write(self):
        dismissed = load(DISMISSED, {})
        items = []
        for key, template in self.templates.items():
            verdict = self.verdicts.get(key)
            if not verdict or verdict["verdict"] == "noise":
                continue
            items.append({
                "key": key,
                "unit": template["unit"],
                "verdict": verdict["verdict"],
                "summary": verdict["summary"],
                "sample": template["sample"],
                "count": len(template["hits"]),
                "last_seen": max(template["hits"]),
                # A dismissal holds until the item gets worse (a higher count magnitude).
                "dismissed": dismissed.get(key, 0) >= verdict.get("bucket", 1),
            })
        items.sort(key=lambda item: (-VERDICTS.index(item["verdict"]), -item["last_seen"]))
        if items != self.last_written:
            save(OUTPUT, {"version": 1, "items": items})
            self.last_written = items
        self.dirty = False


def run(endpoint):
    triage = Triage(endpoint)
    backfill = subprocess.run(["journalctl", "-p", "warning", "--since", "-24h", "-q", "--no-pager", "-o", "json"],
                              capture_output=True).stdout
    for line in backfill.decode(errors="replace").splitlines():
        try:
            triage.add(json.loads(line))
        except json.JSONDecodeError:
            continue
    follow = subprocess.Popen(["journalctl", "-p", "warning", "-f", "-n", "0", "-q", "-o", "json"],
                              stdout=subprocess.PIPE)
    reachable = triage.classify()
    triage.write()
    next_check = time.monotonic() + (60 if not reachable else 5)
    while True:
        ready, _, _ = select.select([follow.stdout], [], [], max(0.0, next_check - time.monotonic()))
        if ready:
            line = follow.stdout.readline()
            if not line:
                sys.exit("journalctl exited")
            try:
                triage.add(json.loads(line))
            except json.JSONDecodeError:
                pass
            continue
        # Batch work every few seconds rather than per line.
        triage.prune()
        reachable = triage.classify() if triage.dirty or not reachable else True
        triage.write()
        next_check = time.monotonic() + (60 if not reachable else 5)


def set_dismissed(key, dismissed):
    cache = load(CACHE, {})
    marks = load(DISMISSED, {})
    if dismissed:
        marks[key] = cache.get(key, {}).get("bucket", 1)
    else:
        marks.pop(key, None)
    save(DISMISSED, marks)
    # Reflect it immediately; the service rewrites the file on its next pass.
    output = load(OUTPUT, {"version": 1, "items": []})
    for item in output.get("items", []):
        if item["key"] == key:
            item["dismissed"] = dismissed
    save(OUTPUT, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--endpoint", default=os.environ.get("JOURNAL_TRIAGE_ENDPOINT", "http://spark.tailc2db57.ts.net:8888/v1"))
    commands = parser.add_subparsers(dest="command")
    for name in ("dismiss", "undismiss"):
        commands.add_parser(name).add_argument("key")
    args = parser.parse_args()
    if args.command in ("dismiss", "undismiss"):
        set_dismissed(args.key, args.command == "dismiss")
    else:
        run(args.endpoint.rstrip("/"))


if __name__ == "__main__":
    main()
