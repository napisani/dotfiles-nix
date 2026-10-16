import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "workmux_pr.py"


class WorkmuxPrTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.log = self.root / "calls"
        executable = self.root / "workmux"
        executable.write_text(
            f"#!{sys.executable}\n"
            "import json,os,sys\n"
            "with open(os.environ['WORKMUX_CALLS'],'a') as log:\n"
            " log.write(json.dumps({'args':sys.argv[1:],'cwd':os.getcwd()})+'\\n')\n"
            "sys.exit(1 if '13' in sys.argv else 0)\n"
        )
        executable.chmod(0o755)
        self.environment = dict(
            os.environ,
            PATH=f"{self.root}:{os.environ['PATH']}",
            WORKMUX_CALLS=str(self.log),
        )

    def call(self, *args, status=0):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=self.root,
            env=self.environment,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, status, result.stderr)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_development_is_native_workmux_in_the_calling_directory(self):
        self.call("--purpose", "development", "12")
        self.assertEqual(
            self.calls(),
            [
                {
                    "args": ["add", "--pr", "12", "--open-if-exists"],
                    "cwd": str(self.root),
                }
            ],
        )
        self.assertEqual(
            sorted(p.name for p in self.root.iterdir()), ["calls", "workmux"]
        )

    def test_review_uses_only_native_options_and_a_static_profile(self):
        self.call("--purpose", "review", "12")
        args = self.calls()[0]["args"]
        self.assertEqual(
            args[:5], ["add", "--pr", "12", "--open-if-exists", "review/12"]
        )
        self.assertEqual(args[-2:], ["--no-hooks", "--no-file-ops"])
        profile = Path(args[args.index("--config") + 1])
        self.assertEqual(profile, SCRIPT.with_name("workmux-review.json"))
        settings = json.loads(profile.read_text())
        self.assertNotIn("agent", settings)
        self.assertEqual(settings["post_create"], [])
        self.assertEqual(settings["files"], {"copy": [], "symlink": []})
        self.assertTrue(
            settings["panes"][0]["command"].endswith("NVIM_NO_PROJECT_CONFIG=1 nvim")
        )
        self.assertNotIn("--listen", settings["panes"][0]["command"])
        self.assertEqual(settings["panes"][1]["command"], "<agent>")

    def test_failures_do_not_drop_remaining_requests(self):
        self.call("--purpose", "review", "12", "13", "14", status=1)
        self.assertEqual([call["args"][2] for call in self.calls()], ["12", "13", "14"])

    def test_removed_operations_and_invalid_requests_fail_before_creation(self):
        for args in (
            ("12",),
            ("--purpose", "review", "--action", "tour", "12"),
            ("--purpose", "review", "--refresh", "12"),
            ("--purpose", "review", "--focus", "12"),
            ("--purpose", "review", "12", "invalid"),
            ("--purpose", "development", "0"),
        ):
            self.call(*args, status=2)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
