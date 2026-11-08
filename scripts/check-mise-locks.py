"""Check that declared tools have native locks for every selected fleet platform."""

import argparse
from pathlib import Path
import tomllib

PLATFORMS = {
    "macos-arm64": {"macos", "macos/arm64"},
    "macos-x64": {"macos", "macos/x64"},
    "linux-x64": {"linux", "linux/x64"},
}


def declared_tools(config, include_root):
    """Tools declared by a config and its includes, which mise locks with the config."""
    data = tomllib.loads(config.read_text())
    tools = {}
    for include in data.get("include", []):
        tools.update(tomllib.loads((include_root / include).read_text()).get("tools", {}))
    tools.update(data.get("tools", {}))
    return tools


def check(config, lock, include_root):
    declared = declared_tools(config, include_root)
    locked = tomllib.loads(lock.read_text()).get("tools", {})
    for name, request in declared.items():
        version = request if isinstance(request, str) else request["version"]
        selectors = [] if isinstance(request, str) else request.get("os", [])
        if isinstance(selectors, str):
            selectors = [selectors]
        if set(selectors) - set.union(*PLATFORMS.values()):
            raise ValueError(f"{config}: {name}: unknown platform selector")
        required = [
            platform for platform, aliases in PLATFORMS.items()
            if not selectors or set(selectors) & aliases
        ]
        matches = [entry for entry in locked.get(name, []) if version in entry["specifiers"]]
        if not required or len(matches) != 1:
            raise ValueError(f"{config}: {name}: expected exactly one matching lock")
        entry = matches[0]
        backend = entry["backend"]
        if backend.startswith("npm:"):
            continue
        if backend.startswith("go:"):
            if entry["version"] != version:
                raise ValueError(f"{config}: {name}: module version differs")
            continue
        if backend.startswith("pipx:"):
            if not (lock.parent / entry["uv"]["path"] / "uv.lock").is_file():
                raise ValueError(f"{config}: {name}: missing uv sidecar")
            continue
        for platform in required:
            artifact = entry.get(f"platforms.{platform}", {})
            if not artifact.get("url") or not artifact.get("checksum"):
                raise ValueError(f"{config}: {name}: missing locked artifact for {platform}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--lock", type=Path)
    args = parser.parse_args()
    if bool(args.config) != bool(args.lock):
        parser.error("--config and --lock must be supplied together")
    project = Path(__file__).resolve().parents[1]
    pairs = [(args.config, args.lock)] if args.config else [
        (project / "mods/dotfiles/mise/config.toml", project / "mods/dotfiles/mise/mise.lock"),
        (project / "mise.toml", project / "mise.lock"),
        *((config, config.with_name("mise.local.lock")) for config in sorted((project / "homes").glob("*/mise.toml"))),
    ]
    # Includes resolve from ~/.config/mise, where `dotfiles` links to mods/dotfiles.
    include_root = args.config.parent if args.config else project / "mods"
    for config, lock in pairs:
        check(config, lock, include_root)
    print(f"Platform lock coverage passed for {len(pairs)} configs")


if __name__ == "__main__":
    main()
