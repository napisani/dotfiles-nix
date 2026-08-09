# tmux-picker Python Refactor Implementation Plan

**Goal:** Reimplement `tmux-session-picker.sh` and `tmux-session-kill.sh` as a
Python `toolbox` package (`tmux-picker`), preserving behavior exactly, per
`docs/superpowers/specs/2026-07-18-tmux-picker-python-refactor-design.md`.

**Architecture:** A `tmux.py` seam wraps every `tmux` shell-out as a plain
function; `workmux.py` and `kill.py` build on that seam and are unit-tested
without a real tmux server; `cli.py` exposes `list`, `kill`, and `pick` as
Click subcommands. `.tmux.conf` is updated to invoke `tmux-picker pick`, and
the old bash scripts are removed.

**Tech Stack:** Python 3.12, Click, pytest, uv (editable `toolbox` install
via `mods/uvx.nix`).

---

## File Structure

- `mods/dotfiles/toolbox/tmux-picker/pyproject.toml`: package manifest.
- `mods/dotfiles/toolbox/tmux-picker/Makefile`: `test`/`install` targets.
- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/tmux.py`: `tmux` binary wrapper.
- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/workmux.py`: status aggregation.
- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/kill.py`: smart-kill logic.
- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/cli.py`: `list`/`kill`/`pick` subcommands.
- `mods/dotfiles/toolbox/tmux-picker/tests/test_tmux.py`
- `mods/dotfiles/toolbox/tmux-picker/tests/test_workmux.py`
- `mods/dotfiles/toolbox/tmux-picker/tests/test_kill.py`
- `mods/dotfiles/toolbox/tmux-picker/tests/test_cli.py`
- `mods/dotfiles/.tmux.conf`: update the `bind f` line.
- Remove: `mods/dotfiles/shell_scripts/tmux-session-picker.sh`, `tmux-session-kill.sh`.

## Task 1: Package Scaffold + `tmux.py` Seam

**Files:**
- Create: `pyproject.toml`, `Makefile`
- Create: `src/tmux_picker/__init__.py`, `src/tmux_picker/tmux.py`
- Create: `tests/test_tmux.py`

- [x] **Step 1: Scaffold package manifest and Makefile**

Same shape as `read-aloud`/`stackman`: `hatchling` backend,
`requires-python = "==3.12.*"`, `dependencies = ["click>=8.1,<9"]`,
`[project.scripts] tmux-picker = "tmux_picker.cli:main"`.

- [x] **Step 2: Write failing `tmux.py` tests**

`tmux.py` functions shell out via `subprocess.run`/`subprocess.check_output`.
Tests monkeypatch `subprocess.run` to assert the exact `tmux` argv built for
each function, and to feed back canned stdout.

```python
def test_list_sessions_builds_expected_argv_and_parses_lines(monkeypatch):
    ...  # assert argv == ["tmux", "list-sessions", "-f", "<expr>", "-F", "#S"]
         # stdout "a\nb\n" -> ["a", "b"]

def test_list_sessions_returns_empty_on_nonzero_exit(monkeypatch):
    ...  # simulate CalledProcessError -> []

def test_has_session_true_and_false(monkeypatch):
    ...

def test_kill_session_builds_expected_argv(monkeypatch):
    ...

def test_switch_client_builds_expected_argv(monkeypatch):
    ...

def test_list_windows_returns_empty_on_missing_session(monkeypatch):
    ...

def test_list_panes_parses_first_pane_path(monkeypatch):
    ...
```

- [x] **Step 3: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_tmux.py -q
```

Expected: FAIL (module doesn't exist yet).

- [x] **Step 4: Implement `tmux.py`**

Functions: `list_sessions(filter_expr)`, `list_windows(session)`,
`list_panes(session)`, `has_session(session)`, `kill_session(session)`,
`switch_client(session)`. Every "not found"/nonzero-exit case returns
`[]`/`False`, matching the bash's `2>/dev/null || true`.

- [x] **Step 5: Run tests, verify GREEN**

Same command as Step 3. Expected: PASS.

## Task 2: `workmux.py` Status Aggregation

**Files:**
- Create: `src/tmux_picker/workmux.py`
- Create: `tests/test_workmux.py`

- [x] **Step 1: Write failing tests**

```python
def test_get_state_dedupes_and_joins_statuses(monkeypatch):
    # list_windows returns ["🤖", "🤖", "💬", ""] -> "🤖 💬"

def test_get_state_empty_when_no_statuses(monkeypatch):
    # list_windows returns ["", ""] -> ""

def test_format_session_lines_no_state_when_none_present():
    # has_any_state False -> plain "session\tsession" lines, no prefix

def test_format_session_lines_prefixes_with_state_or_spaces():
    # has_any_state True -> "🤖 session\tsession" / "   session\tsession"
```

- [x] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_workmux.py -q
```

- [x] **Step 3: Implement `workmux.py`**

`get_state(session) -> str` (uses `tmux.list_windows`, dedupes/joins per the
bash `awk` logic) and `format_session_lines(sessions: list[str]) -> list[str]`
(replicates the two-pass `_list_sessions` prefixing logic).

- [x] **Step 4: Run tests, verify GREEN**

## Task 3: `kill.py` Smart-Kill Logic

**Files:**
- Create: `src/tmux_picker/kill.py`
- Create: `tests/test_kill.py`

- [x] **Step 1: Write failing tests**

```python
def test_kill_popup_session_kills_directly(monkeypatch):
    # session "_popup_foo" -> only kill_session("_popup_foo") called

def test_kill_workmux_session_removes_worktree(monkeypatch, tmp_path):
    # icon-prefixed session, pane path resolves to a repo with .workmux.yaml
    # -> Popen called with detached kwargs, workmux remove --force in argv

def test_kill_workmux_session_falls_back_when_worktree_detection_fails(monkeypatch):
    # icon-prefixed session, git/`.workmux.yaml` lookup raises/returns None
    # -> falls back to killing popup companion + session directly (no Popen)

def test_kill_regular_session_kills_popup_companion_then_session(monkeypatch):
    # plain session name -> kill_session called for "_popup_<name>_scratch"
    # then for the session itself
```

- [x] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_kill.py -q
```

- [x] **Step 3: Implement `kill.py`**

Port the three branches from `tmux-session-kill.sh` 1:1, including the
`WORKMUX_PREFIX = ""` constant (copy the exact codepoint, do not
retype by hand) and the detached `Popen(..., start_new_session=True,
stdin=DEVNULL, stdout=DEVNULL, stderr=DEVNULL)` for the slow
`workmux remove --force` path. Preserve the deliberate fallback-on-failure
behavior from the bash comment at `tmux-session-kill.sh:49-52`.

- [x] **Step 4: Run tests, verify GREEN**

## Task 4: `cli.py` Subcommands

**Files:**
- Create: `src/tmux_picker/cli.py`
- Create: `tests/test_cli.py`

- [x] **Step 1: Write failing tests**

```python
def test_list_command_prints_formatted_lines(monkeypatch, cli_runner):
    ...

def test_kill_command_invokes_kill_session(monkeypatch, cli_runner):
    ...

def test_pick_command_builds_expected_fzf_invocation(monkeypatch, cli_runner):
    # assert the subprocess.run call for fzf includes the same --bind strings
    # as today's script, and that tmux-picker list's output is piped in
```

- [x] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_cli.py -q
```

- [x] **Step 3: Implement `cli.py`**

Click group with `list`, `kill <session>`, and `pick`. `pick` shells out to
`fzf` with the same `--reverse --delimiter=$'\t' --with-nth=1 --header`
options and `--bind` strings as the current script, substituting
`tmux-picker kill {2}` / `tmux-picker list` for the old script names.

- [x] **Step 4: Run tests, verify GREEN**

## Task 5: Wire In and Remove Old Scripts

**Files:**
- Modify: `mods/dotfiles/.tmux.conf`
- Delete: `mods/dotfiles/shell_scripts/tmux-session-picker.sh`
- Delete: `mods/dotfiles/shell_scripts/tmux-session-kill.sh`

- [x] **Step 1: Update the tmux binding**

Change `.tmux.conf:162` from `bind f display-popup -E
"tmux-session-picker.sh"` to `bind f display-popup -E "tmux-picker pick"`.

- [x] **Step 2: Remove the old bash scripts**

Delete both files now that their logic is fully ported.

- [x] **Step 3: Full test suite + review**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests -q
rtk git diff --stat -- mods/dotfiles/toolbox/tmux-picker mods/dotfiles/.tmux.conf mods/dotfiles/shell_scripts
```

Expected: all tests pass; diff touches only the new package, the tmux
binding, and the two deleted scripts.

- [ ] **Step 4: Rebuild and manually verify** *(requires the user's machine)*

`home-manager switch`, then confirm `tmux-picker` is on `PATH`, pressing `f`
opens the popup picker, `enter` switches sessions, and `ctrl-x` kills +
refreshes — no observable UX change from before.
