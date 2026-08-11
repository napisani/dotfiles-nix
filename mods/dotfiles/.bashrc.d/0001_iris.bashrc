# IRIS starts its child shell by resolving `bash` from PATH. Keep the active
# Nix Bash first so it does not fall back to macOS's legacy /bin/bash.
if [[ $- == *i* ]]; then
  iris_bash_dir="$(dirname "$BASH")"
  case "$PATH" in
    "$iris_bash_dir":*) ;;
    *) export PATH="$iris_bash_dir:$PATH" ;;
  esac
  unset iris_bash_dir

  eval "$(iris init bash)"
fi
