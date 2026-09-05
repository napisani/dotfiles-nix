{ lib, ... }:
let
  inherit (lib) mkOption types;
  stringList = types.listOf types.str;
  nativeConfig = types.attrsOf types.anything;
  skillSelection = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Skill catalog name.";
      };
      manualOnly = mkOption {
        type = types.bool;
        default = false;
        description = "Whether capable agents must disable implicit invocation for this skill.";
      };
    };
  };
  skillSelectionType = types.coercedTo types.str (name: { inherit name; }) skillSelection;
  skillSelectionList = types.listOf skillSelectionType;

  mkAgentOptions =
    extraOptions:
    {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this agent's declared configuration is realized.";
      };

      mcpServers = mkOption {
        type = nativeConfig;
        default = { };
        description = "MCP server declarations in this agent's native configuration shape.";
      };

      settings = mkOption {
        type = nativeConfig;
        default = { };
        description = "Settings owned by this agent adapter.";
      };
    }
    // extraOptions;
in
{
  options.agents = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether declarative agent configuration is enabled for this home.";
    };

    instructions = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = null;
      description = "Shared instruction source applied by enabled agent adapters.";
    };

    skills = {
      shared = mkOption {
        type = skillSelectionList;
        default = [ ];
        description = "Catalog skills installed for every enabled agent; strings coerce to non-manual selections.";
      };

      perAgent = {
        claude = mkOption {
          type = skillSelectionList;
          default = [ ];
          description = "Additional catalog skill selections installed only for Claude Code.";
        };
        codex = mkOption {
          type = skillSelectionList;
          default = [ ];
          description = "Additional catalog skill selections installed only for Codex.";
        };
        pi = mkOption {
          type = skillSelectionList;
          default = [ ];
          description = "Additional catalog skill selections installed only for Pi.";
        };
        opencode = mkOption {
          type = skillSelectionList;
          default = [ ];
          description = "Additional catalog skill selections installed only for OpenCode.";
        };
      };
    };

    globalNpmTools = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Global npm package names mapped to exact desired versions.";
    };

    providers.ollama = {
      baseUrl = mkOption {
        type = types.str;
        description = "OpenAI-compatible Ollama endpoint exposed to agent adapters.";
      };
      models = mkOption {
        type = stringList;
        description = "Model IDs offered by the configured Ollama endpoint.";
      };
    };

    claude = mkAgentOptions {
      pluginMarketplaces = mkOption {
        type = stringList;
        default = [ ];
        description = "Claude Code plugin marketplace sources.";
      };
      plugins = mkOption {
        type = stringList;
        default = [ ];
        description = "Claude Code plugin specs.";
      };
      loancrateConfig = mkOption {
        type = types.nullOr nativeConfig;
        default = null;
        description = "Optional Loancrate Claude plugin configuration.";
      };
    };

    codex = mkAgentOptions { };

    pi = mkAgentOptions {
      packages = mkOption {
        type = stringList;
        default = [ ];
        description = "Pi package specs installed through Pi's native package manager.";
      };
      skillPaths = mkOption {
        type = stringList;
        default = [ ];
        description = "Additional Pi skill search paths preserved alongside user-managed paths.";
      };
    };

    opencode = mkAgentOptions {
      plugins = mkOption {
        type = stringList;
        default = [ ];
        description = "OpenCode plugin package specs.";
      };
    };
  };
}
