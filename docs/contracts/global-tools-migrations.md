# Global tooling migration checks

Reviewed 2026-09-06. These are deployment gates, not automatic expiry dates.
Do not remove compatibility code merely because a host has been offline.

## Vocal retirement

The uv adapter handles `venv:vocal` only while that ID exists in its ownership
ledger. Successful cleanup removes the ID, and later apply/status runs must not
even probe the old environment (covered by a subprocess test).

Remove that branch only after **every host** has migrated and the supported
rollback generations can no longer recreate the old declaration. Keep the old
venv and manual packages intact. Do not infer ownership from the filesystem.
Record the migrated generation and rollback cutoff before deleting the branch.

| Host | Vocal migration generation / rollback cutoff | MCP audit |
|---|---|---|
| nicks-mbp | Pending | Pending |
| Nicks-Loancrate-MacBook-Pro | Pending | 2026-09-06: live Claude/Codex/Pi entries match declarations |
| maclab | Pending | Pending |
| supermicro | Pending | Pending |

No live switch was performed during the refactor. Legacy installation-state
readers should likewise remain until supported generations no longer emit them.

## Pre-switch managed-key audit

MCP keys are owned wholesale; manual entries under them do not survive apply.
This policy predates this refactor. Audit on **each target host**, using that
host's declarations and HOME, before switching:

```sh
cd pub/dotfiles-nix
umask 077
snapshot=$(mktemp)
nix eval --json \
  '.#darwinConfigurations.Nicks-Loancrate-MacBook-Pro.config.home-manager.users.nick.agents' \
  > "$snapshot"
python3 checks/audit-managed-mcp.py "$snapshot" --home "$HOME"
rm -f "$snapshot"
```

Substitute the appropriate flake configuration for other hosts. Python 3.11+
is required. The audit never writes config and prints only entry names, not
credentials or values. Exit 0 means no existing entries would be overwritten
or removed; 1 means undeclared/changed entries need review; 2 means unreadable
config. Missing files are reported, not treated as destructive drift. Promote
needed manual entries/edits into declarations before applying. The local audit
above is not evidence about the other machines.

## RTK upgrades

RTK resource generation must work offline and be reproducible. A normal Nix
build or a cached runtime check does not prove the second property. After
changing `agents.rtkPackage`, run on each supported builder:

```sh
checks/rtk-reproducibility.sh darwinConfigurations.nicks-mbp
```

Use the corresponding configuration on Intel Darwin/Linux. This rebuilds the
actual four RTK asset derivations with `nix build --rebuild`, comparing their
new outputs against the existing store outputs. It does not activate anything.
Requires Nix and jq. The four aarch64-darwin RTK 0.45.0 derivations passed on
2026-09-06; foreign-platform reproducibility remains a builder-side check.
