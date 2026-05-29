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
# Pi extensions are symlinked from:
#   mods/dotfiles/agents/pi/extensions/*.js and *.ts
# into:
#   ~/.pi/agent/extensions/
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
  allAgentsExceptPi = builtins.filter (agent: agent != "pi") allAgents;
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
      ];
      agents = allAgentsExceptPi;
    }
    # Temporarily disabled. Restore this block to reinstall superpowers skills.
    # {
    #   repo = "obra/superpowers";
    #   skills = [
    #     "brainstorming"
    #     "using-superpowers"
    #     "systematic-debugging"
    #     "writing-plans"
    #     "test-driven-development"
    #     "requesting-code-review"
    #     "executing-plans"
    #     "subagent-driven-development"
    #     "verification-before-completion"
    #     "receiving-code-review"
    #     "writing-skills"
    #     "dispatching-parallel-agents"
    #     "using-git-worktrees"
    #     "finishing-a-development-branch"
    #   ];
    #   agents = allAgentsExceptPi;
    # }
    {
      repo = "intellectronica/agent-skills";
      skills = [
        "context7"
      ];
      agents = allAgentsExceptPi;
    }
    {
      repo = "https://github.com/addyosmani/agent-skills";
      skills = [
        "code-simplification"
      ];
      agents = allAgentsExceptPi;
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
        "to-prd"
        "to-issues"
      ];
      agents = allAgentsExceptPi;
    }
    {
      repo = "https://github.com/arjunmahishi/dotfiles";
      skills = [
        "acli-jira"
      ];
      agents = allAgentsExceptPi;
    }
    {
      repo = "https://github.com/napisani/axion-skills";
      skills = [
        "axion-jira"
        "axion-local-db-access"
        "axion-pr-workflow"
        "raygun-script-all-script-writer"
      ];
      agents = allAgentsExceptPi;
    }
    {
      repo = "https://github.com/microsoft/playwright-cli";
      skills = [
        "playwright-cli"
      ];
      agents = allAgentsExceptPi;
    }
    {
      repo = "https://github.com/langchain-ai/deepagents";
      skills = [ "web-research" ];
      agents = allAgentsExceptPi;
    }
    {
      repo = "https://github.com/softaworks/agent-toolkit";
      skills = [ "mermaid-diagrams" ];
      agents = allAgentsExceptPi;
    }
  ]
  ++ lib.optionals isAxionMac [
    {
      repo = "https://github.com/datadog-labs/agent-skills";
      skills = [ "dd-logs" ];
      agents = allAgentsExceptPi;
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
          "$HOME/.pi/agent/extensions"; do
          if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
            echo "agents: removing stale non-directory at $p"
            rm -rf "$p"
          fi
        done
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
      installAgentSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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
          "$HOME/.pi/agent/extensions"

        # ── Community skills (from git repos, copied into agent dirs) ────────
        ${communitySkillCmds}

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

        # ── Pi local extensions ─────────────────────────────────────────────
        ${syncPiExtensions}

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
