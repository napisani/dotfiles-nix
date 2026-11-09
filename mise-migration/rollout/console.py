"""The privileged console a rollout runs in.

The user authenticates sudo once inside a tmux console on the target host. A
bounded keepalive refreshes the sudo timestamp until an absolute deadline or an
end marker, and the agent drives the console with `send-keys`, polling log and
exit files. Old-generation tools are pinned first so the console survives the
switch that replaces them.
"""

import os
import shlex
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from .common import RolloutError, read_json, run, write_json

SESSION = "migration"
PINNED = ["bash", "tmux", "git", "nix", "darwin-rebuild", "nixos-rebuild"]
# A keepalive longer than this would hold administrator rights unattended overnight.
MAX_WINDOW_HOURS = 12

KEEPALIVE = """#!/usr/bin/env bash
# Usage: keepalive-until.sh RUN_DIR DEADLINE_EPOCH
set -u
run=$1
deadline=$2
trap 'sudo -k' EXIT
trap 'exit 0' HUP INT TERM
while [[ ! -e "$run/end-privileged-session" ]]; do
	remaining=$((deadline - $(date +%s)))
	(( remaining > 0 )) || break
	(( remaining > 60 )) && remaining=60
	# A background sleep lets the TERM trap fire at once instead of after the sleep.
	sleep "$remaining" &
	wait $!
	[[ -e "$run/end-privileged-session" ]] && break
	(( $(date +%s) < deadline )) || break
	sudo -n -v || exit 1
done
"""

START = """#!/usr/bin/env bash
# Run once inside the console: authenticate, then keep sudo fresh until the deadline.
set -euo pipefail
umask 077
run={run}
# Sudo timestamps belong to a terminal, not to the run directory.
session=${{TMUX-}}
if [[ ${{session%%,*}} != "$run/console.sock" ]]; then
	echo "First attach to this run's console using ATTACH.txt; authentication in another shell does not authorize it." >&2
	exit 1
fi
if [[ -e "$run/privileged-session.ready" ]]; then
	if kill -0 "$(cat "$run/keepalive.pid" 2>/dev/null)" 2>/dev/null; then
		echo 'This run already has a live privileged session.' >&2
		exit 1
	fi
	mv "$run/privileged-session.ready" "$run/privileged-session.ready.$(date +%s)"
	rm -f "$run/end-privileged-session"
fi
started=0
trap 'if [[ $started != 1 ]]; then sudo -k; fi' EXIT
echo 'Authenticate once for this run. The password stays in this terminal.'
sudo -v
deadline=$(( $(date +%s) + {window} ))
nohup "$BASH" "$run/keepalive-until.sh" "$run" "$deadline" > "$run/keepalive.log" 2>&1 < /dev/null &
echo "$!" > "$run/keepalive.pid"
{caffeinate}{keychain}echo "$deadline" > "$run/privileged-session.ready"
started=1
echo "Ready until $(date -r "$deadline" 2>/dev/null || date -d "@$deadline"). Detach with Ctrl-B then D."
"""

CAFFEINATE = """/usr/bin/caffeinate -i -w "$PPID" > /dev/null 2>&1 &
echo "$!" > "$run/caffeinate.pid"
"""

KEYCHAIN = """echo 'Unlock the login keychain so keychain-backed tools work over SSH.'
/usr/bin/security unlock-keychain "$HOME/Library/Keychains/login.keychain-db" || echo 'Keychain left locked; keychain checks move to the wrap-up list.'
"""


def pin_toolchain(run_dir):
    """Records each old-generation tool and roots its store path in the run directory."""
    pinned = {}
    (Path(run_dir) / "toolchain").mkdir(parents=True, exist_ok=True)
    # `run` already chose an interpreter new enough for the harness; macOS's own python3 is not.
    candidates = {"python3": sys.executable, **{name: shutil.which(name) for name in PINNED}}
    for name, found in candidates.items():
        if not found:
            continue
        real = Path(found).resolve()
        pinned[name] = str(real)
        if real.is_relative_to("/nix/store"):
            store = Path(*real.parts[:4])
            run(["nix-store", "--add-root", Path(run_dir) / "toolchain" / f"{name}-gcroot",
                 "--indirect", "--realise", store])
    write_json(Path(run_dir) / "toolchain.json", pinned)
    return pinned


def tmux(run_dir):
    pinned = read_json(Path(run_dir) / "toolchain.json")
    return pinned.get("tmux") or shutil.which("tmux") or "tmux"


def socket(run_dir):
    return Path(run_dir) / "console.sock"


def write_scripts(run_dir, window_seconds, macos):
    run_dir = Path(run_dir)
    start = START.format(
        run=shlex.quote(str(run_dir)), window=int(window_seconds),
        caffeinate=CAFFEINATE if macos else "", keychain=KEYCHAIN if macos else "",
    )
    for name, text in [("keepalive-until.sh", KEEPALIVE), ("start-privileged-session.sh", start)]:
        path = run_dir / name
        path.write_text(text)
        os.chmod(path, 0o700)


def start_console(run_dir):
    """Starts the console's tmux server with shell history off; reuses a live one."""
    run_dir = Path(run_dir)
    command = [tmux(run_dir), "-f", "/dev/null", "-S", socket(run_dir)]
    if run([*command, "has-session", "-t", SESSION], check=False).returncode == 0:
        return
    # NixOS has no /bin/bash; use the pinned one.
    bash = read_json(run_dir / "toolchain.json").get("bash") or shutil.which("bash") or "bash"
    run([*command, "new-session", "-d", "-s", SESSION, "-c", Path.home(), f"{shlex.quote(bash)} --noprofile --norc"])
    send(run_dir, f"set +o history; unset HISTFILE; umask 077; cd {shlex.quote(str(Path.home()))}")


def send(run_dir, text):
    """Types one line into the console; Enter is a separate send because multi-line input corrupted."""
    command = [tmux(run_dir), "-S", socket(run_dir)]
    if "\n" in text:
        raise RolloutError("console commands must be a single line")
    run([*command, "send-keys", "-t", SESSION, "-l", text])
    run([*command, "send-keys", "-t", SESSION, "Enter"])


def attach_command(run_dir, ssh_alias=None):
    """The command that attaches to the console: on the host itself, or over SSH from the controller."""
    local = f"{shlex.quote(tmux(run_dir))} -S {shlex.quote(str(socket(run_dir)))} attach -t {SESSION}"
    return f"ssh -t {ssh_alias} {shlex.quote(local)}" if ssh_alias else local


def privileges(run_dir):
    """The privileged session's state: live, deadline and seconds remaining."""
    run_dir = Path(run_dir)
    ready = run_dir / "privileged-session.ready"
    if not ready.exists():
        return {"started": False, "live": False, "remaining": 0}
    deadline = int(ready.read_text().strip())
    pid_file = run_dir / "keepalive.pid"
    alive = False
    if pid_file.exists():
        try:
            os.kill(int(pid_file.read_text().strip()), 0)
            alive = True
        except (OSError, ValueError):
            alive = False
    ended = (run_dir / "end-privileged-session").exists()
    remaining = deadline - int(time.time())
    return {"started": True, "live": alive and not ended and remaining > 0,
            "deadline": deadline, "remaining": max(remaining, 0), "ended": ended}


def close(run_dir):
    """Ends the privileged window: end marker, keepalive, sudo -k, caffeinate."""
    run_dir = Path(run_dir)
    record = {"time": datetime.now(timezone.utc).isoformat()}
    (run_dir / "end-privileged-session").touch()
    for name in ["keepalive", "caffeinate"]:
        pid_file = run_dir / f"{name}.pid"
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text().strip()), 15)
                record[name] = "stopped"
            except (OSError, ValueError):
                record[name] = "not running"
    invalidation = run(["sudo", "-k"], check=False)
    record["sudo"] = "invalidated" if invalidation.returncode == 0 else "sudo -k failed"
    if invalidation.returncode:
        record["sudo_error"] = (invalidation.stderr or invalidation.stdout).strip()[-300:]
    write_json(run_dir / "privileged-session.closed.json", record)
    if invalidation.returncode:
        raise RolloutError(f"sudo -k failed: {record['sudo_error']}")
    return record


def window_seconds(estimate_minutes):
    """The keepalive window: the estimate doubled plus an hour, within the hard cap."""
    seconds = int(estimate_minutes * 60 * 2 + 3600)
    return min(seconds, MAX_WINDOW_HOURS * 3600)


def create(run_dir, host, estimate_minutes, ssh_alias):
    """Creates the run directory, pins tools, starts the console and writes the user's instructions."""
    run_dir = Path(run_dir)
    run_dir.mkdir(parents=True, mode=0o700, exist_ok=True)
    os.chmod(run_dir, 0o700)
    state_file = run_dir / "state.json"
    state = read_json(state_file, {})
    if not (run_dir / "toolchain.json").exists():
        pin_toolchain(run_dir)
    window = window_seconds(estimate_minutes)
    write_scripts(run_dir, window, host.macos)
    rollout = run_dir / "rollout.sh"
    python = read_json(run_dir / "toolchain.json").get("python3") or sys.executable
    rollout.write_text(
        "#!/usr/bin/env bash\n# Runs the rollout in this console; the agent polls rollout.exit.\n"
        f"cd {shlex.quote(str(Path.home()))}\n"
        f"{shlex.quote(python)} {shlex.quote(str(host.checkout / 'mise-migration/migration.py'))} "
        f"rollout --host {host.name} --run-dir {shlex.quote(str(run_dir))} \"$@\" "
        f"> {shlex.quote(str(run_dir / 'rollout.log'))} 2>&1\n"
        f"echo $? > {shlex.quote(str(run_dir / 'rollout.exit'))}\n"
    )
    os.chmod(rollout, 0o700)
    start_console(run_dir)
    state.update({
        "host": host.name, "checkout": str(host.checkout), "estimate_minutes": estimate_minutes,
        "window_seconds": window, "created": state.get("created") or datetime.now(timezone.utc).isoformat(),
    })
    write_json(state_file, state)
    attach = attach_command(run_dir, ssh_alias)
    instructions = (
        f"On this host run: {attach_command(run_dir)}\n"
        f"or from the controller: {attach}\n"
        f"then in the console run: bash {shlex.quote(str(run_dir / 'start-privileged-session.sh'))}\n"
    )
    (run_dir / "ATTACH.txt").write_text(instructions)
    return {"run_dir": str(run_dir), "attach": attach,
            "start": str(run_dir / "start-privileged-session.sh"),
            "window_hours": round(window / 3600, 1), "instructions": instructions}
