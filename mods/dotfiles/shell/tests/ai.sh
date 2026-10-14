#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../bash/rc.d/45-ai.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
calls="$tmp/calls"
pi_status=0
pi_response='commit subject'
pi() {
	printf '%s\n' "$@" >"$calls"
	printf '%s\n' "$pi_response"
	return "$pi_status"
}

[ "$(_pi_completion 'Write a subject' 'staged diff')" = 'commit subject' ]
! grep -qx -- '--model' "$calls"
! grep -qx -- '--no-extensions' "$calls"
for flag in --no-tools --no-mcp --no-session --no-context-files; do
	grep -qx -- "$flag" "$calls"
done
grep -qx 'staged diff' "$calls"

_pi_completion 'Write a subject' '' 'openai-codex/gpt-5.6-luna' >/dev/null
grep -A1 -x -- '--model' "$calls" | grep -qx 'openai-codex/gpt-5.6-luna'

pi_status=42
if _pi_completion 'Write a subject' >"$tmp/stdout" 2>"$tmp/stderr"; then
	echo 'ai.sh: failed Pi request returned success' >&2
	exit 1
fi
grep -q 'pi request failed' "$tmp/stderr"

pi_status=0
pi_response=''
if _pi_completion 'Write a subject' >"$tmp/stdout" 2>"$tmp/stderr"; then
	echo 'ai.sh: empty Pi response returned success' >&2
	exit 1
fi
grep -q 'empty response from pi' "$tmp/stderr"

printf 'ai.sh: all checks passed\n'
