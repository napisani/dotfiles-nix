{
  config,
  homeManagerRelPath,
  lib,
  ...
}:
{
  agents = {
    enable = true;
    instructions = "${config.home.homeDirectory}/${homeManagerRelPath}/mods/dotfiles/agents/AGENTS.md";

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
      models = lib.mkDefault [
        "qwen3:1.7b"
        "qwen3:0.6b"
      ];
    };

    globalNpmTools = {
      "@ellery/terminal-mcp" = "0.5.1";
      "@napisani/scute" = "0.0.19";
      "@earendil-works/pi-coding-agent" = "0.85.0";
      "@agentclientprotocol/claude-agent-acp" = "0.74.0";
      "@zed-industries/codex-acp" = "0.16.0";
      "@playwright/cli" = "0.1.19";
    };

    claude = {
      enable = true;
      pluginMarketplaces = [ "nicobailon/visual-explainer" ];
      plugins = [ "visual-explainer@visual-explainer-marketplace" ];
      settings = {
        editorMode = "vim";
        permissions.defaultMode = "auto";
      };
    };

    codex.enable = true;

    pi = {
      enable = true;
      # claude-agent-sdk-pi remains intentionally absent: its stale pi-ai peer
      # range breaks dependency resolution for the other Pi extensions. See
      # WORKAROUNDS.md.
      settings = {
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-luna";
        defaultThinkingLevel = "high";
        theme = "kanagawa-dragon";
        openaiReasoningMode.fast = false;
      };
      skillPaths = [ "~/code/*/apps/*/.agents/skills" ];
      packages = [
        "npm:@ayulab/pi-rewind"
        "npm:pi-mcp-adapter"
        "npm:@datspike/pi-inline-slash-extension"
        "npm:@ff-labs/pi-fff"
        "npm:@juicesharp/rpiv-btw"
        "npm:pi-vim"
        "npm:pi-web-access"
        # Routes Pi through the Claude Agent SDK without the stale pi-ai peer
        # range and removed getModels call in claude-agent-sdk-pi.
        "npm:pi-claude-bridge"
        "npm:pi-goal"
        "git:github.com/nicobailon/visual-explainer"
      ];
    };

    opencode = {
      enable = true;
      settings = builtins.fromJSON (builtins.readFile ../../dotfiles/opencode-config.json);
    };
  };
}
