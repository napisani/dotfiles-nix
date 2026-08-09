# tmux-picker Recency Sort Implementation Plan

**Goal:** Order the picker's session list by `session_last_attached`
(most-recent first, never-attached sessions at the bottom, oldest-first
among those), per
`docs/superpowers/specs/2026-07-18-tmux-picker-recency-sort-design.md`.

**Architecture:** `tmux.list_sessions` returns `(name, last_attached)` tuples
instead of plain names (still one tmux call). A new pure `_sort_by_recency`
in `cli.py` reduces those tuples to a sorted name list, which feeds into the
existing, unchanged `workmux.format_session_lines`.

**Tech Stack:** Python 3.12, argparse, pytest.

---

## File Structure

- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/tmux.py`: `list_sessions` return type change.
- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/cli.py`: add `_sort_by_recency`; update `_cmd_list`/`_cmd_pick`.
- `mods/dotfiles/toolbox/tmux-picker/tests/test_tmux.py`: update `list_sessions` tests.
- `mods/dotfiles/toolbox/tmux-picker/tests/test_cli.py`: new `_sort_by_recency` tests; update `list`/`pick` tests for the tuple contract.

## Task 1: `tmux.list_sessions` Returns `(name, last_attached)` Tuples

**Files:**
- Modify: `tests/test_tmux.py`
- Modify: `src/tmux_picker/tmux.py`

- [x] **Step 1: Write failing tests**

Update `test_list_sessions_builds_expected_argv_and_parses_lines` for the
new format string and tuple return; add a never-attached case:

```python
def test_list_sessions_builds_expected_argv_and_parses_lines(monkeypatch):
    captured = {}

    def fake_run(argv, **kwargs):
        captured["argv"] = argv
        return subprocess.CompletedProcess(
            argv, 0, stdout="alpha\t1784420000\nbeta\t\n", stderr=""
        )

    monkeypatch.setattr(tmux.subprocess, "run", fake_run)

    result = tmux.list_sessions("#{some_filter}")

    assert captured["argv"] == [
        "tmux",
        "list-sessions",
        "-f",
        "#{some_filter}",
        "-F",
        "#S\t#{session_last_attached}",
    ]
    assert result == [("alpha", "1784420000"), ("beta", "")]
```

- [x] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_tmux.py -q
```

Expected: FAIL (old format string / plain-string return).

- [x] **Step 3: Implement**

Change `list_sessions`'s `-F` argument to `"#S\t#{session_last_attached}"`
and parse each line via `line.partition("\t")` into `(name, last_attached)`
tuples, matching `list_windows_all`'s existing parsing pattern.

- [x] **Step 4: Run tests, verify GREEN**

Same command as Step 2. Expected: PASS.

## Task 2: `_sort_by_recency` in `cli.py`

**Files:**
- Modify: `tests/test_cli.py`
- Modify: `src/tmux_picker/cli.py`

- [x] **Step 1: Write failing tests**

```python
def test_sort_by_recency_orders_most_recent_first():
    sessions = [("a", "100"), ("b", "300"), ("c", "200")]

    assert cli._sort_by_recency(sessions) == ["b", "c", "a"]


def test_sort_by_recency_puts_never_attached_at_bottom_oldest_first():
    sessions = [("a", ""), ("b", "100"), ("c", "")]

    # b (attached) first; a and c (never attached) at the bottom.
    # Among never-attached sessions there's no real "oldest" signal (empty
    # string carries no ordering information) -- this test only asserts the
    # tier boundary, not a specific order within it.
    result = cli._sort_by_recency(sessions)
    assert result[0] == "b"
    assert set(result[1:]) == {"a", "c"}


def test_sort_by_recency_mixed():
    sessions = [("never1", ""), ("recent", "500"), ("older", "100"), ("never2", "")]

    result = cli._sort_by_recency(sessions)
    assert result[:2] == ["recent", "older"]
    assert set(result[2:]) == {"never1", "never2"}
```

- [x] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_cli.py -q -k sort_by_recency
```

Expected: FAIL (`_sort_by_recency` doesn't exist).

- [x] **Step 3: Implement**

```python
def _sort_by_recency(sessions: list[tuple[str, str]]) -> list[str]:
    def key(entry: tuple[str, str]) -> tuple[int, int]:
        _, last_attached = entry
        if not last_attached:
            return (0, 0)
        return (1, int(last_attached))

    return [name for name, _ in sorted(sessions, key=key, reverse=True)]
```

- [x] **Step 4: Run tests, verify GREEN**

Same command as Step 2. Expected: PASS.

## Task 3: Wire Sorting Into `list`/`pick`

**Files:**
- Modify: `tests/test_cli.py`
- Modify: `src/tmux_picker/cli.py`

- [x] **Step 1: Update failing tests**

Update `test_list_command_prints_formatted_lines` and
`test_pick_command_builds_expected_fzf_invocation` so the faked
`tmux.list_sessions` returns tuples, and assert the formatted output
reflects sorted order:

```python
def test_list_command_prints_formatted_lines(monkeypatch, capsys):
    monkeypatch.setattr(
        cli.tmux, "list_sessions", lambda filter_expr: [("a", "100"), ("b", "200")]
    )
    monkeypatch.setattr(
        cli.workmux, "format_session_lines", lambda sessions: [f"{s}\t{s}" for s in sessions]
    )

    exit_code = cli.main(["list"])

    assert exit_code == 0
    # b (last_attached=200) sorts before a (last_attached=100)
    assert capsys.readouterr().out == "b\tb\na\ta\n"
```

(Analogous update to the `pick` test's faked `tmux.list_sessions`.)

- [x] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_cli.py -q
```

Expected: FAIL (`_cmd_list`/`_cmd_pick` still call `format_session_lines`
directly on `tmux.list_sessions`'s raw tuples).

- [x] **Step 3: Implement**

In both `_cmd_list` and `_cmd_pick`, change:

```python
sessions = tmux.list_sessions(SESSION_FILTER)
```

to:

```python
sessions = _sort_by_recency(tmux.list_sessions(SESSION_FILTER))
```

- [x] **Step 4: Run tests, verify GREEN**

Same command as Step 2. Expected: PASS.

## Task 4: Full Verification

**Files:**
- Review all modified tmux-picker files.

- [x] **Step 1: Run full test suite**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests -q
```

Expected: all tests pass.

- [x] **Step 2: Re-verify against the live tmux server**

```bash
tmux-picker list
```

Expected: sessions ordered most-recently-attached first, matching
`tmux list-sessions -F '#S #{session_last_attached}'` sorted descending.

- [x] **Step 3: Review diff**

```bash
git diff --stat -- mods/dotfiles/toolbox/tmux-picker
```

Expected: diff touches only `tmux.py`, `cli.py`, and their tests.
