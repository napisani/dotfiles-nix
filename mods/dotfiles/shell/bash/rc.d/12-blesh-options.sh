# Keep ble.sh close to normal Readline behavior while using Kanagawa Dragon.

if [ -n "${BLE_VERSION:-}" ]; then
	# Use direct RGB faces so ble.sh can use the full Kanagawa Dragon palette.
	bleopt term_true_colors=semicolon
	bleopt term_index_colors=256

	# Kanagawa Dragon syntax and completion faces.
	ble-face -s argument_error bg=#ff5d62,fg=#1f1f28
	ble-face -s argument_option fg=#ff9e3b,italic
	ble-face -s auto_complete fg=#c8c093,italic
	ble-face -s cmdinfo_cd_cdpath fg=#a292a3,bg=#1f1f28,italic
	ble-face -s command_alias fg=#7fb4ca
	ble-face -s command_builtin fg=#ff9e3b
	ble-face -s command_directory fg=#7fb4ca
	ble-face -s command_file fg=#dcd7ba
	ble-face -s command_function fg=#a3d4d5
	ble-face -s command_keyword fg=#ff5d62
	ble-face -s disabled fg=#c8c093
	ble-face -s filename_directory fg=#7fb4ca
	ble-face -s filename_directory_sticky fg=#1f1f28,bg=#7fb4ca
	ble-face -s filename_executable fg=#98bb6c,bold
	ble-face -s filename_ls_colors none
	ble-face -s filename_orphan fg=#ff5d62,bold
	ble-face -s filename_other none
	ble-face -s filename_setgid fg=#1f1f28,bg=#ff9e3b,underline
	ble-face -s filename_setuid fg=#1f1f28,bg=#ff5d62,underline
	ble-face -s menu_filter_input fg=#1f1f28,bg=#ff9e3b
	ble-face -s overwrite_mode fg=#1f1f28,bg=#7fb4ca
	ble-face -s prompt_status_line fg=#dcd7ba,bg=#54546d
	ble-face -s region fg=#dcd7ba,bg=#2d4f67
	ble-face -s region_insert fg=#dcd7ba,bg=#2d4f67
	ble-face -s region_match fg=#1f1f28,bg=#ff9e3b
	ble-face -s region_target fg=#1f1f28,bg=#ff5d62
	ble-face -s syntax_brace fg=#c8c093
	ble-face -s syntax_command fg=#7fb4ca
	ble-face -s syntax_comment fg=#727169,italic
	ble-face -s syntax_delimiter fg=#c8c093
	ble-face -s syntax_document fg=#dcd7ba,bold
	ble-face -s syntax_document_begin fg=#dcd7ba,bold
	ble-face -s syntax_error bg=#ff5d62,fg=#1f1f28
	ble-face -s syntax_escape fg=#a3d4d5
	ble-face -s syntax_expr fg=#c4a7e7
	ble-face -s syntax_function_name fg=#7fb4ca
	ble-face -s syntax_glob fg=#a3d4d5
	ble-face -s syntax_history_expansion fg=#ff5d62,italic
	ble-face -s syntax_param_expansion fg=#c4a7e7
	ble-face -s syntax_quotation fg=#98bb6c
	ble-face -s syntax_tilde fg=#c4a7e7
	ble-face -s syntax_varname fg=#7fb4ca
	ble-face -s varname_array fg=#7fb4ca
	ble-face -s varname_empty fg=#7fb4ca
	ble-face -s varname_export fg=#7fb4ca
	ble-face -s varname_expr fg=#7fb4ca
	ble-face -s varname_hash fg=#7fb4ca
	ble-face -s varname_number fg=#a3d4d5
	ble-face -s varname_readonly fg=#ff9e3b
	ble-face -s varname_transform fg=#7fb4ca
	ble-face -s varname_unset bg=#ff5d62,fg=#1f1f28
	ble-face -s vbell_erase bg=#2d4f67

	bleopt complete_menu_complete=

	# Match Readline: abandon the current command and start a fresh prompt.
	ble-bind -m vi_imap -f 'C-c' discard-line
	ble-bind -m vi_nmap -f 'C-c' discard-line
fi
