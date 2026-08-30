# Core aliases — previously programs.bash.shellAliases in mods/shell.nix.
#
# Reproduced exactly, including `ls --color`, which is a GNU coreutils flag.
# That works today because coreutils is installed from nixpkgs on every host and
# shadows BSD ls; on a machine with only BSD ls this alias breaks `ls`. Left
# as-is because changing it is a behavior change, not a port — see
# ../../OWNERSHIP.md "Known rough edges".

# pet: Open files with Neovim
alias vim='nvim'
# pet: Search text with colored matches
alias grep='grep --color=auto'
# pet: Search fixed strings with colored matches
alias fgrep='fgrep --color=auto'
# pet: Search extended regular expressions with colored matches
alias egrep='egrep --color=auto'
# pet: List directory contents with color
alias ls='ls --color'
# pet: List all files with details and type indicators
alias ll='ls -alF'
# pet: List all files except dot and dot-dot
alias la='ls -A'
# pet: List files in columns with type indicators
alias l='ls -CF'
