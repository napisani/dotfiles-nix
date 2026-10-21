#!/usr/bin/env bash
set -euo pipefail
picker=${1:?Usage: pr-review-native.sh /absolute/path/to/candidate-tmux-picker}
picker="$(cd -P "$(dirname "$picker")" && pwd -P)/$(basename "$picker")"
script_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
profile="$script_dir/../../toolbox/workmux-review.json"
root=$(mktemp -d /tmp/pr-review-native.XXXXXX)
root=$(cd "$root" && pwd -P)
mkdir -p "$root/home" "$root/config/workmux" "$root/repo" "$root/bin"
export HOME="$root/home" XDG_CONFIG_HOME="$root/config" XDG_STATE_HOME="$root/state" XDG_CACHE_HOME="$root/cache" XDG_DATA_HOME="$root/data"
export NOSYSBASHRC=1 TERM=xterm-256color
printf '{"agent":"pi","nerdfont":true}\n' >"$root/config/workmux/config.yaml"
cat >"$root/bin/pi" <<'AGENT'
#!/usr/bin/env bash
while :; do sleep 30; done
AGENT
chmod +x "$root/bin/pi"
export PATH="$root/bin:$PATH"
socket="$root/tmux.sock"
trap 'tmux -S "$socket" kill-server 2>/dev/null || true; rm -rf "$root"' EXIT
tmux -S "$socket" new-session -d -s fixture -x 120 -y 40
pid=$(tmux -S "$socket" display-message -p '#{pid}')
export TMUX="$socket,$pid,0"
cd "$root/repo"
git init -q -b main
git config user.name Fixture
git config user.email fixture@example.invalid
printf 'fixture\n' >source.txt
jq -n --arg root "$root" '{mode:"session",agent:"pi",post_create:[("touch "+$root+"/setup-ran")],pre_remove:[("touch "+$root+"/teardown-ran; exit 1")],files:{copy:["private-copy.txt"]},panes:[{command:"<agent>"}]}' >.workmux.yaml
printf 'owned configuration\n' >private-copy.txt
git add source.txt .workmux.yaml
git commit -qm fixture
head=$(git rev-parse HEAD)
handle=review-12-runtime
workmux add review/12-runtime --name "$handle" --base "$head" --config "$profile" -H -F -b
wt="$root/repo__worktrees/$handle"
session=''
for _ in {1..40}; do
  session=$(tmux list-panes -a -F '#{session_id}:#{pane_current_path}' | grep -F ":$wt" | cut -d: -f1 | sort -u) || session=''
  if [ -n "$session" ] && [ "$(tmux show-option -t "$session" -qv @tmux_picker_category)" = Reviews ] &&
       tmux list-panes -t "$session" -F '#{pane_current_command}' | grep -qx nvim; then break; fi
  sleep 0.1
done
[ -n "$session" ]
[ "$(tmux show-option -t "$session" -qv @tmux_picker_category)" = Reviews ]
tmux list-panes -t "$session" -F '#{pane_current_command}' | grep -qx nvim
[ ! -e "$root/setup-ran" ] && [ ! -e "$wt/private-copy.txt" ]
[ -d "$wt" ]
printf 'owned notes\n' >"$wt/notes.txt"
git -C "$wt" add notes.txt
git -C "$wt" commit -qm 'local review work'
local_head=$(git -C "$wt" rev-parse HEAD)
workmux add review/12-runtime --name "$handle" --base "$head" --config "$profile" -H -F --open-if-exists -b
[ "$(git -C "$wt" rev-parse HEAD)" = "$local_head" ]
[ "$(cat "$wt/notes.txt")" = 'owned notes' ]
# Removal hands the client off first, so the headless fixture needs an attached pty client
# whose stdin stays open.
(sleep 60) | script -q /dev/null tmux -S "$socket" attach -t fixture >/dev/null 2>&1 &
client=$!
for _ in {1..40}; do [ -n "$(tmux list-clients 2>/dev/null)" ] && break; sleep 0.1; done
"$picker" kill "$session"
kill "$client" 2>/dev/null || true
# The failing teardown ran, aborted workmux, and the picker still removed everything.
[ -e "$root/teardown-ran" ] && [ ! -d "$wt" ]
[ -z "$(git branch --list review/12-runtime)" ]
workmux add development --base "$head" -b
[ -f "$root/setup-ran" ] && [ -f "$root/repo__worktrees/development/private-copy.txt" ]
printf 'native profile: normal Neovim, isolated review setup, native reuse, removal despite a failing teardown, and normal development setup passed\n'
