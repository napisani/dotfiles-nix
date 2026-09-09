#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
subject="$script_dir/../omniwm-workspace-move-adjacent.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/omniwm-adjacent-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/omniwmctl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == "query workspaces --format json --fields number,is-current" ]]; then
	cat <<'JSON'
{
  "id": "fixture-query",
  "kind": "query",
  "ok": true,
  "result": {
    "kind": "workspaces",
    "payload": {
      "workspaces": [
        { "isCurrent": true, "number": 1 },
        { "isCurrent": false, "number": 2 },
        { "isCurrent": false, "number": 7 }
      ]
    }
  },
  "status": "success",
  "version": 15
}
JSON
elif [[ "$1 $2" == "command move-to-workspace" ]]; then
	printf '%s\n' "$3" >>"$OMNIWM_TEST_LOG"
else
	echo "unexpected omniwmctl invocation: $*" >&2
	exit 1
fi
STUB
chmod +x "$tmp/omniwmctl"

export OMNIWMCTL="$tmp/omniwmctl"
export OMNIWM_TEST_LOG="$tmp/moves"

"$subject" next
"$subject" prev

expected=$'2\n7'
actual="$(cat "$OMNIWM_TEST_LOG")"
if [[ "$actual" != "$expected" ]]; then
	echo "expected adjacent workspace targets 2 and 7, got:" >&2
	printf '%s\n' "$actual" >&2
	exit 1
fi

echo "omniwm adjacent workspace movement: ok"
