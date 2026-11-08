# Declarative tooling

This home configuration declares agent assets and native tools without confusing
their ownership or lifetimes. See the [architecture and operations contract](docs/contracts/declarative-tooling.md)
and [migration gates](docs/contracts/mise-cutover.md).

## Language

**Agent configuration**:
The selected skills, instructions, integrations, and native settings of coding
agents. It is independent of whether an agent's executable happens to come from npm.
_Avoid_: agent assets as an umbrella for all globally installed tools

**Native-tool domain**:
A tool backend's desired executables and native realization rules. npm and pipx
are peers alongside agent configuration, not agent capabilities.

**Profile**:
A host's desired selections and machine-role policy, separate from the mechanism
that realizes them.

**Native adapter**:
Translates one tool's native representation and commands. Adapters share
transport helpers without sharing application policy or authorizing ownership.

**Global mise configuration**:
User-default tools, native packages and configuration deployment, independent of a project's overrides.
It shares the user's ordinary lifecycle state with other trusted configurations.

**Managed ownership**:
Evidence that this configuration owns an asset or config key. Presence in a
native inventory alone is not ownership.

**Convergence**:
Bringing declared assets into the desired installed state. Explicit pruning
removes obsolete owned packages; upstream freshness is a separate update.

**Machine role**:
The policy identity used to select profile overlays, distinct from a hostname
or a shell's machine-name variable.
