"""`rollout`: one resumable command that migrates a host inside its console.

Each step writes `steps/<n>-<name>.log`, `.json` and `.exit`; a step with an
exit file of 0 is skipped when the command runs again, so a dropped connection
or a fix-and-rerun resumes where the run stopped. A required step that fails
stops the run with the privileged session still open; best-effort steps record
what failed in the wrap-up list and continue.
"""

import json
import os
import re
import shutil
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path

from . import checks, console, data
from .common import (
    RolloutError, allowlisted_link, cask_token, output, read_json, run, with_homebrew_ruby, write_json,
)
from .plan import RETIRED_LINKS, apply_plan, home_manager, make_plan

# Homebrew packages that mise replaces, and the mise tool that must exist first.
SUPERSEDED_FORMULAE = {
    "workmux": "github:raine/workmux", "gogcli": "github:openclaw/gogcli", "helm": "helm",
    "awscli": "awscli", "pulumi": "pulumi", "actionlint": "actionlint", "coder": "coder",
    "bk@3": "github:buildkite/cli", "cone": "github:conductorone/cone", "nvm": "node",
    "opencode": None,
}
SUPERSEDED_CASKS = {"claude-code": "aqua:anthropics/claude-code", "codex": "aqua:openai/codex"}
# Store-path RTK hooks from the Nix-era integration; rtk:setup refuses to run beside them.
NIX_RTK = re.compile(r"/nix/store/[^\"\s]*/rtk(?:\s|\\|$)")


class Context:
    """What every step needs: the host, run directory, HOME and tool paths."""

    def __init__(self, host, run_dir, home, *, brew="brew", require_console=True):
        self.host, self.run_dir, self.home = host, Path(run_dir), Path(home)
        self.brew = brew
        self.require_console = require_console
        self.state = read_json(self.run_dir / "state.json", {})

    @property
    def mise(self):
        installed = self.home / ".local/bin/mise"
        staged = self.run_dir / "bin/mise"
        return installed if installed.exists() else staged

    def env(self):
        """The console's PATH plus the paths that exist after the switch, with standalone mise first."""
        # System tools come first: mise's cask steps call BSD-only flags (`ln -h`) by name, and a
        # migrated shell's PATH puts GNU coreutils ahead of them.
        directories = [str(self.home / ".local/bin"), "/usr/bin", "/bin", "/usr/sbin", "/sbin",
                       *os.environ.get("PATH", "").split(":"),
                       "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin",
                       "/opt/homebrew/bin", "/usr/local/bin"]
        path = ":".join(dict.fromkeys(d for d in directories if d))
        return {
            **os.environ, "HOME": str(self.home), "PATH": with_homebrew_ruby(path), "HOMEBREW_NO_AUTOREMOVE": "1",
            # The attended Homebrew startup guard must honor this opt-in; see WORKAROUNDS.md.
            # Resetting the console's cached credentials stalls privileged cask installers.
            "HOMEBREW_SUDO_CHECKED": "1",
        }

    def wrapup(self, item, instructions):
        record = self.run_dir / "wrapup.json"
        items = read_json(record, [])
        if not any(existing["item"] == item for existing in items):
            items.append({"item": item, "instructions": instructions})
            write_json(record, items)

    def save_state(self, **values):
        self.state.update(values)
        write_json(self.run_dir / "state.json", self.state)


def step_console(ctx):
    if ctx.host.checkout.resolve() != ctx.host.live_checkout.resolve():
        raise RolloutError(f"run the rollout from the host's own checkout, {ctx.host.live_checkout}")
    if not ctx.require_console:
        return {"console": "not required"}
    state = console.privileges(ctx.run_dir)
    needed = max(30, ctx.state.get("estimate_minutes", 120) // 2) * 60
    if not state["live"]:
        raise RolloutError("the privileged session is not live; run start-privileged-session.sh in the console")
    if state["remaining"] < needed:
        raise RolloutError(f"keepalive has {state['remaining'] // 60} min left; restart the session for a longer window")
    return state


def step_preflight(ctx):
    estimate = data.estimate(ctx.home, ctx.host)
    results = checks.preflight(ctx.host, ctx.home, estimate=estimate)
    failed = [result for result in results if result["status"] == "fail"]
    if failed:
        raise RolloutError("preflight failed: " + "; ".join(f"{r['name']}: {r['detail']}" for r in failed))
    return {"checks": results, "estimate": {k: v for k, v in estimate.items() if k != "unreadable"}}


def step_plan(ctx):
    generation, _ = home_manager(ctx.home)
    local = ctx.home / ".config/mise/config.local.toml"
    catch_up = generation is None and local.is_symlink() and \
        Path(os.readlink(local)) == ctx.host.checkout / f"homes/{ctx.host.name}/mise.toml"
    plan = make_plan(ctx.host, ctx.home)
    write_json(ctx.run_dir / "plan.json", plan)
    root = ctx.host.checkout.parents[1]
    commit = output(["git", "-C", root, "rev-parse", "HEAD"], check=False) if (root / ".git").exists() else ""
    ctx.save_state(mode="catch-up" if catch_up else "migrate", start_commit=commit,
                   system_before=os.path.realpath("/run/current-system"))
    if not (ctx.home / ".local/bin/mise").exists():
        checks.stage_mise(ctx.run_dir / "bin", checks.minimum_mise(ctx.host.checkout))
    return {"mode": ctx.state["mode"], "actions": len(plan["actions"])}


def step_backup(ctx):
    saved = data.backup(ctx.run_dir, ctx.home, ctx.host)
    result = {"entries": len(saved["entries"]), "method": saved["method"], "skipped": saved.get("skipped", {})}
    if result["skipped"]:
        ctx.wrapup("Files not backed up", f"{len(result['skipped'])} system-protected files could not be cloned "
                   "and were left untouched in place; see steps/04-backup.json.")
    if ctx.host.macos:
        result["local_snapshot"] = data.local_snapshot()
    else:
        result["nightly_backup"] = data.nightly_backup()
        if not result["nightly_backup"]["present"]:
            ctx.wrapup("Nightly home backup", "The nightly rsync was not found; confirm it before accepting the host.")
    return result


def step_files(ctx):
    plan = read_json(ctx.run_dir / "plan.json")
    results = apply_plan(plan, ctx.run_dir, ctx.home, ctx.host.live_checkout)
    return {"applied": [r for r in results if r["outcome"] != "absent"]}


def step_switch(ctx):
    pinned = read_json(ctx.run_dir / "toolchain.json", {})
    rebuild = "darwin-rebuild" if ctx.host.macos else "nixos-rebuild"
    command = pinned.get(rebuild) or shutil.which(rebuild, path=ctx.env()["PATH"]) or rebuild
    run(["sudo", "-n", "true"], env=ctx.env())
    flake = f"{ctx.host.checkout}#{ctx.host.flake_name}"
    try:
        if not ctx.host.macos:
            run(["sudo", "-n", "systemctl", "stop", "gitops-sync.timer"], env=ctx.env())
            active = run(["systemctl", "show", "gitops-sync.service", "--property=ActiveState", "--value"],
                         env=ctx.env()).stdout.strip()
            if active not in ("inactive", "failed"):
                raise RolloutError(f"gitops-sync.service is {active}; wait for it to finish before switching")
        run(["sudo", "-n", "-H", command, "switch", "--flake", flake], env=ctx.env(), capture=False, timeout=7200)
    finally:
        if not ctx.host.macos:
            run(["sudo", "-n", "systemctl", "start", "gitops-sync.timer"], env=ctx.env())
    after = os.path.realpath("/run/current-system")
    ctx.save_state(system_after=after)
    return {"system": after}


def step_bootstrap(ctx):
    env = ctx.env()
    # Apps such as Karabiner recreate their config once its old link is gone.
    late = [item for item in make_plan(ctx.host, ctx.home)["actions"] if item["action"] == "move-aside"]
    moved = apply_plan({"actions": late}, ctx.run_dir / "pre-bootstrap", ctx.home, ctx.host.live_checkout)
    for item in moved:
        if item["outcome"] == "moved":
            ctx.wrapup(f"Moved {item['path']}", "Recreated by an app before bootstrap; the copy is under "
                       f"{ctx.run_dir / 'pre-bootstrap/moved' / item['path']}.")
    run(["/bin/sh", ctx.host.checkout / "bootstrap.sh", ctx.host.name], env=env, cwd=ctx.home,
        capture=False, timeout=7200)
    mise = ctx.home / ".local/bin/mise"
    run([mise, "-C", ctx.home, "run", "skills:sync"], env=env, capture=False, timeout=3600)
    return {"mise": output([mise, "--version"], env=env)}


def retire_nix_rtk_hooks(ctx):
    """Removes store-path RTK hook handlers, keeping a copy of each changed file."""
    retired = []
    for relative in [".claude/settings.json", ".codex/hooks.json"]:
        path = ctx.home / relative
        if not path.is_file() or not NIX_RTK.search(path.read_text()):
            continue
        settings = json.loads(path.read_text())
        hooks = settings.get("hooks", {})
        for event, groups in list(hooks.items()):
            kept = []
            for group in groups:
                handlers = [h for h in group.get("hooks", []) if not NIX_RTK.search(json.dumps(h))]
                if handlers or not group.get("hooks"):
                    kept.append({**group, "hooks": handlers})
            hooks[event] = kept
        copy = ctx.run_dir / "rtk-retired" / relative
        copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, copy)
        path.write_text(json.dumps(settings, indent=2) + "\n")
        retired.append(relative)
    return retired


def step_rtk(ctx):
    retired = retire_nix_rtk_hooks(ctx)
    result = run([ctx.home / ".local/bin/mise", "-C", ctx.home, "run", "rtk:setup"], env=ctx.env(),
                 check=False, timeout=600)
    if result.returncode:
        ctx.wrapup("RTK setup", "Run `mise -C ~ run rtk:setup` after reviewing: "
                   + (result.stderr or result.stdout).strip()[-300:])
    return {"retired_hooks": retired, "setup_exit": result.returncode}


def launchd(domain, label, action, plist=None, env=None):
    prefix = ["sudo", "-n"] if domain == "system" else []
    target = f"{domain}/{label}"
    if action == "print":
        return run([*prefix, "launchctl", "print", target], check=False, env=env)
    if action == "stop":
        return run([*prefix, "launchctl", "bootout", target], check=False, env=env)
    return run([*prefix, "launchctl", "bootstrap", domain, plist], check=False, env=env)


def quiesce(ctx):
    """Stops services that hold protected files open, recording how to restart them."""
    record = ctx.run_dir / "services.json"
    if record.exists():
        return read_json(record)
    stopped = []
    gui = f"gui/{os.getuid()}"
    for spec in ctx.host.decisions.get("services", {}).get("quiesce", []):
        domain = gui if spec["domain"] == "gui" else spec["domain"]
        printed = launchd(domain, spec["label"], "print", env=ctx.env())
        if printed.returncode:
            continue
        paths = [line.strip()[len("path = "):] for line in printed.stdout.splitlines()
                 if line.strip().startswith("path = ")]
        stopped.append({"domain": domain, "label": spec["label"], "plist": paths[0] if paths else spec.get("plist")})
        launchd(domain, spec["label"], "stop", env=ctx.env())
    apps = []
    for app in ctx.host.decisions.get("services", {}).get("quit_apps", []):
        if run(["pgrep", "-xq", app], check=False).returncode == 0:
            run(["osascript", "-e", f'quit app "{app}"'], check=False, env=ctx.env())
            apps.append(app)
    result = {"stopped": stopped, "apps": apps}
    write_json(record, result)
    return result


def resume_services(ctx):
    record = read_json(ctx.run_dir / "services.json", {"stopped": [], "apps": []})
    failed = []
    for item in record["stopped"]:
        if launchd(item["domain"], item["label"], "print", env=ctx.env()).returncode == 0:
            continue
        if not item.get("plist") or launchd(item["domain"], item["label"], "start", item["plist"], ctx.env()).returncode:
            failed.append(item["label"])
    for app in record["apps"]:
        run(["open", "-g", "-a", app], check=False, env=ctx.env())
    if failed:
        ctx.wrapup("Services to restart", "Restart these launchd services: " + ", ".join(failed))
    return {"restart_failed": failed}


def native_casks(ctx):
    status = json.loads(output([ctx.mise, "-C", ctx.home, "bootstrap", "packages", "status", "--json"],
                               env={**ctx.env(), "MISE_SYSTEM_PACKAGES_MANAGERS": "brew-cask,brew"}))
    return {item["package"]: item for item in status.get("brew-cask", {}).get("packages", [])}


APPROVAL = (
    "Open {app} once on the host, approve its system extension or privacy prompt in "
    "System Settings > Privacy & Security, then run `mise -C ~ bootstrap packages apply {name}`."
)


def transfer_cask(ctx, name, native, homebrew):
    token = cask_token(name)
    item = native.get(name.split(":", 1)[1]) or native.get(token)
    if item and item.get("state") == "installed" and item.get("managed_by") == "mise":
        return "already mise-owned"
    env = ctx.env()
    if token in homebrew:
        with_prefix = ctx.run_dir / "cask-prefix" / token
        with_prefix.mkdir(parents=True, exist_ok=True)
        dry = run([ctx.mise, "-C", ctx.home, "bootstrap", "packages", "apply", "--dry-run", name], check=False,
                  env={**env, "MISE_SYSTEM_BREW_PREFIX": str(with_prefix)}, timeout=600)
        if dry.returncode:
            raise RolloutError(f"dry-run failed; Homebrew copy kept: {(dry.stderr or dry.stdout).strip()[-300:]}")
        run([ctx.brew, "uninstall", "--cask", homebrew[token]], env=env, timeout=1800)
    apply = [ctx.mise, "-C", ctx.home, "bootstrap", "packages", "apply", name]
    failure = None
    for _ in range(2):
        result = run(apply, env=env, timeout=3600, check=False)
        if result.returncode == 0:
            return "transferred" if token in homebrew else "installed"
        failure = (result.stderr or result.stdout).strip()[-300:]
    full_token = homebrew.get(token, name.split(":", 1)[1])
    run([ctx.brew, "install", "--cask", full_token], env=env, timeout=3600)
    ctx.wrapup(f"Cask {token} kept with Homebrew",
               f"mise failed twice ({failure}); installed through Homebrew instead. Retry with "
               f"`mise -C ~ bootstrap packages apply {name}` after `brew uninstall --cask {full_token}`.")
    return "kept with Homebrew after mise failed"


def step_casks(ctx):
    if not ctx.host.macos:
        return {"casks": "not macOS"}
    services = quiesce(ctx)
    listing = json.loads(output([ctx.brew, "info", "--json=v2", "--installed"], env=ctx.env()))
    homebrew = {item["token"]: item.get("full_token", item["token"]) for item in listing.get("casks", [])}
    native = native_casks(ctx)
    results = {}
    for name in ctx.host.casks():
        receipt = ctx.run_dir / "casks" / f"{cask_token(name)}.json"
        if receipt.exists() and read_json(receipt)["status"] == "ok":
            results[name] = read_json(receipt)
            continue
        try:
            outcome = {"status": "ok", "detail": transfer_cask(ctx, name, native, homebrew)}
            if outcome["detail"].startswith("kept with Homebrew") and ctx.host.needs_approval(name):
                ctx.wrapup(f"Approve {cask_token(name)}", APPROVAL.format(app=cask_token(name), name=name))
        except RolloutError as error:
            outcome = {"status": "failed", "detail": str(error)[-400:]}
            if ctx.host.needs_approval(name):
                ctx.wrapup(f"Approve {cask_token(name)}", APPROVAL.format(app=cask_token(name), name=name))
            else:
                ctx.wrapup(f"Cask {cask_token(name)}", f"Transfer failed: {outcome['detail']}")
        write_json(receipt, outcome)
        results[name] = outcome
    formulae = [name for name in ctx.host.declarations()["packages"] if name.startswith("brew:")]
    for name in formulae:
        result = run([ctx.mise, "-C", ctx.home, "bootstrap", "packages", "apply", name], env=ctx.env(),
                     check=False, timeout=3600)
        results[name] = {"status": "ok" if result.returncode == 0 else "failed"}
    if "brew-cask:omniwm" in ctx.host.declarations()["packages"]:
        run([ctx.mise, "-C", ctx.home, "bootstrap", "--only", "macos-defaults,macos-launchd-agents"],
            env=ctx.env(), check=False, timeout=600)
    resumed = resume_services(ctx)
    return {"packages": results, "services": services, **resumed}


def step_cleanup(ctx):
    env = ctx.env()
    removed = []
    plan = make_plan(ctx.host, ctx.home)
    leftovers = [item for item in plan["actions"] if item["action"] in ("remove-link", "retire-root")]
    for item in apply_plan({"actions": leftovers}, ctx.run_dir / "cleanup", ctx.home, ctx.host.live_checkout):
        if item["outcome"] != "absent":
            removed.append(item["path"])
    for relative in RETIRED_LINKS:
        path = ctx.home / relative
        if path.is_symlink() and allowlisted_link(path, ctx.host.live_checkout):
            path.unlink()
            removed.append(relative)
    if ctx.host.macos and shutil.which(ctx.brew, path=env["PATH"]):
        tools = ctx.host.declarations()["tools"]
        installed = set(output([ctx.brew, "list", "--formula"], env=env).split())
        for formula, replacement in SUPERSEDED_FORMULAE.items():
            if formula not in installed or (replacement and replacement not in tools):
                continue
            if output([ctx.brew, "uses", "--installed", formula], env=env, check=False):
                ctx.wrapup(f"Homebrew {formula}", "Still required by other formulae; review before removing.")
                continue
            run([ctx.brew, "uninstall", "--formula", formula], env=env)
            removed.append(f"brew:{formula}")
        casks = set(output([ctx.brew, "list", "--cask"], env=env).split())
        for cask, replacement in SUPERSEDED_CASKS.items():
            if cask in casks and replacement in tools:
                run([ctx.brew, "uninstall", "--cask", cask], env=env)
                removed.append(f"brew-cask:{cask}")
    return {"removed": removed}


def step_restore(ctx):
    result = data.compare_and_restore(ctx.run_dir, ctx.home)
    for item in result["manual"]:
        ctx.wrapup(f"Restore {item['path']}", f"{item['reason']}; the backup copy is in "
                   f"{ctx.run_dir / 'backup/files' / item['path']}")
    return result


def step_verify(ctx):
    kept = {path.stem for path in (ctx.run_dir / "casks").glob("*.json")
            if read_json(path).get("detail", "").startswith("kept with Homebrew")}
    results = checks.verify(ctx.host, ctx.home, ctx.home / ".local/bin/mise", kept_with_homebrew=kept)
    failed = [r for r in results if r["status"] == "fail"]
    for result in results:
        if result["status"] == "warn":
            ctx.wrapup(f"Check {result['name']}", result["detail"][-300:])
    write_json(ctx.run_dir / "verify.json", results)
    if failed:
        raise RolloutError("verify failed: " + "; ".join(f"{r['name']}: {r['detail'][-200:]}" for r in failed))
    return {"checks": results}


def step_close(ctx):
    if not ctx.require_console:
        return {"console": "not required"}
    return console.close(ctx.run_dir)


def step_report(ctx):
    path = write_report(ctx)
    return {"report": str(path)}


STEPS = [
    ("console", step_console, {"migrate", "catch-up"}),
    ("preflight", step_preflight, {"migrate", "catch-up"}),
    ("plan", step_plan, {"migrate", "catch-up"}),
    ("backup", step_backup, {"migrate"}),
    ("files", step_files, {"migrate", "catch-up"}),
    ("switch", step_switch, {"migrate", "catch-up"}),
    ("bootstrap", step_bootstrap, {"migrate", "catch-up"}),
    ("rtk", step_rtk, {"migrate"}),
    ("casks", step_casks, {"migrate"}),
    ("cleanup", step_cleanup, {"migrate", "catch-up"}),
    ("restore", step_restore, {"migrate"}),
    ("verify", step_verify, {"migrate", "catch-up"}),
    ("close", step_close, {"migrate", "catch-up"}),
    ("report", step_report, {"migrate", "catch-up"}),
]


def step_record(run_dir, name):
    """The `steps/<n>-<name>` path prefix of a step's log, JSON and exit files."""
    index = next((i for i, (step, _, _) in enumerate(STEPS, 1) if step == name), 0)
    return Path(run_dir) / "steps" / f"{index:02d}-{name}"


def status(run_dir):
    """Each step's state for polling: done, failed, running or pending."""
    run_dir = Path(run_dir)
    states = []
    for name, _, _ in STEPS:
        prefix = step_record(run_dir, name)
        exit_file = prefix.with_suffix(".exit")
        if exit_file.exists():
            code = exit_file.read_text().strip()
            state = "done" if code == "0" else ("skipped" if code == "skip" else f"failed ({code})")
        elif prefix.with_suffix(".started").exists():
            state = "running"
        else:
            state = "pending"
        states.append({"step": name, "state": state})
    return states


def rollout(ctx):
    """Runs every pending step for the run's mode, in order."""
    (ctx.run_dir / "steps").mkdir(parents=True, exist_ok=True)
    for name, function, modes in STEPS:
        prefix = step_record(ctx.run_dir, name)
        exit_file = prefix.with_suffix(".exit")
        if exit_file.exists() and exit_file.read_text().strip() in ("0", "skip"):
            continue
        mode = ctx.state.get("mode")
        if mode and mode not in modes:
            exit_file.write_text("skip\n")
            continue
        started = time.time()
        exit_file.unlink(missing_ok=True)
        prefix.with_suffix(".started").write_text(datetime.now(timezone.utc).isoformat() + "\n")
        print(f"==> {name}", flush=True)
        try:
            result = function(ctx)
            code = 0
        except Exception as error:  # noqa: BLE001 - every failure is recorded, then the run stops
            result = {"error": str(error), "traceback": traceback.format_exc()[-3000:]}
            code = 1
        result["seconds"] = round(time.time() - started)
        write_json(prefix.with_suffix(".json"), result)
        exit_file.write_text(f"{code}\n")
        ctx.state = read_json(ctx.run_dir / "state.json", ctx.state)
        if code:
            print(f"rollout: {name} failed: {result['error']}", file=sys.stderr, flush=True)
            write_report(ctx)
            return 1
    return 0


def write_report(ctx):
    """report.md: steps and timings, casks, restores, exceptions, fixes and the wrap-up list."""
    lines = [f"# Rollout report: {ctx.host.name}", ""]
    state = ctx.state
    lines += [f"- Mode: {state.get('mode', 'unknown')}", f"- Run directory: `{ctx.run_dir}`",
              f"- System before: `{state.get('system_before', '?')}`",
              f"- System after: `{state.get('system_after', 'not switched')}`", ""]
    lines += ["## Steps", "", "| Step | State | Seconds |", "|---|---|---|"]
    for item in status(ctx.run_dir):
        detail = read_json(step_record(ctx.run_dir, item["step"]).with_suffix(".json"), {})
        lines.append(f"| {item['step']} | {item['state']} | {detail.get('seconds', '')} |")
    casks = read_json(step_record(ctx.run_dir, "casks").with_suffix(".json"), {}).get("packages", {})
    if casks:
        lines += ["", "## Packages", ""]
        lines += [f"- `{name}`: {value['status']} {value.get('detail', '')}".rstrip() for name, value in casks.items()]
    restore = read_json(ctx.run_dir / "restore.json", {})
    if restore:
        lines += ["", "## Restores", "", f"- Restored mechanically: {len(restore['restored'])}"]
        lines += [f"- Manual: `{item['path']}`: {item['reason']}" for item in restore["manual"]]
    exceptions = ctx.host.decisions.get("exceptions", {})
    if exceptions:
        lines += ["", "## Known exceptions", ""] + [f"- {key}: {value}" for key, value in exceptions.items()]
    root = ctx.host.checkout.parents[1]
    if state.get("start_commit") and (root / ".git").exists():
        fixes = output(["git", "-C", root, "log", "--oneline", f"{state['start_commit']}..HEAD"], check=False)
        lines += ["", "## Code fixes during the run", ""] + ([f"- {line}" for line in fixes.splitlines()] or ["- none"])
    repairs = read_json(ctx.run_dir / "manual-repairs.json", [])
    lines += ["", "## Manual repairs", ""] + ([f"- {repair}" for repair in repairs] or ["- none"]) + [""]
    lines += ["## Wrap-up list for the user", ""]
    items = read_json(ctx.run_dir / "wrapup.json", [])
    lines += [f"- **{item['item']}**: {item['instructions']}" for item in items] or ["- nothing"]
    path = ctx.run_dir / "report.md"
    path.write_text("\n".join(lines) + "\n")
    return path
