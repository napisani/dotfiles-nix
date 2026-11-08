"""Read-only preflight checks, the dry rehearsal, and full verification.

Every check returns `{"name", "status", "detail"}` where status is `ok`,
`warn` (cosmetic or for the wrap-up list), `fail` (fix before rolling out) or
`info`. Checks never print secret values.
"""

import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path

from . import data
from .common import RolloutError, cask_token, current_platform, output, run, with_homebrew_ruby
from .plan import home_manager, make_plan

GIB = 1024 ** 3


def check(name, status, detail=""):
    return {"name": name, "status": status, "detail": detail}


def guarded(name, function):
    """Runs one check; an unexpected error becomes a failed check instead of a crash."""
    try:
        return function()
    except (RolloutError, OSError, ValueError, subprocess.SubprocessError) as error:
        return check(name, "fail", str(error)[-500:])


def minimum_mise(checkout):
    return tomllib.loads((checkout / "mise.toml").read_text())["min_version"]


def stage_mise(directory, version):
    """Installs the pinned official mise into a scratch directory, leaving the host's mise alone."""
    target = Path(directory) / "mise"
    if target.exists():
        return target
    installer = Path(directory) / "install.sh"
    run(["curl", "-fsSL", "https://mise.jdx.dev/install.sh", "-o", installer], timeout=120)
    run(["sh", installer], env={**os.environ, "MISE_VERSION": version, "MISE_INSTALL_PATH": str(target)},
        timeout=300)
    return target


def preflight(host, home, *, estimate):
    """The read-only checks for one host, run on that host."""
    home = Path(home)
    results = []
    results.append(guarded("platform", lambda: check(
        "platform", "ok" if current_platform() == host.platform else "fail",
        f"expected {host.platform}, found {current_platform()}")))

    def disk():
        free = shutil.disk_usage(home).free
        # APFS clones share blocks until either copy changes; copies need full space.
        needed = 20 * GIB + (0 if host.macos else estimate["bytes"])
        return check("disk", "ok" if free >= needed else "fail",
                     f"{free / GIB:.0f} GiB free; {needed / GIB:.0f} GiB needed for backup and system build")
    results.append(guarded("disk", disk))
    if estimate.get("blocked"):
        readable = check("protected-paths-readable", "fail", f"reading stopped at {estimate['blocked']}")
    elif estimate["unreadable"]:
        readable = check("protected-paths-readable", "fail",
                         "unreadable; grant Full Disk Access to the SSH server (sshd-keygen-wrapper): "
                         + ", ".join(estimate["unreadable"][:10]))
    else:
        readable = check("protected-paths-readable", "ok",
                         f"{estimate['files']} files, {estimate['bytes'] / GIB:.1f} GiB")
    results.append(readable)

    def repos():
        failures = []
        for path, spec in host.declarations()["repos"].items():
            result = run(["git", "ls-remote", spec["url"], spec["ref"]], check=False, timeout=60,
                         env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
            if result.returncode:
                failures.append(spec["url"])
        return check("repo-access", "fail" if failures else "ok",
                     ("cannot read: " + ", ".join(failures)) if failures else
                     f"{len(host.declarations()['repos'])} pinned repositories reachable")
    results.append(guarded("repo-access", repos))

    def github():
        if not shutil.which("gh"):
            return check("gh-auth", "warn", "gh not on PATH")
        result = run(["gh", "auth", "status"], check=False, timeout=30)
        return check("gh-auth", "ok" if result.returncode == 0 else "warn",
                     "logged in" if result.returncode == 0 else "gh is not authenticated")
    results.append(guarded("gh-auth", github))

    if host.decisions.get("agent_profile") == "work":
        def npm_token():
            if not shutil.which("secret_inject"):
                return check("work-npm-token", "warn", "secret_inject not on PATH")
            result = run(["secret_inject", "run", "--profile", "shell", "--", "sh", "-c",
                          'test -n "${NODE_AUTH_TOKEN-}"'], check=False, timeout=60)
            return check("work-npm-token", "ok" if result.returncode == 0 else "fail",
                         "NODE_AUTH_TOKEN resolves" if result.returncode == 0 else
                         "NODE_AUTH_TOKEN is missing from the shell profile; refresh the Doppler login")
        results.append(guarded("work-npm-token", npm_token))

    if host.macos:
        def xcode():
            present = Path("/Applications/Xcode.app").is_dir()
            selected = run(["xcode-select", "-p"], check=False).stdout.strip()
            return check("xcode", "ok" if present else "info",
                         f"Xcode.app {'present' if present else 'absent'}; developer dir {selected or 'unset'}")
        results.append(guarded("xcode", xcode))

    def home_manager_state():
        generation, files = home_manager(home)
        return check("home-manager", "info",
                     f"generation {generation.name} with {len(files)} links" if generation else "absent")
    results.append(guarded("home-manager", home_manager_state))

    def checkout():
        root = host.checkout.parents[1]
        if run(["git", "-C", root, "rev-parse", "--verify", "-q", "HEAD"], check=False).returncode:
            return check("checkout", "info", f"exported tree at {root}")
        head = output(["git", "-C", root, "rev-parse", "--short", "HEAD"])
        branch = output(["git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD"])
        dirty = output(["git", "-C", root, "status", "--porcelain", "--untracked-files=no"])
        return check("checkout", "warn" if dirty else "ok",
                     f"{branch} at {head}" + ("; tracked changes present" if dirty else ""))
    results.append(guarded("checkout", checkout))

    def standalone_mise():
        binary = home / ".local/bin/mise"
        if not binary.exists():
            return check("standalone-mise", "info", "absent; bootstrap installs it")
        version = output([binary, "--version"]).split()[0]
        return check("standalone-mise", "ok", version)
    results.append(guarded("standalone-mise", standalone_mise))
    results.append(guarded("sudo", lambda: check(
        "sudo", "info", "cached" if run(["sudo", "-n", "true"], check=False).returncode == 0
        else "needs the privileged console")))
    return results


def cask_dry_runs(host, mise, home):
    """Dry-runs each declared cask through mise against an empty temporary prefix."""
    results = []
    homebrew = set(run(["brew", "list", "--cask"], check=False).stdout.split()) if shutil.which("brew") else set()
    names = host.casks() + [name for name in host.declarations()["packages"] if name.startswith("brew:")]
    if not names:
        return results
    with tempfile.TemporaryDirectory(prefix="mise-rehearsal-") as scratch:
        config = Path(scratch) / "config"
        config.mkdir()
        links = {
            "config.toml": host.checkout / "mods/dotfiles/mise/config.toml",
            "mise.lock": host.checkout / "mods/dotfiles/mise/mise.lock",
            "config.local.toml": host.checkout / f"homes/{host.name}/mise.toml",
            "mise.local.lock": host.checkout / f"homes/{host.name}/mise.local.lock",
            "dotfiles": host.checkout / "mods/dotfiles",
        }
        for name, source in links.items():
            (config / name).symlink_to(source)
        env = {
            **os.environ, "PATH": with_homebrew_ruby(os.environ.get("PATH", "")), "MISE_CONFIG_DIR": str(config),
            "MISE_TRUSTED_CONFIG_PATHS": str(config), "MISE_YES": "1",
            "MISE_SYSTEM_PACKAGES_MANAGERS": "brew-cask,brew",
            "MISE_DATA_DIR": str(Path(scratch) / "data"), "MISE_STATE_DIR": str(Path(scratch) / "state"),
        }
        for name in names:
            with tempfile.TemporaryDirectory(prefix="mise-cask-prefix-") as prefix:
                started = time.time()
                result = run([mise, "-C", home, "bootstrap", "packages", "apply", "--dry-run", name],
                             check=False, timeout=600, env={**env, "MISE_SYSTEM_BREW_PREFIX": prefix})
                results.append({
                    "package": name, "exit": result.returncode, "seconds": round(time.time() - started),
                    "needs_approval": name.startswith("brew-cask:") and host.needs_approval(name),
                    "homebrew_copy": cask_token(name) in homebrew,
                    "detail": (result.stderr or result.stdout).strip()[-400:],
                })
    return results


def build_system(host, workdir):
    """Builds, never switches, the candidate system; this also downloads it."""
    flake = f"{host.checkout}#{host.flake_name}"
    command = (["darwin-rebuild", "build", "--flake", flake] if host.macos
               else ["nixos-rebuild", "build", "--flake", flake])
    started = time.time()
    result = run(command, check=False, cwd=workdir, timeout=7200)
    return {"command": shlex.join(command), "exit": result.returncode,
            "seconds": round(time.time() - started),
            "detail": (result.stderr or result.stdout).strip()[-800:]}


def lock_coverage(host):
    result = run([sys.executable, host.checkout / "scripts/check-mise-locks.py"], check=False)
    return check("lock-coverage", "ok" if result.returncode == 0 else "fail",
                 (result.stdout or result.stderr).strip()[-300:])


def estimate_minutes(host, estimate, *, build_seconds=900, cask_count=None):
    """A deliberately generous estimate of an unattended run."""
    casks = len(host.casks()) if cask_count is None else cask_count
    # APFS clones cost per file; copies cost per byte.
    backup = 5 + estimate["files"] / 10000 if host.macos else estimate["bytes"] / (80 * 1024 ** 2) / 60
    tools = len(host.declarations()["tools"]) * 0.5
    return round(20 + backup + build_seconds / 60 + tools + casks * 4 + 30)


def rehearse(host, home, mise, estimate):
    """The dry rehearsal: plan, cask dry-runs, system build, lock coverage and run time."""
    plan = make_plan(host, home)
    counts = {}
    for item in plan["actions"]:
        counts[item["action"]] = counts.get(item["action"], 0) + 1
    with tempfile.TemporaryDirectory(prefix="mise-build-") as workdir:
        build = build_system(host, workdir)
    casks = cask_dry_runs(host, mise, home) if host.macos else []
    return {
        "plan": counts, "plan_actions": plan["actions"],
        "casks": casks, "build": build, "lock_coverage": lock_coverage(host),
        "estimate_minutes": estimate_minutes(host, estimate, build_seconds=max(build["seconds"], 300)),
    }


def verify(host, home, mise):
    """Full verification on a migrated host; warnings are cosmetic, failures block acceptance."""
    home = Path(home)
    env = {**os.environ, "HOME": str(home)}
    results = []

    def command(name, argv, *, warn_only=False, **kwargs):
        result = run(argv, check=False, env=kwargs.pop("env", env), timeout=kwargs.pop("timeout", 600), **kwargs)
        status = "ok" if result.returncode == 0 else ("warn" if warn_only else "fail")
        results.append(check(name, status, (result.stdout + result.stderr).strip()[-600:]))
        return result

    command("dotfiles", [mise, "-C", home, "dot", "status", "--missing"])
    approvals = set(host.decisions.get("casks", {}).get("needs_approval", []))
    status = command("bootstrap", [mise, "-C", home, "bootstrap", "status", "--missing"],
                     warn_only=bool(approvals))
    if status.returncode and approvals:
        results[-1]["detail"] += "\n(approval casks may legitimately be pending; see the wrap-up list)"
    results.append(guarded("tools", lambda: tool_resolution(host, home, mise)))
    command("mise-doctor", [mise, "doctor"], warn_only=True)
    command("completion", ["bash", "-lic", "_completion_loader mise 2>/dev/null; complete -p mise"],
            warn_only=True)
    command("tmux", ["sh", "-c", "tmux -L mise-verify new-session -d true && tmux -L mise-verify kill-server; :"])
    command("editor-lsp", [mise, "-C", host.checkout, "run", "test:editor-lsp"], timeout=1800)
    command("python-provider", [mise, "-C", home, "exec", "--", "nvim", "--headless", "-u", "NONE", "-l",
                                host.checkout / "tests/nvim-runtime.lua", host.checkout / "mods/dotfiles/nvim"])
    if not host.macos:
        for binary in ["node", "python", "java", "nvim"]:
            command(f"nix-ld-{binary}", [mise, "-C", home, "exec", "--", binary, "--version"])
        command("gitops-sync-timer", ["systemctl", "is-active", "gitops-sync.timer"])
        command("gitops-sync-last-run", ["systemctl", "show", "gitops-sync.service",
                                         "-p", "Result", "-p", "ExecMainExitTimestamp"], warn_only=True)
    if host.macos:
        results.append(guarded("casks", lambda: casks_owned(host, home, mise)))
    results.append(guarded("skill-links", lambda: skill_links(home)))
    return results


TOOL_BINARIES = {
    "github:DopplerHQ/cli": "doppler", "github:openclaw/gogcli": "gog",
    "aqua:anthropics/claude-code": "claude", "aqua:openai/codex": "codex",
    "aqua:neovim/neovim": "nvim", "npm:@earendil-works/pi-coding-agent": "pi",
    "npm:@playwright/cli": "playwright-cli", "github:buildkite/cli": "bk",
    "github:conductorone/cone": "cone", "awscli": "aws", "npm:typescript": "tsc",
    "npm:vscode-langservers-extracted": "vscode-json-language-server",
    "npm:@tailwindcss/language-server": "tailwindcss-language-server",
    "npm:@vtsls/language-server": "vtsls", "ripgrep": "rg", "conda:coreutils": "ls",
}
# Libraries and adapters without an executable of their own.
NO_BINARY = {"conda:bash-completion", "github:microsoft/vscode-js-debug", "pipx:debugpy"}


def tool_resolution(host, home, mise):
    """Declared tools resolve through mise in a login shell and in `bash -c`."""
    expected = {}
    for name in host.declarations()["tools"]:
        if name in NO_BINARY:
            continue
        binary = TOOL_BINARIES.get(name, name.split(":")[-1].split("/")[-1])
        expected[binary] = Path(output([mise, "-C", home, "where", name])).resolve()
    data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    shims = data_home / "mise/shims"
    script = ("for b in " + shlex.join(expected) +
              "; do printf '%s\\t' \"$b\"; command -v \"$b\" || printf '\\n'; done")
    problems = []
    for flag, context in [("-lc", "login"), ("-c", "non-interactive")]:
        lines = run(["bash", flag, script], cwd=home, check=False).stdout.splitlines()
        resolved = dict(line.split("\t", 1) for line in lines if "\t" in line)
        for binary, root in expected.items():
            selected = resolved.get(binary, "")
            if not selected or not (Path(selected) == shims / binary or Path(selected).resolve().is_relative_to(root)):
                problems.append(f"{context}:{binary}={selected or 'missing'}")
    return check("tools", "fail" if problems else "ok",
                 ("outside mise: " + ", ".join(problems[:20])) if problems else f"{len(expected)} tools resolve")


def casks_owned(host, home, mise):
    status = json.loads(output([mise, "-C", home, "bootstrap", "packages", "status", "--json"],
                               env={**os.environ, "MISE_SYSTEM_PACKAGES_MANAGERS": "brew-cask"}))
    packages = {item["package"]: item for item in status.get("brew-cask", {}).get("packages", [])}
    exceptions = host.decisions.get("exceptions", {})
    missing = []
    for name in host.casks():
        token = name.split(":", 1)[1]
        item = packages.get(token) or packages.get(cask_token(name))
        if cask_token(name) in exceptions:
            continue
        if not item or item.get("state") != "installed" or item.get("managed_by") != "mise":
            missing.append(f"{cask_token(name)}={item.get('state') if item else 'absent'}")
    return check("casks", "fail" if missing else "ok",
                 ("not mise-owned: " + ", ".join(missing)) if missing else "every declared cask is mise-owned")


def skill_links(home):
    dangling = []
    for directory in [".claude/skills", ".codex/skills", ".pi/agent/skills", ".agents/skills"]:
        root = Path(home) / directory
        if root.is_dir():
            dangling += [str(path.relative_to(home)) for path in root.iterdir() if path.is_symlink() and not path.exists()]
    return check("skill-links", "fail" if dangling else "ok",
                 ("dangling: " + ", ".join(dangling[:20])) if dangling else "no dangling skill links")


def summary(results):
    worst = "ok"
    for result in results:
        if result["status"] == "fail":
            return "fail"
        if result["status"] == "warn":
            worst = "warn"
    return worst


def backup_estimate(host, home):
    return data.estimate(home, host)
