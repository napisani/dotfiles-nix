# Restic Backup Over SSH Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `mods/dotfiles/supermicro_scripts/backup.sh` from local mounted-disk restic repositories to remote SSH-backed restic repositories, while keeping all editable config at the top of the script.

**Architecture:** Keep the current restic-centric script structure, but replace all device/mount/fsck logic with shared SSH repository configuration and per-pair remote repo names. Build each repository URL from shared SSH globals, remove root-only local-disk operations, and keep best-effort per-pair handling, retention, logging, and notifications.

**Tech Stack:** Bash, restic, curl, Nix

---

## File Structure

- Modify: `mods/dotfiles/supermicro_scripts/backup.sh` - replace local mount/device workflow with SSH-backed restic repo construction and validation
- Modify: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh` - replace mount/device-oriented tests with SSH-backed behavior tests and remove obsolete local-disk assumptions
- Modify: `docs/superpowers/specs/2026-04-08-restic-backup-script-design.md` - already updated, no further implementation change needed
- Keep: `mods/system-packages.nix` - `restic` is already present; no further package changes required

## Task 1: Convert the test harness from local-disk assumptions to SSH-backed repos

**Files:**
- Modify: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Write the failing SSH repo URL regression**

Replace the current `run_main_restic_flow_test()` in `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh` with this SSH-focused version:

```bash
run_main_restic_flow_test() {
	local stub_bin
	local workspace
	local restic_log
	local repo_url
	local output
	stub_bin="$(make_stub_bin)"
	workspace="${TEST_TMPDIR}/main-restic-flow"
	restic_log="${workspace}/restic.log"
	repo_url="sftp:backup@backup.example.com:/srv/restic/supermicro/source"
	mkdir -p "${workspace}/source"

	set +e
	output="$({ env -i PATH="${stub_bin}:${PATH}" TEST_WORKSPACE="${workspace}" RESTIC_LOG_FILE="${restic_log}" HOMELAB_BACKUP_RESTIC_PASSWORD="secret" /bin/bash -c '
		source "$1"
		LOG_FILE=""
		NTFY_TOPIC=""
		SSH_HOST="backup.example.com"
		SSH_USER="backup"
		SSH_PORT="22"
		REMOTE_REPO_BASE="/srv/restic/supermicro"
		BACKUP_PAIRS=("${TEST_WORKSPACE}/source:source")
		main
	' bash "${SCRIPT_PATH}"; } 2>&1)"
	local status=$?
	set -e

	[[ ${status} -eq 0 ]] || fail "main should complete the SSH restic flow: ${output}"
	[[ -f "${restic_log}" ]] || fail "restic log should be created"

	local restic_calls
	restic_calls="$(<"${restic_log}")"
	assert_contains_line "${restic_calls}" "--repo ${repo_url} init"
	assert_contains_line "${restic_calls}" "--repo ${repo_url} backup ${workspace}/source"
	assert_contains_line "${restic_calls}" "--repo ${repo_url} forget --keep-last 5 --prune"
}
```

- [ ] **Step 2: Add the failing SSH config validation test**

Append this test to `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`:

```bash
run_main_requires_ssh_config_test() {
	local stub_bin
	local workspace
	local output
	stub_bin="$(make_stub_bin)"
	workspace="${TEST_TMPDIR}/main-requires-ssh-config"
	mkdir -p "${workspace}/source"

	set +e
	output="$({ env -i PATH="${stub_bin}:${PATH}" TEST_WORKSPACE="${workspace}" HOMELAB_BACKUP_RESTIC_PASSWORD="secret" /bin/bash -c '
		source "$1"
		LOG_FILE=""
		NTFY_TOPIC=""
		SSH_HOST=""
		SSH_USER="backup"
		SSH_PORT="22"
		REMOTE_REPO_BASE="/srv/restic/supermicro"
		BACKUP_PAIRS=("${TEST_WORKSPACE}/source:source")
		main
	' bash "${SCRIPT_PATH}"; } 2>&1)"
	local status=$?
	set -e

	[[ ${status} -ne 0 ]] || fail "main should fail when SSH_HOST is missing"
	assert_contains "${output}" "Required configuration 'SSH_HOST' is not set."
}
```

- [ ] **Step 3: Remove the obsolete local-disk tests from the execution list**

At the bottom of `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`, remove these calls because the SSH design no longer includes local mount/device behavior:

```bash
run_main_skips_fresh_mount_after_successful_remount_test
run_main_skips_fresh_mount_after_failed_remount_test
run_main_fails_when_wrong_device_is_mounted_test
run_main_skip_fsck_does_not_require_fsck_command_test
```

And keep these active:

```bash
run_help_test
run_source_does_not_run_main_test
run_source_preserves_shell_options_test
run_main_enables_strict_mode_test
run_restic_stub_without_log_file_test
run_main_requires_restic_password_test
run_main_requires_ssh_config_test
run_main_restic_flow_test
run_main_restic_best_effort_pair_failure_test
run_main_restic_dry_run_test
run_main_restic_dry_run_new_repo_test
printf 'PASS: backup_restic_test.sh\n'
```

- [ ] **Step 4: Run the harness to verify the new tests fail before implementation**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: FAIL because `backup.sh` still expects local mount/device configuration and does not validate SSH config or build SSH repo URLs.

## Task 2: Replace top-level config and validation with SSH globals

**Files:**
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Replace the top-of-file config block**

Replace the current global config block at the top of `mods/dotfiles/supermicro_scripts/backup.sh` with:

```bash
STORAGE_MOUNT_POINT="/media/storage"
SSH_HOST="backup.example.com"
SSH_USER="nick"
SSH_PORT="22"
REMOTE_REPO_BASE="/srv/restic/supermicro"
LOG_FILE="/var/log/backup.sh.log"
RESTIC_PASSWORD_ENV_VAR="HOMELAB_BACKUP_RESTIC_PASSWORD"
RESTIC_KEEP_LAST=5

BACKUP_PAIRS=(
	"/home/nick/local_kube_data:local_kube_data"
	"/home/nick/local_kube_config:home_local_kube_config"
	"${STORAGE_MOUNT_POINT}:storage"
)

DRY_RUN=false
LOG_READY=false
ERROR_NOTIFIED=false
PAIR_FAILURES=0
NTFY_TOPIC="${NTFY_TOPIC:-https://ntfy.napisani.xyz/backups}"
TAG="[restic-backup]"
```

- [ ] **Step 2: Update help text to match the SSH design**

Change `usage()` in `mods/dotfiles/supermicro_scripts/backup.sh` to:

```bash
usage() {
	cat <<'EOF'
Usage: backup.sh [options]

Options:
	--dry-run          Show what would be backed up without making changes
	--log-file <path>  Write logs to the given file (default: /var/log/backup.sh.log)
	-h, --help         Display this help message and exit

Backup pairs are configured near the top of this script as source:repo-name entries.
Each run creates a restic snapshot in a remote SSH-backed repository.
EOF
}
```

- [ ] **Step 3: Replace root and SSH validation helpers**

Delete `assert_root()`, `mounted_device_for_mount_point()`, `mount_point_is_mounted()`, and `require_expected_mount_device()`.

Insert these helpers near `require_restic_password()`:

```bash
require_config_value() {
	local name="$1"
	local value="${!name:-}"
	if [[ -z "${value}" ]]; then
		log_error "Required configuration '${name}' is not set."
		exit 1
	fi
}

require_ssh_config() {
	require_config_value SSH_HOST
	require_config_value SSH_USER
	require_config_value SSH_PORT
	require_config_value REMOTE_REPO_BASE
}

build_repo_url() {
	local repo_name="$1"
	printf 'sftp:%s@%s:%s/%s\n' "${SSH_USER}" "${SSH_HOST}" "${REMOTE_REPO_BASE%/}" "${repo_name}"
}
```

- [ ] **Step 4: Run the harness to verify the SSH validation tests now pass and local-disk assumptions are still failing elsewhere**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: still FAIL, but the failure should have moved deeper into the old local mount/device flow rather than the new SSH config validation.

## Task 3: Remove local disk flow and switch execution to SSH repo URLs

**Files:**
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh`
- Modify: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Rewrite pair validation for `source:repo-name` entries**

Replace `validate_pairs()` in `mods/dotfiles/supermicro_scripts/backup.sh` with:

```bash
validate_pairs() {
	if [[ ${#BACKUP_PAIRS[@]} -eq 0 ]]; then
		log_error "No backup pairs defined. Update the BACKUP_PAIRS array near the top of the script."
		exit 1
	fi

	local index=0
	for pair in "${BACKUP_PAIRS[@]}"; do
		index=$((index + 1))

		if [[ "${pair}" != *:* ]]; then
			log_error "Backup pair #${index} ('${pair}') is invalid. Expected format 'source:repo-name'."
			exit 1
		fi

		local source="${pair%%:*}"
		local repo_name="${pair#*:}"

		source="${source%/}"
		repo_name="${repo_name%/}"

		if [[ -z "${source}" || -z "${repo_name}" ]]; then
			log_error "Source and repo name must be non-empty for pair #${index} ('${pair}')."
			exit 1
		fi
	done
}
```

- [ ] **Step 2: Rewrite `process_pair()` to use remote repo URLs**

Replace `process_pair()` in `mods/dotfiles/supermicro_scripts/backup.sh` with:

```bash
process_pair() {
	local index="$1"
	local source="${2%/}"
	local repo_name="${3%/}"
	local repo_url

	repo_url="$(build_repo_url "${repo_name}")"
	log_info "Preparing pair #${index}: ${source} -> ${repo_url}"

	if [[ ! -d "${source}" ]]; then
		record_pair_failure "${index}" "Source directory '${source}' does not exist."
		return 0
	fi

	if ! repo_exists "${repo_url}"; then
		log_info "Repository '${repo_url}' is not initialized yet."
		if ! run_restic "${repo_url}" init; then
			record_pair_failure "${index}" "Failed to initialize repository '${repo_url}'."
			return 0
		fi

		if [[ "${DRY_RUN}" == "true" ]]; then
			log_info "Dry run: skipping backup and forget for '${repo_url}' until the repository exists."
			log_info "Pair #${index} completed successfully."
			return 0
		fi
	fi

	if ! run_restic "${repo_url}" backup "${source}"; then
		record_pair_failure "${index}" "Failed to back up '${source}' to '${repo_url}'."
		return 0
	fi

	if ! run_restic "${repo_url}" forget --keep-last "${RESTIC_KEEP_LAST}" --prune; then
		record_pair_failure "${index}" "Failed to prune repository '${repo_url}'."
		return 0
	fi

	log_info "Pair #${index} completed successfully."
}
```

- [ ] **Step 3: Make `repo_exists()` work with remote repos**

Replace `repo_exists()` with:

```bash
repo_exists() {
	local repo="$1"
	if run_restic "${repo}" snapshots >/dev/null 2>&1; then
		return 0
	fi
	return 1
}
```

And update `run_restic()` so `--dry-run` is only appended for `backup` and `forget`, not for `snapshots`:

```bash
run_restic() {
	local repo="$1"
	shift
	local operation="$1"
	shift

	if [[ "${DRY_RUN}" == "true" && "${operation}" == "init" ]]; then
		log_info "Dry run: would initialize restic repository at '${repo}'."
		return 0
	fi

	local args=(--repo "${repo}")
	if [[ "${DRY_RUN}" == "true" && ( "${operation}" == "backup" || "${operation}" == "forget" ) ]]; then
		args+=(--dry-run)
	fi

	args+=("${operation}")
	if [[ $# -gt 0 ]]; then
		args+=("$@")
	fi

	restic "${args[@]}"
}
```

- [ ] **Step 4: Rewrite `main()` to remove all local disk operations**

In `mods/dotfiles/supermicro_scripts/backup.sh`, remove:

```bash
		require_command fsck.hfsplus
		assert_root
		if [[ "${SKIP_FSCK}" == "false" ]]; then
			...
		fi
		local needs_fresh_mount=true
		...
		local rw_test_file="${BACKUP_MOUNT_POINT}/.backup_rw_test"
		...
```

and replace the startup section with:

```bash
		require_command restic
		require_ssh_config
		require_restic_password

		if [[ -n "${NTFY_TOPIC}" ]]; then
			require_command curl
		fi

		log_info "Starting restic backup. Dry run: ${DRY_RUN}."

		if [[ -n "${NTFY_TOPIC}" ]]; then
			notify "START" "Restic backup job started. Dry run: ${DRY_RUN}."
		fi

		validate_pairs
		log_info "Validated ${#BACKUP_PAIRS[@]} backup pair(s)."
```

Also change the loop variables from `repo` to `repo_name`:

```bash
		local index=0
		for pair in "${BACKUP_PAIRS[@]}"; do
			index=$((index + 1))
			local source="${pair%%:*}"
			local repo_name="${pair#*:}"

			source="${source%/}"
			repo_name="${repo_name%/}"

			process_pair "${index}" "${source}" "${repo_name}"
		done
```

- [ ] **Step 5: Update the best-effort test to use SSH globals instead of local mount values**

In `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`, update `run_main_restic_best_effort_pair_failure_test()` so the child shell sets:

```bash
		LOG_FILE=""
		NTFY_TOPIC="test-topic"
		SSH_HOST="backup.example.com"
		SSH_USER="backup"
		SSH_PORT="22"
		REMOTE_REPO_BASE="/srv/restic/supermicro"
		BACKUP_PAIRS=("${TEST_WORKSPACE}/missing-source:missing-repo" "${TEST_WORKSPACE}/good-source:good-repo")
		main
```

and update the expected repo assertions to:

```bash
	assert_contains_line "${restic_calls}" "--repo sftp:backup@backup.example.com:/srv/restic/supermicro/good-repo init"
	assert_contains_line "${restic_calls}" "--repo sftp:backup@backup.example.com:/srv/restic/supermicro/good-repo backup ${good_source}"
	assert_contains_line "${restic_calls}" "--repo sftp:backup@backup.example.com:/srv/restic/supermicro/good-repo forget --keep-last 5 --prune"
```

- [ ] **Step 6: Run the harness to verify the SSH migration passes**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: PASS

## Task 4: Final cleanup and verification for the SSH version

**Files:**
- Modify: `mods/dotfiles/supermicro_scripts/backup.sh`
- Modify: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
- Test: `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`

- [ ] **Step 1: Remove the stale `--skip-fsck` CLI surface**

In `mods/dotfiles/supermicro_scripts/backup.sh`, delete:

```bash
SKIP_FSCK=false
```

and remove this `parse_args()` branch:

```bash
		--skip-fsck)
			SKIP_FSCK=true
			shift
			;;
```

Also remove all test invocations that still call `main --skip-fsck`; switch them to `main` or `main --dry-run` as appropriate.

- [ ] **Step 2: Add the failing no-root-required regression**

Append this test to `mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`:

```bash
run_main_does_not_require_root_test() {
	local stub_bin
	local workspace
	local output
	stub_bin="$(make_stub_bin)"
	workspace="${TEST_TMPDIR}/main-does-not-require-root"
	mkdir -p "${workspace}/source"

	set +e
	output="$({ env -i PATH="${stub_bin}:${PATH}" TEST_WORKSPACE="${workspace}" HOMELAB_BACKUP_RESTIC_PASSWORD="secret" /bin/bash -c '
		source "$1"
		SSH_HOST="backup.example.com"
		SSH_USER="backup"
		SSH_PORT="22"
		REMOTE_REPO_BASE="/srv/restic/supermicro"
		LOG_FILE=""
		NTFY_TOPIC=""
		BACKUP_PAIRS=("${TEST_WORKSPACE}/source:source")
		main
	' bash "${SCRIPT_PATH}"; } 2>&1)"
	local status=$?
	set -e

	[[ ${status} -eq 0 ]] || fail "main should not require root for SSH backups: ${output}"
	assert_not_contains "${output}" "Please run this script as root."
}
```

- [ ] **Step 3: Run the harness to verify the no-root test fails before removing root enforcement**

Run: `bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh`
Expected: FAIL because `assert_root()` still exists or is still called.

- [ ] **Step 4: Remove root enforcement and stale local helpers**

Delete `assert_root()` entirely from `mods/dotfiles/supermicro_scripts/backup.sh`, and remove any remaining references to:

```bash
DEVICE
BACKUP_MOUNT_POINT
SKIP_FSCK
run_step
```

The SSH version should not mention local device, mount point, or filesystem check behavior anywhere in the script.

- [ ] **Step 5: Run final verification commands**

Run these commands:

```bash
bash -n mods/dotfiles/supermicro_scripts/backup.sh
bash mods/dotfiles/supermicro_scripts/tests/backup_restic_test.sh
nix build .#nixosConfigurations.supermicro.config.system.build.toplevel --dry-run
```

Expected:
- `bash -n` exits 0
- the shell harness prints `PASS: backup_restic_test.sh`
- the Nix dry-run succeeds; warnings are acceptable if they are unrelated to this change

## Spec Coverage Check

- SSH globals at the top of `backup.sh` are implemented in Task 2
- `source:repo-name` pairs and remote `sftp:` repo URLs are implemented in Task 3
- required `HOMELAB_BACKUP_RESTIC_PASSWORD` handling is preserved across Tasks 2 and 3
- local disk/fsck/mount/root behavior is removed in Tasks 3 and 4
- per-pair init/backup/forget behavior and best-effort failures are preserved in Task 3
- `--skip-fsck` removal is handled in Task 4
- final verification is covered in Task 4
