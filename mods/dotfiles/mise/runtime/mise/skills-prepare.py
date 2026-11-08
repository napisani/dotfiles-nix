"""Prepare complete skill directories offline; mise owns their deployment."""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

import yaml


class UniqueKeys(yaml.SafeLoader):
    pass


def mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node)
        if key in result:
            raise ValueError(f"Duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node)
    return result


UniqueKeys.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)


def relative_path(root, relative):
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"Expected a relative path inside its source: {relative}")
    resolved = (root / path).resolve(strict=True)
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError(f"Source path escapes its root: {relative}")
    return resolved


def metadata(text, name):
    fences = list(re.finditer(r"^---[ \t]*$", text, re.MULTILINE))
    if len(fences) < 2 or fences[0].start() != 0:
        raise ValueError(f"{name}: missing YAML frontmatter")
    end = fences[1].start()
    data = yaml.load(text[4:end], Loader=UniqueKeys)
    if not isinstance(data, dict) or data.get("name") != name:
        raise ValueError(f"{name}: frontmatter name must match the selected name")
    if not isinstance(data.get("description"), str) or not data["description"].strip():
        raise ValueError(f"{name}: missing description")
    if "disable-model-invocation" in data and not isinstance(
        data["disable-model-invocation"], bool
    ):
        raise ValueError(f"{name}: disable-model-invocation must be boolean")
    return data, text[fences[1].end() :]


def rewrite(text, replacements, name):
    for index, replacement in enumerate(replacements):
        before = replacement["from"]
        marker = f"__SKILL_REWRITE_{index}__"
        if not before or marker in text:
            raise ValueError(f"{name}: invalid rewrite or placeholder collision")
        if replacement.get("required", True) and before not in text:
            raise ValueError(f"{name}: required rewrite text is missing")
        text = text.replace(before, marker)
    for index, replacement in enumerate(replacements):
        text = text.replace(f"__SKILL_REWRITE_{index}__", replacement["to"])
    return text


def source_roots(catalog, selected, monorepo, declarations):
    roots = {}
    pending = []
    for source in sorted({catalog["skills"][name]["source"] for name, _ in selected}):
        definition = catalog["sources"][source]
        if "path" in definition:
            roots[source] = relative_path(monorepo, definition["path"])
            continue
        key = definition["repo"]
        desired = declarations.get(key, {})
        revision = desired.get("ref", "")
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError(f"{source}: declare an exact commit in bootstrap.repos")
        root = Path(key).expanduser()
        if not root.is_dir():
            pending.append(f"{source}: missing checkout")
            continue

        def git(*args, cwd=root):
            return subprocess.check_output(
                ["git", "-C", str(cwd), *args],
                text=True,
                env={**os.environ, "GIT_NO_LAZY_FETCH": "1", "GIT_OPTIONAL_LOCKS": "0"},
                stderr=subprocess.DEVNULL,
            ).strip()

        if git("status", "--porcelain", "--untracked-files=all", "--ignored"):
            raise ValueError(
                f"{source}: checkout is dirty; preserve and review local changes first"
            )
        if git("config", "--local", "--get", "remote.origin.url").rstrip(
            "/"
        ).removesuffix(".git") != desired["url"].rstrip("/").removesuffix(".git"):
            raise ValueError(f"{source}: checkout origin differs from bootstrap.repos")
        if git("rev-parse", "HEAD") != revision:
            pending.append(f"{source}: wrong revision")
            continue
        roots[source] = root.resolve()
    return roots, pending


def prepare(catalog, profile, monorepo, declarations, output):
    entries = catalog["profiles"]["common"] + (
        [] if profile == "common" else catalog["profiles"][profile]
    )
    selected = []
    for entry in entries:
        if isinstance(entry, str):
            name, manual = entry, False
        else:
            name, manual = entry["name"], entry.get("manualOnly", False)
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name) or not isinstance(
            manual, bool
        ):
            raise ValueError("Invalid skill selection")
        if name not in catalog["skills"]:
            raise ValueError(f"Unknown skill: {name}")
        if name in {existing for existing, _ in selected}:
            raise ValueError(f"Duplicate selected skill: {name}")
        selected.append((name, manual))
    roots, pending = source_roots(catalog, selected, monorepo, declarations)
    for parent in [output, *output.parents]:
        if parent.is_symlink():
            raise ValueError(f"Generated output must not traverse a symlink: {parent}")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and {p.name for p in output.iterdir()} - {
        "links",
        "prepared",
        "claude-overrides.json",
    }:
        raise ValueError(
            "Unexpected files in generated skills directory; review them before replacing it"
        )
    stage = Path(tempfile.mkdtemp(prefix=".skills-prepare-", dir=output.parent))
    try:
        (stage / "links").mkdir()
        (stage / "prepared").mkdir()
        overrides = {}
        for name, manual in selected:
            skill = catalog["skills"][name]
            root = roots.get(skill["source"])
            if root is None:
                continue
            source = relative_path(root, skill["path"])
            for directory, dirs, files in os.walk(source):
                for child in dirs + files:
                    file = Path(directory) / child
                    if file.is_symlink() and not file.resolve(
                        strict=True
                    ).is_relative_to(root):
                        raise ValueError(f"{name}: symlink escapes its source checkout")
            original = (source / "SKILL.md").read_text()
            rewritten = rewrite(original, skill.get("replacements", []), name)
            metadata(rewritten, name)
            settings = {}
            if manual:
                file = source / "agents/openai.yaml"
                settings = (
                    yaml.load(file.read_text(), Loader=UniqueKeys)
                    if file.exists()
                    else {}
                )
                if not isinstance(settings, dict) or not isinstance(
                    settings.get("policy", {}), dict
                ):
                    raise ValueError(f"{name}: malformed Codex metadata")
            if pending:
                continue
            if manual:
                overrides[name] = "user-invocable-only"
            for agent, target in [
                ("claude", ".claude/skills"),
                ("codex", ".codex/skills"),
                ("pi", ".pi/agent/skills"),
                ("shared", ".agents/skills"),
            ]:
                shared = skill.get("sharedDirectory", False)
                if (agent == "shared" and not shared) or (agent == "pi" and shared):
                    continue
                text = rewritten
                if agent == "pi" and name.startswith("workmux-"):
                    text = text.replace("/workmux-", "/skill:workmux-")
                data, body = metadata(text, name)
                if (
                    manual
                    and agent in {"pi", "shared"}
                    and not data.get("disable-model-invocation")
                ):
                    data["disable-model-invocation"] = True
                    text = (
                        "---\n" + yaml.safe_dump(data, sort_keys=False) + "---" + body
                    )
                policy = manual and agent == "codex"
                local = "path" in catalog["sources"][skill["source"]]
                link = stage / "links" / target / name
                link.parent.mkdir(parents=True, exist_ok=True)
                if local and text == original and not policy:
                    link.symlink_to(source, target_is_directory=True)
                    continue
                prepared = stage / "prepared" / agent / name
                # Patched files must not retain links back into the source checkout.
                shutil.copytree(source, prepared, symlinks=False)
                for file in [prepared, *prepared.rglob("*")]:
                    file.chmod(
                        file.stat().st_mode | (0o700 if file.is_dir() else 0o600)
                    )
                (prepared / "SKILL.md").write_text(text)
                if policy:
                    file = prepared / "agents/openai.yaml"
                    settings.setdefault("policy", {})[
                        "allow_implicit_invocation"
                    ] = False
                    file.parent.mkdir(parents=True, exist_ok=True)
                    file.write_text(yaml.safe_dump(settings, sort_keys=False))
                link.symlink_to(
                    output / "prepared" / agent / name, target_is_directory=True
                )
        if pending:
            # Empty bootstrap directories do not constitute a prepared view.
            has_view = output.exists() and any(
                path.is_file() or path.is_symlink() for path in output.rglob("*")
            )
            action = (
                "preserving the last prepared view"
                if has_view
                else "initializing an empty view"
            )
            print(
                f"Skill preparation deferred; {action}: " + "; ".join(pending),
                file=sys.stderr,
            )
            if has_view:
                return
        (stage / "claude-overrides.json").write_text(
            json.dumps(overrides, indent=2) + "\n"
        )
        previous = stage / "previous"
        if output.exists():
            output.rename(previous)
        try:
            stage.rename(output)
        except OSError:
            if previous.exists():
                previous.rename(output)
            raise
        if (output / "previous").exists():
            shutil.rmtree(output / "previous")
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--config", required=True, action="append", type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument(
        "--output", type=Path, default=Path.home() / ".local/share/dotfiles/skills"
    )
    args = parser.parse_args()
    declarations = {}
    for file in args.config:
        declarations.update(
            tomllib.loads(file.read_text()).get("bootstrap", {}).get("repos", {})
        )
    try:
        prepare(
            json.loads(args.catalog.read_text()),
            args.profile,
            args.root.resolve(),
            declarations,
            args.output,
        )
    except (
        ValueError,
        OSError,
        yaml.YAMLError,
        subprocess.CalledProcessError,
    ) as error:
        parser.exit(1, f"Skill preparation failed: {error}\n")


if __name__ == "__main__":
    main()
