#dot file management

if command -v git &> /dev/null ; then
  #source "$HOME/.bashrc.d/0058_git-completion.bashrc"
  function temp-git-clone() {
    GIT_REPO="$1"
    if [ -z "$GIT_REPO" ]; then
      echo "Usage: temp-git-clone <git_repo>"
      return 1
    fi
    PROJECT_NAME=$(basename "$GIT_REPO" .git)
    EPOCH=$(date +%s)
    TEMP_DIR="/tmp/tgc-$PROJECT_NAME-$EPOCH"
    mkdir -p "$TEMP_DIR"
    pushd "$TEMP_DIR"L
    git clone "$GIT_REPO" .
  }


  function project-root-dir() {
      local DIR="$(pwd)"
      while [[ "$DIR" != "/" ]]; do
          if [[ -d "$DIR/.git" ]]; then
              echo "$DIR"
              return 0
          fi
          DIR="$(dirname "$DIR")"
      done
      echo "No .git directory found in the directory tree."
      return 1
  }

  function cdpr() {
    DIR=$(project-root-dir "$1")
    if [ -z "$DIR" ]; then
      return 1
    fi
    cd "$DIR"
  }


  alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
  export GIT_SSL_NO_VERIFY=true
  alias git-current-branch='git rev-parse --abbrev-ref HEAD'
  alias git-push-first='git push --set-upstream origin $(git-current-branch)'
  
  function git-changed-files() {
      COMAPRE_TO="$1"
      COMPARE_TO=${COMPARE_TO:-'main'}
      git diff --name-only "$COMPARE_TO"..."$(git-current-branch)"
  }

  function git-checkout() {
      root_dir=$(project-root-dir)
      if [ -z "$root_dir" ]; then
          return 1
      fi

      git checkout "$@"

      has_procmux=$(command -v procmux)
      if [ -z "$has_procmux" ]; then
          return 0
      fi

      possible_files=("$root_dir/procmux.yaml" "$root_dir/procmux.yml")
      for file in "${possible_files[@]}"; do
          if [ -e "$file" ]; then
              # procmux signal-restart-running --config "$file" 
              # TODO fix this  so its not hardcoded
              procmux signal-restart --name 'pnpm:backend:start'
              procmux signal-restart --name 'pnpm:frontend:start'
              return 0
          fi
      done

  }
  __git_complete git-checkout  _git_checkout

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
