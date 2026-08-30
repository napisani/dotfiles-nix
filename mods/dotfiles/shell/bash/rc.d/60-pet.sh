# pet snippet selection and history capture.
#
# These are pet's documented Bash functions, with the existing animal-rescue
# config selection and Ctrl-F Ctrl-R binding preserved.

sh_have pet || return 0

prev() {
	local previous
	previous=$(history | tail -n 2 | head -n 1 | sed 's/[0-9]* //')
	sh -c "pet new $(printf %q "$previous")"
}

pet-select() {
	local buffer config
	config=$(animal-rescue \
		--config "$HOME/.config/pet/config.toml" \
		--shell-path "$SHELL_DOTFILES_DIR/bash/rc.d") || return
	buffer=$(pet search --query "$READLINE_LINE" --config "$config") || return
	READLINE_LINE=$buffer
	READLINE_POINT=${#buffer}
}

if sh_have animal-rescue && sh_has_line_editing; then
	bind -x '"\C-f\C-r": pet-select'
fi
