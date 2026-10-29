# Shell configuration: who owns what

Read this before changing anything under `mods/dotfiles/shell/`, or before
adding a `programs.<something>` to a nix module that also writes shell config.

## The rule

**Nix owns capabilities, host policy, and link reconciliation. Out-of-store
dotfiles own rapidly edited user configuration. Services own their runtime
environment and credentials.**

All supported systems use Home Manager. `mods/shell.nix` declares shell and
tool configuration as out-of-store links, so Nix owns each destination while
edits in the checkout take effect immediately without a rebuild.

## Ownership table

| Concern | Owner | Where |
|---|---|---|
| Packages: bash, fzf, atuin, starship, gh, git, direnv, bash-completion | nix | `mods/shell.nix`, `mods/git.nix`, `mods/base-packages.nix` |
| `gh` extensions (gh-stack), `nix-direnv` library | nix — inherently nix-shaped | `mods/shell.nix` |
| Machine facts: `MACHINE_NAME`, `PET_ADDL_SNIPPETS`, `STARSHIP_CONFIG`, `NPM_CONFIG_PREFIX`, `TERMINFO_DIRS` | nix `home.sessionVariables`, consumed via `hm-session-vars.sh` | `homes/*`, bridged in `bash/profile` |
| Unattended service credentials and runtime environment | the declaring Nix service | e.g. `gitopsSyncEntrypoint` in `systems/supermicro/configuration.nix` |
| `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.inputrc` | these dotfiles | `bash/` |
| fzf / atuin / direnv / starship / bash-completion **shell init** | these dotfiles | `bash/rc.d/` |
| atuin, git, gh **config files** | these dotfiles | `atuin/`, `git/`, `gh/` |
| Aliases and functions, including `sys-update`, `update-interactive`, and `nixswitch*` | these dotfiles | `bash/rc.d/5*` |
| Shell and tool configuration links | Home Manager | explicit out-of-store `home.file` entries in `mods/shell.nix` |

Home Manager is the only deployment adapter. The link inventory is explicit in
`mods/shell.nix`; `mkOutOfStoreSymlink` keeps source edits live while Home
Manager safely reconciles destination ownership. Git uses its standard init
template. Run `git-local-ignore` in a repository when it needs a private
`.gitignore_local` file.

## Sequencing contract

**`profile` is login-time environment only.** Environment variables and PATH.
No aliases, no functions meant for interactive use, no tool init, no
keybindings, no output. Must be safe to source non-interactively.

**`bashrc` is interactive only.** The interactive guard is its first statement.
Everything else is a numbered fragment in `bash/rc.d/`, sourced in lexical
order. The decade a fragment lives in defines what it may assume already ran:

| Range | Purpose |
|---|---|
| 10–19 | shell options and history |
| 20–29 | completion |
| 30–39 | early tool init — fzf before atuin |
| 40–49 | secrets and environment derived from them |
| 50–59 | aliases and functions |
| 60–69 | command wrappers and keybindings |
| 70–79 | version managers and prompt hooks — Starship before direnv |
| 80–89 | machine-specific |
| 90–99 | local overrides |

To disable a fragment, rename it so it no longer ends in `.sh`, or override it
from `~/.bashrc.local` (loaded at stage 99). This replaces the old
`.bashrc.d/excludes.txt`, which was an empty file and couldn't have worked
selectively anyway: `~/.bashrc.d` was a read-only store copy, so changing
anything there needed a rebuild.

## Shell integration policy

Prefer each tool's documented `init bash`, `hook bash`, or `activate bash`
command. Let `bash-completion` lazy-load version-matched completion files from
installed packages; do not vendor generated completion or preexec code when the
tool/package already supplies it. Scute is the narrow exception: its generated
Bash integration is one stable helper and binding, while launching its Bun CLI
to print those lines dominates startup. Bash uses standard Readline with vi
editing from `inputrc`. Ordering follows each hook's contract:

1. fzf initializes before Atuin so Atuin retains Ctrl-R.
2. Atuin loads its bundled bash-preexec backend for command lifecycle hooks.
3. mise initializes before Starship so Starship preserves its prompt hook;
   Starship registers its command and prompt callbacks with bash-preexec.
4. direnv initializes after every other prompt modifier, as its docs require.
5. Local overrides load last.

## Load-order hazards, all of which have bitten

The previous setup put the fragment loop *above* home-manager's own interactive
guard and *above* its `shellAliases`, so ordering silently decided things:

- **Define each update or activation command in one fragment.**
  `55-nix-aliases.sh` owns `nixswitch`, `nixswitchup`, and `nixclean`.
  `56-update-functions.sh` owns the `sys-update` dispatcher and its completion,
  and `update-interactive`, which only sequences those commands with yes/no
  prompts. Pin updates leave a diff; activation is always a separate command.
- **`update-interactive` never calls overlapping commands.** It pulls with
  `--ff-only` itself and then runs `nixswitch`, never `nixswitchup`; it runs
  `sys-update brew`, `nvim`, and `claude` separately, never `tools`. Pin
  domains come from `sys-update list --json`, filtered to `pub/dotfiles-nix`
  (the scope `sys-update pins` forces), so new domains appear without edits.
- **`have` is not a safe helper name.** bash-completion ends with
  `unset -f have; unset -v have` (it used to provide its own `have`), so any
  helper called `have` evaporates the moment `20-bash-completion.sh` runs, and
  every later fragment that used it fails. All helpers are `sh_`-prefixed.
- **PATH prepend order is precedence order, reversed.** `bash/profile` lists
  `.local/bin`, then `shell_scripts`, then `toolbox` to end up resolving
  `toolbox` > `shell_scripts` > `.local/bin`, matching the old
  `0050_shell.bashrc`. Writing them in the intuitive order inverts precedence.

## Known rough edges

Carried forward deliberately, because fixing them is a behavior change rather
than a port. Each is a separate decision:

- `alias ls='ls --color'` is a GNU coreutils flag. It works because coreutils is
  installed from nixpkgs everywhere and shadows BSD `ls`; on a machine with only
  BSD `ls`, this alias breaks `ls`.
- `PNPM_MANAGE_INSTALLATION=false` in `bash/profile` is not exported, exactly as
  before — which means pnpm itself can't see it, so the line may never have done
  anything.
- `40-secret-inject.sh` and `72-nvm.sh` print to stderr on a machine where their
  config or node version is missing. Pre-existing.
- Only bash is covered. There is no zsh/fish equivalent, because nothing here
  used one.

## Verifying a change

Run `./tests/workmux.sh` after changing the `workmux-pr-review-all` alias; it stubs
`gh` and `workmux-pr-review`.

`workmux-pr` and `workmux-pr-review` forward to `../toolbox/workmux_pr.py`.
Run `./tests/workmux-pr-review.sh` with current Bash and `/bin/bash` for quoting
and exit-status coverage. Test the small Python launcher from `../toolbox/` with
`python3 -m unittest discover -s tests -p workmux_pr_test.py`.

The launcher calls native `workmux add --pr <N> --open-if-exists`. Development
uses normal project configuration, which can install dependencies or start
services. Review adds the static lightweight profile, ordinary Neovim, and the
native configured agent. It skips setup/file operations and suppresses project
editor-init. Review/tour/recap skills are manual. There are no action, focus,
refresh, registry, snapshot, editor RPC, or cleanup operations in the helper.

Run `./tests/pr-review-native.sh /absolute/path/to/candidate-tmux-picker` for an
owned fixture using real Workmux, isolated tmux, ordinary Neovim, and a fake
agent. It checks skipped hooks/files, native reuse preserving local commits,
generic removal blocking, and normal development setup. It uses no live model,
GitHub API, or existing user workspaces.

The profile sets the Reviews category and a generic session removal block;
tmux-picker reads no purpose or manifest. Native Workmux removal can still run
project teardown. Activate a picker supporting removal blocks before opening
reviews; direct native removal bypasses them. The helper never installs tools,
activates configuration, updates checkouts, or removes user work.

Run `./tests/updates.sh` for update/activation command regression tests. Its
native commands and dependency CLI are fixtures; it never updates real tools
or runs a real rebuild.

Run `./tests/update-interactive.sh` after changing `update-interactive`. It
re-runs under the current Bash and `/bin/bash` (3.2 on macOS), feeds scripted
answers, and records every action boundary (git, `deps.ts`, native updaters,
rebuild, garbage collection) as a fixture call. It needs `jq`.

Run the focused smoke test after changing shell initialization. It starts the
installed login shell, fails on unexpected startup stderr, verifies generated
hook functions and prompt order, forces mise completion loading, and checks pet
and scute bindings under a PTY:

```bash
./tests/smoke.sh
```

Use `--simulate` to source a candidate `profile` and `bashrc` directly from the
checkout before rebuilding:

```bash
./tests/smoke.sh --simulate ..
```

After terminal-key configuration changes, also run the isolated tmux regression
suite (Python 3.11+, tmux and Bash; Neovim coverage runs when installed):

```bash
python3 ./tests/tmux-keys.py
```

It exercises native key negotiation, per-pane mode isolation, byte-exact
bracketed paste and Readline acceptance without modifying the running server.

Simulation retains the current `$HOME` and installed tools but bypasses
`/etc/profile` and `~/.bash_profile`, so run the installed mode again after
activating Home Manager.
