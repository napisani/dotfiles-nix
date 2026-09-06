#!/usr/bin/env python3
"""Read-only pre-switch audit. Report names, never configuration/credential values."""
import argparse
import json
from pathlib import Path
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("declarations", type=Path, help="JSON exported from the host's config.agents")
parser.add_argument("--home", required=True, type=Path, help="home belonging to that host")
args = parser.parse_args()
declared = json.loads(args.declarations.read_text())
reports = []
code = 0
for agent, relative, key in [
    ("claude", ".claude.json", "mcpServers"),
    ("codex", ".codex/config.toml", "mcp_servers"),
    ("pi", ".pi/agent/mcp.json", "mcpServers"),
]:
    spec = declared.get(agent, {})
    if not declared.get("enable", True) or not spec.get("enable", True):
        continue
    file = args.home / relative
    report = {"agent": agent, "file": str(file)}
    try:
        expected = spec.get("mcpServers", {})
        if not file.exists():
            report["status"] = "missing"
        else:
            text = file.read_text()
            doc = tomllib.loads(text) if file.suffix == ".toml" else json.loads(text)
            live = doc.get(key, {})
            if not isinstance(live, dict) or not isinstance(expected, dict):
                raise ValueError("invalid managed key")
            report["undeclared"] = sorted(live.keys() - expected.keys())
            report["changed"] = sorted(name for name in live.keys() & expected.keys() if live[name] != expected[name])
            report["status"] = "review" if report["undeclared"] or report["changed"] else "matches"
            if report["status"] == "review":
                code = max(code, 1)
    except (OSError, ValueError, AttributeError):
        report["status"] = "unreadable"
        code = 2
    reports.append(report)
print(json.dumps(reports, indent=2))
raise SystemExit(code)
