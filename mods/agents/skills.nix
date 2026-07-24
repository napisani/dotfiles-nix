# agents/skills.nix — Skill catalog + per-agent install/prune utility
#
# agentSkillSources is the single declared catalog: DRY data, targeting N
# agents from one entry (still fine to share — the coupling problem was
# scripts branching on agent identity, not data lists; see
# docs/adr/0001-per-agent-modules.md). This file owns no home.activation of
# its own. Each agent module calls `mkAgentSkillInstall` itself with its own
# agentId + skillDir to get an activation script scoped to that one agent,
# and decides its own activation ordering.
#
# Catalog entry fields:
#   repo       — GitHub URL or owner/repo shorthand
#   skills     — skill names to install from that repo
#   agents     — list of agent IDs (as used by the `skills` CLI) this entry targets
#   fullDepth  — clone with full history instead of --depth=1 (default: false)
#   condition  — boolean; when false the entry is skipped (default: true)
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname; };
  inherit (shared) dotfiles allAgents isLoancrateMac nodeBin gitBin;

  agentSkillSources = [
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
        "to-spec"
        "domain-modeling"
        "prototype"
        "diagnose"
        "caveman"
        "zoom-out"
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
      repo = "https://github.com/napisani/proctmux";
      skills = [ "proctmux-config" ];
      agents = allAgents;
      fullDepth = true;
    }
    {
      repo = "https://github.com/napisani/vantage-nvim";
      skills = [
        "vantage-distill-session"
        "vantage-author-walkthrough"
      ];
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
    {
      repo = "https://github.com/raine/workmux";
      skills = [ "worktree" ];
      agents = allAgents;
    }
    {
      repo = "rohitg00/agentmemory";
      skills = [
        "recall"
        "remember"
        "session-history"
        "forget"
        "handoff"
        "recap"
        "commit-context"
        "commit-history"
      ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/github/gh-stack";
      skills = [ "gh-stack" ];
      agents = allAgents;
    }
    {
      repo = "https://github.com/petergyang/no-ai-slop";
      skills = [ "no-ai-slop" ];
      agents = allAgents;
    }
    # Loancrate-only: private skills
    {
      repo = "https://github.com/napisani/private-skills";
      skills = [
        "loancrate-pr-workflow"
        "loancrate-with-workmux-stack-handoff"
        "loancrate-standup-prep"
        "loancrate-analyze-agent-self-improve-trend"
        "loancrate-weekly-update-draft"
        "multi-valued-review"
        "mvr-suggestions"
      ];
      agents = allAgents;
      condition = isLoancrateMac;
    }
    # Loancrate-only: lc-script
    {
      repo = "https://github.com/napisani/lc-script";
      skills = [ "loancrate-lc-script" ];
      agents = allAgents;
      condition = isLoancrateMac;
    }
  ];

  enabledSkillSources = builtins.filter (s: s.condition or true) agentSkillSources;

  mkCommunitySkillCmd =
    agentId: source:
    let
      skillArgs = builtins.concatStringsSep " " (
        map (s: "--skill ${lib.escapeShellArg s}") source.skills
      );
      fullDepthArg = lib.optionalString (source.fullDepth or false) " --full-depth";
    in
    "skills add ${lib.escapeShellArg source.repo} --global --agent ${lib.escapeShellArg agentId} --yes --copy ${skillArgs}${fullDepthArg}";

  # Symlink each subdir of a dotfiles source into a target dir. Agent-blind:
  # takes paths, not agent identity. Creates target/<name> -> source/<name>
  # without disturbing unrelated entries already in targetAbsPath.
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
          if [ -d "$_target_link" ] && [ ! -L "$_target_link" ]; then
            rm -rf "$_target_link"
          fi
          if [ ! -L "$_target_link" ] || [ "$(readlink "$_target_link")" != "$_skill_dir" ]; then
            ln -sfn "$_skill_dir" "$_target_link"
            echo "agents: linked skill '$_skill_name' -> $_target_link"
          fi
        done
      fi
    '';

  # Wipe a managed directory (only non-hidden entries — preserves e.g.
  # Codex's .system) then let the rest of the script rebuild it fresh.
  # Agent-blind: takes a path, not agent identity.
  resetManagedDirFn = ''
    _reset_managed_dir() {
      _dst="$1"
      [ -d "$_dst" ] || return 0
      for _entry in "$_dst"/*; do
        [ -e "$_entry" ] || [ -L "$_entry" ] || continue
        rm -rf "$_entry"
      done
    }
  '';

  # The one thing every agent module calls: installs and prunes this agent's
  # community skills (filtered from the shared catalog by agentId) and its
  # local skill symlinks, scoped entirely to skillDir. True revocation: wipes
  # skillDir first, then rebuilds from current declared state, so removing a
  # catalog entry (or a file under localSkillsRelPath) actually disappears on
  # the next activation — matching the bar set in docs/adr/0001.
  #
  # Also wipes and rebuilds the shared global store ($HOME/.agents/skills)
  # on every call. This is deliberately safe to repeat once per agent (all
  # four modules call this): the global store only ever holds the same
  # agent-blind agents/shared-skills content regardless of which agent
  # triggered the rebuild, so re-wiping it from a second or third caller in
  # the same activation just reproduces the same result, not a race.
  mkAgentSkillInstall =
    {
      agentId,
      skillDir,
      localSkillsRelPath,
    }:
    let
      agentSources = builtins.filter (s: builtins.elem agentId (s.agents or [ ])) enabledSkillSources;
      communitySkillCmds = builtins.concatStringsSep "\n" (
        map (mkCommunitySkillCmd agentId) agentSources
      );
    in
    ''
      export DISABLE_TELEMETRY=1
      export NPM_CONFIG_PREFIX="$HOME/.local"
      export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

      mkdir -p "$HOME/.agents/skills" ${lib.escapeShellArg skillDir}

      ${resetManagedDirFn}
      _reset_managed_dir "$HOME/.agents/skills"
      _reset_managed_dir ${lib.escapeShellArg skillDir}

      # ── Community skills (from git repos) ─────────────────────────────────
      if command -v skills >/dev/null 2>&1; then
        ${communitySkillCmds}
      else
        echo "agents: 'skills' command not found — skipping community skill installs for ${agentId}" >&2
        echo "agents: run 'npm install -g skills@latest' then re-run activation to fix" >&2
      fi

      # ── Shared local skills → global store (Pi auto-discovers this) ───────
      ${mkLocalSkillSyncScript {
        sourceRelPath = "agents/shared-skills";
        targetAbsPath = "$HOME/.agents/skills";
      }}
      # ── Shared local skills → this agent's own skill dir ──────────────────
      ${mkLocalSkillSyncScript {
        sourceRelPath = "agents/shared-skills";
        targetAbsPath = skillDir;
      }}
      # ── This agent's own local skills ─────────────────────────────────────
      ${mkLocalSkillSyncScript {
        sourceRelPath = localSkillsRelPath;
        targetAbsPath = skillDir;
      }}
    '';
in
{
  inherit
    agentSkillSources
    enabledSkillSources
    mkAgentSkillInstall
    mkLocalSkillSyncScript
    ;
}
