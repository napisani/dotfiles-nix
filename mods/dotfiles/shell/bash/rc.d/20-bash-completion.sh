if [ -z "${BASH_COMPLETION_VERSINFO:-}" ]; then
	_bash_completion_file=
	_completion_path=$PATH
	while :; do
		_completion_bin=${_completion_path%%:*}
		if [ -n "$_completion_bin" ] && [ -r "$_completion_bin/../share/bash-completion/bash_completion" ]; then
			_bash_completion_file="$_completion_bin/../share/bash-completion/bash_completion"
			break
		fi
		case "$_completion_path" in
		*:*) _completion_path=${_completion_path#*:} ;;
		*) break ;;
		esac
	done
	unset _completion_path _completion_bin
	_bash_completion_root=
	case "$OSTYPE" in
	darwin*)
		# Login shells expose the library through PATH; shim-only callers need lookup.
		if [ -z "$_bash_completion_file" ] && sh_have mise; then
			_bash_completion_root=$(mise where conda:bash-completion 2>/dev/null) || _bash_completion_root=
		fi
		;;
	esac
	sh_source_first \
		"$_bash_completion_file" \
		"${_bash_completion_root:+$_bash_completion_root/share/bash-completion/bash_completion}" \
		"/etc/profiles/per-user/${USER:-$(id -un)}/etc/profile.d/bash_completion.sh" \
		"/run/current-system/sw/etc/profile.d/bash_completion.sh" \
		"/opt/homebrew/etc/profile.d/bash_completion.sh" \
		"/usr/local/etc/profile.d/bash_completion.sh" \
		"/usr/share/bash-completion/bash_completion" \
		"/etc/bash_completion" >/dev/null 2>&1 || true
	unset _bash_completion_root _bash_completion_file
fi
