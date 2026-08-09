# toolbox

Personal CLI utilities and shell replacements, scoped to this dotfiles repo.
Two tiers depending on complexity — both use uv for isolation, both end up as
plain commands on PATH.

---

## Tier 1 — Single-file scripts

For simple utilities with few or no dependencies.

**Location:** a `.py` file directly in `toolbox/`

**Pattern:** uv inline script dependencies (PEP 723). uv manages the Python
version and a per-script venv transparently — nothing to activate or install.

```python
#!/usr/bin/env -S uv run
# /// script
# requires-python = "==3.12"
# dependencies = ["httpx", "rich"]
# ///

import httpx
...
```

**Activation:** `chmod +x my-script.py` — it's immediately on PATH.

---

## Tier 2 — Multi-module packages

For tools that grow beyond a single file: multiple modules, shared utilities,
or heavier dependency trees.

**Location:** a subdirectory with a `pyproject.toml`

```
toolbox/
  my-tool/
    pyproject.toml
    src/
      my_tool/
        __init__.py
        cli.py
        utils.py
```

**`pyproject.toml` minimum:**

```toml
[project]
name = "my-tool"
version = "0.1.0"
requires-python = "==3.12"
dependencies = ["click", "httpx"]

[project.scripts]
my-tool = "my_tool.cli:main"
```

**Activation:** `home-manager switch` — the activation script in `uvx.nix`
auto-discovers any subdirectory with a `pyproject.toml` and runs:

```bash
uv tool install --editable ~/toolbox/my-tool
```

This places `my-tool` in `~/.local/bin` (already on PATH). Because it is an
editable install, edits to source files are reflected immediately with no
reinstall needed. Adding or changing dependencies requires re-running
`home-manager switch` (or `uv tool install --editable ~/toolbox/my-tool`
directly).

---

## Choosing a tier

| | Tier 1 | Tier 2 |
|---|---|---|
| Single file | yes | no |
| Multiple modules | no | yes |
| Edit → run | instant | instant (editable) |
| New dep | edit file header | edit pyproject.toml + switch |
| Command name | `my-script.py` (or alias) | clean name from entry point |
