# direnv shell hook.
#
# The official docs require this hook to be added after other prompt-modifying
# extensions. It therefore loads after mise and Starship. nix-direnv itself is
# still package-shaped: Home Manager installs its library under
# ~/.config/direnv/lib, where direnv discovers it automatically.

sh_have direnv || return 0
sh_init_tool direnv hook bash
