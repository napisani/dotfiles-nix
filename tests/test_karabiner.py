import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]


class KarabinerGenerationTests(unittest.TestCase):
    def test_generation_preserves_user_config_and_writes_beside_its_source(self):
        deno = shutil.which("deno")
        self.assertIsNotNone(deno, "Activate the declared Deno runtime")
        with tempfile.TemporaryDirectory(prefix="karabiner source ") as directory:
            root = Path(directory)
            checkout = root / "checkout"
            source = checkout / "mods/dotfiles/karabiner"
            shutil.copytree(PROJECT / "mods/dotfiles/karabiner", source, ignore=shutil.ignore_patterns("node_modules"))
            shutil.copy2(PROJECT / "mods/dotfiles/karabiner.json", source.parent / "karabiner.json")
            home = root / "home"
            config = home / ".config/karabiner/karabiner.json"
            config.parent.mkdir(parents=True)
            original = '{"manual": true}\n'
            config.write_text(original)
            result = subprocess.run(
                [deno, "run", "--frozen", "-A", "src/index.ts"],
                cwd=source,
                env={**os.environ, "HOME": str(home), "DOTFILES_HOME_MANAGER_DIR": str(root / "wrong-checkout"), "DOTFILES_DIR": str(root / "wrong-checkout")},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(config.is_symlink())
            self.assertEqual(config.read_text(), original)
            generated = checkout / "mods/dotfiles/karabiner.json"
            self.assertTrue(json.loads(generated.read_text())["profiles"])
            self.assertTrue((checkout / "mods/dotfiles/look-sources/window-management.toml").is_file())


if __name__ == "__main__":
    unittest.main()
