# Agent Guidelines for `lua/user/scope/`

Read this before changing scope behavior or wiring a new file-listing surface.

## Purpose

This module answers which subset of the workspace is currently visible:

- `path.lua` handles directory and glob scopes;
- `category.lua` defines the built-in `tests`, `documentation`, and
  `implementation` scopes;
- `project.lua` validates named glob arrays from
  `project_config.scopes` in the project `.nvim.lua`;
- `state.lua` owns the one ephemeral active scope descriptor;
- `common.lua` is the composition seam used by consumers.

Scopes are mutually exclusive. Selecting a built-in category, project glob,
directory, or Vantage glob replaces the previous selection. Definitions in
`.nvim.lua` persist; the active selection does not.

## The one rule that matters

Every surface that lists files must route through `common.lua`, not implement
its own filtering. A selected scope must consistently affect file search, grep,
changed-file pickers, `gr`/`gi` LSP results, NvimTree, and Diffview.

Dependency direction is one-way: `path.lua`, `category.lua`, `project.lua`, and
`state.lua` do not require consumer modules. `common.lua` depends on the scope
modules; pickers and plugins depend on `common.lua`.

## Consumer seams

| Consumer | Required seam |
|---|---|
| Snacks picker | Call `common.apply_to_picker(opts)` before opening it. |
| Materialized path list | Call `common.filter_paths(paths)`. |
| LSP references/implementations | Filter `list_ctx.items` with `common.is_visible`. |
| Diffview | Use `common.diffview_pathspec_args(target?)` at every call site. |
| NvimTree | Use `common.is_visible` for files and `common.is_tree_visible` for directories. |

Do not call `category.*` directly from a consumer when the full active scope is
needed, and do not duplicate glob matching.

## Invariants

- Exactly one scope descriptor is active, or none.
- Built-in names `tests`, `documentation`, and `implementation` are reserved
  and cannot be project scope names.
- Project scopes are non-empty arrays of workspace-relative globs. Supported
  syntax is literals, `/`, `*`, `**`, and `?`; reject absolute paths, `..`,
  braces, whitespace, empty arrays, and non-string entries.
- Active scope state is in memory only and starts clear on launch.
- Built-in patterns remain code-defined; project patterns are persistent data.
- `common.is_visible` is the composition seam for file visibility.

## Diffview rules

`common.diffview_pathspec_args` is the only Diffview filtering seam:

- a built-in category returns its include/exclude pathspecs;
- a directory prefixes patterns or returns `:(glob)<dir>/**`;
- a glob array returns one `:(glob)` pathspec per entry;
- a target returns the literal target if visible, otherwise `nil`;
- no active scope returns no restriction.

Magic pathspecs must not be `fnameescape`d before `vim.cmd`; escape literal
paths only. `:DiffviewFileHistory` takes pathspecs before `--`, while
`:DiffviewOpen` uses post-`--` arguments.

## Project configuration

Project scopes are defined in `.nvim.lua` under `_G.EXRC_M.project_config`:

```lua
local project_config = {
  scopes = {
    frontend = { "src/**/*.ts", "src/**/*.tsx" },
  },
}

_G.EXRC_M = {
  project_config = project_config,
  setup = function() end,
}
```

`scope/project.lua` is responsible for validation and deterministic ordering.
The `<leader><leader>st` picker displays the three built-ins followed by valid
project scopes. `<leader><leader>sx` clears the active selection.

## Testing

From `mods/dotfiles/nvim`, use an isolated runtimepath so installed config does
not shadow worktree changes:

```bash
nvim --headless --clean -c "set rtp^=$(pwd)" -c "luafile tests/scope_project_spec.lua" -c "qa"
nvim --headless --clean -c "set rtp^=$(pwd)" -c "luafile tests/scope_category_spec.lua" -c "qa"
nvim --headless --clean -c "set rtp^=$(pwd)" -c "luafile tests/scope_common_spec.lua" -c "qa"
nvim --headless --clean -c "set rtp^=$(pwd)" -c "luafile tests/lsp_attach_spec.lua" -c "qa"
```
