#!/usr/bin/env bash

# allows tmux scrollbacks to work with claude
export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1

# ── Per-machine AI preferences ─────────────────────────────────────────────
# Add a new branch here when a machine needs different values.
if [ "${MACHINE_NAME:-}" = "nicks-loancrate-mbp" ]; then
	export PREFERRED_AGENT="${PREFERRED_AGENT:-claude}"
	export AI_PROVIDER="${AI_PROVIDER:-anthropic}"
	export AI_MODEL="${AI_MODEL:-claude-sonnet-4-6}"
	export AI_FAST_MODEL="${AI_FAST_MODEL:-claude-haiku-4-5}"
else
	export PREFERRED_AGENT="${PREFERRED_AGENT:-pi}"
	export AI_PROVIDER="${AI_PROVIDER:-anthropic}"
	export AI_MODEL="${AI_MODEL:-claude-sonnet-4-5}"
	export AI_FAST_MODEL="${AI_FAST_MODEL:-claude-haiku-4-5}"
fi

# Shared across all machines
export AI_LOCAL_BASE_URL="${AI_LOCAL_BASE_URL:-https://ollama.napisani.xyz/v1}"

# Native ollama API base — derived from AI_LOCAL_BASE_URL (strip /v1 suffix) when set,
# otherwise falls back to localhost. Set OLLAMA_API_BASE explicitly to override.
_ai_ollama_base="${AI_LOCAL_BASE_URL%/v1}"
export OLLAMA_API_BASE="${OLLAMA_API_BASE:-${_ai_ollama_base:-http://127.0.0.1:11434}}"
unset _ai_ollama_base

# Format a skill invocation for the current preferred agent.
# Usage: ai_skill <skill-name>
# pet: Print the configured agent syntax for a local skill
ai_skill() {
	local name="$1"
	case "${PREFERRED_AGENT:-pi}" in
	claude) printf '/%s' "$name" ;;
	codex) printf '$%s' "$name" ;;
	opencode) printf '/skill %s' "$name" ;;
	pi | *) printf '/skill:%s' "$name" ;;
	esac
}

# pet: Initialize the local Ollama model environment
ollama-init() {
	local model="${1:-${AI_LOCAL_MODEL:-}}"
	if [ -z "$model" ]; then
		echo "ollama-init: pass a model name or set AI_LOCAL_MODEL" >&2
		return 1
	fi
	echo "Pulling ollama model: $model"
	ollama pull "$model"
}

function _pi_completion() {
	if ! command -v pi >/dev/null 2>&1; then
		echo "_pi_completion: pi is required" >&2
		return 1
	fi

	local instruction="$1"
	local context="${2-}"
	local model="${3:-gpt-5.6-luna}"
	local prompt="$instruction"

	if [ -n "$context" ]; then
		prompt+=$'\n\nContext:\n'
		prompt+="$context"
	fi

	local response
	if ! response=$(pi \
		--model "$model" \
		--thinking low \
		--no-session \
		--no-tools \
		--no-extensions \
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

function _ollama_completion() {
	if ! command -v curl >/dev/null 2>&1; then
		echo "_ollama_completion: curl is required" >&2
		return 1
	fi

	if ! command -v jq >/dev/null 2>&1; then
		echo "_ollama_completion: jq is required" >&2
		return 1
	fi

	local instruction="$1"
	local context="${2-}"
	local model="${3:-${AI_LOCAL_MODEL:-}}"
	local base="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
	local prompt="$instruction"

	if [ -z "$model" ]; then
		echo "_ollama_completion: a model is required" >&2
		return 1
	fi

	if [ -n "$context" ]; then
		prompt+=$'\n\nContext:\n'
		prompt+="$context"
	fi

	local payload
	payload=$(
		jq -n \
			--arg model "$model" \
			--arg prompt "$prompt" \
			'{model: $model, prompt: $prompt, stream: false, options: {temperature: 0.2}}'
	)

	local response
	response=$(curl -sS \
		-H "Content-Type: application/json" \
		-d "$payload" \
		"$base/api/generate")

	if [ -z "$response" ]; then
		echo "_ollama_completion: empty response from ollama" >&2
		return 1
	fi

	printf '%s\n' "$response" | jq -r '.response // empty' | sed -e 's/[[:space:]]*$//'
}
