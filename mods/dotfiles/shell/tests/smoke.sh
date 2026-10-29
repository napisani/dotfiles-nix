#!/usr/bin/env bash
# Assert the shell integrations that Nix evaluation cannot: clean startup,
# generated hook functions, prompt ordering, completion provenance, and readline
# bindings. Use --simulate to test checkout edits before activating Home Manager.

set -uo pipefail

bash_bin=""
simulate_dir=""

usage() {
	cat <<'EOF'
Usage: smoke.sh [--simulate SHELL_DIR] [--bash BASH]

Without --simulate, test the installed login shell. With --simulate, source the
candidate profile and bashrc directly while retaining the current HOME and tool
installation.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--simulate)
		simulate_dir="${2:?--simulate needs a shell dotfiles directory}"
		shift 2
		;;
	--bash)
		bash_bin="${2:?--bash needs a path}"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "smoke.sh: unknown argument: $1" >&2
		exit 2
		;;
	esac
done

usable_bash() {
	[ -x "$1" ] || return 1
	"$1" -c 'type -t bind >/dev/null && type -t compgen >/dev/null' 2>/dev/null
}

pick_bash() {
	local candidate
	for candidate in \
		"${SHELL:-}" \
		"/etc/profiles/per-user/${USER:-$(id -un)}/bin/bash" \
		"$HOME/.nix-profile/bin/bash" \
		"/run/current-system/sw/bin/bash" \
		$(command -v -p bash 2>/dev/null) \
		"/bin/bash"; do
		case "$candidate" in
		*bash)
			if usable_bash "$candidate"; then
				printf '%s\n' "$candidate"
				return 0
			fi
			;;
		esac
	done
	return 1
}

if [ -n "$simulate_dir" ]; then
	simulate_dir=$(cd -- "$simulate_dir" && pwd) || exit 1
	for file in bash/profile bash/bashrc inputrc; do
		[ -r "$simulate_dir/$file" ] || {
			echo "smoke.sh: missing $simulate_dir/$file" >&2
			exit 1
		}
	done
fi

if [ -z "$bash_bin" ]; then
	bash_bin=$(pick_bash) || {
		echo "smoke.sh: no Bash with readline and programmable completion" >&2
		exit 1
	}
fi
usable_bash "$bash_bin" || {
	echo "smoke.sh: $bash_bin lacks readline or programmable completion" >&2
	exit 1
}
command -v expect >/dev/null 2>&1 || {
	echo "smoke.sh: expect(1) is required for interactive Readline checks" >&2
	exit 1
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/shell-smoke.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
probe="$tmp/probe.sh"
rcfile="$tmp/bashrc"
expect_script="$tmp/probe.exp"
stdout="$tmp/stdout"
stderr="$tmp/stderr"
clean_stderr="$tmp/stderr.clean"
ctrl_c_marker="$tmp/ctrl-c-retained"

cat >"$probe" <<'PROBE'
smoke_fail() {
	echo "smoke.sh: $*" >&2
	exit 1
}

for name in \
	__fzf_select__ \
	__atuin_history \
	__git_complete \
	_direnv_hook \
	_mise_hook_prompt_command \
	pet-select \
	_scute_build \
	starship_precmd; do
	[ "$(type -t "$name" 2>/dev/null)" = function ] || smoke_fail "missing function: $name"
done

[ -z "${BLE_VERSION:-}" ] || smoke_fail "ble.sh is still loaded"
[ -z "$(type -t ble-attach 2>/dev/null)" ] || smoke_fail "ble.sh functions are still loaded"
case ":$SHELLOPTS:" in
*:vi:*) ;;
*) smoke_fail "Readline vi mode is not enabled" ;;
esac
case "${PROMPT_COMMAND[*]:-}" in
*_direnv_hook*) ;;
*) smoke_fail "direnv prompt hook is missing" ;;
esac
case " ${precmd_functions[*]:-} " in
*" starship_precmd "*) ;;
*) smoke_fail "Starship is absent from bash-preexec prompt hooks" ;;
esac
case " ${precmd_functions[*]:-} " in
*" __atuin_precmd "*) ;;
*) smoke_fail "Atuin prompt hook is missing" ;;
esac
case " ${preexec_functions[*]:-} " in
*" __atuin_preexec "*) ;;
*) smoke_fail "Atuin preexec hook is missing" ;;
esac
case "${ATUIN_PREEXEC_BACKEND:-}" in
*:bash-preexec*) ;;
*) smoke_fail "Atuin did not select its bash-preexec backend" ;;
esac

completion_status=0
_completion_loader mise >/dev/null 2>&1 || completion_status=$?
case "$completion_status" in 0 | 124) ;; *) smoke_fail "mise completion failed to load" ;; esac
_mise_completion=$(complete -p mise 2>/dev/null) || smoke_fail "packaged mise completion is missing"
_mise_completion=${_mise_completion#* -F }
_mise_completion=${_mise_completion%% *}
[ "$(type -t "$_mise_completion" 2>/dev/null)" = function ] || smoke_fail "mise completion function is missing"
unset _mise_completion
if [ -e "$HOME/.local/share/bash-completion/completions/mise" ] \
	|| [ -L "$HOME/.local/share/bash-completion/completions/mise" ]; then
	smoke_fail "user-local mise completion shadows the packaged completion"
fi

_binding_dump=$(bind -m emacs -X; bind -m vi-insert -X; bind -m vi-command -X)
case "$_binding_dump" in *pet-select*) ;; *) smoke_fail "pet keybinding is missing" ;; esac
case "$_binding_dump" in *_scute_build*) ;; *) smoke_fail "scute keybinding is missing" ;; esac
unset _binding_dump

printf 'hooks and completions: ok\n'
printf 'keybindings: ok\n'
PROBE

simulated_prelude() {
	printf 'SHELL_DOTFILES_DIR=%q; export SHELL_DOTFILES_DIR; ' "$simulate_dir"
	printf 'INPUTRC=%q/inputrc; export INPUTRC; ' "$simulate_dir"
	printf '. %q/bash/profile; . %q/bash/bashrc; ' "$simulate_dir" "$simulate_dir"
}

shell_startup() {
	if [ -n "$simulate_dir" ]; then
		"$bash_bin" --noprofile --norc -ic "$(simulated_prelude)true"
	else
		"$bash_bin" -lic true
	fi
}

status=0
shell_startup >"$stdout" 2>"$stderr" || status=$?
grep -Eiv 'cannot set terminal process group|no job control in this shell|stdin isn.t a terminal|.standard input.: Operation not supported|inappropriate ioctl' \
	"$stderr" >"$clean_stderr" || true
if [ "$status" -ne 0 ] || [ -s "$clean_stderr" ]; then
	cat "$clean_stderr" >&2
	[ "$status" -ne 0 ] || status=1
	exit "$status"
fi

{
	cat <<'READY'
_shell_smoke_ready() {
	# Wait for prompt rendering, not just completion of PROMPT_COMMAND hooks.
	PS1+='SHELL_SMOKE_READY '
}
READY
	if [ -n "$simulate_dir" ]; then
		printf 'SHELL_DOTFILES_DIR=%q; export SHELL_DOTFILES_DIR\n' "$simulate_dir"
		printf 'INPUTRC=%q/inputrc; export INPUTRC\n' "$simulate_dir"
		printf '. %q/bash/profile\n. %q/bash/bashrc\n' "$simulate_dir" "$simulate_dir"
	else
		printf '. %q\n' "$HOME/.bash_profile"
	fi
	printf 'PROMPT_COMMAND+=(_shell_smoke_ready)\n'
} >"$rcfile"

cat >"$expect_script" <<'EXPECT'
set timeout 60
set bash_path [lindex $argv 0]
set rcfile [lindex $argv 1]
set probe [lindex $argv 2]
set ctrl_c_marker [lindex $argv 3]
spawn -noecho $bash_path --noprofile --rcfile $rcfile -i
expect {
	-exact "SHELL_SMOKE_READY" {}
	timeout { puts stderr "smoke.sh: timed out waiting for the shell prompt"; exit 1 }
	eof { puts stderr "smoke.sh: shell exited before the first prompt"; exit 1 }
}
send -- ". $probe\r"
expect {
	-exact "hooks and completions: ok" {}
	timeout { puts stderr "smoke.sh: timed out waiting for hook checks"; exit 1 }
	eof { puts stderr "smoke.sh: shell exited during hook checks"; exit 1 }
}
expect {
	-exact "keybindings: ok" {}
	timeout { puts stderr "smoke.sh: timed out waiting for keybinding checks"; exit 1 }
	eof { puts stderr "smoke.sh: shell exited during keybinding checks"; exit 1 }
}
expect {
	-exact "SHELL_SMOKE_READY" {}
	timeout { puts stderr "smoke.sh: timed out waiting for the next prompt"; exit 1 }
	eof { puts stderr "smoke.sh: shell exited before the Ctrl-C check"; exit 1 }
}
send -- "touch '$ctrl_c_marker'"
after 300
send -- "\003"
expect {
	-exact "SHELL_SMOKE_READY" {}
	timeout { puts stderr "smoke.sh: Ctrl-C did not return to a prompt"; exit 1 }
	eof { puts stderr "smoke.sh: shell exited during the Ctrl-C check"; exit 1 }
}
send -- "\r"
expect {
	-exact "SHELL_SMOKE_READY" {}
	timeout { puts stderr "smoke.sh: empty input did not return to a prompt"; exit 1 }
	eof { puts stderr "smoke.sh: shell exited after empty input"; exit 1 }
}
send -- "exit\r"
expect eof
EXPECT

status=0
expect "$expect_script" "$bash_bin" "$rcfile" "$probe" "$ctrl_c_marker" >"$stdout" 2>"$stderr" || status=$?
if [ -e "$ctrl_c_marker" ]; then
	echo "smoke.sh: Ctrl-C retained and executed the current command" >&2
	status=1
fi
if [ "$status" -ne 0 ]; then
	cat "$stdout" >&2
	cat "$stderr" >&2
	exit "$status"
fi

grep -q 'hooks and completions: ok' "$stdout" || {
	cat "$stdout" >&2
	cat "$stderr" >&2
	exit 1
}
grep -q 'keybindings: ok' "$stdout" || {
	cat "$stdout" >&2
	exit 1
}

echo "hooks and completions: ok"
echo "keybindings: ok"
if [ -n "$simulate_dir" ]; then
	echo "shell smoke: ok (candidate $simulate_dir)"
else
	echo "shell smoke: ok (installed configuration)"
fi
