---
name: agent-management
description: How to declaratively add, change, or remove AI coding agent assets — skills, MCP servers, plugin/capability installs, RTK hooks, shared instructions — in this home-manager repo's mods/agents/*.nix module. Use this whenever the user asks to add a skill, add an MCP server, install a plugin for Claude/Codex/OpenCode/Pi, gate something to a specific machine, or asks why removing something from mods/agents/*.nix didn't actually remove it after a rebuild. Also use this before writing any new code under mods/agents/ or mods/dotfiles/agents/scripts/, even if the user doesn't name this skill directly — this architecture has specific, non-obvious rules (see "The one rule that matters") that are easy to violate by copying an old pattern.
---

# Managing agent assets declaratively

This repo installs the same kinds of things — skills, MCP servers, plugins, RTK hooks, shared instructions — into four AI coding agents (Claude Code, Codex, OpenCode, Pi) via `mods/agents/*.nix`. The architecture is deliberate and is documented in full at `docs/adr/0001-per-agent-modules.md` and `CONTEXT.md` in this repo's root — read those if you want the "why," not just the "how." This skill is the "how."

## The one rule that matters

**Each agent owns its complete installation story in its own file** (`mods/agents/claude.nix`, `codex.nix`, `opencode.nix`, `pi.nix`). There is no shared script that takes an `agents = [...]` list and branches on agent identity internally. That pattern used to exist here, caused real bugs (inconsistent revocation, awkward-to-add native mechanisms), and was deliberately torn out — see the ADR's "Considered options" section for exactly why it's rejected.

The dividing line: a **shared utility** that takes a file path, an agent ID string, or other caller-supplied identity — and does not know or care which agent is calling it — is fine to share (`lib.nix`, `skills.nix`, `instructions.nix`, `managed-config-lib.nix` are all built this way). A **shared script that owns a cross-agent declared list and switches behavior per agent** (`if agent == "codex" then ... else ...`) is the anti-pattern. If you catch yourself writing that second shape, stop and put the logic in the one agent file that needs it instead.

## The file map

| File | Owns |
|---|---|
| `mods/agents/lib.nix` | Agent-blind facts and utilities: `dotfiles`, `home`, `allAgents`, `isLoancrateMac` (hostname-derived machine gating), `mkFixPathConflicts`, `mkRtkHookInstall`, `mkDeclaredEntriesFromSources`, `callAgentLib` |
| `mods/agents/skills.nix` | The cross-agent skill **catalog** (still one declared list — see "Why the skill catalog is still one file" below) + the `mkAgentSkillInstall` utility |
| `mods/agents/instructions.nix` | The shared `AGENTS.md` source content + the `writeAgentInstructions`/`removeStaleInstructionSymlink` utilities |
| `mods/agents/managed-config-lib.nix` | JSON/TOML managed-key merge+prune (`mkJsonManagedMerge`, `mkTomlManagedMerge`) and CLI-driven diff+prune (`mkClaudePluginInstall`, `mkPiPackageInstall`) |
| `mods/agents/{claude,codex,opencode,pi}.nix` | Each agent's **entire** story: its own MCP-server declarations, its own capability/plugin installs via whatever mechanism is native to it, its own RTK hook line, its own instruction-file write |
| `mods/agents/default.nix` | Just imports the four per-agent files — nothing else lives here |
| `mods/dotfiles/agents/scripts/*.js` | The Node scripts the Nix utilities above shell out to (JSON/TOML merging, Claude plugin diffing, Pi package diffing) |
| `mods/dotfiles/agents/scripts/lib/managed-state.js` | The shared "read/write previously-managed name set" logic every diff-and-prune script uses |

### Why the skill catalog is still one file

`agentSkillSources` in `skills.nix` is a single list where each entry declares a skill once and targets N agents via an `agents = [...]` field. This looks like the anti-pattern above but isn't: it's **data**, not a script that branches on agent identity. The actual installation logic (`mkAgentSkillInstall`) is a plain utility that filters this list by `agentId` and returns a script scoped to one agent's directory — each agent module calls it itself. Don't "fix" this by splitting the catalog into four copies; that would just reintroduce duplication for no benefit. Do keep new capability installs (MCP servers, plugins, packages) out of a similar shared list — those genuinely differ per agent's native mechanism in a way skills don't.

## Every mechanism must be revocable

Deleting a declaration must make the corresponding thing disappear on the next `darwin-rebuild switch`, with no manual cleanup. This repo has two ways of achieving that, and picking the right one matters:

1. **Wipe-and-rebuild** — for things where the whole target directory is exclusively Nix-managed (skills). `mkAgentSkillInstall` wipes the skill directory, then rebuilds it from the current declared list.
2. **Tracked-state diffing** — for things where the target also holds content Nix doesn't own (a config file with user-added entries, a plugin/package manager with its own installs). `managed-config-lib.nix`'s functions track "what did I, Nix, previously manage" in `~/.local/state/agents-nix/<stateId>.json`, diff that against the current declaration each run, and only prune what's in the tracked state and no longer declared — so hand-added MCP servers or `pi install`ed packages never get touched.

**If a user says "I removed X from the Nix config but it's still there after rebuilding"**: this is almost always a state-tracking mechanism (MCP servers, Claude plugins, Pi packages), not skills. Check `~/.local/state/agents-nix/` for the relevant `<stateId>.json` file. If it's missing or was never populated (e.g. this is the very first activation after adding the mechanism), the thing predates tracking and won't be pruned automatically — see "Migrating something that predates tracking" below. If the state file exists and lists the entry, but it's still present, something about the merge/prune script itself is broken — check the corresponding script in `mods/dotfiles/agents/scripts/`.

## Common tasks

### Add a skill

Add one entry to `agentSkillSources` in `mods/agents/skills.nix`:

```nix
{
  repo = "https://github.com/someone/some-skills-repo";
  skills = [ "the-skill-name" ];
  agents = allAgents;  # or e.g. [ "claude-code" "pi" ] for a subset
}
```

Before adding it, verify the skill actually exists at that path in the target repo (fetch the repo's tree, e.g. via `gh api repos/<owner>/<repo>/git/trees/<default-branch>?recursive=1`) — skill directory names don't always match a project's README wording, and a wrong name fails silently at `skills add` time during activation, not at Nix-eval time.

For a skill that lives in this repo already (not fetched from elsewhere), drop a `SKILL.md` under `mods/dotfiles/agents/shared-skills/<name>/` instead — no catalog entry needed, it's synced automatically to every agent's skill directory by `mkAgentSkillInstall`.

### Add an MCP server

Each agent that needs the server gets its own entry, in its own file — there's no shared cross-agent MCP list. The three JSON-based agents (Claude, Pi, and any future JSON-config agent) and Codex's TOML both follow the same declare-then-merge shape:

```nix
# in claude.nix, codex.nix, or pi.nix's `let` block
mcpSources = [
  # ... existing entries ...
  {
    name = "my-new-server";
    condition = someBooleanOrOmit;  # optional, defaults to true
    config = {
      command = "/path/to/binary";
      env = { SOME_VAR = "value"; };
    };
  }
];
declaredMcpEntries = shared.mkDeclaredEntriesFromSources mcpSources;
```

then wire it into that agent's activation with the format-appropriate merge function — `managedConfig.mkJsonManagedMerge` for Claude/Pi (targeting `~/.claude.json` / `~/.pi/agent/mcp.json`, key `mcpServers`), `managedConfig.mkTomlManagedMerge` for Codex (targeting `~/.codex/config.toml`, key `mcp_servers`). Give it a unique `stateId` (e.g. `"claude-mcp-servers"`) — this is what names its tracked-state file, so make it descriptive and don't reuse another mechanism's id.

If the server needs a different config shape per agent (e.g. one agent needs an `oauth` block another doesn't), that's expected and fine — declare it separately in each agent's own `mcpSources`, shaped however that agent needs. Don't try to unify the shapes into one cross-agent record.

OpenCode is the exception: its MCP config lives directly in `mods/dotfiles/opencode-config.json` (symlinked live into `~/.config/opencode/config.json`, hand-edited, not activation-script-managed — see that file's own `"mcp"` key and `mods/opencode.nix`'s header comment). Add an OpenCode MCP server by editing that JSON file directly, not through `mods/agents/opencode.nix`.

### Add a Claude plugin

In `claude.nix`, add the plugin spec (`"<plugin-name>@<marketplace-name>"`) to `declaredPlugins`, and make sure `pluginMarketplace` points at the marketplace it comes from (only one marketplace is supported per activation today — see `mkClaudePluginInstall`'s `marketplace` parameter). Gate with a `lib.optionals someCondition [...]` the same way the existing Loancrate-only plugins are gated, if it shouldn't install everywhere.

### Add a native capability for one agent only

Not every agent needs to support every capability — partial coverage is expected, not a gap (see the ADR's rejected "shared capability abstraction" option). Use whatever's idiomatic to that one agent:

- **Pi packages** (npm-registry-backed, tracked via `pi install`/`pi remove`): add the package spec to `declaredPiPackages` in `pi.nix`.
- **Pi extensions** (local `.js`/`.ts` files symlinked in, not tracked via CLI): drop the file under `mods/dotfiles/agents/pi/extensions/`.
- **Claude plugins**: see above.
- **OpenCode plugins**: declared directly in `mods/dotfiles/opencode-config.json`'s `"plugin"` array (npm package names) — same hand-edited-file caveat as OpenCode's MCP config.

Do not invent a new shared "capability" list to express "this thing is available on agents A and C but not B, D." Just add it to the specific agent file(s) that support it.

### Gate something to a specific machine

Use `shared.isLoancrateMac` if the gate is specifically "the Loancrate machine," or add a new boolean to `lib.nix` following the exact same pattern for a different machine — compare against the flake-declared `hostname` argument (threaded through as a specialArg from `flake.nix`'s own `darwinConfigurations`/`nixosConfigurations` entries), never `MACHINE_NAME` (a separate, hand-typed `home.sessionVariables` string consumed only by bashrc functions at shell runtime — see `CONTEXT.md`'s glossary entry on "Flake-declared hostname" for why these two must not be conflated). Check `flake.nix` for the exact hostname string a machine is registered under — it's whatever string is passed as `hostname = "..."` to that machine's `mkDarwinSystem`/`mkNixOSSystem` call, which is not always identical to a casual name for the machine.

### Migrating something that predates tracking

If you're moving an existing imperative removal (like an old manually-maintained "packages to uninstall" list) onto one of the tracked-state mechanisms, seed the state file once so the migration doesn't silently stop enforcing it. `mkPiPackageInstall`'s `legacySeed` parameter is the reference example: it seeds the state file with previously-known-stale package specs only if the state file doesn't exist yet, so the very first activation under the new mechanism still prunes them, and every activation after that just uses real tracked state.

## Verifying a change actually works

Nix syntax checking (`nix-instantiate --parse <file>`) only catches parse errors — it does not catch option-merge conflicts (two files defining `home.activation.<sameName>` differently), which only surface when the value is actually forced. `nix eval ...home.activation --apply 'a: builtins.attrNames a'` only lists which activation keys exist; it does **not** force their merged values, so it will not catch a name collision either. To actually verify a change:

- Force the real merged value, not just its key: eval something like `config.system.activationScripts.script.text` (Darwin) with `--apply builtins.stringLength` (or any function that forces the whole string), for every affected machine in `flake.nix`'s `darwinConfigurations`/`nixosConfigurations`. This is the same attribute `darwin-rebuild switch` itself evaluates, so it catches exactly the conflicts a real switch would hit — including a scenario that has actually happened here: two files independently defining an activation entry with the same name (e.g. a new per-agent file's activation name accidentally colliding with an unrelated sibling file's existing one, like `mods/opencode.nix` vs `mods/agents/opencode.nix`).
- For anything that shells out to a script under `mods/dotfiles/agents/scripts/`, test the script directly against a scratch `$HOME`-like directory before trusting the Nix wiring — these scripts are plain Node and can be run standalone with the right env vars set (check the script's own header comment for its env var contract).
- Remember `git add` matters here: flakes only see git-tracked files, so a brand new file won't be visible to `nix eval`/`nix build` until it's at least `git add`ed (staging is enough — it doesn't need to be committed).
