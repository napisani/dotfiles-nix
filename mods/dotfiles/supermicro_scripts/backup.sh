#!/bin/bash
set -euo pipefail

DEVICE="/dev/sde2"
BACKUP_MOUNT_POINT="/media/backup"
STORAGE_MOUNT_POINT="/media/storage"
LOG_FILE="/var/log/backup.sh.log"

# Define backup pairs in "source:target" format. Order is preserved.
BACKUP_PAIRS=(
	"/home/nick:${STORAGE_MOUNT_POINT}/computer_backups/supermicro/home"
	"${STORAGE_MOUNT_POINT}:${BACKUP_MOUNT_POINT}/storage"
)

DRY_RUN=false
SKIP_FSCK=false
LOG_READY=false
ERROR_NOTIFIED=false
NTFY_TOPIC="${NTFY_TOPIC:-https://ntfy.napisani.xyz/backups}"
TAG="[postgres-backup]"

usage() {
	cat <<'EOF'
Usage: backup.sh [options]

Options:
  --dry-run          Show what would be copied without making changes
  --skip-fsck        Skip the filesystem check step
  --log-file <path>  Write logs to the given file (default: /var/log/backup.sh.log)
  -h, --help         Display this help message and exit

Backup pairs are configured near the top of this script.
EOF
}

initialize_logging() {
	if [[ -z "${LOG_FILE:-}" || "${LOG_READY}" == "true" ]]; then
		return 0
	fi

	local log_dir
	log_dir=$(dirname "${LOG_FILE}")

	if mkdir -p "${log_dir}" && touch "${LOG_FILE}"; then
		LOG_READY=true
	else
		local requested="${LOG_FILE}"
		LOG_FILE=""
		LOG_READY=false
		printf '%s\n' "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] Unable to write to log file ${requested}. Logging to stdout only." >&2
	fi
}

notify() {
	local status="$1"
	shift || true
	local message="$*"

	if [[ -z "${NTFY_TOPIC}" ]]; then
		return 0
	fi

	local payload
	payload="$(date -Is) ${TAG} [${status}] ${message}"

	curl -fsS --data-urlencode "message=${payload}" "${NTFY_TOPIC}" >/dev/null 2>&1 || log_warn "Failed to send notification: ${payload}"
}

log() {
	local level="$1"
	shift
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	local formatted="[${timestamp}] [${level}] $*"
	echo "${formatted}"

	if [[ -n "${LOG_FILE:-}" ]]; then
		initialize_logging
		if [[ -n "${LOG_FILE:-}" ]]; then
			echo "${formatted}" >>"${LOG_FILE}"
		fi
	fi
}

log_info() {
	log "INFO" "$@"
}

log_warn() {
	log "WARN" "$@"
}

log_error() {
	log "ERROR" "$@"
}

on_error() {
	local exit_code="$1"
	local line_no="$2"
	log_error "Backup failed at line ${line_no} with exit code ${exit_code}."
	notify "ERROR" "Backup failed at line ${line_no} with exit code ${exit_code}."
	ERROR_NOTIFIED=true
}

on_exit() {
	local exit_code=$?
	if [[ ${exit_code} -eq 0 ]]; then
		log_info "Backup completed successfully."
		notify "SUCCESS" "Backup completed successfully."
	else
		if [[ "${ERROR_NOTIFIED}" != "true" ]]; then
			notify "ERROR" "Backup exited with status ${exit_code}."
			ERROR_NOTIFIED=true
		fi
	fi
}

assert_root() {
	if [[ ${EUID} -ne 0 ]]; then
		log_error "Please run this script as root."
		exit 1
	fi
}

require_command() {
	local cmd="$1"
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		log_error "Required command '${cmd}' not found in PATH."
		exit 1
	fi
}

run_step() {
	local description="$1"
	shift
	log_info "${description}"
	"$@"
	log_info "Finished: ${description}"
}

validate_pairs() {
	if [[ ${#BACKUP_PAIRS[@]} -eq 0 ]]; then
		log_error "No backup pairs defined. Update the BACKUP_PAIRS array near the top of the script."
		exit 1
	fi

	local index=0
	for pair in "${BACKUP_PAIRS[@]}"; do
		index=$((index + 1))

		if [[ "${pair}" != *:* ]]; then
			log_error "Backup pair #${index} ('${pair}') is invalid. Expected format 'source:target'."
			exit 1
		fi

		local source="${pair%%:*}"
		local target="${pair#*:}"

		source="${source%/}"
		target="${target%/}"

		if [[ -z "${source}" || -z "${target}" ]]; then
			log_error "Source and target must be non-empty for pair #${index} ('${pair}')."
			exit 1
		fi

		if [[ ! -d "${source}" ]]; then
			log_error "Source directory '${source}' for pair #${index} does not exist."
			exit 1
		fi

		local mount_prefix="${BACKUP_MOUNT_POINT%/}"
		mount_prefix="${mount_prefix:-/}"
		case "${target}" in
		"${mount_prefix}" | "${mount_prefix}/"*) ;;
		*)
			log_warn "Target directory '${target}' for pair #${index} is outside ${BACKUP_MOUNT_POINT}. Ensure this is intentional."
			;;
		esac
	done
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--skip-fsck)
			SKIP_FSCK=true
			shift
			;;
		--log-file)
			shift
			if [[ $# -eq 0 ]]; then
				printf '%s\n' "Error: --log-file requires a path argument" >&2
				exit 1
			fi
			LOG_FILE="$1"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			printf '%s\n' "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
		esac
	done
}

main() {
	parse_args "$@"
	initialize_logging
	trap 'on_error $? $LINENO' ERR
	trap 'on_exit' EXIT

	if [[ -n "${NTFY_TOPIC}" ]]; then
		require_command curl
	fi

	log_info "Starting backup. Dry run: ${DRY_RUN}. Skip fsck: ${SKIP_FSCK}."

	assert_root

	if [[ -n "${NTFY_TOPIC}" ]]; then
		notify "START" "Backup job started. Dry run: ${DRY_RUN}. Skip fsck: ${SKIP_FSCK}."
	fi

	require_command fsck.hfsplus
	require_command mount
	require_command rsync
	if ! command -v mountpoint >/dev/null 2>&1; then
		log_warn "Command 'mountpoint' not found; mount state checks will be skipped."
	fi

	if [[ ! -d "${BACKUP_MOUNT_POINT}" ]]; then
		log_error "Mount point '${BACKUP_MOUNT_POINT}' does not exist."
		exit 1
	fi

	validate_pairs
	log_info "Validated ${#BACKUP_PAIRS[@]} backup pair(s)."

	if [[ "${SKIP_FSCK}" == "false" ]]; then
		run_step "Checking filesystem integrity on ${DEVICE}" fsck.hfsplus -f "${DEVICE}"
	else
		log_info "Skipping filesystem check as requested."
	fi

	if command -v mountpoint >/dev/null 2>&1 && mountpoint -q "${BACKUP_MOUNT_POINT}"; then
		log_info "Attempting to remount ${DEVICE} as read-write at ${BACKUP_MOUNT_POINT}."
		if ! mount -t hfsplus -o remount,force,rw "${DEVICE}" "${BACKUP_MOUNT_POINT}"; then
			log_warn "Remount attempt failed; continuing with a fresh mount."
		fi
	else
		log_info "${BACKUP_MOUNT_POINT} is not currently mounted."
	fi

	run_step "Mounting ${DEVICE} at ${BACKUP_MOUNT_POINT}" mount -t hfsplus -o force,rw "${DEVICE}" "${BACKUP_MOUNT_POINT}"

	local rw_test_file="${BACKUP_MOUNT_POINT}/.backup_rw_test"
	run_step "Verifying write access on ${BACKUP_MOUNT_POINT}" touch "${rw_test_file}"
	rm -f "${rw_test_file}"

	local rsync_flags=(-rlv --delete --progress --size-only --human-readable)
	if [[ "${DRY_RUN}" == "true" ]]; then
		rsync_flags+=(--dry-run)
	fi
	log_info "Using rsync flags: ${rsync_flags[*]}"

	local index=0
	for pair in "${BACKUP_PAIRS[@]}"; do
		index=$((index + 1))
		local source="${pair%%:*}"
		local target="${pair#*:}"

		source="${source%/}"
		target="${target%/}"

		log_info "Preparing pair #${index}: ${source} -> ${target}"

		if [[ "${DRY_RUN}" == "true" ]]; then
			log_info "Dry run: would ensure target directory '${target}' exists."
		else
			run_step "Ensuring target directory ${target}" mkdir -p "${target}"
		fi

		log_info "Syncing data for pair #${index} with rsync."
		rsync "${rsync_flags[@]}" "${source}/" "${target}"
		log_info "Rsync for pair #${index} complete."
	done
}

main "$@"
