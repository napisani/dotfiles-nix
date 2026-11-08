# mise interactive shell activation. The `apps:configure` task installs the
# version-matched completion that bash-completion loads on demand.

sh_have mise || return 0
sh_init_tool mise activate bash
