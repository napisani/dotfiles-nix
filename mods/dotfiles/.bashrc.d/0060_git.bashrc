#dot file management
if command -v git &> /dev/null
then
    alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
    export GIT_SSL_NO_VERIFY=true
    alias git-current-branch='git rev-parse --abbrev-ref HEAD'
    alias git-push-first='git push --set-upstream origin $(git-current-branch)'
    function git-changed-files() {
        COMAPRE_TO="$1"
        COMPARE_TO=${COMPARE_TO:-'main'}
        git diff --name-only "$COMPARE_TO"..."$(git-current-branch)"
    }
fi
