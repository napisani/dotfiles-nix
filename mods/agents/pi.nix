# agents/pi.nix — Pi: complete installation story
#
# Owns everything specific to Pi: skills (community + Pi-local via home.file;
# shared skills come from the global store ~/.agents/skills that Pi
# auto-discovers, so they're deliberately not linked into ~/.pi/agent/skills),
# RTK hooks, shared instructions, MCP servers (JSON), package installs (diff-
# pruned via `pi install`/`pi remove`, replacing the old manually-maintained
# removedPiPackages list in npmx.nix — including a one-time legacySeed for
# npm:pi-skillful, which that old list used to actively remove every run),
# extension/theme links, and settings.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  inputs ? { },
  homeManagerRelPath,
  ...
}:
let
  shared = import ./lib.nix {
    inherit config lib pkgs-unstable hostname machineRoles inputs homeManagerRelPath;
  };
  inherit (shared) home dotfiles nodeBin callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  ollamaProvider = import ./ollama-provider.nix { inherit (shared) isLoancrateMac; };

  managedPiProviders = {
    ollama = {
      baseUrl = ollamaProvider.baseUrl;
      api = "openai-completions";
      apiKey = "ollama";
      models = ollamaProvider.models;
    };
  };

  scriptsDir = "${dotfiles}/agents/scripts";
  instructionsTarget = "${home}/.pi/agent/AGENTS.md";
  mcpTarget = "${home}/.pi/agent/mcp.json";

  mcpSources = [
    {
      name = "linear";
      condition = shared.isLoancrateMac;
      config = {
        url = "https://mcp.linear.app/mcp";
        lifecycle = "lazy";
      };
    }
    {
      name = "figma";
      condition = shared.isLoancrateMac;
      config = {
        url = "https://mcp.figma.com/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
          scope = "mcp:connect";
        };
        lifecycle = "lazy";
      };
    }
    {
      name = "bde";
      condition = shared.isLoancrateMac;
      config = {
        url = "https://bde.dsci.loancrate.dev/mcp";
        lifecycle = "lazy";
      };
    }
    # Loancrate org connectors — mirrors the claude.ai account-linked MCP
    # connectors already authenticated in Claude Code on this machine. Pi has
    # no equivalent auto-discovered connector directory, so each is declared
    # here explicitly with its own OAuth handshake (same clientName/clientUri
    # pattern as the figma entry above).
    {
      name = "datadog";
      condition = shared.isLoancrateMac;
      config = {
        url = "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
    }
    {
      name = "gmail";
      condition = shared.isLoancrateMac;
      config = {
        url = "https://gmailmcp.googleapis.com/mcp/v1";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
    }
    {
      name = "notion";
      condition = shared.isLoancrateMac;
      config = {
        url = "https://mcp.notion.com/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
    }
    {
      name = "sentry";
      condition = shared.isLoancrateMac;
      config = {
        url = "https://mcp.sentry.dev/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
        };
        lifecycle = "lazy";
      };
    }
    # slack omitted: its OAuth server doesn't support dynamic client
    # registration, so Pi (unlike Claude Code's own registered client) has no
    # way to obtain a client_id for it.
  ];
  declaredMcpEntries = shared.mkDeclaredEntriesFromSources mcpSources;

  declaredPiPackages = [
    "npm:@datspike/pi-inline-slash-extension"
    "npm:@ff-labs/pi-fff"
    "npm:@juicesharp/rpiv-btw"
    "npm:pi-fabric"
    "npm:pi-vim"
    "npm:pi-web-access"
    "npm:claude-agent-sdk-pi"
    "git:github.com/nicobailon/visual-explainer"
  ];

in
{
  # Layer 0 links. Pi skills: community + Pi-local only — shared skills are
  # deliberately NOT linked here because Pi auto-discovers ~/.agents/skills
  # (the global store, owned by shared-store.nix), so linking them here too
  # would double them up. This replaces the old install-then-dedupe dance.
  # Extensions (.js/.ts) and themes (.json) are live-editable out-of-store
  # links. See docs/adr/0002-layered-asset-management.md.
  home.file =
    skills.mkCommunitySkillFiles {
      agentId = "pi";
      skillDirRelPath = ".pi/agent/skills";
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/pi/skills";
      targetDirRelPath = ".pi/agent/skills";
    }
    // shared.mkLocalFileLinks {
      sourceRelPath = "agents/pi/extensions";
      targetDirRelPath = ".pi/agent/extensions";
      extensions = [
        ".js"
        ".ts"
      ];
    }
    // shared.mkLocalFileLinks {
      sourceRelPath = "agents/pi/themes";
      targetDirRelPath = ".pi/agent/themes";
      extensions = [ ".json" ];
    };

  home.activation.preparePiInstructionsForRtk = lib.hm.dag.entryBefore [ "installPiRtkHooks" ] (
    instructions.removeStaleInstructionSymlink { target = instructionsTarget; }
  );

  home.activation.installPiRtkHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--agent pi";
      label = "pi";
    }
  );

  home.activation.writePiInstructions = lib.hm.dag.entryAfter [ "installPiRtkHooks" ] (
    instructions.writeAgentInstructions {
      target = instructionsTarget;
      extraSourcePaths = [ "${dotfiles}/agents/pi/instructions.md" ];
    }
  );

  home.activation.configurePiMcpServers = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = declaredMcpEntries;
    }
  );

  home.activation.installPiPackages = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkPiPackageInstall {
      declaredPackages = declaredPiPackages;
      stateId = "pi-packages";
      # npmx.nix used to actively `pi remove npm:pi-skillful` every run via
      # a manually-maintained removedPiPackages list. Seed it here once so
      # the new diff-based mechanism still prunes it on its first run,
      # instead of silently never pruning something that predates this
      # tracking.
      legacySeed = [ "npm:pi-skillful" ];
    }
  );

  home.activation.installPiConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # ── Settings (provider defaults, model, packages, skill paths) ────────────
    ${nodeBin}/node ${scriptsDir}/apply-pi-settings.js

    # ── Custom providers/models → ~/.pi/agent/models.json (the file Pi reads) ─
    MANAGED_PROVIDERS=${lib.escapeShellArg (builtins.toJSON managedPiProviders)} \
    REMOVED_PROVIDERS=${lib.escapeShellArg (builtins.toJSON [ "mlx" ])} \
      ${nodeBin}/node ${scriptsDir}/apply-pi-models.js
  '';
}
