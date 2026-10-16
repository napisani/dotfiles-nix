from __future__ import annotations

import asyncio
import os
import secrets
from pathlib import Path

import aiohttp
import edge_tts
from edge_tts.exceptions import EdgeTTSException

DEFAULT_VOICE = "en-US-GuyNeural"
DEFAULT_SPEED = 1.0


class SynthesisError(Exception):
    """The speech backend failed; the message is safe to show to the user."""


def _speed_to_rate(speed: float) -> str:
    """Convert a speed multiplier to an edge-tts rate string.

    1.0 → "+0%", 1.2 → "+20%", 0.8 → "-20%"
    """
    return f"{(speed - 1) * 100:+.0f}%"


def _describe_backend_error(exc: Exception) -> str:
    # aiohttp errors embed the signed request URL in str(exc), so report only
    # the status.
    if isinstance(exc, aiohttp.ClientResponseError):
        return f"speech service rejected the request (HTTP {exc.status})"
    if isinstance(exc, EdgeTTSException):
        return str(exc)
    return f"could not reach the speech service ({type(exc).__name__})"


def _create_partial_file(output: Path) -> Path:
    # O_EXCL guarantees this call owns the file, so cleanup never removes
    # another invocation's partial. The 0o666 mode is narrowed by the umask.
    while True:
        partial = output.with_name(f".{output.name}.{secrets.token_hex(4)}.part")
        try:
            os.close(os.open(partial, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o666))
        except FileExistsError:
            continue
        return partial


def text_to_mp3(text: str, output: Path, *, voice: str = DEFAULT_VOICE, speed: float = DEFAULT_SPEED) -> None:
    """Convert text to an MP3 file using Microsoft Edge TTS.

    Blocks until the file is written. Raises SynthesisError on backend failure,
    leaving any existing file at `output` untouched.
    """
    communicate = edge_tts.Communicate(text, voice, rate=_speed_to_rate(speed))
    # edge-tts truncates its target before connecting, so synthesize to a
    # sibling file and rename it over `output` only on success.
    partial = _create_partial_file(output)
    try:
        asyncio.run(communicate.save(str(partial)))
        os.replace(partial, output)
    except (aiohttp.ClientError, EdgeTTSException) as exc:
        raise SynthesisError(_describe_backend_error(exc)) from None
    finally:
        partial.unlink(missing_ok=True)
