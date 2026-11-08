#!/bin/sh
set -eu

[ "$(uname -s)" = Darwin ] || exit 0
[ "$#" -eq 2 ] || {
	printf 'Usage: %s BINARY LEGACY_PLIST\n' "$0" >&2
	exit 2
}
if [ ! -x "$1" ]; then
	printf 'Install the reviewed native OmniWM cask before applying its LaunchAgent.\n' >&2
	exit 1
fi
if [ -e "$2" ] || [ -L "$2" ]; then
	printf 'Retire the Home Manager OmniWM plist through the migration allowlist first.\n' >&2
	exit 1
fi
status=0
launchctl print "gui/$(id -u)/org.nix-community.home.omniwm" >/dev/null 2>&1 || status=$?
case "$status" in
113) ;;
0)
	printf 'The Home Manager OmniWM agent is still loaded; complete its reviewed handoff first.\n' >&2
	exit 1
	;;
*)
	printf 'Unable to verify the Home Manager OmniWM agent state.\n' >&2
	exit 1
	;;
esac
