# agents/pi.nix — Pi: complete installation story
#
# Owns everything specific to Pi: skills (+ its own global-store dedup quirk
# — Pi auto-discovers ~/.agents/skills in addition to ~/.pi/agent/skills, so
# shared skills must be removed from the latter to avoid name collisions),
# RTK hooks, shared instructions, MCP servers (JSON), package installs (diff-
# pruned via `pi install`/`pi remove`, replacing the old manually-maintained
# removedPiPackages list in npmx.nix — including a one-time legacySeed for
# npm:pi-skillful, which that old list used to actively remove every run),
# extension/theme symlinking, settings, and the Understand-Anything plugin.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname; };
  inherit (shared) home dotfiles nodeBin gitBin callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  scriptsDir = "${dotfiles}/agents/scripts";
  skillDir = "${home}/.pi/agent/skills";
  extensionsDir = "${home}/.pi/agent/extensions";
  themesDir = "${home}/.pi/agent/themes";
  instructionsTarget = "${home}/.pi/agent/AGENTS.md";
  mcpTarget = "${home}/.pi/agent/mcp.json";

  # Installed globally by mods/npmx.nix (`npm install -g @agentmemory/mcp`),
  # not spawned via `npx` — avoids an npx fetch/resolve on every MCP connect.
  agentmemoryMcpBin = "${home}/.local/bin/agentmemory-mcp";

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
      name = "agentmemory";
      config = {
        command = agentmemoryMcpBin;
        env = {
          AGENTMEMORY_URL = "http://localhost:3111";
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

  syncPiExtensions = ''
    _src="${dotfiles}/agents/pi/extensions"
    _dst="${extensionsDir}"
    mkdir -p "$_dst"

    if [ -d "$_src" ]; then
      for _extension_file in "$_src"/*.js "$_src"/*.ts; do
        [ -f "$_extension_file" ] || continue

        _extension_name=$(basename "$_extension_file")
        case "$_extension_name" in
          *.test.*) continue ;;
        esac

        _target_link="$_dst/$_extension_name"
        if [ -e "$_target_link" ] && [ ! -L "$_target_link" ]; then
          echo "agents: refusing to replace non-symlink Pi extension at $_target_link"
          continue
        fi

        if [ ! -L "$_target_link" ] || [ "$(readlink "$_target_link")" != "$_extension_file" ]; then
          ln -sfn "$_extension_file" "$_target_link"
          echo "agents: linked Pi extension '$_extension_name' -> $_target_link"
        fi
      done
    fi
  '';

  syncPiThemes = ''
    _src="${dotfiles}/agents/pi/themes"
    _dst="${themesDir}"
    mkdir -p "$_dst"

    if [ -d "$_src" ]; then
      for _theme_file in "$_src"/*.json; do
        [ -f "$_theme_file" ] || continue

        _theme_name=$(basename "$_theme_file")
        _target_link="$_dst/$_theme_name"
        if [ -e "$_target_link" ] && [ ! -L "$_target_link" ]; then
          echo "agents: refusing to replace non-symlink Pi theme at $_target_link"
          continue
        fi

        if [ ! -L "$_target_link" ] || [ "$(readlink "$_target_link")" != "$_theme_file" ]; then
          ln -sfn "$_theme_file" "$_target_link"
          echo "agents: linked Pi theme '$_theme_name' -> $_target_link"
        fi
      done
    fi
  '';

  # Pi discovers ~/.agents/skills in addition to ~/.pi/agent/skills. Keep
  # Pi's agent-local directory for Pi-only skills, and delete duplicate
  # entries that are already available through the global store.
  removePiGlobalSkillDuplicates = ''
    if [ -d "$HOME/.agents/skills" ] && [ -d "${skillDir}" ]; then
      for _global_skill_dir in "$HOME/.agents/skills"/*/; do
        [ -d "$_global_skill_dir" ] || continue
        _skill_name=$(basename "$_global_skill_dir")
        _pi_skill="${skillDir}/$_skill_name"
        if [ -e "$_pi_skill" ] || [ -L "$_pi_skill" ]; then
          rm -rf "$_pi_skill"
          echo "agents: removed duplicate Pi skill '$_skill_name' (already in ~/.agents/skills)"
        fi
      done
    fi
  '';

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
  home.activation.fixPiPathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] (
    shared.mkFixPathConflicts [
      skillDir
      extensionsDir
      themesDir
    ]
  );

  home.activation.installPiSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    skills.mkAgentSkillInstall {
      agentId = "pi";
      inherit skillDir;
      localSkillsRelPath = "agents/pi/skills";
    }
  );

  home.activation.dedupePiGlobalSkills = lib.hm.dag.entryAfter [ "installPiSkills" ] removePiGlobalSkillDuplicates;

  home.activation.preparePiInstructionsForRtk = lib.hm.dag.entryBefore [ "installPiRtkHooks" ] (
    instructions.removeStaleInstructionSymlink { target = instructionsTarget; }
  );

  home.activation.installPiRtkHooks = lib.hm.dag.entryAfter [ "installPiSkills" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--agent pi";
      label = "pi";
    }
  );

  home.activation.writePiInstructions = lib.hm.dag.entryAfter [ "installPiRtkHooks" ] (
    instructions.writeAgentInstructions { target = instructionsTarget; }
  );

  home.activation.configurePiMcpServers = lib.hm.dag.entryAfter [ "installPiSkills" ] (
    managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = declaredMcpEntries;
      stateId = "pi-mcp-servers";
    }
  );

  home.activation.installPiPackages = lib.hm.dag.entryAfter [ "installPiSkills" ] (
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

  home.activation.installPiConfig = lib.hm.dag.entryAfter [ "installPiSkills" ] ''
    # ── Extensions and themes ─────────────────────────────────────────────────
    ${syncPiExtensions}
    ${syncPiThemes}

    # ── Settings (provider, model, packages, skill paths) ─────────────────────
    ${nodeBin}/node ${scriptsDir}/apply-pi-settings.js

    # ── Understand-Anything plugin (Pi-only, requires full repo clone) ─────────
    ${installUnderstandAnythingPlugin}
  '';
}
