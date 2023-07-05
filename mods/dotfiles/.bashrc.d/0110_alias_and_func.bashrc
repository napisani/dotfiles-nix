# keep retrying a command until it succeeds
function keep_retrying {
  local n=1
  local max=10
  local delay=15
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
       	echo "The command has failed after $n attempts." >&2
	exit 1
      fi
    }
  done
}

# lookup cheat sheet
function cht() {
  read -p "Enter query: " query
  curl -s "cht.sh/$query" | bat --pager "less -R"
}

alias chrome_insecure='open -n -a /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --user-data-dir="/tmp/chrome_dev_test" --disable-web-security'
alias LockScreen='open -a /System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/ScreenSaverEngine.app'
alias serve-directory='python3 -m http.server'
alias password-lookup='pushd $(pwd) ; cd ~/scripts/password-lookup3; python password-lookup.py; popd'
alias restart-karabiner='killall Karabiner-Elements && launchctl stop org.pqrs.karabiner.karabiner_console_user_server && sleep 3 && launchctl start org.pqrs.karabiner.karabiner_console_user_server && open -a karabiner-elements'
