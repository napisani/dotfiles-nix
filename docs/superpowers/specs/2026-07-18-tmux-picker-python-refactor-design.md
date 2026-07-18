# tmux-picker Python Refactor Design

**Status:** approved for planning
**Date:** 2026-07-18
**Scope:** `mods/dotfiles/toolbox/tmux-picker` (new), `mods/dotfiles/shell_scripts/tmux-session-picker.sh` and `tmux-session-kill.sh` (removed), `mods/dotfiles/.tmux.conf` (binding update)

## Purpose

The custom tmux session picker currently lives as two bash scripts:
`tmux-session-picker.sh` (fzf-driven session list with Workmux status
indicators) and `tmux-session-kill.sh` (smart session removal with
Workmux-worktree awareness). The logic has grown branchy enough — status
aggregation, a three-way kill decision, a self-regenerating temp-file reload
script — that it's becoming hard to change safely in bash.

This is a **maintainability-only refactor**: reimplement the existing
behavior in Python, in `toolbox/`, following the conventions already
established by `stackman`. No new user-facing features are in scope; those
will be scoped and designed separately once this foundation exists.

## Non-Goals

- No new picker features (multi-select, preview pane, config file, etc.) —
  follow-up work, separate design.
- No change to the interactive UX or keybindings as experienced by the user.
- No replacement of fzf as the picker UI.

## Package Layout

Tier-2 toolbox package, same shape as `stackman`:

```
toolbox/tmux-picker/
  pyproject.toml
  src/tmux_picker/
    __init__.py
    cli.py        # click group: list, kill, pick
    tmux.py       # thin wrapper around the `tmux` binary
    workmux.py    # per-session status aggregation
    kill.py       # the 3-branch smart-kill logic
  tests/
    test_workmux.py
    test_kill.py
    test_cli.py
```

`pyproject.toml`: `hatchling` build backend, `requires-python = "==3.12.*"`,
`dependencies = ["click"]`, `[project.scripts] tmux-picker =
"tmux_picker.cli:main"`. Auto-discovered by the existing
`home.activation.installUvTools` loop in `mods/uvx.nix` — no Nix changes
required.

### `tmux.py` — the seam

Every current shell-out becomes a plain Python function returning parsed
data instead of raw text:

- `list_sessions(filter_expr: str) -> list[str]`
- `list_windows(session: str) -> list[str]` (raw `@workmux_status` values)
- `list_panes(session: str) -> list[str]` (pane cwd paths)
- `has_session(session: str) -> bool`
- `kill_session(session: str) -> None`
- `switch_client(session: str) -> None`

`kill.py`, `workmux.py`, and `cli.py` never call `subprocess` directly —
they only go through `tmux.py`. This is what makes the branchy kill logic
unit-testable without a real tmux server: tests fake `tmux.py`, not the OS.

## CLI / tmux / fzf Integration

`.tmux.conf:162` changes from:

```
bind f display-popup -E "tmux-session-picker.sh"
```

to:

```
bind f display-popup -E "tmux-picker pick"
```

- **`tmux-picker pick`** — the entry point. Builds the `fzf` subprocess call
  with the same bindings as today, piping `tmux-picker list`'s output in as
  the initial candidate set:

  ```
  --bind "enter:execute(tmux switch-client -t {2})+accept"
  --bind "ctrl-x:execute-silent(tmux-picker kill {2})+reload(tmux-picker list)"
  ```

- **`tmux-picker list`** — replaces `_list_sessions`. Filters sessions via
  the same `SESSION_FILTER` tmux format-string (passed straight through to
  `tmux list-sessions -f`, not reimplemented), calls `workmux.py` per
  session, and prints the same `<display>\t<raw_name>` lines. Because it's
  now a real installed subcommand, fzf's `reload()` bind calls it directly.
  **The `mktemp`/`trap`/heredoc self-cloning reload script is eliminated
  entirely** — this is the single biggest simplification of the rewrite.

- **`tmux-picker kill <session>`** — replaces `tmux-session-kill.sh` 1:1:
  same three branches (popup / Workmux worktree / regular). The slow
  `workmux remove --force` path still detaches so the picker isn't blocked:
  `subprocess.Popen(..., start_new_session=True, stdin=DEVNULL,
  stdout=DEVNULL, stderr=DEVNULL)`, the Python equivalent of today's `nohup
  ... & disown`.

## Error Handling

Mirrors what's already defensive in the bash, made explicit instead of
relying on scattered `set -e` / `|| true`:

- `tmux.py` functions return empty results (not exceptions) for expected
  "not found" cases (`has_session` → `False`, `list_windows` → `[]`),
  matching today's `2>/dev/null || true` pattern.
- `kill.py`'s Workmux-detection path (git common-dir lookup, `.workmux.yaml`
  check) explicitly falls through to the "kill popup + session directly"
  fallback branch on any failure — this was a deliberate bug fix in the bash
  version (see the comment at `tmux-session-kill.sh:49-52` about
  `set -e`/pipefail swallowing the fallback), and the Python version must
  preserve that fallback behavior rather than losing it.
- `pick` / `list` do not need defensive handling beyond this — if `tmux`
  itself is unreachable, that's a hard failure, not something to paper over.

## Testing

The main payoff of the rewrite:

- `test_workmux.py`: pure function tests for status aggregation (dedup,
  join, empty-state) against fake `tmux list-windows` output.
- `test_kill.py`: all three kill branches, each driven by faking `tmux.py`'s
  functions, plus a case asserting the fallback path triggers when
  git/`.workmux.yaml` detection fails.
- `test_cli.py`: Click's `CliRunner` for `list` / `kill` argument handling
  and output formatting.

Nothing talks to a real tmux server or real `workmux` binary — everything
goes through the `tmux.py` seam, same spirit as `stackman`'s
`git_repo_fixture` isolating git operations.

## Migration Plan

1. Add `toolbox/tmux-picker/` with the layout above.
2. Port `_list_sessions` → `tmux-picker list`.
3. Port `tmux-session-kill.sh` → `tmux-picker kill`.
4. Add `tmux-picker pick` as the fzf-wrapping entry point.
5. Update `.tmux.conf:162` to invoke `tmux-picker pick`.
6. Remove `mods/dotfiles/shell_scripts/tmux-session-picker.sh` and
   `tmux-session-kill.sh`.
7. `home-manager switch` to pick up the new toolbox package and the
   `.tmux.conf` change.

## Verification

- `uv tool install --editable toolbox/tmux-picker` succeeds and
  `tmux-picker` is on `PATH`.
- `tmux-picker list` output is byte-for-byte equivalent to the current
  `_list_sessions` output for a given tmux state (with/without Workmux
  status present).
- `tmux-picker kill` exercised against all three session-name shapes
  (`_popup_*`, Workmux-icon-prefixed, regular) produces the same tmux/
  workmux side effects as the bash version.
- Pressing `f` in tmux still opens the popup picker; `enter` switches,
  `ctrl-x` kills and refreshes the list — no observable UX change.
- `pytest` passes for all three test modules.

## Risks

- The detached-background kill path (`workmux remove --force`) is
  inherently hard to test end-to-end; tests will verify the `Popen` call is
  constructed correctly (detached, right args) rather than exercising a real
  `workmux remove`.
- The Workmux icon prefix (`\xef\x90\x98`, a 3-byte UTF-8 nerd-font
  character) must be carried over as an exact byte match — a source of
  subtle bugs if re-typed instead of copied.

## Recommendation

Implement `toolbox/tmux-picker` as a single tier-2 package with `list`,
`kill`, and `pick` subcommands, following `stackman`'s structure and test
conventions. Treat this strictly as a behavior-preserving rewrite; new
picker features are a separate follow-up design once this foundation is in
place.
