"""Host files that include roles resolve to the declarations they replaced.

`fixtures/pre-role-hosts/` holds each host file as it was before shared setup
moved into `mods/dotfiles/mise/roles/`. Update a fixture together with its host
file when a host's declarations change on purpose.
"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

PROJECT = Path(__file__).resolve().parents[1]
FIXTURES = Path(__file__).resolve().parent / "fixtures/pre-role-hosts"
MISE = os.environ.get("MISE_TEST_BINARY")
HOSTS = ["maclab", "nicks-mbp", "nicks-loancrate-mbp", "supermicro"]


def resolved(host_file, host):
    """What native mise reports for a core config plus one host file, offline."""
    with tempfile.TemporaryDirectory(prefix="host-roles-") as directory:
        home = Path(directory).resolve() / "home"
        config = home / ".config/mise"
        config.mkdir(parents=True)
        links = {
            "config.toml": PROJECT / "mods/dotfiles/mise/config.toml",
            "mise.lock": PROJECT / "mods/dotfiles/mise/mise.lock",
            "config.local.toml": host_file,
            "mise.local.lock": PROJECT / "homes" / host / "mise.local.lock",
            "dotfiles": PROJECT / "mods/dotfiles",
        }
        for name, source in links.items():
            (config / name).symlink_to(source)
        env = {
            key: value for key, value in os.environ.items()
            if not key.startswith("MISE_") or key == "MISE_TEST_BINARY"
        }
        env.update({
            "HOME": str(home),
            "MISE_DATA_DIR": str(home / ".local/share/mise"),
            "MISE_STATE_DIR": str(home / ".local/state/mise"),
            "MISE_CACHE_DIR": str(home / ".cache/mise"),
            "MISE_SYSTEM_CONFIG_DIR": str(home / "system"),
            "MISE_TRUSTED_CONFIG_PATHS": str(config),
            "MISE_SYSTEM_PACKAGES_MANAGERS": "none",
            "MISE_YES": "1",
            "NO_COLOR": "1",
        })

        def run(*args):
            result = subprocess.run([MISE, "-C", str(home), *args], env=env,
                                    capture_output=True, text=True, timeout=60)
            if result.returncode:
                raise AssertionError(f"mise {' '.join(args)} failed:\n{result.stderr}")
            return result.stdout.replace(str(home), "~")

        status = json.loads(run("bootstrap", "status", "--json"))
        hooks = run("bootstrap", "--dry-run", "--only", "macos-defaults,macos-launchd-agents")
        environment = json.loads(run("env", "--json"))
        environment.pop("PATH", None)
        return {
            "packages": {
                manager: sorted((p["package"], p["requested_version"]) for p in entry["packages"])
                for manager, entry in status["packages"].items()
            },
            "launchd": sorted((a["name"], a["label"]) for a in status["launchd"]["agents"]),
            "tools": sorted((t["tool"], t["requested_version"]) for t in status["tools"]),
            "repos": sorted(r["path_raw"] for r in status["repos"]),
            "hooks": hooks,
            "env": environment,
        }


def merge(base, layer):
    for key, value in layer.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value
    return base


def declared(host_file):
    """Host tables after merging its roles, for fields native status omits."""
    host = tomllib.loads(host_file.read_text())
    merged = {}
    for role in host.pop("include", []):
        merge(merged, tomllib.loads((PROJECT / "mods" / role).read_text()))
    # Roles cannot declare dotfiles, so the fixtures omit them.
    host.pop("dotfiles", None)
    return merge(merged, host)


class HostRoleDeclarationTests(unittest.TestCase):
    def test_roles_preserve_each_host_table(self):
        for host in HOSTS:
            with self.subTest(host=host):
                self.assertEqual(
                    declared(PROJECT / "homes" / host / "mise.toml"),
                    declared(FIXTURES / f"{host}.toml"),
                )

    def test_roles_declare_no_dotfiles(self):
        for role in (PROJECT / "mods/dotfiles/mise/roles").glob("*.toml"):
            self.assertNotIn("dotfiles", tomllib.loads(role.read_text()), role.name)


@unittest.skipUnless(MISE, "MISE_TEST_BINARY selects the native mise under test")
class HostRoleTests(unittest.TestCase):
    def test_roles_preserve_each_host_declarations(self):
        for host in HOSTS:
            with self.subTest(host=host):
                self.assertEqual(
                    resolved(PROJECT / "homes" / host / "mise.toml", host),
                    resolved(FIXTURES / f"{host}.toml", host),
                )


if __name__ == "__main__":
    unittest.main()
