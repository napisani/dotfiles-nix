#!/usr/bin/env bash
set -euo pipefail
shell_dir=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
source "$shell_dir/bash/lib/guards.sh"
source "$shell_dir/bash/rc.d/56-update-functions.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" DOTFILES_DIR="$tmp/checkout with spaces" MACHINE_NAME=maclab
export CALL_LOG="$tmp/calls" BOOTSTRAP_STATUS=0 SKILLS_STATUS=0
mkdir -p "$HOME/.local/bin" "$DOTFILES_DIR/homes/maclab"
printf '[vars]\n' >"$DOTFILES_DIR/homes/maclab/mise.toml"
cat >"$DOTFILES_DIR/bootstrap.sh" <<'BOOTSTRAP'
#!/bin/sh
printf 'bootstrap %s\n' "$*" >> "$CALL_LOG"
exit "$BOOTSTRAP_STATUS"
BOOTSTRAP
cat >"$HOME/.local/bin/mise" <<'MISE'
#!/bin/sh
printf 'mise %s\n' "$*" >> "$CALL_LOG"
if [ "$1" = env ]; then
	printf 'export APPLY_ENV=ready\n'
elif [ "$3" = run ] && [ "$4" = skills:sync ]; then
	exit "$SKILLS_STATUS"
fi
MISE
chmod +x "$DOTFILES_DIR/bootstrap.sh" "$HOME/.local/bin/mise"
export PATH="$HOME/.local/bin:$PATH"
has_nix=1
system_status=0
sh_have() {
	case "$1" in
	darwin-rebuild) [ "$has_nix" = 1 ] ;;
	nixos-rebuild) return 1 ;;
	*) command -v "$1" >/dev/null 2>&1 ;;
	esac
}
nixswitch() {
	printf 'system\n' >>"$CALL_LOG"
	return "$system_status"
}
check_apply() {
	local expected=$1 status=0
	: >"$CALL_LOG"
	unset APPLY_ENV
	sys-update apply || status=$?
	[ "$status" -eq "$expected" ]
}
check_apply 0
expected=$(printf 'system\nbootstrap maclab\nmise -C %s run skills:sync\nmise env --shell bash' "$HOME")
[ "$(<"$CALL_LOG")" = "$expected" ]
[ "$APPLY_ENV" = ready ]
system_status=41
check_apply 41
[ "$(<"$CALL_LOG")" = system ]
system_status=0
BOOTSTRAP_STATUS=42
check_apply 42
[ "$(wc -l <"$CALL_LOG")" -eq 2 ]
BOOTSTRAP_STATUS=0
SKILLS_STATUS=43
check_apply 43
[ "$(wc -l <"$CALL_LOG")" -eq 3 ]
SKILLS_STATUS=0
has_nix=0
check_apply 0
[ "$(wc -l <"$CALL_LOG")" -eq 3 ]
MACHINE_NAME=unknown
check_apply 2
[ ! -s "$CALL_LOG" ]
MACHINE_NAME=maclab
: >"$CALL_LOG"
sys-update rtk
[ "$(<"$CALL_LOG")" = "mise -C $HOME run rtk:setup" ]
printf 'Apply ordering, failure boundaries and explicit RTK passed.\n'
