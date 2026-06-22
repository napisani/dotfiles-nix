# agents.nix — Declarative multi-agent configuration
#
# Manages skills, commands, and RTK hooks across all AI coding agents:
#   claude-code, cursor, gemini-cli, codex, opencode, pi
#
# ARCHITECTURE
# ─────────────────────────────────────────────────────────────────────────────
# ~/.agents/skills/<name>/          Global skill store (managed by skills@latest)
#   ├── shared from dotfiles         mods/dotfiles/agents/shared-skills/<name>/
#   ├── Axion from git               github.com/napisani/axion-skills
#   └── community (from git repos)   installed via activation hook
#
# Per-agent skill dirs receive symlinks from ~/.agents/skills/:
#   ~/.claude/skills/<name>
#   ~/.cursor/skills/<name>
#   ~/.gemini/antigravity/skills/<name>  (antigravity layer)
#   ~/.codex/skills/<name>
#   ~/.config/opencode/skills/<name>
#
# Pi is the exception: it auto-discovers both ~/.pi/agent/skills and
# ~/.agents/skills. Shared/community skills must live only in ~/.agents/skills
# for Pi, otherwise Pi reports name collisions at startup.
#
# Pi extensions, themes, and MCP config are symlinked from:
#   mods/dotfiles/agents/pi/extensions/*.js and *.ts
#   mods/dotfiles/agents/pi/themes/*.json
#   mods/dotfiles/agents/pi/mcp.json
# into:
#   ~/.pi/agent/extensions/
#   ~/.pi/agent/themes/
#   ~/.pi/agent/mcp.json
#
# Per-agent dotfiles (commands) live in:
#   mods/dotfiles/agents/<agent>/
#
# Shared agent instructions live in one editable base file:
#   mods/dotfiles/agents/AGENTS.md
# Applied after RTK hook installation to:
#   ~/.codex/AGENTS.md
#   ~/.config/opencode/AGENTS.md
#   ~/.claude/CLAUDE.md
#   ~/.gemini/GEMINI.md
#   ~/.pi/agent/AGENTS.md
#
# SKILLS INSTALLATION MATRIX
# ─────────────────────────────────────────────────────────────────────────────
# Community skill sources (see `agentCommunitySkillSources` below) declare:
#   - repo: GitHub URL of skills package
#   - skills: list of skill names to install from that repo
#   - agents: list of agent IDs (see `skills --help` for valid IDs)
#     Use ["*"] to install to all known agents.
#
# Local skills (from dotfiles, always current without rebuilding):
#   - shared-skills/  → ~/.agents/skills + non-Pi agent skill dirs
#   - <agent>/skills/ → that agent only
#
# Axion-specific skills are installed from:
#   https://github.com/napisani/axion-skills
#
# RTK HOOKS
# ─────────────────────────────────────────────────────────────────────────────
# RTK (Rust Token Killer) hooks are installed by `rtk init -g` per-agent.
# The installRtkHooks activation runs after linkGeneration when rtk is on PATH.
# Each agent uses its own init flag:
#   Claude Code:  rtk init -g --auto-patch
#   Cursor:       rtk init -g --agent cursor
#   Gemini CLI:   rtk init -g --gemini
#   Codex:        rtk init -g --codex
#   OpenCode:     rtk init -g --opencode
#   Pi:           no rtk init target in the current rtk CLI
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles";
  allAgents = [
    "claude-code"
    "cursor"
    "gemini-cli"
    "opencode"
    "codex"
    "pi"
  ];
  isAxionMac = (config.home.sessionVariables.MACHINE_NAME or "") == "axion-mbp";

  # ── Community skill sources ─────────────────────────────────────────────
  # `agents` uses skill CLI IDs (lowercase, hyphened).
  # Valid IDs: claude-code, cursor, gemini-cli, codex, opencode, pi,
  #            amp, antigravity, augment, cline, codebuddy, continue,
  #            github-copilot, goose, windsurf, and many more.
  agentCommunitySkillSources = [
    {
      repo = "https://github.com/anthropics/skills";
      skills = [
        "skill-creator"
        "doc-coauthoring"
        "frontend-design"
      ];
      agents = allAgents;
    }
    {
      repo = "intellectronica/agent-skills";
      skills = [
        "context7"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/addyosmani/agent-skills";
      skills = [
        "code-simplification"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/obra/superpowers";
      skills = [
        "brainstorming"
        "systematic-debugging"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/mattpocock/skills";
      skills = [
        "diagnose"
        "grill-me"
        "grill-with-docs"
        "handoff"
        "improve-codebase-architecture"
        "tdd"
        "write-a-skill"
        "to-prd"
        "to-issues"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/arjunmahishi/dotfiles";
      skills = [
        "acli-jira"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/napisani/axion-skills";
      skills = [
        "axion-jira"
        "axion-local-db-access"
        "axion-mcp-trace-analysis"
        "axion-pr-workflow"
        "raygun-script-all-script-writer"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/napisani/proctmux";
      skills = [ "proctmux-config" ];
      agents = allAgents;
      fullDepth = true;
    }
    {
      repo = "https://github.com/napisani/vantage-nvim";
      skills = [ "vantage-distill-session" ];
      agents = allAgents;
      fullDepth = true;
    }
    {
      repo = "https://github.com/microsoft/playwright-cli";
      skills = [
        "playwright-cli"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/langchain-ai/deepagents";
      skills = [ "web-research" ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/softaworks/agent-toolkit";
      skills = [ "mermaid-diagrams" ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/Lum1104/Understand-Anything";
      skills = [
        "understand"
        "understand-chat"
        "understand-dashboard"
        "understand-diff"
        "understand-domain"
        "understand-explain"
        "understand-knowledge"
        "understand-onboard"
      ];
      agents = [ "pi" ];
      fullDepth = true;
    }
  ]
  ++ lib.optionals isAxionMac [
    {
      repo = "https://github.com/datadog-labs/agent-skills";
      skills = [ "dd-logs" ];
      agents = allAgents;
      fullDepth = true;
    }
  ];

  mkCommunitySkillCmd =
    source:
    let
      agentArgs = builtins.concatStringsSep " " (
        map (a: "--agent ${lib.escapeShellArg a}") source.agents
      );
      skillArgs = builtins.concatStringsSep " " (
        map (s: "--skill ${lib.escapeShellArg s}") source.skills
      );
      fullDepthArg = lib.optionalString (source.fullDepth or false) " --full-depth";
    in
    ''
      skills add ${lib.escapeShellArg source.repo} --global ${agentArgs} --yes --copy ${skillArgs}${fullDepthArg}
    '';

  communitySkillCmds = builtins.concatStringsSep "\n" (
    map mkCommunitySkillCmd agentCommunitySkillSources
  );

  agentSkillTargets = {
    claude-code = "${home}/.claude/skills";
    cursor = "${home}/.cursor/skills";
    gemini-cli = "${home}/.gemini/skills";
    opencode = "${home}/.config/opencode/skills";
    codex = "${home}/.codex/skills";
    pi = "${home}/.pi/agent/skills";
  };

  agentsForCleanup =
    agents: if builtins.elem "*" agents then builtins.attrNames agentSkillTargets else agents;

  mkCommunitySkillCleanupCmds =
    source:
    builtins.concatStringsSep "\n" (
      lib.flatten (
        map (
          agent:
          let
            target = agentSkillTargets.${agent} or "";
          in
          lib.optionals (target != "") (
            map (
              skill: "_remove_managed_skill ${lib.escapeShellArg target} ${lib.escapeShellArg skill}"
            ) source.skills
          )
        ) (agentsForCleanup source.agents)
      )
    );

  communitySkillCleanupCmds = builtins.concatStringsSep "\n" (
    map mkCommunitySkillCleanupCmds agentCommunitySkillSources
  );

  # Pi discovers ~/.agents/skills in addition to ~/.pi/agent/skills. Keep Pi's
  # agent-local directory for Pi-only skills, and delete duplicate entries that
  # are already available through the global store.
  removePiGlobalSkillDuplicates = ''
    if [ -d "$HOME/.agents/skills" ] && [ -d "$HOME/.pi/agent/skills" ]; then
      for _global_skill_dir in "$HOME/.agents/skills"/*/; do
        [ -d "$_global_skill_dir" ] || continue
        _skill_name=$(basename "$_global_skill_dir")
        _pi_skill="$HOME/.pi/agent/skills/$_skill_name"
        if [ -e "$_pi_skill" ] || [ -L "$_pi_skill" ]; then
          rm -rf "$_pi_skill"
          echo "agents: removed duplicate Pi skill '$_skill_name' already provided by ~/.agents/skills"
        fi
      done
    fi
  '';

  syncPiExtensions = ''
    _src="${dotfiles}/agents/pi/extensions"
    _dst="$HOME/.pi/agent/extensions"
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
    _dst="$HOME/.pi/agent/themes"
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

  syncPiMcpConfig = ''
    _src="${dotfiles}/agents/pi/mcp.json"
    _dst="$HOME/.pi/agent/mcp.json"
    mkdir -p "$(dirname "$_dst")"

    if [ -f "$_src" ]; then
      if [ -e "$_dst" ] && [ ! -L "$_dst" ]; then
        echo "agents: refusing to replace non-symlink Pi MCP config at $_dst"
      elif [ ! -L "$_dst" ] || [ "$(readlink "$_dst")" != "$_src" ]; then
        ln -sfn "$_src" "$_dst"
        echo "agents: linked Pi MCP config -> $_dst"
      fi
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

  applyWorkmuxStatusHooks = ''
    ${nodeBin}/node <<'NODE'
    const fs = require("node:fs");
    const path = require("node:path");

    const home = process.env.HOME;
    const dotfiles = ${builtins.toJSON dotfiles};
    const sourceDir = path.join(dotfiles, "agents", "workmux-status");

    function readJson(file, fallback) {
      try {
        if (!fs.existsSync(file)) return fallback;
        return JSON.parse(fs.readFileSync(file, "utf8"));
      } catch (error) {
        console.error("agents: refusing to update invalid JSON at " + file + ": " + error.message);
        return null;
      }
    }

    function writeJsonIfChanged(file, value) {
      const next = JSON.stringify(value, null, 2) + "\n";
      const current = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
      if (current === next) return;
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, next);
      console.log("agents: applied Workmux status hooks -> " + file);
    }

    function containsWorkmuxStatusCommand(value) {
      if (typeof value === "string") return value.includes("workmux set-window-status");
      if (Array.isArray(value)) return value.some(containsWorkmuxStatusCommand);
      if (value && typeof value === "object") return Object.values(value).some(containsWorkmuxStatusCommand);
      return false;
    }

    function mergeHookMap(targetFile, sourceFile) {
      const sourceHooks = readJson(sourceFile, null);
      const target = readJson(targetFile, {});
      if (!sourceHooks || !target) return;

      const hooks = target.hooks && typeof target.hooks === "object" && !Array.isArray(target.hooks)
        ? target.hooks
        : {};

      for (const [eventName, desiredEntries] of Object.entries(sourceHooks)) {
        const existingEntries = Array.isArray(hooks[eventName]) ? hooks[eventName] : [];
        hooks[eventName] = [
          ...existingEntries.filter((entry) => !containsWorkmuxStatusCommand(entry)),
          ...desiredEntries,
        ];
      }

      target.hooks = hooks;
      writeJsonIfChanged(targetFile, target);
    }

    function mergeCodexHooks(targetFile, sourceFile) {
      const source = readJson(sourceFile, null);
      const target = readJson(targetFile, {});
      if (!source || !target) return;

      const hooks = target.hooks && typeof target.hooks === "object" && !Array.isArray(target.hooks)
        ? target.hooks
        : {};

      for (const [eventName, desiredEntries] of Object.entries(source)) {
        const existingEntries = Array.isArray(hooks[eventName]) ? hooks[eventName] : [];
        hooks[eventName] = [
          ...existingEntries.filter((entry) => !containsWorkmuxStatusCommand(entry)),
          ...desiredEntries,
        ];
      }

      target.hooks = hooks;
      writeJsonIfChanged(targetFile, target);
    }

    function codexEventKey(eventName) {
      return eventName.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
    }

    function codexWorkmuxHookKeys(hooksFile) {
      const config = readJson(hooksFile, null);
      const hooks = config && config.hooks && typeof config.hooks === "object" && !Array.isArray(config.hooks)
        ? config.hooks
        : {};
      const keys = [];

      for (const [eventName, groups] of Object.entries(hooks)) {
        if (!Array.isArray(groups)) continue;
        groups.forEach((group, groupIndex) => {
          const handlers = group && Array.isArray(group.hooks) ? group.hooks : [];
          handlers.forEach((handler, handlerIndex) => {
            if (containsWorkmuxStatusCommand(handler)) {
              keys.push(hooksFile + ":" + codexEventKey(eventName) + ":" + groupIndex + ":" + handlerIndex);
            }
          });
        });
      }

      return keys;
    }

    function tomlSection(lines, header) {
      const start = lines.findIndex((line) => line.trim() === header);
      if (start === -1) return null;

      let end = lines.length;
      for (let index = start + 1; index < lines.length; index += 1) {
        if (/^\s*\[[^\n]+\]\s*$/.test(lines[index])) {
          end = index;
          break;
        }
      }

      return { start, end };
    }

    function ensureCodexHooksEnabled(configFile, hooksFile) {
      const original = fs.existsSync(configFile) ? fs.readFileSync(configFile, "utf8") : "";
      const lines = original.trim() ? original.replace(/\n+$/, "").split("\n") : [];

      const featuresHeader = "[features]";
      const features = tomlSection(lines, featuresHeader);
      if (features) {
        let foundHooksFlag = false;
        for (let index = features.start + 1; index < features.end; index += 1) {
          if (/^\s*hooks\s*=/.test(lines[index])) {
            foundHooksFlag = true;
            if (!/^\s*hooks\s*=\s*true\s*(#.*)?$/.test(lines[index])) {
              lines[index] = "hooks = true";
            }
          }
        }
        if (!foundHooksFlag) {
          lines.splice(features.start + 1, 0, "hooks = true");
        }
      } else {
        if (lines.length && lines[lines.length - 1] !== "") lines.push("");
        lines.push(featuresHeader, "hooks = true");
      }

      for (const key of codexWorkmuxHookKeys(hooksFile)) {
        const header = "[hooks.state." + JSON.stringify(key) + "]";
        const section = tomlSection(lines, header);
        if (!section) continue;

        for (let index = section.start + 1; index < section.end; index += 1) {
          if (/^\s*enabled\s*=\s*false\s*(#.*)?$/.test(lines[index])) {
            lines[index] = "enabled = true";
          }
        }
      }

      const next = lines.join("\n") + "\n";
      if (next !== original) {
        fs.mkdirSync(path.dirname(configFile), { recursive: true });
        fs.writeFileSync(configFile, next);
        console.log("agents: ensured Codex Workmux hooks are enabled -> " + configFile);
      }
    }

    const codexHooksFile = path.join(home, ".codex", "hooks.json");

    mergeHookMap(path.join(home, ".claude", "settings.json"), path.join(sourceDir, "claude-hooks.json"));
    mergeHookMap(path.join(home, ".gemini", "settings.json"), path.join(sourceDir, "gemini-hooks.json"));
    mergeCodexHooks(codexHooksFile, path.join(sourceDir, "codex-hooks.json"));
    ensureCodexHooksEnabled(path.join(home, ".codex", "config.toml"), codexHooksFile);
    NODE
  '';

  applyPiSettings = ''
    _settings="$HOME/.pi/agent/settings.json"
    mkdir -p "$(dirname "$_settings")"

    ${nodeBin}/node -e '
      const fs = require("node:fs");
      const path = process.env.HOME + "/.pi/agent/settings.json";

      let settings = {};
      if (fs.existsSync(path)) {
        try {
          settings = JSON.parse(fs.readFileSync(path, "utf8"));
        } catch (error) {
          console.error("agents: refusing to update invalid Pi settings JSON at " + path + ": " + error.message);
          process.exit(0);
        }
      }

      const managed = {
        defaultProvider: "openai-codex",
        defaultModel: "gpt-5.5",
        defaultThinkingLevel: "xhigh",
        theme: "kanagawa",
      };
      const managedSkills = [
        "~/code/*/apps/*/.agents/skills",
      ];
      const managedPackages = [
        "npm:@ayulab/pi-rewind",
        "npm:pi-mcp-adapter",
      ];
      const removedPackages = new Set([
        "npm:pi-subagents",
      ]);

      let changed = false;
      for (const [key, value] of Object.entries(managed)) {
        if (settings[key] !== value) {
          settings[key] = value;
          changed = true;
        }
      }

      const currentOpenAI = settings.openaiReasoningMode && typeof settings.openaiReasoningMode === "object"
        ? settings.openaiReasoningMode
        : {};
      if (currentOpenAI.fast !== true) {
        settings.openaiReasoningMode = { ...currentOpenAI, fast: true };
        changed = true;
      }

      const currentPackages = Array.isArray(settings.packages) ? settings.packages : [];
      const nextPackages = currentPackages.filter((packageSource) => !removedPackages.has(packageSource));
      let packagesChanged = !Array.isArray(settings.packages) || nextPackages.length !== currentPackages.length;
      for (const packageSource of managedPackages) {
        if (!nextPackages.includes(packageSource)) {
          nextPackages.push(packageSource);
          packagesChanged = true;
        }
      }
      if (packagesChanged) {
        settings.packages = nextPackages;
        changed = true;
      }

      const currentSkills = Array.isArray(settings.skills) ? settings.skills : [];
      const nextSkills = [...currentSkills];
      let skillsChanged = !Array.isArray(settings.skills);
      for (const skillPath of managedSkills) {
        if (!nextSkills.includes(skillPath)) {
          nextSkills.push(skillPath);
          skillsChanged = true;
        }
      }
      if (skillsChanged) {
        settings.skills = nextSkills;
        changed = true;
      }

      if (changed) {
        fs.writeFileSync(path, JSON.stringify(settings, null, 2) + "\n");
        console.log("agents: applied Pi defaults -> openai-codex/gpt-5.5/xhigh, fast:on, theme:kanagawa, monorepo app skills, managed Pi packages");
      }
    '
  '';

  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
  sharedAgentInstructions = "${dotfiles}/agents/AGENTS.md";

  # Activation script: symlink all subdirs of a dotfiles source dir into a target dir.
  # Creates target/<name> → source/<name> for each entry, without touching other entries.
  mkLocalSkillSyncScript =
    { sourceRelPath, targetAbsPath }:
    let
      sourcePath = "${dotfiles}/${sourceRelPath}";
    in
    ''
      _src="${sourcePath}"
      _dst="${targetAbsPath}"
      mkdir -p "$_dst"
      if [ -d "$_src" ]; then
        for _skill_dir in "$_src"/*/; do
          [ -d "$_skill_dir" ] || continue
          _skill_name=$(basename "$_skill_dir")
          _target_link="$_dst/$_skill_name"
          # If it's a real directory (not a symlink), remove it so ln can replace it.
          if [ -d "$_target_link" ] && [ ! -L "$_target_link" ]; then
            rm -rf "$_target_link"
          fi
          if [ ! -L "$_target_link" ] || [ "$(readlink "$_target_link")" != "$_skill_dir" ]; then
            ln -sfn "$_skill_dir" "$_target_link"
            echo "agents: linked skill '$_skill_name' → $_target_link"
          fi
        done
      fi
    '';

  home = config.home.homeDirectory;
in
{
  home = {
    activation = {
      # Remove stale files that must be dirs (skills@latest requires dirs, not symlinks).
      fixAgentPathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
        for p in \
          "$HOME/.agents/skills" \
          "$HOME/.claude/skills" \
          "$HOME/.claude/commands" \
          "$HOME/.cursor/skills" \
          "$HOME/.gemini/skills" \
          "$HOME/.gemini/antigravity/skills" \
          "$HOME/.codex/skills" \
          "$HOME/.pi/agent/skills" \
          "$HOME/.pi/agent/extensions" \
          "$HOME/.pi/agent/themes"; do
          if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
            echo "agents: removing stale non-directory at $p"
            rm -rf "$p"
          fi
        done
      '';

      cleanupLegacyAgentInstalls = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        _remove_managed_skill() {
          _target_dir="$1"
          _skill_name="$2"
          _target="$_target_dir/$_skill_name"

          if [ -e "$_target" ] || [ -L "$_target" ]; then
            rm -rf "$_target"
            echo "agents: removed legacy managed skill $_target"
          fi
        }

        _cleanup_local_skill_source() {
          _src="$1"
          _dst="$2"

          [ -d "$_src" ] || return 0

          for _skill_dir in "$_src"/*/; do
            [ -d "$_skill_dir" ] || continue
            _remove_managed_skill "$_dst" "$(basename "$_skill_dir")"
          done
        }

        # Community skills copied by skills@latest. Remove only names declared
        # in this module so old manual installs are replaced without touching
        # unrelated user skills.
        ${communitySkillCleanupCmds}

        # Local skills managed by this repo. They will be recreated as symlinks
        # by installAgentSkills.
        _cleanup_local_skill_source "${dotfiles}/agents/shared-skills" "${home}/.agents/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/shared-skills" "${home}/.claude/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/shared-skills" "${home}/.cursor/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/shared-skills" "${home}/.gemini/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/shared-skills" "${home}/.gemini/antigravity/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/shared-skills" "${home}/.codex/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/shared-skills" "${home}/.config/opencode/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/claude/skills" "${home}/.claude/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/cursor/skills" "${home}/.cursor/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/gemini/skills" "${home}/.gemini/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/gemini/skills" "${home}/.gemini/antigravity/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/codex/skills" "${home}/.codex/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/opencode/skills" "${home}/.config/opencode/skills"
        _cleanup_local_skill_source "${dotfiles}/agents/pi/skills" "${home}/.pi/agent/skills"

      '';

      # Previous versions symlinked these files back into the dotfiles repo.
      # RTK writes global agent instruction files during init, so remove those
      # symlinks before RTK runs to keep repo-managed instructions immutable.
      prepareAgentInstructionsForRtk = lib.hm.dag.entryBefore [ "installRtkHooks" ] ''
        for p in \
          "$HOME/.codex/AGENTS.md" \
          "$HOME/.config/opencode/AGENTS.md" \
          "$HOME/.claude/CLAUDE.md" \
          "$HOME/.gemini/GEMINI.md" \
          "$HOME/.pi/agent/AGENTS.md"; do
          if [ -L "$p" ]; then
            echo "agents: removing old instruction symlink at $p"
            rm -f "$p"
          fi
        done
      '';

      # Install community skills, then overlay local dotfile skills.
      # Local skills intentionally run last so repo-managed fixes and overrides
      # replace copied community skill dirs with live symlinks.
      installAgentSkills = lib.hm.dag.entryAfter [ "cleanupLegacyAgentInstalls" ] ''
        export DISABLE_TELEMETRY=1
        export NPM_CONFIG_PREFIX="$HOME/.local"
        export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

        mkdir -p \
          "$HOME/.agents/skills" \
          "$HOME/.claude/skills" \
          "$HOME/.claude/commands" \
          "$HOME/.cursor/skills" \
          "$HOME/.gemini/skills" \
          "$HOME/.gemini/antigravity/skills" \
          "$HOME/.codex/skills" \
          "$HOME/.pi/agent/skills" \
          "$HOME/.pi/agent/extensions" \
          "$HOME/.pi/agent/themes"

        _reset_managed_skill_dir() {
          _dst="$1"
          [ -d "$_dst" ] || return 0

          # Skills are declarative in this module: each activation rebuilds the
          # managed skill directories from agentCommunitySkillSources and local
          # dotfiles. Preserve hidden/system entries such as Codex's .system.
          for _entry in "$_dst"/*; do
            [ -e "$_entry" ] || [ -L "$_entry" ] || continue
            rm -rf "$_entry"
          done
        }

        for _managed_skill_dir in \
          "$HOME/.agents/skills" \
          "$HOME/.claude/skills" \
          "$HOME/.cursor/skills" \
          "$HOME/.gemini/skills" \
          "$HOME/.gemini/antigravity/skills" \
          "$HOME/.codex/skills" \
          "$HOME/.config/opencode/skills" \
          "$HOME/.pi/agent/skills"; do
          _reset_managed_skill_dir "$_managed_skill_dir"
        done

        # ── Community skills (from git repos, copied into agent dirs) ────────
        if command -v skills >/dev/null 2>&1; then
          ${communitySkillCmds}
        else
          echo "agents: 'skills' command not found — skipping community skill installs" >&2
          echo "agents: run 'npm install -g skills@latest' then 'darwin-rebuild switch' to fix" >&2
        fi

        # ── Shared local skills → global store + non-Pi agent dirs ──────────
        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.agents/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.claude/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.cursor/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.gemini/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.gemini/antigravity/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.codex/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.config/opencode/skills";
        }}

        # ── Per-agent local skills ───────────────────────────────────────────
        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/claude/skills";
          targetAbsPath = "${home}/.claude/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/cursor/skills";
          targetAbsPath = "${home}/.cursor/skills";
        }}

        # gemini-cli native skills dir (~/.gemini/skills/) — used by `gemini` TUI directly
        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/gemini/skills";
          targetAbsPath = "${home}/.gemini/skills";
        }}

        # antigravity extension skills dir (~/.gemini/antigravity/skills/) — used by the antigravity plugin
        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/gemini/skills";
          targetAbsPath = "${home}/.gemini/antigravity/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/codex/skills";
          targetAbsPath = "${home}/.codex/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/opencode/skills";
          targetAbsPath = "${home}/.config/opencode/skills";
        }}

        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/pi/skills";
          targetAbsPath = "${home}/.pi/agent/skills";
        }}

        # ── Pi-only Understand-Anything plugin root ─────────────────────────
        ${installUnderstandAnythingPlugin}

        # ── Workmux status tracking hooks ───────────────────────────────────
        ${applyWorkmuxStatusHooks}

        # ── Pi local extensions, themes, and MCP config ─────────────────────
        ${syncPiExtensions}
        ${syncPiThemes}
        ${syncPiMcpConfig}
        ${applyPiSettings}

        # Pi also discovers ~/.agents/skills, so remove stale/accidental copies
        # from ~/.pi/agent/skills when the same skill exists globally.
        ${removePiGlobalSkillDuplicates}

        # ── Per-agent local commands (claude slash commands) ─────────────────
        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/claude/commands";
          targetAbsPath = "${home}/.claude/commands";
        }}
      '';

      # Install RTK Bash-rewrite hooks for each agent when rtk is available.
      # RTK intercepts shell tool calls and transparently rewrites commands
      # (e.g. `git status` → `rtk git status`) for token savings.
      # Re-runs on every switch so hooks stay up to date with rtk upgrades.
      installRtkHooks = lib.hm.dag.entryAfter [ "installAgentSkills" ] ''
        export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

        if command -v rtk >/dev/null 2>&1; then
          echo "agents: installing RTK hooks ($(rtk --version 2>/dev/null || echo unknown))"

          rtk init -g --auto-patch       && echo "agents: RTK hook installed for claude-code" || echo "agents: WARNING: RTK hook failed for claude-code"
          rtk init -g --agent cursor     && echo "agents: RTK hook installed for cursor"      || echo "agents: WARNING: RTK hook failed for cursor"
          rtk init -g --gemini           && echo "agents: RTK hook installed for gemini-cli"  || echo "agents: WARNING: RTK hook failed for gemini-cli"
          rtk init -g --codex            && echo "agents: RTK hook installed for codex"       || echo "agents: WARNING: RTK hook failed for codex"
          rtk init -g --opencode         && echo "agents: RTK hook installed for opencode"    || echo "agents: WARNING: RTK hook failed for opencode"
        else
          echo "agents: rtk not found on PATH — skipping RTK hook installation (install via: brew install rtk)"
        fi
      '';

      # Write normal files, not symlinks. RTK may write these paths during init;
      # this step deliberately restores the single repo-managed instruction body
      # afterward so all agents receive identical global context.
      applySharedAgentInstructions = lib.hm.dag.entryAfter [ "installRtkHooks" ] ''
        _base="${sharedAgentInstructions}"

        _write_agent_instructions() {
          _target="$1"

          mkdir -p "$(dirname "$_target")"

          if [ -d "$_target" ] && [ ! -L "$_target" ]; then
            echo "agents: refusing to replace directory at $_target"
            return 0
          fi

          _tmp="$(mktemp)"
          cat "$_base" > "$_tmp"
          mv "$_tmp" "$_target"
          echo "agents: wrote shared instructions -> $_target"
        }

        _write_agent_instructions "$HOME/.codex/AGENTS.md"
        _write_agent_instructions "$HOME/.config/opencode/AGENTS.md"
        _write_agent_instructions "$HOME/.claude/CLAUDE.md"
        _write_agent_instructions "$HOME/.gemini/GEMINI.md"
        _write_agent_instructions "$HOME/.pi/agent/AGENTS.md"
      '';
    };
  };
}
