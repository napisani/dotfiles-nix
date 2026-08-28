# Load ble.sh early so integrations can register against it, but defer taking
# over line editing until every prompt hook and local override has loaded.
# `blesh-share` is provided by Nix's blesh package.

sh_have blesh-share || return 0

_blesh_share=$(blesh-share) || return 0
if [ -r "$_blesh_share/ble.sh" ]; then
	# shellcheck disable=SC1090
	source -- "$_blesh_share/ble.sh" --attach=none
fi
unset _blesh_share
