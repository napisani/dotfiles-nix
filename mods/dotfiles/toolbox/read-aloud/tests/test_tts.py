from __future__ import annotations

import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch


def _write_audio(path: str) -> None:
    Path(path).write_bytes(b"audio")


def test_text_to_mp3_calls_edge_tts_save(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock(side_effect=_write_audio)

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello world", output, voice="en-US-GuyNeural")

    mock_cls.assert_called_once_with("Hello world", "en-US-GuyNeural", rate="+0%")
    mock_communicate.save.assert_called_once()


def test_text_to_mp3_uses_default_voice(tmp_path: Path):
    from read_aloud.tts import DEFAULT_VOICE, text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock(side_effect=_write_audio)

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello", output)

    mock_cls.assert_called_once_with("Hello", DEFAULT_VOICE, rate="+0%")


def test_text_to_mp3_speed_above_1_produces_positive_rate(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock(side_effect=_write_audio)

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello", output, speed=1.2)

    mock_cls.assert_called_once_with("Hello", "en-US-GuyNeural", rate="+20%")


def test_text_to_mp3_speed_below_1_produces_negative_rate(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock(side_effect=_write_audio)

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello", output, speed=0.8)

    mock_cls.assert_called_once_with("Hello", "en-US-GuyNeural", rate="-20%")


def test_speed_to_rate_conversion():
    from read_aloud.tts import _speed_to_rate

    assert _speed_to_rate(1.0) == "+0%"
    assert _speed_to_rate(1.2) == "+20%"
    assert _speed_to_rate(0.8) == "-20%"
    assert _speed_to_rate(2.0) == "+100%"
    assert _speed_to_rate(0.5) == "-50%"


def _handshake_error(status: int):
    from aiohttp import RequestInfo, WSServerHandshakeError
    from multidict import CIMultiDict, CIMultiDictProxy
    from yarl import URL

    url = URL("wss://speech.example/edge/v1?Sec-MS-GEC=SIGNED-SECRET")
    info = RequestInfo(url, "GET", CIMultiDictProxy(CIMultiDict()), url)
    return WSServerHandshakeError(info, (), status=status, message="Invalid response status")


def _fake_communicate(save):
    communicate = MagicMock()
    communicate.save = save
    return communicate


def test_handshake_rejection_raises_synthesis_error_without_signed_url(tmp_path: Path):
    import pytest

    from read_aloud.tts import SynthesisError, text_to_mp3

    output = tmp_path / "out.mp3"
    communicate = _fake_communicate(AsyncMock(side_effect=_handshake_error(403)))

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=communicate):
        with pytest.raises(SynthesisError) as excinfo:
            text_to_mp3("Hello", output)

    message = str(excinfo.value)
    assert "403" in message
    assert "SIGNED-SECRET" not in message
    assert "wss://" not in message


def test_edge_tts_error_raises_synthesis_error(tmp_path: Path):
    import pytest
    from edge_tts.exceptions import NoAudioReceived

    from read_aloud.tts import SynthesisError, text_to_mp3

    communicate = _fake_communicate(AsyncMock(side_effect=NoAudioReceived("No audio was received.")))

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=communicate):
        with pytest.raises(SynthesisError, match="No audio was received"):
            text_to_mp3("Hello", tmp_path / "out.mp3")


def test_failed_synthesis_keeps_existing_output_and_leaves_no_partial(tmp_path: Path):
    import pytest

    from read_aloud.tts import SynthesisError, text_to_mp3

    output = tmp_path / "article.mp3"
    output.write_bytes(b"previous audio")

    async def write_then_fail(path: str) -> None:
        Path(path).write_bytes(b"partial")
        raise _handshake_error(403)

    communicate = _fake_communicate(write_then_fail)

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=communicate):
        with pytest.raises(SynthesisError):
            text_to_mp3("Hello", output)

    assert output.read_bytes() == b"previous audio"
    assert list(tmp_path.iterdir()) == [output]


def test_successful_synthesis_replaces_output_and_leaves_no_partial(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "article.mp3"
    output.write_bytes(b"previous audio")

    async def write_audio(path: str) -> None:
        Path(path).write_bytes(b"new audio")

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=_fake_communicate(write_audio)):
        text_to_mp3("Hello", output)

    assert output.read_bytes() == b"new audio"
    assert list(tmp_path.iterdir()) == [output]


def test_successful_synthesis_keeps_umask_default_permissions(tmp_path: Path):
    import os

    from read_aloud.tts import text_to_mp3

    output = tmp_path / "article.mp3"

    async def write_audio(path: str) -> None:
        Path(path).write_bytes(b"audio")

    previous = os.umask(0o022)
    try:
        with patch("read_aloud.tts.edge_tts.Communicate", return_value=_fake_communicate(write_audio)):
            text_to_mp3("Hello", output)
    finally:
        os.umask(previous)

    assert output.stat().st_mode & 0o777 == 0o644


def test_existing_partial_file_is_neither_overwritten_nor_removed(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "article.mp3"
    foreign = tmp_path / ".article.mp3.aaaa.part"
    foreign.write_bytes(b"someone else's data")

    with patch("read_aloud.tts.secrets.token_hex", side_effect=["aaaa", "bbbb"]):
        with patch("read_aloud.tts.edge_tts.Communicate", return_value=_fake_communicate(AsyncMock(side_effect=_write_audio))):
            text_to_mp3("Hello", output)

    assert foreign.read_bytes() == b"someone else's data"
    assert output.read_bytes() == b"audio"


def test_concurrent_synthesis_to_same_output_uses_distinct_partials(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "article.mp3"
    seen: list[Path] = []

    async def inner_save(path: str) -> None:
        seen.append(Path(path))
        Path(path).write_bytes(b"second")

    async def outer_save(path: str) -> None:
        seen.append(Path(path))
        Path(path).write_bytes(b"first")
        await asyncio.to_thread(text_to_mp3, "Second", output)
        # The nested call finished while this call's partial was in flight.
        assert Path(path).exists()

    communicates = [_fake_communicate(outer_save), _fake_communicate(inner_save)]
    with patch("read_aloud.tts.edge_tts.Communicate", side_effect=communicates):
        text_to_mp3("First", output)

    assert seen[0] != seen[1]
    assert output.read_bytes() == b"first"
    assert list(tmp_path.iterdir()) == [output]
