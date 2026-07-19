# tmux-picker Quickjump Tags Design

**Status:** approved for planning
**Date:** 2026-07-18
**Scope:** `mods/dotfiles/toolbox/tmux-picker`

## Purpose

Add a short, typeable identifier to each session row in the picker, shown in
square brackets between the Workmux status prefix and the session name
(e.g. `🤖 [fj] home`), so the user can type those characters to quickly
narrow the fzf list to one session.

## Matching Behavior (Trade-off, Accepted)

fzf's default matching is fuzzy (subsequence), not exact substring, and this
stays unchanged. Typing a tag like `fj` is a strong practical convenience,
not a hard isolation guarantee -- it could in rare cases also
fuzzy-subsequence-match unrelated text in another row. Forcing a hard
guarantee would require either exact-substring matching globally (changing
today's fuzzy partial-name search) or restricting search to only the tag
field (removing fuzzy name search entirely). Neither trade-off is worth it;
the tag is additive convenience on top of unchanged search behavior.

## Algorithm -- `quickjump.py`

```python
KEYS = "fjdkslgheirutycnvmowa;qp"  # ergonomic priority, best reach first

def assign_tags(sessions: list[str]) -> list[tuple[str, str]]:
    ...
```

- Smallest `n`, starting at 2, such that `len(KEYS) ** n >= len(sessions)`
  (repeated characters allowed within a tag, e.g. `ff` -- simpler capacity
  math, no ergonomic downside, and 2 chars already covers 576 combinations,
  far more than any realistic session count).
- Tags enumerate `itertools.product(KEYS, repeat=n)` in the given key order
  (first character varies slowest), taking the first `len(sessions)` combos.
- Tags are zipped 1:1 with `sessions` in the order given by the caller. Since
  callers always pass the already recency-sorted list, the most-recently-used
  session naturally gets the ergonomically-easiest tag (`ff`) -- an emergent
  property of simple zipping, not a separate rule.
- Tags are recomputed fresh on every render (no persistence, no stability
  across picker opens) -- consistent with this project's "read live tmux
  state, no custom state management" philosophy established for recency
  sorting.

## Line Assembly -- `cli.py` Owns It

`workmux.py` and `quickjump.py` each stay single-purpose, returning plain
per-session data (a status map, a tag map) rather than formatted lines.
`workmux.format_session_lines` -- which today does status lookup, assembly,
*and* the "only show blank-padding columns if at least one session has a
status" logic all in one function -- is removed (along with its tests) as
part of this change. `cli.py` gains the sole responsibility of assembling
the final display line:

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

This is a deliberate simplification of `workmux.py`'s public surface (one
fewer function, moved into the one place that actually needs to know about
final line layout), not scope creep -- called out explicitly here since it
changes an existing tested contract.

## Data Flow

1. `tmux.list_sessions(SESSION_FILTER)` -- unchanged, one tmux call.
2. `_sort_by_recency(...)` -- unchanged.
3. `_format_lines(sessions)` -- new: `workmux.build_state_map()` (existing,
   unchanged) + `quickjump.assign_tags(sessions)` (new) assembled into final
   lines.
4. `pick` pipes those lines into fzf exactly as before -- no changes to the
   fzf invocation, `--bind` wiring, or delimiter/field structure (the raw
   session name stays in the hidden second tab-delimited field, used for
   `switch-client`/`kill` targeting).

## Module Changes

- `quickjump.py` (new): `assign_tags(sessions: list[str]) -> list[tuple[str, str]]`.
- `workmux.py`: remove `format_session_lines`; `build_state_map` unchanged.
- `cli.py`: add `_format_lines`; `_cmd_list`/`_cmd_pick` call it instead of
  `workmux.format_session_lines`.

## Testing

- `test_quickjump.py` (new): capacity scaling (asserts `n=2` for small
  counts, `n=3`/`n=4` once counts exceed `24**2`/`24**3` -- constructed with
  a small counts list, not literally 577+ real sessions), tag uniqueness for
  a given count, and that tags are assigned in the given (already-sorted)
  order.
- `test_workmux.py`: remove the now-deleted `format_session_lines` tests;
  `build_state_map` tests are unchanged.
- `test_cli.py`: new tests for `_format_lines` -- status+tag+name assembly,
  blank-padding-only-when-some-session-has-status behavior (carried over
  from the old `format_session_lines` tests), and tag insertion position.
  Update `test_list_command_prints_formatted_lines` /
  `test_pick_command_builds_expected_fzf_invocation` for the new call shape.

## Non-Goals

- No hard isolation guarantee for quickjump tags (see Matching Behavior).
- No tag persistence/stability across picker opens.
- No change to the fzf invocation itself, `--bind` wiring, or the hidden
  raw-session-name field used for switch/kill targeting.

## Recommendation

Add `quickjump.py` as a small, independent module producing a session-to-tag
map; remove `workmux.format_session_lines` in favor of `cli.py` owning line
assembly directly from `workmux.build_state_map()` and
`quickjump.assign_tags()`.
