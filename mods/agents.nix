# agents.nix — Declarative multi-agent configuration
#
# Manages skills, commands, and RTK hooks across all AI coding agents:
#   claude-code, cursor, gemini-cli, codex, opencode
#
# ARCHITECTURE
# ─────────────────────────────────────────────────────────────────────────────
# ~/.agents/skills/<name>/          Global skill store (managed by skills@latest)
#   ├── shared from dotfiles         mods/dotfiles/agents/shared-skills/<name>/
#   └── community (from git repos)   installed via activation hook
#
# Per-agent skill dirs receive symlinks from ~/.agents/skills/:
#   ~/.claude/skills/<name>
#   ~/.cursor/skills/<name>
#   ~/.gemini/antigravity/skills/<name>  (antigravity layer)
#   ~/.codex/skills/<name>
#   ~/.config/opencode/skills/<name>
#
# Per-agent dotfiles (commands) live in:
#   mods/dotfiles/agents/<agent>/
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
#   - shared-skills/  → all agents
#   - <agent>/skills/ → that agent only
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
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles";

  # ── Community skill sources ─────────────────────────────────────────────
  # `agents` uses skill CLI IDs (lowercase, hyphened).
  # Valid IDs: claude-code, cursor, gemini-cli, codex, opencode,
  #            amp, antigravity, augment, cline, codebuddy, continue,
  #            github-copilot, goose, windsurf, and many more.
  agentCommunitySkillSources = [
    {
      repo = "https://github.com/anthropics/skills";
      skills = [
        "skill-creator"
        "doc-coauthoring"
      ];
      agents = [
        "claude-code"
        "cursor"
        "gemini-cli"
        "opencode"
        "codex"
      ];
    }
    {
      repo = "intellectronica/agent-skills";
      skills = [
        "context7"
      ];
      agents = [
        "claude-code"
        "cursor"
        "gemini-cli"
        "opencode"
        "codex"
      ];
    }
  {
       repo = "https://github.com/microsoft/playwright-cli";
       skills = [
         "playwright-cli"
       ];
       agents = [
         "claude-code"
         "cursor"
         "gemini-cli"
         "opencode"
         "codex"
       ];
    }
    {
      repo = "https://github.com/langchain-ai/deepagents";
      skills = [ "web-research" ];
      agents = [
        "claude-code"
        "cursor"
        "gemini-cli"
        "opencode"
        "codex"
      ];
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
    in
    ''
      skills add ${lib.escapeShellArg source.repo} --global ${agentArgs} --yes --copy ${skillArgs}
    '';

  communitySkillCmds = builtins.concatStringsSep "\n" (
    map mkCommunitySkillCmd agentCommunitySkillSources
  );

  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";

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
          "$HOME/.codex/skills"; do
          if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
            echo "agents: removing stale non-directory at $p"
            rm -rf "$p"
          fi
        done
      '';

      # Sync local skills from dotfiles into agent dirs, then install community skills.
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
          "$HOME/.codex/skills"

        # ── Shared local skills → all agents via ~/.agents/skills/ ──────────
        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/shared-skills";
          targetAbsPath = "${home}/.agents/skills";
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

        # ── Per-agent local commands (claude slash commands) ─────────────────
        ${mkLocalSkillSyncScript {
          sourceRelPath = "agents/claude/commands";
          targetAbsPath = "${home}/.claude/commands";
        }}

        # ── Community skills (from git repos, copied into agent dirs) ────────
        ${communitySkillCmds}
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
    };
  };
}
