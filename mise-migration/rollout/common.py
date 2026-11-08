"""Paths, process helpers and a host's declarations for the rollout harness."""

import json
import os
import platform
import subprocess
import sys
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

HARNESS = Path(__file__).resolve().parents[1]
DOTFILES = HARNESS.parent

PLATFORMS = {
    "nicks-mbp": ("macos", "arm64"),
    "nicks-loancrate-mbp": ("macos", "arm64"),
    "maclab": ("macos", "x64"),
    "supermicro": ("linux", "x64"),
}


class RolloutError(Exception):
    """A step cannot continue; the message says what to review."""


def run(command, *, check=True, env=None, cwd=None, timeout=None, capture=True, input=None):
    """Runs a command and returns the completed process; raises RolloutError on failure."""
    try:
        result = subprocess.run(
            [str(part) for part in command], env=env, cwd=cwd, timeout=timeout, input=input,
            capture_output=capture, text=True,
        )
    except FileNotFoundError as error:
        raise RolloutError(f"command not found: {command[0]}") from error
    if check and result.returncode:
        detail = (result.stderr or result.stdout or "").strip()[-2000:] if capture else ""
        raise RolloutError(f"{' '.join(map(str, command))} exited {result.returncode}: {detail}")
    return result


def output(command, **kwargs):
    """Stdout of a successful command, stripped."""
    return run(command, **kwargs).stdout.strip()


def read_json(path, default=None):
    path = Path(path)
    if not path.exists() and default is not None:
        return default
    return json.loads(path.read_text())


def write_json(path, value):
    """Writes private JSON atomically."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    os.chmod(temporary, 0o600)
    temporary.replace(path)


def home_path(home, relative):
    """A HOME-relative path whose ancestors are real directories, or RolloutError."""
    parts = Path(relative)
    if parts.is_absolute() or ".." in parts.parts or not parts.parts:
        raise RolloutError(f"unsafe home-relative path: {relative}")
    target = Path(home) / parts
    for parent in target.parents:
        if parent == Path(home):
            break
        if parent.is_symlink():
            raise RolloutError(f"symlink ancestor requires review: {relative}")
    return target


def monorepo_root(checkout=DOTFILES):
    return Path(checkout).resolve().parents[1]


def allowlisted_link(path, checkout=DOTFILES):
    """Whether a symlink points into /nix/store or the monorepo checkout, the only links the harness removes."""
    path = Path(path)
    if not path.is_symlink():
        return False
    target = Path(os.readlink(path))
    if not target.is_absolute():
        target = path.parent / target
    resolved = Path(os.path.normpath(target))
    return resolved.is_relative_to("/nix/store") or resolved.is_relative_to(monorepo_root(checkout))


def move_aside(path, run_dir, relative):
    """Moves an unknown file into the run's moved/ tree; never overwrites an earlier move."""
    destination = Path(run_dir) / "moved" / relative
    if destination.exists() or destination.is_symlink():
        raise RolloutError(f"moved copy already exists; review it: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    Path(path).rename(destination)
    return destination


# mise evaluates tap casks with Ruby 3+, which macOS lacks; Homebrew vendors one.
HOMEBREW_RUBY = [
    "/opt/homebrew/Library/Homebrew/vendor/portable-ruby/current/bin",
    "/usr/local/Homebrew/Library/Homebrew/vendor/portable-ruby/current/bin",
]


def with_homebrew_ruby(path):
    """`path` with Homebrew's portable Ruby first, when it exists."""
    rubies = [directory for directory in HOMEBREW_RUBY if Path(directory).is_dir()]
    return ":".join([*rubies, path]) if rubies else path


def current_platform():
    system = "macos" if sys.platform == "darwin" else "linux"
    arch = "arm64" if platform.machine() in ("arm64", "aarch64") else "x64"
    return system, arch


@dataclass
class Host:
    """One fleet host: its committed decisions and the declarations mise will apply."""

    name: str
    checkout: Path = DOTFILES
    decisions: dict = field(default_factory=dict)

    @property
    def platform(self):
        return PLATFORMS[self.name]

    @property
    def macos(self):
        return self.platform[0] == "macos"

    @property
    def flake_name(self):
        return self.decisions["flake_name"]

    @property
    def live_checkout(self):
        """The host's own dotfiles checkout, which bootstrap links HOME into."""
        return Path(self.decisions.get("checkout", "~/code/monorepo/pub/dotfiles-nix")).expanduser()

    @property
    def controller(self):
        return self.decisions.get("controller", "maclab")

    def config_layers(self):
        """Core, the host's roles and the host file, in mise's precedence order."""
        host_file = self.checkout / f"homes/{self.name}/mise.toml"
        # Includes resolve from ~/.config/mise, where `dotfiles` links to mods/dotfiles.
        roles = tomllib.loads(host_file.read_text()).get("include", [])
        return [
            self.checkout / "mods/dotfiles/mise/config.toml",
            *(self.checkout / "mods" / role for role in roles),
            host_file,
        ]

    def declarations(self):
        """Tools, packages and repositories selected for this host's platform."""
        result = {"tools": {}, "packages": {}, "repos": {}}
        for path in self.config_layers():
            data = tomllib.loads(path.read_text())
            result["tools"].update(data.get("tools", {}))
            bootstrap = data.get("bootstrap", {})
            result["packages"].update(bootstrap.get("packages", {}))
            result["repos"].update(bootstrap.get("repos", {}))
        system, arch = self.platform
        for group in (result["tools"], result["packages"]):
            for name, spec in list(group.items()):
                selectors = spec.get("os", []) if isinstance(spec, dict) else []
                selectors = [selectors] if isinstance(selectors, str) else selectors
                if selectors and system not in selectors and f"{system}/{arch}" not in selectors:
                    del group[name]
        return result

    def casks(self):
        """Declared cask package names (`brew-cask:<token>`) this host transfers."""
        declared = [name for name in self.declarations()["packages"] if name.startswith("brew-cask:")]
        selected = self.decisions.get("casks", {}).get("transfer", "all")
        if selected == "all":
            return declared
        return [name for name in declared if cask_token(name) in selected]

    def needs_approval(self, name):
        return cask_token(name) in self.decisions.get("casks", {}).get("needs_approval", [])


def cask_token(name):
    """`brew-cask:anomalyco/tap/hex` -> `hex`."""
    return name.split(":", 1)[1].split("/")[-1]


def load_host(name, checkout=DOTFILES):
    """Loads `hosts/<name>.toml` beside the harness for a fleet host."""
    if name not in PLATFORMS:
        raise RolloutError(f"unknown host: {name}")
    checkout = Path(checkout).resolve()
    decisions = tomllib.loads((checkout / "mise-migration/hosts" / f"{name}.toml").read_text())
    return Host(name=name, checkout=checkout, decisions=decisions)
