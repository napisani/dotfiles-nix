# toolbox

Personal CLI utilities and shell replacements, scoped to this dotfiles repo.
Standard-library scripts run directly with Python. Dependency-bearing scripts
can use standard uv inline dependencies; packaged CLIs use mise's built-in
`pipx` backend, not a custom editable installer.

## PR checkouts

`workmux_pr.py --purpose development|review <PR> [...]` delegates to native
Workmux. The shell exposes `workmux-pr` and the review shortcut
`workmux-pr-review`. Review mode uses the static `workmux-review.json` to skip
project setup/file operations and start ordinary Neovim plus the configured agent.
It does not create a registry, pin comparisons, dispatch skills, refresh checkouts,
or perform cleanup. Invoke review, tour, and recap skills manually in the agent.

The profile suppresses project editor-init. Removing a review Session from the
picker runs the project's `pre_remove` teardown through `workmux remove`, like
any other Workmux Session; if that fails, the picker falls back to deleting the
worktree and branch with git. This is not a sandbox for running PR code.

Tests, without installing anything:

```sh
python3 -m unittest discover -s tests -p workmux_pr_test.py
```

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

## Packaged Python CLIs

Declare an explicit version under `[tools]` in `mise/config.toml`, using
`"pipx:<package>" = "<version>"`. Mise provides an isolated installation and
normal shims. Nothing auto-discovers toolbox subdirectories, and no command
mutates system Python. Local development environments stay project-local.
