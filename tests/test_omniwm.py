import json
import os
from pathlib import Path
import platform
import plistlib
import shlex
import subprocess
import sys
import tempfile
import tomllib
import unittest


PROJECT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT / "mods/dotfiles/mise/runtime/mise/check-omniwm-handoff.sh"
LEGACY = "org.nix-community.home.omniwm"
MISE = os.environ.get("MISE_TEST_BINARY")


def host_config(host):
    """The host's bootstrap tables merged with its roles, as mise combines them."""
    config = tomllib.loads((PROJECT / "homes" / host / "mise.toml").read_text())
    merged = {"packages": {}, "hooks": {}, "macos": {"launchd": {"agents": {}}}}
    for layer in [*(tomllib.loads((PROJECT / "mods" / role).read_text())
                    for role in config.get("include", [])), config]:
        bootstrap = layer.get("bootstrap", {})
        merged["packages"].update(bootstrap.get("packages", {}))
        merged["hooks"].update(bootstrap.get("hooks", {}))
        merged["macos"]["launchd"]["agents"].update(
            bootstrap.get("macos", {}).get("launchd", {}).get("agents", {}))
    return {"bootstrap": merged}


class OmniwmTests(unittest.TestCase):
    def test_host_ownership(self):
        for host in ["nicks-mbp", "nicks-loancrate-mbp", "maclab", "supermicro"]:
            config = host_config(host)
            enabled = host in {"nicks-mbp", "nicks-loancrate-mbp"}
            bootstrap = config.get("bootstrap", {})
            self.assertEqual("brew-cask:omniwm" in bootstrap.get("packages", {}), enabled)
            agents = bootstrap.get("macos", {}).get("launchd", {}).get("agents", {})
            self.assertEqual("omniwm" in agents, enabled)
            if enabled:
                self.assertEqual(bootstrap["packages"]["brew-cask:omniwm"]["os"], "macos/arm64")
                self.assertEqual(agents["omniwm"], {
                    "program": "/Applications/OmniWM.app/Contents/MacOS/OmniWM",
                    "keep_alive": True, "run_at_load": True,
                    "stdout_path": "/tmp/omniwm.log", "stderr_path": "/tmp/omniwm.err.log",
                })
                self.assertIn("check-omniwm-handoff.sh", bootstrap["hooks"]["pre-defaults"]["run"])

    def test_consumers_use_native_bundle(self):
        for relative in ["karabiner/src/window-action-catalog.ts", "karabiner.json",
                         "look-sources/window-management.toml", "shell_scripts/omniwm-workspace-move-adjacent.sh"]:
            content = (PROJECT / "mods/dotfiles" / relative).read_text()
            self.assertNotIn("/etc/profiles/per-user/nick/bin/omniwmctl", content, relative)
            self.assertIn("/Applications/OmniWM.app/Contents/MacOS/omniwmctl", content, relative)

    def test_adjacent_workspace_command(self):
        with tempfile.TemporaryDirectory(prefix="omniwm-workspaces-") as directory:
            root = Path(directory)
            cli, trace = root / "omniwmctl fixture", root / "trace"
            cli.write_text('''#!/bin/sh
case "$1" in
 query) printf '%s\\n' '{"result":{"payload":{"workspaces":[{"number":1},{"number":5,"isCurrent":true}]}}}' ;;
 command) printf '%s\\n' "$*" > "$TRACE" ;;
 *) exit 99 ;;
esac
''')
            cli.chmod(0o700)
            result = subprocess.run(["bash", str(PROJECT / "mods/dotfiles/shell_scripts/omniwm-workspace-move-adjacent.sh"), "next"],
                env={**os.environ, "OMNIWMCTL": str(cli), "TRACE": str(trace),
                     "PATH": f"{Path(sys.executable).parent}:/usr/bin:/bin"},
                capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(trace.read_text().strip(), "command move-to-workspace 1")

    def test_handoff_guard(self):
        with tempfile.TemporaryDirectory(prefix="omniwm-guard-") as directory:
            root = Path(directory)
            app, legacy, trace = root / "app", root / "legacy.plist", root / "trace"
            app.touch()
            app.chmod(0o700)
            for name, body in {
                "uname": "printf 'Darwin\\n'",
                "launchctl": 'printf "%s\\n" "$*" >> "$TRACE"; exit "$LEGACY_EXIT"',
            }.items():
                tool = root / name
                tool.write_text("#!/bin/sh\n" + body + "\n")
                tool.chmod(0o700)
            def run(status):
                return subprocess.run(["sh", str(SCRIPT), str(app), str(legacy)],
                    env={**os.environ, "PATH": f"{root}:/usr/bin:/bin", "TRACE": str(trace),
                         "LEGACY_EXIT": str(status)}, capture_output=True, text=True, timeout=10)
            self.assertEqual(run(113).returncode, 0)
            self.assertNotEqual(run(0).returncode, 0)
            self.assertNotEqual(run(5).returncode, 0)
            self.assertNotIn("bootout", trace.read_text())
            legacy.symlink_to(root / "missing-generation")
            trace.write_text("")
            self.assertNotEqual(run(113).returncode, 0)
            self.assertEqual(trace.read_text(), "")

    @unittest.skipUnless(platform.system() == "Darwin" and MISE, "native launchd acceptance needs macOS and MISE_TEST_BINARY")
    def test_native_mise_plist_and_hook(self):
        with tempfile.TemporaryDirectory(prefix="omniwm-native-") as directory:
            root = Path(directory)
            app, trace = root / "app 'quoted'", root / "trace"
            app.touch()
            app.chmod(0o700)
            launchctl = root / "launchctl"
            launchctl.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$TRACE"
case "$1" in
 print)
  case "$2" in
   */org.nix-community.home.omniwm) exit "$LEGACY_EXIT" ;;
   *) exit 113 ;;
  esac ;;
 bootstrap|bootout|enable) exit 0 ;;
 *) exit 99 ;;
esac
''')
            launchctl.chmod(0o700)
            source = host_config("nicks-mbp")["bootstrap"]
            agent = {**source["macos"]["launchd"]["agents"]["omniwm"], "program": str(app)}
            hook = source["hooks"]["pre-defaults"]["run"].replace(
                "/Applications/OmniWM.app/Contents/MacOS/OmniWM", shlex.quote(str(app)))
            config = root / "config.toml"
            config.write_text(
                '[vars]\ndotfiles_root = ' + json.dumps(str(PROJECT / "mods/dotfiles")) +
                '\n[bootstrap.hooks.pre-defaults]\nrun = ' + json.dumps(hook) +
                '\n[bootstrap.macos.launchd.agents.omniwm]\n' +
                '\n'.join(f'{key} = {json.dumps(value)}' for key, value in agent.items()) + '\n')
            env = {"HOME": str(root), "USER": os.environ.get("USER", "nick"),
                   "PATH": f"{root}:/usr/bin:/bin:/usr/sbin:/sbin",
                   "MISE_GLOBAL_CONFIG_FILE": str(config), "MISE_SYSTEM_CONFIG_DIR": str(root / "system"),
                   "MISE_TRUSTED_CONFIG_PATHS": str(root), "TRACE": str(trace), "LEGACY_EXIT": "113"}
            # Deny the real executable even if upstream stops respecting the fixture PATH.
            sandbox = ["/usr/bin/sandbox-exec", "-p", '(version 1)(allow default)(deny process-exec (literal "/bin/launchctl") (literal "/usr/bin/launchctl"))']
            def run(args, overrides=None):
                return subprocess.run([*sandbox, MISE, *args], cwd=root,
                    env={**env, **(overrides or {})}, capture_output=True, text=True, timeout=30)
            result = run(["bootstrap", "--only", "defaults"])
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(LEGACY, trace.read_text())
            result = run(["bootstrap", "--only", "defaults"], {"LEGACY_EXIT": "0"})
            self.assertNotEqual(result.returncode, 0)
            trace.write_text("")
            result = run(["bootstrap", "macos", "launchd-agents", "apply", "--yes"])
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            plist = plistlib.loads((root / "Library/LaunchAgents/dev.mise.omniwm.plist").read_bytes())
            self.assertEqual(plist["Label"], "dev.mise.omniwm")
            self.assertEqual(plist["ProgramArguments"], [str(app)])
            self.assertTrue(plist["KeepAlive"])
            self.assertTrue(plist["RunAtLoad"])
            self.assertEqual(plist["StandardOutPath"], agent["stdout_path"])
            self.assertEqual(plist["StandardErrorPath"], agent["stderr_path"])
            self.assertIn("bootstrap gui/", trace.read_text())
            self.assertNotIn(LEGACY, trace.read_text())


if __name__ == "__main__":
    unittest.main()
