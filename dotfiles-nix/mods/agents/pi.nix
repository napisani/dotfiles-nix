# agents/pi.nix — Pi: complete installation story
#
# Owns everything specific to Pi: skills (community + Pi-local via home.file;
# shared skills come from the global store ~/.agents/skills that Pi
# auto-discovers, so they're deliberately not linked into ~/.pi/agent/skills),
# RTK hooks, shared instructions, MCP servers (JSON), package installs (diff-
# pruned via `pi install`/`pi remove`, replacing the old manually-maintained
# removedPiPackages list in npmx.nix — including a one-time legacySeed for
# npm:pi-skillful, which that old list used to actively remove every run),
# extension/theme links, settings, and the Understand-Anything plugin.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  inputs ? { },
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname machineRoles inputs; };
  inherit (shared) home dotfiles nodeBin gitBin callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  remoteOllamaProvider = import ./ollama-provider.nix;
  ollamaProvider =
    if shared.isLoancrateMac then
      {
        baseUrl = "http://localhost:11434/v1";
        models = [
          "qwen3:1.7b"
          "qwen3.6-coding"
        ];
      }
    else
      remoteOllamaProvider;

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
    {
      name = "agentmemory";
      config = {
        command = shared.agentmemoryMcpBin;
        env = {
          AGENTMEMORY_URL = shared.agentmemoryUrl;
        };
        lifecycle = "lazy";
      };
    }
  ];
  declaredMcpEntries = shared.mkDeclaredEntriesFromSources mcpSources;

  declaredPiPackages = [
    "npm:@datspike/pi-inline-slash-extension"
    "npm:@juicesharp/rpiv-btw"
    "npm:pi-vim"
    "npm:pi-web-access"
  ];

  installUnderstandAnythingPlugin = ''
    _ua_repo_url="https://github.com/Lum1104/Understand-Anything.git"
    _ua_repo_dir="$HOME/.understand-anything/repo"
    _ua_plugin_root="$_ua_repo_dir/understand-anything-plugin"
    _ua_plugin_link="$HOME/.understand-anything-plugin"

    if [ -d "$_ua_repo_dir/.git" ]; then
      echo "agents: updating Understand-Anything checkout at $_ua_repo_dir"
      if ! ${gitBin}/git -C "$_ua_repo_dir" fetch --depth=1 origin main; then
        echo "agents: WARNING: failed to fetch Understand-Anything" >&2
      elif ! ${gitBin}/git -C "$_ua_repo_dir" reset --hard origin/main; then
        echo "agents: WARNING: failed to reset Understand-Anything checkout" >&2
      fi
    else
      if [ -e "$_ua_repo_dir" ] || [ -L "$_ua_repo_dir" ]; then
        echo "agents: replacing unmanaged Understand-Anything checkout at $_ua_repo_dir"
        rm -rf "$_ua_repo_dir"
      fi
      mkdir -p "$(dirname "$_ua_repo_dir")"
      echo "agents: cloning Understand-Anything -> $_ua_repo_dir"
      if ! ${gitBin}/git clone --depth=1 "$_ua_repo_url" "$_ua_repo_dir"; then
        echo "agents: WARNING: failed to clone Understand-Anything" >&2
      fi
    fi

    if [ -d "$_ua_plugin_root" ]; then
      if [ -e "$_ua_plugin_link" ] && [ ! -L "$_ua_plugin_link" ]; then
        echo "agents: replacing unmanaged Understand-Anything plugin root at $_ua_plugin_link"
        rm -rf "$_ua_plugin_link"
      fi

      if [ ! -L "$_ua_plugin_link" ] || [ "$(readlink "$_ua_plugin_link")" != "$_ua_plugin_root" ]; then
        ln -sfn "$_ua_plugin_root" "$_ua_plugin_link"
        echo "agents: linked Understand-Anything plugin root -> $_ua_plugin_link"
      fi
    else
      echo "agents: WARNING: Understand-Anything plugin root missing at $_ua_plugin_root" >&2
    fi
  '';
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
    instructions.writeAgentInstructions { target = instructionsTarget; }
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

    # ── Understand-Anything plugin (Pi-only, requires full repo clone) ─────────
    ${installUnderstandAnythingPlugin}
  '';
}
