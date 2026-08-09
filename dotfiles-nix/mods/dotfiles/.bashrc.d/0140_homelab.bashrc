labkubectl() {
  homelab.py run supermicro -- kubectl "$@"
}

labk9s() {
  homelab.py tui supermicro -- k9s "$@"
}

labopenclaw() {
  local pod
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

macimessage() {
  homelab.py imessage maclab
}

alias macsleep='homelab.py run maclab -- pmset sleepnow'
alias macwake='homelab.py wake maclab'
