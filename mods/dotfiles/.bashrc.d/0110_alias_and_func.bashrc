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
alias restart-karabiner='killall Karabiner-Elements ; launchctl stop org.pqrs.karabiner.karabiner_console_user_server && sleep 3 && launchctl start org.pqrs.karabiner.karabiner_console_user_server && open -a karabiner-elements'

alias dns-clear='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
alias cdhomeman='cd ~/.config/home-manager'
alias nixupgrade='nix flake lock --update-input nixpkgs-unstable; nix flake lock --update-input nixpkgs'

# capture the output of a command so it can be retrieved with ret
cap() { 
  tee /tmp/cmd_cap.out;
}

# return the output of the most recent command that was captured by cap
ret() { 
  cat /tmp/cmd_cap.out;
}

# edit the output catpured from the most recent command that was captured by cap
eret() { 
  nvim /tmp/cmd_cap.out;
}

function ls-on-port() {
  PORT="$1"
  if [ -z "$PORT" ]; then
    echo "Usage: ls-on-port <port_number>"
    return 1
  fi
  lsof -n -i :"$PORT"
}

function kill-on-port() {
  PORT="$1"
  if [ -z "$PORT" ]; then
    echo "Usage: kill-on-port <port_number>"
    return 1
  fi
  ls-on-port "$PORT" | grep -v ^COMMAND | awk '{print $2}' | xargs kill -9
}

function kill-all() {
  WHAT="$1"
  if [ -z "$WHAT" ]; then
    echo "Usage: kill-all <process name>"
    return 1
  fi
  ps aux | grep "$WHAT" | grep -v grep | awk '{print $2}' | xargs kill -9
}

function color-test {
  awk -v term_cols="${width:-$(tput cols || echo 80)}" -v term_lines="${height:-1}" 'BEGIN{
      s="/\\";
      total_cols=term_cols*term_lines;
      for (colnum = 0; colnum<total_cols; colnum++) {
          r = 255-(colnum*255/total_cols);
          g = (colnum*510/total_cols);
          b = (colnum*255/total_cols);
          if (g>255) g = 510-g;
          printf "\033[48;2;%d;%d;%dm", r,g,b;
          printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
          printf "%s\033[0m", substr(s,colnum%2+1,1);
          if (colnum%term_cols==term_cols) printf "\n";
      }
      printf "\n";
  }'
}

function temp-git-clone() {
  GIT_REPO="$1"
  if [ -z "$GIT_REPO" ]; then
    echo "Usage: temp-git-clone <git_repo>"
    return 1
  fi
  PROJECT_NAME=$(basename "$GIT_REPO" .git)
  EPOCH=$(date +%s)
  TEMP_DIR="/tmp/tgc-$PROJECT_NAME-$EPOCH"
  mkdir -p "$TEMP_DIR"
  pushd "$TEMP_DIR"
  git clone "$GIT_REPO" .
}

alias gitcm='git commit -m'
alias gita='git add .'


function project-root-dir() {
    local DIR="$(pwd)"
    while [[ "$DIR" != "/" ]]; do
        if [[ -d "$DIR/.git" ]]; then
            echo "$DIR"
            return 0
        fi
        DIR="$(dirname "$DIR")"
    done
    echo "No .git directory found in the directory tree."
    return 1
}

function cdpr() {
  DIR=$(project-root-dir "$1")
  if [ -z "$DIR" ]; then
    return 1
  fi
  cd "$DIR"
}


# diff two files in WebStorm
alias wsdiff='function _wsdiff() { /Applications/WebStorm.app/Contents/MacOS/webstorm diff "$1" "$2"; }; _wsdiff'

alias nixpkgup='cdhomeman && nix flake lock --update-input nixpkgs-unstable; nix flake lock --update-input nixpkgs'

function nix-update-home-packages() {
  cdhomeman
  nix flake lock \
  --update-input nixpkgs-unstable \
  --update-input nixpkgs \
  --update-input home-manager \
  --update-input procmux \
  --update-input secret_inject \
  --update-input animal_rescue \
  --update-input scrollbacktamer
}

# scrollbacktamer aliases
alias stame='scrollbacktamer'
alias stame-last='scrollbacktamer -last 1'



