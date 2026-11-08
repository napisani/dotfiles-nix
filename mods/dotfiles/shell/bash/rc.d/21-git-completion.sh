# Git's package-provided Bash completion.
#
# bash-completion normally lazy-loads this on the first `git <TAB>`, but
# 52-git-functions.sh registers a custom git-checkout completion through
# __git_complete during startup. Load the installed, version-matched file now;
# do not vendor a copy that can drift behind the Git binary.

sh_have git || return 0

type -t __git_complete >/dev/null 2>&1 && return 0
_git_bin=$(command -v git)
_git_completion="${_git_bin%/*}/../share/bash-completion/completions/git"
_git_exec_path=
if [ ! -r "$_git_completion" ]; then
	_git_exec_path=$(git --exec-path 2>/dev/null) || _git_exec_path=
fi
sh_source_first \
	"$_git_completion" \
	"${_git_exec_path:+${_git_exec_path%/libexec/git-core}/share/bash-completion/completions/git}" \
	"/etc/profiles/per-user/${USER:-$(id -un)}/share/bash-completion/completions/git" \
	"/run/current-system/sw/share/bash-completion/completions/git" \
	"/opt/homebrew/share/bash-completion/completions/git" \
	"/opt/homebrew/etc/bash_completion.d/git-completion.bash" \
	"/usr/local/share/bash-completion/completions/git" \
	"/usr/local/etc/bash_completion.d/git-completion.bash" \
	"/usr/share/bash-completion/completions/git" >/dev/null 2>&1 || true
unset _git_bin _git_completion _git_exec_path
