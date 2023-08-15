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

    # rebase branch without dealing with merge conflicts
    # already been resolved
    function git-squash-branch() {
      REBASE_BRANCH="$1"
      CURRENT_BRANCH="$(git-current-branch)"
      if [ -z "$REBASE_BRANCH" ]; then
        echo "Usage: git-branch-commits <branch>"
        return 1
      fi
      if [ "$REBASE_BRANCH" = "$CURRENT_BRANCH" ]; then
        echo "Cannot rebase branch onto itself"
        return 1
      fi
      TEMP_BRANCH="squash-branch-$(date +%s)"

      # back merge ancestor branch
      git fetch && \ 
      git merge "origin/$REBASE_BRANCH" && \
      git checkout "$REBASE_BRANCH" && \

      # create temp branch 
      git pull && \
      git checkout -b "$TEMP_BRANCH" && \

      # merge the original branch and squash all commits
      git merge --squash "$CURRENT_BRANCH" && \
      git commit

      # renmae to original branch and clean up the temp branch
      git branch -D "$CURRENT_BRANCH" && \
      git checkout -b "$CURRENT_BRANCH" 

      git branch -D "$TEMP_BRANCH" 
      


    }

fi
