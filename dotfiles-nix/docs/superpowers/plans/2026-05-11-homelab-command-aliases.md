# Homelab Command Aliases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local shell commands that run homelab apps on the correct server, using local execution when already on the target host and SSH otherwise.

**Architecture:** Implement the real behavior in a focused toolbox script, `mods/dotfiles/toolbox/homelab.py`, and keep shell-facing commands in `mods/dotfiles/.bashrc.d/0140_homelab.bashrc`. The Python script owns server config, host resolution, Tailscale discovery, command construction, and process execution.

**Tech Stack:** Python 3.12 standard library, bash functions, existing Home Manager dotfile symlinks.

---

### Task 1: Homelab Launcher Tests

**Files:**
- Create: `mods/dotfiles/toolbox/tests/homelab_test.py`
- Create: `mods/dotfiles/toolbox/homelab.py`

- [ ] **Step 1: Write failing tests**

Cover:

- `supermicro` has user `nick` and LAN candidate `192.168.1.51`.
- `maclab` has user `nick` and LAN candidate `192.168.1.52`.
- local hostname match resolves to local execution.
- hostname candidate is ordered before LAN IP.
- Tailscale JSON discovery extracts matching host IPs.
- `kubectl` and `k9s` command specs forward arguments.
- `macimessage` command includes `pgrep`, `nohup imsg serve`, and `exec itui`.

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
uv run --with pytest pytest mods/dotfiles/toolbox/tests/homelab_test.py -q
```

Expected: fail because `homelab.py` does not exist yet.

### Task 2: Homelab Launcher Implementation

**Files:**
- Create: `mods/dotfiles/toolbox/homelab.py`
- Test: `mods/dotfiles/toolbox/tests/homelab_test.py`

- [ ] **Step 1: Implement server registry and pure helpers**

Add:

- `SERVERS`
- `CommandSpec`
- hostname normalization
- local-host detection
- Tailscale JSON parsing
- target candidate ordering
- command construction for `run`, `tui`, and `imessage`

- [ ] **Step 2: Implement execution**

Add CLI commands:

- `run <server> -- <command...>`
- `tui <server> -- <command...>`
- `imessage <server>`

Use local subprocess execution when target is local. Use `ssh` with short probe options for remote target checks and `ssh -t` for TUI commands.

- [ ] **Step 3: Run tests and verify pass**

Run:

```bash
uv run --with pytest pytest mods/dotfiles/toolbox/tests/homelab_test.py -q
```

Expected: pass.

### Task 3: Bash Wrappers

**Files:**
- Create: `mods/dotfiles/.bashrc.d/0140_homelab.bashrc`

- [ ] **Step 1: Add shell functions**

Add:

```bash
labkubectl() { homelab.py run supermicro -- kubectl "$@"; }
labk9s() { homelab.py tui supermicro -- k9s "$@"; }
macimessage() { homelab.py imessage maclab; }
```

- [ ] **Step 2: Validate bash syntax**

Run:

```bash
bash -n mods/dotfiles/.bashrc.d/0140_homelab.bashrc
```

Expected: no output and exit code 0.

### Task 4: Verification

**Files:**
- `mods/dotfiles/toolbox/homelab.py`
- `mods/dotfiles/toolbox/tests/homelab_test.py`
- `mods/dotfiles/.bashrc.d/0140_homelab.bashrc`

- [ ] **Step 1: Run focused tests**

```bash
uv run --with pytest pytest mods/dotfiles/toolbox/tests/homelab_test.py -q
```

- [ ] **Step 2: Run existing toolbox tests**

```bash
uv run --with pytest pytest mods/dotfiles/toolbox/tests -q
```

- [ ] **Step 3: Run script help**

```bash
mods/dotfiles/toolbox/homelab.py --help
```

- [ ] **Step 4: Inspect final diff**

```bash
git diff -- mods/dotfiles/toolbox/homelab.py mods/dotfiles/toolbox/tests/homelab_test.py mods/dotfiles/.bashrc.d/0140_homelab.bashrc
```
