# Core aliases — previously programs.bash.shellAliases in mods/shell.nix.
#
# Reproduced exactly, including `ls --color`, which is a GNU coreutils flag.
# That works today because coreutils is installed from nixpkgs on every host and
# shadows BSD ls; on a machine with only BSD ls this alias breaks `ls`. Left
# as-is because changing it is a behavior change, not a port — see
# ../../OWNERSHIP.md "Known rough edges".

alias vim='nvim'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ls='ls --color'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
