---
name: behavior-docs
description: Write or update BEHAVIOR.md files that document tool/plugin workflows as portable behavior contracts. Use when the user wants to document keybindings, workflow behaviors, tool conventions, or create per-tool behavior specs for Neovim, tmux, bash, or other keyboard-driven tools. Also use when the user wants to capture "what this tool should do" independently of the current plugin implementation, so that plugins can be swapped without losing workflow preferences.
---

# Behavior Documentation Skill

This skill captures keyboard-driven tool workflows as **portable behavior contracts** — stable descriptions of *what* and *why*, independent of *which* plugin currently implements them.

Each tool gets its own `BEHAVIOR.md` co-located with its config. Files use a flat compact notation that is easy to grep, sort, and maintain.

---

## File Location Convention

Place `BEHAVIOR.md` next to the tool's config:

```
mods/dotfiles/nvim/BEHAVIOR.md       # Neovim
mods/dotfiles/tmux/BEHAVIOR.md       # tmux
mods/dotfiles/bash/BEHAVIOR.md       # bash / shell
mods/dotfiles/karabiner/BEHAVIOR.md  # Karabiner
```

Each file is self-contained. Use a single cross-reference line when a workflow spans tools, rather than duplicating content.

---

## File Structure

Every `BEHAVIOR.md` has three sections in this order:

### 1. Header (tool metadata)

```markdown
# <Tool> Behavior

**Default mode notation:** `[n]` omitted = normal mode  
**Chord spelling:** `<leader>ff` (no spaces within a sequence)  
**Leader / prefix:** `<leader>` = Space, `<localleader>` = `;`
```

Adapt the header for non-Neovim tools (e.g. tmux uses `prefix` not `<leader>`).

### 2. Philosophy (2–6 bullets, freeform)

Short, opinionated statements about how this tool's keyboard layer should *feel*. These are stable values — they change only when you deliberately decide to change your workflow philosophy.

```markdown
## Philosophy

- Prefer fuzzy, filterable list pickers over blind commands wherever a list makes sense.
- After sending content to an external tool, focus should follow so output is immediately visible.
- Related actions share a namespace prefix; the first key signals the domain, the second specifies the action.
- Frequent actions get short chords; infrequent or destructive actions get longer ones.
```

### 3. Compact behavior catalog

One line per fact, organized into prefix groups separated by blank lines.

---

## Compact Notation

### Line grammar

```
<binding> → <kind>: <payload>
```

**Binding** — Full chord with no spaces within the sequence: `<leader>ff`, `<C-p>`, `prefix+r`.  
**Kind** — Fixed vocabulary (see below).  
**Payload** — User-visible behavior in plain language. No plugin names, no API calls.

### Kind vocabulary

| Kind | Meaning |
|------|---------|
| `domain` | What this namespace is for (intent, scope) |
| `contract` | Obligation shared by everything under this prefix |
| `leaf` | One concrete binding and what it does |
| `exception` | Breaks an ancestor contract — must follow the relevant `contract` line |
| `note` | Optional context: preconditions, tool restrictions, caveats |

### Mode prefix (Neovim)

When the same chord does different things in different modes, prefix the line:

```
[n] <leader>O? → leaf: free-text prompt → send to current route
[v] <leader>O? → leaf: prompt, append visual selection, send
```

Omit `[n]` for normal-mode-only lines (stated once in the header).

### Ordering within a group

1. `domain` line first
2. `contract` line(s) next
3. `exception` lines immediately after the `contract` they modify
4. `leaf` lines last (most specific chords at the end)
5. `note` lines after the leaf they annotate

---

## Example: Neovim find namespace

```
<leader>f  → domain: find / search (locate files, text, symbols, repo objects)
<leader>f  → contract: every command in this namespace presents a fuzzy, filter-as-you-type picker; preview is optional but fuzzy filtering is not

<leader>ff → leaf: pick and open a file from the current project root(s)
<leader>fg → leaf: git-scoped file or content search
<leader>fb → leaf: pick from open buffers
<leader>fs → leaf: pick a symbol (LSP) in the current file or project
<leader>fr → leaf: pick from recently opened files
```

## Example: Neovim external agent namespace

```
<leader>O  → domain: external agent / outboard AI tools
<leader>O  → contract: after any send, toggle, or focus action the target ends up focused so output is immediately readable without hunting for the pane

[n] <leader>Oo → leaf: show or hide the agent UI for the current route; focus it when shown
[n] <leader>O? → leaf: free-text prompt → send to current route
[v] <leader>O? → leaf: prompt, append visual selection, send
[n] <leader>OP → leaf: pick a canned prompt from the library → send (templates expanded by the integration)
[n] <leader>OS → leaf: pick which backend/route receives subsequent sends
[n] <leader>Ox → leaf: close or tear down the current route's target(s)
[v] <leader>Oa → leaf: send visual selection to current route
```

---

## Hierarchical conventions (prefix families)

Namespaces can share a parent convention. Document the parent with a `domain` + `contract` line, then document each child namespace separately. Child groups inherit parent contracts unless they have an explicit `exception`.

```
<leader>g  → domain: git operations
<leader>g  → contract: destructive git actions (reset, force push) always prompt for confirmation before executing

<leader>gs → leaf: show git status with diff preview
<leader>gc → leaf: pick a branch and checkout
<leader>gb → leaf: show git blame for current file
<leader>gp → leaf: push current branch (prompts for confirmation if force required)
<leader>gp → exception: force push bypasses the confirmation contract only when an explicit --force flag is acknowledged in the prompt
```

---

## Workflow: writing a new BEHAVIOR.md

1. **Start with philosophy** — ask "what would feel broken if a replacement plugin didn't do it?" Those are your contracts and non-negotiables.
2. **Group by prefix family** — list the namespaces (`<leader>f`, `<leader>g`, etc.), write `domain` + `contract` for each.
3. **Fill in leaves** — one line per binding. Write the user-visible outcome, not the implementation.
4. **Add exceptions** — any binding that violates a parent contract gets an `exception` line immediately after the `contract` it breaks.
5. **Add notes sparingly** — only when a precondition or tool-specific restriction would surprise someone trying to replace the plugin.

## Workflow: updating during a plugin swap

When replacing a plugin:

1. Read the tool's `BEHAVIOR.md` — the `contract` lines are the must-haves, `leaf` lines are the full requirement set.
2. Implement the new plugin to satisfy all `contract` lines first (P0).
3. Work through `leaf` lines and map each to the new plugin's API.
4. Where a leaf cannot be satisfied, add an `exception` or revise the leaf with the new behavior.
5. Do **not** update `contract` lines just to match what the new plugin does — contracts only change when you deliberately want to change your workflow.

---

## What does NOT belong in BEHAVIOR.md

- Plugin names, function names, or API calls (those belong in the plugin module or AGENTS.md)
- Installation or configuration instructions (those belong in AGENTS.md or the Nix config)
- Exhaustive lists of every single keymap — only document bindings that represent deliberate workflow choices worth preserving
- Editor settings, color schemes, or non-behavioral preferences
