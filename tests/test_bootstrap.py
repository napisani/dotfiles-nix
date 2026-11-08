import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bootstrap home ")
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        mise = self.bin / "mise"
        mise.write_text(
            '#!/bin/sh\n'
            'if [ "$1" = --version ]; then echo mise-fixture; exit; fi\n'
            'printf "%s\\n" "$@" > "$HOME/bootstrap-args"\n'
            'command -v mise > "$HOME/bootstrap-mise-path"\n'
            'printf "%s" "$MISE_SYSTEM_PACKAGES_MANAGERS" > "$HOME/bootstrap-managers"\n'
        )
        mise.chmod(0o700)
        self.env = {"HOME": str(self.home), "PATH": "/usr/bin:/bin", "USER": "fixture"}

    def test_nix_fragment_must_be_retired_before_bootstrap(self):
        fragment = self.home / ".config/mise/conf.d/nix.toml"
        fragment.parent.mkdir(parents=True)
        fragment.symlink_to("/nix/store/retired-fragment")
        result = self.bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retired Nix fragment", result.stderr)
        self.assertTrue(fragment.is_symlink())
        self.assertFalse((self.home / ".config/mise/config.toml").exists())

    def test_plugin_collision_is_preserved_before_config_links_are_created(self):
        plugin = self.home / ".local/share/mise/plugins/pi"
        plugin.mkdir(parents=True)
        (plugin / "manual").write_text("keep")
        result = self.bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((plugin / "manual").read_text(), "keep")
        self.assertFalse((self.home / ".config/mise/config.toml").exists())

    def test_bootstrap_hooks_can_find_the_standalone_mise(self):
        result = self.bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.home / "bootstrap-mise-path").read_text().strip(),
            str(self.bin / "mise"),
        )

    def test_real_mise_applies_core_without_nix_fragment(self):
        executable = os.environ.get("MISE_BIN") or shutil.which("mise")
        self.assertIsNotNone(executable, "Install mise or set MISE_BIN for the native contract test")
        shutil.copy2(Path(executable).resolve(), self.bin / "mise")
        result = self.bootstrap("maclab", "--only", "dotfiles")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / ".config/mise/conf.d/nix.toml").exists())
        self.assertEqual(
            (self.home / ".bashrc").resolve(),
            ROOT / "mods/dotfiles/shell/bash/bashrc",
        )
        self.assertTrue((self.home / ".config/nvim/init.vim").is_symlink())
        self.assertTrue((self.home / ".claude/settings.json").is_file())
        plugins = [self.home / ".local/share/mise/plugins" / name for name in ["claude", "pi"]]
        for plugin in plugins:
            self.assertEqual(
                plugin.resolve(),
                ROOT / "mods/dotfiles/mise/runtime/mise/plugins" / plugin.name,
            )
        inodes = [plugin.lstat().st_ino for plugin in plugins]
        result = self.bootstrap("maclab", "--only", "dotfiles")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([plugin.lstat().st_ino for plugin in plugins], inodes)

    def test_reapplying_preserves_matching_links(self):
        first = self.bootstrap()
        self.assertEqual(first.returncode, 0, first.stderr)
        config = self.home / ".config/mise"
        original = {p.name: p.lstat().st_ino for p in config.iterdir()}
        second = self.bootstrap()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual({p.name: p.lstat().st_ino for p in config.iterdir()}, original)

    def test_late_collision_leaves_all_other_targets_uncreated(self):
        config = self.home / ".config/mise"
        config.mkdir(parents=True)
        manual = config / "mise.local.lock"
        manual.write_text("manual lock\n")
        result = self.bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(manual.read_text(), "manual lock\n")
        self.assertEqual(list(config.iterdir()), [manual])
        self.assertFalse((self.home / "bootstrap-args").exists())

    def test_broken_target_link_is_preserved(self):
        config = self.home / ".config/mise"
        config.mkdir(parents=True)
        link = config / "config.toml"
        link.symlink_to(self.home / "missing")
        result = self.bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(link.readlink(), self.home / "missing")

    def test_symlink_ancestor_cannot_redirect_bootstrap_writes(self):
        outside = self.home / "outside"
        outside.mkdir()
        (self.home / ".config").symlink_to(outside, target_is_directory=True)
        result = self.bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertFalse((self.home / "bootstrap-args").exists())

    def test_unknown_host_is_rejected_before_writes(self):
        result = self.bootstrap("../maclab")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / ".config").exists())
        self.assertFalse((self.home / "bootstrap-args").exists())

    def test_machine_without_a_host_directory_is_rejected(self):
        result = self.bootstrap("not-a-host")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("homes/not-a-host/mise.toml", result.stderr)
        self.assertFalse((self.home / ".config").exists())

    def test_machine_defaults_from_the_hostname_map(self):
        fake = self.home / "fake-bin/hostname"
        fake.parent.mkdir()
        fake.write_text("#!/bin/sh\necho Nicks-MacBook-Pro\n")
        fake.chmod(0o700)
        self.env["PATH"] = f"{fake.parent}:{self.env['PATH']}"
        result = self.bootstrap(None, "--only", "dotfiles")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.home / ".config/mise/config.local.toml").readlink(),
            ROOT / "homes/nicks-mbp/mise.toml",
        )

    def bootstrap(self, machine="maclab", *args):
        return subprocess.run(
            ["/bin/sh", str(ROOT / "bootstrap.sh"), *([machine] if machine else []), *args],
            env=self.env,
            cwd=self.home,
            text=True,
            capture_output=True,
        )

    def test_cold_start_links_global_config_and_delegates_to_mise(self):
        result = self.bootstrap("maclab", "--only", "dotfiles")
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = {
            "config.toml": ROOT / "mods/dotfiles/mise/config.toml",
            "config.local.toml": ROOT / "homes/maclab/mise.toml",
            "dotfiles": ROOT / "mods/dotfiles",
            "mise.lock": ROOT / "mods/dotfiles/mise/mise.lock",
            "mise.local.lock": ROOT / "homes/maclab/mise.local.lock",
        }
        for name, source in expected.items():
            target = self.home / ".config/mise" / name
            self.assertTrue(target.is_symlink(), name)
            self.assertEqual(target.readlink(), source)
        self.assertEqual(
            (self.home / "bootstrap-args").read_text().splitlines(),
            ["-C", str(self.home), "bootstrap", "--only", "dotfiles"],
        )
        self.assertEqual((self.home / "bootstrap-managers").read_text(), "claude,pi")


if __name__ == "__main__":
    unittest.main()
