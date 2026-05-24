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

  labkubectl exec -n home "$pod" -c gateway -- openclaw "$@"
}

macimessage() {
  homelab.py imessage maclab
}

alias macsleep='homelab.py run maclab -- pmset sleepnow'
alias macwake='homelab.py wake maclab'
