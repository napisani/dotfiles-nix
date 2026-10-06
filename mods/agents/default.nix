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

  home.sessionVariables = {
    PREFERRED_AGENT = "pi";
    REMOTE_PI_RELAY = "https://remote-pi.napisani.xyz";
  };

  agents = {
    enable = true;
    instructions = ../dotfiles/agents/AGENTS.md;
    rtkPackage = pkgs-unstable.rtk;

    skills.shared = import ./shared-skills.nix;

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
        transport = "sse";
        theme = "kanagawa-dragon";
        # Pi 1.0 defaults to fullscreen; keep the terminal's own scrollback.
        tuiMode = "regular";
        openaiReasoningMode.fast = false;
        # Use the same local Vantage checkout as Neovim, not a second copy of
        # its bridge implementation or a temporary feature worktree.
        extensions = [
          "${config.home.homeDirectory}/code/monorepo/pub/vantage-nvim/server/src/neovim/runtime/adjacent/extension.ts"
        ];
      };
      skillPaths = [ "~/code/*/apps/*/.agents/skills" ];
      # These packages provide native binaries or package-specific setup used by
      # the declared Pi extensions. Name-level approval intentionally follows
      # extension updates; adding a new script-owning dependency still produces
      # npm's review warning until it is added here.
      allowScripts = [
        "@google/genai"
        "@lincoln504/pi-research"
        "better-sqlite3"
        "esbuild"
        "koffi"
        "onnxruntime-node"
        "protobufjs"
        "sharp"
        "webgpu"
      ];
      # Keep this extension and the native Pi SDK in lockstep. The unqualified
      # git source previously advanced ahead of the pinned Pi installation.
      packages = [
        "npm:@ayulab/pi-rewind"
        "git:github.com/nicobailon/pi-subagents@v0.70.1"
        "npm:@datspike/pi-inline-slash-extension"
        "npm:@ff-labs/pi-fff"
        "npm:@juicesharp/rpiv-btw"
        "npm:@juicesharp/rpiv-ask-user-question"
        "npm:@lincoln504/pi-research"
        "npm:pi-vim"
        "npm:pi-web-access"
        "npm:remote-pi@0.7.0"
        # Routes Pi through the Claude Agent SDK without the stale pi-ai peer
        # range and removed getModels call in claude-agent-sdk-pi.
        "npm:pi-claude-bridge"
        "npm:pi-goal"
        "npm:pi-blackhole"
        # Direct dependency for local extensions; Pi's package root is not an
        # ancestor of individually linked extension files during Node resolution.
        "npm:@earendil-works/pi-tui@0.86.1"
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
