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

  function git-local-ignore() {
    local root
    root=$(project-root-dir)
    if [ -z "$root" ]; then
      return 1
    fi

    local file="$root/.gitignore_local"
    if [ ! -f "$file" ]; then
      touch "$file"
    fi

    local exclude="$root/.git/info/exclude"
    mkdir -p "$root/.git/info"
    if [ ! -f "$exclude" ]; then
      touch "$exclude"
    fi

    if ! grep -qxF ".gitignore_local" "$exclude"; then
      printf "%s\n" ".gitignore_local" >> "$exclude"
    fi

    git -C "$root" config --local core.excludesFile .gitignore_local

    if [ -n "${EDITOR:-}" ]; then
      "$EDITOR" "$file"
    else
      nvim "$file"
    fi
  }


  alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
  export GIT_SSL_NO_VERIFY=true
  alias git-current-branch='git rev-parse --abbrev-ref HEAD'
  alias git-push-first='git push --set-upstream origin $(git-current-branch)'
  alias gitp='git push'

  function gitcm() {
      if [ $# -eq 0 ]; then
          read -p "Enter commit message: " message
      else
          message="$1"
      fi
      git commit -m "$message"
  }

  alias gita='git add'
  alias gitau='git add -u '


  
  function gitscp() {
    local OPTIND
    OPTIND=1

    local message=""
    local has_message=0
    local opt

    while getopts ":m:" opt; do
      case "$opt" in
        m)
          message="$OPTARG"
          has_message=1
          ;;
        \?)
          echo "gitscp: invalid option -- $OPTARG" >&2
          return 1
          ;;
        :)
          echo "gitscp: option requires an argument -- $OPTARG" >&2
          return 1
          ;;
      esac
    done

    shift $((OPTIND - 1))

    if [ $# -ne 0 ]; then
      echo "gitscp: unexpected arguments: $*" >&2
      return 1
    fi

    if ! git add -A; then
      echo "gitscp: failed to stage changes" >&2
      return 1
    fi

    if git diff --cached --quiet; then
      echo "gitscp: no staged changes" >&2
      return 1
    fi

    if [ "$has_message" -eq 0 ]; then
      local staged_diff
      staged_diff=$(git diff --cached)

      if [ -z "$staged_diff" ]; then
        echo "gitscp: unable to collect staged diff" >&2
        return 1
      fi

      local prompt
      prompt="Write a concise git commit message (12 words max) for these staged changes. Respond with a single line suitable for \"git commit -m\"."

      local generated_message
      if ! generated_message=$(_ollama_completion "$prompt" "$staged_diff"); then
        echo "gitscp: unable to generate commit message" >&2
        return 1
      fi

      generated_message=$(printf '%s' "$generated_message" | head -n 1 | tr -d '\r')

      if [ -z "$generated_message" ]; then
        echo "gitscp: received empty commit message" >&2
        return 1
      fi

      message="$generated_message"
    fi

    if ! git commit -m "$message"; then
      echo "gitscp: commit failed" >&2
      return 1
    fi

    if ! git push; then
      echo "gitscp: push failed" >&2
      return 1
    fi

    return 0
  }

  
  function git-changed-files() {
    # get only the file name (everything after the last space)
    git status --porcelain=v2  -u | sed -E 's/^.*[[:space:]]+([^[:space:]]+)$/\1/' 
  }

  function git-changed-in-branch() {
      COMAPRE_TO="$1"
      COMPARE_TO=${COMPARE_TO:-'main'}
      git diff --name-only  --relative "$COMPARE_TO"..."$(git-current-branch)"
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
              procmux signal-restart-running --config "$file" 
              return 0
          fi
      done

  }
  __git_complete git-checkout  _git_checkout

  function git-rebase-onto() {
    if [ -z "$1" ]; then
      echo "Usage: git-rebase-onto <branch>"
      return 1
    fi
    git rebase --onto "$1" "$(git log --oneline | fzf --reverse  --prompt='Select the commit BEFORE the first commit: ' | awk '{print $1}')"
  }

  function git-squash() {
    git rebase -i  "$(git log --oneline | fzf --reverse  --prompt='Select the commit BEFORE the first commit: ' | awk '{print $1}')"
  }
fi
