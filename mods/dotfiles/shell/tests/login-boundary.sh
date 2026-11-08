#!/usr/bin/env bash
set -euo pipefail
shell_dir=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home with spaces"
checkout="$tmp/checkout with spaces"
mkdir -p "$checkout/mods/dotfiles" "$home/.config/mise"
checkout=$(cd -- "$checkout" && pwd -P)
ln -s "$checkout/mods/dotfiles" "$home/.config/mise/dotfiles"
mkdir -p "$home/.local/bin" "$home/.nix-profile/etc/profile.d" "$home/.docker/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$TEST_HOST"\n' >"$home/.local/bin/hostname"
printf '#!/bin/sh\nprintf ":\\n"\n' >"$home/.local/bin/mise"
chmod +x "$home/.local/bin/hostname" "$home/.local/bin/mise"
printf 'touch "$HOME/bridge-read"\n' >"$home/.nix-profile/etc/profile.d/hm-session-vars.sh"
for host in Nicks-Loancrate-MacBook-Pro Nicks-MacBook-Pro maclab supermicro; do
	env -i HOME="$home" USER=login-boundary TEST_HOST="$host" MACHINE_NAME=stale \
		__HM_SESS_VARS_SOURCED=1 HOMEBREW_PREFIX="$tmp/brew" \
		DOTFILES_DIR=/stale EXPECTED_DOTFILES="$checkout" \
		PATH="$home/.local/bin:/usr/bin:/bin" SHELL_DOTFILES_DIR="$shell_dir" \
		PROFILE="$shell_dir/bash/profile" "$BASH" --noprofile --norc -s <<'PROBE'
set -eu
. "$PROFILE"
[ ! -e "$HOME/bridge-read" ]
[ "$DOTFILES_DIR" = "$EXPECTED_DOTFILES" ]
[ "$(sh_dotfiles_dir)" = "$EXPECTED_DOTFILES" ]
case "$TEST_HOST" in
Nicks-Loancrate-MacBook-Pro) expected=nicks-loancrate-mbp ;;
Nicks-MacBook-Pro) expected=nicks-mbp ;;
*) expected=$TEST_HOST ;;
esac
[ "$MACHINE_NAME" = "$expected" ]
if [ -x /run/current-system/sw/bin/bash ]; then
	[ "$(command -v bash)" = /run/current-system/sw/bin/bash ]
fi
PROBE
done
env -i HOME="$home" USER=login-boundary TEST_HOST=maclab \
	HOMEBREW_PREFIX="$tmp/brew" PATH="$home/.local/bin:/usr/bin:/bin" \
	SHELL_DOTFILES_DIR="$tmp/missing" PROFILE="$shell_dir/bash/profile" \
	"$BASH" --noprofile --norc -c 'set -eu; . "$PROFILE"'
printf 'Login identity, system Bash and missing-helper boundaries passed.\n'
