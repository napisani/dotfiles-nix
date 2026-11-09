#!/usr/bin/env bash
set -euo pipefail

shell_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home with spaces"
shims="$home/.local/share/mise/shims"
legacy="$tmp/legacy/bin"
mkdir -p "$shims" "$legacy"
printf '#!/bin/sh\nprintf "mise-node\\n"\n' >"$shims/node"
printf '#!/bin/sh\nprintf "legacy-node\\n"\n' >"$legacy/node"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "${MISE_CALLS:-/dev/null}"\nif [ -n "${REAL_BIN:-}" ]; then printf '\''export PATH="%%s:$PATH"\\n'\'' "$REAL_BIN"; else printf ":\\n"; fi\n' >"$legacy/mise"
chmod +x "$shims/node" "$legacy/node" "$legacy/mise"

env -i HOME="$home" USER=mise-path-regression MACHINE_NAME=maclab \
	HOMEBREW_PREFIX="$tmp/legacy" SHELL_DOTFILES_DIR="$shell_dir" \
	PROFILE="$shell_dir/bash/profile" SHIMS="$shims" \
	PATH="$legacy:$shims:$PATH:$shims" \
	"$BASH" --noprofile --norc -s <<'PROBE'
	set -eu
	. "$PROFILE"
	selected=$(node </dev/null)
	if [ "$selected" != mise-node ]; then
		printf "Expected mise node; selected %s\n" "$selected" >&2
		exit 1
	fi
	first_path=$PATH
	. "$PROFILE"
	[ "$(node </dev/null)" = mise-node ]
	[ "$PATH" = "$first_path" ]
	count=0
	old_ifs=$IFS
	IFS=:
	set -f
	for entry in $PATH; do
		if [ "$entry" = "$SHIMS" ]; then count=$((count + 1)); fi
	done
	IFS=$old_ifs
	[ "$count" -eq 1 ]
	for inherited in "" ":" "::" ":$SHIMS::$SHIMS:"; do
		PATH=$inherited
		sh_path_prepend "$SHIMS"
		if [ "$PATH" != "$SHIMS" ]; then
			printf 'PATH contains an empty entry after prepend: %s\n' "$PATH" >&2
			exit 1
		fi
	done
PROBE
real_bin="$tmp/real tool/bin"
mkdir -p "$real_bin"
printf '#!/bin/sh\nprintf "real-mise-node\\n"\n' >"$real_bin/node"
printf '#!/bin/sh\nexit 99\n' >"$real_bin/git"
chmod +x "$real_bin/node" "$real_bin/git"
completion="$tmp/real tool/share/bash-completion"
mkdir -p "$completion/completions"
printf 'BASH_COMPLETION_VERSINFO=(2 fixture)\n' >"$completion/bash_completion"
printf '__git_complete() { :; }\n' >"$completion/completions/git"
env -i HOME="$home" USER=mise-path-regression MACHINE_NAME=maclab \
	HOMEBREW_PREFIX="$tmp/legacy" SHELL_DOTFILES_DIR="$shell_dir" \
	PROFILE="$shell_dir/bash/profile" REAL_BIN="$real_bin" MISE_CALLS="$tmp/mise-calls" \
	PATH="$legacy:$shims:/usr/bin:/bin" \
	"$BASH" --noprofile --norc -s <<'PROBE'
	set -eu
	. "$PROFILE"
	[ "$(node)" = real-mise-node ]
	for pass in 1 2; do
		. "$SHELL_DOTFILES_DIR/bash/rc.d/20-bash-completion.sh"
		. "$SHELL_DOTFILES_DIR/bash/rc.d/21-git-completion.sh"
		[ "${BASH_COMPLETION_VERSINFO[1]}" = fixture ]
		[ "$(type -t __git_complete)" = function ]
	done
	[ "$(cat "$MISE_CALLS")" = 'env --shell bash' ]
PROBE
linux_shell="$tmp/linux-shell"
mkdir -p "$linux_shell/bash/lib"
printf '%s\n' \
	'sh_have() { return 1; }' \
	'sh_path_prepend() { PATH="$1:$PATH"; export PATH; }' \
	'sh_path_append() { :; }' >"$linux_shell/bash/lib/guards.sh"
env -i HOME="$home" USER=mise-path-regression HOMEBREW_PREFIX="$tmp/legacy" \
	SHELL_DOTFILES_DIR="$linux_shell" PROFILE="$shell_dir/bash/profile" \
	PATH="/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin" \
	"$BASH" --noprofile --norc -s <<'PROBE'
	set -eu
	uname() { printf 'Linux\n'; }
	. "$PROFILE"
	before_wrappers=${PATH%%/run/wrappers/bin*}
	case ":$before_wrappers:" in
	*:/run/current-system/sw/bin:*)
		printf 'NixOS privileged wrappers lost precedence: %s\n' "$PATH" >&2
		exit 1
		;;
	esac
PROBE
printf 'Profile command precedence and repeated-login uniqueness passed.\n'
