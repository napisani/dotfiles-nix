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

    mock_cls.assert_called_once_with("Hello world", "en-US-GuyNeural", rate="+0%")
    mock_communicate.save.assert_called_once_with(str(output))


def test_text_to_mp3_uses_default_voice(tmp_path: Path):
    from read_aloud.tts import DEFAULT_VOICE, text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock()

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello", output)

    mock_cls.assert_called_once_with("Hello", DEFAULT_VOICE, rate="+0%")


def test_text_to_mp3_speed_above_1_produces_positive_rate(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock()

    with patch("read_aloud.tts.edge_tts.Communicate", return_value=mock_communicate) as mock_cls:
        text_to_mp3("Hello", output, speed=1.2)

    mock_cls.assert_called_once_with("Hello", "en-US-GuyNeural", rate="+20%")


def test_text_to_mp3_speed_below_1_produces_negative_rate(tmp_path: Path):
    from read_aloud.tts import text_to_mp3

    output = tmp_path / "out.mp3"
    mock_communicate = MagicMock()
    mock_communicate.save = AsyncMock()

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
