# starship prompt.
#
# Load after Atuin and mise so Starship can detect and preserve their preexec /
# PROMPT_COMMAND hooks. Use the documented command rather than the internal
# --print-full-init implementation detail.

sh_have starship || return 0

if [ "${TERM:-dumb}" != "dumb" ]; then
	sh_init_tool starship init bash
fi
