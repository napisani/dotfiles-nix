# tmux-picker Popover Guard Design

**Status:** approved for planning
**Date:** 2026-07-18
**Scope:** `mods/dotfiles/.tmux.conf`

## Purpose

Pressing `prefix+f` while inside the scratch popover (opened via `prefix+o`,
a `_popup_*`-named session) accidentally switches the session displayed
*inside* the popover, making it hard to get back to -- or close -- the
popover. `prefix+f` should be a complete no-op while inside a `_popup_*`
session.

## Design

`.tmux.conf`'s `f` binding gains the same `if-shell` guard already used for
`o` and `q` in the same file, with an empty-string true-branch instead of
`detach` -- pressing `f` inside a popover does nothing at all, rather than
closing the popover (that's already `o`/`q`'s job):

```
unbind f
bind f if-shell 'tmux display -p "#{session_name}" | grep -q "_popup_"' '' 'display-popup -E "tmux-picker pick"'
```

An empty string as `if-shell`'s true-branch command was verified directly
against the live tmux server (`tmux if-shell 'true' '' '...'` exits 0 with
no visible effect and does not run the false-branch command) -- it is a
genuine no-op, not a placeholder.

## Scope

Matches the existing `o`/`q` guards exactly: only `_popup_*` session names
trigger the guard, not `_proctmux*`. This is specifically about the
`prefix+o` scratch popover the user described; `_proctmux*` sessions aren't
that popover, and none of the existing `o`/`q`/kill guards treat them
specially either.

## Non-Goals

- No change to `tmux-picker` (the Python package) -- this is entirely a
  keybinding-level guard in `.tmux.conf`.
- No change to `o`/`q`'s existing detach-on-popover behavior.

## Testing

Manual verification only (a tmux keybinding, not a unit-testable function):
confirm `prefix+f` inside a `_popup_*` session does nothing, and still opens
the picker normally everywhere else.

## Recommendation

Add the `if-shell` guard to the `f` binding, mirroring the existing `o`/`q`
idiom with an empty no-op true-branch.
