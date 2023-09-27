# if homebrew is on this machine include it 
# on the path and export all of its env vars 
if [ -f "/opt/homebrew/bin/brew" ] ; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export EDITOR="nvim"
export VISUAL="nvim" 


