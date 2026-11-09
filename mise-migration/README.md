# Fleet rollout runbook

`rollout` moves one host from Home Manager to the mise-owned userland, or
catches up a host that is already on mise. It runs inside the host's
**privileged console**, a tmux session where the user authenticated sudo once,
so a dropped SSH connection never stops it. The agent drives it from the
**controller** (nicks-loancrate-mbp) over SSH and polls files in the run directory.

`run` selects a Python 3.11+ interpreter and runs `migration.py` (standard
library only). Paths below are relative to `pub/dotfiles-nix` unless absolute.

| Command | Where | What |
|---|---|---|
| `run preflight --host H` | host | Read-only checks |
| `run preflight --host H --rehearse` | host | Adds the dry rehearsal: plan, cask dry-runs, system **build**, lock coverage, run-time estimate |
| `run preflight --host H --console --ssh-alias A` | host | Creates the run directory, pins old tools, starts the console |
| `run remote-preflight --host H --alias A [--rehearse]` | controller | Copies this commit to the host's `/tmp` and preflights it there |
| `run reach --host H --alias A` | controller | Non-interactive SSH check |
| `run send --run-dir R -- TEXT` | host | Types one line into the console |
| `run status --run-dir R` | host | Step states, `rollout.exit`, sudo time left |
| `run rollout --host H --run-dir R` | console | Runs or resumes the migration (`R/rollout.sh` wraps it) |
| `run verify --host H` | host | Full verification on its own |
| `run restore --run-dir R [--apply]` | host | Compare with the backup; restore missing or emptied files |
| `run close --run-dir R` | host | End the privileged session |

Per-host decisions live in `hosts/<host>.toml`: casks to transfer, casks that
need a macOS approval, extra protected and regenerable paths, services to
quiesce, the controller and the SSH alias it uses, and known exceptions. They
are published with this directory, so addresses stay in the controller's
`~/.ssh/config` and in the private preflight packets.

## Run a migration session

1. **Confirm the branch and access.** On the controller, in its own checkout
   of `mise`, fetch and merge `origin/mise`. Run `run reach --host H --alias A`.
   On the host, `~/code/monorepo` must be on `mise` with no tracked changes:
   `git -C ~/code/monorepo fetch origin && git -C ~/code/monorepo switch mise
   && git -C ~/code/monorepo merge --ff-only origin/mise`. Untracked files stay.
   Done when `reach` exits 0 and the host's `HEAD` equals `origin/mise`.
2. **Rehearse if the code moved** since the host's preflight packet was
   written: `run remote-preflight --host H --alias A --rehearse`. Done when its
   summary is not `fail`, or every failure is a known wrap-up item.
3. **Open or reuse the console.** The user opens it in the attended preflight:
   `ssh A '~/code/monorepo/pub/dotfiles-nix/mise-migration/run preflight --host H
   --console --ssh-alias A'` prints the attach command and the start script; the
   user attaches, runs the script, authenticates once and detaches. Done when
   `run status --run-dir R` shows `privileges.live: true`.
4. **Start the rollout:** `ssh A "$RUN send --run-dir R -- bash R/rollout.sh"`.
5. **Poll** `run status --run-dir R` every few minutes. A step's details are in
   `R/steps/<n>-<step>.json`, its output in `R/rollout.log`. Done when
   `rollout_exit` is `0`.
6. **On a failed step**, follow the failure policy below, then send
   `bash R/rollout.sh` again; it resumes at the failed step.
7. **Hand over.** Copy `R/report.md` to the controller session's notes and
   give the user its wrap-up list. Done when the report exists, the `close`
   step shows the keepalive stopped and sudo invalidated, and no step is
   failed.

Three hosts may run at once from one controller, each from its own checkout
or worktree there and its own run directory on its host. Nothing in a run
reads or writes another host.

## Steps

| Step | Mode | What it does |
|---|---|---|
| console | both | Requires a live keepalive with at least half the estimate left |
| preflight | both | The read-only checks; any `fail` stops here |
| plan | both | Chooses `migrate` or `catch-up`; plans HOME file actions; stages the pinned mise if `~/.local/bin/mise` is absent |
| backup | migrate | One backup of protected data, APFS clones on macOS; a `tmutil` local snapshot attempt; supermicro's nightly rsync date |
| files | both | Removes Home Manager links and roots (roots kept as GC roots in the run), retires the legacy OmniWM agent, moves anything else in a mise target's way |
| switch | both | `sudo -n darwin-rebuild switch` or `nixos-rebuild switch` with the pinned command |
| bootstrap | both | `bootstrap.sh <host>`, then `mise run skills:sync` |
| rtk | migrate | Retires store-path RTK hooks (copies kept), then `rtk:setup`; best effort |
| casks | migrate | Quiesces services, transfers each declared cask (dry-run with an empty prefix, `brew uninstall --cask` without zap, `mise bootstrap packages apply`), applies formulae and OmniWM's agent, restarts services; best effort per cask |
| cleanup | both | Superseded Homebrew formulae and casks (`HOMEBREW_NO_AUTOREMOVE=1`), the gh-stack link, leftover Home Manager links |
| restore | migrate | Restores missing or emptied backed-up files that are not newer than the backup |
| verify | both | `verify --full`; warnings go to the wrap-up list |
| close | both | End marker, keepalive stopped, `sudo -k`, caffeinate stopped |
| report | both | `R/report.md` |

A host with no Home Manager generation whose `config.local.toml` already links
this checkout runs `catch-up`: switch, bootstrap, cleanup and verify.

## Failure policy

- **Required steps stop the run** with the console still privileged. Read the
  step's `error`, diagnose before changing code, fix forward, and resume.
- **Best-effort work continues.** A cask that fails, RTK setup, and checks that
  only warn become wrap-up items with exact instructions. A cask that needs a
  macOS approval gets "approve it in System Settings, then apply it" steps.
- **Data**: the harness removes only links into `/nix/store` or the checkout,
  uninstalls only through a package's own manager and never with zap, moves
  every other obstacle into `R/moved/`, and never deletes a backup. The user
  removes `~/migration_bk/*` after accepting the host.
- **Never** `--force`, zap, prune or Nix garbage collection; never push to
  `main`, merge PR #209 or switch another host.
- **If sudo time runs out**, the console step fails; the user re-runs the start
  script for a new window. Record the interruption in the report.
- **If macOS locks the login keychain** during the run, move keychain-dependent
  checks to the wrap-up list rather than prompting.

## Privileged console

`preflight --console` creates `~/migration_bk/<UTC time>-<host>-rollout`
(`R`), records the old generation's `python3`, `tmux`, `git`, `nix` and rebuild
command in `R/toolchain.json` with GC roots in `R/toolchain/`, and starts tmux
on `R/console.sock` with the pinned tmux and shell history off. Its start
script runs `sudo -v`, unlocks the login keychain on macOS, starts
`keepalive-until.sh` (a `sudo -n -v` every 60 seconds until the deadline or
`R/end-privileged-session`, then `sudo -k`) and `caffeinate -i -w` on macOS.
The window is twice the preflight's estimate plus an hour, capped at 12 hours.
The start script refuses other shells: their sudo timestamps cannot authorize
this console. A failed `sudo -k` fails close instead of certifying invalidation.

Drive the console with `run send`: it types one line with `send-keys -l` and
sends Enter separately. Never capture the pane while a password prompt could
be showing; poll files instead.

macOS reads of other applications' containers need Full Disk Access for the
SSH server: System Settings > General > Sharing > Remote Login > "Allow full
disk access for remote users". Without it the backup cannot read them.

## Sharing the mise branch

Up to three migration sessions push fixes to `origin/mise` concurrently.

- Before each commit: `git fetch origin && git merge origin/mise`; never
  rebase or force-push.
- Keep each fix small and prefix its subject with the host, for example
  `rollout(nicks-mbp): ...`. Re-run the narrowest failing test first.
- If a push is rejected, fetch, merge, re-run that test and push again.
- Pull the fix into the host checkout with `git merge --ff-only origin/mise`
  before resuming. The report lists every commit between the run's start and
  the host's `HEAD` under "Code fixes".

## After every host has migrated

- Delete the transitional Pi skill-path retirement from
  `mods/dotfiles/mise/runtime/configure-apps.ts` (`applyPiSkillPaths`, its
  `pi-skill-paths.json` input and tests) once Pi settings on every host no
  longer list the retired paths.
- Catch maclab up to the final commit with `rollout` in catch-up mode.

## Local checks

`run test` runs the harness tests: fake CLI boundaries and disposable HOMEs,
including a run killed mid-step that resumes at that step. They do not migrate
a real host.
