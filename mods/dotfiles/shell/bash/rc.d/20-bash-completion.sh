# bash-completion.
#
# home-manager sourced this from an absolute /nix/store path. Probing the usual
# locations instead covers nix, homebrew (both Apple-silicon and Intel prefixes),
# and ordinary Linux distributions.
#
# The BASH_COMPLETION_VERSINFO guard is the upstream-recommended one and matches
# what home-manager emitted: it makes re-sourcing a no-op, which matters because
# nested shells and `exec bash` both re-run this file.

if [ -z "${BASH_COMPLETION_VERSINFO:-}" ]; then
	sh_source_first \
		"$HOME/.nix-profile/etc/profile.d/bash_completion.sh" \
		"/etc/profiles/per-user/${USER:-$(id -un)}/etc/profile.d/bash_completion.sh" \
		"/run/current-system/sw/etc/profile.d/bash_completion.sh" \
		"/opt/homebrew/etc/profile.d/bash_completion.sh" \
		"/usr/local/etc/profile.d/bash_completion.sh" \
		"/usr/share/bash-completion/bash_completion" \
		"/etc/bash_completion" >/dev/null 2>&1 || true
fi

# Completion directories are not eagerly sourced here. bash-completion lazy-loads
# version-matched files from installed packages on first use; 21 only forces Git
# early because 52-git-functions.sh needs __git_complete while registering a
# custom command.
