# tmux Behavior

**Prefix:** `C-Space` (Ctrl+Space)  
**Chord spelling:** `prefix+X` means press prefix, release, then press X; `-n` bindings require no prefix  
**Copy mode:** vi keybindings; enter with `prefix+[`  
**Config:** `mods/dotfiles/.tmux.conf` (flat file, one level up from this directory)  
**Cross-reference:** Neovim split navigation is unified with tmux pane navigation — see `nvim/BEHAVIOR.md` § Motions & Navigation

---

## Philosophy

- Pane navigation uses `<C-hjkl>` with no prefix, unified with Neovim splits; the boundary between editor and terminal should be invisible.
- When a pane is zoomed, moving to another pane preserves the zoom state — the destination pane zooms in automatically.
- Popup overlays (sessions, windows, AI tools) appear at 90% of the screen and can be dismissed by re-triggering or pressing `q`.
- Session switching hides internal plumbing sessions (`_popup_*`, `_proctmux*`) by default; an alternate binding shows all sessions.
- Copy mode mirrors vim: `v` to select, `y` to yank to system clipboard, `C-v` for rectangle select.

---

## Pane navigation (no prefix)

`C-h` → leaf: move focus to the left pane (passes through to Neovim if Neovim is focused)  
`C-j` → leaf: move focus to the pane below (passes through to Neovim if Neovim is focused)  
`C-k` → leaf: move focus to the pane above (passes through to Neovim if Neovim is focused)  
`C-l` → leaf: move focus to the right pane (passes through to Neovim if Neovim is focused)  
`C-\` → leaf: move focus to the last-active pane (passes through to Neovim if Neovim is focused)

---

## Pane navigation (with prefix)

`prefix+h` → leaf: select pane to the left; if pane was zoomed, destination is also zoomed  
`prefix+j` → leaf: select pane below; zoom-aware  
`prefix+k` → leaf: select pane above; zoom-aware  
`prefix+l` → leaf: select pane to the right; zoom-aware

---

## Splits

`prefix+"` → leaf: open a new horizontal split in the current pane's directory  
`prefix+%` → leaf: open a new vertical split in the current pane's directory

---

## Session management

`prefix+f` → domain: session switcher  
`prefix+f` → contract: shows only user-facing sessions (hides `_popup_*` and `_proctmux*` internal sessions); supports OpenCode status indicators  
`prefix+f` → leaf: open fuzzy session picker; Enter switches, `C-x` kills the selected session

`prefix+F` → leaf: open tree session chooser filtered to user-facing sessions only (no popup sessions)  
`prefix+C-f` → leaf: open tree session chooser showing ALL sessions including internal ones  
`prefix+$` → leaf: rename current session (tmux default)  
`prefix+d` → leaf: detach from current session (tmux default)

---

## Window management

`prefix+e` → leaf: open fuzzy window picker across all user-facing sessions; Enter switches to selected window  
`prefix+c` → leaf: create a new window (tmux default)  
`prefix+,` → leaf: rename current window (tmux default)  
`prefix+n` / `prefix+p` → leaf: next / previous window (tmux default)  
`prefix+l` → leaf: last (most recently used) window (tmux default; overridden by pane nav — use `C-l` instead)

---

## Popups and overlays

`prefix+o` → domain: popup overlay  
`prefix+o` → contract: if already inside a popup session (name contains `_popup_`), detach back to the parent; otherwise open the popup  
`prefix+o` → leaf: open or dismiss the main popup overlay (runs `tmux-show-popup.sh`)

`prefix+q` → leaf: display pane numbers for quick selection; if inside a popup session, detach back to parent instead

---

## Copy mode

`prefix+[` → leaf: enter copy mode (vi keybindings)

Inside copy mode:  
`v` → leaf: begin character selection  
`V` → leaf: begin line selection (tmux default)  
`C-v` → leaf: toggle rectangle selection  
`y` → leaf: yank selection to system clipboard and exit copy mode  
`[` → leaf: begin selection (alternate)  
`]` → leaf: copy selection and exit  
`q` / `Escape` → leaf: exit copy mode without yanking (tmux default)

`prefix+P` → leaf: paste the most recent buffer

---

## Scrollback

`prefix+E` → leaf: open the current pane's scrollback buffer in a Neovim popup for searching and copying  
`prefix+s` → leaf: jump to any visible text in the current pane using a two-key label (tmux-jump); similar to hop in Neovim

---

## Pane tagging (MCP / tool integration)

`prefix+T` → leaf: prompt for a tag name and attach it to the current pane (used by MCP integrations to address specific panes)  
`prefix+C-T` → leaf: clear the tag from the current pane

---

## Session persistence

`prefix+C-s` → leaf: save the current session layout and pane state to disk  
`prefix+C-r` → leaf: restore a previously saved session layout

---

## Config

`prefix+R` → leaf: reload tmux config from disk and confirm with a message  
`prefix+I` → leaf: install plugins via TPM (Tmux Plugin Manager)
