#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../bash/rc.d/51-aliases-and-functions.sh
source "$script_dir/../bash/rc.d/51-aliases-and-functions.sh" 2>/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
calls="$tmp/calls"
fail_prs=' '

ai_skill() { printf '/skill:%s' "$1"; }

# Stands in for the real workmux; fails for any --pr value listed in $fail_prs.
workmux() {
	local pr="$4"
	printf '%s|%s|%s|%s|%s|%s\n' "$@" >>"$calls"
	case "$fail_prs" in *" $pr "*) echo "workmux: cannot check out PR '$pr'" >&2; return 3 ;; esac
}

status=0
stderr=
# Run as a plain statement (not in `||` or `if`) so the subshell's errexit stays live.
run() {
	: >"$calls"
	set +e
	(
		set "$1"
		shift
		workmux-pr-review "$@"
	) 2>"$tmp/stderr"
	status=$?
	set -e
	stderr=$(cat "$tmp/stderr")
}

attempted() { cut -d'|' -f2 "$calls" | paste -sd' ' -; }
fail() { echo "workmux-pr-review.sh: $*" >&2; exit 1; }
expect_attempts() { [ "$(attempted)" = "$1" ] || fail "attempted [$(attempted)], want [$1]"; }
expect_status() { [ "$status" -eq "$2" ] || fail "$1: exit $status, want $2"; }
expect_stderr() { case "$stderr" in *"$1"*) ;; *) fail "stderr lacks '$1': $stderr" ;; esac; }

# The argument shape workmux receives must not change.
expected_call='add|review_12|--pr|12|--prompt|/skill:multi-valued-review on the changes made in this pr: 12'
for flags in +e -e -eu; do
	fail_prs=' '
	run $flags 12
	expect_status "single success ($flags)" 0
	[ "$(head -n1 "$calls")" = "$expected_call" ] || fail "call was $(head -n1 "$calls")"

	run $flags 12 34 56
	expect_status "all success ($flags)" 0
	expect_attempts 'review_12 review_34 review_56'

	fail_prs=' 12 '
	run $flags 12 34
	expect_status "failure then success ($flags)" 1
	expect_attempts 'review_12 review_34'
	expect_stderr "failed to open review for '12'"

	fail_prs=' 34 '
	run $flags 12 34
	expect_status "success then failure ($flags)" 1
	expect_attempts 'review_12 review_34'
	expect_stderr "failed to open review for '34'"

	fail_prs=' 34 '
	run $flags 12 34 56
	expect_status "middle failure ($flags)" 1
	expect_attempts 'review_12 review_34 review_56'
	expect_stderr "1 of 3 review window(s) failed to create"

	fail_prs=' 12 56 '
	run $flags 12 34 56
	expect_status "two failures around a success ($flags)" 1
	expect_attempts 'review_12 review_34 review_56'
	expect_stderr "failed to open review for '12'"
	expect_stderr "failed to open review for '56'"
	expect_stderr "2 of 3 review window(s) failed to create"

	# Invalid arguments reach workmux, which rejects them; valid ones still open.
	fail_prs=' abc  -5 '
	run $flags abc '' -5 34
	expect_status "invalid arguments ($flags)" 1
	expect_attempts 'review_abc review_ review_-5 review_34'
	expect_stderr "failed to open review for 'abc'"
	expect_stderr "failed to open review for ''"
	expect_stderr "failed to open review for '-5'"
	expect_stderr "3 of 4 review window(s) failed to create"
done

# No arguments: usage error, nothing attempted.
run +e
expect_status 'no arguments' 1
expect_attempts ''
expect_stderr 'Usage: workmux-pr-review <pr-number> [pr-number...]'
