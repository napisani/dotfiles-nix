#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../bash/rc.d/51-aliases-and-functions.sh
source "$script_dir/../bash/rc.d/51-aliases-and-functions.sh" 2>/dev/null
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir "$root/bin"
export PR_WRAPPER_LOG="$root/args"
cat >"$root/bin/workmux_pr.py" <<'COMMAND'
#!/usr/bin/env bash
printf '<%s>\n' "$@" >"$PR_WRAPPER_LOG"
exit "${PR_WRAPPER_EXIT:-0}"
COMMAND
chmod +x "$root/bin/workmux_pr.py"
export PATH="$root/bin:$PATH"
workmux-pr --purpose development 'argument with spaces'
printf '%s\n' '<--purpose>' '<development>' '<argument with spaces>' >"$root/expected"
cmp "$root/args" "$root/expected"
workmux-pr-review 12
printf '%s\n' '<--purpose>' '<review>' '<12>' >"$root/expected"
cmp "$root/args" "$root/expected"
status=0
PR_WRAPPER_EXIT=7 workmux-pr-review 12 || status=$?
[ "$status" -eq 7 ]
printf 'workmux-pr wrappers: passed\n'
