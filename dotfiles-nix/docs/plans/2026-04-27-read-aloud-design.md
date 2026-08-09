# read-aloud: Design

**Date:** 2026-04-27  
**Status:** Approved

## Overview

A CLI tool that converts web articles or piped text to speech using Microsoft Edge TTS voices. Takes a URL or stdin text, produces an MP3 file at a user-specified path.

**Stack:** Python 3.12, `trafilatura` (article extraction), `edge-tts` (TTS), `click` (CLI)

---

## Package Structure

Tier 2 toolbox package following the stackman pattern. Auto-discovered and installed by `uvx.nix` via `uv tool install --editable`.

```
toolbox/read-aloud/
  pyproject.toml
  Makefile
  src/read_aloud/
    __init__.py
    cli.py        # click entry point
    app.py        # ReadAloudApp dataclass (injectable)
    extractor.py  # trafilatura: URL -> (title, text)
    tts.py        # edge-tts: text -> MP3 file (async)
  tests/
    test_app.py
    test_extractor.py
    test_tts.py
```

Entry point: `read-aloud = "read_aloud.cli:main"`

---

## CLI Interface

Single command (no subcommand group):

```
read-aloud --output <file.mp3> [--url <url>] [--voice <name>]
```

### Examples

```bash
# URL mode
read-aloud --url https://example.com/article --output article.mp3

# Pipe mode
echo "Hello world" | read-aloud --output hello.mp3

# Override voice
read-aloud --url https://... --output out.mp3 --voice en-US-JennyNeural
```

### Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--output` | yes | — | Destination MP3 file path |
| `--url` | no | — | URL to fetch and extract article from |
| `--voice` | no | `en-US-GuyNeural` | Edge TTS voice name |

- `--url` and stdin are mutually exclusive; providing both is an error
- If neither `--url` nor stdin data is provided, exit with a clear usage error
- Status/progress messages go to stderr; nothing to stdout

---

## Core Logic Flow

### URL Mode
1. `extractor.py`: `trafilatura.fetch_url(url)` → raw HTML
2. `trafilatura.extract(html, include_title=True)` → text with title prepended as `"{title}.\n\n{body}"`
3. `tts.py`: `asyncio.run(edge_tts.Communicate(text, voice).save(output_path))`
4. Print save confirmation to stderr

### Pipe Mode
1. Read all of stdin
2. Pass text directly to `tts.py`
3. Print save confirmation to stderr

### Error Cases

| Condition | Behavior |
|-----------|----------|
| URL fetch fails (network, 404) | Print error to stderr, exit 1 |
| trafilatura returns no content | Print error to stderr, exit 1 |
| `--url` and stdin both present | Print mutual exclusion error, exit 1 |
| Neither `--url` nor stdin | Print usage hint, exit 1 |

---

## Testing Strategy

- **`test_extractor.py`**: mock `trafilatura.fetch_url` and `trafilatura.extract` — no real HTTP
- **`test_tts.py`**: mock `edge_tts.Communicate` — verify `save()` called with correct args, no real TTS calls
- **`test_app.py`**: integration-style tests using `ReadAloudApp` with faked extractor/tts callables injected — tests end-to-end wiring

---

## Integration with Repo

- Lives at `mods/dotfiles/toolbox/read-aloud/`
- `~/toolbox` symlink (managed by `shell.nix`) exposes it at `~/toolbox/read-aloud/`
- `uvx.nix` auto-discovers it via `pyproject.toml` and runs `uv tool install --editable`
- Binary lands in `~/.local/bin/read-aloud` (already on PATH)
- No Nix rebuild needed after initial setup
