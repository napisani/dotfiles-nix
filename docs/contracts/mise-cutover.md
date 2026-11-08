# mise cutover notes

## Maclab pilot

The initial maclab transfer completed under functional acceptance. Original
backups and failed strict mutable-data evidence remain; this is not blanket
preservation certification or fleet acceptance. The remaining-userland run
`20261105T214816Z-maclab-userland` activated its exact candidate and is explicitly
closed as partially verified in its `CLOSED.json`. Fresh-login functional checks
passed, but nested login PATH can select Apple Bash 3.2. Strict checks stopped
on mutable mise/Atuin state and changed login Keychain bytes; unchanged
credentials are not certified. Post-switch/cleanup acceptance is incomplete.
Retain that run's backups and failure evidence; do not reuse its sealed plan.

The [boundary roadmap](../superpowers/plans/2026-11-05-nix-boundary-roadmap-plan.md)
requires a fresh run after phases 1–3, following the
[fleet rollout runbook](../../mise-migration/README.md): preflight and dry
rehearsal → privileged console → one resumable `rollout` (backup, file actions,
switch, bootstrap, casks, cleanup, restore, verify) → the user's wrap-up list.
This replaces reconstructed four-host linked-files builds. Local tests are not
real-host acceptance, and maclab does not prove ARM/work-host or Linux behavior.

Casks use native `brew-cask:`; formulae use `brew:` on the ARM work host.
Xcode is not managed by these declarations. Retain Homebrew on disk. Intel casks transfer by native
Homebrew uninstall without zap followed by mise apply; no receipt importer or
blind adoption. Privileged/complex casks require explicit review and opt-in.
Activation excludes these native macOS packages so it cannot replace an old
Intel app before the reviewed transfer. `sys-update brew` performs native mise
upgrades after migration; it does not clean unrelated packages.

## Mise cutover

Native lifecycle is delegated to mise. The cutover deliberately uses mise's
ownership rules instead of importing the old ledgers or automatically
uninstalling/reinstalling existing packages.

- Keep existing installations, plugin secrets, histories, and native state.
- Preserve legacy install ledgers under `~/.local/state/agents-nix/` and
  `~/.local/state/nix-models/` as rollback evidence. Mise package lifecycle does
  not read or rewrite them. Existing configuration state such as Pi's skill-path
  tracking remains part of settings management.
- Preexisting native packages remain unowned by mise. Deleting their declarations
  will not remove them. A deliberate, separately reviewed native uninstall and
  mise apply can establish new ownership; first verify data/secret preservation.
  Claude uninstall can remove secure-store secrets even with `--keep-data`.
- Review any preexisting global mise config before the first switch. Merge
  needed tools, settings and authentication references into the authored TOML;
  standalone bootstrap rejects collisions; use the reviewed migration backup. There is no automatic
  global-config import or overwrite migration.
- npm CLIs use mise prefixes and stock shims ahead of the legacy shared npm
  prefix. Old prefix installations remain. After removing a mise tool, an old
  unowned executable may still become visible through PATH.
- Private mise roots from the isolated prototype, if deployed, are not imported
  or deleted. New shells use ordinary mise paths. Stop old lifecycle commands
  before applying or pruning with the global configuration.
- Removal is an explicit native prune, not an activation side effect. Other
  trusted tracked configs can retain packages/versions.
- Claude Code and Codex executable declarations move from Homebrew to existing
  mise backends, initially at the installed Homebrew versions. Existing casks are
  not uninstalled by this code; verify mise's executables before separately
  retiring the old casks. Homebrew cleanup remains non-destructive.
- Local model integration is retired: no runtime, models, provider options or
  shell helpers are declared. Existing model data and user configuration remain
  untouched; there is no destructive retirement hook.
- The unused read-aloud source and editable installer are retired. Existing uv
  installations and ledgers are not uninstalled or rewritten; review any native
  `uv tool uninstall read-aloud` separately, since its old source path is gone.
- Keep the empty Pi skill-path retirement writer until all four hosts have applied
  it, old managed paths are absent from Pi settings and its managed-path ledger,
  and a fresh Pi session discovers shared skills. Then remove its invocation,
  `pi-skill-paths.json`, writer and retirement-only tests; retain manual skill paths.
  No fleet cutover has been recorded.
- Never write mise's internal ownership format or claim ownership by reporting
  a healthy preexisting package as missing.
- An interrupted first install may remain unowned after retry. This is accepted
  mise behavior, not an invitation to create a local recovery engine.

A rollback restores old generation commands and file configuration, not mutable
native installations. An old generation may recreate or prune its tracked native
assets. Inspect both inventories before deliberately switching between old and
new ownership systems. Do not run both generations' lifecycle commands together.

No host was switched during implementation. Record actual deployment evidence
separately from successful evaluation and disposable-profile tests.

## Retired coding-agent cleanup

OpenCode is no longer declared or configured. No host installation or user state
is deleted during activation. The migration cleanup preview includes an installed
Homebrew `opencode` formula, with no replacement required. Only the operator's
reviewed cleanup can uninstall it, without zap; dependent formulae block removal.
The migration never runs blanket Homebrew cleanup. On every host, inspect `~/.config/opencode` and preserve
anything needed before removing it. Omitted top-level mise declarations leave
existing links in place; some will point at retired checkout sources.

## User-configuration cutover

The reviewed harness retires generation-matching legacy links and preserves
recognized Home Manager generations under backup GC roots. General profiles and
manual data remain untouched. Standalone bootstrap exposes source/configuration
links, then mise deploys authored destinations and native merges. The post-tools
task prepares runtime dependencies, providers, skills and app-aware writers.
Shared regular files retain unmanaged fields, hooks and credentials. Native
merges write in place. Failures propagate rather than becoming activation warnings.

The global config requires standalone mise >=2026.11.2. Install and verify it
before withdrawing the old Nix executable; changing a pin does not upgrade the
running binary. System activation itself no longer bootstraps userland.

Review existing global `config.toml`, `config.local.toml` and destination
conflicts before approving a real deployment. Native mise runs without force;
resolve unknown files explicitly instead of blanket cleanup. The host overlay
uses `config.local.toml` because `conf.d` cannot override the main global file.

Preview `mise -C "$HOME" bootstrap dotfiles diff`, then use
`mise -C "$HOME" bootstrap --only dotfiles` for user configuration or
`--only dotfiles,repos,tools` for configuration, sources and tools. Apply macOS
packages through the reviewed migration before using broad package commands.
Use `mise -C "$HOME" run apps:configure` to reconcile shared-file policies and
prepare providers/skills; the post-tools hook invokes this task. Direct dotfile
commands only apply their native declarations. Source, fragment and portable
runtime edits need no Nix switch; system build inputs do.

Mise removes stale owned entries within the skill group. Plain top-level
declaration omission leaves its applied link: explicitly select native
`mode = "absent"` or review `unapply` before removing that declaration.
File history is disabled, including temporary recovery preimages, because native
merge targets can contain app credentials. Existing history is not deleted.
Review that trade-off before enabling history. Authored fragments use references,
not secret values. Templates contain no commands.

A rollback across this ownership handoff is not a transactional rollback of
mise links/history or app state. Stop the other deployer, review conflicts and
restore the required source/bootstrap interfaces before deliberately applying
an older generation. No recovery or ownership-import layer is provided.

## Prebuilt-tool and runtime cutover

Each tool now has one declaration owner per platform; old user installations are
not automatically removed. Before switching, preserve needed global tool/config
entries and inspect existing `mise.lock` and `mise.local.lock`. Standalone bootstrap
links the checked-in lockfiles; they must exist in the checkout. Native sidecars
are resolved beside those files, not copied into a second ownership tree.

After a separately approved switch and successful mise install:

- Use `type -a node python go gh fzf starship scute proctmux` and the relevant
  host tools to verify precedence in a new login shell. Check project overrides
  separately. Also check btop, fff, direnv, Atuin, statix, tmux and Mac base
  commands from both login and non-interactive Bash. Scute/proctmux must resolve
  to local Nix builds; Mac GnuPG is a retained pinentry exception.
- Inspect old Homebrew formulae before removing any: candidates include workmux,
  gogcli, helm, awscli, pulumi, actionlint, coder, nvm, bk@3 and cone, depending on
  the host. Removing nix-darwin declarations leaves these installations on disk. Preserve formulae needed
  by unrelated software; do not run a blanket uninstall.
- Preserve `~/.nvm`, legacy npm prefixes and existing Python tool environments
  until their users and rollback requirements are understood.
- Inspect `~/.tmux/plugins/tpm`. If it is the old Nix/mise-owned artifact symlink,
  retire that link explicitly before `mise bootstrap repos apply`. Preserve any
  real checkout or modifications. Omitting the old dotfile declaration does not
  remove its link; native repository checkout must not be forced over it.
- Check mise-owned servers, formatters, providers and debug adapters in native
  Neovim from both tmux and a GUI launcher. Lua adds mise shims; nil remains a
  system package. Preserve old Mason data and the user's plugin-lock edits.
  Executable resolution alone does not prove server or adapter functionality.
- Keep `programs.nix-ld` enabled on supermicro for prebuilt dynamic executables.

ARM macOS package-only Scute and Neovim-wrapper builds passed during implementation.
Other platforms have evaluation and lock-resolution evidence only, not runtime
verification for the remaining-userland increment. The initial maclab cutover
has functional acceptance, not strict mutable-data certification. Delete these notes only after
all four hosts have switched and cleanup/rollback requirements are settled.

## Remaining-userland increment

Take a new inventory/plan/backup after landing all declarations and Nix changes.
The fingerprint includes evaluated targets, the package derivation and generated
mise fragment. Retain the original run and its receipts unchanged.

Mac base tools use conda, including unprefixed GNU coreutils/grep/sed. NixOS
retains its base tools and gcc in system packages. Login bash is unchanged;
Macs use Apple's compiler. GnuPG stays Nix-owned on Macs: conda's configured
pinentry executable is missing, and a protected fixture key failed signing after
agent restart. No real key material was used in that probe.

The login profile exports native `mise env` paths for child scripts. A disposable
100-iteration basename/grep/sed probe on ARM macOS produced identical output:
median Nix 1.20s, shims 13.01s, native `mise exec` paths 2.43s (three runs each).
Conda's own launch wrappers still have overhead; these figures do not establish
Intel performance. Independent launchd environments can use `mise exec` too.

The migration harness retires gh-stack's store-backed extension link and keeps
neighboring extensions. Mermaid CLI, Linux Chromium and the Neovim renderer are removed. Preserve GPG,
Atuin history/keys/session and GitHub extensions in the reviewed manifest.

## Historical migration gates

The following records predate the mise cutover and remain rollback evidence.
They are not automatic expiry dates.

## Vocal retirement

Old generations used `venv:vocal` in the uv ledger for removal-only dependency
cleanup. The mise cutover leaves that legacy environment and its ledger intact;
there is no new Vocal installation or automatic cleanup/adoption. Retire any
remaining tracked requirements through an explicitly reviewed cleanup once the
host and rollback inventory are known. Preserve unrelated venv packages.

| Host | Vocal migration generation / rollback cutoff | MCP audit |
|---|---|---|
| nicks-mbp | Pending | Pending |
| Nicks-Loancrate-MacBook-Pro | Pending | 2026-09-06: live Claude/Codex/Pi entries match declarations |
| maclab | Pending | Pending |
| supermicro | Pending | Pending |

These pending rows are not evidence that those hosts completed retirement.
Keep their original state files even though the new generation no longer reads
the legacy installation formats.

## Pre-switch managed-key audit

MCP keys are owned wholesale; manual entries under them do not survive apply.
This policy predates this refactor. Audit on **each target host**, using that
host's declarations and HOME, before switching:

```sh
cd pub/dotfiles-nix
python3 checks/audit-managed-mcp.py mods/dotfiles/mise/apps/work --home "$HOME"
```

Use `common` for the other hosts, and inspect that host's HOME.
Python 3.11+
is required. The audit never writes config and prints only entry names, not
credentials or values. Exit 0 means no existing entries would be overwritten
or removed; 1 means undeclared/changed entries need review; 2 means unreadable
config. Missing files are reported, not treated as destructive drift. Promote
needed manual entries/edits into declarations before applying. The local audit
above is not evidence about the other machines.

## Skills and RTK cutover

Skills no longer require Nix builds. The catalog is `mods/agents/skills.json`;
remote source commits live in mise's `[bootstrap.repos]`. Local source paths
are relative to the monorepo root. Common selections apply everywhere; work adds
its own selections. `sharedDirectory` exposes a local skill through
`~/.agents/skills`, where Pi discovers it; other selected skills get Pi-specific
directories. Required rewrites, manual-only controls and complete helper trees
are prepared together.

The old `~/.local/share/dotfiles-nix/agent-assets` bootstrap link disappears with
Home Manager. If an earlier version of this branch already deployed Nix-built
skills **through mise**, hand off that native group before changing its source root:

```sh
mise -C "$HOME" dot unapply --group agent-assets --dry-run
# After reviewing the owned links, repeat without --dry-run; never add --force.
```

Then switch/apply the prepared group. Pinned mise can skip relinking a
canonical-equivalent link and then prune it when the group source root changes;
a direct root change can therefore report success with missing links. The fixed
prepared-output root avoids that transition on ordinary catalog edits. The
handoff test verifies native unapply/reapply preserves manual neighbors. This
step is unnecessary for hosts that have never applied the intermediate mise group.
Native apply retires removed skills within the stable group. Keep old ledgers. Hermes reads the same
catalog and native repository pins; its derived lock is refreshed by dependency
updates in `mise-repos`.

The offline configuration phase preserves the last good skill view when sources
are missing or stale, or creates an empty view on a first run. The later warning-only
activation phase runs `skills:sync`: native repo apply, then a scoped dotfile apply
whose pre-hook prepares the acquired sources. Rerun explicitly with:

```sh
sys-update skills
# Equivalent: mise -C "$HOME" run skills:sync
```

Private sources need working Git credentials. Preparation uses private Nix
Python/PyYAML and never downloads. Missing checkouts or wrong commits defer output
replacement; dirty checkouts, wrong origins, malformed available metadata and
missing rewrite text still fail. First activation can start LaunchAgents without
skill sources; failed acquisition leaves the last good view in place. Native
dotfiles applies also prepare automatically. Catalog/source edits need an apply;
helper-runtime changes need a Nix switch. Unmodified local skills remain live.
Generated output under `~/.local/share/dotfiles/skills` is disposable; keep manual
skills in the agents' directories, not this output tree. Do not run preparation
and source updates concurrently.

### RTK ownership handoff

RTK uses the pinned `aqua:rtk-ai/rtk` tool. Setup is an explicit operator step,
not a dotfile hook or unattended activation action:

```sh
mise -C "$HOME" install aqua:rtk-ai/rtk
mise -C "$HOME" run rtk:setup
```

Before first setup, back up agent instructions/settings/hooks, the Pi extension,
and RTK's own data/filter directory. Inspect and deliberately retire only the old
managed links at `~/.claude/RTK.md`, `~/.codex/RTK.md` and
`~/.pi/agent/extensions/rtk.ts`, plus any Claude hook command pointing into the
Nix store. Preserve manual handlers and Workmux hooks. The task refuses symlinks
(including parent directories) and old Nix RTK hook commands; it never performs
that handoff for you.

RTK 1.1.0 overwrites an existing `RTK.md` without asking, even with Claude's
`--no-patch`; Codex rejects that flag. Setup therefore generates stock upstream
output in a disposable home **for comparison only**, refuses differing files,
then dry-runs every agent before invoking upstream init against the real home.
No generated resources are copied into the profile and no ownership ledger is
created. A previously stock file may differ after an upgrade: back it up and
review it before deliberately removing it and retrying. Leave applications
closed during setup; this is not a cross-file transaction.

Claude uses `--global --auto-patch`, Pi uses `--agent pi --global`, and Codex
uses `--codex --global`. Each passes `--no-trust-filters`; neither task nor
writers enable custom filters. Custom global-directory or RTK environment
overrides require review before this standard-path task can run. Authored
instructions retain the matching `RTK.md` references. Codex gains the upstream
PreToolUse hook, not only instructions. Subsequent Workmux/configuration applies
preserve both upstream hooks.

The host's existing Homebrew RTK is **not uninstalled or cleaned up**. That
requires separate approval. Verify mise shim resolution in a fresh login shell
and restart agents; test GUI/launchd resolution separately.

### Upgrade verification

Refresh native locks after changing the RTK tool pin. Require download URLs and
checksums for ARM macOS, Intel macOS and x86-64 Linux. In disposable homes, run:

```sh
RTK_TEST_BINARY=/absolute/path/to/isolated/mise-selected/rtk \
node --test pub/dotfiles-nix/checks/fixtures/rtk-setup.cjs
```

The tests run init twice and verify unchanged configuration, manual hooks,
Workmux coexistence, modified-file refusal, malformed JSON and symlink guards.
Upstream records invocations in its history database and can add Pi/OMP ownership
metadata on the second run; byte-identical bookkeeping is not promised. Test
native execution on each target platform before deploying there. No check
activates a real host.
