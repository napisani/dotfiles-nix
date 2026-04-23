# Neovim Behavior

**Default mode notation:** `[n]` omitted = normal mode; `[v]` = visual; `[nv]` = both  
**Chord spelling:** no spaces within a sequence (e.g. `<leader>ff`, not `<leader> f f`)  
**Leader / prefix:** `<leader>` = Space, `<localleader>` = `;`

---

## Philosophy

- Every command that presents a list of things to choose from uses a fuzzy, filter-as-you-type picker. Preview is optional; fuzzy filtering is not.
- Related actions cluster under a shared prefix. The first key after `<leader>` signals the domain; subsequent keys narrow the action.
- Inward-focus actions (navigating, editing, reading) use short chords. Outward/destructive actions (send to agent, close, quit, format) may be longer.
- Navigation across panes and tmux panes uses the same `<C-hjkl>` keys regardless of whether the boundary is a Neovim split or a tmux pane.
- After sending content to an external agent or tool, that target gets focus so the reply is immediately visible.
- Visual selection is a first-class input: most commands that accept a scope have a visual-mode variant that uses the selection as the scope.
- Code motion (jump-to-word, hop) is available in normal, visual, and operator-pending modes so it composes with operators.

---

## Motions & Navigation (no leader)

`<C-h>` → leaf: move focus left (Neovim split or tmux pane, zoom-aware)  
`<C-j>` → leaf: move focus down (Neovim split or tmux pane, zoom-aware)  
`<C-k>` → leaf: move focus up (Neovim split or tmux pane, zoom-aware)  
`<C-l>` → leaf: move focus right (Neovim split or tmux pane, zoom-aware)  
`<C-\>` → leaf: move focus to last-active pane (Neovim or tmux)  
`<S-l>` → leaf: next buffer  
`<S-h>` → leaf: previous buffer

`S` / `ss` → leaf: hop to any word on screen (multi-window)  
`sv` → leaf: hop vertically to any line  
`sb` → leaf: hop to any syntax node  
`sl` → leaf: hop to any camelCase word on the current line  
`<C-_>` → [nv] leaf: toggle comment on line or selection

`gd` → leaf: jump to definition (LSP)  
`gr` → leaf: show all references (LSP)  
`gl` → leaf: show inline diagnostics float for current line  
`]d` → leaf: jump to next diagnostic  
`]g` / `[g` → leaf: next / previous git hunk  
`gw` → leaf: enter window-management mode (`<C-w>` alias)

---

## `<leader>` — root / global

`<leader>"` → leaf: open a horizontal split  
`<leader>%` → leaf: open a vertical split  
`<leader>-` → leaf: open file manager (directory browser) in current buffer's directory  
`<leader>t` → leaf: toggle project file tree sidebar  
`<leader>q` → leaf: force-quit current window  
`<leader>Q` → leaf: quit current window  
`<leader>w` → leaf: write (save) current buffer  
`<leader>W` → leaf: write all open buffers  
`<leader>x` → leaf: close current buffer without closing the window  
`<leader>e` → leaf: reload current buffer from disk; if in a diff view, refresh that view instead  
`<leader>E` → leaf: reload all file buffers from disk; if in a diff view, refresh that view instead  
`<leader>/` → [v] leaf: search buffer for the visual selection  
`<leader>K` → leaf: show LSP signature help for the symbol under the cursor

---

## `<leader>f` — find (file picker)

`<leader>f` → domain: locate files, buffers, commands, and meta resources  
`<leader>f` → contract: every command here opens a fuzzy, filter-as-you-type picker  
`<leader>f` → note: visual mode variants pre-fill the picker filter with the current selection

`<leader>fe` → [nv] leaf: pick from open buffers  
`<leader>ff` → leaf: pick a file from the project (path-scoped search)  
`<leader>fr` → [nv] leaf: pick a file searching from repository root  
`<leader>ft` → [nv] leaf: pick a git-tracked file  
`<leader>fd` → [nv] leaf: pick from files changed in git (unstaged diff)  
`<leader>fD` → [nv] leaf: pick from files changed vs. the base branch  
`<leader>fC` → [nv] leaf: pick from git-conflicted files  
`<leader>fc` → [nv] leaf: pick a project command (proctmux/procmux command list)  
`<leader>fl` → leaf: pick and launch a configured command  
`<leader>fk` → leaf: pick and run a Neovim ex-command  
`<leader>fm` → leaf: pick and jump to a keymap definition  
`<leader>fM` → [nv] leaf: pick from man pages  
`<leader>fQ` → [nv] leaf: pick from Neovim help topics  
`<leader>fR` → [nv] leaf: pick from registers  
`<leader>fp` → [nv] leaf: pick a file by path (from current file's directory)  
`<leader>fP` → leaf: pick from available pickers (meta-picker)

---

## `<leader>h` — search (live grep)

`<leader>h` → domain: search text content across files  
`<leader>h` → contract: every command here opens a live, filter-as-you-type grep experience  
`<leader>h` → note: visual mode variants pre-seed the search with the current selection

`<leader>hr` → [nv] leaf: live grep from repository root  
`<leader>hq` → [nv] leaf: live grep within the quickfix list file set  
`<leader>hd` → [nv] leaf: live grep within git-changed files (unstaged diff)  
`<leader>hD` → [nv] leaf: live grep within files changed vs. base branch  
`<leader>hs` → [nv] leaf: pick an LSP symbol (functions, classes, variables) across project  
`<leader>hm` → [nv] leaf: pick a method or function symbol specifically  
`<leader>hG` → [nv] leaf: search GitHub code (opens GitHub code search with query)

---

## `<leader>r` — replace

`<leader>r` → domain: search-and-replace operations across various scopes  
`<leader>r` → contract: replacements use `:s@…@…@` pattern (not `/`); `B`/`Q` variants prompt for confirmation before each change

`<leader>r*` → leaf: replace word under cursor across buffer (no confirmation)  
`<leader>rb` → [nv] leaf: replace pattern in current buffer (no confirmation)  
`<leader>rB` → [nv] leaf: replace pattern in current buffer (ask each occurrence)  
`<leader>rl` → [nv] leaf: replace pattern on current line  
`<leader>rq` → [nv] leaf: replace pattern across quickfix list  
`<leader>rQ` → [nv] leaf: replace pattern across quickfix list (ask each occurrence)  
`<leader>rd` → leaf: delete lines matching pattern  
`<leader>rD` → leaf: delete lines NOT matching pattern  
`<leader>rv` → [v] leaf: replace pattern within visual selection  
`<leader>rV` → [v] leaf: replace pattern within visual selection (ask each occurrence)

`<leader><leader>r` → domain: case-aware variant of replace (Subvert) — handles snake_case, CamelCase, etc.  
`<leader><leader>r*` → leaf: Subvert-replace word under cursor across buffer  
`<leader><leader>rb` → [nv] leaf: Subvert-replace in buffer  
`<leader><leader>rB` → [nv] leaf: Subvert-replace in buffer (ask)  
`<leader><leader>rl` → [nv] leaf: Subvert-replace on current line  
`<leader><leader>rq` → [nv] leaf: Subvert-replace across quickfix list  
`<leader><leader>rQ` → [nv] leaf: Subvert-replace across quickfix list (ask)  
`<leader><leader>rv` → [v] leaf: Subvert-replace within visual selection  
`<leader><leader>rV` → [v] leaf: Subvert-replace within visual selection (ask)

---

## `<leader>l` — LSP / language

`<leader>l` → domain: language server actions — code intelligence, formatting, diagnostics  
`<leader>l` → contract: actions only activate when an LSP server is attached to the current buffer

`<leader>la` → [n] leaf: show code actions at cursor position (pick from list)  
`<leader>lr` → leaf: rename symbol under cursor (LSP rename, updates all references)  
`<leader>lf` → leaf: format current buffer using the project's configured formatter  
`<leader>ll` → leaf: refresh and run code lens at cursor  
`<leader>li` → leaf: organize imports (Go and TypeScript; no-op for other filetypes)  
`<leader>lE` → leaf: populate location list with all diagnostics in current buffer  
`<leader>lR` → leaf: restart all attached LSP servers  
`<leader>lc` → [nv] leaf: toggle comment on current line or selection  
`<leader>lm` → leaf: toggle markdown rendering (preview rendered output inline)  
`<leader>lw` → leaf: toggle line wrap in current window

---

## `<leader>g` — git

`<leader>g` → domain: git operations — status, blame, hunk navigation, diff reference  
`<leader>gl` → leaf: show git blame for the current line (inline popup)  
`<leader>gr` → leaf: set a git comparison reference (branch or commit) for diff views  
`<leader>gR` → leaf: set a git comparison reference to a specific commit  
`<leader>go` → leaf: open the full git status / commit UI  
`]g` / `[g` → leaf: jump to next / previous hunk in the buffer (also under motions)

---

## `<leader>c` — changes / diff

`<leader>c` → domain: diff, compare, conflict resolution, and change review  
`<leader>co` → leaf: open diff view for current working changes  
`<leader>cH` → leaf: open diff view comparing current state to HEAD  
`<leader>ch` → [nv] leaf: open file history (recent commits affecting current file)  
`<leader>cr` → leaf: open diff view comparing to the stored reference  
`<leader>cq` → leaf: close the diff view tab  
`<leader>cB` → leaf: show full-file git blame

`<leader>cf` → domain: file-level diff operations  
`<leader>cff` → leaf: pick a file to compare the current file against (side-by-side diff)  
`<leader>cfH` → leaf: diff current file against HEAD  
`<leader>cfr` → leaf: diff current file against stored reference  
`<leader>cfh` → leaf: show history of current file (last 20 commits)  
`<leader>cfc` → leaf: compare current buffer against clipboard (side-by-side diff)

`<leader>cc` → [v] leaf: compare visual selection against clipboard (side-by-side diff)

Conflict resolution (active inside a diff/conflict view):  
`<leader>ct` → leaf: accept incoming (theirs) change at current conflict  
`<leader>co` → leaf: accept current (ours) change at current conflict  
`<leader>cb` → leaf: accept both changes (incoming first)  
`<leader>cx` → leaf: discard both, restore base

---

## `<leader>d` — debug (DAP)

`<leader>d` → domain: debugger — breakpoints, execution control, REPL  
`<leader>d` → contract: DAP UI opens automatically when a debug session starts and closes on termination  
`<leader>d` → note: requires a language-specific debug adapter to be configured (typescript, python, go)

`<leader>db` → leaf: toggle breakpoint at current line  
`<leader>dB` → leaf: set conditional breakpoint (prompts for condition expression)  
`<leader>dL` → leaf: set log point (prints message without stopping)  
`<leader>dX` → leaf: clear all breakpoints  
`<leader>dc` → leaf: continue execution (or launch the debug session)  
`<leader>dh` → leaf: step into  
`<leader>dj` → leaf: step over  
`<leader>dk` → leaf: step out  
`<leader>dl` → leaf: re-run the last debug configuration  
`<leader>do` → leaf: open the debugger UI manually  
`<leader>dq` → leaf: close the debugger UI  
`<leader>dr` → leaf: open the debug REPL

---

## `<leader>a` — Wiremux agent + PromptBuilder (staged context)

`<leader>a` → domain: control the **Wiremux** target pane and **PromptBuilder** — a single **horizontal** split (opens **below** the current window, height capped to a fraction of the screen), markdown-syntax scratch buffer (tag `prompt_builder`) where you assemble `@` references and freeform text. At most one PromptBuilder buffer exists; new material **appends** to it. Nothing here talks to the agent by itself except **`ao` / `aq` / `aw` / `av`** and **`<C-g>` inside PromptBuilder** (see below)  
`<leader>a` → contract: after a **send** to the agent (including from PromptBuilder via `<C-g>`) or after **`ao`** toggle / focus, the **Wiremux target pane** gets focus so the reply is visible. Staging keys (`af*`, `ae`, `a?`, `ap`, `am`) only update PromptBuilder until you `<C-g>` there; **`ai`** is different: it only opens or focuses PromptBuilder and appends no text  
`<leader>a` → note: route (target) is per-session and defaults to the `opencode` pane for the current working directory

**Direct to Wiremux / voice (not PromptBuilder)**  
`<leader>aq` → [n] leaf: close the current route target  
`<leader>ao` → [n] leaf: show or hide the current route target and focus it  
`<leader>av` → [nv] leaf: toggle voice recording; transcription replaces selection or inserts at cursor  
`<leader>aw` → [n] leaf: pick the active route/backend in a fuzzy list

**`af` — append @-ref lines to PromptBuilder** (then edit; `<C-g>` in that buffer to send to the agent and close the builder)  
`<leader>afe` → leaf: pick from open buffers; each choice appends an `@` reference line (and trailing newline) to PromptBuilder  
`<leader>aff` → [n] leaf: append an `@` line for the **current file** to PromptBuilder  
`<leader>aff` → [v] leaf: append an `@… lines s–e` line for the **visual line range** to PromptBuilder  
`<leader>afr` → leaf: pick a file (from repo root search); append `@` ref(s) to PromptBuilder  
`<leader>aft` → leaf: pick a git-tracked file; append `@` ref to PromptBuilder  
`<leader>afd` → leaf: pick from files changed in git (unstaged); append ref(s) to PromptBuilder  
`<leader>afD` → leaf: pick from files changed vs. the base branch; append ref(s) to PromptBuilder  
`<leader>afC` → leaf: pick from git-conflicted files; append ref(s) to PromptBuilder

**`ai` — open or focus PromptBuilder**  
`<leader>ai` → [n] [v] leaf: if the PromptBuilder buffer does not exist yet, open it in a horizontal split (below, same rules as the rest of `<leader>a`); if it already exists, jump to the window that already shows it, or show it in a new lower split if it is hidden. Inserts nothing — use this when you only need the staging buffer in front of you

**`ae` / `a?` — Snacks prompt, then at-style block in PromptBuilder** (same interaction as `am`, then edit further or `<C-g>` to send)  
`<leader>ae` → [n] [v] leaf: **Snacks.input** titled *Instruction*; the buffer gets `@path:line`, optional **Selection** fence in visual, and an **Instruction:** line with your text (then `<C-g>` to send the whole buffer)  
`<leader>a?` → [n] [v] leaf: same, but Snacks title *Question* and a **Question:** line in the appended block

**Canned and submit**  
`<leader>ap` → [n] leaf: pick a **canned prompt** from the library; the template (with `{file}` / `{this}` / `{selection}` expanded where possible) is **appended** to PromptBuilder for you to edit, then `<C-g>` to send

**Memo (accumulate rich context, replaces old register-`5` memos)**  
`<leader>am` → [n] [v] leaf: **Snacks.input** titled *Instructions*; the buffer gets an `@path:line` ref (at-style), a fenced **Selection** block in visual mode, and an **Instructions:** line with your text — **appended** to PromptBuilder. A markdown `---` rule separates a new block from prior buffer content, matching the old `accumulate` behavior between register pastes

**Inside a PromptBuilder buffer**  
`<C-g>` → [n] [i] leaf: send the **entire** buffer as one message to Wiremux **with submit**, then wipe the PromptBuilder buffer  

---

## `<leader>b` — buffers

`<leader>b` → domain: buffer management and path utilities  
`<leader>bo` → leaf: close all buffers except the current one  
`<leader>bq` → leaf: close current buffer  
`<leader>bfy` → leaf: copy just the filename (no path) to the system clipboard  
`<leader>bpy` → leaf: copy the full absolute path to the system clipboard  
`<leader>bpry` → leaf: copy the relative path (from project root) to the system clipboard  
`<leader>bpgo` → leaf: open the current file in the browser at its remote git URL

---

## `<leader>P` — system / package management

`<leader>P` → domain: Neovim package manager and tooling meta-commands  
`<leader>Pm` → leaf: open Mason (LSP / tool installer)  
`<leader>Ps` → leaf: open Lazy (plugin manager sync UI)  
`<leader>Pt` → leaf: update Treesitter parsers  
`<leader>Pl` → leaf: show LSP info for the current buffer  
`<leader>PM` → leaf: show Neovim message history  
`<leader>PN` → leaf: show notification history

---

## `<leader>D` — database

`<leader>D` → domain: database tools (group; specific bindings depend on active database plugin)

---

## `<leader><leader>s` — scopes

`<leader><leader>sa` → leaf: add a search scope (pick a root path to restrict future searches)  
`<leader><leader>sx` → leaf: clear all active search scopes

---

## `<localleader>r` — REPL (Slime)

`<localleader>r` → domain: send code to a connected REPL process  
`<localleader>rr` → [n] leaf: send the current cell (delimited block) to the REPL  
`<localleader>rr` → [v] leaf: send the visual selection to the REPL  
`<localleader>rC` → leaf: reconfigure Slime connection settings

---

## Inside diff / conflict views

These bindings are active within the diff viewer tab (not global leader bindings):

`q` → leaf: close the diff tab  
`]g` / `[g` → leaf: jump to next / previous change hunk  
`]f` / `[f` → leaf: next / previous file in the explorer  
`do` → leaf: get change from the other buffer (vimdiff-style)  
`dp` → leaf: put change to the other buffer  
`gf` → leaf: open current buffer in the previous tab  
`-` → leaf: stage / unstage current file  
`R` → leaf: refresh git status in explorer  
`S` / `U` → leaf: stage all / unstage all files  
`X` → leaf: discard changes (restore file)

---

## Inside file tree (nvim-tree)

`<CR>` / `l` / `o` → leaf: open selected file or expand directory  
`h` / `<BS>` → leaf: close directory or go to parent  
`v` → leaf: open in vertical split  
`a` → leaf: create a new file or directory  
`d` → leaf: delete file (to trash with `D`)  
`r` / `e` → leaf: rename (full path / basename only)  
`c` / `x` / `p` → leaf: copy / cut / paste file  
`y` / `Y` / `gy` → leaf: copy filename / relative path / absolute path  
`f` / `F` → leaf: start / clear live filter  
`H` → leaf: toggle hidden (dotfiles) visibility  
`R` → leaf: refresh tree  
`q` → leaf: close tree
