#!/usr/bin/env bash

export OLLAMA_API_BASE=http://127.0.0.1:11434 # Mac/Linux

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
	local model="qwen3:1.7b"
	local base="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
	local prompt="$instruction"

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
