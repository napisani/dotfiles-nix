# atuin shell history.
#
# Atuin recommends ble.sh >= 0.4 as its most accurate Bash preexec backend.
# Generate Atuin's integration before loading ble.sh: Atuin registers a
# BLE_ONLOAD callback for this supported order, while parsing its large init
# script before ble.sh's traps are active is substantially faster. Suppress the
# bash-preexec fallback only when ble.sh is available; otherwise retain Atuin's
# standalone fallback. This file stays after fzf so Atuin owns Ctrl-R.

sh_have atuin || return 0

if sh_has_line_editing; then
	if sh_have blesh-share; then
		ATUIN_NO_BUILTIN_PREEXEC=1 sh_init_tool atuin init bash
	else
		sh_init_tool atuin init bash
	fi
fi
