# Restic Backup Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `supermicro` backup script's `rsync` workflow with per-pair `restic` repositories, require `HOMELAB_BACKUP_RESTIC_PASSWORD`, and add `restic` to system packages.

**Architecture:** Keep the existing mounted-disk workflow and top-of-file global configuration, but reinterpret each `BACKUP_PAIRS` destination as a restic repository path. Refactor the Bash script just enough to make its behavior testable with stubbed commands, then migrate validation, backup, retention, and error handling around `restic`.

**Tech Stack:** Nix, Bash, restic, hfsprogs, curl

---

## File Structure

- Modify: `mods/system-packages.nix` - add `restic` to `environment.systemPackages`
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh` - replace `rsync` flow with `restic`, keep globals at the top, preserve logging/notification flow
- Create: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh` - shell regression tests using temporary directories and stub executables

## Task 1: Add a shell regression harness for the backup script

**Files:**
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh`
- Create: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Write the failing test for the missing password env var**

Create `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh` with this initial test harness and test:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backup.sh"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TEST_TMPDIR}"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "${haystack}" == *"${needle}"* ]] || fail "expected output to contain: ${needle}"
}

run_missing_password_test() {
  local output
  set +e
  output="$({ env -i PATH="${PATH}" bash "${SCRIPT_PATH}" --help; } 2>&1)"
  local status=$?
  set -e

  [[ ${status} -eq 0 ]] || fail "help command should exit successfully before this refactor"
  assert_contains "${output}" "Usage: backup.sh"
}

run_missing_password_test
printf 'PASS: backup_restic_test.sh\n'
```

- [ ] **Step 2: Run the test to establish the starting point**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: PASS, confirming the harness runs before tightening startup validation.

- [ ] **Step 3: Make the script source-friendly so later tests can exercise functions safely**

Change the end of `mods/dotfiles/supermicro_scripts/backup.sh` from:

```bash
main "$@"
```

to:

```bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

- [ ] **Step 4: Expand the test harness with restic-oriented command stubs**

Append these helpers to `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`:

```bash
make_stub_bin() {
  local dir="${TEST_TMPDIR}/bin"
  mkdir -p "${dir}"
  cat >"${dir}/fsck.hfsplus" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"${dir}/mount" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"${dir}/mountpoint" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  cat >"${dir}/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"${dir}/restic" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${RESTIC_LOG_FILE}"
if [[ "$1" == "--repo" && "$3" == "init" ]]; then
  mkdir -p "$2"
  : >"$2/config"
fi
exit 0
EOF
  chmod +x "${dir}"/*
  printf '%s\n' "${dir}"
}
```

- [ ] **Step 5: Re-run the test harness after the main-guard change**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: PASS

- [ ] **Step 6: Commit the harness setup**

```bash
git add mods/dotfiles/supermicro_scripts/backup.sh mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh
git commit -m "test: add backup script harness"
```

## Task 2: Add Nix package support and top-level restic configuration

**Files:**
- Modify: `mods/system-packages.nix`
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Write the failing test for required password validation**

Replace the test function in `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh` with this version:

```bash
run_missing_password_test() {
  local backup_mount="${TEST_TMPDIR}/backup"
  local storage_mount="${TEST_TMPDIR}/storage"
  local log_file="${TEST_TMPDIR}/backup.log"
  mkdir -p "${backup_mount}" "${storage_mount}"

  local output
  set +e
  output="$({
    env PATH="$(make_stub_bin):${PATH}" bash -c '
      source "$1"
      assert_root() { :; }
      BACKUP_MOUNT_POINT="$2"
      STORAGE_MOUNT_POINT="$3"
      LOG_FILE="$4"
      NTFY_TOPIC=""
      BACKUP_PAIRS=("$3:$2/repos/storage")
      main --skip-fsck
    ' bash "${SCRIPT_PATH}" "${backup_mount}" "${storage_mount}" "${log_file}"
  } 2>&1)"
  local status=$?
  set -e

  [[ ${status} -ne 0 ]] || fail "backup should fail when password env var is missing"
  assert_contains "${output}" "HOMELAB_BACKUP_RESTIC_PASSWORD"
}
```

- [ ] **Step 2: Run the test and verify it fails for the right reason**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: FAIL because `backup.sh` does not yet validate `HOMELAB_BACKUP_RESTIC_PASSWORD`.

- [ ] **Step 3: Add `restic` to system packages**

Update the package list in `mods/system-packages.nix` to:

```nix
  environment.systemPackages = with pkgs; [
    tmux
    unzip
    wget
    kubectl
    kubekill
    opencode
    restic
    # for fixing the backup disk occasionally
    hfsprogs
  ];
```

- [ ] **Step 4: Replace the top-of-file rsync globals with restic globals**

Update the configuration block near the top of `mods/dotfiles/supermicro_scripts/backup.sh` to:

```bash
DEVICE="/dev/sde2"
BACKUP_MOUNT_POINT="/media/backup"
STORAGE_MOUNT_POINT="/media/storage"
LOG_FILE="/var/log/backup.sh.log"
RESTIC_PASSWORD_ENV_VAR="HOMELAB_BACKUP_RESTIC_PASSWORD"
RESTIC_KEEP_LAST=5

BACKUP_PAIRS=(
  "/home/nick/local_kube_data:${BACKUP_MOUNT_POINT}/repos/local_kube_data"
  "/home/nick/local_kube_config:${BACKUP_MOUNT_POINT}/repos/home_local_kube_config"
  "${STORAGE_MOUNT_POINT}:${BACKUP_MOUNT_POINT}/repos/storage"
)

DRY_RUN=false
SKIP_FSCK=false
LOG_READY=false
ERROR_NOTIFIED=false
PAIR_FAILURES=0
NTFY_TOPIC="${NTFY_TOPIC:-https://ntfy.napisani.xyz/backups}"
TAG="[restic-backup]"
```

- [ ] **Step 5: Add the password validation helper and wire it into startup**

Insert this helper into `mods/dotfiles/supermicro_scripts/backup.sh` near the other validation functions:

```bash
require_restic_password() {
  local password_value="${!RESTIC_PASSWORD_ENV_VAR:-}"
  if [[ -z "${password_value}" ]]; then
    log_error "Required environment variable '${RESTIC_PASSWORD_ENV_VAR}' is not set."
    exit 1
  fi

  export RESTIC_PASSWORD="${password_value}"
}
```

Then update the startup requirement block in `main()` to:

```bash
  if [[ -n "${NTFY_TOPIC}" ]]; then
    require_command curl
  fi

  require_command fsck.hfsplus
  require_command mount
  require_command restic
  require_restic_password
```

- [ ] **Step 6: Update help text from copy/sync wording to snapshot/repository wording**

Change the usage trailer in `mods/dotfiles/supermicro_scripts/backup.sh` to:

```bash
Backup pairs are configured near the top of this script as "source:repository" entries.
Each run creates a restic snapshot per configured repository.
```

- [ ] **Step 7: Re-run the password test**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: PASS

- [ ] **Step 8: Commit the package and config changes**

```bash
git add mods/system-packages.nix mods/dotfiles/supermicro_scripts/backup.sh mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh
git commit -m "feat: add restic backup configuration"
```

## Task 3: Replace rsync execution with per-pair restic repositories

**Files:**
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Write the failing regression test for restic init, backup, and retention**

Append this test to `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`:

```bash
run_restic_flow_test() {
  local backup_mount="${TEST_TMPDIR}/backup"
  local storage_mount="${TEST_TMPDIR}/storage"
  local source_dir="${TEST_TMPDIR}/source"
  local restic_log="${TEST_TMPDIR}/restic.log"
  mkdir -p "${backup_mount}" "${storage_mount}" "${source_dir}"
  printf 'hello\n' >"${source_dir}/file.txt"

  local output
  set +e
  output="$({
    env \
      PATH="$(make_stub_bin):${PATH}" \
      RESTIC_LOG_FILE="${restic_log}" \
      HOMELAB_BACKUP_RESTIC_PASSWORD="secret" \
      bash -c '
        source "$1"
        assert_root() { :; }
        NTFY_TOPIC=""
        DEVICE="/dev/testdisk"
        BACKUP_MOUNT_POINT="$2"
        STORAGE_MOUNT_POINT="$3"
        BACKUP_PAIRS=("$4:$2/repos/source")
        main --skip-fsck
      ' bash "${SCRIPT_PATH}" "${backup_mount}" "${storage_mount}" "${source_dir}"
  } 2>&1)"
  local status=$?
  set -e

  [[ ${status} -eq 0 ]] || fail "backup should succeed with stubbed restic commands"
  assert_contains "$(<"${restic_log}")" "--repo ${backup_mount}/repos/source init"
  assert_contains "$(<"${restic_log}")" "--repo ${backup_mount}/repos/source backup ${source_dir}"
  assert_contains "$(<"${restic_log}")" "--repo ${backup_mount}/repos/source forget --keep-last 5 --prune"
}

run_restic_flow_test
```

- [ ] **Step 2: Run the regression test and verify it fails before the rewrite**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: FAIL because the script still calls `rsync` and does not emit `restic` commands.

- [ ] **Step 3: Add repository helpers and pair-local failure tracking**

Insert these helpers into `mods/dotfiles/supermicro_scripts/backup.sh` after `validate_pairs()`:

```bash
repo_exists() {
  local repo_path="$1"
  [[ -f "${repo_path}/config" ]]
}

run_restic() {
  local repo_path="$1"
  shift
  restic --repo "${repo_path}" "$@"
}

record_pair_failure() {
  local message="$1"
  PAIR_FAILURES=$((PAIR_FAILURES + 1))
  log_error "${message}"
}

process_pair() {
  local index="$1"
  local source="$2"
  local repo_path="$3"
  local repo_parent
  repo_parent=$(dirname "${repo_path}")

  if [[ ! -d "${source}" ]]; then
    record_pair_failure "Source directory '${source}' for pair #${index} does not exist."
    return 0
  fi

  mkdir -p "${repo_parent}"

  if ! repo_exists "${repo_path}"; then
    log_info "Initializing restic repository for pair #${index}: ${repo_path}"
    run_restic "${repo_path}" init || {
      record_pair_failure "Failed to initialize restic repository '${repo_path}' for pair #${index}."
      return 0
    }
  fi

  log_info "Creating restic snapshot for pair #${index}: ${source} -> ${repo_path}"
  run_restic "${repo_path}" backup "${source}" || {
    record_pair_failure "Restic backup failed for pair #${index} ('${source}' -> '${repo_path}')."
    return 0
  }

  log_info "Pruning old snapshots for pair #${index}: ${repo_path}"
  run_restic "${repo_path}" forget --keep-last "${RESTIC_KEEP_LAST}" --prune || {
    record_pair_failure "Restic retention failed for pair #${index} ('${repo_path}')."
    return 0
  }

  log_info "Pair #${index} completed successfully."
}
```

- [ ] **Step 4: Rewrite validation and the main loop around repositories instead of rsync targets**

Make these two focused changes in `mods/dotfiles/supermicro_scripts/backup.sh`.

First, update the `validate_pairs()` loop body to stop failing on missing source directories and to rename `target` to `repo_path`:

```bash
    local source="${pair%%:*}"
    local repo_path="${pair#*:}"

    source="${source%/}"
    repo_path="${repo_path%/}"

    if [[ -z "${source}" || -z "${repo_path}" ]]; then
      log_error "Source and repository must be non-empty for pair #${index} ('${pair}')."
      exit 1
    fi

    local mount_prefix="${BACKUP_MOUNT_POINT%/}"
    mount_prefix="${mount_prefix:-/}"
    case "${repo_path}" in
    "${mount_prefix}" | "${mount_prefix}/"*) ;;
    *)
      log_error "Repository path '${repo_path}' for pair #${index} must be under ${BACKUP_MOUNT_POINT}."
      exit 1
      ;;
    esac
```

Second, replace the `rsync_flags` block and the loop body in `main()` with:

```bash
  local index=0
  for pair in "${BACKUP_PAIRS[@]}"; do
    index=$((index + 1))
    local source="${pair%%:*}"
    local repo_path="${pair#*:}"

    source="${source%/}"
    repo_path="${repo_path%/}"

    process_pair "${index}" "${source}" "${repo_path}"
  done

  if [[ ${PAIR_FAILURES} -gt 0 ]]; then
    log_error "Backup completed with ${PAIR_FAILURES} failed pair(s)."
    exit 1
  fi
```

- [ ] **Step 5: Add dry-run support to the restic path**

Adjust `run_restic()` in `mods/dotfiles/supermicro_scripts/backup.sh` to:

```bash
run_restic() {
  local repo_path="$1"
  shift

  if [[ "${DRY_RUN}" == "true" ]]; then
    case "$1" in
    init)
      log_info "Dry run: would run restic --repo ${repo_path} $*"
      return 0
      ;;
    backup | forget)
      restic --repo "${repo_path}" --dry-run "$@"
      return 0
      ;;
    esac
  fi

  restic --repo "${repo_path}" "$@"
}
```

- [ ] **Step 6: Re-run the regression harness**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: PASS

- [ ] **Step 7: Commit the restic rewrite**

```bash
git add mods/dotfiles/supermicro_scripts/backup.sh mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh
git commit -m "feat: rewrite backup script for restic"
```

## Task 4: Final verification and user-visible cleanup

**Files:**
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Write the failing test for best-effort pair failures**

Append this test to `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`:

```bash
run_pair_failure_test() {
  local backup_mount="${TEST_TMPDIR}/backup-failure"
  local storage_mount="${TEST_TMPDIR}/storage-failure"
  local good_source="${TEST_TMPDIR}/good-source"
  local missing_source="${TEST_TMPDIR}/missing-source"
  local restic_log="${TEST_TMPDIR}/restic-failure.log"
  mkdir -p "${backup_mount}" "${storage_mount}" "${good_source}"
  printf 'ok\n' >"${good_source}/file.txt"

  local output
  set +e
  output="$({
    env \
      PATH="$(make_stub_bin):${PATH}" \
      RESTIC_LOG_FILE="${restic_log}" \
      HOMELAB_BACKUP_RESTIC_PASSWORD="secret" \
      bash -c '
        source "$1"
        assert_root() { :; }
        NTFY_TOPIC=""
        BACKUP_MOUNT_POINT="$2"
        STORAGE_MOUNT_POINT="$3"
        BACKUP_PAIRS=(
          "$4:$2/repos/missing"
          "$5:$2/repos/good"
        )
        main --skip-fsck
      ' bash "${SCRIPT_PATH}" "${backup_mount}" "${storage_mount}" "${missing_source}" "${good_source}"
  } 2>&1)"
  local status=$?
  set -e

  [[ ${status} -ne 0 ]] || fail "script should exit non-zero when any pair fails"
  assert_contains "${output}" "failed pair(s)"
  assert_contains "$(<"${restic_log}")" "--repo ${backup_mount}/repos/good backup ${good_source}"
}

run_pair_failure_test
```

- [ ] **Step 2: Run the test and verify it fails before the final cleanup**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: FAIL until pair-failure accounting and final exit status are wired correctly.

- [ ] **Step 3: Tighten notifications and final exit behavior**

Update `on_exit()` in `mods/dotfiles/supermicro_scripts/backup.sh` to:

```bash
on_exit() {
  local exit_code=$?
  if [[ ${exit_code} -eq 0 ]]; then
    log_info "Restic backup completed successfully."
    notify "SUCCESS" "Restic backup completed successfully."
  else
    if [[ "${ERROR_NOTIFIED}" != "true" ]]; then
      notify "ERROR" "Restic backup exited with status ${exit_code}."
      ERROR_NOTIFIED=true
    fi
  fi
}
```

And update the startup log line in `main()` to:

```bash
  log_info "Starting restic backup. Dry run: ${DRY_RUN}. Skip fsck: ${SKIP_FSCK}."
```

- [ ] **Step 4: Run syntax checks and the shell regression tests**

Run these commands:

```bash
bash -n mods/dotfiles/supermicro_scripts/backup.sh
bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh
```

Expected: both commands succeed with exit code 0.

- [ ] **Step 5: Dry-run the Nix evaluation for the supermicro host**

Run: `nix build .#nixosConfigurations.supermicro.config.system.build.toplevel --dry-run`
Expected: dry-run evaluation succeeds and includes the package change.

- [ ] **Step 6: Commit the final verification pass**

```bash
git add mods/system-packages.nix mods/dotfiles/supermicro_scripts/backup.sh mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh
git commit -m "chore: verify restic backup migration"
```

## Spec Coverage Check

- `mods/system-packages.nix` gains `restic` in Task 2
- `backup.sh` keeps globals at the top and renames destinations to repositories in Task 2
- required `HOMELAB_BACKUP_RESTIC_PASSWORD` handling lands in Task 2
- per-pair repository init, backup, and `--keep-last 5 --prune` land in Task 3
- shared setup failures remain fail-fast in Task 2 and Task 3
- pair failures become best-effort with final non-zero exit in Task 3 and Task 4
- logging, notifications, syntax checks, and dry-run Nix verification are covered in Task 4
