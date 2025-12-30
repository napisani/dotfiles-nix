# if homebrew is on this machine include it 
# on the path and export all of its env vars 
if [ -f "/opt/homebrew/bin/brew" ] ; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Ensure user-local bins stay ahead of Homebrew/path_helper
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/shell_scripts:$PATH"


export EDITOR="nvim"
export VISUAL="nvim" 

ulimit -n 65536 


export SBTAMER_EDITOR='nvim +"term cat %s"  +"execute \":normal! G\""'
export SBTAMER_TERMINATOR='.*❯.*' 


