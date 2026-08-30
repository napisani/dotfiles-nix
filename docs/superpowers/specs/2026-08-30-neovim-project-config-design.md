# Neovim Project Configuration and Persistent File Scopes

## Status

Design proposed for review.

## Goal

Add persistent, project-local named file scopes to the existing Neovim project
configuration, expose them as additional choices in the `<leader><leader>st`
scope picker, and provide a manual-only `neovim-project-config` skill for
initializing, managing, and auditing the structured project configuration.

The feature must preserve the existing executable `.nvim.lua` model and custom
Lua outside the structured configuration section.

## Existing system

Neovim sources `.nvim.lua` through
`lua/user/plugins/util/exrc_manager.lua`. Project configuration is conventionally
stored as a local `project_config` table and exposed through `_G.EXRC_M`:

```lua
local project_config = {
  -- project settings
}

_G.EXRC_M = {
  project_config = project_config,
  setup = function() end,
}
```

`lua/user/utils/project_utils.lua` merges that table with defaults. The current
scope system has three built-in categories (`tests`, `documentation`, and
`implementation`) whose enabled flags can be combined. Directory and ad hoc glob
scopes are held in memory and are not persisted.

## Decisions

### Project scope data

Project scopes live in the existing `project_config` table:

```lua
local project_config = {
  scopes = {
    frontend = { "src/**/*.ts", "src/**/*.tsx" },
    integration = { "**/integration/**", "**/*_integration.*" },
  },
}
```

Each scope value is a non-empty array of workspace-relative glob strings. The
supported glob language is the same one already used by `path.lua`: literals,
`/`, `*`, `**`, and `?`. Absolute paths, parent traversal (`..`), braces, and
whitespace inside entries are invalid.

The built-in names `tests`, `documentation`, and `implementation` are reserved
and cannot be defined or shadowed by project configuration. Project scope names
must be non-empty strings, use a stable identifier-like format, and be unique
within the project configuration.

### Selection model

All scope choices are mutually exclusive. The picker contains:

- the built-in `tests` scope;
- the built-in `documentation` scope;
- the built-in `implementation` scope;
- each configured project scope, in deterministic name order.

Selecting an item replaces the active directory/glob/category scope. The
selected scope is represented by one active scope descriptor: a built-in
category, a directory, or a validated glob array. `<leader><leader>sx` clears
the active scope. Scope selection is ephemeral and resets on a new Neovim
launch; the project configuration stores definitions, not the current
selection.

The previous category enabled/disabled composition is removed from the user
flow. Built-in category patterns remain the source of truth for the three
built-in choices, so existing classification and filtering behavior remains
consistent. `implementation` retains its current catch-all meaning: files that
do not classify as tests or documentation. Category state no longer needs
runtime reset or toggle semantics.

Directory selection through `<leader><leader>sp` and Vantage ad hoc selection
continue to set an active scope, but they also participate in the same
mutually-exclusive runtime state. A later selection from any scope entry
replaces them.

### Picker behavior

`<leader><leader>st` remains the entry point. Its picker becomes a radio-style
scope picker rather than a category toggle picker:

- each row displays its name and whether it is active;
- `<CR>` selects the row and closes the picker;
- the selection callback refreshes open trees and other existing consumers;
- project scopes are loaded from the current project configuration when the
  picker opens;
- an empty or invalid project-scope table is ignored with a user-visible
  validation error rather than crashing startup.

The existing `<leader><leader>sx` mapping clears the active scope. Its
category-reset portion is removed because there is no longer mutable category
state.

### Filtering seams

The existing scope consumers remain the public behavior seams:

- `path.is_visible` and `path.is_tree_visible` filter paths and tree nodes;
- picker integrations filter file lists;
- LSP result filtering uses the active scope;
- Diffview receives exact pathspecs or materialized intersection paths.

Built-in scopes use their existing pattern definitions. Project scopes use the
same validated glob representation. No consumer duplicates glob parsing or
scope-selection logic.

### Project configuration skill

Create `priv/skills/neovim-project-config/SKILL.md` with:

- `name: neovim-project-config`;
- a description covering initialization, management, auditing, and all
  supported project configuration capabilities;
- `disable-model-invocation: true`.

The skill is explicit-operation driven:

- **initialize** creates a minimal valid `.nvim.lua` skeleton containing an
  empty `project_config`, then may report inferred suggestions for approval;
- **manage** adds, updates, removes, or explains structured fields in
  `project_config`;
- **audit** reports project-specific configuration opportunities without
  editing files.

The skill must read the complete `.nvim.lua` before editing, preserve unrelated
Lua and `_G.EXRC_M.setup`, maintain valid Lua syntax, reject reserved scope
names, validate glob arrays, and verify the resulting Lua syntax and config
shape without invoking project setup side effects where practical. It must not
activate a scope automatically.

The skill will be declared in `pub/dotfiles-nix/mods/agents/skills.nix` without
a machine condition or agent restriction, so it is installed on every system
and all four agents. Pi, Claude, and Codex hide it from model discovery using
their existing manual-only mechanisms. OpenCode receives the installation but
remains subject to its current lack of a supported manual-only mechanism.

## Implementation boundaries

Likely implementation files:

- `mods/dotfiles/nvim/lua/user/utils/project_utils.lua` — default and validated
  project scope access;
- `mods/dotfiles/nvim/lua/user/scope/path.lua` — active-scope representation and
  project glob application;
- `mods/dotfiles/nvim/lua/user/scope/category.lua` — retain built-in patterns,
  expose built-in scope definitions, remove mutable enabled-state composition;
- `mods/dotfiles/nvim/lua/user/whichkey/categories.lua` or a renamed scope
  picker module — unified radio picker;
- `mods/dotfiles/nvim/lua/user/whichkey/scopes.lua` — picker wiring and clear
  behavior;
- `tests/scope_common_spec.lua`, `tests/scope_category_spec.lua`, and new
  focused specs as needed;
- `mods/dotfiles/nvim/AGENTS.md`, `BEHAVIOR.md`, `readme.md`, and scope-local
  guidance — update user-facing behavior;
- `priv/skills/neovim-project-config/SKILL.md` — skill instructions;
- `mods/agents/skills.nix` — all-system/all-agent manual-only catalog entry.

No new persistence file, global scope state, or automatic project mutation is
introduced. The existing `.nvim.lua` remains the persistence boundary.

## Verification

1. Run focused headless Neovim scope tests.
2. Verify project config loading, built-in catch-all behavior, and invalid-scope
   handling in isolation.
3. Verify the picker exposes the three built-ins plus configured project names,
   and that selection is mutually exclusive.
4. Verify Diffview, picker, tree, and LSP filtering use each selected scope.
5. Verify the skill has valid frontmatter and its catalog entry evaluates for
   personal, Loancrate, lab, and server configurations.
6. Run `cd pub/dotfiles-nix && rtk nix flake check`.
7. Run applicable monorepo checks after implementation.
