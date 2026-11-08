sh_have fzf || return 0

# Set before fzf initializes so Atuin retains Ctrl-R.
export FZF_CTRL_R_COMMAND=""

if sh_has_line_editing; then
	sh_init_tool fzf --bash
fi
