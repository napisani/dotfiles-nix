from __future__ import annotations

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


def test_cli_speed_default_is_1(tmp_path: Path):
    from read_aloud.cli import cli
    from read_aloud.tts import DEFAULT_SPEED

    output = tmp_path / "out.mp3"
    runner = CliRunner()

    with patch("read_aloud.cli.ReadAloudApp") as MockApp:
        instance = MagicMock()
        instance.run.return_value = 0
        MockApp.return_value = instance

        runner.invoke(cli, ["--url", "https://example.com", "--output", str(output)])

    call_kwargs = instance.run.call_args.kwargs
    assert call_kwargs["speed"] == DEFAULT_SPEED


def test_cli_speed_option_is_passed_to_app(tmp_path: Path):
    from read_aloud.cli import cli

    output = tmp_path / "out.mp3"
    runner = CliRunner()

    with patch("read_aloud.cli.ReadAloudApp") as MockApp:
        instance = MagicMock()
        instance.run.return_value = 0
        MockApp.return_value = instance

        runner.invoke(cli, ["--url", "https://example.com", "--output", str(output), "--speed", "1.5"])

    call_kwargs = instance.run.call_args.kwargs
    assert call_kwargs["speed"] == 1.5
