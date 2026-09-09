# pet: Run kubectl against the homelab cluster
labkubectl() {
  homelab.py run supermicro -- kubectl "$@"
}

# pet: Open k9s against the homelab cluster
labk9s() {
  homelab.py tui supermicro -- k9s "$@"
}

# pet: Open a shell in the running OpenClaw homelab pod
labopenclaw() {
  local arg pod

  # Configuration and the image are owned by kube-home-lab. Keep read-only
  # diagnostics convenient, but reject commands that would mutate either one.
  if [ "${1:-}" = "update" ]; then
    echo "labopenclaw: OpenClaw is managed by kube-home-lab; update its pinned image there" >&2
    return 1
  fi
  if [ "${1:-}" = "doctor" ]; then
    for arg in "$@"; do
      case "$arg" in
        --fix|--repair)
          echo "labopenclaw: OpenClaw configuration is managed by kube-home-lab; edit the declarative config there" >&2
          return 1
          ;;
      esac
    done
    if [ "$#" -eq 1 ]; then
      set -- doctor --lint
    fi
  elif [ "$#" -eq 0 ]; then
    # OpenClaw 2026.9.2 requires an explicit owner when multiple agents are
    # configured, so open the default agent's main TUI session.
    set -- tui --session agent:default:main
  fi

  pod="$(labkubectl get pods -n home -l app=openclaw --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"
  if [ -z "$pod" ]; then
    echo "labopenclaw: no running openclaw pod found in namespace home" >&2
    return 1
  fi

  # openclaw is a TUI: needs both an interactive ssh session (homelab.py tui,
  # not labkubectl's "run") and -it on kubectl exec so the container process
  # gets a tty. kubectl exec also does not forward the caller's environment,
  # so the container sees no $TERM at all (or whatever Ghostty's local TERM
  # happens to be, e.g. xterm-ghostty, which a minimal container image almost
  # certainly has no terminfo entry for) and its TUI lib bails out instead of
  # rendering. Force a TERM value every base image ships terminfo for.
  homelab.py tui supermicro -- kubectl exec -it -n home "$pod" -c gateway -- env TERM=xterm-256color openclaw "$@"
}

# pet: Open the maclab iMessage helper
macimessage() {
  homelab.py imessage maclab
}

# pet: Put the maclab machine to sleep
alias macsleep='homelab.py run maclab -- pmset sleepnow'
# pet: Wake the maclab machine
alias macwake='homelab.py wake maclab'
