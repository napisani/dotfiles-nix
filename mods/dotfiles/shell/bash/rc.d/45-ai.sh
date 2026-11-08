#!/usr/bin/env bash

# allows tmux scrollbacks to work with claude
export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1

# Pi is the default agent everywhere; callers can still override it before
# shell initialization. Provider and model preferences remain machine-specific.
export PREFERRED_AGENT="${PREFERRED_AGENT:-pi}"

# ── Per-machine AI preferences ─────────────────────────────────────────────
# Add a new branch here when a machine needs different values.
if [ "${MACHINE_NAME:-}" = "nicks-loancrate-mbp" ]; then
	export AI_PROVIDER="${AI_PROVIDER:-anthropic}"
	export AI_MODEL="${AI_MODEL:-claude-sonnet-4-6}"
	export AI_FAST_MODEL="${AI_FAST_MODEL:-claude-haiku-4-5}"
else
	export AI_PROVIDER="${AI_PROVIDER:-anthropic}"
	export AI_MODEL="${AI_MODEL:-claude-sonnet-4-5}"
	export AI_FAST_MODEL="${AI_FAST_MODEL:-claude-haiku-4-5}"
fi

# Format a skill invocation for the current preferred agent.
# Usage: ai_skill <skill-name>
# pet: Print the configured agent syntax for a local skill
ai_skill() {
	local name="$1"
	case "${PREFERRED_AGENT:-pi}" in
	claude) printf '/%s' "$name" ;;
	codex) printf '$%s' "$name" ;;
	pi | *) printf '/skill:%s' "$name" ;;
	esac
}

function _pi_completion() {
	if ! command -v pi >/dev/null 2>&1; then
		echo "_pi_completion: pi is required" >&2
		return 1
	fi

	local instruction="$1"
	local context="${2-}"
	local -a model_args=()
	if [ -n "${3-}" ]; then
		model_args=(--model "$3")
	fi
	local prompt="$instruction"

	if [ -n "$context" ]; then
		prompt+=$'\n\nContext:\n'
		prompt+="$context"
	fi

	local response
	if ! response=$(pi \
		"${model_args[@]}" \
		--thinking low \
		--no-session \
		--no-tools \
		--no-mcp \
		--no-skills \
		--no-context-files \
		--no-themes \
		--print \
		"$prompt"); then
		echo "_pi_completion: pi request failed" >&2
		return 1
	fi

	if [ -z "$response" ]; then
		echo "_pi_completion: empty response from pi" >&2
		return 1
	fi

	printf '%s\n' "$response" | sed -e 's/[[:space:]]*$//'
}
