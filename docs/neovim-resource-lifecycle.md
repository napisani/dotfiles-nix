# Neovim resource lifecycle

## Lazy startup and manual control

Every `nvim` launch defers heavyweight language servers. There is no launch flag
or separate eager-startup mode. Lightweight services such as EFM remain available.
Opening files, scrolling, moving the cursor, returning focus, viewing Diffview,
and agent edits do not start heavyweight servers. Syntax highlighting, grep,
pickers, and Vantage remain available. Workmux's existing pane commands are
unchanged and use the same lazy behavior.

`<leader>lo` controls language services in every editor:

- From lazy startup, it enters authoring mode and eagerly enables all selected LSPs.
- In authoring mode, it turns all selected LSPs off, including lightweight ones.
- After explicit off, it restores authoring mode and enables them again.

Explicit off is sticky. Editing, semantic requests, focus changes, and idle wake
cannot override it. Use `<leader>lo` or `:LspEnable` to turn services back on.
`:LspToggle` is the command equivalent of the keybinding.

## Heavyweight registry

`mods/dotfiles/nvim/lua/user/lsp/registry.lua` owns the configured server list,
project selection, and `heavy` classification. Mason uses that same configured
list for installation. The heavyweight set is:

- `vtsls` and `denols` for JavaScript/TypeScript.
- `basedpyright`, `pyright`, and `pylsp` for Python analysis.
- `ruff`, grouped with Python analysis so review sessions defer both Python
  services. This is a lifecycle policy, not a claim that Ruff uses as much memory
  as a type checker.

The default Python selection remains basedpyright plus Ruff. Classifying pyright
and pylsp does not enable or install them alongside basedpyright. Deno projects
select denols instead of vtsls. Toggling never enables an unselected alternative.
To change the configured backends or classify another expensive server, edit the
registry rather than adding language-specific branches to the idle controller.

## Automatic first use

Until the user explicitly turns LSPs off, deferred servers start when:

- Insert mode begins in a real source buffer matching their configured
  filetypes. Python insertion starts basedpyright and Ruff; TypeScript insertion
  starts the selected TypeScript backend. Entering Vantage prompts or scratch
  buffers does not count.
- A mapped semantic action needs a server that is not ready. This includes
  `gd`, `gD`, `gi`, `gr`, `gy`, `K`, LSP-backed `<leader>l` actions, stock aliases
  `gri`, `grr`, `grt`, `grn`, `gra`, `gO`, and insert-mode `<C-s>`.

First use enters authoring mode for the requested language. Heavyweight servers
for other languages remain deferred until needed; explicitly toggling on enables
all selected servers. Completion uses the ordinary LSP attachment once ready.

Startup does not wait for initialization. A cold semantic action waits up to
60 seconds for an attached client supporting its method. The editor remains
responsive. Only the most recent pending action survives. Before replay, the
lifecycle checks the original window, buffer, cursor, changed tick, and mode.
Movement, edits, closed buffers/windows, focus loss, or a manual toggle cancel the
pending action. Existing Diffview destination handling and capability checks stay
in place. Startup failures appear in Neovim's LSP messages; timeouts report the
requested method. A subsequent semantic request can retry a failed startup.

## Background sleep and UI refresh

`lua/user/idle.lua` tracks focus rather than keyboard inactivity. After 15
continuous minutes unfocused, the lifecycle disables and stops enabled servers
in the heavyweight registry. Lightweight servers stay running. Returning restores
only servers that idle sleep actually suspended. Never-used servers and servers
disabled before idle sleep stay disabled. Explicit toggle off clears the sleep
snapshot, so returning focus cannot resurrect those servers.

Buffers, unsaved text, undo, windows, and Vantage remain running. Servers get a
one-second shutdown grace period unless their configuration overrides it. An
initialization guard also stops late clients if their source buffer closes during
shutdown. The TypeScript heap limit and filesystem watcher settings are unchanged.

Focus comes from `FocusLost` and `FocusGained`. An asynchronous tmux query on UI
attachment catches editors launched in background sessions and checks all
clients. Newer focus events override older queries. Failed or malformed queries
preserve the last focus state. Losing the last UI starts the same idle grace
period; it does not quit or save the editor.

Background lualine queue checks run every second instead of every 16 ms. Its
periodic redraw runs every five seconds, and background buffer activity does not
queue redraws. Focus restores the original intervals and events and forces an
immediate refresh. Which-key and Snacks notifier polling are unchanged.

`:IdleStatus` reports focus, LSP mode (`lazy`, `authoring`, or `off`), deferred and
sleeping server names, the idle
timeout, and the last tmux query error. Newly started editors pick up these live
configuration files. Existing editors are not reconfigured automatically. No
system switch is necessary.

## Verification

Run from the monorepo root with the configured Neovim, Python, and installed
lualine plugin:

```sh
for spec in lsp_registry_spec lsp_lifecycle_spec lsp_first_use_spec \
  idle_spec idle_ui_spec idle_focus_spec; do
  nvim --clean --headless -i NONE -n -l \
    "pub/dotfiles-nix/mods/dotfiles/nvim/tests/$spec.lua" || exit 1
done
```

The tests use separate Neovim processes and a stdio LSP fixture. They cover
TypeScript/Python classification and first use, Deno selection, unconditional lazy
startup, the actual toggle keybinding, sticky off, buffer-local mappings, stock aliases,
capability checks, initialization failures and retries, timeout/cancellation,
unsaved-buffer synchronization, undo/layout preservation, unrelated servers,
background file opens, hung shutdown, overlapping resume, late initialization,
tmux startup, multiple clients, stale/failed queries, and UI detachment. The UI
test uses the installed lualine plugin and checks rendered statusline text.
The default launch also passed an isolated full-configuration startup check.

The broader `diffview_navigation_spec` intermittently aborts in native Treesitter
range handling on the installed runtime. It also crashes with the original HEAD
keymaps. Its navigation assertions passed three times with Treesitter highlighting
disabled only in the test processes. No production highlighting setting or plugin
pin was changed to hide that failure.

Local isolated measurements, with the filesystem caches already warm:

- Lualine timer callbacks over two seconds: 123 focused, 2 unfocused, 123 after
  returning. This measures lualine wakeups, not whole-editor CPU usage.
- Tiny TypeScript fixture: no server processes before first use; four processes
  using about 513 MiB RSS after first hover; cold hover 664 ms, resume hover
  311 ms.
- Tiny Python fixture with real basedpyright and Ruff: no processes before first
  use; three processes using about 204 MiB RSS; cold hover 616 ms, resume hover
  543 ms.
- One real Loancrate file in a separate minimal editor: no processes before first
  use; cold hover 342 ms, then a definition lookup in 2 ms and completion in
  32 ms. Four server processes used about 466 MiB RSS. Resume hover took 303 ms.

The process counts exclude the measurement's `ps` subprocess. Sleep terminated
all recorded server descendants, and cleanup terminated the resumed descendants.
The Loancrate trial did not modify its source file or existing editors. These
single-file samples do not measure a large multi-buffer session, full-workspace
indexing, compressed memory footprint, or filesystem-cache-cold startup.
