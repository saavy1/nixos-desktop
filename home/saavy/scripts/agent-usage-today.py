"""Summarise today's agent token usage from local session logs as JSON.

Reads Claude Code (~/.claude/projects), omp (~/.omp/agent/sessions) and Codex
(~/.codex/sessions) JSONL files touched today and prints per-tool and
per-model totals for the local calendar day.
"""

import json
import sys
from datetime import date, datetime, timezone
from pathlib import Path

HOME = Path.home()
TODAY = date.today()
MIDNIGHT = datetime.combine(TODAY, datetime.min.time()).timestamp()


def is_today(stamp):
    if not stamp:
        return False
    try:
        if isinstance(stamp, (int, float)):
            moment = datetime.fromtimestamp(stamp / 1000 if stamp > 1e11 else stamp)
        else:
            moment = datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone()
        return moment.date() == TODAY
    except (ValueError, OSError, OverflowError):
        return False


def recent_files(root):
    if not root.is_dir():
        return []
    return [path for path in root.rglob("*.jsonl") if path.stat().st_mtime >= MIDNIGHT]


def records(path):
    try:
        with path.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue
    except OSError:
        return


class Tally:
    def __init__(self, name):
        self.name = name
        self.input = self.output = self.cache_read = self.cache_write = 0
        self.cost = None
        self.requests = 0
        self.sessions = set()
        self.models = {}

    def add(self, session, model, input_tokens, output_tokens, cache_read, cache_write, cost=None):
        self.input += input_tokens
        self.output += output_tokens
        self.cache_read += cache_read
        self.cache_write += cache_write
        self.requests += 1
        self.sessions.add(session)
        if cost is not None:
            self.cost = (self.cost or 0) + cost
        # "Fresh" excludes cache reads, which dominate agent traffic.
        fresh = input_tokens + output_tokens + cache_write
        entry = self.models.setdefault(model or "unknown", {"fresh": 0, "total": 0})
        entry["fresh"] += fresh
        entry["total"] += fresh + cache_read

    def summary(self):
        return {
            "name": self.name,
            "input": self.input,
            "output": self.output,
            "cacheRead": self.cache_read,
            "cacheWrite": self.cache_write,
            "fresh": self.input + self.output + self.cache_write,
            "total": self.input + self.output + self.cache_read + self.cache_write,
            "cost": self.cost,
            "requests": self.requests,
            "sessions": len(self.sessions),
        }


def claude_code():
    tally = Tally("Claude Code")
    for path in recent_files(HOME / ".claude" / "projects"):
        seen = set()
        for entry in records(path):
            message = entry.get("message") or {}
            usage = message.get("usage")
            if entry.get("type") != "assistant" or not usage or not is_today(entry.get("timestamp")):
                continue
            # Streaming writes one line per content block with the same message id.
            key = message.get("id") or entry.get("requestId") or entry.get("uuid")
            if key in seen:
                continue
            seen.add(key)
            tally.add(
                path.stem,
                message.get("model"),
                usage.get("input_tokens", 0),
                usage.get("output_tokens", 0),
                usage.get("cache_read_input_tokens", 0),
                usage.get("cache_creation_input_tokens", 0),
            )
    return tally


def omp():
    tally = Tally("omp")
    for path in recent_files(HOME / ".omp" / "agent" / "sessions"):
        for entry in records(path):
            message = entry.get("message") or {}
            usage = message.get("usage")
            if message.get("role") != "assistant" or not usage or not is_today(entry.get("timestamp")):
                continue
            cost = (usage.get("cost") or {}).get("total")
            model = message.get("model")
            if message.get("provider"):
                model = f"{message['provider']}/{model}"
            tally.add(
                path.stem,
                model,
                usage.get("input", 0),
                usage.get("output", 0),
                usage.get("cacheRead", 0),
                usage.get("cacheWrite", 0),
                cost if isinstance(cost, (int, float)) else None,
            )
    return tally


def codex():
    tally = Tally("Codex")
    for path in recent_files(HOME / ".codex" / "sessions"):
        model = None
        for entry in records(path):
            payload = entry.get("payload") or {}
            if payload.get("type") == "turn_context" or entry.get("type") == "turn_context":
                model = payload.get("model") or model
            if payload.get("type") != "token_count" or not is_today(entry.get("timestamp")):
                continue
            last = (payload.get("info") or {}).get("last_token_usage") or {}
            if not last:
                continue
            cached = last.get("cached_input_tokens", 0)
            tally.add(
                path.stem,
                model,
                max(0, last.get("input_tokens", 0) - cached),
                last.get("output_tokens", 0),
                cached,
                0,
            )
    return tally


def main():
    tallies = [claude_code(), omp(), codex()]
    models = []
    for tally in tallies:
        for model, counts in tally.models.items():
            models.append({"tool": tally.name, "model": model, **counts})
    models.sort(key=lambda item: item["fresh"], reverse=True)
    json.dump(
        {
            "date": TODAY.isoformat(),
            "generatedAt": int(datetime.now(timezone.utc).timestamp() * 1000),
            "tools": [tally.summary() for tally in tallies],
            "models": models[:8],
        },
        sys.stdout,
    )


if __name__ == "__main__":
    main()
