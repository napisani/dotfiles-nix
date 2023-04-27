# if homebrew is on this machine include it 
# on the path and export all of its env vars 
if [ -f "/opt/homebrew/bin/brew" ] ; then
  echo "tes"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
