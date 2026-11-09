"""Reconciles the agent configuration fields native mise merges cannot own:
whole-map MCP declarations, managed hooks and transitional Pi skill paths.
Every target is shared with its application, so sibling keys, manual hooks
and credentials are preserved.

Usage: configure_apps.py DOTFILES PROFILE SKILL_OVERRIDES_FILE
With RECONCILE_MODE=status it reports drift and exits 1 without writing.
"""

import json
import os
import re
import stat
import sys
import time
import tomllib
from collections.abc import Callable
from pathlib import Path
from typing import Any

import tomli_w

JsonObject = dict[str, Any]
ManagedPredicate = Callable[[Any], bool]


class ConfigWriter:
    """Compares projected bytes, then writes atomically or records drift."""

    def __init__(self, mode: str = "apply") -> None:
        self.mode = mode
        self.drift = False

    def write(self, file: Path, content: str) -> bool:
        """Writes `content` unless the regular file already holds it. Returns whether it changed."""
        info = _lstat(file)
        is_file = info is not None and stat.S_ISREG(info.st_mode)
        if is_file and file.read_text() == content:
            return False
        if self.mode == "status":
            print(f"config: drift at {file}")
            self.drift = True
            return False
        file.parent.mkdir(parents=True, exist_ok=True)
        temporary = file.with_name(f"{file.name}.tmp.{os.getpid()}.{time.time_ns()}")
        # A replaced symlink's permissions must not carry into writable config.
        mode = stat.S_IMODE(info.st_mode) if is_file else 0o600
        try:
            fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
            with os.fdopen(fd, "w") as handle:
                os.fchmod(handle.fileno(), mode)
                handle.write(content)
            os.replace(temporary, file)
        finally:
            if _lstat(temporary):
                temporary.unlink()
        return True

    def write_json(self, file: Path, value: Any) -> bool:
        """Writes `value` as two-space JSON."""
        return self.write(file, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def _lstat(file: Path) -> os.stat_result | None:
    try:
        return file.lstat()
    except FileNotFoundError:
        return None


def _is_object(value: Any) -> bool:
    return isinstance(value, dict)


def read_json_object(file: Path, fallback: JsonObject | None = None) -> JsonObject:
    """Reads a JSON object, or `fallback` when the file is missing. Raises on any other shape."""
    if fallback is not None and not _lstat(file):
        return fallback
    try:
        value = json.loads(file.read_text())
    except (OSError, ValueError) as error:
        raise ValueError(f"refusing to update invalid JSON at {file}: {error}") from error
    if not _is_object(value):
        raise ValueError(f"refusing to update {file}: top-level value is not a JSON object")
    return value


def replace_managed_hooks(current: JsonObject, desired: JsonObject, is_managed: ManagedPredicate) -> JsonObject:
    """Replaces the managed hooks in each event, keeping every other group and handler."""
    result: JsonObject = {}
    for event in dict.fromkeys([*current, *desired]):
        retained = []
        for group in current.get(event) or []:
            hooks = group.get("hooks") if _is_object(group) else None
            if not isinstance(hooks, list):
                if not is_managed(group):
                    retained.append(group)
                continue
            kept = [handler for handler in hooks if not is_managed(handler)]
            if kept or not hooks:
                retained.append({**group, "hooks": kept})
        entries = [*retained, *(desired.get(event) or [])]
        if entries:
            result[event] = entries
    return result


WORKMUX = "workmux set-window-status"


def contains_managed_command(value: Any) -> bool:
    """Claude hooks are managed when any string inside them runs workmux."""
    if isinstance(value, str):
        return WORKMUX in value
    if isinstance(value, list):
        return any(contains_managed_command(item) for item in value)
    if _is_object(value):
        return any(contains_managed_command(item) for item in value.values())
    return False


def is_managed_codex_handler(value: Any) -> bool:
    """Codex hooks are managed when their command runs workmux."""
    return _is_object(value) and isinstance(value.get("command"), str) and WORKMUX in value["command"]


def apply_managed_key(writer: ConfigWriter, file: Path, key: str, declared: Any) -> None:
    """Owns `key` in a shared JSON file outright: exactly the declared entries remain."""
    if not _is_object(declared):
        raise ValueError(f"invalid declared entries for {key}")
    config = read_json_object(file, {})
    config[key] = declared
    if writer.write_json(file, config):
        print(f"agents: applied managed '{key}' entries -> {file}")


def apply_claude_settings(writer: ConfigWriter, file: Path, declared_hooks: JsonObject, skill_overrides: Any) -> None:
    """Claude settings: managed workmux hooks plus the wholly owned skill overrides, in one write."""
    if not _is_object(skill_overrides):
        raise ValueError("invalid Claude skill overrides")
    settings = read_json_object(file, {})
    hooks = settings["hooks"] if _is_object(settings.get("hooks")) else {}
    settings["hooks"] = replace_managed_hooks(hooks, declared_hooks, contains_managed_command)
    settings["skillOverrides"] = skill_overrides
    writer.write_json(file, settings)


def apply_codex_hooks(writer: ConfigWriter, file: Path, declared_hooks: JsonObject) -> None:
    """Codex hooks.json: managed workmux hooks beside RTK's and the user's."""
    target = read_json_object(file, {})
    hooks = target["hooks"] if _is_object(target.get("hooks")) else {}
    target["hooks"] = replace_managed_hooks(hooks, declared_hooks, is_managed_codex_handler)
    writer.write_json(file, target)


def apply_codex_config(writer: ConfigWriter, file: Path, mcp_servers: Any, hooks_file: Path) -> None:
    """Codex config.toml: owns `mcp_servers` and re-enables managed hooks the user disabled.

    Codex keys hook state as "<hooksFile>:<snake_case_event>:<group>:<index>".
    """
    if not _is_object(mcp_servers):
        raise ValueError("invalid Codex MCP servers")
    original = file.read_text() if _lstat(file) else ""
    config = tomllib.loads(original) if original.strip() else {}
    config["mcp_servers"] = mcp_servers
    hooks = read_json_object(hooks_file, {}).get("hooks") or {}
    state = config["hooks"]["state"] if _is_object(config.get("hooks")) and _is_object(config["hooks"].get("state")) else {}
    for event, groups in hooks.items():
        if not isinstance(groups, list):
            raise ValueError(f"invalid Codex hook event {event}")
        event_key = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", event).lower()
        for group_index, group in enumerate(groups):
            for index, handler in enumerate(group.get("hooks") or []):
                entry = state.get(f"{hooks_file}:{event_key}:{group_index}:{index}")
                if is_managed_codex_handler(handler) and _is_object(entry) and entry.get("enabled") is False:
                    entry["enabled"] = True
    writer.write(file, tomli_w.dumps(config))


# Declared before skill paths were recorded, so no state file names them.
# Pi also reads the glob as a filter that hid every other skill.
RETIRED_SKILL_PATHS = [
    "~/code/*/apps/*/.agents/skills",
    "~/code/monorepo/pub/pi-surface/skills",
]


def apply_pi_skill_paths(writer: ConfigWriter, settings_file: Path, declared: Any, state_file: Path) -> None:
    """Pi settings: declared skill paths are added and earlier declarations retired; hand-added paths stay."""
    if not isinstance(declared, list) or not all(isinstance(item, str) for item in declared):
        raise ValueError("invalid Pi skill paths")
    settings = read_json_object(settings_file, {})
    before = json.dumps(settings)
    previous: list[str] = []
    try:
        recorded = json.loads(state_file.read_text())
        if isinstance(recorded, list):
            previous = [item for item in recorded if isinstance(item, str)]
    except (OSError, ValueError):
        # An absent or unreadable record only means nothing earlier can be pruned.
        pass
    stale = {path for path in [*previous, *RETIRED_SKILL_PATHS] if path not in declared}
    if isinstance(settings.get("skills"), list) or declared:
        skills = [path for path in settings.get("skills") or [] if path not in stale]
        skills += [path for path in declared if path not in skills]
        settings["skills"] = skills
    # Pi reads custom providers from models.json, so a providers map here is stale.
    settings.pop("providers", None)
    if json.dumps(settings) != before and writer.write_json(settings_file, settings):
        print("agents: applied declared Pi settings")
    writer.write(state_file, json.dumps(declared, separators=(",", ":"), ensure_ascii=False) + "\n")


def configure_apps(writer: ConfigWriter, home: Path, dotfiles: Path, profile: str, skill_overrides_file: Path) -> None:
    """Applies every managed field for one agent profile under `home`."""
    apps = dotfiles / "mise/apps"
    hooks = dotfiles / "agents/workmux-status"

    def read(file: Path) -> Any:
        return json.loads(file.read_text())

    apply_managed_key(writer, home / ".claude.json", "mcpServers", read(apps / profile / "claude-mcp.json"))
    apply_claude_settings(writer, home / ".claude/settings.json", read_json_object(hooks / "claude-hooks.json"), read(skill_overrides_file))
    codex_hooks = home / ".codex/hooks.json"
    apply_codex_hooks(writer, codex_hooks, read_json_object(hooks / "codex-hooks.json"))
    apply_codex_config(writer, home / ".codex/config.toml", read(apps / profile / "codex-mcp.json"), codex_hooks)
    apply_managed_key(writer, home / ".pi/agent/mcp.json", "mcpServers", read(apps / profile / "pi-mcp.json"))
    apply_managed_key(writer, home / ".pi/agent/npm/package.json", "allowScripts", read(apps / "pi-allow-scripts.json"))
    apply_pi_skill_paths(
        writer,
        home / ".pi/agent/settings.json",
        read(apps / "pi-skill-paths.json"),
        home / ".local/state/agents-nix/pi-skill-paths.json",
    )


def main() -> int:
    mode = os.environ.get("RECONCILE_MODE", "apply")
    home = os.environ.get("HOME")
    if len(sys.argv) != 4 or not home or mode not in ("apply", "status"):
        print("usage: configure_apps.py DOTFILES PROFILE SKILL_OVERRIDES_FILE (RECONCILE_MODE=apply|status)", file=sys.stderr)
        return 2
    dotfiles, profile, skill_overrides = sys.argv[1:]
    writer = ConfigWriter(mode)
    try:
        configure_apps(writer, Path(home), Path(dotfiles), profile, Path(skill_overrides))
    except (OSError, ValueError) as error:
        print(f"agents: {error}", file=sys.stderr)
        return 1
    return 1 if writer.drift else 0


if __name__ == "__main__":
    sys.exit(main())
