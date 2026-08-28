# atuin shell history.
#
# Atuin recommends ble.sh >= 0.4 as its most accurate Bash preexec backend. When
# ble.sh loaded successfully, suppress Atuin's built-in bash-preexec fallback;
# otherwise keep the fallback so a missing optional package does not disable
# history capture. This file stays after fzf so Atuin owns Ctrl-R.

sh_have atuin || return 0

if sh_has_line_editing; then
	if [ -n "${BLE_VERSION:-}" ]; then
		ATUIN_NO_BUILTIN_PREEXEC=1 sh_init_tool atuin init bash
	else
		sh_init_tool atuin init bash
	fi
fi
