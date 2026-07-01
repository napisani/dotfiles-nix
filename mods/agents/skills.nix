# agents/skills.nix — Community and local skill installation
#
# agentSkillSources declares all skill repos to install from. Each entry supports:
#   repo       — GitHub URL or owner/repo shorthand
#   skills     — skill names to install from that repo
#   agents     — list of agent IDs to install into (see `skills --help` for valid IDs)
#   fullDepth  — clone with full history instead of --depth=1 (default: false)
#   condition  — boolean; when false the entry is skipped (default: true)
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  shared = import ./lib.nix { inherit config pkgs-unstable; };
  inherit (shared) dotfiles home allAgents isAxionMac isLoancrateMac nodeBin gitBin;

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
    # Loancrate-only: private skills
    {
      repo = "https://github.com/napisani/private-skills";
      skills = [
        "loancrate-pr-workflow"
        "loancrate-with-workmux-stack-handoff"
      ];
      agents = allAgents;
      condition = isLoancrateMac;
    }
    # Axion-only: Datadog log skill
    {
      repo = "https://github.com/datadog-labs/agent-skills";
      skills = [ "dd-logs" ];
      agents = allAgents;
      fullDepth = true;
      condition = isAxionMac;
    }
  ];

  enabledSkillSources = builtins.filter (s: s.condition or true) agentSkillSources;

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
    "skills add ${lib.escapeShellArg source.repo} --global ${agentArgs} --yes --copy ${skillArgs}${fullDepthArg}";

  communitySkillCmds = builtins.concatStringsSep "\n" (
    map mkCommunitySkillCmd enabledSkillSources
  );

  # Activation script: symlink each subdir of a dotfiles source into a target dir.
  # Creates target/<name> → source/<name> without disturbing unrelated entries.
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
in
{
  home.activation.installAgentSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    export DISABLE_TELEMETRY=1
    export NPM_CONFIG_PREFIX="$HOME/.local"
    export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

    mkdir -p \
      "$HOME/.agents/skills" \
      "$HOME/.claude/skills" \
      "$HOME/.claude/commands" \
      "$HOME/.cursor/skills" \
      "$HOME/.codex/skills" \
      "$HOME/.pi/agent/skills" \
      "$HOME/.pi/agent/extensions" \
      "$HOME/.pi/agent/themes"

    # Skills are declarative: reset managed dirs each activation, then rebuild.
    # Preserves hidden/system entries such as Codex's .system.
    _reset_managed_skill_dir() {
      _dst="$1"
      [ -d "$_dst" ] || return 0
      for _entry in "$_dst"/*; do
        [ -e "$_entry" ] || [ -L "$_entry" ] || continue
        rm -rf "$_entry"
      done
    }

    for _managed_skill_dir in \
      "$HOME/.agents/skills" \
      "$HOME/.claude/skills" \
      "$HOME/.cursor/skills" \
      "$HOME/.codex/skills" \
      "$HOME/.config/opencode/skills" \
      "$HOME/.pi/agent/skills"; do
      _reset_managed_skill_dir "$_managed_skill_dir"
    done

    # ── Community skills (from git repos, copied into agent dirs) ────────────
    if command -v skills >/dev/null 2>&1; then
      ${communitySkillCmds}
    else
      echo "agents: 'skills' command not found — skipping community skill installs" >&2
      echo "agents: run 'npm install -g skills@latest' then 'darwin-rebuild switch' to fix" >&2
    fi

    # ── Shared local skills → global store + all non-Pi agent skill dirs ─────
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
      targetAbsPath = "${home}/.codex/skills";
    }}
    ${mkLocalSkillSyncScript {
      sourceRelPath = "agents/shared-skills";
      targetAbsPath = "${home}/.config/opencode/skills";
    }}

    # ── Per-agent local skills ────────────────────────────────────────────────
    ${mkLocalSkillSyncScript {
      sourceRelPath = "agents/claude/skills";
      targetAbsPath = "${home}/.claude/skills";
    }}
    ${mkLocalSkillSyncScript {
      sourceRelPath = "agents/cursor/skills";
      targetAbsPath = "${home}/.cursor/skills";
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

    # ── Per-agent local commands (Claude slash commands) ──────────────────────
    ${mkLocalSkillSyncScript {
      sourceRelPath = "agents/claude/commands";
      targetAbsPath = "${home}/.claude/commands";
    }}
  '';
}
