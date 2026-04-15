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


def test_sync_subcommand_is_wired() -> None:
    runner = CliRunner()
    result = runner.invoke(cli, ["sync", "--help"])
    assert result.exit_code == 0
    assert "STACK_ID" in result.output or "stack" in result.output.lower()
    assert "--dry-run" in result.output


def test_stacks_and_stack_group_help() -> None:
    runner = CliRunner()
    assert runner.invoke(cli, ["stacks", "--help"]).exit_code == 0
    r = runner.invoke(cli, ["stack", "--help"])
    assert r.exit_code == 0
    assert "branches" in r.output
    assert "unlabel" in r.output
    assert "delete" in r.output


def test_merged_subcommand_help() -> None:
    runner = CliRunner()
    r = runner.invoke(cli, ["merged", "--help"])
    assert r.exit_code == 0
    assert "--branch" in r.output
    assert "--dry-run" in r.output


def test_stack_delete_requires_confirmation_flag(tmp_path) -> None:
    from stackman.store import initialize

    db_path = tmp_path / "db.sqlite"
    initialize(db_path)
    runner = CliRunner()
    result = runner.invoke(cli, ["--db-path", str(db_path), "stack", "delete", "x"])
    assert result.exit_code == 1
    assert "--yes" in result.output
