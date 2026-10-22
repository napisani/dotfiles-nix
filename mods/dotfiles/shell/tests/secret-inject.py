#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


binary = Path(sys.argv[1]).resolve(strict=True)
shell_dir = Path(__file__).resolve().parents[1]
hook = shell_dir / "bash/rc.d/40-secret-inject.sh"
fixture_value = "synthetic fixture value"

for name in ("loancrate", "personal"):
    config_path = shell_dir.parent / f"{name}_secret_inject.json"
    config = json.loads(config_path.read_text())
    assert config["profiles"]["shell"] == {"exclude": [], "overwrite": True}
    assert set(config["sources"]) == {"doppler"}
    assert config["profiles"]["project-only"]["remote_sources"] is False
    assert config["profiles"]["project"]["remote_sources"] is True
    for profile in ("project-only", "project"):
        assert config["profiles"][profile]["env_files"] == ["*.env", "*.env.local"]

    with tempfile.TemporaryDirectory(prefix="secret-inject-shell-") as temporary:
        home = Path(temporary)
        bin_dir = home / "bin"
        bin_dir.mkdir()
        (bin_dir / "secret_inject").symlink_to(binary)
        doppler = bin_dir / "doppler"
        doppler.write_text(
            "#!/bin/sh\n"
            'printf called > "$HOME/provider-called"\n'
            "printf '%s\\n' "
            "'{\"SECRET_INJECT_FIXTURE\":{\"computed\":\"synthetic fixture value\"},"
            "\"REMOTE_ONLY\":{\"computed\":\"remote fixture\"}}'\n"
        )
        doppler.chmod(0o700)
        config_dir = home / ".config"
        config_dir.mkdir()
        # Keep real keyring credentials and caches outside the fixture process.
        config["storage"] = {"type": "file"}
        config["profiles"]["fixture override"] = {"include": []}
        (config_dir / ".secret_inject.json").write_text(json.dumps(config))
        environment = {
            "HOME": str(home),
            "PATH": f"{bin_dir}{os.pathsep}{os.defpath}",
            "TMPDIR": str(home),
            "XDG_CONFIG_HOME": str(config_dir),
            "XDG_CACHE_HOME": str(home / "cache"),
            "BASH_ENV": "/dev/null",
        }

        def run(arguments, env):
            result = subprocess.run(
                arguments, env=env, cwd=home, capture_output=True, text=True,
                timeout=15,
            )
            assert result.returncode == 0, result.stderr
            return result

        missing = subprocess.run(
            [str(binary)], env=environment, cwd=home,
            capture_output=True, text=True, timeout=15,
        )
        assert missing.returncode == 1
        assert "--profile is required" in missing.stderr
        assert not (home / "provider-called").exists()

        (home / ".env").write_text("SECRET_INJECT_FIXTURE=base\nLOCAL_ONLY=local\n")
        (home / ".env.local").write_text("SECRET_INJECT_FIXTURE=local override\n")
        local = run([str(binary), "--profile", "project-only", "--output", "json"], environment)
        assert json.loads(local.stdout) == {
            "SECRET_INJECT_FIXTURE": "local override", "LOCAL_ONLY": "local",
        }
        assert not (home / "provider-called").exists()
        combined = run([str(binary), "--profile", "project", "--output", "json"], environment)
        assert json.loads(combined.stdout) == {
            "SECRET_INJECT_FIXTURE": "local override", "LOCAL_ONLY": "local",
            "REMOTE_ONLY": "remote fixture",
        }
        print(f"PASS: {name}: project-only skips providers; project overlays local files")

        for case, variables, expected in (
            ("unset profile", {}, fixture_value),
            ("empty profile", {"SECRET_INJECT_PROFILE": ""}, fixture_value),
            ("inherited session guard", {"__HM_SESS_VARS_SOURCED": "1"}, fixture_value),
            ("explicit shell", {"SECRET_INJECT_PROFILE": "shell"}, fixture_value),
            ("explicit override", {"SECRET_INJECT_PROFILE": "fixture override"},
             "existing fixture value"),
        ):
            startup_environment = {
                **environment,
                "SECRET_INJECT_FIXTURE": "existing fixture value",
                **variables,
            }
            exported = run(
                ["/bin/bash", "--noprofile", "--norc", "-c",
                 '. "$1"; test "$RESULT" -eq 0 || exit 1; '
                 'printf "%s" "$SECRET_INJECT_FIXTURE"', "fixture", str(hook)],
                startup_environment,
            )
            assert exported.stdout == expected, case
            assert exported.stderr == "", case
            assert (home / "provider-called").read_text() == "called"
            print(f"PASS: {name}: {case}")

        checked = run(
            [str(binary), "profile", "check", "--profile", "shell"], environment,
        )
        assert json.loads(checked.stdout) == {
            "profile": "shell", "missing_includes": [],
        }
        print(f"PASS: {name} config, explicit profile, startup export, profile check")
