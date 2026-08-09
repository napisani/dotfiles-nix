from __future__ import annotations

import sys
from pathlib import Path

import click

from .app import ReadAloudApp
from .tts import DEFAULT_SPEED, DEFAULT_VOICE


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
@click.option(
    "--speed",
    default=DEFAULT_SPEED,
    show_default=True,
    type=float,
    help="Playback speed multiplier (1.0 = normal, 1.2 = 20% faster, 0.8 = 20% slower).",
)
def cli(url: str | None, output: Path, voice: str, speed: float) -> None:
    """Convert a web article or piped text to speech and save as MP3."""
    stdin = sys.stdin if not sys.stdin.isatty() else None
    app = ReadAloudApp()
    raise SystemExit(app.run(url=url, output=output, voice=voice, speed=speed, stdin=stdin))


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
