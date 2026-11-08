# Phases 1–3: maclab deployment and acceptance

Accepted on 2026-11-08 with the explicit preservation exceptions below.
Phase 4 remains deferred. This report records a deployed code candidate;
subsequent documentation commits do not describe another host switch.

## Deployment identity

- Code candidate: `4646c530eb38aae4392f05a40364cb3479e46e2a` on `mise`.
- Candidate CI: GitHub Actions run `42440422916`, successful on attempt 2.
  Ubuntu portable and all-host Nix jobs passed; macOS portable passed on retry.
  The first macOS attempt failed during `skills:sync`; its detailed temporary
  fixture was not uploaded, so the underlying cause is not established.
- Activated and verified system:
  `/nix/store/gq64xarh71ic1hzww3wxqn560v42673g-darwin-system-26.05.d31953c`.
- Previous system retained and rooted:
  `/nix/store/kn3bmxynygq9smlnj4n95jsq168vx1dx-darwin-system-26.05.d31953c`.
- Evidence directory on maclab, abbreviated **R** below:
  `~/migration_bk/20261108T122156Z-maclab-boundary-authorized`.
- Earlier phase evidence on the development machine, abbreviated **L**:
  `/tmp/mise-userland-probe`.

`activate.exit`, `system-backup.exit`, `authenticated-data-check.exit`,
`system-post-check.exit` and `admin-session.exit` are all zero. The active system
was compared with the rebuilt candidate, not inferred from the command exit.
Native administrator authentication stayed in maclab's Terminal. The protected
session ended and invalidated its sudo timestamp.

## Requirement-to-artifact checklist

| Requirement | Implementation / evidence | Acceptance |
| --- | --- | --- |
| Remove dead Nix plumbing | Phase-1 commit `7e77f1a2`; removal of `home.nix`, `homes/profiles/darwin.nix`, `mods/ui-packages.nix`, `overlays/oxlint-darwin-ps-fix.nix`, unused builder arguments and Look input | Implemented; phase-1 focused tests and four-host gates retained in L |
| Preserve system behavior during cleanup | `systems/profiles/darwin-maclab.nix`, `mods/base-packages.nix`, shell rebuild helpers; Spotlight disposable-plist proof | System Bash retained; duplicate GNU packages removed; live `womp=1`; narrow Spotlight mutation retained; pure rebuild tested |
| Simplify Supermicro and relocate orphan scripts | `homes/home-supermicro.nix`, shared profile, `systems/supermicro/`; removal of obsolete Python-version directory | Source changes evaluated, not activated on Supermicro |
| Standalone portable mise | `bootstrap.sh`, `mods/dotfiles/mise/config.toml`, host overlays and locks | Official 2026.11.2 binary retained; bootstrap preflights, source handoff and cold portable CI passed |
| Move configuration/runtime out of Nix | `mods/dotfiles/mise/runtime/`, native Claude/Pi plugins, config writers and skill deployment | Portable runtime/config preservation tests; R `userland-verification.log` and `approved-acceptance.log` |
| Shell identity and update orchestration | Shell profile/hostname mapping, `sys-update apply`, pure `nixswitch`, Karabiner source discovery, six `.envrc` overrides | Bash 3.2/current tests; live native direnv loaded a Nix dev shell; no nix-direnv or HM session bridge |
| Replace every HM responsibility | L `phase3-home-manager-inventory.json`; system package/default ownership, native editor/runtime, native service declarations | HM builders, inputs and obsolete wrappers removed; retained package paths and Linux defaults checked; four-host evaluation/dry builds |
| Preserve local builds and system exceptions | `mods/base-packages.nix` | Seven local CLIs resolve and start; GPG signs/verifies with an isolated key; Nix tooling/man/terminfo ownership retained |
| Native editor and provider | Neovim 0.12.6, `nvim/python/{pyproject.toml,uv.lock}`, Lua runtime and canonical local-plugin paths | R `editor-live/results.json`, both `full-nvim-*/report.json` variants and `vantage-backend.json` |
| Native LSP fleet | `nvim/lsp/`, registry and `tests/editor-lsp.py` | All 16 servers, including system-owned nil, attached on activated maclab; R `editor-live/lsp/report.json` |
| Native debugging adapters | Go/Python/TypeScript DAP configuration and maintained session probes | Python debuggee and JS initialization passed; Go debuggee passed after separately approved native developer authorization |
| Remove Mason/unused lldb ownership without deleting user state | Editor ownership tests and full-config assertion | No Mason plugins configured; old Mason data/lock entries retained; user plugin lock unchanged |
| OmniWM ownership and lifecycle | Native cask/launchd configuration, handoff guard and `tests/test_omniwm.py` | ARM artifact/signature and lifecycle fixtures passed; no ARM activation or OmniWM launch authorized/performed |
| Work-host PostgreSQL | Registry `postgres` 18.6, native locks, `tests/postgres.py` | Isolated SQL/dump/restore/socket/shutdown checks in L; no work-host activation or existing database access |
| Fresh inventory, plan and backup | R `inventory.json`, `plan.json`, `backup.json`, receipts | All packages keep-native; no new file retirement; backup integrity validated before mutation and again during final acceptance |
| Protected system backup | R `system-state-native.*`, restore-check directory and log | 284 entries, 129,358,848 bytes; restore/readback, metadata and ownership checked; four IPC objects omitted |
| Exact reviewed activation | R `candidate-system-ready.txt`, `activate.log`, `activated-system.txt`, `final-state.json` | Active system equals candidate; no other host activated |
| Real tool behavior | R `functional-*/functional-results.json` | GNU operations, Git clone/commit, compiler, utilities, completion, direnv, Atuin read and btop/fff/ncdu/watch passed |
| Existing tmux child environments | R `tmux-children.json`, saved PATHs | Both pre-existing servers passed full command-resolution probes; only temporary probe windows were closed |
| Skills, native package ownership and RTK | Unmodified host checks in `migration.verify`, R `approved-acceptance.log`, `rtk-check.json` | No missing declared packages or dangling skill links; casks remain mise-owned except approved Docker exception; RTK rewrite preserves host approval semantics |
| Stateful service preservation | R `final-state.json`, `preservation-baseline.json`, `native-services.json` | Original Tdarr process/profile/plist and five original tmux/Neovim processes preserved; Docker engine healthy; Tailscale NeedsLogin |
| Root checks and lint | L `phase3-keychain-root-{check,lint}.log` | All 15 root check projects and eight lint projects passed at the implementation checkpoint |
| Final change checks | L `phase3-docker-exception-{check,lint}.log`; candidate CI | Dotfiles gate passed, including 48 migration tests; all three CI jobs passed |
| Branch and scope restrictions | `origin/mise`, PR209 state, retained run roots | No main merge/rebase, PR merge, other-host activation, force reinstall, prune, zap or Nix GC |

The maintained documentation surfaces are ADR 0004, both tooling contracts,
`mise-migration/README.md`, shell ownership and agent guidance. Their ownership
model matches the implementation. The roadmap retains historical red/green
checkpoints rather than rewriting failed attempts as successful ones.

## Editor and debugging scope

Full startup was checked in isolated copies of maclab's current plugin cache,
both without an explicit restoration and after restoration to the user's lock.
The restored Git-backed plugin copies all matched that lock. Both startup paths
loaded the full configuration, Python provider and Lua/Python/Go/Bash parsers.
The actual checkout's Vantage backend also started under native Node and returned
a protocol validation response. These checks do not claim a live model request.

LSP acceptance covers gopls, lua_ls, jsonls, cssls, html, eslint, tailwindcss,
bashls, basedpyright, ruff, yamlls, zls, vtsls, denols, efm and nil_ls. ESLint and
Tailwind evidence establishes attachment/capabilities, not complete project
linting or CSS generation. Efm's formatter was exercised.

Python and Go probes launched, stopped, continued and terminated real disposable
debuggees. JS/Chrome acceptance is adapter initialization, as required by the
roadmap, not a complete JS debugging session.

Maclab initially denied Go's `task_for_pid` request. The operator explicitly
approved enabling standard Developer Tools authorization through native sudo.
R retains the before/after `system.privilege.taskport` rule exports, status and
`go-authorized-session.log`. SIP was not disabled and installed binaries were
not re-signed. The successful probe ran as the normal user after sudo was
invalidated. Its stdin was detached from the terminal to avoid a separate
controlling-terminal failure in the test harness.

Earlier plain-HOME cold-runtime evidence remains in L. Exact cold-cache plugin
pinning and the quoted-HOME upstream help-tag failure are not newly certified
by the copied-cache checks above. Phase 4's plain-Linux container proof remains
deferred, distinct from the passing portable Ubuntu CI job.

## Explicit preservation exceptions

### Apple synchronization files

The existing opt-in exception covers only the two named Apple synchronization
databases and their journals inside UUID keychain directories. Six files were
excepted in this run. Backup bytes still validate; main databases must remain
regular, nonempty files. It does not generally exempt login keychains.

### Login keychain: this run only

The final standard verifier failed because `Library/Keychains/login.keychain-db`
changed. Its size remained 189,568 bytes. The observed modification time was
15:38 UTC, after the 12:41 activation and before the later 16:49 editor probe.
This timing does **not** establish the cause or unchanged credential contents.

The operator explicitly accepted a one-run byte-identity exception after being
told that the cause was unproved. Both the original verified backup and the
observed live copy are retained. **Unchanged login-keychain credential contents
are not certified.** No live keychain was restored or overwritten.

R `login-keychain-exception-approved.json` binds this approval to the observed
before/after hashes. The independent read-only audit validates every saved file,
20 other credential files and all remaining live checks, retaining the six
separate Apple-sync exceptions. The production verifier was not weakened:
`post-activation-verification.log` remains a failure. R `approved-acceptance.json`
records acceptance under the explicit waiver; its driver reuses the remaining
host checks from the unmodified verifier after checking the exact approved drift.
Future migration runs retain the original strict login-keychain check.

### Docker Desktop: application-managed on maclab

The maclab declaration omits Docker; it does not request its absence. Its app,
data and native receipt remain. The receipt is byte-identical to the retained
pre-experiment copy. Docker uses System CLI integration; the original automatic
configuration-check preference was restored. The engine reports 29.9.2 with no
running containers. Other hosts retain their Docker declarations.

See `WORKAROUNDS.md` for the link-fingerprint incompatibility, rejected User CLI
mode and removal condition. Failed experiments remain preserved.

## Backups, failures and boundaries

- Atuin's earlier checkpoint removed SQLite journal/shared-memory files. The
  guard failed rather than ignoring that change. Reconstructed before/after
  copies passed integrity checks and retained all 862 store rows; a fresh
  snapshot was then taken after checkpointing. No stale journal was restored.
- Earlier authentication-only runs were closed without activation. Their logs,
  failed backups and roots remain. A zero EXIT-trap status from one cancelled
  session is explicitly distinguished from successful authorization/activation.
- The supplemental audit's first symlink comparison normalized a trailing slash;
  that false positive and its script are retained. Raw `os.readlink` comparison
  confirmed the link was unchanged. The standard verifier was unaffected.
- The retained GPG passed signing/verification using a short disposable HOME.
  Its first overly long fixture path could not start the Unix-socket agent;
  that failure remains recorded. Real user keys were not used or modified.
- APFS clones are not off-disk disaster protection. Noncredential live-file
  existence/size checks do not prove universal byte identity.
- Later baselines do not retroactively certify unchanged credentials across the
  historical 20261105 run's login-Keychain/mise/gh discrepancies.
- No application data or recovery roots were deleted. The user Neovim lock hash
  remains `a294391f312c0250dac222cf7e2f6ee152287971f96051f804b6c9d8009eb8b7`.

## Deferred scope

Phase 4 retains the mono backend, per-project toolchain/task migration, removal
of flake dev shells, final repository split/boundary lint, plain-Linux container
proof and login-shell migration. Supermicro's GitOps `nix develop` contract stays
unchanged. PR209 remains unmerged; this deployment is not a rollout to the fleet.
