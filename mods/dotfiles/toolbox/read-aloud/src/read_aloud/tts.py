from __future__ import annotations

import asyncio
from pathlib import Path

import edge_tts

DEFAULT_VOICE = "en-US-GuyNeural"
DEFAULT_SPEED = 1.0


def _speed_to_rate(speed: float) -> str:
    """Convert a speed multiplier to an edge-tts rate string.

    1.0 → "+0%", 1.2 → "+20%", 0.8 → "-20%"
    """
    return f"{(speed - 1) * 100:+.0f}%"


def text_to_mp3(text: str, output: Path, *, voice: str = DEFAULT_VOICE, speed: float = DEFAULT_SPEED) -> None:
    """Convert text to an MP3 file using Microsoft Edge TTS.

    Blocks until the file is written.
    """
    communicate = edge_tts.Communicate(text, voice, rate=_speed_to_rate(speed))
    asyncio.run(communicate.save(str(output)))
