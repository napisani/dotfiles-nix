#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
shopt -s expand_aliases
# Aliases expand only when the command line is parsed, so the check runs through eval.
# shellcheck source=../bash/rc.d/51-aliases-and-functions.sh
source "$script_dir/../bash/rc.d/51-aliases-and-functions.sh" 2>/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gh_calls="$tmp/gh-calls"
review_calls="$tmp/review-calls"
gh_output=$'12\n34\n56\n'

gh() {
	printf '%s\n' "$@" >>"$gh_calls"
	printf '%s' "$gh_output"
}

workmux-pr-review() {
	printf '%s\n' "$#" "$@" >"$review_calls"
}

# Sourcing alone must not query GitHub.
[ ! -e "$gh_calls" ]

eval 'workmux-pr-review-all'
expected_gh=$'pr\nlist\n--search\nis:pr state:open user-review-requested:@me\n--limit\n1000\n--json\nnumber\n--jq\n.[].number'
[ "$(cat "$gh_calls")" = "$expected_gh" ]
[ "$(paste -sd, "$review_calls")" = '3,12,34,56' ]

# A later invocation re-queries instead of reusing the alias definition's output.
rm "$gh_calls"
gh_output=$'78\n'
eval 'workmux-pr-review-all'
[ "$(paste -sd, "$review_calls")" = '1,78' ]
[ -e "$gh_calls" ]

# No matching PRs yields zero arguments, so workmux-pr-review prints its usage error.
gh_output=''
eval 'workmux-pr-review-all'
[ "$(cat "$review_calls")" = 0 ]
