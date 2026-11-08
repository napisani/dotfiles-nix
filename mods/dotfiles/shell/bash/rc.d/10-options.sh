HISTFILESIZE=100000
HISTSIZE=10000

# Stock macOS Bash 3.2 lacks globstar and checkjobs.
shopt -s histappend 2>/dev/null
shopt -s extglob 2>/dev/null
shopt -s globstar 2>/dev/null
shopt -s checkjobs 2>/dev/null
