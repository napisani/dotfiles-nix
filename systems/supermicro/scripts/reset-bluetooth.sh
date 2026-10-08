#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

mode=${1-preserve}
if (( $# > 1 )) || [[ $mode != preserve && $mode != clear ]]; then
    echo 'Usage: supermicro-bluetooth-reset [preserve|clear]' >&2
    exit 2
fi

for command in bash id timeout flock kubectl systemctl rfkill modprobe btmgmt grep sleep; do
    command -v "$command" >/dev/null || {
        echo "Missing required command: $command" >&2
        exit 1
    }
done
if [[ $mode == clear ]]; then
    for command in date mktemp cp rm; do
        command -v "$command" >/dev/null || exit 1
    done
fi
[[ $(id -u) == 0 ]] || { echo 'Must run as root' >&2; exit 1; }

run() {
    printf 'Bluetooth reset: %s\n' "$*" >&2
    timeout --kill-after=5s 30s "$@"
}

run btmgmt --index hci0 info >/dev/null
exec 9>/run/lock/tether-bluetooth-reset.lock
flock -n 9 || { echo 'Another Bluetooth reset holds the lock' >&2; exit 1; }
replicas=$(run kubectl -n home get deployment tether -o 'jsonpath={.spec.replicas}')
[[ $replicas =~ ^[0-9]+$ ]] || { echo 'Invalid Tether replica count' >&2; exit 1; }

restore_bluetooth() {
    local failed=0
    run modprobe btusb || failed=$?
    run systemctl start bluetooth.service || failed=$?
    run btmgmt --index hci0 power on || failed=$?
    run systemctl restart tether-btclass@hci0.service || failed=$?
    return "$failed"
}

restore_tether() {
    run kubectl -n home scale deployment tether "--replicas=$replicas" || return $?
    if (( replicas > 0 )); then
        timeout --kill-after=5s 150s kubectl -n home rollout status deployment/tether --timeout=120s
    fi
}

recover_on_exit() {
    local status=$?
    trap - EXIT
    if (( status != 0 )); then
        echo "Bluetooth reset failed (status $status); attempting recovery" >&2
        restore_bluetooth || echo 'Recovery failed: Bluetooth services/controller' >&2
        restore_tether || echo 'Recovery failed: Tether replicas/rollout' >&2
    fi
    exit "$status"
}
trap recover_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run kubectl -n home scale deployment tether --replicas=0
# Poll an empty pod list as well as deletions already underway after scale-down.
# Expansion belongs to the child shell polling the cluster.
# shellcheck disable=SC2016
timeout --kill-after=5s 150s bash -c '
    while :; do
        pods=$(timeout --kill-after=5s 15s kubectl -n home get pods -l app=tether -o name) || exit $?
        [[ -z $pods ]] && exit 0
        sleep 2
    done
'
run systemctl stop tether-btclass@hci0.service bluetooth.service
run rfkill unblock bluetooth
run modprobe -r btusb
run modprobe btusb
timeout --kill-after=5s 30s bash -c '
    until timeout --kill-after=5s 5s btmgmt --index hci0 info >/dev/null; do
        sleep 1
    done
'

if [[ $mode == clear ]]; then
    umask 077
    timestamp=$(run date -u +%Y%m%dT%H%M%SZ)
    backup=$(run mktemp -d "/var/lib/bluetooth-backup.$timestamp.XXXXXX")
    run cp -a /var/lib/bluetooth/. "$backup/"
    echo "Pairing backup: $backup"
    # BlueZ adapter state is stored in MAC-address directories, never backups.
    for directory in /var/lib/bluetooth/*; do
        if [[ -d $directory && ! -L $directory && ${directory##*/} =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; then
            run rm -rf -- "$directory"
        fi
    done
fi

restore_bluetooth
info=$(run btmgmt --index hci0 info)
if ! grep -Eiq 'class[[:space:]]+0x[[:xdigit:]]{2}0408([[:space:]]|$)' <<< "$info" ||
    ! grep -Eq 'current settings:.*\bpowered\b' <<< "$info"; then
    echo 'Adapter verification failed: expected class 0x..0408 and powered' >&2
    exit 1
fi
restore_tether
echo "Bluetooth reset complete ($mode; restored $replicas Tether replicas)"
