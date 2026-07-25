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
  machineRoles ? [ ],
  inputs ? { },
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname machineRoles inputs; };
  inherit (shared) dotfiles allAgents isLoancrateMac nodeBin gitBin;

  # Catalog: each entry pins a flake input (from flake.nix) and names the
  # skills to install from it by their in-repo directory `path`. `path`
  # is verified against the input's actual store tree, not the README —
  # names drift (e.g. mattpocock renamed `diagnose` -> `diagnosing-bugs`).
  # `input` + per-skill `path` replaced the old `repo` URL + bare-name shape
  # when community skills moved from `skills add` fetches to pinned flake
  # inputs installed via home.file (see docs/adr/0002-layered-asset-management.md).
  agentSkillSources = [
    {
      input = inputs.anthropic-skills;
      skills = [
        {
          name = "skill-creator";
          path = "skills/skill-creator";
        }
        {
          name = "doc-coauthoring";
          path = "skills/doc-coauthoring";
        }
        {
          name = "frontend-design";
          path = "skills/frontend-design";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.intellectronica-agent-skills;
      skills = [
        {
          name = "context7";
          path = "skills/context7";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.addyosmani-agent-skills;
      skills = [
        {
          name = "code-simplification";
          path = "skills/code-simplification";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.superpowers;
      skills = [
        {
          name = "brainstorming";
          path = "skills/brainstorming";
        }
        {
          name = "systematic-debugging";
          path = "skills/systematic-debugging";
        }
      ];
      agents = allAgents;
    }
    {
      # NOTE ON UPSTREAM DRIFT (pinned rev): `diagnose` was renamed upstream
      # to `diagnosing-bugs` (migrated below); `write-a-skill`, `caveman`, and
      # `zoom-out` no longer exist at this rev and were dropped; `handoff`
      # also ships here but is installed from agentmemory below (its handoff is
      # what currently wins under the old last-writer mechanism), so it's
      # omitted here to avoid a same-name home.file collision.
      input = inputs.mattpocock-skills;
      skills = [
        {
          name = "diagnosing-bugs";
          path = "skills/engineering/diagnosing-bugs";
        }
        {
          name = "grill-me";
          path = "skills/productivity/grill-me";
        }
        {
          name = "grill-with-docs";
          path = "skills/engineering/grill-with-docs";
        }
        {
          name = "improve-codebase-architecture";
          path = "skills/engineering/improve-codebase-architecture";
        }
        {
          name = "tdd";
          path = "skills/engineering/tdd";
        }
        {
          name = "to-spec";
          path = "skills/engineering/to-spec";
        }
        {
          name = "domain-modeling";
          path = "skills/engineering/domain-modeling";
        }
        {
          name = "prototype";
          path = "skills/engineering/prototype";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.arjunmahishi-dotfiles;
      skills = [
        {
          name = "acli-jira";
          path = "common/agent-skills/acli-jira";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.proctmux;
      skills = [
        {
          name = "proctmux-config";
          path = "skills/proctmux-config";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.vantage-nvim-skills;
      skills = [
        {
          name = "vantage-distill-session";
          path = "skills/vantage-distill-session";
        }
        {
          name = "vantage-author-walkthrough";
          path = "skills/vantage-author-walkthrough";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.playwright-cli-skills;
      skills = [
        {
          name = "playwright-cli";
          path = "skills/playwright-cli";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.deepagents;
      skills = [
        {
          name = "web-research";
          path = "libs/code/examples/skills/web-research";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.softaworks-agent-toolkit;
      skills = [
        {
          name = "mermaid-diagrams";
          path = "dist/plugins/mermaid-diagrams/skills/mermaid-diagrams";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.understand-anything;
      skills = [
        {
          name = "understand";
          path = "understand-anything-plugin/skills/understand";
        }
        {
          name = "understand-chat";
          path = "understand-anything-plugin/skills/understand-chat";
        }
        {
          name = "understand-dashboard";
          path = "understand-anything-plugin/skills/understand-dashboard";
        }
        {
          name = "understand-diff";
          path = "understand-anything-plugin/skills/understand-diff";
        }
        {
          name = "understand-domain";
          path = "understand-anything-plugin/skills/understand-domain";
        }
        {
          name = "understand-explain";
          path = "understand-anything-plugin/skills/understand-explain";
        }
        {
          name = "understand-knowledge";
          path = "understand-anything-plugin/skills/understand-knowledge";
        }
        {
          name = "understand-onboard";
          path = "understand-anything-plugin/skills/understand-onboard";
        }
      ];
      agents = [ "pi" ];
    }
    {
      input = inputs.workmux-skills;
      skills = [
        {
          name = "worktree";
          path = "skills/worktree";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.agentmemory-skills;
      skills = [
        {
          name = "recall";
          path = "plugin/skills/recall";
        }
        {
          name = "remember";
          path = "plugin/skills/remember";
        }
        {
          name = "session-history";
          path = "plugin/skills/session-history";
        }
        {
          name = "forget";
          path = "plugin/skills/forget";
        }
        {
          name = "handoff";
          path = "plugin/skills/handoff";
        }
        {
          name = "recap";
          path = "plugin/skills/recap";
        }
        {
          name = "commit-context";
          path = "plugin/skills/commit-context";
        }
        {
          name = "commit-history";
          path = "plugin/skills/commit-history";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.gh-stack-skills;
      skills = [
        {
          name = "gh-stack";
          path = "skills/gh-stack";
        }
      ];
      agents = allAgents;
    }
    {
      input = inputs.no-ai-slop;
      # SKILL.md lives at the repo root, so the skill dir is the input itself.
      skills = [
        {
          name = "no-ai-slop";
          path = ".";
        }
      ];
      agents = allAgents;
    }
    # Loancrate-only: private skills
    {
      input = inputs.private-skills;
      skills = [
        {
          name = "loancrate-pr-workflow";
          path = "loancrate-pr-workflow";
        }
        {
          name = "loancrate-with-workmux-stack-handoff";
          path = "loancrate-with-workmux-stack-handoff";
        }
        {
          name = "loancrate-standup-prep";
          path = "loancrate-standup-prep";
        }
        {
          name = "loancrate-analyze-agent-self-improve-trend";
          path = "loancrate-analyze-agent-self-improve-trend";
        }
        {
          name = "loancrate-weekly-update-draft";
          path = "loancrate-weekly-update-draft";
        }
        {
          name = "multi-valued-review";
          path = "multi-valued-review";
        }
        {
          name = "mvr-suggestions";
          path = "mvr-suggestions";
        }
      ];
      agents = allAgents;
      condition = isLoancrateMac;
    }
    # Loancrate-only: lc-script
    {
      input = inputs.lc-script-skills;
      skills = [
        {
          name = "loancrate-lc-script";
          path = "skills/loancrate-lc-script";
        }
      ];
      agents = allAgents;
      condition = isLoancrateMac;
    }
  ];

  enabledSkillSources = builtins.filter (s: s.condition or true) agentSkillSources;

  # Store-path for one catalog skill: the input tree, plus the in-repo path
  # (a root-level SKILL.md means the skill dir is the input itself).
  skillSourcePath = source: s: if s.path == "." then "${source.input}" else "${source.input}/${s.path}";

  mkCommunitySkillCmd =
    agentId: source:
    let
      skillArgs = builtins.concatStringsSep " " (
        map (s: "--skill ${lib.escapeShellArg s.name}") source.skills
      );
    in
    "skills add ${lib.escapeShellArg "${source.input}"} --global --agent ${lib.escapeShellArg agentId} --yes --copy ${skillArgs}";

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

  # ── Layer 0 home.file generators (replace mkAgentSkillInstall) ────────────

  # home.file attrset installing this agent's community skills as store
  # symlinks. Revocation is home-manager's own link bookkeeping (drop the
  # catalog entry → the link disappears on the next switch), content is pinned
  # by flake.lock, and activation needs no network. force=true so a
  # pre-migration copied directory (or a stray write into a skill dir) is
  # replaced, preserving the old wipe-and-rebuild "Nix owns this dir" semantics.
  mkCommunitySkillFiles =
    {
      agentId,
      skillDirRelPath,
    }:
    builtins.listToAttrs (
      lib.concatMap (
        source:
        map (s: {
          name = "${skillDirRelPath}/${s.name}";
          value = {
            source = skillSourcePath source s;
            force = true;
          };
        }) source.skills
      ) (builtins.filter (s: builtins.elem agentId (s.agents or [ ])) enabledSkillSources)
    );

  # home.file attrset linking each skill directory under a dotfiles subdir into
  # targetDirRelPath as out-of-store symlinks (live-editable). The directory
  # set is enumerated at eval time from the flake's tracked tree, so a new dir
  # needs a switch but edits to files inside a linked dir are live. A missing
  # source dir yields an empty set (agents with no local skills of their own).
  mkLocalSkillFiles =
    {
      sourceRelPath,
      targetDirRelPath,
    }:
    let
      absSrc = ../dotfiles + "/${sourceRelPath}";
      names =
        if builtins.pathExists absSrc then
          lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir absSrc))
        else
          [ ];
    in
    builtins.listToAttrs (
      map (name: {
        name = "${targetDirRelPath}/${name}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${sourceRelPath}/${name}";
          force = true;
        };
      }) names
    );
in
{
  inherit
    agentSkillSources
    enabledSkillSources
    mkAgentSkillInstall
    mkLocalSkillSyncScript
    mkCommunitySkillFiles
    mkLocalSkillFiles
    ;
}
