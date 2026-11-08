import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parents[1]
LIBRARY = PROJECT / "mods/dotfiles/direnv/lib/use_flake.sh"
ENVIRONMENTS = [
    ".envrc", "priv/kube-home-lab/.envrc", "pub/animalcontrol/.envrc",
    "pub/proctmux/.envrc", "pub/secret_inject/.envrc", "pub/scrollbacktamer/.envrc",
]
PROBE = '''
set -eu
watch_file() { :; }
direnv_layout_dir() { printf '%s/.direnv' "$PWD"; }
use() { use_flake; }
nix() {
    [ -d "$(direnv_layout_dir)" ] || return 22
    [ "$NIX_FAIL" = 0 ] || return 23
    printf 'export BOUNDARY_READY=yes\\n'
}
. "$LIBRARY"
. "$ENVRC"
[ "${BOUNDARY_READY:-}" = yes ]
'''


class DirenvBoundaryTests(unittest.TestCase):
    def test_fresh_layout_and_evaluation_failures(self):
        for relative in ENVIRONMENTS:
            for fail in ["0", "1"]:
                with self.subTest(envrc=relative, failure=fail), tempfile.TemporaryDirectory() as cwd:
                    result = subprocess.run(
                        ["bash", "--noprofile", "--norc", "-c", PROBE], cwd=cwd,
                        env={**os.environ, "ENVRC": str(ROOT / relative), "LIBRARY": str(LIBRARY),
                             "NIX_FAIL": fail},
                        capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 0 if fail == "0" else 23, result.stderr)

    def test_one_deployed_definition(self):
        for relative in ENVIRONMENTS:
            self.assertNotIn("use_flake()", (ROOT / relative).read_text(), relative)
        dotfiles = tomllib.loads((PROJECT / "mods/dotfiles/mise/config.toml").read_text())["dotfiles"]
        self.assertEqual(
            dotfiles["~/.config/direnv/lib/use_flake.sh"]["source"],
            "~/.config/mise/dotfiles/direnv/lib/use_flake.sh",
        )


if __name__ == "__main__":
    unittest.main()
