# Shell configuration: who owns what

Read this before changing anything under `mods/dotfiles/shell/`, or before
adding shell configuration to a Nix module.

## The rule

**Nix builds prerequisites and publishes host facts. Mise deploys authored
configuration and user environment. Applications/services own runtime state and
credentials.**

Standalone bootstrap links the canonical source and configuration. Shell and
tool links belong to global mise declarations, preserving live edits without a
rebuild.

## Ownership table

| Concern | Owner | Where |
|---|---|---|
| Login bash and Mac GnuPG | Nix prerequisites | `mods/base-packages.nix` |
| Mac base userland, user tmux, direnv, Atuin, btop, fff and statix | mise tools | core `[tools]` with platform selectors |
| NixOS base userland and administrative tmux | NixOS OS layer | `mods/system-packages.nix` |
| fzf, starship, gh, prebuilt CLIs and language runtimes | mise tools | core/host `[tools]`; one owner across hosts |
| TPM | mise pinned repository | core `[bootstrap.repos]` |
| Project environment loading | Native direnv, project `.envrc` and one deployed `use_flake` | `mods/dotfiles/direnv/lib/use_flake.sh`; no nix-direnv |
| Shell machine identity and source path | Authored profile | Hostname mapping and canonical source-link resolution in `bash/profile` |
| User preferences and extra pet snippets | mise `[env]` | global and host TOML |
| npm prefix/authentication references | mise native INI merge | `mise/apps/{common,work}/npmrc.tera` |
| Unattended service credentials and runtime environment | the declaring Nix service | e.g. `gitopsSyncEntrypoint` in `systems/supermicro/configuration.nix` |
| `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.inputrc` | these dotfiles | `bash/` |
| fzf / atuin / direnv / starship / bash-completion **shell init** | these dotfiles | `bash/rc.d/` |
| atuin, git, gh **config files** | these dotfiles | `atuin/`, `git/`, `gh/` |
| Aliases and functions, including `sys-update`, `update-interactive`, and `nixswitch*` | these dotfiles | `bash/rc.d/5*` |
| Shell and tool configuration links | mise | `[dotfiles]` in global/host TOML |

Mise owns authored links. Nix owns system packages, not user configuration or
bootstrap execution.
Git uses its standard init template. Run `git-local-ignore` in a repository
when it needs a private `.gitignore_local` file.

## Sequencing contract

**`profile` is login-time environment only.** Environment variables and PATH.
No aliases, no functions meant for interactive use, no tool init, no
keybindings, no output. Native `mise env --shell bash` supplies environment
exports, not interactive hooks, so child scripts avoid per-command shim startup.
Must be safe to source non-interactively.

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
from `~/.bashrc.local` (loaded at stage 99).

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

- **Define each update or activation command in one fragment.**
  `55-nix-aliases.sh` owns `nixswitch`, `nixswitchup`, and `nixclean`.
  `56-update-functions.sh` owns the `sys-update` dispatcher and its completion,
  and `update-interactive`, which only sequences those commands with yes/no
  prompts. Pin updates leave a diff; activation is always a separate command.
- **`update-interactive` never calls overlapping commands.** It pulls with
  `--ff-only` itself and then runs `nixswitch`, never `nixswitchup`; it runs
  `sys-update brew`, `nvim`, and `claude` separately, never `tools`. Skill-only
  updates use `sys-update skills` outside that interactive flow. Pin
  domains come from `sys-update list --json`, filtered to `pub/dotfiles-nix`
  (the scope `sys-update pins` forces), so new domains appear without edits.
- **`have` is not a safe helper name.** bash-completion ends with
  `unset -f have; unset -v have` (it used to provide its own `have`), so any
  helper called `have` evaporates the moment `20-bash-completion.sh` runs, and
  every later fragment that used it fails. All helpers are `sh_`-prefixed.
- **PATH prepend order is precedence order, reversed.** `bash/profile` lists
  `.local/bin`, then `shell_scripts`, then `toolbox` to end up resolving
  `toolbox` > `shell_scripts` > mise tool directories > stock mise shims > `.local/bin`.
  Mise paths precede the legacy npm prefix; shell scripts and editable
  toolbox commands retain precedence. Writing prepends in the intuitive order
  inverts precedence.

## Known rough edges

Fixing each of these changes behavior, so each is a separate decision:

- `alias ls='ls --color'` is a GNU coreutils flag. It works because coreutils is
  installed through conda on Macs and NixOS system packages on Linux, ahead of
  BSD `ls`; on a machine with only
  BSD `ls`, this alias breaks `ls`.
- `PNPM_MANAGE_INSTALLATION=false` in `bash/profile` is not exported, so pnpm
  itself can't see it and the line may have no effect.
- `40-secret-inject.sh` prints to stderr when its configuration is missing.
  Node versions come from mise; no NVM fragment is loaded.
- Only bash is covered. There is no zsh/fish equivalent.

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

Run `bash ./tests/profile-path.sh` and `/bin/bash ./tests/profile-path.sh` for
isolated profile precedence checks, including empty PATH components, inherited
shim entries, real tool directories and repeated logins.

Run the focused smoke test after changing shell initialization. It starts the
installed login shell, fails on unexpected startup stderr, verifies generated
hook functions and prompt order, forces mise completion loading, and checks pet
and scute bindings under a PTY:

```bash
./tests/smoke.sh
```

Use `--simulate` to source a candidate `profile` and `bashrc` directly from the
checkout before applying it:

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
deploying the system and portable user configuration.
