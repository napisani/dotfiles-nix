# Karabiner Behavior

**Layer activation:** Hold a trigger key to activate a layer; release to deactivate (dual-role / simlayer)  
**Chord spelling:** `Caps+h` means hold Caps Lock and press h; `Tab+Q+h` means hold Tab, then hold Q, then press h  
**Context:** Some rules are app-context-aware (dev apps vs. standard apps)  
**Config:** `mods/dotfiles/karabiner/src/`  
**Cross-reference:** Window management targets the rift-cli tiling manager; tmux prefix key relies on the `Caps+Space` mapping here

---

## Philosophy

- Caps Lock is wasted as a modifier and more useful as a dual-role key: tap for Escape, hold for a modal layer.
- Home-row navigation (`hjkl`) should be reachable everywhere without reaching for arrow keys.
- Symbol and number layers eliminate reaching for the number row; they are designed around common programming characters.
- Terminal and editor apps are "dev apps" and get different modifier behavior than GUI apps — `fn` becomes `Ctrl` in dev contexts.
- Window management should not require modifier chords; a held `Tab` key activates a dedicated window layer so navigation and layout control are single keys.
- Tab alone still sends Tab; the layer only activates when Tab is held with another key simultaneously.

---

## Caps Lock — dual-role layer trigger

`Caps` (tap alone) → leaf: send Escape  
`Caps` (hold) → domain: activate Caps layer for all keys below  
`Caps` (hold) → contract: Caps layer stays active until Caps is released; all remappings below only fire while Caps is held

### Caps layer — navigation

`Caps+h` → leaf: left arrow  
`Caps+j` → leaf: down arrow  
`Caps+k` → leaf: up arrow  
`Caps+l` → leaf: right arrow

### Caps layer — tmux prefix

`Caps+Space` → leaf: send `Ctrl+Space` (tmux prefix)

### Caps layer — screenshots

`Caps+4` → leaf: trigger macOS screenshot selection (`Cmd+Shift+4`)  
`Caps+5` → leaf: trigger macOS screen recording picker (`Cmd+Shift+5`)

### Caps layer — Ctrl shortcuts

`Caps+<letter>` → leaf: send `Ctrl+<letter>` for every letter except `h`, `j`, `k`, `l` (those are arrow keys above)  
`Caps+'` → leaf: send `Ctrl+'`

---

## Modifier swap — app-context rules

`Caps` (hold) → note: modifier swap is independent of the Caps layer; both apply simultaneously

**Standard apps** (everything except Terminal, iTerm2, Alacritty, Ghostty):

`left_command` → leaf: behaves as `left_control`  
`left_control` → leaf: behaves as `left_command`  
`fn` → leaf: behaves as `left_command`  
`fn` → note: so `fn+c/v/z` etc. work as copy/paste/undo in GUI apps without reaching for Cmd

**Dev apps** (Terminal, iTerm2, Alacritty, Ghostty):

`fn` → leaf: behaves as `left_control`  
`left_command` → exception: NOT swapped in dev apps — keeps its native behavior so shell `Cmd+...` shortcuts work normally  
`fn` → note: so `fn+c` sends `Ctrl+c` (interrupt) rather than copy

---

## Simlayers — hold trigger + second key simultaneously

Simlayers activate when the trigger key and the action key are pressed at almost the same time (within the simlayer timeout). Unlike the Caps layer, there is no explicit "hold"; the two keys must overlap.

### `a` layer — delimiters / brackets

`a` → domain: insert brackets, quotes, and paired delimiters  
`a` → contract: every key in this layer inserts a single character; no modifier state is left behind

`a+r` → leaf: `(`  
`a+u` → leaf: `)`  
`a+f` → leaf: `{`  
`a+j` → leaf: `}`  
`a+d` → leaf: `[`  
`a+k` → leaf: `]`  
`a+t` → leaf: `'`  
`a+y` → leaf: `"`  
`a+g` → leaf: `,`  
`a+h` → leaf: `.`  
`a+c` → leaf: `<`  
`a+m` → leaf: `>`  
`a+v` → leaf: `&`  
`a+n` → leaf: `*`

### `d` layer — arrows

`d` → domain: directional arrow keys without leaving the home row  
`d+h` → leaf: left arrow  
`d+j` → leaf: down arrow  
`d+k` → leaf: up arrow  
`d+l` → leaf: right arrow

### `l` layer — operators and symbols

`l` → domain: insert operators, math symbols, and shell special characters  
`l+r` → leaf: `+`  
`l+u` → leaf: `-`  
`l+t` → leaf: `~`  
`l+i` → leaf: `_`  
`l+f` → leaf: `:`  
`l+j` → leaf: `=`  
`l+g` → leaf: `/`  
`l+h` → leaf: `?`  
`l+c` → leaf: `\`  
`l+m` → leaf: `|`  
`l+n` → leaf: `%`  
`l+e` → leaf: `$`  
`l+w` → leaf: `^`  
`l+v` → leaf: `!`  
`l+a` → leaf: `@`  
`l+q` → leaf: `0`

### `n` layer — numbers

`n` → domain: number row without leaving the home row  
`n+q` → leaf: `1`  
`n+w` → leaf: `2`  
`n+e` → leaf: `3`  
`n+r` → leaf: `4`  
`n+t` → leaf: `5`  
`n+y` → leaf: `6`  
`n+u` → leaf: `7`  
`n+i` → leaf: `8`  
`n+o` → leaf: `9`  
`n+p` → leaf: `0`

### `s` layer — Ctrl shortcuts (home row)

`s` → domain: send `Ctrl+hjkl` without a modifier key  
`s+h` → leaf: `Ctrl+h`  
`s+j` → leaf: `Ctrl+j`  
`s+k` → leaf: `Ctrl+k`  
`s+l` → leaf: `Ctrl+l`

---

## Tab — dual-role window management layer

`Tab` (tap alone) → leaf: send Tab normally  
`Tab` (hold) → domain: activate primary window management layer  
`Tab` (hold) → contract: all window actions below only fire while Tab is held; Tab alone or Tab released before a second key sends a real Tab

### Tab primary layer — window focus and workspace

`Tab+h` → leaf: focus the window to the left  
`Tab+j` → leaf: focus the window below  
`Tab+k` → leaf: focus the window above  
`Tab+l` → leaf: focus the window to the right  
`Tab+n` → leaf: switch to the next workspace  
`Tab+p` → leaf: switch to the previous workspace  
`Tab+Q` (hold) → domain: activate nested layer for window manipulation (hold Q while Tab is held)

### Tab+Q nested layer — window move and layout

`Tab+Q` → contract: requires Tab to remain held; Q itself activates the sub-layer, release Q to return to the primary layer

`Tab+Q+h` → leaf: move current window left in the layout  
`Tab+Q+j` → leaf: move current window down in the layout  
`Tab+Q+k` → leaf: move current window up in the layout  
`Tab+Q+l` → leaf: move current window right in the layout  
`Tab+Q+y` → leaf: join current window into the container to the left  
`Tab+Q+u` → leaf: join current window into the container above  
`Tab+Q+i` → leaf: join current window into the container below  
`Tab+Q+o` → leaf: join current window into the container to the right  
`Tab+Q+n` → leaf: move current window to the next workspace  
`Tab+Q+p` → leaf: move current window to the previous workspace  
`Tab+Q+Space` → leaf: toggle float for current window  
`Tab+Q+z` → leaf: toggle fullscreen within gaps for current window  
`Tab+Q+b` → leaf: toggle layout orientation (horizontal ↔ vertical)  
`Tab+Q+s` → leaf: toggle stack layout  
`Tab+Q+c` → leaf: create a new workspace  
`Tab+Q+m` → leaf: minimize current window (`Cmd+M`)  
`Tab+Q+x` → leaf: close current window (`Cmd+W`)

---

## Global remaps (no layer required)

`Escape` → leaf: send backtick/tilde (`` ` ``/`~`) — makes the Escape key useful on keyboards where backtick is awkward
