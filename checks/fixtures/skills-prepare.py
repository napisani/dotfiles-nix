import copy
import importlib.util
import json
import os
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

runtime = Path(
    os.environ.get(
        "CONFIG_WRITER_RUNTIME", Path(__file__).resolve().parents[2] / "mods/dotfiles/mise/runtime"
    )
)
spec = importlib.util.spec_from_file_location(
    "skills_prepare", runtime / "mise/skills-prepare.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Preparation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="skill-preparation-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / "sources"
        self.output = self.root / "generated"
        self.write(
            "local/SKILL.md",
            "---\nname: local\ndescription: A local skill\n---\nLocal body\n",
        )
        self.write("local/helpers/run.sh", "#!/bin/sh\necho helper\n")
        self.write(
            "upstream/SKILL.md",
            "---\nname: upstream\ndescription: A renamed skill\n---\n/upstream\n",
        )
        self.write(
            "upstream/agents/openai.yaml",
            "interface:\n  display_name: Keep this\npolicy:\n  allow_implicit_invocation: true\n",
        )
        self.catalog = {
            "sources": {"local": {"path": "sources"}},
            "skills": {
                "local": {"source": "local", "path": "local", "sharedDirectory": True},
                "workmux-example": {
                    "source": "local",
                    "path": "upstream",
                    "replacements": [
                        {"from": "name: upstream", "to": "name: workmux-example"},
                        {"from": "/upstream", "to": "/workmux-example"},
                    ],
                },
            },
            "profiles": {
                "common": ["local", {"name": "workmux-example", "manualOnly": True}],
                "work": [],
            },
        }
        self.declarations = {}

    def write(self, relative, contents):
        file = self.source / relative
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(contents)

    def prepare(self):
        module.prepare(
            self.catalog, "common", self.root, self.declarations, self.output
        )

    def snapshot(self):
        return {
            str(p.relative_to(self.output)): (
                os.readlink(p) if p.is_symlink() else p.read_bytes()
            )
            for p in self.output.rglob("*")
            if p.is_symlink() or p.is_file()
        }

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-c", "core.hooksPath=/dev/null", "-C", str(self.source), *args],
            env={"HOME": str(self.root), "PATH": os.environ["PATH"]},
            text=True,
        ).strip()

    def pin_source(self):
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.test",
            "commit",
            "--quiet",
            "-m",
            "fixture",
        )
        self.git("remote", "add", "origin", "https://example.test/skills")
        self.catalog["sources"]["local"] = {"repo": str(self.source)}
        self.declarations[str(self.source)] = {
            "url": "https://example.test/skills",
            "ref": self.git("rev-parse", "HEAD"),
        }

    def test_complete_directories_native_controls_and_live_local_sources(self):
        self.prepare()
        links = self.output / "links"
        self.assertEqual(
            (links / ".agents/skills/local").resolve(), self.source / "local"
        )
        self.assertEqual(
            (links / ".codex/skills/local/helpers/run.sh").read_text(),
            "#!/bin/sh\necho helper\n",
        )
        self.write("local/new.md", "live addition")
        self.assertEqual(
            (links / ".agents/skills/local/new.md").read_text(), "live addition"
        )
        codex = yaml.safe_load(
            (links / ".codex/skills/workmux-example/agents/openai.yaml").read_text()
        )
        self.assertEqual(codex["interface"]["display_name"], "Keep this")
        self.assertFalse(codex["policy"]["allow_implicit_invocation"])
        pi = (links / ".pi/agent/skills/workmux-example/SKILL.md").read_text()
        self.assertIn("disable-model-invocation: true", pi)
        self.assertIn("/skill:workmux-example", pi)
        self.assertNotIn("/skill:skill:", pi)
        self.assertEqual(
            json.loads((self.output / "claude-overrides.json").read_text()),
            {"workmux-example": "user-invocable-only"},
        )
        before = self.snapshot()
        self.prepare()
        self.assertEqual(self.snapshot(), before)
        self.assertIn(
            "allow_implicit_invocation: true",
            (self.source / "upstream/agents/openai.yaml").read_text(),
        )

    def test_missing_required_rewrite_preserves_published_output(self):
        self.prepare()
        before = self.snapshot()
        self.catalog["skills"]["workmux-example"]["replacements"][0][
            "from"
        ] = "missing text"
        with self.assertRaisesRegex(ValueError, "required rewrite"):
            self.prepare()
        self.assertEqual(self.snapshot(), before)

    def test_duplicate_selection_unknown_name_and_missing_source_fail(self):
        original = copy.deepcopy(self.catalog)
        for selection in ["local", "unknown"]:
            self.catalog = copy.deepcopy(original)
            self.catalog["profiles"]["common"].append(selection)
            with self.assertRaises(ValueError):
                self.prepare()
        self.catalog = original
        self.catalog["skills"]["local"]["path"] = "missing"
        with self.assertRaises(FileNotFoundError):
            self.prepare()
        self.assertFalse(self.output.exists())

    def test_invalid_yaml_duplicate_metadata_and_malformed_codex_policy_fail(self):
        original = (self.source / "local/SKILL.md").read_text()
        for text in [
            "no frontmatter",
            "---\nname: [invalid\n---\n",
            original.replace("name: local", "name: local\nname: local"),
        ]:
            self.write("local/SKILL.md", text)
            with self.assertRaises((ValueError, yaml.YAMLError)):
                self.prepare()
        self.write("local/SKILL.md", original)
        self.write("upstream/agents/openai.yaml", "policy: malformed\n")
        with self.assertRaisesRegex(ValueError, "malformed Codex"):
            self.prepare()

    def test_exact_pins_clean_checkouts_and_origins_are_required_offline(self):
        self.pin_source()
        self.git(
            "config", "url.ssh://git@example.test/.insteadOf", "https://example.test/"
        )
        self.assertEqual(
            self.git("remote", "get-url", "origin"), "ssh://git@example.test/skills"
        )
        self.prepare()
        before = self.snapshot()
        desired = self.declarations[str(self.source)]
        revision = desired["ref"]
        desired["ref"] = "0" * 40
        self.prepare()
        self.assertEqual(self.snapshot(), before)
        desired["url"] = "https://other.invalid/source"
        with self.assertRaisesRegex(ValueError, "origin differs"):
            self.prepare()
        desired["url"] = "https://example.test/skills"
        self.write("untracked", "local work")
        with self.assertRaisesRegex(ValueError, "dirty"):
            self.prepare()
        self.assertEqual(self.snapshot(), before)
        desired["ref"] = revision

    def test_empty_bootstrap_view_is_initialized_when_sources_are_pending(self):
        (self.output / "links").mkdir(parents=True)
        missing = str(self.root / "missing-repo")
        self.catalog["sources"]["missing"] = {"repo": missing}
        self.catalog["skills"]["missing"] = {"source": "missing", "path": "."}
        self.catalog["profiles"]["common"].append("missing")
        self.declarations[missing] = {
            "url": "https://example.test/missing",
            "ref": "0" * 40,
        }
        self.prepare()
        self.assertTrue((self.output / "claude-overrides.json").is_file())
        self.assertEqual(list((self.output / "links").iterdir()), [])
        before = self.snapshot()
        self.prepare()
        self.assertEqual(self.snapshot(), before)

    def test_invalid_available_metadata_fails_even_when_another_source_is_missing(self):
        self.prepare()
        before = self.snapshot()
        missing = str(self.root / "missing-repo")
        self.catalog["sources"]["missing"] = {"repo": missing}
        self.catalog["skills"]["missing"] = {"source": "missing", "path": "."}
        self.catalog["profiles"]["common"].append("missing")
        self.declarations[missing] = {
            "url": "https://example.test/missing",
            "ref": "0" * 40,
        }
        original = (self.source / "local/SKILL.md").read_text()
        self.write("local/SKILL.md", "invalid metadata")
        with self.assertRaisesRegex(ValueError, "frontmatter"):
            self.prepare()
        self.write("local/SKILL.md", original)
        self.write("upstream/agents/openai.yaml", "policy: malformed\n")
        with self.assertRaisesRegex(ValueError, "malformed Codex"):
            self.prepare()
        self.assertEqual(self.snapshot(), before)

    def test_symlinks_cannot_escape_sources_or_redirect_output(self):
        outside = self.root / "private"
        outside.write_text("credential canary")
        (self.source / "local/escape").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "symlink escapes"):
            self.prepare()
        (self.source / "local/escape").unlink()
        self.output.symlink_to(self.source, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "must not traverse"):
            self.prepare()
        self.assertEqual(outside.read_text(), "credential canary")

    @unittest.skipUnless(
        os.environ.get("MISE_TEST_BINARY"),
        "Set MISE_TEST_BINARY for native deployment/revocation",
    )
    def test_native_dotfiles_revoke_removed_skills_but_preserve_manual_neighbors(self):
        self.pin_source()
        home = self.root / "home"
        checkout = home / "skill-source"
        self.catalog["sources"]["local"] = {"repo": str(checkout)}
        catalog = self.root / "catalog.json"
        catalog.write_text(json.dumps(self.catalog))
        config = home / ".config/mise/config.toml"
        config.parent.mkdir(parents=True)
        config.write_text(
            '[settings]\nexperimental = true\n[settings.history]\nenabled = false\n[dotfiles]\n"~/.ordinary" = { content = "offline configuration" }\n[dotfile_groups.skills]\nroot = '
            + json.dumps(str(self.output / "links"))
            + '\ntarget = "~"\nmode = "symlink-each"\n[bootstrap.hooks.pre-dotfiles]\nrun = '
            + json.dumps(
                shlex.join(
                    [
                        sys.executable,
                        str(runtime / "mise/skills-prepare.py"),
                        "--catalog",
                        str(catalog),
                        "--root",
                        str(self.root),
                        "--config",
                        str(config),
                        "--profile",
                        "common",
                        "--output",
                        str(self.output),
                    ]
                )
            )
            + "\n[bootstrap.repos]\n"
            + json.dumps(str(checkout))
            + " = { url = "
            + json.dumps(self.source.as_uri())
            + ", ref = "
            + json.dumps(self.git("rev-parse", "HEAD"))
            + " }\n"
        )
        env = {
            "HOME": str(home),
            "PATH": os.environ["PATH"],
            "MISE_YES": "1",
            "PYTHONPATH": str(Path(yaml.__file__).parent.parent),
        }
        for name, directory in [
            ("MISE_CONFIG_DIR", config.parent),
            ("MISE_DATA_DIR", home / "data"),
            ("MISE_STATE_DIR", home / "state"),
            ("MISE_CACHE_DIR", home / "cache"),
            ("MISE_SYSTEM_CONFIG_DIR", home / "system"),
        ]:
            env[name] = str(directory)

        def apply(*targets):
            subprocess.run(
                [
                    os.environ["MISE_TEST_BINARY"],
                    "-C",
                    str(home),
                    "dot",
                    "apply",
                    *targets,
                ],
                env=env,
                check=True,
                capture_output=True,
            )

        apply()
        self.assertEqual((home / ".ordinary").read_text(), "offline configuration")
        self.assertTrue((self.output / "links").is_dir())
        self.assertEqual(
            json.loads((self.output / "claude-overrides.json").read_text()), {}
        )
        self.assertFalse((home / ".agents/skills/local").exists())
        subprocess.run(
            [
                os.environ["MISE_TEST_BINARY"],
                "-C",
                str(home),
                "bootstrap",
                "repos",
                "apply",
            ],
            env=env,
            check=True,
            capture_output=True,
        )
        apply()
        deployed = home / ".agents/skills/local/SKILL.md"
        previous = deployed.read_text()
        old_revision = self.git("rev-parse", "HEAD")
        self.write("local/SKILL.md", previous.replace("Local body", "Updated body"))
        self.git("add", ".")
        self.git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.test",
            "commit",
            "--quiet",
            "-m",
            "new skill revision",
        )
        config.write_text(
            config.read_text().replace(old_revision, self.git("rev-parse", "HEAD"))
        )
        apply()
        self.assertEqual(deployed.read_text(), previous)
        subprocess.run(
            [
                os.environ["MISE_TEST_BINARY"],
                "-C",
                str(home),
                "bootstrap",
                "repos",
                "apply",
            ],
            env=env,
            check=True,
            capture_output=True,
        )
        apply()
        self.assertIn("Updated body", deployed.read_text())
        manual = home / ".agents/skills/manual/SKILL.md"
        manual.parent.mkdir(parents=True)
        manual.write_text("manual skill")
        self.catalog["profiles"]["common"] = [self.catalog["profiles"]["common"][1]]
        catalog.write_text(json.dumps(self.catalog))
        (home / ".ordinary").write_text("manual configuration")
        apply("~")
        self.assertEqual((home / ".ordinary").read_text(), "manual configuration")
        self.assertFalse((home / ".agents/skills/local").is_symlink())
        self.assertEqual(manual.read_text(), "manual skill")
        self.assertTrue((home / ".codex/skills/workmux-example/SKILL.md").exists())


if __name__ == "__main__":
    unittest.main()
