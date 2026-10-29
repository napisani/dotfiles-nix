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
        defaultProvider = "claude-bridge";
        defaultModel = "claude-sonnet-5-5";
        defaultThinkingLevel = "high";
        transport = "sse";
        theme = "kanagawa-dragon";
        # Pi 1.0 defaults to fullscreen; keep the terminal's own scrollback.
        tuiMode = "regular";
        openaiReasoningMode.fast = false;
        # Use the same local Vantage checkout as Neovim, not a second copy of
        # its bridge implementation or a temporary feature worktree.
        # pi-surface loads from the monorepo checkout too; it needs
        # `npm ci && npm run build` there to serve its pages. Its surface-*
        # skills come from shared-skills.nix like every other skill.
        extensions = [
          "${config.home.homeDirectory}/code/monorepo/pub/vantage-nvim/server/src/neovim/runtime/adjacent/extension.ts"
          "${config.home.homeDirectory}/code/monorepo/pub/pi-surface/extension/index.ts"
        ];
        # pi-surface pages open in one terminal-browser tmux window per session,
        # reused while open; the script falls back to the default browser outside tmux.
        surface.browser = {
          command = "${config.home.homeDirectory}/shell_scripts/pi-surface-browser.sh";
          args = [ "{url}" ];
        };
      };
      # Plain paths only: Pi treats a glob here as a filter that disables every
      # skill outside it. It already finds .agents/skills in the cwd's ancestors.
      skillPaths = [ ];
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
        "git:github.com/nicobailon/pi-subagents@v0.78.0"
        "npm:@datspike/pi-inline-slash-extension@0.2.1"
        "npm:@ff-labs/pi-fff@0.11.0"
        "npm:@juicesharp/rpiv-btw@2.15.0"
        "npm:@juicesharp/rpiv-ask-user-question@2.15.0"
        "npm:@lincoln504/pi-research@1.7.23"
        "npm:pi-vim@0.14.2"
        "npm:pi-web-access@0.45.0"
        "npm:remote-pi@0.7.0"
        # Routes Pi through the Claude Agent SDK without the stale pi-ai peer
        # range and removed getModels call in claude-agent-sdk-pi.
        "npm:pi-claude-bridge@0.9.3"
        "npm:pi-goal@0.1.7"
        "npm:pi-cache-graph@1.0.2"
        # pi-blackhole 0.5.11 still requires the pre-1.0 Pi APIs and cannot
        # resolve alongside the Pi 1.0 dependency tree.
        # Direct dependency for local extensions; Pi's package root is not an
        # ancestor of individually linked extension files during Node resolution.
        "npm:@earendil-works/pi-tui@1.0.4"
        "git:github.com/nicobailon/visual-explainer@5f378868e0ea745a6284b51e710c390f0c76f72c"
      ];
    };

    opencode = {
      enable = true;
      rtk.enable = true;
      settings = builtins.fromJSON (builtins.readFile ../dotfiles/opencode-config.json);
    };
  };
}
