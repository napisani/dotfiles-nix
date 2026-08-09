# LoanCrate MCP Parity Design

## Goal

Make every configured coding agent on the LoanCrate Mac expose the same MCP servers currently managed for Claude Code:

- `agentmemory`
- `linear`
- `figma`
- `bde`

`agentmemory` remains available on every machine. The three LoanCrate services remain limited to machines with the `loancrate` role.

## Current State

- Claude Code has all four servers.
- Pi already has all four servers with LoanCrate role gates where appropriate.
- Codex has only `agentmemory`.
- OpenCode has only `agentmemory`.

Claude's effective `~/.claude.json` contains no additional global or project MCP servers.

## Design

Each agent continues to own its MCP configuration in its native format.

### Codex

Add `linear`, `figma`, and `bde` to `mods/agents/codex.nix` through an `mcpSources` list and `shared.mkDeclaredEntriesFromSources`, matching the existing Claude and Pi pattern. Each new entry is conditional on `shared.isLoancrateMac` and uses Codex's streamable HTTP `url` field. Codex handles OAuth separately through `codex mcp login` when required.

### OpenCode

Keep the common `agentmemory` definition from `mods/dotfiles/opencode-config.json`. In `mods/agents/opencode.nix`, merge `linear`, `figma`, and `bde` into the generated config's `mcp` object only when `shared.isLoancrateMac` is true. Each uses OpenCode's native remote shape:

```json
{
  "type": "remote",
  "url": "https://example/mcp"
}
```

OpenCode performs automatic OAuth discovery for remote MCP servers and can authenticate through `opencode mcp auth <name>`.

### Pi and Claude

No configuration changes. Their declarations already match the intended set.

## Verification

1. Run `rtk nix flake check` to force activation merge evaluation for every machine.
2. Evaluate or inspect generated LoanCrate configurations to confirm all four MCP names are present for Codex and OpenCode.
3. Evaluate a non-LoanCrate configuration to confirm only `agentmemory` is present.
4. Do not run a system switch; the user will apply the configuration separately.

## Scope

This change only establishes declarative MCP parity. It does not authenticate OAuth servers, alter MCP credentials, or modify unrelated agent capabilities.
