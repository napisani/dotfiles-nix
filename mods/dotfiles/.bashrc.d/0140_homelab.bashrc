labkubectl() {
  homelab.py run supermicro -- kubectl "$@"
}

labk9s() {
  homelab.py tui supermicro -- k9s "$@"
}

macimessage() {
  homelab.py imessage maclab
}
