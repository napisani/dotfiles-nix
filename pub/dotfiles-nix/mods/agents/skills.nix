# agents/skills.nix — Skill catalog + home.file skill-link generators
#
# agentSkillSources is the single declared catalog: DRY data, targeting N
# agents from one entry (still fine to share — the coupling problem was
# scripts branching on agent identity, not data lists; see
# docs/adr/0001-per-agent-modules.md). This file owns no home.activation of
# its own. Each agent module calls `mkCommunitySkillFiles`/`mkLocalSkillFiles`
# itself to get a home.file attrset scoped to that one agent's skill dir (see
# docs/adr/0002-layered-asset-management.md for the Layer 0 model).
#
# Catalog entry fields:
#   input      — a flake input (from flake.nix), pinned via flake.lock
#   skills     — list of { name; path; }: the installed skill name and its
#                in-repo directory path within `input`
#   agents     — list of agent IDs this entry targets
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
  shared = import ./lib.nix {
    inherit
      config
      lib
      pkgs-unstable
      hostname
      machineRoles
      inputs
      ;
  };
  inherit (shared)
    dotfiles
    allAgents
    isLoancrateMac
    nodeBin
    gitBin
    ;

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
          name = "resolving-merge-conflicts";
          path = "skills/engineering/resolving-merge-conflicts";
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
          name = "codebase-design";
          path = "skills/engineering/codebase-design";
        }
        {
          name = "tdd";
          path = "skills/engineering/tdd";
        }
        {
          name = "implement";
          path = "skills/engineering/implement";
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
    # {
    #   input = inputs.gh-stack-skills;
    #   skills = [
    #     {
    #       name = "gh-stack";
    #       path = "skills/gh-stack";
    #     }
    #   ];
    #   agents = allAgents;
    # }
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
    # Loancrate-only: private skills (from napisani/monorepo priv/skills/)
    {
      input = inputs.private-skills;
      skills = [
        {
          name = "loancrate-pr-workflow";
          path = "priv/skills/loancrate-pr-workflow";
        }
        {
          name = "loancrate-with-workmux-stack-handoff";
          path = "priv/skills/loancrate-with-workmux-stack-handoff";
        }
        {
          name = "loancrate-standup-prep";
          path = "priv/skills/loancrate-standup-prep";
        }
        {
          name = "loancrate-analyze-agent-self-improve-trend";
          path = "priv/skills/loancrate-analyze-agent-self-improve-trend";
        }
        {
          name = "loancrate-weekly-update-draft";
          path = "priv/skills/loancrate-weekly-update-draft";
        }
        {
          name = "loancrate-weekly-project-update-draft";
          path = "priv/skills/loancrate-weekly-project-update-draft";
        }
        {
          name = "multi-valued-review";
          path = "priv/skills/multi-valued-review";
        }
        {
          name = "mvr-suggestions";
          path = "priv/skills/mvr-suggestions";
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
        {
          name = "loancrate-eval-model-candidates-ci";
          path = "skills/loancrate-eval-model-candidates-ci";
        }
        {
          name = "loancrate-ob-pricing-regression-test";
          path = "skills/loancrate-ob-pricing-regression-test";
        }
        {
          name = "loancrate-run-local-agent-eval";
          path = "skills/loancrate-run-local-agent-eval";
        }
      ];
      agents = allAgents;
      condition = isLoancrateMac;
    }
  ];

  enabledSkillSources = builtins.filter (s: s.condition or true) agentSkillSources;

  # Store-path for one catalog skill: the input tree, plus the in-repo path
  # (a root-level SKILL.md means the skill dir is the input itself).
  skillSourcePath =
    source: s: if s.path == "." then "${source.input}" else "${source.input}/${s.path}";

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
    mkCommunitySkillFiles
    mkLocalSkillFiles
    ;
}
