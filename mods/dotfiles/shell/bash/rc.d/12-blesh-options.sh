# Keep ble.sh close to normal Readline behavior while using Tokyo Night.

if [ -n "${BLE_VERSION:-}" ]; then
	bleopt color_scheme=tokyonight
	bleopt complete_menu_complete=

	# Match Readline: abandon the current command and start a fresh prompt.
	ble-bind -m vi_imap -f 'C-c' discard-line
	ble-bind -m vi_nmap -f 'C-c' discard-line
fi
