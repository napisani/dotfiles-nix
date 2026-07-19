# tmux-picker Quickjump Tags Implementation Plan

**Goal:** Add bracketed home-row quickjump tags to each session row, per
`docs/superpowers/specs/2026-07-18-tmux-picker-quickjump-design.md`.

**Architecture:** New `quickjump.py` assigns tags to an already-sorted
session list. `workmux.format_session_lines` is removed; `cli.py` gains
`_format_lines`, assembling status + tag + name itself from
`workmux.build_state_map()` and `quickjump.assign_tags()`.

**Tech Stack:** Python 3.12, argparse, pytest, `itertools` (stdlib).

---

## File Structure

- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/quickjump.py` (new)
- `mods/dotfiles/toolbox/tmux-picker/tests/test_quickjump.py` (new)
- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/workmux.py`: remove `format_session_lines`
- `mods/dotfiles/toolbox/tmux-picker/tests/test_workmux.py`: remove its tests
- `mods/dotfiles/toolbox/tmux-picker/src/tmux_picker/cli.py`: add `_format_lines`; update `_cmd_list`/`_cmd_pick`
- `mods/dotfiles/toolbox/tmux-picker/tests/test_cli.py`: update accordingly

## Task 1: `quickjump.py` — Tag Generation

**Files:**
- Create: `tests/test_quickjump.py`
- Create: `src/tmux_picker/quickjump.py`

- [ ] **Step 1: Write failing tests**

```python
from tmux_picker import quickjump


def test_assign_tags_uses_two_chars_for_small_counts():
    sessions = ["a", "b", "c"]

    result = quickjump.assign_tags(sessions)

    assert [tag for _, tag in result] == ["ff", "fj", "fd"]


def test_assign_tags_pairs_are_unique():
    sessions = [f"s{i}" for i in range(50)]

    result = quickjump.assign_tags(sessions)

    tags = [tag for _, tag in result]
    assert len(set(tags)) == len(tags)
    assert all(len(tag) == 2 for tag in tags)


def test_assign_tags_preserves_input_order():
    sessions = ["first", "second", "third"]

    result = quickjump.assign_tags(sessions)

    assert [name for name, _ in result] == sessions


def test_assign_tags_scales_to_three_chars_past_two_char_capacity():
    sessions = [f"s{i}" for i in range(600)]  # > 24**2 == 576

    result = quickjump.assign_tags(sessions)

    tags = [tag for _, tag in result]
    assert all(len(tag) == 3 for tag in tags)
    assert len(set(tags)) == len(tags)


def test_assign_tags_empty_list():
    assert quickjump.assign_tags([]) == []
```

- [ ] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_quickjump.py -q
```

Expected: FAIL (module doesn't exist).

- [ ] **Step 3: Implement**

```python
import itertools

KEYS = "fjdkslgheirutycnvmowa;qp"


def assign_tags(sessions: list[str]) -> list[tuple[str, str]]:
    n = 2
    while len(KEYS) ** n < len(sessions):
        n += 1
    tags = itertools.islice(
        ("".join(combo) for combo in itertools.product(KEYS, repeat=n)),
        len(sessions),
    )
    return list(zip(sessions, tags))
```

- [ ] **Step 4: Run tests, verify GREEN**

Same command as Step 2. Expected: PASS.

## Task 2: Remove `workmux.format_session_lines`

**Files:**
- Modify: `tests/test_workmux.py`
- Modify: `src/tmux_picker/workmux.py`

- [ ] **Step 1: Delete its tests**

Remove `test_format_session_lines_no_state_when_none_present`,
`test_format_session_lines_prefixes_with_state_or_spaces`, and
`test_format_session_lines_makes_a_single_tmux_call` from
`test_workmux.py`. Keep the `build_state_map` tests as-is.

- [ ] **Step 2: Remove the function**

Delete `format_session_lines` from `workmux.py`.

- [ ] **Step 3: Run workmux tests, verify GREEN**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_workmux.py -q
```

Expected: PASS (only `build_state_map` tests remain).

## Task 3: `cli.py` — `_format_lines` and Wiring

**Files:**
- Modify: `tests/test_cli.py`
- Modify: `src/tmux_picker/cli.py`

- [ ] **Step 1: Write failing tests**

```python
def test_format_lines_inserts_tag_between_status_and_name(monkeypatch):
    monkeypatch.setattr(cli.workmux, "build_state_map", lambda: {"alpha": "🤖"})
    monkeypatch.setattr(
        cli.quickjump, "assign_tags", lambda sessions: [(s, "ff") for s in sessions]
    )

    lines = cli._format_lines(["alpha", "beta"])

    assert lines == ["🤖 [ff] alpha\talpha", "   [ff] beta\tbeta"]


def test_format_lines_no_padding_when_no_session_has_status(monkeypatch):
    monkeypatch.setattr(cli.workmux, "build_state_map", lambda: {})
    monkeypatch.setattr(
        cli.quickjump, "assign_tags", lambda sessions: [(s, "ff") for s in sessions]
    )

    lines = cli._format_lines(["alpha"])

    assert lines == ["[ff] alpha\talpha"]
```

Update `test_list_command_prints_formatted_lines` and
`test_pick_command_builds_expected_fzf_invocation` to fake
`cli._format_lines` directly (isolating them from `_format_lines`'s own
internals, which are covered by the tests above) instead of the removed
`workmux.format_session_lines`.

- [ ] **Step 2: Run tests, verify RED**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests/test_cli.py -q
```

Expected: FAIL (`_format_lines` doesn't exist; old tests reference the
removed `workmux.format_session_lines`).

- [ ] **Step 3: Implement**

Add `quickjump` import. Add `_format_lines`:

```python
def _format_lines(sessions: list[str]) -> list[str]:
    status_map = workmux.build_state_map()
    tag_map = dict(quickjump.assign_tags(sessions))
    has_any_status = any(status_map.values())

    lines = []
    for session in sessions:
        status = status_map.get(session, "")
        prefix = f"{status} " if status else ("   " if has_any_status else "")
        lines.append(f"{prefix}[{tag_map[session]}] {session}\t{session}")
    return lines
```

Update `_cmd_list` and `_cmd_pick` to call `_format_lines(sessions)` instead
of `workmux.format_session_lines(sessions)`.

- [ ] **Step 4: Run tests, verify GREEN**

Same command as Step 2. Expected: PASS.

## Task 4: Full Verification

- [ ] **Step 1: Run full test suite**

```bash
rtk uv run --with pytest pytest mods/dotfiles/toolbox/tmux-picker/tests -q
```

Expected: all tests pass.

- [ ] **Step 2: Re-verify against the live tmux server**

```bash
tmux-picker list
```

Expected: every line shows `[XX]` (or `[XXX]`) between the status column and
the session name, tags unique, most-recent session gets `[ff]`.

- [ ] **Step 3: Review diff**

```bash
git diff --stat -- mods/dotfiles/toolbox/tmux-picker
```

Expected: diff touches only `quickjump.py`, `workmux.py`, `cli.py`, and
their tests.
