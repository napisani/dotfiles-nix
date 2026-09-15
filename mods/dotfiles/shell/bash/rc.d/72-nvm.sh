export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# NPM_CONFIG_PREFIX is incompatible with nvm and must be absent before nvm.sh
# initializes, not removed afterward.
unset NPM_CONFIG_PREFIX

# When nvm's default is "system", --no-use loads its functions without spending
# hundreds of milliseconds resolving and selecting the Node already on PATH.
# Keep normal nvm initialization for hosts with any other default so their
# configured version still wins. Probe the standard manual install plus
# Homebrew prefixes.
_nvm_script=
for _nvm_candidate in \
	"$NVM_DIR/nvm.sh" \
	"/opt/homebrew/opt/nvm/nvm.sh" \
	"/usr/local/opt/nvm/nvm.sh" \
	"/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh"; do
	if [ -r "$_nvm_candidate" ]; then
		_nvm_script=$_nvm_candidate
		break
	fi
done
unset _nvm_candidate
[ -n "$_nvm_script" ] || return 0
# shellcheck disable=SC1090
if [ -r "$NVM_DIR/alias/default" ] && [ "$(<"$NVM_DIR/alias/default")" = system ]; then
	source -- "$_nvm_script" --no-use >/dev/null 2>&1
else
	source -- "$_nvm_script" >/dev/null 2>&1
fi || {
	unset _nvm_script
	return 0
}
unset _nvm_script

sh_source_first \
	"$NVM_DIR/bash_completion" \
	"/opt/homebrew/opt/nvm/bash_completion" \
	"/usr/local/opt/nvm/bash_completion" \
	"/home/linuxbrew/.linuxbrew/opt/nvm/bash_completion" >/dev/null 2>&1 || true

# Auto-switch Node versions only when a directory is covered by an .nvmrc.
# Remember its path so moving within the same project is free. When leaving an
# nvm-managed project, restore the configured default once. This preserves the
# prior cdnvm behavior without paying for nvm's subprocess-style queries when a
# shell starts outside an nvm-managed project.
_nvm_auto_use() {
	local nvm_path nvmrc nvm_version locally_resolved_nvm_version
	nvm_path=$(nvm_find_up .nvmrc | command tr -d '\n')

	if [[ ! $nvm_path = *[^[:space:]]* ]]; then
		if [ "${_NVM_AUTO_USE_ACTIVE:-0}" = 1 ]; then
			nvm use --silent default || return
			_NVM_AUTO_USE_ACTIVE=0
			_NVM_AUTO_USE_RC=
		fi
		return 0
	fi

	nvmrc="$nvm_path/.nvmrc"
	[ "$nvmrc" = "${_NVM_AUTO_USE_RC:-}" ] && return 0
	[ -s "$nvmrc" ] && [ -r "$nvmrc" ] || return 0
	nvm_version=$(<"$nvmrc")

	locally_resolved_nvm_version=$(nvm ls --no-colors "$nvm_version" | command tail -1 | command tr -d '\->*' | command tr -d '[:space:]')
	if [ "$locally_resolved_nvm_version" = N/A ]; then
		nvm install "$nvm_version"
	elif [ "$(nvm current)" != "$locally_resolved_nvm_version" ]; then
		nvm use --silent "$nvm_version"
	fi
	_NVM_AUTO_USE_ACTIVE=1
	_NVM_AUTO_USE_RC="$nvmrc"
}

cdnvm() {
	command cd "$@" || return $?
	_nvm_auto_use
}

alias cd='cdnvm'
_nvm_auto_use || true
