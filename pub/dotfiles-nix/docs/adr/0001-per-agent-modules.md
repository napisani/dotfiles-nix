# Split mods/agents/* into one module per agent, sharing utilities not policy

**Status:** accepted

Skills, MCP servers, plugin installs, and RTK hooks used to each live in one
shared cross-agent file (`skills.nix`, `mcp.nix`, `plugins.nix`, `hooks.nix`),
each holding a declared list with an `agents = [...]` field and one script
that branched internally per agent ID (JSON merge for some, TOML surgery for
Codex, CLI marketplace calls for Claude only, nothing at all for Pi/OpenCode
capability installs). That branching-inside-one-script shape was the actual
pain, not "sharing code" per se — it made revocation inconsistent (only
`skills.nix`'s wipe-and-rebuild loop actually removes what's undeclared; MCP
servers only ever get added/updated; Claude plugins have no removal path at
all) and made adding agent-specific installation mechanisms (Pi extensions,
OpenCode's plain npm-string plugin array, a hypothetical Codex-native
mechanism) awkward to bolt onto a script that wasn't written with that agent
in mind.

We're splitting into `mods/agents/{claude,codex,opencode,pi}.nix`, each
owning its complete installation story end to end: its own MCP-server
declarations, its own capability/plugin installs via whatever mechanism is
native to that agent, its own RTK hook line, its own instruction-file write
(chaining any agent-specific follow-up, e.g. Codex's `@RTK.md` reference
reapply, in the same file instead of a cross-file ordering dependency by
name). A capability like `agentmemory` may appear in `claude.nix`'s plugin
list and `pi.nix`'s extension list independently, with no shared "capability"
record tying them together — partial coverage across agents is expected, not
a gap.

What stays shared is `lib.nix` (agent-blind facts: hostname-derived machine
booleans, repo paths — fixing the existing bug where the flake's own
`hostname` param was silently discarded in favor of a hand-duplicated
`MACHINE_NAME` string) and format-specific *utility functions* — a JSON-
merge-with-prune function, a TOML-merge-with-prune function, a
`mkAgentSkillInstall { agentId, skillDir }` function, a
`writeAgentInstructions { target }` function. Each is parameterized by
caller-supplied identity (a file path, an agent ID string) and contains no
internal `if agent == X` branching — that's the line: a shared function that
doesn't know which agent is calling it is fine to share; a shared script that
owns a cross-agent list and switches behavior per agent is not.

## Considered options

- **Keep one shared script per concern, add more `agents = [...]` branches
  as needed.** Rejected — this is the status quo and is exactly what made
  revocation inconsistent and Pi/OpenCode-native mechanisms hard to add
  without further contorting scripts not written for them.
- **One shared "capability" abstraction** (declare `agentmemory` once with
  per-agent config blocks, similar to today's MCP source shape). Rejected —
  forces every capability to model itself as expressible-or-not across all 4
  agents uniformly, when in practice support is genuinely partial and
  independent per agent.

## Consequences

- Revocation must be upgraded per mechanism as part of this migration, not
  deferred: MCP-server writers need actual prune-on-diff (not just
  add/update), and CLI-driven plugin installs (Claude marketplace, Pi
  packages) need to diff against real installed state (e.g.
  `~/.claude/plugins/installed_plugins.json`) and uninstall anything
  present-but-undeclared, matching the bar `skills.nix`'s wipe-and-rebuild
  already set.
- Cross-file `entryAfter [ "installAgentSkills" ]`-style ordering by a shared
  step name goes away; each agent module's internal steps order against each
  other in the same file instead.
