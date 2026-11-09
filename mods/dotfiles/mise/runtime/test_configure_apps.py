import json
import os
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

import tomli_w

sys.path.insert(0, str(Path(__file__).parent))

from configure_apps import (  # noqa: E402 -- imported from beside this test, after the path insert
    ConfigWriter,
    apply_claude_settings,
    apply_codex_config,
    apply_codex_hooks,
    apply_managed_key,
    apply_pi_skill_paths,
)

SCRIPT = Path(__file__).with_name("configure_apps.py")
DOTFILES = Path(__file__).parents[2]
APPLY = ConfigWriter("apply")


def read_json(file: Path):
    return json.loads(file.read_text())


def write_json(file: Path, value) -> None:
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(json.dumps(value))


class ConfigureAppsTest(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory(prefix="configure-apps-")
        self.dir = Path(self._dir.name).resolve()

    def tearDown(self) -> None:
        self._dir.cleanup()

    def test_managed_keys_are_owned_outright_while_sibling_keys_survive(self) -> None:
        target = self.dir / "target.json"
        write_json(target, {"mcpServers": {"stale": {}, "userAdded": {"command": "manual"}}, "oauthAccount": {"token": "secret"}})
        target.chmod(0o640)
        apply_managed_key(APPLY, target, "mcpServers", {"linear": {"url": "https://mcp.linear.app/mcp"}})
        self.assertEqual(read_json(target), {"mcpServers": {"linear": {"url": "https://mcp.linear.app/mcp"}}, "oauthAccount": {"token": "secret"}})
        self.assertEqual(target.stat().st_mode & 0o777, 0o640)

    def test_a_missing_target_is_created_privately_with_just_the_managed_key(self) -> None:
        target = self.dir / "nested/target.json"
        apply_managed_key(APPLY, target, "mcpServers", {"linear": {}})
        self.assertEqual(read_json(target), {"mcpServers": {"linear": {}}})
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_invalid_targets_and_declarations_fail_without_changing_shared_state(self) -> None:
        target = self.dir / "target.json"
        target.write_text("not json {{{")
        with self.assertRaisesRegex(ValueError, "invalid JSON"):
            apply_managed_key(APPLY, target, "mcpServers", {})
        self.assertEqual(target.read_text(), "not json {{{")
        target.write_text("[]")
        with self.assertRaisesRegex(ValueError, "not a JSON object"):
            apply_managed_key(APPLY, target, "mcpServers", {})
        original = '{"oauth":"private","mcpServers":{}}'
        target.write_text(original)
        for declared in (None, [], "wrong-shape", 1):
            with self.assertRaisesRegex(ValueError, "invalid declared"):
                apply_managed_key(APPLY, target, "mcpServers", declared)
            self.assertEqual(target.read_text(), original)

    def test_claude_workmux_hooks_replace_and_revoke_without_touching_rtk_or_manual_hooks(self) -> None:
        target = self.dir / "settings.json"
        unmanaged = {"matcher": "Bash", "hooks": [{"type": "command", "command": "my-personal-hook"}, {"type": "command", "command": "rtk hook claude"}]}
        write_json(target, {"hooks": {"PreToolUse": [unmanaged]}})
        for status in ("waiting", "running"):
            managed = {"matcher": "Bash", "hooks": [{"type": "command", "command": f"workmux set-window-status {status}"}]}
            apply_claude_settings(APPLY, target, {"PreToolUse": [managed]}, {"skill": "user-invocable-only"})
            self.assertEqual(read_json(target)["hooks"]["PreToolUse"], [unmanaged, managed])
            before = target.stat().st_mtime_ns
            apply_claude_settings(APPLY, target, {"PreToolUse": [managed]}, {"skill": "user-invocable-only"})
            self.assertEqual(target.stat().st_mtime_ns, before)
        status_writer = ConfigWriter("status")
        before_text = target.read_text()
        apply_claude_settings(status_writer, target, {}, {})
        self.assertTrue(status_writer.drift)
        self.assertEqual(target.read_text(), before_text)
        apply_claude_settings(APPLY, target, {}, {})
        self.assertEqual(read_json(target)["hooks"]["PreToolUse"], [unmanaged])
        self.assertEqual(read_json(target)["skillOverrides"], {})

    def test_corrupt_hook_targets_fail_closed(self) -> None:
        cases = [
            ("settings.json", lambda file: apply_claude_settings(APPLY, file, {}, {})),
            ("hooks.json", lambda file: apply_codex_hooks(APPLY, file, {})),
        ]
        for name, apply_hooks in cases:
            target = self.dir / name
            target.write_text("not-json")
            with self.assertRaisesRegex(ValueError, "invalid JSON"):
                apply_hooks(target)
            self.assertEqual(target.read_text(), "not-json")

    def test_codex_config_replaces_mcp_and_reenables_only_managed_hook_state(self) -> None:
        hooks, config = self.dir / "hooks.json", self.dir / "config.toml"
        managed_key, manual_key = f"{hooks}:stop:0:0", f"{hooks}:stop:0:1"
        write_json(hooks, {"hooks": {"Stop": [{"hooks": [{"command": "workmux set-window-status done"}, {"command": "manual"}]}]}})
        before = tomli_w.dumps({
            "model": "keep",
            "features": {"hooks": False, "other": True},
            "mcp_servers": {"old": {"command": "old"}},
            "hooks": {"state": {managed_key: {"enabled": False}, manual_key: {"enabled": False}}},
        })
        config.write_text(before)
        status_writer = ConfigWriter("status")
        apply_codex_config(status_writer, config, {"new": {"command": "new"}}, hooks)
        self.assertTrue(status_writer.drift)
        self.assertEqual(config.read_text(), before)
        apply_codex_config(APPLY, config, {"new": {"command": "new"}}, hooks)
        result = tomllib.loads(config.read_text())
        self.assertEqual(list(result["mcp_servers"]), ["new"])
        self.assertEqual(result["model"], "keep")
        self.assertEqual(result["features"], {"hooks": False, "other": True})
        self.assertTrue(result["hooks"]["state"][managed_key]["enabled"])
        self.assertFalse(result["hooks"]["state"][manual_key]["enabled"])
        healthy = ConfigWriter("status")
        apply_codex_config(healthy, config, {"new": {"command": "new"}}, hooks)
        self.assertFalse(healthy.drift)

    def test_pi_skill_paths_add_declarations_retire_earlier_ones_and_keep_hand_added_paths(self) -> None:
        settings, state = self.dir / "settings.json", self.dir / "state/pi-skill-paths.json"
        write_json(settings, {
            "custom": True,
            "packages": ["manual-package"],
            "providers": {"stale": {}},
            "skills": ["~/manual-skills", "~/code/*/apps/*/.agents/skills"],
        })
        apply_pi_skill_paths(APPLY, settings, ["~/old-skills", "~/kept-skills"], state)
        apply_pi_skill_paths(APPLY, settings, ["~/kept-skills"], state)
        self.assertEqual(read_json(settings), {"custom": True, "packages": ["manual-package"], "skills": ["~/manual-skills", "~/kept-skills"]})
        self.assertEqual(read_json(state), ["~/kept-skills"])
        before = settings.read_text()
        with self.assertRaisesRegex(ValueError, "invalid Pi skill paths"):
            apply_pi_skill_paths(APPLY, settings, "not-a-list", state)
        self.assertEqual(settings.read_text(), before)

    def test_the_command_reports_drift_without_writing_then_converges(self) -> None:
        home = self.dir / "home"
        home.mkdir()
        overrides = home / "overrides.json"
        write_json(overrides, {"classify": "user-invocable-only"})

        def run(mode: str) -> subprocess.CompletedProcess[str]:
            env = {**os.environ, "HOME": str(home), "RECONCILE_MODE": mode}
            return subprocess.run([sys.executable, str(SCRIPT), str(DOTFILES), "work", str(overrides)], env=env, capture_output=True, text=True, check=False)

        before = sorted(entry.name for entry in home.iterdir())
        status = run("status")
        self.assertEqual(status.returncode, 1, status.stderr)
        self.assertRegex(status.stdout, "config: drift")
        self.assertEqual(sorted(entry.name for entry in home.iterdir()), before)
        applied = run("apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertEqual((home / ".claude.json").stat().st_mode & 0o777, 0o600)
        healthy = run("status")
        self.assertEqual(healthy.returncode, 0, healthy.stdout)


if __name__ == "__main__":
    unittest.main()
