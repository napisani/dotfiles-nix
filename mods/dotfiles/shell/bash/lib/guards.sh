# Helpers shared by every rc.d fragment and by profile.
#
# The whole point of this file is that nothing downstream needs to know whether
# a tool came from nix, homebrew, a curl installer, or isn't installed at all.
# No fragment should ever name an absolute /nix/store path — that's what made
# the previous nix-generated .bashrc unusable off a nix host.
#
# Sourced by both profile (login) and bashrc (interactive), so it must stay
# POSIX-ish and side-effect free beyond defining functions.

# Is this command available?
sh_have() {
	command -v "$1" >/dev/null 2>&1
}

# Source a file only if it's readable. Returns success either way, so a missing
# optional file never aborts shell startup.
sh_source_if() {
	[ -r "$1" ] || return 0
	# shellcheck disable=SC1090
	. "$1"
}

# Source the first readable file from the arguments, then stop.
sh_source_first() {
	local candidate
	for candidate in "$@"; do
		if [ -r "$candidate" ]; then
			# shellcheck disable=SC1090
			. "$candidate"
			return 0
		fi
	done
	return 1
}

# Prepend to PATH, but only once and only if the directory exists.
#
# Idempotence matters: the old 0050_shell.bashrc prepended unconditionally from
# .bashrc, so every nested interactive shell added another copy — the pre-change
# baseline had $HOME/.local/bin, $HOME/shell_scripts and $HOME/toolbox in PATH
# three times each.
sh_path_prepend() {
	local dir="$1"
	[ -d "$dir" ] || return 0
	case ":$PATH:" in
	*":$dir:"*) return 0 ;;
	esac
	PATH="$dir:$PATH"
	export PATH
}

sh_path_append() {
	local dir="$1"
	[ -d "$dir" ] || return 0
	case ":$PATH:" in
	*":$dir:"*) return 0 ;;
	esac
	PATH="$PATH:$dir"
	export PATH
}

# Evaluate a tool's shell-init output, if the tool exists.
#   sh_init_tool starship init bash --print-full-init
sh_init_tool() {
	sh_have "$1" || return 0
	local output
	# A tool that fails to emit init shouldn't take the shell down with it.
	output=$("$@" 2>/dev/null) || return 0
	[ -n "$output" ] || return 0
	eval "$output"
}

# True when the shell is interactive. Cheaper and clearer at call sites than
# repeating the $- test.
sh_is_interactive() {
	case $- in
	*i*) return 0 ;;
	*) return 1 ;;
	esac
}

# True when readline is active, which is what tool keybindings require. A
# `TERM=dumb` shell (e.g. inside an editor's terminal shim) has line editing
# disabled, and binding keys there produces errors on every startup.
sh_has_line_editing() {
	sh_is_interactive || return 1
	[ "${TERM:-dumb}" != "dumb" ] || return 1
	case ":$SHELLOPTS:" in
	*:vi:* | *:emacs:*) return 0 ;;
	esac
	return 1
}
