---
title: Homelab Command Aliases Design
date: 2026-05-11
status: draft
---

# Homelab Command Aliases Design

## Summary

Create a small homelab command launcher that provides local shell aliases for applications running on home servers. The launcher should make remote commands feel local, avoid SSH when already running on the target host, and resolve hosts through hostname, LAN IP, and Tailscale discovery.

## Goals

- Provide `labkubectl`, `labk9s`, and `macimessage` commands.
- Run target commands locally when already on the target host.
- Use passwordless SSH when running from another machine.
- Try multiple SSH addresses, starting with hostname.
- Discover Tailscale IPs with the `tailscale` CLI when available.
- Keep host and app definitions organized for future homelab aliases.

## Non-Goals

- Manage SSH keys or credentials.
- Install or configure Kubernetes, `k9s`, `imsg`, `itui`, or Tailscale.
- Replace `~/.ssh/config`; configured SSH aliases should still work.
- Create a general-purpose remote orchestration framework.

## Recommended Approach

Use a toolbox Python script with thin bash wrappers.

The script should own host resolution, local-host detection, command execution, argument forwarding, and special app flows. Bash should only expose ergonomic command names:

```bash
labkubectl() { homelab.py run supermicro -- kubectl "$@"; }
labk9s() { homelab.py tui supermicro -- k9s "$@"; }
macimessage() { homelab.py imessage maclab; }
```

This matches the repository's existing split:

- `mods/dotfiles/.bashrc.d/*.bashrc` loads shell-facing aliases and functions.
- `mods/dotfiles/toolbox/` contains personal CLI utilities with real behavior.
- `~/toolbox` is already symlinked and on `PATH`.

## Alternatives Considered

### Bash-only aliases/functions

This would put all behavior in a new `~/.bashrc.d/*.bashrc` file.

Pros:

- Minimal files.
- No install step.
- Easy to inspect from a shell.

Cons:

- Host resolution, Tailscale JSON parsing, SSH quoting, TTY handling, and `nohup` process checks become brittle in bash.
- Future apps would make the bashrc file harder to maintain.

### SSH config only

This would rely on `~/.ssh/config` and keep aliases as direct `ssh host command` wrappers.

Pros:

- Idiomatic SSH.
- Works well for static hostnames.

Cons:

- Weak local-host bypass.
- Hard to express "hostname first, LAN IP second, Tailscale CLI-discovered IP third".
- Does not organize app-specific flows like `macimessage`.

### Toolbox script plus thin bash wrappers

This is the recommended design.

Pros:

- Keeps shell aliases small.
- Handles structured server config cleanly.
- Can parse Tailscale JSON safely.
- Can use correct SSH quoting and TTY handling.
- Easy to extend with future apps.

Cons:

- Slightly more structure than simple aliases.
- Requires keeping one small Python CLI on `PATH`.

## Server Configuration

The initial server registry should be defined in the script as structured data:

```python
servers = {
    "supermicro": {
        "user": "nick",
        "local_hostnames": ["supermicro"],
        "candidates": ["supermicro", "192.168.1.51"],
        "tailscale_names": ["supermicro"],
        "tailscale_fallbacks": [],
    },
    "maclab": {
        "user": "nick",
        "local_hostnames": ["maclab"],
        "candidates": ["maclab", "192.168.1.52"],
        "tailscale_names": ["maclab"],
        "tailscale_fallbacks": [],
    },
}
```

Every server entry includes a configurable SSH username. Both initial servers use `nick`.

## Target Resolution

For a target server, resolve execution in this order:

1. Check local hostname. If the current host matches a configured `local_hostnames` value, run locally.
2. Try SSH by configured hostname first, such as `nick@supermicro`.
3. Try configured LAN IPs, such as `nick@192.168.1.51`.
4. If the local `tailscale` CLI exists and is running, parse `tailscale status --json`, match configured Tailscale names, and try discovered IPs.
5. Try any configured hardcoded Tailscale fallbacks.

The first target that succeeds should be used. SSH probes should be non-interactive and short-lived so a down host does not hang the shell.

## Commands

### `labkubectl`

Purpose: run any `kubectl` command against the Kubernetes environment on `supermicro` without copying credentials to the local machine.

Behavior:

- If already on `supermicro`, run `kubectl "$@"`.
- Otherwise run `kubectl "$@"` over SSH on the resolved `supermicro` target.
- Preserve all user-provided arguments after `labkubectl`.

Example:

```bash
labkubectl get pods -n home
```

### `labk9s`

Purpose: run the `k9s` TUI on `supermicro`.

Behavior:

- If already on `supermicro`, run `k9s "$@"`.
- Otherwise run `k9s "$@"` over SSH on the resolved `supermicro` target.
- Allocate an interactive TTY for SSH.
- Preserve user-provided `k9s` arguments.

Example:

```bash
labk9s -n home
```

### `macimessage`

Purpose: use the iMessage terminal UI backed by `imsg serve` on `maclab`.

Behavior:

- If already on `maclab`, run the process check and `itui` locally.
- Otherwise run the same process check and `itui` over SSH on the resolved `maclab` target.
- Before launching `itui`, ensure `imsg serve` is running.
- If `imsg serve` is not already running, start it with `nohup` in a way that survives SSH session termination.

Remote command shape:

```bash
if ! pgrep -f "imsg serve" >/dev/null; then
  nohup imsg serve >/tmp/imsg-serve.log 2>&1 < /dev/null &
fi
exec itui
```

## Error Handling

- If no target can be reached, print the attempted targets in order.
- If Tailscale is unavailable, skip Tailscale discovery without failing the whole command.
- If a remote command is missing, let the remote shell error surface clearly.
- For TUI commands, preserve interactive behavior and exit codes when practical.
- Avoid prompting for passwords; passwordless SSH is assumed.

## Testing

Testing should cover the command-construction and resolution behavior without requiring real SSH access:

- Local-host match returns local execution.
- Hostname candidate is tried before LAN IP.
- `maclab` includes `192.168.1.52`.
- `supermicro` includes `192.168.1.51`.
- Tailscale JSON discovery can extract matching host IPs.
- `labkubectl` forwards arbitrary args after `kubectl`.
- `labk9s` marks execution as TTY-required.
- `macimessage` command checks for `imsg serve`, starts it with `nohup` when absent, and then runs `itui`.

## Placement

Recommended files:

- `mods/dotfiles/toolbox/homelab.py`
- `mods/dotfiles/.bashrc.d/0140_homelab.bashrc`

The toolbox script is immediately available because `~/toolbox` is already on `PATH`. The bashrc file is loaded by the existing `programs.bash.profileExtra` loop.

## Verification

Implementation verification should include:

- Running the unit or script-level tests for the homelab launcher.
- Parsing/sourcing the new bashrc file in a shell.
- Running `nix-instantiate --parse` on any touched Nix files, if Nix files are touched.
- Running the relevant machine dry-run build if Home Manager wiring changes.

## Open Decision

No additional user decisions are required for the initial version. Future apps can be added to the same server registry and bash wrapper file.
