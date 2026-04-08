# Restic Backup Script Design

Date: 2026-04-08

## Goal

Replace the current `rsync`-based `mods/dotfiles/supermicro_scripts/backup.sh` workflow with a simple `restic`-based snapshot workflow for the `supermicro` system, and add `restic` to `mods/system-packages.nix`.

The new script should keep all user-edited configuration at the top of the file, target a remote backup server over SSH, and stay easy to understand and maintain.

## Non-Goals

- Support separate user-facing "full" and "incremental" backup modes
- Keep the old mounted local backup disk workflow
- Add per-pair excludes, hooks, or restore helpers
- Add local filesystem checks or mount management to the backup flow

## High-Level Approach

The script will:

1. validate prerequisites
2. validate required environment variables and SSH config
3. iterate through ordered backup pairs
4. back up each source to a per-pair remote `restic` repository over SSH
5. apply retention to each repository
6. log and notify about success or failure

Every run creates a new `restic` snapshot. The script will not expose "full" or "incremental" modes, because `restic` already stores snapshots incrementally while preserving full restore behavior.

## Configuration Layout

All operator-tunable settings remain grouped at the top of `mods/dotfiles/supermicro_scripts/backup.sh` as global variables.

Expected top-level configuration includes:

- `SSH_HOST`
- `SSH_USER`
- `SSH_PORT`
- `REMOTE_REPO_BASE`
- `LOG_FILE`
- `RESTIC_PASSWORD_ENV_VAR="HOMELAB_BACKUP_RESTIC_PASSWORD"`
- `RESTIC_KEEP_LAST=5`
- `NTFY_TOPIC`
- notification tag value
- ordered `BACKUP_PAIRS`

`BACKUP_PAIRS` will keep the familiar `"source:destination"` shape, but the destination becomes a remote repository name under `REMOTE_REPO_BASE`.

Example shape:

```bash
SSH_HOST="backup.example.com"
SSH_USER="nick"
SSH_PORT="22"
REMOTE_REPO_BASE="/srv/restic/supermicro"

BACKUP_PAIRS=(
  "/home/nick/local_kube_data:local_kube_data"
  "/home/nick/local_kube_config:home_local_kube_config"
  "${STORAGE_MOUNT_POINT}:storage"
)
```

For each pair, the script builds a repository URL like:

```text
sftp:${SSH_USER}@${SSH_HOST}:${REMOTE_REPO_BASE}/${repo_name}
```

## Secret Handling

The script must require the environment variable `HOMELAB_BACKUP_RESTIC_PASSWORD`.

Behavior:

- On startup, the script checks whether the variable named by `RESTIC_PASSWORD_ENV_VAR` is set and non-empty.
- If it is missing, the script exits immediately with a clear error message.
- If it is present, the script exports its value as `RESTIC_PASSWORD` before calling `restic`.

The password is not hardcoded in the script and is not read from a separate password file.

## SSH Configuration

The script will leave a clearly grouped SSH config section at the top for the backup server details.

The script will not manage SSH keys. It assumes SSH authentication is already configured for the backup host.

The script should fail early if required SSH globals are empty.

## Package Change

`mods/system-packages.nix` will add `restic` to `environment.systemPackages`.

No local disk repair or HFS tooling is required for the new SSH-based backup flow.

## Script Flow

The new `backup.sh` flow is:

1. parse CLI arguments
2. initialize logging
3. install `ERR` and `EXIT` handlers
4. do not require root, because the SSH-based flow no longer depends on local disk repair or mount operations
5. verify required commands
6. verify SSH globals and the backup password environment variable
7. validate configured backup pairs
8. process each backup pair in order
9. send final success or failure notification

## Per-Pair Processing

For each configured pair:

1. validate the source directory exists
2. construct the remote repository URL from the shared SSH globals plus the pair repo name
3. initialize the `restic` repository if it does not already exist
4. run `restic backup <source>` against that repository
5. run `restic forget --keep-last 5 --prune` against that repository
6. record whether the pair succeeded or failed

The backup command should stay simple. The script will not add advanced tagging or custom SSH command wrappers unless needed later.

## Deletions and Snapshot Semantics

Intentional deletions in the source are handled by normal `restic` snapshot behavior:

- a new snapshot reflects the current state of the source
- files deleted from the source will not appear in later snapshots
- deleted files remain recoverable from older retained snapshots
- data is physically removed from the repository only after it is unreferenced by retained snapshots and `prune` runs

This keeps deleted data recoverable until it ages out of retention.

## Retention Policy

Retention remains intentionally simple because backups happen infrequently.

The script will use:

```bash
RESTIC_KEEP_LAST=5
```

and run:

```bash
restic forget --keep-last "${RESTIC_KEEP_LAST}" --prune
```

for each repository after a successful backup.

## Dry-Run Behavior

The script should preserve `--dry-run`.

Design intent:

- validation and config checks still run
- repo initialization is not performed in dry-run mode; the script logs that it would initialize the repo if missing
- backup and retention commands run in dry-run mode where supported by `restic`
- no repository data is changed during a dry run

## Failure Handling

Failure handling is split into two classes.

Fail-fast shared setup failures:

- missing required command
- missing `HOMELAB_BACKUP_RESTIC_PASSWORD`
- missing required SSH config globals
- malformed backup pair configuration

Best-effort pair-level failures:

- source missing for a pair
- repo init failure for a pair
- backup failure for a pair
- retention failure for a pair

If a pair fails, the script logs the failure, continues to the next pair, and exits non-zero at the end if any pair failed.

## Logging and Notifications

Existing logging and `ntfy` notification behavior should be preserved.

Updates needed:

- start notification reflects that a restic backup run has started
- per-pair log lines mention remote repository initialization, snapshot creation, and retention pruning
- final notification reports overall success only if all pairs succeed
- final notification reports a pair-failure summary if one or more pairs fail

## CLI Surface

The script should keep the CLI simple:

- `--dry-run`
- `--log-file <path>`
- `-h` / `--help`

`--skip-fsck` should be removed because the SSH-based flow no longer performs local filesystem checks.

## Success Criteria

The work is complete when:

- `mods/system-packages.nix` includes `restic`
- `mods/dotfiles/supermicro_scripts/backup.sh` targets remote `restic` repositories over SSH instead of local `rsync`
- all editable backup and SSH configuration remains at the top of the script
- the script exits with a clear error if `HOMELAB_BACKUP_RESTIC_PASSWORD` is not set
- the script leaves clear top-of-file placeholders for the backup server SSH details
- each backup pair writes to its own remote `restic` repository under `REMOTE_REPO_BASE`
- retention uses `keep last 5`
- shared setup failures stop the run immediately
- pair failures are best-effort and produce a final non-zero exit
