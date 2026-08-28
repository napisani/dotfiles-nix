# Shell options and history.
#
# The two history sizes and these four shopts are exactly what home-manager's
# programs.bash module used to emit. Reproduced verbatim rather than "improved",
# so this migration is provably behavior-neutral; tune them in a separate change.

HISTFILESIZE=100000
HISTSIZE=10000

# stderr is suppressed per-option rather than probed first: an unknown option
# makes `shopt -s` complain and return 1, and there is no side-effect-free way
# to ask "does this option exist" (`shopt -q NAME` reports whether it's *set*,
# not whether it's valid). home-manager could emit these unguarded because it
# only ever generated a .bashrc for the bash it also installed; a portable
# dotfile has to cope with stock macOS /bin/bash, which is 3.2 and has neither
# `globstar` nor `checkjobs`.
shopt -s histappend 2>/dev/null
shopt -s extglob 2>/dev/null
shopt -s globstar 2>/dev/null
shopt -s checkjobs 2>/dev/null
