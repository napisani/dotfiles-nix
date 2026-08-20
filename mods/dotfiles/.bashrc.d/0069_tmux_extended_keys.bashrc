#!/usr/bin/env bash

# tmux's extended-keys (Kitty keyboard protocol reporting) is what gives
# Neovim and several agent CLIs Shift+Enter and other disambiguated key
# combos, but it's a server-wide tmux setting with a known bug
# (tmux/tmux#4663) that corrupts multi-line pastes at a plain shell prompt by
# re-encoding embedded newlines as literal CSI-u escape text. .tmux.conf
# defaults it off; these wrappers flip it on only for the duration one of
# these programs is actually running, and back off the moment it exits --
# right when you're back at a prompt and might paste something.
#
# Must use "always", not "on": "on" only forwards the enhanced encoding if
# tmux detected the outer terminal supports it, and that detection appears to
# happen once at client-attach time -- since the session now starts at
# "off", switching to "on" later leaves tmux still thinking the client can't
# handle it, so Shift+Enter silently degrades to plain Enter. Confirmed
# empirically: switching a live session to "on" did NOT fix Shift+Enter in a
# running Pi session; switching to "always" did, immediately, no restart.
#
# _TMUX_EXTKEYS_DEPTH guards nested invocations (e.g. opening nvim from
# inside claude, or vice versa) so an inner exit doesn't turn extended-keys
# off while the outer program still needs it.
#
# Known limitation: a program invoked another way (e.g. nvim launched as
# $EDITOR by a non-interactive subshell that doesn't source .bashrc.d) skips
# this wrapper and runs with extended-keys left at whatever it already was.
_tmux_extended_keys_wrap() {
	local real_cmd="$1"
	shift
	if [ -z "${TMUX:-}" ]; then
		command "$real_cmd" "$@"
		return
	fi
	: "${_TMUX_EXTKEYS_DEPTH:=0}"
	if [ "$_TMUX_EXTKEYS_DEPTH" -eq 0 ]; then
		tmux set-option -g extended-keys always
	fi
	_TMUX_EXTKEYS_DEPTH=$((_TMUX_EXTKEYS_DEPTH + 1))
	export _TMUX_EXTKEYS_DEPTH

	command "$real_cmd" "$@"
	local status=$?

	_TMUX_EXTKEYS_DEPTH=$((_TMUX_EXTKEYS_DEPTH - 1))
	export _TMUX_EXTKEYS_DEPTH
	if [ "$_TMUX_EXTKEYS_DEPTH" -eq 0 ]; then
		tmux set-option -g extended-keys off
	fi
	return $status
}

for _extkeys_cmd in nvim vim claude codex pi opencode; do
	if command -v "$_extkeys_cmd" >/dev/null 2>&1; then
		eval "${_extkeys_cmd}() { _tmux_extended_keys_wrap ${_extkeys_cmd} \"\$@\"; }"
	fi
done
unset _extkeys_cmd
