# Agent Guidelines for `lua/user/scope/`

## Read this before touching any file in this directory or wiring a new
## picker/list/LSP-list/Diffview surface into visibility filtering.

## Purpose

This module answers one question, two independent ways: **"what subset of
the project should currently be visible?"**

- `path.lua` — directory scope. At most one active directory; narrows the
  cwd a picker searches from.
- `category.lua` — file-category scope. Classifies every path into exactly
  one category (`tests`, `documentation`, or the `implementation`
  catch-all) and lets each category be toggled on/off at runtime.
- `common.lua` — the composition point. Combines both onto a picker's
  `opts` in one call, or filters an already-materialized path list.

They are **orthogonal and additive**, not alternatives. Disabling a
directory and disabling a category both apply at once — that's a feature
(an intersection), never treat it as a conflict to resolve.

## The one rule that matters

**Every surface that lists files must route through this module, not
build its own filtering.** The whole point of centralizing classification
and enabled-state here is that a user can hide "tests" once and have it
disappear from file search, grep, changed-file pickers, `gr`/`gi` LSP
results, the explorer tree, and Diffview simultaneously. The moment a
consumer hand-rolls its own category check, that consumer silently drifts
out of sync the next time a category's patterns change — this has already
happened once by design intent (Option 2 in the original design was
explicitly rejected for this reason). If you are adding a new
file-listing surface anywhere in this Neovim config, wire it through
`category.lua`/`common.lua` here rather than reimplementing pattern
matching.

Dependency direction is one-way: `path.lua` and `category.lua` never
`require` a consumer module. `common.lua` depends on both. Everything
else depends on one or more of these three, never the reverse.

## Picking the right seam

Different consumer shapes need different integration points — **use the
one that matches the shape you have, don't force a different one to fit**:

| Consumer shape | Seam | Call |
|---|---|---|
| Snacks picker (files, grep, explorer, custom `finder`) | `opts.transform` hook, fires per item regardless of backend (rg, fd, a Rust index, a hand-built Lua list) | `common.apply_to_picker(opts)` when building `opts`, before passing to `Snacks.picker.*` |
| Already-materialized path list (e.g. `git status` output) | no Snacks finder exists to hook a `transform` into — pre-filter instead | `common.filter_paths(paths)` before building picker items |
| `vim.lsp.buf.references` / `vim.lsp.buf.implementation` | the built-in `on_list` callback — the only point before Neovim renders results into a loclist | wrap `on_list`, filter `list_ctx.items` with `category.is_visible(item.filename)`, then `setloclist` + open (see `lua/user/lsp/keymaps.lua`) |
| Diffview | no persistent config option and no item-level hook exists — pathspec CLI args are the *only* seam | `category.diffview_pathspec_args()` appended after `--` at every `:DiffviewOpen`/`:DiffviewFileHistory` call site (see `lua/user/plugins/git/diff.lua`) |

If you find yourself needing a filtering point that isn't one of these
four shapes, that's a sign the new surface's integration is genuinely
novel — add a fifth row here documenting the seam you found, don't quietly
bypass the module.

## Invariants — do not break these

- Exactly one category in `category.categories` has `catchall = true`, and
  it is checked last. A path that matches no other category's patterns
  always belongs to it — there is no "unclassifiable" state.
- `category.is_visible(path)` is pure: same enabled-state + same path
  always returns the same answer, no I/O, no caching that can go stale.
- Enabled state is **in-memory only** and always starts fully-enabled on
  launch. Do not add persistence (a save-to-disk, a global var read at
  require-time, etc.) — this deliberately mirrors `path.lua`'s existing
  behavior. If a user wants persistence, that's a product decision to
  revisit explicitly, not something to sneak in via a "helpful" default.
- Category *patterns* are edited in code (`category.categories[name].patterns`),
  never exposed as a runtime-editable setting. Only *enabled/disabled* is a
  runtime toggle (`<leader><leader>ta` / `<leader><leader>tx`, see
  `lua/user/whichkey/categories.lua`). Don't add a picker/prompt for
  editing globs at runtime — if patterns need to change, that's a code
  change and a stylua/test pass, same as adding a category (below).

## Diffview's pathspec quirk — read before changing `diffview_pathspec_args`

Git pathspec has no "everything except this named set" operator when the
named set isn't complementary to a single glob, so the function runs in
two distinct modes depending on whether the catch-all is enabled:

- **Catch-all enabled**: disabled non-catch-all categories become
  `:!<pattern>` negative args. Everything not explicitly excluded stays
  visible (the catch-all's files included by default).
- **Catch-all disabled**: negation can't express "only what's left",
  so the function switches to positive-only mode — the pathspec becomes
  the union of enabled non-catch-all categories' patterns.
- **Everything disabled** (catch-all included): the positive-mode union is
  empty, which to git means "no restriction" — the opposite of intent.
  `category.NOTHING_MATCHES_SENTINEL` is returned instead, a positive
  pathspec guaranteed to match zero real files. Don't special-case this
  at Diffview call sites — the sentinel already makes the returned args
  list correct on its own; callers just append whatever comes back.

## Extending: adding a new category

1. Add an entry to `category.categories` in `category.lua` with a
   `patterns` list (small hand-rolled glob subset: `*`, `**`, `?`,
   literals — see `glob_to_lua_pattern`; no new dependency for a richer
   glob syntax unless a real pattern shape genuinely requires it).
2. Insert its name into `category.order` **before** the catch-all
   (`implementation`) — order is match-priority, first hit wins, and the
   catch-all must stay last.
3. Do not touch `is_visible`, `transform`, `filter_paths`, or
   `diffview_pathspec_args` — they're written generically over
   `M.order`/`M.categories` and pick up new categories automatically.
4. Add classify/visibility assertions to `tests/scope_category_spec.lua`
   for the new patterns (red/green, matching the existing style there).
5. It will appear automatically in the `<leader><leader>ta` toggle picker
   (`whichkey/categories.lua` iterates `category.list_names()`) — no
   keymap or whichkey change needed.

## Extending: wiring a new file-listing surface

1. Identify which row of the seam table above matches its shape.
2. Call the matching `common.*`/`category.*` function — don't copy
   `glob_to_lua_pattern` or reimplement classification inline anywhere
   outside `category.lua`.
3. If a genuinely new seam shape shows up (not a Snacks picker, not a
   materialized list, not `on_list`, not Diffview pathspec), add a row to
   this file's seam table describing it before shipping the integration,
   so the next person doesn't have to rediscover it by reading the diff.

## Known non-goals (don't "fix" these without discussing first)

- `nvim-tree` is not filtered — only the Snacks explorer (the tree UI
  actually wired into the which-key leader menu) is in scope.
- Trouble's combined LSP list (`<leader>Tl` in `lua/user/trouble.lua`) is
  not filtered — a separate surface with its own filter API, deliberately
  left as a follow-up rather than bundled in here.
- `path.lua` (directory scope) and `category.lua` (file-category scope)
  are intentionally kept as separate sibling modules, not merged into one
  "active scope" value — see Purpose above. If a future change wants to
  fold them together, that's a deliberate redesign, not a refactor.

## Testing

```bash
# From lua/user/scope/'s repo root (mods/dotfiles/nvim), run with an
# isolated runtimepath so the live-installed config doesn't shadow local
# edits under test:
nvim --headless --clean -c "set rtp^=$(pwd)" -c "luafile tests/scope_category_spec.lua" -c "qa"
nvim --headless --clean -c "set rtp^=$(pwd)" -c "luafile tests/scope_common_spec.lua" -c "qa"
nvim --headless --clean -c "set rtp^=$(pwd)" -c "luafile tests/lsp_attach_spec.lua" -c "qa"
```

`--clean` plus an explicit `rtp^=` prepend matters: a bare `nvim
--headless -c "luafile ..."` picks up the *installed* (symlinked) config
first, so edits made in a worktree or PR branch silently don't take
effect and stale behavior passes.
