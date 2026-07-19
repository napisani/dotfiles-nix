# tmux-picker Recency Sort Design

**Status:** approved for planning
**Date:** 2026-07-18
**Scope:** `mods/dotfiles/toolbox/tmux-picker`

## Purpose

Order the session picker's list by most-recently-selected first, so the
session you were just in is at the top and stale sessions sink to the
bottom. "Selected" means switched to via the picker (or attached to
directly) -- not merely had output/activity.

## No New State Needed

tmux already tracks this natively via the `#{session_last_attached}` format
variable, a per-session epoch timestamp. It was empirically confirmed (via a
throwaway pty-backed test client, in a live tmux server) that
`tmux switch-client -t <session>` -- exactly what the picker's existing
`enter` fzf binding runs -- updates the target session's
`session_last_attached` immediately. `#{session_activity}` was considered
and rejected: it updates on any output or keystroke, which is "last used,"
not "last selected." No daemon, no state file, and no persistence layer are
needed; the feature is entirely "read an existing tmux field and sort by
it."

## Data Flow

1. `tmux.list_sessions(SESSION_FILTER)` -- **still one tmux call** --
   extends its format string from `'#S'` to `'#S\t#{session_last_attached}'`
   and returns `list[tuple[str, str]]` (session name, raw last-attached
   string; empty string for a session that has never been attached to).
2. A new pure function in `cli.py`, `_sort_by_recency`, sorts those tuples
   into a plain `list[str]` of session names: most-recently-attached first,
   with never-attached sessions forming their own group at the bottom,
   ordered oldest-first among themselves. This is an explicit two-tier sort
   key (`(has_been_attached, last_attached_epoch)`), not just "treat missing
   as epoch 0" -- the tiering makes the bottom-group invariant explicit and
   directly assertable in tests, rather than an incidental side effect of
   numeric comparison.
3. `workmux.format_session_lines(sorted_names)` -- **unchanged** -- adds the
   Workmux status-emoji prefixes in whatever order it's given.
4. `pick` pipes the resulting lines into fzf as today. fzf preserves input
   order when the query is empty (it only re-ranks once the user starts
   typing), so the recency order is exactly what's visible on open.

`kill.py`, `workmux.py`'s internals, and the fzf `--bind` wiring are all
unchanged.

## Module Changes

- `tmux.py`: `list_sessions(filter_expr)` return type changes from
  `list[str]` to `list[tuple[str, str]]`.
- `cli.py`: add `_sort_by_recency(sessions: list[tuple[str, str]]) ->
  list[str]`. `_cmd_list` and `_cmd_pick` both change from
  `tmux.list_sessions(SESSION_FILTER)` to
  `_sort_by_recency(tmux.list_sessions(SESSION_FILTER))` before calling
  `workmux.format_session_lines`.

## Testing

- `test_tmux.py`: update the existing `list_sessions` argv/parsing test for
  the new format string and tuple return; add a case for a never-attached
  session (empty second field parses to `("name", "")`).
- `test_cli.py`: new direct tests for `_sort_by_recency` -- most-recent-first
  ordering, never-attached sessions sinking to the bottom in oldest-first
  order among themselves, and a mixed case combining both. Update
  `test_list_command_prints_formatted_lines` and
  `test_pick_command_builds_expected_fzf_invocation` to fake
  `tmux.list_sessions` returning tuples (matching the new contract) and
  assert the output reflects sorted order.
- `test_workmux.py`: no changes -- `format_session_lines`'s contract is
  untouched.

## Non-Goals

- No change to which sessions appear (the existing `SESSION_FILTER` is
  unchanged) -- only their order.
- No special-casing of the currently-attached session (e.g. excluding it or
  pinning it); it sorts by its own `session_last_attached` like any other
  session, matching existing behavior of including it in the list at all.
- No persistence across tmux server restarts beyond what tmux itself
  retains -- this is intentionally just a read of live tmux state.

## Recommendation

Extend `tmux.list_sessions` to carry `session_last_attached` alongside the
name (still one tmux call), add a small pure `_sort_by_recency` function in
`cli.py`, and apply it before the existing, unchanged
`workmux.format_session_lines` formatting step.
