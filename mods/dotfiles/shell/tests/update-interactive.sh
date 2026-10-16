#!/usr/bin/env bash
# Regression tests for update-interactive. Every action boundary (git, the
# dependency CLI, native updaters, rebuild, garbage collection) is a fixture, so
# nothing here updates, pulls, switches, or deletes anything real.
#
# The suite re-runs itself under each available Bash (the current one and
# /bin/bash, which is 3.2 on macOS) so compatibility is exercised, not assumed.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${UPDATE_INTERACTIVE_TEST_SHELL:-}" ]; then
	seen=''
	for candidate in "$BASH" /bin/bash $(type -ap bash); do
		[ -x "$candidate" ] || continue
		# shellcheck disable=SC2016 # The child shell expands the variable.
		version=$("$candidate" -c 'echo "$BASH_VERSION"')
		case "$seen" in *"|$version|"*) continue ;; esac
		seen="$seen|$version|"
		printf '==> update-interactive tests under %s (bash %s)\n' "$candidate" "$version"
		UPDATE_INTERACTIVE_TEST_SHELL="$candidate" "$candidate" "${BASH_SOURCE[0]}"
	done
	exit 0
fi

command -v jq >/dev/null || {
	echo 'update-interactive tests need jq (domain discovery parses JSON)' >&2
	exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export CALL_LOG="$tmp/calls"
repo="$tmp/monorepo with spaces"
export DOTFILES_HOME_MANAGER_DIR="$repo/pub/dotfiles-nix"
mkdir -p "$DOTFILES_HOME_MANAGER_DIR" "$repo/scripts" "$tmp/elsewhere"

# Domains span projects. Only rows under pub/dotfiles-nix belong to the project
# that sys-update pins is scoped to; the rest must never be offered.
cat >"$tmp/list.json" <<'LIST'
[
  {"domain": "pi", "mechanism": "annotated-pins", "item": "p", "location": "pub/dotfiles-nix/mods/agents/default.nix"},
  {"domain": "app:proctmux", "mechanism": "flake-inputs", "item": "a", "location": "pub/proctmux"},
  {"domain": "skills", "mechanism": "flake-inputs", "item": "s", "location": "priv/kube-home-lab"},
  {"domain": "skills", "mechanism": "flake-inputs", "item": "s", "location": "pub/dotfiles-nix"},
  {"domain": "new-domain", "mechanism": "annotated-pins", "item": "n", "location": "pub/dotfiles-nix/mods/new.nix"},
  {"domain": "nix-core", "mechanism": "flake-inputs", "item": "n", "location": "."},
  {"domain": "nix-core", "mechanism": "flake-inputs", "item": "n", "location": "pub/dotfiles-nix"},
  {"domain": "homelab-images", "mechanism": "annotated-pins", "item": "h", "location": "priv/kube-home-lab/src/x.ts"},
  {"domain": "decoy-prefix", "mechanism": "annotated-pins", "item": "d", "location": "pub/dotfiles-nixish/x.nix"},
  {"domain": "npm-tools", "mechanism": "annotated-pins", "item": "t", "location": "pub/dotfiles-nix/mods/native-tools.nix"},
  {"domain": "flake-tools", "mechanism": "flake-inputs", "item": "f", "location": "pub/dotfiles-nix"},
  {"domain": "github-actions", "mechanism": "annotated-pins", "item": "g", "location": ".github/workflows/a.yml"}
]
LIST
export LIST_JSON="$tmp/list.json"
cat >"$repo/scripts/deps.ts" <<'DEPS'
#!/usr/bin/env bash
printf 'deps cwd=%s' "$PWD" >> "$CALL_LOG"
printf ' %s' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
case "$1" in
list)
	[ "${LIST_STATUS:-0}" -eq 0 ] || exit "$LIST_STATUS"
	cat "$LIST_JSON"
	exit 0
	;;
check) exit "${CHECK_STATUS:-0}" ;;
update)
	[ "$4" != "${FAIL_DOMAIN:-}" ] || exit "${FAIL_STATUS:-2}"
	exit 0
	;;
esac
DEPS
chmod +x "$repo/scripts/deps.ts"

# Fixture commands are shell functions so the sourced fragments call them
# exactly as they would call the real tools.
cat >"$tmp/harness.sh" <<'HARNESS'
eval "${HARNESS_OPTS:-:}"
script_dir=$1
state=$2
shift 2
source "$script_dir/../bash/lib/guards.sh"
source "$script_dir/../bash/rc.d/55-nix-aliases.sh"
source "$script_dir/../bash/rc.d/56-update-functions.sh"

record() { printf '%s\n' "$*" >>"$CALL_LOG"; }
sh_have() {
	case " ${AVAILABLE:-darwin-rebuild brew nvim global-tools jq git} " in
	*" $1 "*) return 0 ;;
	*) return 1 ;;
	esac
}
# jq is a real dependency of the function under test, not an action boundary.
jq() { command jq "$@"; }
sudo() {
	record sudo "$@"
	"$@"
}
darwin-rebuild() {
	record darwin-rebuild "$@"
	record "cwd=$PWD"
	return "${SWITCH_STATUS:-0}"
}
nixos-rebuild() { record nixos-rebuild "$@"; }
hostname() { printf 'test-host\n'; }
brew() {
	record brew "$@"
	if [ "${BREW_INTERRUPT:-0}" = 1 ]; then kill -INT "$$"; fi
	[ "$1" != "${BREW_FAIL:-}" ] || return 42
}
nvim() {
	record nvim "$@"
	return "${NVIM_STATUS:-0}"
}
global-tools() {
	record global-tools "$@"
	return "${CLAUDE_STATUS:-0}"
}
nix() { record nix "$@"; }
nix-collect-garbage() {
	record nix-collect-garbage "$@"
	return "${GC_STATUS:-0}"
}
git() {
	record git "$@"
	local args=("$@")
	[ "${args[0]}" != --no-pager ] || args=("${args[@]:1}")
	if [ "${args[0]}" = -C ]; then args=("${args[@]:2}"); fi
	while [ "${args[0]:-}" = -c ]; do args=("${args[@]:2}"); done
	case "${args[0]}" in
	rev-parse)
		case "${args[*]}" in
		*'--show-toplevel'*) printf '%s\n' "$REPO_TOP" ;;
		*'@{u'*) [ "${NO_UPSTREAM:-0}" = 0 ] || return 128; printf 'origin/main\n' ;;
		*HEAD*) printf 'main\n' ;;
		esac
		;;
	pull) return "${PULL_STATUS:-0}" ;;
	status) printf ' M pub/dotfiles-nix/flake.lock\n M mods/dotfiles/nvim/lazy-lock.json\n?? untracked-notes.txt\n' ;;
	diff)
		case "${args[*]}" in
		*--stat*) printf ' pub/dotfiles-nix/flake.lock | 4 ++--\n' ;;
		*) printf '@@ -1 +1 @@\n-old-skill-rev\n+new-skill-rev\n' ;;
		esac
		;;
	esac
}
export REPO_TOP

snapshot() { { set +o; trap -p; shopt -p; printf 'IFS=%s\nPWD=%s\n' "$(printf '%s' "$IFS" | od -An -c)" "$PWD"; } >"$1" 2>&1; }
cd "$HARNESS_CWD"
trap 'snapshot "$state.after"; if cmp -s "$state.before" "$state.after"; then echo same >"$state"; else { echo changed; diff "$state.before" "$state.after"; } >"$state"; fi' EXIT
snapshot "$state.before"
update-interactive "$@"
HARNESS

shell_under_test=$UPDATE_INTERACTIVE_TEST_SHELL
unset BREW_INTERRUPT

# run ANSWERS [VAR=value...]: feeds ANSWERS (printf %b) to the wizard.
run() {
	local answers="$1"
	shift
	: >"$CALL_LOG"
	status=0
	# shellcheck disable=SC2086 # ARGS is a deliberate word list.
	printf '%b' "$answers" |
		env "$@" REPO_TOP="$repo" HARNESS_CWD="$tmp/elsewhere" \
			"$shell_under_test" "$tmp/harness.sh" "$script_dir" "$tmp/state" ${ARGS:-} \
			>"$tmp/out" 2>"$tmp/err" || status=$?
}
fail() {
	printf 'FAIL: %s\n--- calls ---\n%s\n--- stdout ---\n' "$1" "$(<"$CALL_LOG")" >&2
	cat "$tmp/out" >&2
	printf -- '--- stderr ---\n' >&2
	cat "$tmp/err" >&2
	exit 1
}
expect_status() { [ "$status" -eq "$1" ] || fail "expected exit $1, got $status"; }
expect_calls() {
	local actual
	actual=$(<"$CALL_LOG")
	[ "$actual" = "$1" ] || {
		printf 'Expected calls:\n%s\nActual calls:\n%s\n' "$1" "$actual" >&2
		fail "$2"
	}
}
expect_text() { grep -Fq -- "$1" "$tmp/out" "$tmp/err" 2>/dev/null || fail "missing text: $1"; }
reject_text() { ! grep -Fq -- "$1" "$tmp/out" "$tmp/err" || fail "unexpected text: $1"; }
expect_prompts() {
	local n
	n=$({ grep -o '\[y/N\]' "$tmp/err" || true; } | wc -l | tr -d ' ')
	[ "$n" -eq "$1" ] || fail "expected $1 prompts, saw $n"
}
expect_call() { grep -Fxq -- "$1" "$CALL_LOG" || fail "missing call: $1"; }
reject_call() { ! grep -Eq -- "$1" "$CALL_LOG" || fail "unexpected call matching: $1"; }
expect_clean_shell() { [ "$(head -1 "$tmp/state")" = same ] || fail "caller state changed: $(cat "$tmp/state")"; }
no_destructive_git() {
	reject_call '^git .* (add|commit|stash|reset|restore|clean|checkout|push)( |$)'
	reject_call '^git .*(--force|--hard|--autostash|--rebase)'
	reject_call '^git (--no-pager )?pull$'
	reject_call 'allow major'
}

# Escape text for printf %b, since command substitution strips raw newlines.
yes_all=$(printf 'y\\n%.0s' {1..40})
no_all=$(printf '\\n%.0s' {1..40})
dot=$DOTFILES_HOME_MANAGER_DIR
sw_line='sudo darwin-rebuild switch --show-trace --no-update-lock-file --flake .#'
sw="$sw_line
darwin-rebuild switch --show-trace --no-update-lock-file --flake .#
cwd=$dot"
check="deps cwd=$repo check --project dotfiles-nix"
pre="git -C $dot rev-parse --abbrev-ref HEAD
git -C $dot rev-parse --abbrev-ref @{u}"
pull="git -C $dot -c pull.rebase=false pull --ff-only --no-autostash"
list="deps cwd=$repo list --json"
update="deps cwd=$repo update --project dotfiles-nix"
pins="$update nix-core
$update flake-tools
$update skills
$update npm-tools
$update pi
$update new-domain"
review="git --no-pager -C $dot rev-parse --show-toplevel
git --no-pager -C $repo status --short
git --no-pager -C $repo diff --stat HEAD
git --no-pager -C $repo diff --no-ext-diff HEAD"
tools="brew update
brew upgrade
brew cleanup
nvim --headless +Lazy! sync +qa
global-tools update claude-plugins"
clean="nix-collect-garbage -d
nix store optimise
sudo nix-collect-garbage -d
nix-collect-garbage -d"
# Stage prompts: pull, check, six pin domains, review, activate, three tools,
# cleanup.
prompts=14
head_calls="$pre
$pull
$list
$check
$pins
$review"

ARGS=--help run ''
expect_status 0
expect_calls '' 'help makes no calls'
expect_text 'nixswitch'
expect_prompts 0
ARGS=bogus run ''
expect_status 2
expect_calls '' 'bad arguments make no calls'
ARGS='help extra' run ''
expect_status 2
ARGS=

# Default Enter declines everything; only read-only discovery runs.
run "$no_all"
expect_status 0
expect_calls "$pre
$list" 'all-no runs no action'
expect_prompts "$prompts"
expect_clean_shell
no_destructive_git

# Each stage describes its impact before its own prompt. Streams are merged
# because descriptions go to stdout and prompts to stderr.
run_merged() {
	: >"$CALL_LOG"
	status=0
	printf '%b' "$no_all" |
		env REPO_TOP="$repo" HARNESS_CWD="$tmp/elsewhere" \
			"$shell_under_test" "$tmp/harness.sh" "$script_dir" "$tmp/state" \
			>"$tmp/merged" 2>&1 || status=$?
}
# expect_described HEADING TEXT: TEXT is printed after the "==> HEADING" line
# and before that block's prompt.
expect_described() {
	awk -v heading="==> $1" -v text="$2" '
		/^==> / { block = $0; body = ""; next }
		/\[y\/N\]/ {
			if (block == heading && index(body, text)) found = 1
			block = ""
			next
		}
		{ body = body "\n" $0 }
		END { exit !found }
	' "$tmp/merged" || {
		cat "$tmp/merged" >&2
		fail "no '$2' between '$1' and its prompt"
	}
}
# reject_described HEADING TEXT: TEXT must not appear in HEADING's block.
reject_described() {
	if awk -v heading="==> $1" -v text="$2" '
		/^==> / { block = $0; body = ""; next }
		/\[y\/N\]/ {
			if (block == heading && index(body, text)) found = 1
			block = ""
			next
		}
		{ body = body "\n" $0 }
		END { exit !found }
	' "$tmp/merged"; then
		fail "'$2' must not describe '$1'"
	fi
}

run_merged
[ "$status" -eq 0 ] || fail 'merged all-no run failed'
expect_described 'Pull configuration' 'without rebuilding Nix'
expect_described 'Pull configuration' 'Live-linked shell and editor files'
expect_described 'Check pins (read-only)' 'changes no pin and installs nothing'
expect_described 'Update pins: nix-core' 'nixpkgs, home-manager, nix-darwin'
expect_described 'Update pins: flake-tools' 'from their own source repositories'
expect_described 'Update pins: skills' 'instructions your coding agents follow'
expect_described 'Update pins: skills' 'read the diff first'
expect_described 'Update pins: npm-tools' 'global npm command-line tools'
expect_described 'Update pins: npm-tools' 'not Pi extensions or Claude plugins'
expect_described 'Update pins: npm-tools' 'majors and any held packages stay held'
expect_described 'Update pins: pi' 'held packages stay held'
expect_described 'Update pins: pi' 'Pi extension packages'
expect_described 'Update pins: pi' 'read the diff first'
expect_described 'Update pins: new-domain' 'in the new-domain domain'
for domain in nix-core flake-tools skills npm-tools pi; do
	expect_described "Update pins: $domain" 'nothing is installed until you activate'
	expect_described "Update pins: $domain" "update --project dotfiles-nix $domain"
done
# Domain descriptions are distinct, not one text repeated.
reject_described 'Update pins: nix-core' 'agent skill repositories'
reject_described 'Update pins: skills' 'nixpkgs'
reject_described 'Update pins: npm-tools' 'extension packages in'
reject_described 'Update pins: pi' 'global npm command-line tools'
reject_described 'Update pins: new-domain' 'nixpkgs'
expect_described 'Review changes (read-only)' 'including edits you made before this run'
expect_described 'Review changes (read-only)' 'stages, commits and applies nothing'
expect_described 'Review changes (read-only)' 'skills and Pi packages'
expect_described 'Activate configuration' 'earlier pin changes take effect here'
expect_described 'Activate configuration' 'does not restart your editors or agent sessions'
expect_described 'Native tool: brew' 'casks (GUI apps)'
expect_described 'Native tool: brew' '--greedy is not used'
expect_described 'Native tool: nvim' 'lazy-lock.json'
expect_described 'Native tool: nvim' 'may load newer files later'
expect_described 'Native tool: claude' 'does not update the Claude CLI itself'
expect_described 'Native tool: claude' 'plugin reload or restart'
expect_described 'Cleanup (not an update)' 'no longer roll back'
expect_described 'Cleanup (not an update)' 'DELETES every old Nix generation'

# Every action, in the documented order, each exactly once. This also proves
# neither sys-update tools nor nixswitchup runs alongside its components.
run "$yes_all"
expect_status 0
expect_calls "$head_calls
$sw
$tools
$clean" 'full run'
expect_prompts "$prompts"
expect_clean_shell
no_destructive_git
reject_text 'app:proctmux'
reject_text 'homelab-images'
reject_text 'decoy-prefix'
reject_text 'github-actions'
expect_text 'not nixswitchup'
for opts in 'set -e' 'set -euo pipefail'; do
	run "$yes_all" HARNESS_OPTS="$opts"
	expect_status 0
	expect_calls "$head_calls
$sw
$tools
$clean" "full run ($opts)"
	expect_clean_shell
done

# Answer parsing: y/yes/n/no in any case and padding; junk reprompts.
run 'maybe\n  YeS  \nNo\nn\nNO\n\n\n\n\n\n\n\n\n\n\n\n'
expect_status 0
expect_calls "$pre
$pull
$list" 'only the pull was accepted'
[ "$(grep -c 'Please answer' "$tmp/err")" -eq 1 ] || fail 'invalid answer must reprompt once'
expect_prompts "$((prompts + 1))"

# Check exiting 1 means "updates available", not failure.
run "$yes_all" CHECK_STATUS=1
expect_status 0
expect_text 'not an error'
run "$yes_all" CHECK_STATUS=3
expect_status 1
expect_text 'Check pins (read-only): exit 3'

# End of input aborts without consenting to anything further.
run 'y'
expect_status 130
expect_calls "$pre" 'a partial answer at EOF is not consent'
expect_text 'input ended'
expect_clean_shell
run 'y\ny\n'
expect_status 130
expect_calls "$pre
$pull
$list
$check" 'EOF at the first pin prompt stops pins'
expect_prompts 3
run 'n\nn\ny\n'
expect_status 130
expect_calls "$pre
$list
$update nix-core" 'EOF mid pins stops pins'
run 'y\ny\ny\ny\n' FAIL_DOMAIN=flake-tools
expect_status 130
expect_text 'flake-tools: exit 2'
expect_text 'input ended'

# Interrupt kills the run; nothing after the interrupted action executes.
run "$yes_all" BREW_INTERRUPT=1
expect_status 130
expect_calls "$head_calls
$sw
brew update" 'interrupt'

# Failure continuation under errexit callers, with a nonzero aggregate.
for opts in 'set -e' 'set -euo pipefail'; do
	run "$yes_all" HARNESS_OPTS="$opts" FAIL_DOMAIN=skills FAIL_STATUS=2 BREW_FAIL=upgrade NVIM_STATUS=46
	expect_status 1
	expect_calls "$head_calls
brew update
brew upgrade
nvim --headless +Lazy! sync +qa
global-tools update claude-plugins
$clean" "continues after failures ($opts)"
	expect_text 'Update pins: skills: exit 2'
	expect_text 'Native tool: brew: exit 42'
	expect_text 'Native tool: nvim: exit 46'
	expect_text 'Skipping activation'
	reject_call 'darwin-rebuild'
	expect_clean_shell
	no_destructive_git
done
# A later success cannot mask an earlier failure.
run "$yes_all" HARNESS_OPTS='set -e' FAIL_DOMAIN=nix-core
expect_status 1
# A failed activation keeps rollback generations and still runs the tools.
run "$yes_all" SWITCH_STATUS=43
expect_status 1
expect_text 'Activate configuration: exit 43'
expect_text 'Skipping cleanup'
reject_call 'nix-collect-garbage'
expect_call 'global-tools update claude-plugins'

# Failed pull: pin updates (stale checkout) and activation are skipped.
run "$yes_all" PULL_STATUS=44
expect_status 1
expect_calls "$pre
$pull
$list
$check
$review
$tools
$clean" 'failed pull gates pins and activation'
expect_text 'Pull configuration: exit 44'
expect_text 'Skipping pin updates'
expect_text 'Skipping activation'

# Pin discovery trouble: unavailable skips, a broken CLI is a failure.
chmod -x "$repo/scripts/deps.ts"
run "$yes_all"
expect_status 0
expect_text 'unavailable'
expect_call "$sw_line"
reject_call 'update --project'
chmod +x "$repo/scripts/deps.ts"
run "$yes_all" LIST_STATUS=3
expect_status 1
expect_text 'pin domain discovery'
reject_call 'update --project'
reject_call 'darwin-rebuild'

# Unavailable stages explain themselves and are never offered.
run "$yes_all" AVAILABLE='git jq'
expect_status 0
expect_text 'brew is not installed'
expect_text 'nvim is not installed'
expect_text 'global-tools is not installed'
expect_text 'neither darwin-rebuild nor nixos-rebuild'
reject_call '^(sudo darwin|brew|nvim|global-tools|nixos)'
run "$yes_all" NO_UPSTREAM=1
expect_status 0
expect_text 'no upstream'
reject_call 'pull --ff-only'

# NixOS hosts activate through nixos-rebuild, once.
run "$yes_all" AVAILABLE='nixos-rebuild brew nvim global-tools jq git'
expect_status 0
expect_call 'sudo nixos-rebuild --show-trace --no-update-lock-file --flake .#test-host switch --impure'

# Review surfaces the existing user edits and the skills/Pi reminder.
run "$yes_all"
expect_text 'lazy-lock.json'
expect_text 'skills and Pi packages'
# The tracked diff itself is shown (tracked edits only, against HEAD) and
# untracked contents are never read or staged.
expect_text '?? untracked-notes.txt'
expect_text '+new-skill-rev'
expect_text 'flake.lock | 4'
reject_call 'intent-to-add|--no-index|ls-files|git .* add '
reject_call ' diff( --stat)?$'

# Cleanup is labelled as deletion and sits last, separately opt-in.
run 'n\nn\nn\nn\nn\nn\nn\nn\nn\nn\nn\nn\nn\ny\n'
expect_status 0
expect_calls "$pre
$list
$clean" 'cleanup alone'
expect_text 'DELETES'
expect_text 'not an update'

printf 'update-interactive: ok\n'
