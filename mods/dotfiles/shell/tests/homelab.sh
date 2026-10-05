#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../bash/rc.d/74-homelab.sh"

pod_state=ready
launch_status=0
launch_args=()

labkubectl() {
  [ "$*" = 'get pods -n home -l app=hermes --field-selector=status.phase=Running -o jsonpath={.items[0].metadata.name}' ] || return 99
  case "$pod_state" in
    ready) printf '%s\n' hermes-test-pod ;;
    empty) return 0 ;;
    error) return 42 ;;
  esac
}

homelab.py() {
  launch_args=("$@")
  return "$launch_status"
}

assert_launch() {
  local i
  local expected=(tui supermicro -- kubectl exec -it -n home hermes-test-pod -c hermes --
    /command/s6-setuidgid hermes env TERM=xterm-256color HOME=/opt/data/home HERMES_HOME=/opt/data
    hermes --in /opt/data/workspace "$@")
  [ "${#launch_args[@]}" -eq "${#expected[@]}" ]
  for ((i = 0; i < ${#expected[@]}; i++)); do
    [ "${launch_args[$i]}" = "${expected[$i]}" ]
  done
}

labhermes
assert_launch chat
labhermes --resume 'OpenClaw session title'
assert_launch --resume 'OpenClaw session title'
labhermes doctor
assert_launch doctor
labhermes sessions list
assert_launch sessions list

for command in update uninstall; do
  launch_args=()
  if labhermes "$command" 2>/dev/null; then
    echo "labhermes accepted $command" >&2
    exit 1
  fi
  [ "${#launch_args[@]}" -eq 0 ]
done
launch_args=()
if labhermes doctor --live --fix 2>/dev/null; then
  echo 'labhermes accepted doctor --fix' >&2
  exit 1
fi
[ "${#launch_args[@]}" -eq 0 ]

for pod_state in empty error; do
  launch_args=()
  status=0
  labhermes status 2>/dev/null || status=$?
  if [ "$pod_state" = error ]; then
    [ "$status" -eq 42 ]
  else
    [ "$status" -eq 1 ]
  fi
  [ "${#launch_args[@]}" -eq 0 ]
done

pod_state=ready
launch_status=43
status=0
labhermes status || status=$?
[ "$status" -eq 43 ]
assert_launch status

echo 'labhermes: ok'
