"""Attach the declared LSP fleet using pinned plugin configs and native tools."""

import argparse
import json
import os
from pathlib import Path
import subprocess


TOOLS = [
    "node", "python", "uv", "go", "zig", "aqua:neovim/neovim", "ruff", "deno",
    "stylua", "shellcheck", "go:golang.org/x/tools/gopls", "lua-language-server",
    "npm:vscode-langservers-extracted", "npm:@tailwindcss/language-server",
    "npm:bash-language-server", "npm:yaml-language-server", "npm:@vtsls/language-server",
    "pipx:basedpyright", "zls", "github:mattn/efm-langserver",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tools", action="store_true", help="Print the required mise tool selection")
    parser.add_argument("--mise")
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--nil", type=Path, help="Also verify the system-owned nil executable")
    args = parser.parse_args()
    if args.tools:
        print(",".join(TOOLS))
        return
    if not args.mise or not args.evidence:
        parser.error("--mise and --evidence are required for acceptance")
    project = Path(__file__).resolve().parents[1]
    source = project / "mods/dotfiles/nvim"
    work = args.evidence.resolve()
    work.mkdir(parents=True)
    plugins = work / "plugins"
    plugins.mkdir()
    env = {**os.environ, "XDG_STATE_HOME": str(work / "state 'quoted'")}
    lock = json.loads((source / "lazy-lock.json").read_text())
    with (work / "plugins.log").open("w") as log:
        for name, repository in [
            ("nvim-lspconfig", "neovim/nvim-lspconfig"),
            ("efmls-configs-nvim", "creativenull/efmls-configs-nvim"),
            ("plenary.nvim", "nvim-lua/plenary.nvim"),
        ]:
            checkout = plugins / name
            subprocess.run(["git", "init", "-q", str(checkout)], check=True, env=env)
            subprocess.run([
                "git", "-C", str(checkout), "fetch", "--depth=1",
                f"https://github.com/{repository}.git", lock[name]["commit"],
            ], check=True, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90)
            subprocess.run([
                "git", "-C", str(checkout), "checkout", "--detach", "FETCH_HEAD",
            ], check=True, env=env, stdout=log, stderr=subprocess.STDOUT)
    nvim = subprocess.check_output([args.mise, "which", "nvim"], env=env, text=True).strip()
    missing = work / "missing-server"
    missing.mkdir()
    (missing / "main.nix").write_text("{ }\n")
    without_nil = os.pathsep.join(
        entry for entry in env["PATH"].split(os.pathsep)
        if not os.access(os.path.join(entry, "nil"), os.X_OK)
    )
    with (missing / "nvim.log").open("w") as log:
        result = subprocess.run([
            nvim, "--headless", "-u", "NONE", "-l", str(project / "tests/nvim-lsp-missing.lua"),
            str(source), str(plugins), str(missing / "main.nix"),
        ], cwd=missing, env={**env, "PATH": without_nil}, stdout=log, stderr=subprocess.STDOUT, timeout=60)
    assert result.returncode == 0, f"An uninstalled server caused errors; see {missing / 'nvim.log'}"
    print("uninstalled servers skipped", flush=True)
    cases = {
        "gopls": ("go", "main.go", "package main\nfunc main() {}\n", {"go.mod": "module example.test/probe\n\ngo 1.26.0\n"}),
        "lua_ls": ("lua", "main.lua", "local value = 1\n", {}),
        "jsonls": ("json", "main.json", '{"value":1}\n', {}),
        "cssls": ("css", "main.css", "body { color: red; }\n", {}),
        "html": ("html", "main.html", "<html><body>probe</body></html>\n", {}),
        "eslint": ("javascript", "main.js", "const value = 1;\n", {"eslint.config.js": "module.exports = [];\n"}),
        "tailwindcss": ("html", "main.html", '<div class="text-red-500">probe</div>\n', {"tailwind.config.js": "module.exports = { content: ['./*.html'] };\n"}),
        "bashls": ("sh", "main.sh", "#!/bin/bash\nprobe() { printf 'probe\\n'; }\nprobe\n", {}),
        "basedpyright": ("python", "main.py", "def probe():\n    return 1\n", {"pyproject.toml": "[project]\nname='probe'\nversion='0.0.0'\n"}),
        "ruff": ("python", "main.py", "import os\nprint(unknown_name)\n", {"pyproject.toml": "[tool.ruff]\n"}),
        "yamlls": ("yaml", "main.yaml", "value: 1\n", {}),
        "zls": ("zig", "main.zig", "pub const value: u32 = 1;\n", {"zls.json": "{}\n"}),
        "vtsls": ("typescript", "main.ts", "export const value: number = 1;\n", {"tsconfig.json": "{}\n", "package-lock.json": "{}\n"}),
        "denols": ("typescript", "main.ts", "export const value: number = 1;\n", {"deno.json": "{}\n"}),
        "efm": ("lua", "main.lua", "local value=1\n", {}),
    }
    if args.nil:
        nil = args.nil.resolve(strict=True)
        assert str(nil).startswith("/nix/store/"), f"nil must remain Nix-owned: {nil}"
        env["PATH"] = f"{nil.parent}:{env['PATH']}"
        cases["nil_ls"] = ("nix", "main.nix", "let value = 1; in { inherit value; }\n", {})
    results = []
    for name, (filetype, filename, content, files) in cases.items():
        root = work / name
        root.mkdir()
        (root / ".git").mkdir()
        (root / filename).write_text(content)
        (root / "package.json").write_text('{"name":"probe","private":true}\n')
        for filename_extra, content_extra in files.items():
            (root / filename_extra).write_text(content_extra)
        case = {
            "name": name, "filetype": filetype, "root": str(root),
            "file": str(root / filename), "report": str(root / "result.json"),
            "owner": "nix" if name == "nil_ls" else "mise",
        }
        case_file = root / "case.json"
        case_file.write_text(json.dumps(case))
        with (root / "nvim.log").open("w") as log:
            result = subprocess.run([
                nvim, "--headless", "-u", "NONE", "-l", str(project / "tests/nvim-lsp.lua"),
                str(source), str(plugins), str(case_file),
            ], cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=60)
        results.append({"name": name, "exit": result.returncode})
        (work / "report.json").write_text(json.dumps(results, indent=2))
        print(name, result.returncode, flush=True)
    assert all(result["exit"] == 0 for result in results), f"LSP failures retained under {work}"
    configured = set(json.loads((work / "gopls/result.json").read_text())["configured"])
    separate = set() if args.nil else {"nil_ls"}
    assert configured == set(cases) | separate, f"Missing server acceptance: {configured - set(cases) - separate}"
    print(f"{len(cases)} configured servers attached; evidence: {work}")
    if separate:
        print("System-owned nil not exercised; pass --nil /path/to/nil to verify it separately.")


if __name__ == "__main__":
    main()
