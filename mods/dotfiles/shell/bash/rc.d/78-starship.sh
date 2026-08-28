# starship prompt.
#
# Load after Atuin and mise so Starship can detect and preserve their preexec /
# PROMPT_COMMAND hooks. Use the documented command rather than Home Manager's
# internal --print-full-init implementation detail.
#
# STARSHIP_CONFIG points at ~/.config/starship.toml via Home Manager session
# variables on Nix hosts; Starship defaults to that same path elsewhere.

sh_have starship || return 0

if [ "${TERM:-dumb}" != "dumb" ]; then
	sh_init_tool starship init bash
fi
