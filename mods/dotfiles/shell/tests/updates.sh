#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../bash/lib/guards.sh"
source "$script_dir/../bash/rc.d/55-nix-aliases.sh"
source "$script_dir/../bash/rc.d/56-update-functions.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export CALL_LOG="$tmp/calls"
export DEPS_STATUS=0
repo="$tmp/monorepo with spaces"
export DOTFILES_HOME_MANAGER_DIR="$repo/pub/dotfiles-nix"
mkdir -p "$DOTFILES_HOME_MANAGER_DIR" "$repo/scripts"
cat >"$repo/scripts/deps.ts" <<'DEPS'
#!/usr/bin/env bash
printf 'deps\ncwd=%s\n' "$PWD" >> "$CALL_LOG"
printf 'arg=%s\n' "$@" >> "$CALL_LOG"
exit "$DEPS_STATUS"
DEPS
chmod +x "$repo/scripts/deps.ts"
mkdir "$tmp/bin"
export PATH="$tmp/bin:$PATH"
for tool in darwin-rebuild nixos-rebuild; do
	cat >"$tmp/bin/$tool" <<'REBUILD'
#!/usr/bin/env bash
printf 'cwd=%s\n' "$PWD" >> "$CALL_LOG"
exit "$switch_status"
REBUILD
	chmod +x "$tmp/bin/$tool"
done
cat >"$tmp/bin/nix-collect-garbage" <<'GC'
#!/usr/bin/env bash
printf 'nix-collect-garbage %s\n' "$*" >> "$CALL_LOG"
exit "$gc_status"
GC
chmod +x "$tmp/bin/nix-collect-garbage"

available='darwin-rebuild brew nvim global-tools'
export switch_status=0
git_status=0
brew_failure=''
nvim_status=0
claude_status=0
export gc_status=0

sh_have() {
	case " $available " in
	*" $1 "*) return 0 ;;
	*) return 1 ;;
	esac
}
record() { printf '%s\n' "$*" >>"$CALL_LOG"; }
sudo() {
	record sudo "$@"
	"$@"
}
hostname() {
	[ "$1" = -s ]
	printf 'test-host\n'
}
git() {
	record git "$@"
	return "$git_status"
}
brew() {
	record brew "$@"
	[ "$1" != "$brew_failure" ] || return 42
}
nvim() {
	record nvim "$@"
	return "$nvim_status"
}
global-tools() {
	record global-tools "$@"
	return "$claude_status"
}
nix() { record nix "$@"; }

expect_status() {
	local expected="$1" status=0
	shift
	: >"$CALL_LOG"
	"$@" >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
	if [ "$status" -ne "$expected" ]; then
		printf '%s: expected exit %s, got %s\n' "$*" "$expected" "$status" >&2
		cat "$tmp/stdout" "$tmp/stderr" >&2
		exit 1
	fi
}
assert_calls() {
	local actual
	actual=$(<"$CALL_LOG")
	if [ "$actual" != "$1" ]; then
		printf 'Expected calls:\n%s\nActual calls:\n%s\n' "$1" "$actual" >&2
		exit 1
	fi
}

if declare -F update >/dev/null; then
	echo 'The generic update name is still defined' >&2
	exit 1
fi
expect_status 0 sys-update
assert_calls ''
grep -q 'Usage: sys-update' "$tmp/stdout"
grep -q 'nixswitchup' "$tmp/stdout"
expect_status 0 sys-update --help
assert_calls ''
expect_status 2 sys-update unknown
assert_calls ''
expect_status 2 sys-update tools unexpected
assert_calls ''

expect_status 0 sys-update list --json
assert_calls "deps
cwd=$repo
arg=list
arg=--json"
expect_status 0 sys-update check nix-core pi --json
assert_calls "deps
cwd=$repo
arg=check
arg=--project
arg=dotfiles-nix
arg=nix-core
arg=pi
arg=--json"
expect_status 0 sys-update pins npm-tools '@scope/package with spaces' --allow major --dry-run
assert_calls "deps
cwd=$repo
arg=update
arg=--project
arg=dotfiles-nix
arg=npm-tools
arg=@scope/package with spaces
arg=--allow
arg=major
arg=--dry-run"
expect_status 0 sys-update check --project kube-home-lab
assert_calls "deps
cwd=$repo
arg=check
arg=--project
arg=dotfiles-nix
arg=--project
arg=kube-home-lab"
export DEPS_STATUS=2
expect_status 2 sys-update pins skills
export DEPS_STATUS=0
chmod -x "$repo/scripts/deps.ts"
expect_status 127 sys-update pins nix-core
assert_calls ''
chmod +x "$repo/scripts/deps.ts"

original_pwd=$PWD
expect_status 0 nixswitch --verbose
assert_calls "sudo darwin-rebuild switch --show-trace --no-update-lock-file --flake .# --verbose
cwd=$DOTFILES_HOME_MANAGER_DIR"
[ "$PWD" = "$original_pwd" ]
expect_status 0 nixswitchup
assert_calls "git pull
sudo darwin-rebuild switch --show-trace --no-update-lock-file --flake .#
cwd=$DOTFILES_HOME_MANAGER_DIR"
[ "$PWD" = "$original_pwd" ]
switch_status=43
expect_status 43 nixswitch
expect_status 43 nixswitchup
switch_status=0
git_status=44
expect_status 44 nixswitchup
assert_calls 'git pull'
git_status=0
available=nixos-rebuild
expect_status 0 nixswitch
assert_calls "sudo nixos-rebuild --show-trace --no-update-lock-file --flake .#test-host switch --impure
cwd=$DOTFILES_HOME_MANAGER_DIR"
available=''
expect_status 127 nixswitch
assert_calls ''

expect_status 0 nixclean
assert_calls 'nix-collect-garbage -d
nix store optimise
sudo nix-collect-garbage -d
nix-collect-garbage -d'
gc_status=45
expect_status 45 nixclean
assert_calls 'nix-collect-garbage -d'
gc_status=0

available='brew nvim global-tools'
expect_status 0 sys-update tools
assert_calls 'brew update
brew upgrade
brew cleanup
nvim --headless +Lazy! sync +qa
global-tools update claude-plugins'
brew_failure=update
nvim_status=46
claude_status=47
expect_status 42 sys-update brew
assert_calls 'brew update'
expect_status 46 sys-update nvim
expect_status 47 sys-update claude
expect_status 1 sys-update tools
assert_calls 'brew update
nvim --headless +Lazy! sync +qa
global-tools update claude-plugins'
grep -q 'failed: brew nvim claude' "$tmp/stderr"
available=''
expect_status 0 sys-update tools
assert_calls ''

if type -t complete >/dev/null; then
	COMP_CWORD=1
	COMP_WORDS=(sys-update p)
	sh_complete_sys_update
	[ "${COMPREPLY[*]}" = pins ]
	COMP_CWORD=2
	COMP_WORDS=(sys-update pins '')
	sh_complete_sys_update
	[ "${#COMPREPLY[@]}" -eq 0 ]
	complete -p sys-update | grep -q sh_complete_sys_update
fi

alias nixswitch='false'
source "$script_dir/../bash/rc.d/55-nix-aliases.sh"
if alias nixswitch >/dev/null 2>&1; then
	echo 'nixswitch alias survived re-sourcing' >&2
	exit 1
fi

printf 'updates: ok\n'
