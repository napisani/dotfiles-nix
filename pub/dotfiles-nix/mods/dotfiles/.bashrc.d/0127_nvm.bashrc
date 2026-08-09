export NVM_DIR="$HOME/.nvm"
# Source nvm.sh: nixpkgs install → brew install → manual/curl install
if command -v nvm-exec >/dev/null 2>&1; then
    . "$(dirname "$(readlink -f "$(command -v nvm-exec)")")/nvm.sh" 2>/dev/null
elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    . "/opt/homebrew/opt/nvm/nvm.sh"
elif [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi

# Bash completion (recommended by nvm docs)
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# NPM_CONFIG_PREFIX (set globally by npmx.nix) is incompatible with nvm —
# nvm manages its own prefix per node version. Unset it so nvm can activate.
unset NPM_CONFIG_PREFIX

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
