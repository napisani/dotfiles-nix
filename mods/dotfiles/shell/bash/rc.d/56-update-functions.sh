# pet: Discover dependency and native-tool updates with sys-update help
sys-update() {
	local action="${1:-help}"
	[ $# -eq 0 ] || shift
	case "$action" in
	help | -h | --help | brew | nvim | claude | tools)
		if [ $# -ne 0 ]; then
			echo "sys-update $action: unexpected arguments; see sys-update help" >&2
			return 2
		fi
		;;
	esac

	case "$action" in
	help | -h | --help)
		cat <<'HELP'
Usage: sys-update <command> [arguments]

Dependency pins:
  list [--json]                 List all monorepo domains and their pins
  check [DOMAIN...] [options]    Check for newer versions without changing pins
  pins DOMAIN [ITEM...] [options]
                                Update one domain and verify the changed pins

Check and pins default to --project dotfiles-nix; override with --project NAME.
Arguments pass through to scripts/deps.ts. Pin updates support --allow,
--dry-run, and --no-verify; list and check support --json.
These commands require a monorepo checkout. They never activate Nix.

Native tools and plugin locks:
  brew                          Update, upgrade, and clean Homebrew packages
  nvim                          Sync Neovim plugins and rewrite lazy-lock.json
  claude                        Refresh Claude plugins through global-tools
  tools                         Run brew, nvim, and claude; report every failure

Activation and cleanup are separate:
  nixswitch                     Apply the current configuration
  nixswitchup                   Pull configuration changes, then apply them
  nixclean                      Delete old Nix generations and optimize the store

Example: sys-update pins nix-core, review the diff, then run nixswitch.
update-interactive walks through all of the above, one yes/no question each.
HELP
		;;
	list | check | pins)
		local dotfiles
		dotfiles=$(sh_dotfiles_dir)
		(
			cd -- "$dotfiles/../.." || return
			if [ ! -x scripts/deps.ts ]; then
				echo "sys-update $action: scripts/deps.ts is unavailable; use a monorepo checkout" >&2
				return 127
			fi
			case "$action" in
			list) ./scripts/deps.ts list "$@" ;;
			check) ./scripts/deps.ts check --project dotfiles-nix "$@" ;;
			pins) ./scripts/deps.ts update --project dotfiles-nix "$@" ;;
			esac
		)
		;;
	brew | nvim | claude)
		local tool="$action"
		[ "$action" != claude ] || tool=global-tools
		if ! sh_have "$tool"; then
			echo "sys-update $action: $tool is not installed; skipping" >&2
			return 0
		fi
		case "$action" in
		brew)
			echo '==> Updating Homebrew packages'
			brew update && brew upgrade && brew cleanup
			;;
		nvim)
			echo '==> Updating Neovim plugins'
			nvim --headless '+Lazy! sync' +qa
			;;
		claude)
			echo '==> Updating Claude plugins'
			global-tools update claude-plugins
			;;
		esac
		;;
	tools)
		local step failed=()
		# Independent tools should still update when another tool fails.
		for step in brew nvim claude; do
			sys-update "$step" || failed+=("$step")
		done
		if [ ${#failed[@]} -gt 0 ]; then
			printf '==> sys-update tools: failed: %s\n' "${failed[*]}" >&2
			return 1
		fi
		echo '==> sys-update tools: done'
		;;
	*)
		echo "sys-update: unknown command '$action'; see sys-update help" >&2
		return 2
		;;
	esac
}

# Ask one yes/no question. Returns 0 for yes, 1 for no (Enter included), and
# 2 when input ends, which must never count as consent.
sh_update_confirm() {
	local reply
	while :; do
		printf '%s [y/N] ' "$1" >&2
		if ! IFS= read -r reply; then
			echo >&2
			return 2
		fi
		reply=${reply#"${reply%%[![:space:]]*}"}
		reply=${reply%"${reply##*[![:space:]]}"}
		case "$reply" in
		[Yy] | [Yy][Ee][Ss]) return 0 ;;
		'' | [Nn] | [Nn][Oo]) return 1 ;;
		esac
		echo 'Please answer y or n.' >&2
	done
}

# Outcomes go to the caller's $stage_result and $failures, not the exit
# status, so a failing action cannot trip an errexit caller.
sh_update_stage() {
	local label="$1" note="$2" answer=0 status=0
	shift 2
	stage_result=skipped
	printf '\n==> %s\n%s\n' "$label" "$note"
	# Helper functions describe the commands they run in $note instead.
	case "$1" in
	sh_update_*) ;;
	*) printf '    Command: %s\n' "$*" ;;
	esac
	sh_update_confirm 'Run this?' || answer=$?
	case "$answer" in
	0) ;;
	1) return 0 ;;
	*)
		echo 'update-interactive: input ended; nothing further was run.' >&2
		sh_update_report
		return 130
		;;
	esac
	"$@" || status=$?
	if [ "$status" -eq 0 ]; then
		stage_result=ran
		return 0
	fi
	stage_result=failed
	failures="$failures  $label: exit $status"$'\n'
	printf 'update-interactive: FAILED %s (exit %s)\n' "$label" "$status" >&2
}

sh_update_report() {
	[ -z "$failures" ] || printf 'update-interactive: these actions failed:\n%s' "$failures" >&2
}

# Domains for sys-update pins, one per line, in apply order. list rows carry
# paths, not projects, and domains span projects, so filter by directory.
sh_update_pin_domains() {
	local rows domains ordered='' domain preferred='nix-core flake-tools skills npm-tools pi'
	if ! sh_have jq; then
		echo 'update-interactive: jq is not installed' >&2
		return 127
	fi
	rows=$(sys-update list --json) || return
	domains=$(printf '%s\n' "$rows" | jq -r '
		.[] | select(.location == "pub/dotfiles-nix" or (.location | startswith("pub/dotfiles-nix/")))
		| .domain | select(test("^[A-Za-z0-9][A-Za-z0-9:._-]*$"))' | sort -u) || return
	for domain in $preferred; do
		case $'\n'"$domains"$'\n' in
		*$'\n'"$domain"$'\n'*) ordered="$ordered$domain"$'\n' ;;
		esac
	done
	for domain in $domains; do
		case " $preferred " in
		*" $domain "*) ;;
		*) ordered="$ordered$domain"$'\n' ;;
		esac
	done
	printf '%s' "$ordered"
}

# What a pin domain controls and when its change takes effect. Unknown
# domains get a generic description so new ones are never left unexplained.
sh_update_pin_impact() {
	case "$1" in
	nix-core)
		echo '    Impact: Moves the shared Nix foundation (nixpkgs, home-manager, nix-darwin) to its latest revisions in flake.lock. Once activated, this can change the version of most Nix-installed software and the system modules.'
		;;
	flake-tools)
		echo '    Impact: Moves the tools this config builds from their own source repositories (for example proctmux and secret_inject) to their latest revisions in flake.lock. They rebuild from the newer source when activated.'
		;;
	skills)
		echo '    Impact: Moves the agent skill repositories to their latest revisions in flake.lock. Skills are instructions your coding agents follow, so this can change agent behavior once activated; read the diff first.'
		;;
	npm-tools)
		echo '    Impact: Raises the exact versions in mods/native-tools.nix for global npm command-line tools, including the Pi CLI itself. Applies newer minor and patch versions the update policy allows; majors and any held packages stay held. These are not Pi extensions or Claude plugins.'
		;;
	pi)
		echo '    Impact: Raises the pinned Pi extension packages in mods/agents/default.nix (npm versions, git tags or commits) where the update policy allows; held packages stay held. Extensions run code inside Pi and can change how it behaves, so read the diff first. This does not update the Pi CLI.'
		;;
	*)
		echo "    Impact: Updates the dotfiles-nix pins in the $1 domain within its update policy. Run sys-update list to see what it contains."
		;;
	esac
}

# sys-update check exits 1 when updates are available, which is not a failure.
sh_update_check_pins() {
	local status=0
	sys-update check || status=$?
	if [ "$status" -eq 1 ]; then
		echo 'Updates are available (check exit 1); that is not an error.'
		return 0
	fi
	return "$status"
}

# Read-only: the whole checkout is shown because pin updates can regenerate
# files outside pub/dotfiles-nix. Untracked files are listed, never read.
sh_update_review_changes() {
	local top
	top=$(git --no-pager -C "$1" rev-parse --show-toplevel) || return
	git --no-pager -C "$top" status --short || return
	git --no-pager -C "$top" diff --stat HEAD || return
	git --no-pager -C "$top" diff --no-ext-diff HEAD
}

# pet: Walk through every update step with a yes/no question for each
update-interactive() {
	case "$#:${1:-}" in
	0:) ;;
	1:-h | 1:--help | 1:help)
		cat <<'HELP'
Usage: update-interactive

Asks yes/no (default no) before each step, in this order:
  1. Pull the configuration checkout (git pull --ff-only; never merges)
  2. Check pins (read-only), then update each dotfiles-nix pin domain
  3. Review the checkout's changes (read-only; stages and commits nothing)
  4. nixswitch to activate (pulling already happened, so not nixswitchup)
  5. Native tools: brew, nvim, claude (each separately, never `tools`)
  6. nixclean, which deletes old rollback generations (not an update)

Each step explains what it changes before asking.
A failed pull or pin update skips activation. Failures never stop later
steps; the exit status is 1 if any action failed. Closing input aborts.
HELP
		return 0
		;;
	*)
		echo 'update-interactive: unexpected arguments; see update-interactive --help' >&2
		return 2
		;;
	esac

	local IFS=$' \t\n'
	local dotfiles branch upstream domains domain step bin note rc
	local failures='' stage_result='' pins_blocked='' activation_blocked='' activation_failed=0
	dotfiles=$(sh_dotfiles_dir)
	printf 'update-interactive: configuration checkout %s\nEvery step defaults to no; press Enter to skip it.\n' "$dotfiles"

	if [ ! -d "$dotfiles" ]; then
		echo "Skipping configuration steps: $dotfiles is not a directory (set DOTFILES_HOME_MANAGER_DIR)."
		pins_blocked='the configuration checkout is missing'
		activation_blocked=$pins_blocked
	elif ! sh_have git; then
		echo 'Skipping pull and review: git is not installed.'
	elif ! branch=$(git -C "$dotfiles" rev-parse --abbrev-ref HEAD) ||
		! upstream=$(git -C "$dotfiles" rev-parse --abbrev-ref '@{u}' 2>/dev/null); then
		echo "Skipping pull: ${branch:-the checkout} has no upstream branch."
	else
		# Pull comes first: pin updates dirty the tree, and --ff-only with
		# autostash and rebase disabled never rewrites or hides existing work.
		sh_update_stage 'Pull configuration' "    Impact: Brings upstream configuration changes into this checkout without rebuilding Nix. Live-linked shell and editor files can take effect on their own; Nix-managed content waits for activation.
    Scope: $dotfiles, fast-forward $branch from $upstream only. Existing local edits are left untouched; it fails instead of merging." \
			git -C "$dotfiles" -c pull.rebase=false pull --ff-only --no-autostash || return
		if [ "$stage_result" = failed ]; then
			pins_blocked='the configuration pull failed, so the checkout is not current'
			activation_blocked=$pins_blocked
		fi
	fi

	rc=0
	domains=$(sh_update_pin_domains) || rc=$?
	case "$rc" in
	0) ;;
	127)
		echo 'Skipping pin steps: sys-update pins is unavailable (it needs a monorepo checkout with scripts/deps.ts, deno, and jq).'
		domains=''
		;;
	*)
		failures="$failures  pin domain discovery (sys-update list --json): exit $rc"$'\n'
		printf 'update-interactive: FAILED pin domain discovery (exit %s)\n' "$rc" >&2
		activation_blocked=${activation_blocked:-'pin domains could not be discovered'}
		domains=''
		;;
	esac
	if [ "$rc" -eq 0 ]; then
		sh_update_stage 'Check pins (read-only)' '    Impact: Read-only. Compares the dotfiles-nix pins with upstream and reports what is newer; it changes no pin and installs nothing.
    Runs: sys-update check (scripts/deps.ts check --project dotfiles-nix).' \
			sh_update_check_pins || return
		if [ -n "$pins_blocked" ]; then
			echo "Skipping pin updates: $pins_blocked."
		elif [ -z "$domains" ]; then
			echo 'No pin domains were found for dotfiles-nix.'
		fi
	fi
	for domain in $domains; do
		[ -z "$pins_blocked" ] || break
		sh_update_stage "Update pins: $domain" "$(sh_update_pin_impact "$domain")
    Timing: rewrites recorded versions or locks in the checkout now; nothing is installed until you activate.
    Scope: project dotfiles-nix, domain $domain only (scripts/deps.ts update --project dotfiles-nix $domain). Verifies the result." \
			sys-update pins "$domain" || return
		if [ "$stage_result" = failed ]; then
			activation_blocked=${activation_blocked:-"pin update $domain failed, so its pins are not verified"}
		fi
	done

	if [ -d "$dotfiles" ] && sh_have git; then
		sh_update_stage 'Review changes (read-only)' "    Impact: Shows every tracked change in the checkout, including edits you made before this run, and lists untracked paths. It stages, commits and applies nothing.
    Runs: git status --short, git diff --stat, and git diff against HEAD for the whole checkout.
    Read changed skills and Pi packages (flake.lock skill sources, mods/agents/default.nix) before activating: they install new agent instructions and code." \
			sh_update_review_changes "$dotfiles" || return
	fi

	if [ -n "$activation_blocked" ]; then
		echo "Skipping activation: $activation_blocked. Resolve it, review the diff, then run nixswitch yourself."
	elif ! sh_have darwin-rebuild && ! sh_have nixos-rebuild; then
		echo 'Skipping activation: neither darwin-rebuild nor nixos-rebuild is installed.'
	else
		sh_update_stage 'Activate configuration' "    Impact: Applies the checkout as it is now, so earlier pin changes take effect here: Nix-managed packages, npm tools, skills, Pi packages and Claude plugins move to the recorded versions, and system settings or services can change. It does not restart your editors or agent sessions.
    Scope: nixswitch applies the current $dotfiles checkout with sudo (--no-update-lock-file). It does not pull, so this is not nixswitchup." \
			nixswitch || return
		[ "$stage_result" != failed ] || activation_failed=1
	fi

	for step in brew nvim claude; do
		bin=$step
		[ "$step" != claude ] || bin=global-tools
		if ! sh_have "$bin"; then
			echo "Skipping $step: $bin is not installed."
			continue
		fi
		case "$step" in
		brew) note='    Impact: Updates Homebrew formulae and casks (GUI apps) right now, then removes old versions and cached downloads. Casks that update themselves are skipped because --greedy is not used. Running apps may need a relaunch. Not pinned, so nothing changes in the checkout.
    Scope: Homebrew: brew update, brew upgrade, then brew cleanup.' ;;
		nvim) note='    Impact: Updates, installs and removes Neovim plugins right now and rewrites mods/dotfiles/nvim/lazy-lock.json in the checkout. Open editors are not restarted; they keep the plugin code already loaded but may load newer files later, so restart them.
    Scope: Neovim plugins: Lazy! sync.' ;;
		claude) note='    Impact: Refreshes the Claude plugin marketplaces and updates the plugins this config declares, right now. It does not update the Claude CLI itself. Running Claude sessions may need a plugin reload or restart to use the new versions. Not pinned, so nothing changes in the checkout.
    Scope: Claude plugins through global-tools.' ;;
		esac
		sh_update_stage "Native tool: $step" "$note" sys-update "$step" || return
	done

	if [ "$activation_failed" -eq 1 ]; then
		echo 'Skipping cleanup: activation failed, and old generations are the way back.'
	else
		sh_update_stage 'Cleanup (not an update)' '    Impact: Frees disk space by removing unused Nix store paths. It cannot be undone: once old generations are gone you can no longer roll back to them.
    Scope: DELETES every old Nix generation (your rollback points) and optimizes the store, using sudo. Run it only once the new generation works.' \
			nixclean || return
	fi

	sh_update_report
	[ -z "$failures" ]
}

sh_complete_sys_update() {
	COMPREPLY=()
	if [ "$COMP_CWORD" -eq 1 ]; then
		local candidate
		while IFS= read -r candidate; do
			COMPREPLY+=("$candidate")
		done < <(compgen -W 'help list check pins brew nvim claude tools' -- "${COMP_WORDS[1]}")
	fi
}
if sh_have complete; then
	complete -o default -F sh_complete_sys_update sys-update
fi
