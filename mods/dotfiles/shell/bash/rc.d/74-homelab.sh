# pet: Run kubectl against the homelab cluster
labkubectl() {
  homelab.py run supermicro -- kubectl "$@"
}

# pet: Open k9s against the homelab cluster
labk9s() {
  homelab.py tui supermicro -- k9s "$@"
}

# pet: Open Hermes chat in the running homelab pod
labhermes() {
  local arg pod

  # The image and configuration are repo-managed, so in-pod updates and repairs must not rewrite them.
  case "${1:-}" in
    update|uninstall)
      echo "labhermes: Hermes is managed by kube-home-lab; change its deployment there" >&2
      return 1
      ;;
    doctor)
      for arg in "$@"; do
        if [ "$arg" = "--fix" ]; then
          echo "labhermes: Hermes configuration is managed by kube-home-lab; edit the declarative config there" >&2
          return 1
        fi
      done
      ;;
  esac
  if [ "$#" -eq 0 ]; then
    set -- chat
  fi

  pod="$(labkubectl get pods -n home -l app=hermes --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')" || return
  if [ -z "$pod" ]; then
    echo "labhermes: no running hermes pod found in namespace home" >&2
    return 1
  fi

  # A TUI: needs homelab.py tui plus -it for a tty. kubectl exec forwards no
  # $TERM, so force one every base image has terminfo for.
  # kubectl exec bypasses s6's service user; keep CLI writes owned by Hermes.
  homelab.py tui supermicro -- kubectl exec -it -n home "$pod" -c hermes -- \
    /command/s6-setuidgid hermes env TERM=xterm-256color HOME=/opt/data/home HERMES_HOME=/opt/data \
    hermes --in /opt/data/workspace "$@"
}

# pet: Open the maclab iMessage helper
macimessage() {
  homelab.py imessage maclab
}

# pet: Put the maclab machine to sleep
alias macsleep='homelab.py run maclab -- pmset sleepnow'
# pet: Wake the maclab machine
alias macwake='homelab.py wake maclab'
