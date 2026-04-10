from __future__ import annotations

from click.testing import CliRunner

from stackman.cli import cli


def test_click_cli_help() -> None:
    runner = CliRunner()

    result = runner.invoke(cli, ["--help"])

    assert result.exit_code == 0
    assert "Manage stacked Git branches." in result.output
    assert "status" in result.output
    assert "init" in result.output
