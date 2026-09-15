# Load ble.sh after the integrations that support its BLE_ONLOAD callback
# (notably Atuin), but before Starship, which detects ble.sh during its own init.
# Keeping ble.sh's traps inactive while earlier generated scripts are parsed
# materially reduces startup time. Attachment still waits until every prompt
# hook and local override has loaded. `blesh-share` comes from Nix's blesh
# package.

sh_have blesh-share || return 0

_blesh_share=$(blesh-share) || return 0
if [ -r "$_blesh_share/ble.sh" ]; then
	# shellcheck disable=SC1090
	source -- "$_blesh_share/ble.sh" --attach=none
fi
unset _blesh_share
