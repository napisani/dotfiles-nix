# Shared agent choices. Host-specific overrides are explicit imports in homes/.
{
  config,
  pkgs-unstable,
  lib,
  ...
}:
{
  imports = [
    ../internal/agents
    ../internal/global-tools.nix
  ];

  agents = {
    enable = true;
    instructions = ../dotfiles/agents/AGENTS.md;
    rtkPackage = pkgs-unstable.rtk;

    skills = {
      shared = [
        # Pinned community skills.
        "skill-creator"
        "doc-coauthoring"
        "frontend-design"
        "prompt-engineering-patterns"
        "context7"
        "code-simplification"
        {
          name = "brainstorming";
          manualOnly = true;
        }
        {
          name = "systematic-debugging";
          manualOnly = true;
        }
        "diagnosing-bugs"
        "resolving-merge-conflicts"
        "handoff"
        "grill-me"
        "grill-with-docs"
        "improve-codebase-architecture"
        "codebase-design"
        "tdd"
        "implement"
        "to-spec"
        "domain-modeling"
        {
          name = "prototype";
          manualOnly = true;
        }
        "proctmux-config"
        "vantage-distill-session"
        "vantage-author-walkthrough"
        "playwright-cli"
        "web-research"
        "mermaid-diagrams"
        "worktree"
        "no-ai-slop"
        "show-me"
        "visual-explainer"
        {
          name = "multi-valued-review";
          manualOnly = true;
        }
        {
          name = "mvr-suggestions";
          manualOnly = true;
        }
        {
          name = "neovim-project-config";
          manualOnly = true;
        }
        {
          name = "rfc-generator";
          manualOnly = true;
        }
        {
          name = "smart-docs";
          manualOnly = true;
        }

        # Repo-local shared skills.
        "address-pr-feedback"
        "agent-management"
        "forge-solution"
        "ob-note"
        "rebase-from-parent"
        "stackman-rebase-conflicts"
        "tech-spec"
      ];

    };

    providers.ollama = {
      baseUrl = lib.mkDefault "https://ollama.napisani.xyz/v1";
      models = lib.mkDefault [ ];
    };

    claude = {
      enable = true;
      rtk.enable = true;
      pluginMarketplaces = [ "nicobailon/visual-explainer" ];
      plugins = [ "visual-explainer@visual-explainer-marketplace" ];
      settings = {
        editorMode = "vim";
        permissions.defaultMode = "auto";
      };
    };

    codex = {
      enable = true;
      rtk.enable = true;
    };

    pi = {
      enable = true;
      rtk.enable = true;
      # claude-agent-sdk-pi remains intentionally absent: its stale pi-ai peer
      # range breaks dependency resolution for the other Pi extensions. See
      # WORKAROUNDS.md.
      settings = {
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-luna";
        defaultThinkingLevel = "high";
        theme = "kanagawa-dragon";
        openaiReasoningMode.fast = false;
        # Use the same local Vantage checkout as Neovim, not a second copy of
        # its bridge implementation or a temporary feature worktree.
        extensions = [
          "${config.home.homeDirectory}/code/monorepo/pub/vantage-nvim/server/src/neovim/runtime/adjacent/extension.ts"
        ];
      };
      skillPaths = [ "~/code/*/apps/*/.agents/skills" ];
      packages = [
        "npm:@ayulab/pi-rewind"
        "npm:pi-mcp-adapter"
        "git:github.com/nicobailon/pi-subagents"
        "npm:@datspike/pi-inline-slash-extension"
        "npm:@ff-labs/pi-fff"
        "npm:@juicesharp/rpiv-btw"
        "npm:@juicesharp/rpiv-ask-user-question"
        "npm:@lincoln504/pi-research"
        "npm:pi-vim"
        "npm:pi-web-access"
        # Routes Pi through the Claude Agent SDK without the stale pi-ai peer
        # range and removed getModels call in claude-agent-sdk-pi.
        "npm:pi-claude-bridge"
        "npm:pi-goal"
        # Direct dependency for local extensions; Pi's package root is not an
        # ancestor of individually linked extension files during Node resolution.
        "npm:@earendil-works/pi-tui@0.85.0"
        "git:github.com/nicobailon/visual-explainer"
      ];
    };

    opencode = {
      enable = true;
      rtk.enable = true;
      settings = builtins.fromJSON (builtins.readFile ../dotfiles/opencode-config.json);
    };
  };
}
