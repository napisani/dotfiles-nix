# mise interactive shell activation.
#
# `mise activate bash` is the documented hook. Completion generation is a
# one-time install operation, not shell startup behavior; Nix's mise package
# already exposes a version-matched completion to bash-completion. Off Nix, run
# `mise completion bash --install` once if the package manager does not provide
# it.

sh_have mise || return 0
sh_init_tool mise activate bash
