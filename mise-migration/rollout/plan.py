"""The HOME changes a run makes before bootstrap, and applying them.

Only links into /nix/store or the checkout are removed. Anything else in the
way of a mise target is moved under the run directory, never deleted.
"""

import os
import shutil
import tomllib
from pathlib import Path

from .common import (
    RolloutError, allowlisted_link, home_path, move_aside, read_json, run, write_json,
)

HM_ROOT = ".local/state/home-manager/gcroots/current-home"
HM_PROFILES = ".local/state/nix/profiles"
LEGACY_OMNIWM = "org.nix-community.home.omniwm"
# Retired tools whose store-backed links outlive their Home Manager generation.
RETIRED_LINKS = [".local/share/gh/extensions/gh-stack"]
BOOTSTRAP_LINKS = {
    ".config/mise/config.toml": "mods/dotfiles/mise/config.toml",
    ".config/mise/config.local.toml": "homes/{host}/mise.toml",
    ".config/mise/dotfiles": "mods/dotfiles",
    ".config/mise/mise.lock": "mods/dotfiles/mise/mise.lock",
    ".config/mise/mise.local.lock": "homes/{host}/mise.local.lock",
    ".local/share/mise/plugins/claude": "mods/dotfiles/mise/runtime/mise/plugins/claude",
    ".local/share/mise/plugins/pi": "mods/dotfiles/mise/runtime/mise/plugins/pi",
}
NIX_FRAGMENT = ".config/mise/conf.d/nix.toml"


def home_manager(home):
    """The active Home Manager generation and the links it placed in HOME."""
    root = Path(home) / HM_ROOT
    if not root.exists():
        return None, {}
    generation = root.resolve()
    putter = generation / "putter.json"
    files = {}
    if putter.is_file():
        for item in read_json(putter)["files"]:
            target = Path(item["target"])
            if target.is_relative_to(home):
                files[target.relative_to(home).as_posix()] = item["source"]
    else:
        tree = (generation / "home-files").resolve()
        for path in tree.rglob("*"):
            if path.is_symlink():
                files[path.relative_to(tree).as_posix()] = str(path)
    return generation, files


def declared_dotfiles(host):
    """Declared dotfile targets as (HOME-relative target, mode), core first, host overriding."""
    entries, groups = {}, {}
    for path in host.config_layers():
        data = tomllib.loads(path.read_text())
        for target, spec in data.get("dotfiles", {}).items():
            entries[target] = spec
        groups.update(data.get("dotfile_groups", {}))
    declared = []
    for target, spec in entries.items():
        mode = spec.get("mode", "symlink")
        if spec.get("merge") or mode == "absent" or not target.startswith("~/"):
            continue
        if any(variant.get("os") == "macos" for variant in spec.get("variants", [])) and not host.macos:
            continue
        declared.append((target[2:], mode))
    dotfiles = host.checkout / "mods/dotfiles"
    for group in groups.values():
        prefix = "~/.config/mise/dotfiles/"
        if not group["root"].startswith(prefix):
            continue
        root = dotfiles / group["root"][len(prefix):]
        for child in sorted(root.iterdir()):
            declared.append((f"{group['target'][2:]}/{child.name}", "symlink"))
    return declared


def make_plan(host, home):
    """File actions for this run, from the live HOME and the candidate declarations."""
    home = Path(home)
    actions = []
    seen = set()

    def add(relative, action, reason, **extra):
        if relative not in seen:
            seen.add(relative)
            actions.append({"path": relative, "action": action, "reason": reason, **extra})

    generation, files = home_manager(home)
    for relative, source in sorted(files.items()):
        path = home / relative
        if path.is_symlink() and (os.readlink(path) == source or "-home-manager-files" in os.readlink(path)):
            add(relative, "remove-link", "Home Manager link")
    if generation:
        add(HM_ROOT, "retire-root", "Home Manager generation root", target=str(generation))
        plist = generation / "LaunchAgents" / f"{LEGACY_OMNIWM}.plist"
        live = f"Library/LaunchAgents/{LEGACY_OMNIWM}.plist"
        if plist.is_file() and (home / live).exists():
            add(live, "retire-agent", "legacy OmniWM launch agent", label=LEGACY_OMNIWM)
    profiles = home / HM_PROFILES
    for path in sorted(profiles.glob("home-manager*")) if profiles.is_dir() else []:
        if path.is_symlink():
            add(path.relative_to(home).as_posix(), "retire-root", "Home Manager profile",
                target=str(path.resolve()))
    for relative in [NIX_FRAGMENT, *RETIRED_LINKS]:
        path = home / relative
        if path.is_symlink() and allowlisted_link(path, host.live_checkout):
            add(relative, "remove-link", "retired Nix-provided link")
        elif path.exists():
            add(relative, "move-aside", "retired target is not a store link")
    for relative, source in BOOTSTRAP_LINKS.items():
        path = home / relative
        expected = host.live_checkout / source.format(host=host.name)
        if path.is_symlink() and os.readlink(path) == str(expected):
            continue
        if path.is_symlink() and allowlisted_link(path, host.live_checkout):
            add(relative, "remove-link", "bootstrap replaces this link")
        elif path.exists() or path.is_symlink():
            add(relative, "move-aside", "bootstrap refuses an existing target")
    for relative, mode in declared_dotfiles(host):
        path = home / relative
        if relative in seen or not (path.exists() or path.is_symlink()):
            continue
        if path.is_symlink():
            if not allowlisted_link(path, host.live_checkout):
                add(relative, "move-aside", "unknown link at a mise target")
        elif mode == "symlink":
            add(relative, "move-aside", "mise refuses to replace a file with a link")
        elif path.is_file():
            add(relative, "preserve-copy", f"mise {mode} mode overwrites this file")
    return {"host": host.name, "home": str(home), "actions": actions}


def preserve_root(run_dir, relative, target):
    """Registers an indirect GC root for a retired generation under the run directory."""
    saved = Path(run_dir) / "retired-roots" / relative.replace("/", "__")
    if saved.is_symlink() and str(saved.resolve()) == target:
        return saved
    if saved.exists() or saved.is_symlink():
        raise RolloutError(f"retired root already recorded differently: {saved}")
    saved.parent.mkdir(parents=True, exist_ok=True)
    run(["nix-store", "--add-root", saved, "--indirect", "--realise", target])
    return saved


def retire_agent(label):
    target = f"gui/{os.getuid()}/{label}"
    if run(["launchctl", "print", target], check=False).returncode == 0:
        run(["launchctl", "bootout", target])
    if run(["launchctl", "print", target], check=False).returncode == 0:
        raise RolloutError(f"launch agent is still loaded: {label}")


def apply_plan(plan, run_dir, home, checkout):
    """Applies each planned action once; re-running skips completed ones."""
    run_dir, home = Path(run_dir), Path(home)
    done = run_dir / "actions"
    done.mkdir(parents=True, exist_ok=True)
    results = []
    for index, item in enumerate(plan["actions"]):
        receipt = done / f"{index:04d}.json"
        if receipt.exists():
            results.append(read_json(receipt))
            continue
        relative, action = item["path"], item["action"]
        path = home_path(home, relative)
        present = path.exists() or path.is_symlink()
        outcome = "absent"
        if present and action == "remove-link":
            if not allowlisted_link(path, checkout):
                raise RolloutError(f"refusing to remove a link outside the allowlist: {relative}")
            path.unlink()
            outcome = "removed"
        elif present and action == "retire-root":
            preserve_root(run_dir, relative, item["target"])
            path.unlink()
            outcome = "retired; generation kept as a GC root in the run directory"
        elif present and action == "retire-agent":
            retire_agent(item["label"])
            move_aside(path, run_dir, relative)
            outcome = "unloaded and moved"
        elif present and action == "move-aside":
            move_aside(path, run_dir, relative)
            outcome = "moved"
        elif present and action == "preserve-copy":
            copy = run_dir / "moved" / relative
            copy.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, copy, follow_symlinks=False)
            outcome = "copied"
        result = {**item, "outcome": outcome}
        write_json(receipt, result)
        results.append(result)
    return results
