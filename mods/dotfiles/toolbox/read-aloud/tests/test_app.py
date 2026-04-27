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

    def fake_tts(text: str, out: Path, *, voice: str, speed: float) -> None:
        calls.append(("tts", text, out, voice))

    app = _make_app(tmp_path, extractor=fake_extractor, tts=fake_tts)
    code = app.run(url="https://example.com/article", output=output, voice="en-US-GuyNeural", stdin=None)

    assert code == 0
    assert ("extract", "https://example.com/article") in calls
    assert any(c[0] == "tts" and c[1] == extracted_text and c[2] == output for c in calls)


def test_run_stdin_mode_skips_extractor(tmp_path: Path):
    output = tmp_path / "out.mp3"
    calls = []

    def fake_tts(text: str, out: Path, *, voice: str, speed: float) -> None:
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

    def fake_tts(text: str, out: Path, *, voice: str, speed: float) -> None:
        pass

    app = _make_app(tmp_path, tts=fake_tts)
    stdin = io.StringIO("Some text")
    app.run(url=None, output=output, voice="en-US-GuyNeural", stdin=stdin)

    assert str(output) in app.stderr.getvalue()


def test_run_speed_is_passed_to_tts(tmp_path: Path):
    output = tmp_path / "out.mp3"
    calls = []

    def fake_tts(text: str, out: Path, *, voice: str, speed: float) -> None:
        calls.append(("tts", speed))

    app = _make_app(tmp_path, tts=fake_tts)
    stdin = io.StringIO("Hello")
    code = app.run(url=None, output=output, voice="en-US-GuyNeural", speed=1.5, stdin=stdin)

    assert code == 0
    assert ("tts", 1.5) in calls
