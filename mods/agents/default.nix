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
        "npm:@ayulab/pi-rewind@0.4.6"
        "git:github.com/nicobailon/pi-subagents@v0.76.1"
        "npm:@datspike/pi-inline-slash-extension@0.2.0"
        "npm:@ff-labs/pi-fff@0.11.0"
        "npm:@juicesharp/rpiv-btw@2.12.0"
        "npm:@juicesharp/rpiv-ask-user-question@2.12.0"
        "npm:@lincoln504/pi-research@1.7.9"
        "npm:pi-vim@0.14.2"
        "npm:pi-web-access@0.37.0"
        "npm:remote-pi@0.7.0"
        # Routes Pi through the Claude Agent SDK without the stale pi-ai peer
        # range and removed getModels call in claude-agent-sdk-pi.
        "npm:pi-claude-bridge@0.9.1"
        "npm:pi-goal@0.1.7"
        # pi-blackhole 0.5.11 still requires the pre-1.0 Pi APIs and cannot
        # resolve alongside the Pi 1.0 dependency tree.
        # Direct dependency for local extensions; Pi's package root is not an
        # ancestor of individually linked extension files during Node resolution.
        "npm:@earendil-works/pi-tui@1.0.4"
        "git:github.com/nicobailon/visual-explainer@0cc6f15452c455a05fb7fceb036d0da31387c69c"
      ];
    };

    opencode = {
      enable = true;
      rtk.enable = true;
      settings = builtins.fromJSON (builtins.readFile ../dotfiles/opencode-config.json);
    };
  };
}
