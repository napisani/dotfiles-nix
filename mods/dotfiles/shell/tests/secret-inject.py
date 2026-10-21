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
            "'{\"SECRET_INJECT_FIXTURE\":{\"computed\":\"synthetic fixture value\"}}'\n"
        )
        doppler.chmod(0o700)
        config_dir = home / ".config"
        config_dir.mkdir()
        # Keep real keyring credentials and caches outside the fixture process.
        config["storage"] = {"type": "file"}
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

        environment["SECRET_INJECT_PROFILE"] = "shell"
        environment["SECRET_INJECT_FIXTURE"] = "existing fixture value"
        exported = run(
            ["/bin/bash", "--noprofile", "--norc", "-c",
             '. "$1"; test "$RESULT" -eq 0 || exit 1; '
             'printf "%s" "$SECRET_INJECT_FIXTURE"', "fixture", str(hook)],
            environment,
        )
        assert exported.stdout == fixture_value
        assert exported.stderr == ""
        assert (home / "provider-called").read_text() == "called"

        checked = run(
            [str(binary), "profile", "check", "--profile", "shell"], environment,
        )
        assert json.loads(checked.stdout) == {
            "profile": "shell", "missing_includes": [],
        }
        print(f"PASS: {name} config, explicit profile, startup export, profile check")
