# fzf keybindings and completion.
#
# FZF_CTRL_R_COMMAND="" must be set BEFORE `fzf --bash` runs: it's how fzf is
# told to skip installing its own Ctrl-R history widget, leaving Ctrl-R to atuin
# (31-atuin.sh, which loads immediately after). Ctrl-T and Alt-C stay with fzf.
#
# This used to come from `programs.fzf.historyWidget.bash.command = ""`, an
# option that doesn't exist in the home-manager 26.05 release — so it was gated
# on `!useHomeManager26` and maclab silently never got it, leaving fzf owning
# Ctrl-R on that one host. Setting it here fixes that divergence: all four hosts
# now behave the same.
#
# The SHELLOPTS guard mirrors what home-manager emitted — no point installing
# keybindings in a shell with line editing disabled.

sh_have fzf || return 0

export FZF_CTRL_R_COMMAND=""

if sh_has_line_editing; then
	sh_init_tool fzf --bash
fi
