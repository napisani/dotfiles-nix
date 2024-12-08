#!/usr/bin/env bash

export OLLAMA_API_BASE=http://127.0.0.1:11434 # Mac/Linux

function hey_gpt() {
	prompt="$@"
	echo "Prompt: $prompt"
	gpt="$(
		curl -s https://api.openai.com/v1/chat/completions \
			-H "Content-Type: application/json" \
			-H "Authorization: Bearer $OPENAI_API_KEY" \
			-d "{ \
        \"model\": \"gpt-3.5-turbo\", \
        \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}], \
        \"temperature\": 0.7 \
    }"
	)"
	echo "$gpt" | jq -r '.choices[0].message.content'
}

function data_gpt() {
	prompt="$1:\n\n$(sed -e 's/"/\\"/g' "$2" | tr '\n' ' ')"
	gpt="$(
		curl -s https://api.openai.com/v1/chat/completions \
			-H "Content-Type: application/json" \
			-H "Authorization: Bearer $OPENAI_API_KEY" \
			-d "{ \
        \"model\": \"gpt-3.5-turbo\", \
        \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}], \
        \"temperature\": 0.7 \
    }"
	)"
	echo "$gpt" | jq -r '.choices[0].message.content'
}

alias chatai="nvim -c 'GpChatNew'"
alias aichat="nvim -c 'GpChatNew'"
