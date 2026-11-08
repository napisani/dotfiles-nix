# Nix / mise / shell boundary roadmap

Status: phases 1–3 implemented and deployed to maclab on 2026-11-08, accepted with the explicit preservation exceptions in the [deployment audit](../../audits/2026-11-08-maclab-nix-boundary.md). Phase 4 remains a separate follow-up. Historical checkpoints below retain their original failures and verification limits.

## Accepted maclab deployment

- Reviewed code candidate `4646c530eb38aae4392f05a40364cb3479e46e2a`; CI
  `42440422916` passed. Run `20261108T122156Z-maclab-boundary-authorized`
  activated the exact rebuilt system after fresh sealed backup/plan checks and
  protected native authentication. No other host was activated.
- Native tools, both existing tmux servers' child environments, full Neovim,
  all 16 LSPs, Python/Go debuggees, JS initialization, local CLIs, GPG and RTK
  passed their scoped checks. Go required separately approved macOS Developer
  Tools authorization. Original tmux/Neovim processes, the user lock and manual
  Tdarr profile/process remain; Tailscale is disconnected.
- Docker is application-managed on maclab only. The operator also accepted
  observed login-keychain byte drift for this run only, in addition to the
  existing narrow Apple synchronization exception. Both keychain copies remain;
  unchanged login-keychain contents are **not certified**. The standard
  verifier's failure remains intact; no general login-keychain waiver was added.
- The linked audit maps requirements to actual artifacts and distinguishes
  copied-cache editor checks, adapter initialization and other bounded evidence
  from stronger claims. PR209 remains unmerged; all recovery roots are retained.

## Contract and decisions

Nix owns system configuration and base packages; nix-darwin owns macOS preferences. Mise owns portable user configuration and tooling. Shell code provides runtime configuration and orchestration, not another package or ownership manager.

User confirmations on 2026-11-05:

- Remove Home Manager from Darwin and NixOS after replacing its responsibilities.
- Remove the nix-direnv library, retain mise-owned direnv and existing project `use_flake` functions. The root, kube-home-lab, animalcontrol, proctmux, secret_inject and scrollbacktamer `.envrc` files were inspected: all override `use_flake` with `nix print-dev-env`. This does not establish usage in repositories outside this checkout.
- Install mise independently of Nix using the official installer. Check version and required capabilities before dropping the Nix executable.
- Defer the mono backend, per-project dev-shell replacement and final repository split to phase 4.
- Choose backups autonomously. Minimize data loss, retain prior evidence and report any loss or waived checks; final acceptance prioritizes actual tool functionality on maclab.

Commit on `mise`, push only `origin/mise`, leave PR209 unmerged. Activate maclab only. Preserve other people's edits, including maclab's four Neovim lock changes. Keep Tailscale disconnected and existing tmux servers alive. No force, zap, prune or Nix GC. Keep credentials out of logs and authentication panes out of captures.

## Entry gate: complete the userland rollout

Source: `7552560a7600cfa6cbadc96f954b2489ecf62856`.
Run: `/Users/nick/migration_bk/20261105T214816Z-maclab-userland`.

- Backup, pre-mutation data verification, native locked tool installation, candidate build and guarded migration returned zero.
- Plan retires only `.local/share/dotfiles-nix/shell-assets`; all 15 GUI casks are `keep-native`.
- Existing tmux servers 3.6a and 3.7b remain alive and accept client 3.7c. Their future-child PATH was updated using native mise env; old values are retained.
- Activation exited zero; active system and candidate are `/nix/store/kn3bmxynygq9smlnj4n95jsq168vx1dx-darwin-system-26.05.d31953c`.
- The run is explicitly closed as partially verified in `CLOSED.json`. Fresh-login functional checks passed (`functional-jpu14uni/functional-results.json`): command resolution, GNU behavior, Git, compiler, utilities, completion, direnv/flakes, Atuin history access and four terminal interfaces.
- Strict data verification did not pass: native Mermaid bookkeeping shrank, Atuin checkpointed/migrated its database, and login Keychain bytes changed. Backup integrity passed; Atuin integrity and stored-record counts agree. Unchanged credentials are NOT certified. Post-switch/cleanup acceptance remains incomplete; retain all failed checks and recovery roots, and never reuse this run's sealed plan.
- Nested login PATH can select Apple Bash 3.2 and break nix-direnv; retain its reproduction and fix it separately from behavior-neutral cleanup. A fresh registered login passes.
- The user confirmed sole writing ownership after peer coordination; the peer was notified before implementation.

Record actual command exits and functional probes. Restore the inventory's cask-manager filter after this run: native status retains excluded manager keys with `state = skipped`; checking only JSON keys was an incorrect test of filtering.

## Phase 1 — remove dead configuration and redundant system ownership

Re-read each candidate and prove it is unreferenced before removing it:

- `home.nix`, `homes/profiles/darwin.nix`, `mods/ui-packages.nix`, `overlays/oxlint-darwin-ps-fix.nix`.
- Unused `overlays` special arguments, the `look` flake input, and `machineRoles` / `useHomeManager26` builder arguments. Keep any currently used host-selection behavior until its replacement is explicit.
- Collapse supermicro's duplicated Home Manager composition into common configuration plus machine data. Preserve the userland change that moved GCC into system packages.
- **Approved exception:** retain the targeted Spotlight `postActivation` plutil mutation. The upstream defaults writer replaces the whole dictionary; a disposable macOS plist test proved it deletes unrelated hotkeys and key parameters. The user confirmed preserving the targeted update instead.
- Replace maclab's `pmset -a womp 1` with `networking.wakeOnLan.enable`.
- Remove Darwin system `coreutils` and `gnugrep` duplicates; keep the registered login bash and its system package.
- Move the unreferenced `mods/dotfiles/supermicro_scripts/` scripts to `systems/supermicro/`, as confirmed by the user. Inspect the lone `.python-version` under `global_python_scripts/` before removing that obsolete directory. Do not remove user modifications.
- Remove historical narration from the shell profile, bashrc, rc.d/10, 20, 30, 50, 51, 56, 80 and relevant Nix comments. Keep only necessary constraints.
- Test whether the `nixos-rebuild` helper needs `--impure`; remove it only with evidence.

Gate: focused shell/configuration tests, Nix checks, four host dry-run builds, `make check` and `make lint`. No host switch for this phase alone.

Implementation checkpoint:
- Removed the dead modules/template/overlay and their imports, unused roles/overlay arguments, and the Look input plus its orphan rust-overlay lock node. No other pin moved.
- Reduced Supermicro home configuration to machine identity; common configuration supplies the shared responsibilities.
- Kept system login bash, removed duplicate Mac GNU packages, and made Wake-on-LAN declarative.
- Relocated the two unused Supermicro scripts without executing them; removed the orphan Python 3.9 version file.
- Removed historical shell narration. Pure Supermicro dry-run passed; updated rebuild regression tests failed before removing `--impure` from the helper.
- All-system no-build evaluation and all four host dry-run builds passed. Bash/current and Bash 3.2 profile-path tests, simulated shell smoke, rebuild/update tests, migration tests, root `make check` and root `make lint` all passed. Root checks used the project-pinned Zig 0.16.
- Evidence lives under `/tmp/mise-userland-probe/phase1-*.log`; Spotlight proof is `spotlight-defaults-proof.json`. The intermediate maclab run's closure and detailed evidence remain in its retained run directory.

## Phase 2 — make mise configuration self-contained

Historical implementation checkpoint, before the accepted deployment:

- `bootstrap.sh MACHINE [--only PHASES]` preflights five links and both plugins,
  preserves matching links, refuses unknown targets and uses standalone mise.
  Ten CLI contracts pass. The real official installer and core-only dotfiles
  apply passed in a fresh HOME with spaces and quotes.
- Runtime files moved to `mods/dotfiles/mise/runtime/`, preserving relative
  imports. Core TOML declares post-tools app configuration, offline preparation,
  skill sync/group deployment and explicit RTK setup. Dependencies use npm's
  existing lock and a uv lock for PyYAML 6.0.3, matching the Nix dependency.
- `tests/portable-runtime.py` passed with official mise 2026.11.2: native Node,
  Python and uv install; real post-tools hook; shared-field preservation and MCP
  revocation; pinned source sync and ten shared skill links. PATH excluded Nix.
  This scopes tools to those three runtimes, not the entire global tool fleet.
- Project `mise.toml` owns test, lint, lock coverage and cold-runtime gates;
  root `make check`/`make lint` dispatch to it. Native tests now pass 76/76,
  including five upstream RTK cases that previously skipped without a binary.
  Bootstrap/lock contracts: 15 pass; skills: nine pass; migration: 42 pass.
  The migration suite exercises real Nix projections with a missing fragment
  and absent Home Manager, and fingerprints the system derivation as well.
- Active Home Manager imports no longer install mise, generate its fragment,
  link its config/plugins, add its shim PATH or run bootstrap activations.
  A lightweight Nix ownership check enforces that boundary. Inactive old
  module/check wrappers still need removal; other Home Manager modules remain.
- Restored cask-only inventory filtering. A real native CLI probe confirms
  excluded managers remain in JSON with package states `skipped`; checking key
  absence was wrong. A separate cold full-cask status probe failed on unavailable
  `hex` metadata/Ruby 3; it is not evidence of full GUI cold-start acceptance.
- Raised the minimum mise version to 2026.11.2: the source-root handoff/reapply
  regression fails on 2026.10.25 and passes on 2026.11.2. Only the `mise-src`
  flake-lock node was temporarily advanced through a targeted override. The
  input is now removed because production and test execution no longer use it;
  lock comparison confirmed every other input stayed unchanged.
- All-system no-build evaluation and root `make check FILTER=dotfiles-nix` /
  `make lint FILTER=dotfiles-nix` pass. Actionlint validates the new Linux/macOS
  portable and all-host Nix CI workflow; remote CI has not run yet.
- The earlier Nix configuration-check build timed out after 1200 seconds while
  compiling mise. That failure remains recorded; its check is now replaced by
  portable tests, not counted as a successful historical build.

Evidence: `/tmp/mise-userland-probe/phase2-*.log` and JSON reports, notably
`phase2-portable-runtime-post-tools-gate.json` and `phase2-official-installer.json`.
Post-switch now invokes the standalone entrypoint after generation retirement,
requires the installed standalone binary, sets HOME explicitly, and rechecks
bootstrap ownership on retries. Tests cover the full retirement/recreation path,
unknown targets and selecting the wrong binary. Bootstrap also refuses a stale
Nix fragment, including dangling links. Operator migration instructions reflect
this handoff and the separately staged inventory binary option.

All four host dry builds pass, as do full root `make check` and `make lint`.
The first full check exposed a stale dependency-domain assertion after removal
of the last remote flake tool input; it now asserts the actual ownership
boundary. Two other failures were PATH-dependent: Nix clang lacked Apple's
Security framework, and the tmux fixture timed out waiting for cat.
Platform utilities first on PATH resolved both without changing those projects.
Failure and rerun logs remain under `/tmp/mise-userland-probe/phase2-*`.

Next: finish remaining documentation/obsolete-wrapper cleanup, then phase 3 and
the fresh maclab deployment. Remote CI and live final functionality remain
unverified; these gates do not certify deployment or preservation.

### Runtime and lifecycle

- Move live writers, package plugins, shared helpers, `skills-prepare.py`, `rtk-setup.cjs` and `configure-apps.sh` out of Nix runtime packaging into the portable checkout tree. Preserve their established relative imports where possible.
- Move task/hook and skill-group declarations from `mods/mise.nix` into core TOML. Use stable source links and checkout-relative discovery, not a fixed checkout pathname or store paths.
- Provision Python/PyYAML through locked uv dependencies and Node/TOML through a checked-in npm dependency lock. Preserve CommonJS semantics. No Nix runtime or NODE_PATH dependency in production.
- Prepare skills after tools exist, inside `skills:sync`, then apply only the skill group. Test empty first-run sources and last-good views without private repository credentials.
- Run remaining shared-file writers from post-tools through mise runtimes, before Claude/Pi packages need allowScripts. Preserve manual fields, credentials, package lists, revocation, malformed-input refusal and file-history privacy.
- Move explicit guarded `rtk:setup` into core tasks; do not make it an unattended destructive initializer.
- Link Claude/Pi plugins from the live checkout. Retire verified old managed links through the harness, then link without force. Idempotent calls must preserve matching links and refuse unknown conflicts.

### Entry points

- Add idempotent `bootstrap.sh`: validate/install mise, determine machine, create the five global config/source/lock links, link plugins and run native bootstrap with an explicit package scope.
- Bootstrap must work before GNU user tools or language runtimes are installed. Preserve unknown existing files and leave actionable errors, not broad replacement.
- Separate cold-start preparation from ordinary apply only where sequencing requires it. Prefer native hooks/tasks over a parallel dispatcher or ownership ledger.
- Home Manager stops creating mise links and running its activation hooks. `sys-update` becomes the single orchestrator: system switch where applicable, then native bootstrap, skills and explicit RTK handling.
- Remove the Home Manager shims sessionPath dependency; the shell already supplies shims and native tool paths.

### Tests and migration

- Add project `mise.toml` tasks `test`, `lint`, `lock:check`; integrate them with `scripts/lib/projects.ts`.
- Move configuration, skills, RTK, plugin and platform-lock checks out of Nix derivations into portable tests. Keep behavioral regression coverage; remove assertions over obsolete writer names and activation strings.
- Keep Nix evaluation/build checks on the Nix side.
- Add red/green harness tests for retiring only generation-owned mise/source/plugin links, refusing unknown replacements and preserving rollback information.
- Extend sealed-plan fingerprints to cover the new portable runtime/configuration inputs after Nix stops capturing them. Preserve detection of Nix-only changes.

Gate: core-only bootstrap in a disposable HOME with no Nix fragment, native writer/privacy tests, lock coverage, migration suite, Nix gates and root checks. No per-phase host switch.

## Phase 3 — replace remaining Home Manager responsibilities

Historical implementation checkpoint (before deployment):

- Recorded all remaining Home Manager packages, files, activation names, session
  variable names, services and launch agents for four hosts in
  `/tmp/mise-userland-probe/phase3-home-manager-inventory.json`. OmniWM agents
  exist only on the two ARM Macs; PostgreSQL is work-host only. No systemd user
  services remain. Man pages, terminfo/locale variables and Linux MIME/font
  defaults still need explicit retirement/replacement decisions from code.
- The login profile no longer sources Home Manager session variables. Hostname
  mapping overrides stale inherited identity; the source link derives
  `DOTFILES_DIR`. System Bash is restored ahead of Apple's Bash after
  `path_helper`; missing optional shell helpers no longer break login.
  Both Bash 3.2 and current Bash pass the regression.
- Shell update helpers use `DOTFILES_DIR` and fail if checkout discovery fails.
  Karabiner generation derives its output from its own module location rather
  than a session variable, and no longer replaces a user's configuration link.
  A disposable-source test reproduced the manual-file replacement before the
  fix and now proves preservation even with stale checkout environment variables.
- Removed active nix-direnv library ownership and the obsolete checkout session
  variable from Home Manager. A fresh native direnv probe exposed missing
  `.direnv` directory creation in the six existing `use_flake` overrides, plus
  masked Nix failures. Each override now creates its profile directory and
  propagates evaluation failure; project dev shells are otherwise unchanged.
- Real native direnv loaded a copied root flake in a fresh directory without
  nix-direnv or a `DIRENV_BASH` override. Evidence:
  `phase3-native-direnv{,-green}.log` and `phase3-native-direnv.json` retain both
  failure and success. Portable tests and all-host no-build evaluation pass;
  shell update tests pass under Bash 3.2 and current Bash. CI test runtimes now
  include the already-declared jq and Deno for those added contracts.

- `sys-update apply` now validates the machine/source, switches the system when
  Nix is present, runs standalone bootstrap, syncs skills, and refreshes the
  calling shell's current-project mise environment. Each failure stops later
  steps. Interactive activation uses this command; RTK initialization remains
  separate as `sys-update rtk`. Pure `nixswitch` behavior is unchanged. Bash
  3.2/current-Bash ordering, failure, portable-host and interactive tests pass.
- Native Neovim 0.12.6 is pinned and locked for all three fleet platforms. Its
  Python provider has a dedicated `pyproject.toml`/`uv.lock`, installed by
  `nvim:prepare` into `$XDG_DATA_HOME/dotfiles/nvim-python` (standard HOME
  fallback). `apps:configure` prepares it. Startup disables Ruby and prepends
  mise shims idempotently before plugin loading. The active Home Manager
  Neovim import is removed; the Nix boundary check asserts it stays disabled.
- Fresh quoted-HOME bootstrap installs Node/Python/uv/Neovim without Nix on
  PATH, runs the real post-tools hook, preserves manual agent fields, syncs ten
  skill links and executes a Python RPC from native Neovim. Evidence is
  `/tmp/mise-userland-probe/phase3-cold-nvim-runtime.log` and the retained HOME
  `/private/tmp/portable-runtime 'quoted' 4vith557/evidence/`. This exercises
  provider/runtime setup, **not** the full plugin configuration or LSP/DAP.
- Migration tool verification recognizes the `nvim` executable. Sealed source
  digests now cover Neovim and shell sources as well as mise; a regression
  reproduces stale-plan acceptance of changes to the provider lock, Lua runtime
  and login profile, then proves all three rejected. Generated dependency
  directories remain excluded. The first attempted test used Apple's Python
  3.9 and failed to import `tomllib`; valid red/green evidence is the `-r2`
  pair in `phase3-native-source-{red,green}-r2.log`.
- Portable tests pass (`phase3-apply-provider-tests-r3.log`), all 42 migration
  tests pass including the real Nix projection (`phase3-migration-all.log`),
  root-tooling checks pass (`phase3-root-check.log`), and all-host evaluation
  and dry builds pass (`phase3-native-neovim-eval.log`,
  `phase3-all-host-dry-builds.log`). The dependency CLI sees the new Neovim
  pin in `mise-tools`. No existing tool pin moved during fleet locking.

- Declared and fleet-locked all thirteen additional language/debug tools below;
  native installation succeeds in the retained test HOME. Existing installed
  Mason versions supplied most pins; ZLS 0.17.0 matches the declared Zig version.
  The dependency CLI recognizes all thirteen (`phase3-editor-pins.json`).
- Removed Mason initialization, its module and three plugin specifications.
  No configured LLDB consumer was found beyond its installer list. Existing
  Mason data and all plugin lock entries remain untouched, including the entry
  containing maclab's user-edited Mason pin.
- Python DAP uses `debugpy-adapter`, with project interpreter callbacks for file,
  Flask and Dagster launches. The cold test launches and completes a real DAP
  session in a separate project venv that contains no debugpy, proving adapter
  and debuggee independence. Native JS adapters resolve the installed
  `src/dapDebugServer.js` via mise and run it through Node on loopback.
- Fresh quoted-HOME bootstrap passes provider tests, Python launch/termination,
  and Node/Chrome initialize handshakes (`phase3-cold-native-dap.log`; retained
  HOME `/private/tmp/portable-runtime 'quoted' zf40h8in/evidence/`). An earlier
  JS probe waiting for a pre-launch disconnect timed out; its evidence remains
  in `phase3-js-dap-handshake.log` and `js-dap-session/`. The passing JS probe
  certifies initialization only, not launch/disconnect or browser operation.
- Portable contracts, all 42 migration tests with Nix, root-tooling checks and
  all-host evaluation pass (`phase3-mason-contracts.log`,
  `phase3-editor-{migration,root-check,eval}.log`). Migration checks recognize
  actual language-server executables and validate the JS adapter as a module.

- Reproduced Delve's TCP listener and the failing stdio adapter contract
  (`phase3-go-transport-red.log`, `phase3-go-config-red.log`). Go DAP now uses
  a loopback server adapter. A real native debuggee launches, stops before
  writing its result, continues, terminates and disconnects. The initial
  successful session hit a cleanup `EPERM`; no debug processes remained.
  Successful disconnect now waits for Delve's normal exit instead of signalling
  its process group. The fresh quoted-HOME gate passes all 18 steps, including
  Go, Python and JS checks (`phase3-cold-go-dap.log`; retained HOME
  `/private/tmp/portable-runtime 'quoted' bzeyj4r6/evidence/`).
- `test:editor-lsp` clones exact plugin-lock commits into disposable evidence
  directories and exercises authored configurations without Nix on PATH.
  All 15 configured servers attach through mise; eleven return document
  symbols, Ruff publishes diagnostics, and EFM runs StyLua. ESLint/Tailwind
  coverage is attachment only. The fixture handles upstream command factories,
  includes Plenary and waits for asynchronous document indexing. The initial
  failures and passing gate remain in `phase3-lsp-first.log`,
  `phase3-lsp-r2.log`, `phase3-bash-lsp-retry.log`, `phase3-lsp-gate.log`.
  A retained run logged failed optional Deno registry-intellisense fetches;
  local TypeScript symbol requests passed. Plugin locks remain unchanged.
- Portable contracts pass (`phase3-go-lsp-contracts.log`). Native LSP acceptance
  is wired into both portable CI platforms, but remote execution is still
  pending. This does not certify full plugin startup or system-owned nil.

- Local Neovim plugins now resolve sibling projects through the canonical
  mise source link rather than `/Users/nick/code/monorepo`. The path contract
  fails before the fix and passes afterward (`phase3-local-plugins-{red,green}.log`).
  The fresh quoted-HOME portable gate passes all 19 steps, including this
  contract (`phase3-cold-local-plugins.log`).
- Added `tests/nvim-full.lua`: loads all registry modules, checks configured
  adapters, performs Python RPC and fails with a nonzero exit on visible
  startup errors. Full configuration passes in an isolated plain HOME with
  prepared dependencies and exact plugin-lock commits (`phase3-full-nvim-pinned.log`).
  Local plugin builds and all configuration copies were isolated; source and
  maclab plugin locks were not edited.
- This is not a clean first-plugin-install certification. The initial quoted
  HOME install hit a help-tag glob failure also reproduced by the existing Nix
  Neovim (`phase3-helptags-{minimal,nix-baseline}.log`). Plain-HOME experiments
  exposed an intermittent Gitsigns startup error and a fixture-induced mise
  shim loop from sharing a data directory through an alias. Broken shim links
  were retained, canonical shims rebuilt, and the plain fixture given its own
  physical data copy. Three unmodified-cache control startups and the strict
  pinned check pass. Disabling the module cache did not reliably fix Gitsigns,
  so no cache workaround or plugin-pin change was applied. Retained probes:
  `full-nvim-probe.py`, `full-nvim-plain.py`, `phase3-full-nvim-*.log` under
  `/tmp/mise-userland-probe/`; prepared fixture `/tmp/full-nvim-home-dk4yj2wl`.

- Enabled `nil_ls` after reproducing its exclusion from the registry. The
  retained Nix-owned binary attaches and returns two Nix document symbols;
  all 16 server cases pass (`phase3-nil-{red,green}.log`). Its move from the
  Home Manager package list to system packages is now implemented (see below). Portable CI
  still tests the fifteen mise-owned servers without Nix and explicitly
  reports that nil requires a separate `--nil` run. Registry tests pass in
  both Deno and non-Deno projects (`phase3-nil-registry.log`).
- Work-profile PostgreSQL now uses registry `postgres` 18.6 (Conda), matching
  the existing Nix package version, restricted to macOS ARM. Removed its Home
  Manager package and added a negative Nix ownership assertion; red/green
  evaluation is retained in `phase3-postgres-boundary-{red,green}.log`.
  Fleet locking changes only the work-host lock; the tested artifact and all
  dependencies match that generated lock (`phase3-postgres-artifact-match.log`).
- A standalone native PostgreSQL install initialized an isolated cluster,
  wrote SQL data, dumped/restored it, read the restored value and shut down.
  `SHOW listen_addresses` verifies no TCP listener. No existing databases or
  ARM system activations were touched. Evidence:
  `phase3-postgres-probe.log`, `phase3-postgres-acceptance-r2.log`, and
  `phase3-postgres-task.log`; maintained entry point `mise run test:postgres`.
  The first test's `/dev/null` password-file warning is retained; the fixture
  now uses a private empty password file rather than reading user credentials.
- Dependency inventory recognizes `postgres` in `mise-tools`; root-tooling
  checks, lock coverage, all 42 migration tests (including real Nix), all-host
  evaluation and four dry builds pass (`phase3-postgres-deps.json` and
  `phase3-postgres-{root-check,lock-check,migration,eval,dry-builds}.log`). Full root gates and
  remote CI remain pending after the rest of phase 3.

### Home Manager removal and final local gates

- OmniWM now uses the native ARM cask and `dev.mise.omniwm` LaunchAgent.
  Artifact checksum/signature checks passed without launching the app. Fixtures
  cover native plist rendering, hook ordering, legacy ownership rejection and
  a CLI path containing spaces. Real launchctl is sandbox-denied in those tests.
  The migration retires only a generation-matching legacy plist/job. Direct
  native part commands bypass hooks and are not an approved handoff shortcut.
- Removed Home Manager integration and both inputs, preserving every other lock
  node. Builders receive machine identity directly. Shared system packages retain
  nil, Nix tooling, login Bash, macOS GnuPG/man/ncurses and local monorepo builds.
  Retained maclab packages resolve to the same store paths as their former Home
  Manager packages. General `.nix-profile` ownership is unchanged (maclab's
  manually installed Tdarr remains there).
- Preserved the sixteen retired modules/check wrappers and their SHA256 manifest
  under `/tmp/mise-userland-probe/retired-home-manager-modules`. Updated active
  ownership, migration, shell, runtime and agent documentation.
- Generation retirement registers backup GC roots before unlinking live roots.
  A regression exposed retries trusting an existing symlink without repeating
  registration. Both pre-unlink and post-unlink interruption cases now pass;
  all 45 migration tests pass (`phase3-hm-root-retry-{red,green}.log`). Real Nix
  accepted repeated registration (`phase3-hm-root-registration-real.log`). Its
  roots query also removed two stale automatic-root links; no store GC ran.
- All-system evaluation passed. The first dry build caught conflicting string
  and list definitions of `TERMINFO_DIRS`; removing the redundant definition
  leaves nix-darwin's system/profile defaults. All four dry builds then passed
  (`phase3-hm-final-nix-gates{,-r2}.log`).
- Full root `make check`: all 15 projects passed. Full root `make lint`: all eight
  passed (`phase3-full-root-{check,lint}.log`). The migration retry fix was tested
  afterward with the complete migration suite.
- A fresh plain-HOME plugin install and subsequent startup passed the strict
  full-config check, including Python RPC and actual Lua/Python/Go/Bash parser
  loading/parsing. Sources/local plugins were copied, Vantage built natively,
  and installed native tool artifacts reused without a Nix PATH. Evidence:
  `phase3-full-nvim-cold-parsers.log`, retained HOME
  `/tmp/full-nvim-cold-zjwwqb9q`, and `full-nvim-cold.py`. This is cold plugin
  installation, not a fresh download of every tool or certification of every
  asynchronously requested parser. The cold pin audit found 44 matching plugin
  commits and the existing bootstrap selecting current stable lazy.nvim instead
  of its lock entry, changing only the isolated copy. Exact-lock prepared startup
  passed separately; cold exact-lock startup is not certified. Source and maclab
  locks remain untouched. The quoted-HOME upstream help-tag failure remains
  documented; no workaround or source plugin-pin change was made.

### Maclab preparation and approved Keychain boundary

- Phases 2–3 were pushed as `a3da89f6`; branch-scoped CI was enabled in
  `f67229c7` because PR209 conflicts with current main. It remains unmerged.
  `8a4304ad` corrected a fixture expecting macOS Homebrew inventory on Linux.
  CI run `42379060732` passed portable Ubuntu, portable macOS and all-host Nix
  checks. No merge/rebase of main was performed.
- Maclab received standalone mise 2026.11.2 and the checkout was fast-forwarded
  to `8a4304ad`, retaining its four Neovim lock edits. Its candidate system built
  successfully with those edits; the live system and legacy generation links
  have not been switched or retired.
- Preparation run `20261107T134956Z-maclab-boundary` retained a verified protected
  system archive (283 entries, 129,353,728 bytes; four IPC objects omitted).
  Two overly broad user-data attempts encountered live Brave/Stats file changes;
  their complete failure evidence and partial snapshots remain retained. Docker
  (zero running containers) and Stats were restored after quiescing them.
- Returned to the previously approved affected-data-only scope, adding affected
  host preferences and manual profile/bin paths. Its 162,040-path backup passed
  integrity readback. The live check then found five Apple-managed Keychain
  synchronization files changing before any generation retirement; the other
  22 credential files matched. The administrator session expired safely without
  activation.
- The operator explicitly approved a narrow exception for those Apple-managed
  databases/journals. The run was closed in `CLOSED.json` before policy edits.
  `--allow-apple-keychain-sync` preserves full backup validation and strict login
  keychain/other-credential checks, limits matching to two named database
  families in UUID directories, rejects missing/empty main databases and changed
  file types, and reports the byte-identity limitation. All 47 migration tests
  pass (`phase3-keychain-exception-{red,green}.log`). No unchanged iCloud
  credential-content claim is made.

- Explicit Keychain policy commit `dde4cc81` passed CI `42406781925` and local
  full root check/lint (15/8 projects). Run
  `20261107T193643Z-maclab-boundary-approved` validated its 162,040-path backup,
  retired the reviewed legacy links with backup GC roots and applied userland.
  Seventeen native package-command receipts were retained; the run stopped on
  Docker's pending ownership classification without activating the system.
- Docker Desktop retargeted four mise-owned system symlinks to the same actual
  binaries on restart. Operator-approved User CLI mode preserved the links but
  rewrote both managed Bash profiles; even portable marker blocks were replaced.
  A separately approved System-mode/configuration-check-disabled test still
  retargeted the links. Original configuration checking and clean managed shell
  files were restored; all experiments remain in
  `20261108T010815Z-docker-cli-handoff`.
- The operator approved a maclab-only Docker lifecycle exception. Its declaration
  is omitted on maclab, not set absent: keep the app, data and receipts, never
  uninstall/prune it, and verify the engine separately. Other hosts retain their
  declarations. The partially applied run was closed before this source change.

The deployment and remaining acceptance work from this checkpoint are recorded
in the accepted-deployment section above. Closed plans were not reused, and
native administrator authentication was not bypassed. Preserve this checkpoint
as evidence of the pre-deployment state.

### Neovim, language servers and debugging

- Install Neovim through `aqua:neovim/neovim`; remove `mods/neovim.nix` only after its behavior has replacements.
- Create a stable uv Python-provider environment with pinned pynvim; set `python3_host_prog` in Lua. Disable the Ruby provider. Add the `vim` shell alias and preserve EDITOR selection.
- Add GUI-safe mise shims in Lua without inserting empty PATH components.
- Remove Mason setup, mason-nvim-dap and the three Mason plugin declarations. Preserve unrelated Neovim lock edits and leave the existing Mason tree on disk unless removal is actually needed.
- Declare and lock the following for every applicable fleet platform:

| Server/adapter | Owner and verification |
|---|---|
| gopls | `go:golang.org/x/tools/gopls`; attach to a Go module |
| lua_ls | `lua-language-server`; attach to Lua |
| jsonls/cssls/html/eslint | `npm:vscode-langservers-extracted`; attach each server in suitable fixtures |
| tailwindcss | `npm:@tailwindcss/language-server`; attach in a Tailwind workspace |
| bashls | `npm:bash-language-server`; attach to shell |
| yamlls | `npm:yaml-language-server`; attach to YAML |
| vtsls | `npm:@vtsls/language-server`; attach to TypeScript |
| basedpyright | `pipx:basedpyright`; attach to Python |
| ruff/denols | Existing mise tools; verify real attachment |
| zls | `zls`; pin compatibly with Zig and attach to Zig |
| efm | `github:mattn/efm-langserver`; attach and exercise a formatter |
| Go debugging | `go:github.com/go-delve/delve/cmd/dlv`; DAP initialize/session probe |
| Python debugging | `pipx:debugpy`; verify its actual adapter entry point and DAP handshake |
| JS/Chrome debugging | `github:microsoft/vscode-js-debug` js-debug-dap artifact; resolve its real launcher and test DAP handshake |
| lldb | Remove only after confirming no consumer |
| nil | Retain as system-level Nix tooling; verify Nix attachment separately |

Update `lua/user/lsp/mason.lua`, LSP initialization/registry, `lua/user/lazy.lua`, and Go/Python/TypeScript DAP configuration. Capability/version output alone is not attachment or adapter-functionality evidence.

### Other owners and host identity

- Inspect OmniWM's existing module/launch-agent behavior; replace its package with the cask on the hosts that actually use it and preserve launch behavior through native launchd or an appropriate login item. No ARM host activation is authorized; report that runtime limitation.
- Move work-host PostgreSQL to registry `postgres` / conda, with artifact locks and disposable-platform checks rather than a work-host activation.
- Remove the nix-direnv library and `mods/shell.nix`; retain mise direnv and test project flake loading.
- Move nil, nixfmt and nix-search-cli to system packages.
- Make shell hostname mapping the shell identity authority, pass machine explicitly through flake builders, and use it to choose bootstrap's host overlay.
- Remove the Home Manager session-variable bridge. Derive `DOTFILES_DIR` from the source link and replace `DOTFILES_HOME_MANAGER_DIR` consumers, including shell helpers and Karabiner references.
- Prefer native completion prefixes; remove retired per-user Nix profile fallbacks only once the replacement covers actual callers.
- Enumerate every Home Manager package, file, session variable, service and launch agent before removal. Preserve required behavior, not only package names.
- Remove Home Manager builders/inputs and Intel-specific Home Manager plumbing. Use one package set per host while retaining Intel support.
- Until phase 4, retain local monorepo builds as explicitly documented system-package exceptions. Preserve the known working GnuPG/pinentry system exception rather than break signing.

### Migration

Add red/green retirement checks for old generation links and the actual Home Manager-owned profile. Do not assume an arbitrary `.nix-profile` is Home Manager-owned. Preserve unknown/manual links and active process dependencies.

Build phases 1–3 together, commit/push to origin/mise, then take a fresh maclab run. Keep prior roots/backups. Install and verify standalone mise before withdrawing its Nix executable. Migrate links, switch, bootstrap and verify tools/services. Do not run simultaneous old/new deployers.

## Evidence and completion checklist

Maintain phase reports with changed ownership, retained exceptions, gates and blockers. Update ADR 0004, both tooling contracts, the migration README, shell ownership and agent guidance.

For each phase:

- Focused red/green tests for ownership and runtime changes.
- Portable mise tasks once introduced, plus `bash pub/dotfiles-nix/mise-migration/run test`.
- `make check` and `make lint` from root, using project-pinned compilers where necessary.
- `nix flake check` and dry-run builds for personal ARM Mac, work ARM Mac, Intel maclab and NixOS supermicro.
- Inspect the diff and ensure pin/lock changes came through the dependency workflow.

For the final maclab run:

- Record commit, source/plan identity, candidate and active system, commands and real failures.
- Verify login, non-interactive, GUI/editor and existing tmux subprocess resolution where affected.
- Exercise GNU commands, Git, Atuin history access, btop/fff TUIs, statix, tmux, direnv/flakes, providers, each migrated LSP and each DAP adapter.
- Verify local monorepo commands, retained GPG, skills, RTK and affected launch services; verify unchanged GUI package ownership and disconnected Tailscale.
- Preserve the four original Neovim lock edits and existing tmux servers. Record any app-state differences without claiming unproved preservation.
- Map every named handoff item to its actual artifact/test or an explicitly approved deferral. Unknown or untested functionality is not complete.

## Deferred phase 4

The mono backend, per-project mise toolchains/tasks, replacing flake dev shells, the final portable/Nix directory split and its boundary lint, and the plain-Linux container proof remain a separate track. Preserve supermicro gitops-sync's `nix develop` contract. Login-shell migration is also deferred. Recheck old conda/Linux limitations rather than treating historical failures as current facts.
