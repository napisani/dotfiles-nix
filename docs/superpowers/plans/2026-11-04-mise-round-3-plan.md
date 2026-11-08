# Mise migration, round 3: implementation plan

**Audience:** the implementation agent continuing the uncommitted `mise` worktree.
**Status:** approved direction, 2026-11-04. Builds on the
[round-2 plan](2026-11-03-mise-boundary-round-2-plan.md); decisions below are settled.

Read first: `docs/code-style.md`, `pub/dotfiles-nix/AGENTS.md`,
[ADR 0004](../../adr/0004-global-mise-lifecycles.md), the
[Homebrew follow-up](2026-11-03-mise-homebrew-follow-up.md) (this plan activates it)
and the repository `monorepo-deps` skill for every pin you add, move or delete.

**Implementation checkpoint (round 3b):** W1/W2 and the activation-ordering fix
are implemented. Missing/stale skill sources preserve the prior view; the
warning-only `skills:sync` task fetches and deploys after LaunchAgents, also exposed
as `sys-update skills`. Instruction templates are portable, Loancrate uses a native
merge, writers read authored sources directly, and global-only locking is enabled.
The migration preflights casks before uninstall, includes retired OpenCode cleanup,
and selects Python 3.11+ through `run test`. Maclab acceptance has not run.

### Round-3b evidence and limits

- 133 focused tests passed: 49 lifecycle/writer/activation, 14 configuration,
  eight skills, 16 RTK plus one real-Claude missing-import test, 18 migration,
  and 27 root-tooling tests. Shell smoke and update-command tests passed.
- All-system no-build flake evaluation and all four system build dry-runs passed.
  Native lock assertions cover platform artifacts, with the documented npm,
  pipx and version-only Go backend distinctions. No build-producing
  `make check FILTER=dotfiles-nix` was run under the dry-run-only restriction.
- Disposable native installs proved Atuin and goimports; actual EFM formatting
  found the goimports shim. Conda tmux failed Linux solving, so Nix 3.8 remains on
  all hosts, including supermicro's administrative system environment.
- Claude 2.1.308 loaded instructions with a missing `@RTK.md` against a loopback
  API fixture. Repeated upstream RTK initialization and native template applies
  preserved the instructions. No real-profile RTK setup occurred.
- A native Slack cask dry-run with an empty temporary prefix produced an install
  plan without writing that prefix. Failed-preflight tests keep the installed app.
  Downloads, privilege requirements and writes to the real prefix remain live-run risks.
- `make lint` remains red in Scute and in vantage-nvim/mushy-lint/pi-surface
  (missing `@oxlint/plugins`). The interactive-update fixture still expects old
  Homebrew text/commands; it is not evidence of a successful interactive flow.

The read-only work-Mac rehearsal is private at
`~/.local/state/mise-migration/round-3b.6hcYpw/` (0700). It planned five managed-link
replacements, nine keeps, 16 cask transfers, eight opt-in casks and five native
formula applies. Opt-in casks: tailscale-app, stats, karabiner-elements,
docker-desktop, 1password, ngrok, session-manager-plugin and zulu@17.
Cleanup candidates: actionlint, awscli, bk@3, coder, cone, nvm, opencode, pulumi,
workmux, plus old claude-code/codex casks. Nothing was applied or uninstalled.

Retired-tool search survivors are intentional: executable-absence checks in the
migration, retirement statements in README/AGENTS, historical `eelixir` health
notes in WORKAROUNDS, Claude streaming-protocol `delta` fields, and Mermaid's
mouse-wheel `deltaY`. No removed language tool remains declared.

## Settled decisions

**D1. Ownership is per tool per platform.** Use a tool's `os` filter in mise and the
same platform condition on the Nix side, so each host still has exactly one owner.
Confirm the per-tool `os` option on the pinned mise before relying on it.

**D2. Removed entirely:** delta, google-java-format, Erlang and Elixir. Remove every
consumer too, not just the package.

**D3. tmux 3.8, one owner fleet-wide.**
- First choice: `conda:tmux = "3.8"`. conda-forge publishes 3.8 for osx-arm64,
  osx-64 and linux-64.
- Accept it only if the lockfile records URLs and checksums for all three
  lockfile platforms, and the pinned mise runs the conda backend without new
  global settings.
- Fallback: Nix on every host. nixpkgs-unstable is already at 3.8; maclab builds
  the unstable expression against its package set. RTK now uses mise release artifacts (R8).

**D4. Kept, with their homes settled:**
- **atuin:** mise on `macos/arm64` and `linux`; Nix (with its test patches) only on
  x86_64-darwin.
- **java:** stays `temurin-11` in mise.
- **btop:** stays in Nix.
- **goimports:** moves to `go:golang.org/x/tools/cmd/goimports`; drop Nix `gotools`.

**D5. Homebrew moves to mise.** The nix-darwin `homebrew` module is removed
entirely, on every Mac, once mise declares every entry.
- Formulae become `brew:` entries.
- Casks become `brew-cask:` entries with `os = "macos"`.
- Xcode and mas are excluded from management (review requests R9/R11).
- Shared entries go in the core config; host-specific entries go in host fragments.
- Audit every tap. Declare only taps that a remaining entry needs, via the
  fully-qualified name or `[bootstrap.brew.taps]`.
- The Homebrew installation itself stays on disk this round.

**D6. Cask ownership transfers through the migration, not by editing TOML.**
- A cask Homebrew installed counts as installed for mise, but stays Homebrew-owned
  for upgrades.
- To transfer it: uninstall through Homebrew *without* `--zap`, then install it
  through mise. App bundles may be wiped and reinstalled; user data may not.
- Formulae need no transfer, because mise counts and upgrades Homebrew-installed
  formulae.

**D7. Carried over from the last review:**
- loancrate config becomes a `merge` entry in the work host fragment.
- The `~/.config/dotfiles/apps/` intermediate directory goes.
- The agent profile is read from the host TOML (single source of truth).
- `CLAUDE.md` and the Codex `AGENTS.md` move back to the core config.
- Transitional steps get removal conditions.
- `experimental = true` is justified or removed.
- `locked = true` is scoped to the global config.

**D8. Real hosts are touched only by the user.** The agent builds and proves the
migration in sandboxes. It may run read-only inventory on the machine it is on.
It never runs `migrate --apply`, a system switch, or Homebrew/mise package
changes against a real host.

## Workstreams

W1/W2 implementation is complete; W3/W4 live acceptance remains pending through
the user-approved maclab pilot below, not reconstructed Home Manager closure builds.

### W1. Removals and tool moves (D2–D4)

- **delta:** remove from `mods/languages/misc.nix`. Edit the Neovim consumers in
  `nvim/lua/user/lazy.lua` (the `backend = "delta"` setting) and
  `nvim/lua/user/snacks/init.lua` (the `cmd = { "delta" }` example) to use the
  plugin's built-in diff.
- **google-java-format:** remove from `mods/languages/java.nix`; delete the module
  if it ends up empty.
- **Erlang and Elixir:** remove `mods/languages/elixir.nix` and its `all.nix` entry,
  the `expert` server from `nvim/lua/user/lsp/registry.lua` and `nvim/lsp/expert.lua`,
  the `mix` formatter in `nvim/lsp/efm.lua`, and `$elixir` in `starship.toml`.
- **goimports:** move to the `go:` backend and delete `mods/languages/golang.nix`.
  Confirm efm still finds `goimports` through mise shims.
- **tmux:** apply D3. Remove the Nix `tmux` from `mods/shell.nix` when mise owns it.
  Report whether supermicro's system-level `tmux` should stay.
- **atuin:** apply D1 and D4.

Done when:
- `rg -n -i 'delta|google-java|elixir|erlang|expert' pub/dotfiles-nix --glob '!docs/**' --glob '!**/lazy-lock.json'`
  matches only intended survivors. Report each one with its reason. Words like
  "deltaY" in `mermaid.lua` are expected survivors.
- `mise lock -g` covers every changed tool on all three platforms.
- ADR 0004's exception table matches reality.

### W2. Configuration pipeline cleanup (D7)

- Replace `apply-loancrate-config.js` with a `merge` entry in
  `homes/nicks-loancrate-mbp/mise.toml`. Delete the script, its test and
  `common/loancrate.json.tera`.
- Pass authored source paths straight to `configure-apps.sh` from the Nix fragment.
  Delete the `~/.config/dotfiles/apps/*` entries.
- Derive `profile` in `mods/mise.nix` from the host TOML's `vars.agent_profile`
  (default `common`). Drop the machine-name comparison.
- Move the `CLAUDE.md` and Codex `AGENTS.md` templates into the core config. First
  verify Claude tolerates a missing `@RTK.md` import on a host without the Nix
  fragment. If it does not, report back rather than working around it.
- Record removal conditions for the empty Pi skill-paths writer and the legacy
  mise-completion removal in the cutover notes.
- `experimental = true`: name the feature that requires it in a comment, or
  remove it.
- Add `locked = true` with `locked_scopes = ["global"]`.

Done when `configure-apps.sh` contains only the writers that must remove keys:
the MCP maps, Pi `allowScripts` and the Claude/Codex hooks.

### W3. User-run maclab acceptance workflow

**Revised by the user during implementation:** the reconstructed four-host
Home Manager build/fixture loop was too aggressive. Use maclab as the real
testbed instead; agents do not switch it or mutate its installed packages.

The implementation and run order live in
[`mise-migration/README.md`](../../../mise-migration/README.md): read-only
inventory, a reviewed plan, private user-data backup, guarded pre-switch file
actions, explicit post-switch cask transfers, allowlisted cleanup, data
restoration and verification. Inventory evaluates desired link targets without
building linked-files closures.

Keep the deletion allowlist and data-preservation controls even on maclab:
its low stakes make it a useful test, not evidence that important hosts are safe.
The operator runs the system switch and native package changes, then verifies
credential bytes, data paths, package ownership, cleanup and tool resolution.
Seed canary data as well as checking existing app state.

Develop against focused temporary-HOME tests with fake package-manager
boundaries. No four-host fixture regeneration or linked-files builds are
required. Tests must go red for changed credentials, lost data, damaged
backups, stale plans, symlink escapes and wrong tool resolution.

Done when the **operator's maclab run** passes acceptance and app smoke tests,
with its commit and outstanding manual exceptions recorded. Do not infer
ARM/work-host or NixOS success from that result; repeat the preservation checks
on those hosts when they migrate.

### W4. Homebrew to mise (D5, D6)

1. **Inventory every entry** in `darwin-base.nix`, `darwin-loancrate.nix`,
   `darwin-maclab.nix` and `darwin-personal.nix`. Map each to its mise entry and
   host placement:
   - shared casks in the core config with `os = "macos"`;
   - Hex additionally limited to `macos/arm64`;
   - work casks and the formulae (ghostscript, graphicsmagick, pango, poppler,
     cocoapods) in the work fragment;
   - the personal and maclab casks in their fragments;
   - Xcode via `mas`.
2. **Audit taps.** `mongodb/brew`, `asmvik/formulae`, `jundot/omlx` and
   `kitlangton/tap` have no consumer in the current declarations. Drop each one
   that nothing needs. The implementation's local Homebrew inventory identifies
   `look` as `homebrew/cask`, so `kunkka19xx/tap` also has no current consumer;
   confirm maclab's inventory before transfer. Hex retains `anomalyco/tap/hex`.
3. **Classify each cask** from its Homebrew API artifacts:
   - **plain installed app bundle:** transferred by the operator's `post-switch --apply`;
   - **pkg/installer, system extension, launch daemon or privileged helper:**
     transferred only when listed in a per-host opt-in, and flagged for macOS
     permission re-approval. Expect docker-desktop, karabiner-elements,
     tailscale-app, zulu@17 and session-manager-plugin here.

   A cask whose artifacts mise does not implement stays declared in mise and
   installed by Homebrew, recorded as an exception.
4. **maclab (Intel):** `brew:` is unavailable there, and its existing casks live in
   `/usr/local/Caskroom`, which mise cannot see. The plan must uninstall them
   through Intel Homebrew (no zap) before mise installs them, or opt into `adopt`.
   Pick one and justify it.
5. **Remove the nix-darwin `homebrew` blocks** in the same change that adds the mise
   entries (atomic move). Keep nix-darwin's other macOS settings.
6. **Activation:** keep casks/formulae/App Store changes out of unattended
   activation until their ownership transfer is reviewed. Activation still applies
   repositories, tools and Claude/Pi packages non-fatally; the operator runs
   `post-switch` and later uses `sys-update brew` for native upgrades.
7. **Update** `sys-update`/`tools` in `56-update-functions.sh` from Homebrew
   commands to the mise package commands.

Done when:
- no Darwin profile declares Homebrew;
- every former entry is declared in mise or recorded as an exception;
- native package status on maclab reports the expected entries and ownership;
- the Homebrew follow-up distinguishes implemented declarations from pending
  live acceptance, with platform/installer constraints recorded.

### W5. Documentation

Update ADR 0004 (ownership per platform, Homebrew now mise-owned, removals), the
contract, the cutover notes (per-host migration via `mise-migration/`) and the
round-2 plan's Next steps (Homebrew is no longer deferred).

## Verification

Never switch or activate a host, and never run `migrate --apply` or package
changes outside a sandbox.

- `nix flake check ./pub/dotfiles-nix --all-systems --no-build` and the relevant
  host `--dry-run` build; no linked-files closure build prerequisite.
- Temporary-HOME migration tests, then user-run maclab acceptance. Record live
  results separately; local tests do not imply real-host success.
- `mise lock -g` covering all three platforms for every `[tools]` entry.
- `make check FILTER=dotfiles-nix` and `make lint` from the monorepo root.

Finish with a report covering:
- what moved, was removed or stays as an exception, and why;
- maclab's inventory/plan and subsequent host-specific results, including the
  manual/opt-in casks;
- the per-host run order you recommend for the user;
- anything you stopped on.

## Maclab acceptance precursors

Local precursor validation is complete; PR CI and live maclab acceptance remain
pending. No host has been switched or migrated.

- The link planner compares against the active Home Manager generation and keeps
  targets still owned by the next generation, regardless of changed store paths.
- Backup exclusions omit regenerable data without deleting it. Credentials and
  protected application/container state remain included. Optional estimates
  report logical and allocated bytes.
- macOS backup and restore use native APFS clones without a full-copy fallback;
  the sparse-copy regression and an isolated Intel maclab probe passed. The
  temporary same-volume backup is not protection against disk failure.
- Unfiltered root `make check` passed all 15 projects; `make lint` passed all
  seven. Proctmux used its pinned Zig 0.16, not the incompatible global 0.17.
- Native aarch64-darwin `nix flake check`, all four host build dry-runs, 21
  migration tests, 12 focused Scute tests and shell smoke/update tests passed.
- Cross-host Nix fixtures substitute native runtimes and writable checkout copies.
  Interactive package updates check for mise rather than the Homebrew executable.

The separately authorized acceptance run must follow `mise-migration/README.md`,
wait for green PR CI, confirm interruption timing and retain manual casks without
specific transfer approval. Other hosts still require separate authorization.
