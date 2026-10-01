"""Name Hyprland workspaces after what's on them, using a local model.

Listens on Hyprland's event socket; when windows open, close, move or change
title it waits for things to settle, describes each workspace's windows and
asks an OpenAI-compatible model for a short name. Names are cached by the
exact window description, so returning to a known state costs nothing, and
each workspace is asked at most once per cooldown. Output for the bar:

    $XDG_STATE_HOME/workspace-names.json
    {"version": 1, "workspaces": {"1": "texturesgg dev", ...}}

Usage: workspace-namer [endpoint]   (default $WORKSPACE_NAMER_ENDPOINT or the Spark)
"""

import hashlib
import json
import os
import re
import select
import socket
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_ENDPOINT = "http://spark.tailc2db57.ts.net:8888/v1"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
OUTPUT = STATE_DIR / "workspace-names.json"
CACHE = STATE_DIR / "workspace-names-cache.json"
MAX_LENGTH = 20
SETTLE = 3.0
COOLDOWN = 30.0
RELEVANT = ("openwindow", "closewindow", "movewindow", "windowtitle", "createworkspace", "destroyworkspace")

PROMPT = f"""You name workspaces in a tiling window manager's status bar.
Given the windows on one workspace, reply with a short name for what the
workspace is being used for: 1-3 lowercase words, at most {MAX_LENGTH} characters.
Prefer the project, repo, site or topic visible in window titles over app
names; a workspace often mixes an editor, terminals, a browser and chat
around one project, so name the project. If the windows are unrelated,
name the activity instead (for example "music + chat"). Never include the
workspace number.

Examples:
- ghostty "~/d/texturesgg", Zed "texturesgg", Helium "textures.gg" -> "texturesgg dev"
- Spotify "Artist - Song" -> "music"
- KiCad PCB Editor "miata-ecu.kicad_pcb", Helium "ECU pinout" -> "miata ecu"
- Discord, Spotify -> "music + chat"
"""


def runtime():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        sys.exit("HYPRLAND_INSTANCE_SIGNATURE is not set")
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "hypr" / signature


def hypr(command):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(str(runtime() / ".socket.sock"))
        sock.sendall(command.encode())
        chunks = []
        while chunk := sock.recv(65536):
            chunks.append(chunk)
    return json.loads(b"".join(chunks))


def describe_workspaces():
    """Workspace id -> sorted window description lines."""
    workspaces = {}
    for client in hypr("j/clients"):
        workspace_id = client.get("workspace", {}).get("id", -1)
        if workspace_id <= 0 or not client.get("mapped", True):
            continue
        title = re.sub(r"\s+", " ", client.get("title", "")).strip()[:80]
        workspaces.setdefault(workspace_id, []).append(f'{client.get("class", "")} "{title}"')
    return {workspace_id: sorted(lines) for workspace_id, lines in workspaces.items()}


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


def request(url, body=None, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if data else {}
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers), timeout=timeout) as response:
        return json.load(response)


def ask(endpoint, model, lines, current):
    message = "Windows:\n" + "\n".join(f"- {line}" for line in lines)
    if current:
        message += f'\n\nCurrent name: "{current}". Keep it unless what the workspace is for has changed.'
    body = {
        "model": model,
        "temperature": 0,
        "max_tokens": 24,
        "chat_template_kwargs": {"enable_thinking": False},
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "workspace_name",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {"name": {"type": "string", "maxLength": MAX_LENGTH}},
                    "required": ["name"],
                    "additionalProperties": False,
                },
            },
        },
        "messages": [
            {"role": "system", "content": PROMPT},
            {"role": "user", "content": message},
        ],
    }
    name = json.loads(request(f"{endpoint}/chat/completions", body)["choices"][0]["message"]["content"])["name"]
    name = re.sub(r"\s+", " ", name).strip().lower()
    return name[:MAX_LENGTH].rstrip() or None


class Namer:
    def __init__(self, endpoint):
        self.endpoint = endpoint
        self.model = None
        cache = load(CACHE, {})
        self.cache = cache if isinstance(cache, dict) else {}
        self.asked_at = {}
        self.names = {}

    def model_id(self):
        if not self.model:
            self.model = request(f"{self.endpoint}/models", timeout=10)["data"][0]["id"]
        return self.model

    def refresh(self):
        """Rename what changed; returns True if a workspace is still waiting on cooldown."""
        pending = False
        names = {}
        for workspace_id, lines in describe_workspaces().items():
            fingerprint = hashlib.sha1("\n".join(lines).encode()).hexdigest()[:16]
            if fingerprint in self.cache:
                names[str(workspace_id)] = self.cache[fingerprint]
                continue
            # Keep the old name until the new state is named.
            if str(workspace_id) in self.names:
                names[str(workspace_id)] = self.names[str(workspace_id)]
            if time.monotonic() - self.asked_at.get(workspace_id, -COOLDOWN) < COOLDOWN:
                pending = True
                continue
            try:
                name = ask(self.endpoint, self.model_id(), lines, self.names.get(str(workspace_id)))
            except (urllib.error.URLError, OSError, KeyError, IndexError, ValueError) as error:
                print(f"workspace {workspace_id}: {error}", file=sys.stderr, flush=True)
                self.model = None
                pending = True
                continue
            self.asked_at[workspace_id] = time.monotonic()
            if name:
                self.cache[fingerprint] = name
                names[str(workspace_id)] = name
                print(f"workspace {workspace_id}: {name}", flush=True)
        if len(self.cache) > 500:
            self.cache = dict(list(self.cache.items())[-500:])
        save(CACHE, self.cache)
        if names != self.names:
            self.names = names
            save(OUTPUT, {"version": 1, "workspaces": names})
        return pending


def main():
    endpoint = (sys.argv[1] if len(sys.argv) > 1 else os.environ.get("WORKSPACE_NAMER_ENDPOINT", DEFAULT_ENDPOINT)).rstrip("/")
    namer = Namer(endpoint)
    events = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    events.connect(str(runtime() / ".socket2.sock"))
    buffer = b""
    due = time.monotonic()  # name everything once at startup
    while True:
        timeout = max(0.0, due - time.monotonic()) if due is not None else None
        ready, _, _ = select.select([events], [], [], timeout)
        if ready:
            data = events.recv(65536)
            if not data:
                sys.exit("Hyprland event socket closed")
            buffer += data
            *lines, buffer = buffer.split(b"\n")
            if any(line.split(b">>", 1)[0].decode(errors="replace").startswith(RELEVANT) for line in lines):
                due = time.monotonic() + SETTLE
            continue
        if due is not None and time.monotonic() >= due:
            due = time.monotonic() + COOLDOWN if namer.refresh() else None


if __name__ == "__main__":
    main()
