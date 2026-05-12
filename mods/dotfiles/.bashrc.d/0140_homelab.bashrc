labkubectl() {
  homelab.py run supermicro -- kubectl "$@"
}

labk9s() {
  homelab.py tui supermicro -- k9s "$@"
}

macimessage() {
  homelab.py imessage maclab
}

alias macsleep='homelab.py run maclab -- pmset sleepnow'
alias macwake='homelab.py wake maclab'
