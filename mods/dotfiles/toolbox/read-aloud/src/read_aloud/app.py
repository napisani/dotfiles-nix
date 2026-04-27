from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, TextIO

from .extractor import ExtractionError, extract_from_url
from .tts import DEFAULT_SPEED, DEFAULT_VOICE, text_to_mp3


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
        speed: float = DEFAULT_SPEED,
        stdin: TextIO | None,
    ) -> int:
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
        self.tts(text, output, voice=voice, speed=speed)
        self.stderr.write(f"Saved: {output}\n")
        return 0
