"""Exercise native runtime setup in a retained, disposable HOME without Nix on PATH."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mise", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    home = Path(tempfile.mkdtemp(prefix="portable-runtime 'quoted' ")).resolve()
    evidence = home / "evidence"
    evidence.mkdir()
    mise = home / ".local/bin/mise"
    mise.parent.mkdir(parents=True)
    shutil.copy2(args.mise.resolve(), mise)
    env = {
        "HOME": str(home),
        "USER": "fixture",
        "PATH": f"{home}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "MISE_CACHE_PRUNE_AGE": "0s",
        "MISE_TASK_RUN_AUTO_INSTALL": "false",
        "MISE_ENABLE_TOOLS": "node,python,uv,deno,go,go:github.com/go-delve/delve/cmd/dlv,aqua:neovim/neovim,pipx:debugpy,github:microsoft/vscode-js-debug",
        "GIT_TERMINAL_PROMPT": "0",
        "UV_PROJECT_ENVIRONMENT": str(home / ".local/share/dotfiles/runtime/python"),
    }
    report = {"home": str(home), "steps": []}

    def run(name, command):
        result = subprocess.run(
            command, cwd=home, env=env, capture_output=True, text=True, timeout=600
        )
        (evidence / f"{name}.log").write_text(result.stdout + result.stderr)
        report["steps"].append({"name": name, "exit": result.returncode})
        (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        if result.returncode:
            raise RuntimeError(f"{name} failed; evidence: {evidence}")
        return result.stdout.strip()

    (home / ".claude.json").write_text(json.dumps({
        "manual": {"keep": True},
        "mcpServers": {"retired": {"command": "old"}},
    }))
    run("bootstrap", ["/bin/sh", str(project / "bootstrap.sh"), "maclab", "--only", "dotfiles"])
    run("tools-and-hook", [str(mise), "-C", str(home), "bootstrap", "--only", "tools"])
    run("configure", [str(mise), "-C", str(home), "run", "apps:configure"])
    run("skills-sync", [str(mise), "-C", str(home), "run", "skills:sync"])
    claude = json.loads((home / ".claude.json").read_text())
    assert claude["manual"] == {"keep": True}
    assert "retired" not in claude["mcpServers"]
    assert (home / ".pi/agent/mcp.json").is_file()
    assert not (home / ".config/mise/conf.d/nix.toml").exists()
    paths = {
        tool: run(f"which-{tool}", [str(mise), "-C", str(home), "which", tool])
        for tool in ["node", "python", "uv", "go", "dlv", "nvim", "debugpy-adapter"]
    }
    assert all(Path(value).resolve().is_relative_to(home) for value in paths.values())
    run("nvim-provider", [
        paths["nvim"], "--headless", "-u", "NONE", "-l",
        str(project / "tests/nvim-runtime.lua"), str(project / "mods/dotfiles/nvim"),
    ])
    run("nvim-local-plugins", [
        paths["nvim"], "--headless", "-u", "NONE", "-l",
        str(project / "tests/nvim-local-plugins.lua"), str(project / "mods/dotfiles/nvim"),
        str(project.parent),
    ])
    run("nvim-python-dap", [
        paths["nvim"], "--headless", "-u", "NONE", "-l",
        str(project / "tests/nvim-python-dap.lua"), str(project / "mods/dotfiles/nvim"),
    ])
    run("python-dap-session", [
        paths["python"], str(project / "tests/python-dap.py"),
        "--python", paths["python"], "--adapter", paths["debugpy-adapter"],
        "--evidence", str(evidence / "python-dap"),
    ])
    run("nvim-js-dap", [
        paths["nvim"], "--headless", "-u", "NONE", "-l",
        str(project / "tests/nvim-js-dap.lua"), str(project / "mods/dotfiles/nvim"),
        str(evidence / "js-adapter.json"),
    ])
    run("js-dap-handshake", [
        paths["python"], str(project / "tests/js-dap.py"), "--node", paths["node"],
        "--adapter", str(evidence / "js-adapter.json"),
        "--evidence", str(evidence / "js-dap"),
    ])
    run("nvim-go-dap", [
        paths["nvim"], "--headless", "-u", "NONE", "-l",
        str(project / "tests/nvim-go-dap.lua"), str(project / "mods/dotfiles/nvim"),
        str(evidence / "go-adapter.json"),
    ])
    run("go-dap-session", [
        paths["python"], str(project / "tests/go-dap.py"),
        "--go", paths["go"], "--dlv", paths["dlv"],
        "--adapter", str(evidence / "go-adapter.json"), "--evidence", str(evidence / "go-dap"),
    ])
    links = sum(path.is_symlink() for path in (home / ".agents/skills").iterdir())
    assert links > 0
    report.update(tool_paths=paths, shared_skill_links=links, manual_fields_preserved=True)
    (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
