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
HELP
		;;
	list | check | pins)
		local dotfiles="${DOTFILES_HOME_MANAGER_DIR:-$HOME/code/monorepo/pub/dotfiles-nix}"
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
