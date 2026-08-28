# nix rebuild aliases — previously generated per host from interpolated nix
# values in homes/profiles/darwin.nix and homes/home-supermicro.nix.
#
# LOAD ORDER IS LOAD-BEARING. This file must stay numbered above
# 51-aliases-and-functions.sh, which also defines `nixupgrade` (as a bare
# `nix flake lock --update-input ...`). home-manager emitted its shellAliases
# *after* bashrcExtra, so the nix definition has always been the one that wins;
# keeping this file later preserves that. The now-dead duplicate was removed
# from 51 as part of this migration — that ambiguity, where load order silently
# picked between two definitions of the same alias, is exactly what this
# restructure is meant to eliminate.
#
# The rebuild command differs per platform, so it's selected by which binary
# exists rather than by interpolating a value at build time. That's what makes
# this file work on a host nix never configured: it simply defines nothing.

_nix_dotfiles_dir="${DOTFILES_HOME_MANAGER_DIR:-$HOME/code/monorepo/pub/dotfiles-nix}"

if sh_have darwin-rebuild; then
	_nix_switch="sudo darwin-rebuild switch --show-trace --no-update-lock-file --flake $_nix_dotfiles_dir/.#"
elif sh_have nixos-rebuild; then
	_nix_switch="sudo nixos-rebuild --show-trace --no-update-lock-file --flake $_nix_dotfiles_dir/.#$(hostname -s) switch --impure"
else
	unset _nix_dotfiles_dir
	return 0
fi

# shellcheck disable=SC2139  # expansion at definition time is intended here
{
	alias nixswitch="pushd $_nix_dotfiles_dir; $_nix_switch; popd"
	alias nixswitchup="pushd $_nix_dotfiles_dir; git pull && $_nix_switch; popd"
	alias nixflakeup="pushd $_nix_dotfiles_dir; nix flake update --refresh && $_nix_switch; popd"
	alias nixupgrade="pushd $_nix_dotfiles_dir; nix flake update --refresh && $_nix_switch; popd"
	alias nixclean="echo 'Collecting garbage...'; nix-collect-garbage -d && echo 'Optimizing store...'; nix store optimise && echo 'Cleaning up old profiles...'; sudo nix-collect-garbage -d && echo 'Done! Space freed.'"
}

unset _nix_dotfiles_dir _nix_switch
