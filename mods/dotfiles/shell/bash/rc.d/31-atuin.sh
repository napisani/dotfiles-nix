# Load after fzf so Atuin retains Ctrl-R. Its bundled bash-preexec backend
# provides command lifecycle hooks for Atuin and Starship with Readline.

sh_have atuin || return 0

if sh_has_line_editing; then
	sh_init_tool atuin init bash
fi
