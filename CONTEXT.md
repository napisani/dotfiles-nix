# Declarative tooling

This home configuration declares agent assets and native tools without confusing
their ownership or lifetimes. See the [architecture and operations contract](docs/contracts/declarative-tooling.md)
and [migration gates](docs/contracts/global-tools-migrations.md).

## Language

**Agent configuration**:
The selected skills, instructions, integrations, and native settings of coding
agents. It is independent of whether an agent's executable happens to come from npm.
_Avoid_: agent assets as an umbrella for all globally installed tools

**Native-tool domain**:
A package manager's desired tools and native realization rules. npm and uv are
peer domains alongside agent configuration, not agent capabilities.

**Profile**:
A host's desired selections and machine-role policy, separate from the mechanism
that realizes them.

**Native adapter**:
The owner of one tool's native representation, commands, and health criteria.
Adapters share installation mechanics without sharing native policy.

**Global tooling infrastructure**:
The common execution and reconciliation facilities used by agent, npm, and uv
adapters. Sharing these facilities does not make their consumers one domain.
_Avoid_: agent manager for the shared execution plane

**Managed ownership**:
Evidence that this configuration owns an asset or config key. Presence in a
native inventory alone is not ownership.

**Convergence**:
Bringing declared assets into the desired installed state, including retrying
failures and removing previously managed assets whose declarations disappeared.
It is distinct from checking upstream freshness or intentionally updating mutable assets.

**Machine role**:
The policy identity used to select profile overlays, distinct from a hostname
or a shell's machine-name variable.
