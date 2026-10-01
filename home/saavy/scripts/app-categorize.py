"""Sort installed desktop applications into launcher categories, offline.

Reads every .desktop application, and for any app whose details changed (or
that isn't in the cache yet) asks an OpenAI-compatible model to pick one of
the configured categories, constrained by a JSON-schema enum so the answer is
always a valid category. Results go to a small JSON map the launcher reads:

    $XDG_STATE_HOME/app-categories.json
    {"version": 1, "apps": {"<desktop id>": {"category": "...", "fingerprint": "..."}}}

Usage: app-categorize <categories.json> [endpoint]
The endpoint defaults to $APP_CATEGORIZE_ENDPOINT, then the Spark's /v1.
If the model server is unreachable the cache is left as it is.
"""

import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_ENDPOINT = "http://spark.tailc2db57.ts.net:8888/v1"
HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "app-categories.json"


def data_dirs():
    dirs = [Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))]
    dirs += [Path(entry) for entry in os.environ.get("XDG_DATA_DIRS", "").split(":") if entry]
    dirs += [
        HOME / ".nix-profile/share",
        Path(f"/etc/profiles/per-user/{os.environ.get('USER', 'saavy')}/share"),
        Path("/run/current-system/sw/share"),
        Path("/var/lib/flatpak/exports/share"),
        HOME / ".local/share/flatpak/exports/share",
    ]
    seen = []
    for directory in dirs:
        if directory not in seen:
            seen.append(directory)
    return seen


def parse_desktop(path):
    entry = {}
    in_main = False
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None
    for line in lines:
        line = line.strip()
        if line.startswith("["):
            in_main = line == "[Desktop Entry]"
            continue
        if in_main and "=" in line and not line.startswith("#"):
            key, _, value = line.partition("=")
            if "[" not in key:
                entry.setdefault(key.strip(), value.strip())
    return entry


def applications():
    """Desktop id -> entry, first match wins like XDG lookup."""
    apps = {}
    for directory in data_dirs():
        root = directory / "applications"
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.desktop")):
            app_id = str(path.relative_to(root))[: -len(".desktop")].replace("/", "-")
            if app_id in apps:
                continue
            entry = parse_desktop(path)
            if not entry or entry.get("Type") != "Application" or entry.get("Hidden") == "true":
                continue
            apps[app_id] = entry
    return apps


def describe(entry):
    executable = (entry.get("Exec", "").split() or [""])[0].split("/")[-1]
    parts = [
        f"Name: {entry.get('Name', '')}",
        f"Generic name: {entry.get('GenericName', '')}",
        f"Description: {entry.get('Comment', '')}",
        f"Desktop categories: {entry.get('Categories', '').strip(';').replace(';', ', ')}",
        f"Keywords: {entry.get('Keywords', '').strip(';').replace(';', ', ')}",
        f"Executable: {executable}",
    ]
    return "\n".join(part for part in parts if not part.endswith(": "))


def request(url, body=None, timeout=60):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if data else {}
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers), timeout=timeout) as response:
        return json.load(response)


def classify(endpoint, model, categories, description):
    names = [category["name"] for category in categories]
    guide = "\n".join(f"- {category['name']}: {category['description']}" for category in categories)
    body = {
        "model": model,
        "temperature": 0,
        "max_tokens": 32,
        "chat_template_kwargs": {"enable_thinking": False},
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "app_category",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {"category": {"type": "string", "enum": names}},
                    "required": ["category"],
                    "additionalProperties": False,
                },
            },
        },
        "messages": [
            {
                "role": "system",
                "content": "You sort desktop applications into app launcher categories. "
                "Pick the single best category from this list:\n" + guide,
            },
            {"role": "user", "content": description},
        ],
    }
    reply = request(f"{endpoint}/chat/completions", body)
    content = reply["choices"][0]["message"]["content"]
    category = json.loads(content).get("category")
    return category if category in names else None


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    config = json.loads(Path(sys.argv[1]).read_text())
    categories = config["categories"]
    endpoint = (sys.argv[2] if len(sys.argv) > 2 else os.environ.get("APP_CATEGORIZE_ENDPOINT", DEFAULT_ENDPOINT)).rstrip("/")

    try:
        cache = json.loads(STATE.read_text())
    except (OSError, json.JSONDecodeError):
        cache = {}
    known = cache.get("apps", {}) if cache.get("version") == 1 else {}

    # Changing the category list invalidates every answer.
    salt = hashlib.sha1(json.dumps(categories, sort_keys=True).encode()).hexdigest()[:12]
    apps = applications()
    todo = {}
    for app_id, entry in apps.items():
        description = describe(entry)
        fingerprint = hashlib.sha1(f"{salt}\n{description}".encode()).hexdigest()[:16]
        if known.get(app_id, {}).get("fingerprint") != fingerprint:
            todo[app_id] = (description, fingerprint)

    result = {app_id: known[app_id] for app_id in apps if app_id in known and app_id not in todo}
    if todo:
        try:
            model = request(f"{endpoint}/models", timeout=10)["data"][0]["id"]
        except (urllib.error.URLError, OSError, KeyError, IndexError, ValueError) as error:
            print(f"model server unavailable ({error}); leaving the cache as it is", file=sys.stderr)
            return
        for app_id, (description, fingerprint) in sorted(todo.items()):
            try:
                category = classify(endpoint, model, categories, description)
            except (urllib.error.URLError, OSError, KeyError, IndexError, ValueError) as error:
                print(f"{app_id}: {error}", file=sys.stderr)
                continue
            if category:
                result[app_id] = {"category": category, "fingerprint": fingerprint}
                print(f"{app_id}: {category}")

    STATE.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps({"version": 1, "apps": result}, indent=1, sort_keys=True))
    temporary.replace(STATE)
    print(f"{len(result)} apps categorised, {len(todo)} asked")


if __name__ == "__main__":
    main()
