export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# NPM_CONFIG_PREFIX is incompatible with nvm and must be absent before nvm.sh
# initializes, not removed afterward.
unset NPM_CONFIG_PREFIX

# The nvm docs source nvm.sh and then bash_completion. Probe the standard manual
# install plus Homebrew prefixes; no package-manager-specific generated code is
# needed.
sh_source_first \
	"$NVM_DIR/nvm.sh" \
	"/opt/homebrew/opt/nvm/nvm.sh" \
	"/usr/local/opt/nvm/nvm.sh" \
	"/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" >/dev/null 2>&1 || return 0

sh_source_first \
	"$NVM_DIR/bash_completion" \
	"/opt/homebrew/opt/nvm/bash_completion" \
	"/usr/local/opt/nvm/bash_completion" \
	"/home/linuxbrew/.linuxbrew/opt/nvm/bash_completion" >/dev/null 2>&1 || true

# Auto-switch node version on directory change — official cdnvm pattern from
# nvm README. Aliases `cd` so it fires only on actual directory changes (unlike
# PROMPT_COMMAND which fires after every command). Handles lts/*, version
# aliases, auto-install, and fallback to nvm default when leaving a project.
if command -v nvm >/dev/null 2>&1; then
    cdnvm() {
        command cd "$@" || return $?
        local nvm_path
        nvm_path="$(nvm_find_up .nvmrc | command tr -d '\n')"

        if [[ ! $nvm_path = *[^[:space:]]* ]]; then
            local default_version
            default_version="$(nvm version default)"
            if [ "$default_version" = 'N/A' ]; then
                nvm alias default node
                default_version=$(nvm version default)
            fi
            if [ "$(nvm current)" != "${default_version}" ]; then
                nvm use default
            fi
        elif [[ -s "${nvm_path}/.nvmrc" && -r "${nvm_path}/.nvmrc" ]]; then
            local nvm_version
            nvm_version=$(<"${nvm_path}"/.nvmrc)
            local locally_resolved_nvm_version
            locally_resolved_nvm_version=$(nvm ls --no-colors "${nvm_version}" | command tail -1 | command tr -d '\->*' | command tr -d '[:space:]')
            if [ "${locally_resolved_nvm_version}" = 'N/A' ]; then
                nvm install "${nvm_version}"
            elif [ "$(nvm current)" != "${locally_resolved_nvm_version}" ]; then
                nvm use "${nvm_version}"
            fi
        fi
    }
    alias cd='cdnvm'
    cdnvm "$PWD" || true
fi
