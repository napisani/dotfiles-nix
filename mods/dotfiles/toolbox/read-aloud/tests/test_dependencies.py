from __future__ import annotations

import re
import tomllib
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

# edge-tts 7.2.x sends a Sec-MS-GEC scheme the speech service rejects with 403.
MIN_EDGE_TTS = (7, 3, 0)


def _version(text: str) -> tuple[int, ...]:
    parts = [int(part) for part in text.split(".")]
    return tuple(parts + [0] * (3 - len(parts)))


def test_pyproject_requires_edge_tts_with_current_gec_scheme():
    project = tomllib.loads((PROJECT / "pyproject.toml").read_text())["project"]
    spec = next(d for d in project["dependencies"] if d.startswith("edge-tts"))

    assert _version(re.search(r">=([\d.]+)", spec).group(1)) >= MIN_EDGE_TTS


def test_lockfile_resolves_edge_tts_with_current_gec_scheme():
    lock = tomllib.loads((PROJECT / "uv.lock").read_text())
    locked = next(p for p in lock["package"] if p["name"] == "edge-tts")

    assert _version(locked["version"]) >= MIN_EDGE_TTS
