# scute's Bash integration is deliberately small and stable: one helper plus
# the configured build keybinding. Keep that integration here instead of
# starting Bun and loading the full CLI just to print this code on every shell
# startup. All checked-in machine configs use scute's default Ctrl-E binding.
sh_have scute || return 0

SCUTE_BIN=$(command -v scute)

_scute_build() {
	local tmpfile
	tmpfile=$(mktemp /tmp/scute-output.XXXXXX) || return
	SCUTE_OUTPUT_FILE="$tmpfile" "$SCUTE_BIN" build "$READLINE_LINE"
	if [ -f "$tmpfile" ]; then
		READLINE_LINE=$(<"$tmpfile")
		READLINE_POINT=${#READLINE_LINE}
		rm -f "$tmpfile"
	fi
}

if [[ $- == *i* ]] && [[ -t 0 ]] && bind -v >/dev/null 2>&1; then
	bind -x '"\C-e": _scute_build'
fi
