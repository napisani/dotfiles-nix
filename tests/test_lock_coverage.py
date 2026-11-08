import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check-mise-locks.py"


class LockCoverageTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.config = self.root / "config.toml"
        self.lock = self.root / "mise.lock"
        self.config.write_text('[tools]\nexample = "1.2.3"\n')

    def write_lock(self, platforms, backend="aqua:example/tool", specifier="1.2.3"):
        self.lock.write_text(
            '[[tools.example]]\nversion = "1.2.3"\n'
            f'backend = {json.dumps(backend)}\nspecifiers = [{json.dumps(specifier)}]\n'
            'uv = { path = ".mise/locks/example" }\n'
            + "".join(
                f'[tools.example."platforms.{platform}"]\n'
                'url = "https://example.invalid/archive"\nchecksum = "sha256:fixture"\n'
                for platform in platforms
            )
        )

    def run_check(self):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--config", str(self.config), "--lock", str(self.lock)],
            capture_output=True, text=True,
        )

    def test_requires_every_selected_platform(self):
        self.write_lock(["macos-arm64", "macos-x64", "linux-x64"])
        self.assertEqual(self.run_check().returncode, 0)
        self.write_lock(["macos-arm64", "linux-x64"])
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("macos-x64", result.stderr)

    def test_selectors_limit_required_artifacts_but_unknown_selectors_fail(self):
        self.write_lock(["macos-arm64"])
        self.config.write_text('[tools]\nexample = { version = "1.2.3", os = ["macos/arm64"] }\n')
        self.assertEqual(self.run_check().returncode, 0)
        self.config.write_text('[tools]\nexample = { version = "1.2.3", os = ["windows"] }\n')
        self.assertIn("unknown platform", self.run_check().stderr)

    def test_stale_specifiers_fail(self):
        self.write_lock(["macos-arm64", "macos-x64", "linux-x64"], specifier="1.2.2")
        self.assertIn("matching lock", self.run_check().stderr)

    def test_pipx_requires_its_uv_sidecar(self):
        self.write_lock([], backend="pipx:example")
        self.assertIn("missing uv sidecar", self.run_check().stderr)
        sidecar = self.root / ".mise/locks/example/uv.lock"
        sidecar.parent.mkdir(parents=True)
        sidecar.write_text("version = 1\n")
        self.assertEqual(self.run_check().returncode, 0)

    def test_included_tools_are_locked_with_the_including_config(self):
        role = self.root / "dotfiles/roles/example.toml"
        role.parent.mkdir(parents=True)
        role.write_text('[tools]\nexample = "1.2.3"\n')
        self.config.write_text('include = ["dotfiles/roles/example.toml"]\n')
        self.write_lock(["macos-arm64"])
        self.assertIn("macos-x64", self.run_check().stderr)
        self.write_lock(["macos-arm64", "macos-x64", "linux-x64"])
        self.assertEqual(self.run_check().returncode, 0)

    def test_project_toolchain_matches_the_core_versions(self):
        project = SCRIPT.parents[1]
        core = tomllib.loads((project / "mods/dotfiles/mise/config.toml").read_text())["tools"]
        for name, version in tomllib.loads((project / "mise.toml").read_text())["tools"].items():
            self.assertEqual(version, core[name], name)

    def test_npm_and_go_use_version_locks_without_platform_artifacts(self):
        for backend in ["npm:example", "go:example.invalid/tool"]:
            with self.subTest(backend=backend):
                self.write_lock([], backend=backend)
                self.assertEqual(self.run_check().returncode, 0)


if __name__ == "__main__":
    unittest.main()
