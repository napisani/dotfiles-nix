# read-aloud Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a CLI tool `read-aloud` that converts web articles (via URL) or piped text to MP3 using Microsoft Edge TTS.

**Architecture:** Tier 2 toolbox package following the stackman pattern. `ReadAloudApp` dataclass with injectable extractor/tts callables for testability. Thin `cli.py` wrapper. Auto-installed by `uvx.nix`.

**Tech Stack:** Python 3.12, `trafilatura`, `edge-tts`, `click`, `pytest`, `hatchling`

**Design doc:** `docs/plans/2026-04-27-read-aloud-design.md`

---

## Task 1: Scaffold the package

**Files:**
- Create: `mods/dotfiles/toolbox/read-aloud/pyproject.toml`
- Create: `mods/dotfiles/toolbox/read-aloud/Makefile`
- Create: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/__init__.py`
- Create: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/cli.py` (stub)
- Create: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/app.py` (stub)
- Create: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/extractor.py` (stub)
- Create: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/tts.py` (stub)
- Create: `mods/dotfiles/toolbox/read-aloud/tests/__init__.py`

**Step 1: Create `pyproject.toml`**

```toml
[build-system]
requires = ["hatchling>=1.26"]
build-backend = "hatchling.build"

[project]
name = "read-aloud"
version = "0.1.0"
description = "Convert web articles or piped text to speech"
requires-python = "==3.12.*"
dependencies = [
    "click>=8.1,<9",
    "trafilatura>=1.12,<2",
    "edge-tts>=7.0,<8",
]

[project.scripts]
read-aloud = "read_aloud.cli:main"

[tool.hatch.build.targets.wheel]
packages = ["src/read_aloud"]
```

**Step 2: Create `Makefile`**

```makefile
PYTHON ?= 3.12
UV_CACHE_DIR ?= $(CURDIR)/.uv-cache

.PHONY: test install

test:
	UV_CACHE_DIR="$(UV_CACHE_DIR)" uv run --python $(PYTHON) --with pytest pytest tests -q

install:
	UV_CACHE_DIR="$(UV_CACHE_DIR)" uv tool install --editable .
```

**Step 3: Create stub source files**

`src/read_aloud/__init__.py` — empty file.

`src/read_aloud/extractor.py`:
```python
from __future__ import annotations
```

`src/read_aloud/tts.py`:
```python
from __future__ import annotations
```

`src/read_aloud/app.py`:
```python
from __future__ import annotations
```

`src/read_aloud/cli.py`:
```python
from __future__ import annotations
```

`tests/__init__.py` — empty file.

**Step 4: Verify package resolves**

Run from `mods/dotfiles/toolbox/read-aloud/`:
```bash
uv run --python 3.12 python -c "import read_aloud"
```
Expected: no output, exit 0.

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/read-aloud/
git commit -m "feat(read-aloud): scaffold package structure"
```

---

## Task 2: Implement `extractor.py`

**Files:**
- Modify: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/extractor.py`
- Create: `mods/dotfiles/toolbox/read-aloud/tests/test_extractor.py`

**Step 1: Write failing tests**

`tests/test_extractor.py`:
```python
from __future__ import annotations

from unittest.mock import patch


def test_extract_from_url_returns_title_and_body():
    from read_aloud.extractor import extract_from_url

    fake_html = "<html><body><h1>My Title</h1><p>Article body text.</p></body></html>"
    with patch("read_aloud.extractor.trafilatura.fetch_url", return_value=fake_html) as mock_fetch:
        with patch("read_aloud.extractor.trafilatura.extract", return_value="My Title\n\nArticle body text.") as mock_extract:
            result = extract_from_url("https://example.com/article")

    mock_fetch.assert_called_once_with("https://example.com/article")
    mock_extract.assert_called_once_with(fake_html, include_comments=False, no_fallback=False)
    assert result == "My Title\n\nArticle body text."


def test_extract_from_url_raises_on_fetch_failure():
    from read_aloud.extractor import ExtractionError, extract_from_url

    with patch("read_aloud.extractor.trafilatura.fetch_url", return_value=None):
        try:
            extract_from_url("https://example.com/bad")
            assert False, "Should have raised"
        except ExtractionError as e:
            assert "fetch" in str(e).lower()


def test_extract_from_url_raises_on_empty_content():
    from read_aloud.extractor import ExtractionError, extract_from_url

    fake_html = "<html><body></body></html>"
    with patch("read_aloud.extractor.trafilatura.fetch_url", return_value=fake_html):
        with patch("read_aloud.extractor.trafilatura.extract", return_value=None):
            try:
                extract_from_url("https://example.com/empty")
                assert False, "Should have raised"
            except ExtractionError as e:
                assert "content" in str(e).lower()
```

**Step 2: Run tests to verify they fail**

```bash
# from mods/dotfiles/toolbox/read-aloud/
make test
```
Expected: FAIL — `ImportError: cannot import name 'extract_from_url'`

**Step 3: Implement `extractor.py`**

```python
from __future__ import annotations

import trafilatura


class ExtractionError(Exception):
    pass


def extract_from_url(url: str) -> str:
    """Fetch a URL and extract article text (with title prepended).

    Returns the full text as a single string.
    Raises ExtractionError on fetch failure or empty content.
    """
    html = trafilatura.fetch_url(url)
    if html is None:
        raise ExtractionError(f"Failed to fetch URL: {url}")

    text = trafilatura.extract(html, include_comments=False, no_fallback=False)
    if not text:
        raise ExtractionError(f"No content could be extracted from: {url}")

    return text
```

**Step 4: Run tests to verify they pass**

```bash
make test
```
Expected: 3 tests PASS.

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/read-aloud/src/read_aloud/extractor.py \
        mods/dotfiles/toolbox/read-aloud/tests/test_extractor.py
git commit -m "feat(read-aloud): implement URL extraction via trafilatura"
```

---

## Task 3: Implement `tts.py`

**Files:**
- Modify: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/tts.py`
- Create: `mods/dotfiles/toolbox/read-aloud/tests/test_tts.py`

**Step 1: Write failing tests**

`tests/test_tts.py`:
```python
from __future__ import annotations

from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch


def test_text_to_mp3_calls_edge_tts_save(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock()

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello world", output, voice="en-US-GuyNeural")

    mock_cls.assert_called_once_with("Hello world", "en-US-GuyNeural")
    mock_communicate.save.assert_called_once_with(str(output))


def test_text_to_mp3_uses_default_voice(tmp_path: Path):
    from read_aloud.tts import DEFAULT_VOICE, text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock()

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello", output)

    mock_cls.assert_called_once_with("Hello", DEFAULT_VOICE)
```

**Step 2: Run tests to verify they fail**

```bash
make test
```
Expected: FAIL — `ImportError: cannot import name 'text_to_mp3'`

**Step 3: Implement `tts.py`**

```python
from __future__ import annotations

import asyncio
from pathlib import Path

import edge_tts

DEFAULT_VOICE = "en-US-GuyNeural"


def text_to_mp3(text: str, output: Path, *, voice: str = DEFAULT_VOICE) -> None:
    """Convert text to an MP3 file using Microsoft Edge TTS.

    Blocks until the file is written.
    """
    communicate = edge_tts.Communicate(text, voice)
    asyncio.run(communicate.save(str(output)))
```

**Step 4: Run tests to verify they pass**

```bash
make test
```
Expected: all tests PASS.

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/read-aloud/src/read_aloud/tts.py \
        mods/dotfiles/toolbox/read-aloud/tests/test_tts.py
git commit -m "feat(read-aloud): implement TTS via edge-tts"
```

---

## Task 4: Implement `app.py`

**Files:**
- Modify: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/app.py`
- Create: `mods/dotfiles/toolbox/read-aloud/tests/test_app.py`

The app follows stackman's injectable boundary pattern. Extractor and TTS callables are injected so tests don't make real network or TTS calls.

**Step 1: Write failing tests**

`tests/test_app.py`:
```python
from __future__ import annotations

import io
import sys
from pathlib import Path


def _make_app(tmp_path: Path, extractor=None, tts=None):
    from read_aloud.app import ReadAloudApp

    return ReadAloudApp(
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        extractor=extractor,
        tts=tts,
    )


def test_run_url_mode_calls_extractor_and_tts(tmp_path: Path):
    output = tmp_path / "out.mp3"
    extracted_text = "Article Title.\n\nBody text here."
    calls = []

    def fake_extractor(url: str) -> str:
        calls.append(("extract", url))
        return extracted_text

    def fake_tts(text: str, out: Path, *, voice: str) -> None:
        calls.append(("tts", text, out, voice))

    app = _make_app(tmp_path, extractor=fake_extractor, tts=fake_tts)
    code = app.run(url="https://example.com/article", output=output, voice="en-US-GuyNeural", stdin=None)

    assert code == 0
    assert ("extract", "https://example.com/article") in calls
    assert any(c[0] == "tts" and c[1] == extracted_text and c[2] == output for c in calls)


def test_run_stdin_mode_skips_extractor(tmp_path: Path):
    output = tmp_path / "out.mp3"
    calls = []

    def fake_tts(text: str, out: Path, *, voice: str) -> None:
        calls.append(("tts", text))

    app = _make_app(tmp_path, tts=fake_tts)
    stdin = io.StringIO("Hello from stdin")
    code = app.run(url=None, output=output, voice="en-US-GuyNeural", stdin=stdin)

    assert code == 0
    assert ("tts", "Hello from stdin") in calls


def test_run_both_url_and_stdin_is_error(tmp_path: Path):
    output = tmp_path / "out.mp3"
    app = _make_app(tmp_path)
    stdin = io.StringIO("some text")
    code = app.run(url="https://example.com", output=output, voice="en-US-GuyNeural", stdin=stdin)

    assert code == 1
    assert "mutually exclusive" in app.stderr.getvalue().lower()


def test_run_neither_url_nor_stdin_is_error(tmp_path: Path):
    output = tmp_path / "out.mp3"
    app = _make_app(tmp_path)
    code = app.run(url=None, output=output, voice="en-US-GuyNeural", stdin=None)

    assert code == 1
    assert "provide" in app.stderr.getvalue().lower()


def test_run_extraction_error_returns_1(tmp_path: Path):
    from read_aloud.extractor import ExtractionError

    output = tmp_path / "out.mp3"

    def failing_extractor(url: str) -> str:
        raise ExtractionError("No content extracted")

    app = _make_app(tmp_path, extractor=failing_extractor)
    code = app.run(url="https://example.com/bad", output=output, voice="en-US-GuyNeural", stdin=None)

    assert code == 1
    assert "no content extracted" in app.stderr.getvalue().lower()


def test_run_prints_output_path_to_stderr(tmp_path: Path):
    output = tmp_path / "article.mp3"

    def fake_tts(text: str, out: Path, *, voice: str) -> None:
        pass

    app = _make_app(tmp_path, tts=fake_tts)
    stdin = io.StringIO("Some text")
    app.run(url=None, output=output, voice="en-US-GuyNeural", stdin=stdin)

    assert str(output) in app.stderr.getvalue()
```

**Step 2: Run tests to verify they fail**

```bash
make test
```
Expected: FAIL — `ImportError: cannot import name 'ReadAloudApp'`

**Step 3: Implement `app.py`**

```python
from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, TextIO

from .extractor import ExtractionError, extract_from_url
from .tts import DEFAULT_VOICE, text_to_mp3


@dataclass
class ReadAloudApp:
    """Core application logic with injectable dependencies."""

    stdout: TextIO = field(default_factory=lambda: sys.stdout)
    stderr: TextIO = field(default_factory=lambda: sys.stderr)
    extractor: Callable[[str], str] = field(default=extract_from_url)
    tts: Callable[..., None] = field(default=text_to_mp3)

    def run(
        self,
        *,
        url: str | None,
        output: Path,
        voice: str = DEFAULT_VOICE,
        stdin: TextIO | None,
    ) -> int:
        # Validate input mode
        stdin_has_data = stdin is not None and not stdin.isatty() if hasattr(stdin, "isatty") else stdin is not None
        # For StringIO in tests, just check if it's not None
        has_stdin = stdin is not None

        if url and has_stdin:
            self.stderr.write("Error: --url and stdin are mutually exclusive. Provide one or the other.\n")
            return 1

        if not url and not has_stdin:
            self.stderr.write("Error: provide either --url <url> or pipe text via stdin.\n")
            return 1

        # Get text
        if url:
            try:
                text = self.extractor(url)
            except ExtractionError as exc:
                self.stderr.write(f"Error: {exc}\n")
                return 1
        else:
            text = stdin.read()
            if not text.strip():
                self.stderr.write("Error: stdin was empty.\n")
                return 1

        # Convert to speech
        self.tts(text, output, voice=voice)
        self.stderr.write(f"Saved: {output}\n")
        return 0
```

**Step 4: Run tests to verify they pass**

```bash
make test
```
Expected: all tests PASS.

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/read-aloud/src/read_aloud/app.py \
        mods/dotfiles/toolbox/read-aloud/tests/test_app.py
git commit -m "feat(read-aloud): implement ReadAloudApp with injectable boundaries"
```

---

## Task 5: Implement `cli.py`

**Files:**
- Modify: `mods/dotfiles/toolbox/read-aloud/src/read_aloud/cli.py`
- Create: `mods/dotfiles/toolbox/read-aloud/tests/test_cli.py`

**Step 1: Write failing tests**

`tests/test_cli.py`:
```python
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

from click.testing import CliRunner


def test_cli_url_mode_invokes_app(tmp_path: Path):
    from read_aloud.cli import cli

    output = tmp_path / "out.mp3"
    runner = CliRunner()

    with patch("read_aloud.cli.ReadAloudApp") as MockApp:
        instance = MagicMock()
        instance.run.return_value = 0
        MockApp.return_value = instance

        result = runner.invoke(cli, ["--url", "https://example.com", "--output", str(output)])

    assert result.exit_code == 0
    instance.run.assert_called_once()
    call_kwargs = instance.run.call_args.kwargs
    assert call_kwargs["url"] == "https://example.com"
    assert call_kwargs["output"] == output


def test_cli_missing_output_exits_with_error():
    from read_aloud.cli import cli

    runner = CliRunner()
    result = runner.invoke(cli, ["--url", "https://example.com"])
    assert result.exit_code != 0
    assert "--output" in result.output


def test_cli_voice_default_is_guy_neural(tmp_path: Path):
    from read_aloud.cli import cli
    from read_aloud.tts import DEFAULT_VOICE

    output = tmp_path / "out.mp3"
    runner = CliRunner()

    with patch("read_aloud.cli.ReadAloudApp") as MockApp:
        instance = MagicMock()
        instance.run.return_value = 0
        MockApp.return_value = instance

        runner.invoke(cli, ["--url", "https://example.com", "--output", str(output)])

    call_kwargs = instance.run.call_args.kwargs
    assert call_kwargs["voice"] == DEFAULT_VOICE


def test_main_returns_exit_code():
    from read_aloud.cli import main

    with patch("read_aloud.cli.ReadAloudApp") as MockApp:
        instance = MagicMock()
        instance.run.return_value = 0
        MockApp.return_value = instance

        import io
        from click.testing import CliRunner
        runner = CliRunner()
        # just verify main() doesn't raise
        result = runner.invoke_catch_exceptions = False
        code = main(["--url", "https://example.com", "--output", "/tmp/out.mp3"])
        # main can return None for click standalone_mode=False path
```

**Step 2: Run tests to verify they fail**

```bash
make test
```
Expected: FAIL — `ImportError` or attribute errors on `cli`.

**Step 3: Implement `cli.py`**

```python
from __future__ import annotations

import sys
from pathlib import Path

import click

from .app import ReadAloudApp
from .tts import DEFAULT_VOICE


@click.command()
@click.option(
    "--url",
    default=None,
    help="URL of the article to read aloud.",
)
@click.option(
    "--output",
    required=True,
    type=click.Path(path_type=Path),
    help="Destination MP3 file path.",
)
@click.option(
    "--voice",
    default=DEFAULT_VOICE,
    show_default=True,
    help="Edge TTS voice name.",
)
def cli(url: str | None, output: Path, voice: str) -> None:
    """Convert a web article or piped text to speech and save as MP3."""
    stdin = sys.stdin if not sys.stdin.isatty() else None
    app = ReadAloudApp()
    raise SystemExit(app.run(url=url, output=output, voice=voice, stdin=stdin))


def main(argv: list[str] | None = None) -> int:
    try:
        cli.main(args=argv, prog_name="read-aloud", standalone_mode=False)
    except SystemExit as exc:
        code = exc.code
        if isinstance(code, int):
            return code
        if code:
            click.echo(str(code), err=True)
        return 1
    return 0
```

**Step 4: Run tests to verify they pass**

```bash
make test
```
Expected: all tests PASS.

**Step 5: Commit**

```bash
git add mods/dotfiles/toolbox/read-aloud/src/read_aloud/cli.py \
        mods/dotfiles/toolbox/read-aloud/tests/test_cli.py
git commit -m "feat(read-aloud): implement CLI entry point"
```

---

## Task 6: Install and smoke test

**Step 1: Install the package**

```bash
# from mods/dotfiles/toolbox/read-aloud/
make install
```
Expected: `read-aloud` binary appears in `~/.local/bin/`.

**Step 2: Verify the binary exists**

```bash
which read-aloud
read-aloud --help
```
Expected: prints usage with `--url`, `--output`, `--voice` options.

**Step 3: Quick smoke test with stdin**

```bash
echo "This is a test of the read aloud tool." | read-aloud --output /tmp/test-read-aloud.mp3
```
Expected: `Saved: /tmp/test-read-aloud.mp3` on stderr, file exists.

**Step 4: Verify the MP3 file**

```bash
ls -lh /tmp/test-read-aloud.mp3
file /tmp/test-read-aloud.mp3
```
Expected: file exists, is a few KB, `file` reports it as MPEG audio.

**Step 5: Final commit**

```bash
git add mods/dotfiles/toolbox/read-aloud/
git commit -m "feat(read-aloud): complete implementation"
```

---

## Notes

- `uvx.nix` auto-discovers any `toolbox/*/pyproject.toml` — no Nix changes needed after initial scaffold commit
- The `~/toolbox` symlink already points to `mods/dotfiles/toolbox/` — no shell config changes needed
- `edge-tts` makes real network calls to Microsoft's TTS endpoint; tests mock it entirely
- `trafilatura` behaviour varies by site; the tool is best-effort for content extraction
