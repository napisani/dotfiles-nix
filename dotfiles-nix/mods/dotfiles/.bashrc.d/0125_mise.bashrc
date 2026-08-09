if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"

    completion_file="$HOME/.local/share/bash-completion/completions/mise"
    if [[ ! -f "$completion_file" ]]; then
        mkdir -p "$(dirname "$completion_file")"
        mise completion bash --include-bash-completion-lib > "$completion_file"
    fi

    if [[ -r "$completion_file" ]]; then
        source "$completion_file"
    fi
fi
