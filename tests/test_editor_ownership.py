"""Guard editor package ownership independently of installed plugin caches."""

from pathlib import Path
import unittest


NVIM = Path(__file__).resolve().parents[1] / "mods/dotfiles/nvim"


class EditorOwnershipTest(unittest.TestCase):
    def test_editor_does_not_start_a_second_package_manager(self):
        for name in ["lua/user/lazy.lua", "lua/user/lsp/init.lua"]:
            with self.subTest(source=name):
                self.assertNotIn("mason", (NVIM / name).read_text())
        self.assertFalse((NVIM / "lua/user/lsp/mason.lua").exists())

    def test_javascript_adapter_uses_the_declared_module(self):
        source = (NVIM / "lua/user/dap/typescript.lua").read_text()
        self.assertNotIn('command = "js-debug-adapter"', source)
        self.assertIn('"github:microsoft/vscode-js-debug"', source)
        self.assertIn('"/src/dapDebugServer.js"', source)
