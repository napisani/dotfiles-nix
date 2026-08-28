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
| Aliases and functions, including the `nix*` rebuild aliases | these dotfiles | `bash/rc.d/5*` |
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
| 10–19 | shell options, history, and early ble.sh load without attachment |
| 20–29 | completion |
| 30–39 | early tool init — fzf before atuin |
| 40–49 | secrets and environment derived from them |
| 50–59 | aliases and functions |
| 60–69 | command wrappers and keybindings |
| 70–79 | version managers and late prompt hooks — Starship before direnv |
| 80–89 | machine-specific |
| 90–99 | local overrides, then final ble.sh attachment |

To disable a fragment, rename it so it no longer ends in `.sh`, or override it
from `~/.bashrc.local` (loaded at stage 99). This replaces the old
`.bashrc.d/excludes.txt`, which was an empty file and couldn't have worked
selectively anyway: `~/.bashrc.d` was a read-only store copy, so changing
anything there needed a rebuild.

## Shell integration policy

Prefer each tool's documented `init bash`, `hook bash`, or `activate bash`
command. Let `bash-completion` lazy-load version-matched completion files from
installed packages; do not vendor generated completion or preexec code when the
tool/package already supplies it. Ordering follows each hook's contract:

1. ble.sh loads with `--attach=none` before tool initialization.
2. fzf initializes before Atuin so Atuin retains Ctrl-R.
3. Atuin detects ble.sh and disables its less-accurate bash-preexec fallback.
4. mise initializes before Starship so Starship preserves its prompt hook.
5. direnv initializes after every other prompt modifier, as its docs require.
6. Local overrides load before ble.sh attaches at the very end.

## Load-order hazards, all of which have bitten

The previous setup put the fragment loop *above* home-manager's own interactive
guard and *above* its `shellAliases`, so ordering silently decided things:

- **`nixupgrade` was defined twice** — once in `0110_alias_and_func.bashrc`, once
  by nix. Nix was emitted later, so nix always won and the fragment's version was
  dead code for as long as both existed. The dead one is now deleted and the
  survivor lives in `55-nix-aliases.sh`, numbered after `51`.
- **Aliases now load before the command wrappers**, which they didn't before. A
  function definition inside `eval` is subject to alias expansion, so with
  `alias vim='nvim'` in effect, `eval "vim() { ... }"` defines `nvim()` a second
  time and `vim` never gets wrapped. `61-tmux-extended-keys.sh` disables
  `expand_aliases` around its loop. Quoting the name (`\vim()`) does not work —
  bash rejects a quoted word as a function name.
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

Simulation retains the current `$HOME` and installed tools but bypasses
`/etc/profile` and `~/.bash_profile`, so run the installed mode again after
activating Home Manager.
