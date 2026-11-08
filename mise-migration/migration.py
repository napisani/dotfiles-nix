#!/usr/bin/env python3
"""Fleet rollout harness: preflight, privileged console, rollout and verification.

Run on the target host unless noted. See README.md for the runbook.
"""

import argparse
import json
import os
import shlex
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from rollout import checks, console, data, steps  # noqa: E402
from rollout.common import DOTFILES, PLATFORMS, RolloutError, load_host, monorepo_root, run, write_json  # noqa: E402


def emit(value, args):
    text = json.dumps(value, indent=2, sort_keys=True)
    if getattr(args, "json", None):
        Path(args.json).write_text(text + "\n")
    print(text)


def command_preflight(args):
    host = load_host(args.host, args.checkout)
    home = Path(args.home)
    estimate = data.estimate(home, host, timeout=args.estimate_timeout)
    result = {"host": host.name, "time": datetime.now(timezone.utc).isoformat(),
              "checks": checks.preflight(host, home, estimate=estimate),
              "backup_estimate": {k: v for k, v in estimate.items() if k != "unreadable"}}
    minutes = checks.estimate_minutes(host, estimate)
    if args.rehearse:
        with tempfile.TemporaryDirectory(prefix="mise-staged-") as staged:
            mise = checks.stage_mise(staged, checks.minimum_mise(host.checkout))
            rehearsal = checks.rehearse(host, home, mise, estimate)
        result["rehearsal"] = rehearsal
        minutes = rehearsal["estimate_minutes"]
        result["checks"].append(rehearsal["lock_coverage"])
        if rehearsal["build"]["exit"]:
            result["checks"].append(checks.check("system-build", "fail", rehearsal["build"]["detail"]))
        # Only a cask with a Homebrew copy is dry-run before its uninstall; approval casks may fail.
        failed_casks = [c for c in rehearsal["casks"]
                        if c["exit"] and c.get("homebrew_copy", True) and not c["needs_approval"]]
        result["checks"].append(checks.check(
            "cask-dry-runs", "fail" if failed_casks else "ok",
            ", ".join(f"{c['package']}: {c['detail'][-200:]}" for c in failed_casks) or
            f"{len(rehearsal['casks'])} packages dry-run"))
    result["estimate_minutes"] = minutes
    if args.console:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        run_dir = Path(args.run_dir) if args.run_dir else home / "migration_bk" / f"{stamp}-{host.name}-rollout"
        result["console"] = console.create(run_dir, host, minutes, args.ssh_alias or host.name)
    result["summary"] = checks.summary(result["checks"])
    emit(result, args)
    return 0 if result["summary"] != "fail" else 2


def context(args):
    host = load_host(args.host, args.checkout)
    return steps.Context(host, args.run_dir, args.home, brew=args.brew, require_console=not args.no_console)


def command_rollout(args):
    return steps.rollout(context(args))


def command_status(args):
    run_dir = Path(args.run_dir)
    exit_file = run_dir / "rollout.exit"
    emit({"steps": steps.status(run_dir), "privileges": console.privileges(run_dir),
          "rollout_exit": exit_file.read_text().strip() if exit_file.exists() else None}, args)
    return 0


def command_send(args):
    console.send(args.run_dir, shlex.join(args.text) if len(args.text) > 1 else args.text[0])
    return 0


def command_close(args):
    emit(console.close(args.run_dir), args)
    return 0


def command_verify(args):
    host = load_host(args.host, args.checkout)
    results = checks.verify(host, Path(args.home), Path(args.home) / ".local/bin/mise")
    emit({"checks": results, "summary": checks.summary(results)}, args)
    return 0 if checks.summary(results) != "fail" else 2


def command_restore(args):
    emit(data.compare_and_restore(args.run_dir, args.home, apply=args.apply), args)
    return 0


def ssh_command(alias, *extra):
    return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15", *extra, alias]


def command_reach(args):
    """Run on the controller: non-interactive SSH to the host's alias."""
    started = time.time()
    result = run([*ssh_command(args.alias or args.host), "hostname"], check=False, timeout=60)
    emit({"host": args.host, "alias": args.alias or args.host, "exit": result.returncode,
          "hostname": result.stdout.strip(), "seconds": round(time.time() - started, 1),
          "detail": result.stderr.strip()[-300:]}, args)
    return result.returncode


def command_remote_preflight(args):
    """Run on the controller: export this commit to the host and run its preflight there."""
    alias = args.alias or args.host
    root = monorepo_root(DOTFILES)
    commit = run(["git", "-C", root, "rev-parse", "HEAD"]).stdout.strip()
    remote_dir = f"/tmp/mise-preflight-{args.host}-{commit[:12]}"
    archive = subprocess.Popen(["git", "-C", str(root), "archive", commit], stdout=subprocess.PIPE)
    # Relative flake path inputs resolve only inside a Git work tree.
    unpack = subprocess.run([*ssh_command(alias), f"rm -rf {remote_dir} && mkdir -p {remote_dir} && "
                             f"tar -xf - -C {remote_dir} && git -C {remote_dir} init -q && git -C {remote_dir} add -A"],
                            stdin=archive.stdout, capture_output=True, text=True)
    archive.wait()
    if archive.returncode or unpack.returncode:
        raise RolloutError(f"could not copy the checkout to {alias}: {unpack.stderr.strip()[-300:]}")
    flags = ["--rehearse"] if args.rehearse else []
    remote = (f"cd {remote_dir} && bash pub/dotfiles-nix/mise-migration/run preflight --host {args.host} "
              f"--checkout {remote_dir}/pub/dotfiles-nix {' '.join(flags)}")
    # A login shell gives the host's normal PATH, which non-interactive SSH lacks on Nix hosts.
    result = subprocess.run([*ssh_command(alias), f"bash -lc {shlex.quote(remote)}"], capture_output=True, text=True)
    if args.json:
        Path(args.json).write_text(result.stdout)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr[-2000:])
    if not args.keep:
        subprocess.run([*ssh_command(alias), f"rm -rf {remote_dir}"], capture_output=True)
    return result.returncode


def parser():
    top = argparse.ArgumentParser(description=__doc__)
    commands = top.add_subparsers(dest="command", required=True)

    def add(name, function, help_text):
        sub = commands.add_parser(name, help=help_text)
        sub.set_defaults(function=function)
        sub.add_argument("--json", help="also write the JSON result to this file")
        return sub

    def host_args(sub, required=True):
        sub.add_argument("--host", choices=sorted(PLATFORMS), required=required)
        sub.add_argument("--checkout", type=Path, default=DOTFILES, help="dotfiles project to use")
        sub.add_argument("--home", type=Path, default=Path.home())

    sub = add("preflight", command_preflight, "read-only checks; --rehearse adds the dry rehearsal")
    host_args(sub)
    sub.add_argument("--rehearse", action="store_true")
    sub.add_argument("--console", action="store_true", help="create the run directory and privileged console")
    sub.add_argument("--run-dir", type=Path)
    sub.add_argument("--ssh-alias", help="the controller's ~/.ssh/config alias for this host")
    sub.add_argument("--estimate-timeout", type=int, default=900,
                     help="seconds before a blocked read of protected data is reported")
    sub = add("rollout", command_rollout, "run or resume the migration inside the console")
    host_args(sub)
    sub.add_argument("--run-dir", type=Path, required=True)
    sub.add_argument("--brew", default="brew")
    sub.add_argument("--no-console", action="store_true", help=argparse.SUPPRESS)
    sub = add("status", command_status, "step states and privileged-session time left")
    sub.add_argument("--run-dir", type=Path, required=True)
    sub = add("send", command_send, "type one command line into the console")
    sub.add_argument("--run-dir", type=Path, required=True)
    sub.add_argument("text", nargs="+")
    sub = add("close", command_close, "end the privileged session")
    sub.add_argument("--run-dir", type=Path, required=True)
    sub = add("verify", command_verify, "full verification of a migrated host")
    host_args(sub)
    sub = add("restore", command_restore, "compare with the backup; --apply restores missing or emptied files")
    sub.add_argument("--run-dir", type=Path, required=True)
    sub.add_argument("--home", type=Path, default=Path.home())
    sub.add_argument("--apply", action="store_true")
    sub = add("reach", command_reach, "controller: non-interactive SSH to a host")
    sub.add_argument("--host", choices=sorted(PLATFORMS), required=True)
    sub.add_argument("--alias")
    sub = add("remote-preflight", command_remote_preflight, "controller: export this commit and preflight a host")
    sub.add_argument("--host", choices=sorted(PLATFORMS), required=True)
    sub.add_argument("--alias")
    sub.add_argument("--rehearse", action="store_true")
    sub.add_argument("--keep", action="store_true", help="keep the exported tree on the host")
    return top


def main():
    os.umask(0o077)
    args = parser().parse_args()
    for name in ("home", "run_dir", "checkout"):
        if getattr(args, name, None):
            setattr(args, name, Path(getattr(args, name)).expanduser().resolve())
    return args.function(args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RolloutError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"migration: {error}", file=sys.stderr)
        sys.exit(1)
