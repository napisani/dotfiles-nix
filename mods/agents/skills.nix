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
#   skills     — list of { name; path; disableModelInvocation ? false; }: the
#                installed skill name, its in-repo directory path within
#                `input`, and whether it should be invoked by name only
#                (never auto-triggered by description matching). This is a
#                plain intent flag — it says nothing about *which* agents can
#                honor it. That's decided separately by
#                `manualOnlyCapableAgents` below (today: every agent except
#                OpenCode, which has no such mechanism upstream —
#                anomalyco/opencode#11972). `isSkillManualOnlyFor` combines
#                the two; each agent module calls it to decide whether to
#                realize "manual-only" in its own mechanism (see claude.nix,
#                pi.nix, codex.nix) — no agent-identity branching in the
#                catalog itself.
#   agents     — list of agent IDs this entry targets (default: allAgents —
#                nearly every entry targets all four, so only entries scoped
#                to a subset need to state it)
#   condition  — boolean; when false the entry is skipped (default: true)
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  inputs ? { },
  homeManagerRelPath,
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
      homeManagerRelPath
      ;
  };
  inherit (shared)
    dotfiles
    allAgents
    isLoancrateMac
    nodeBin
    gitBin
    ;

  # Every agent with a working manual-only mechanism today (see "Make a skill
  # manual-only" in the agent-management skill) — i.e. every agent except
  # OpenCode, which has none upstream yet (anomalyco/opencode#11972). This is
  # the one place that knows which agents can act on a skill's
  # disableModelInvocation flag — the catalog itself never names an agent, so
  # OpenCode gaining support later, or an agent losing it, is a one-line
  # change here instead of a hunt through every flagged skill.
  manualOnlyCapableAgents = [
    "claude-code"
    "pi"
    "codex"
  ];

  # Should `agentId` treat `s` as manual-only? True iff the skill asked for it
  # (disableModelInvocation) AND this agent actually has a mechanism for it
  # (manualOnlyCapableAgents) — the catalog's intent and each agent's
  # capability are declared separately and only combined here.
  isSkillManualOnlyFor =
    { s, agentId }: (s.disableModelInvocation or false) && builtins.elem agentId manualOnlyCapableAgents;

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
    }
    {
      input = inputs.wshobson-agents;
      skills = [
        {
          name = "prompt-engineering-patterns";
          path = "plugins/llm-application-dev/skills/prompt-engineering-patterns";
        }
      ];
    }
    {
      input = inputs.intellectronica-agent-skills;
      skills = [
        {
          name = "context7";
          path = "skills/context7";
        }
      ];
    }
    {
      input = inputs.addyosmani-agent-skills;
      skills = [
        {
          name = "code-simplification";
          path = "skills/code-simplification";
        }
      ];
    }
    {
      input = inputs.superpowers;
      skills = [
        {
          name = "brainstorming";
          path = "skills/brainstorming";
          disableModelInvocation = true;
        }
        {
          name = "systematic-debugging";
          path = "skills/systematic-debugging";
          disableModelInvocation = true;
        }
      ];
    }
    {
      # NOTE ON UPSTREAM DRIFT (pinned rev): `diagnose` was renamed upstream
      # to `diagnosing-bugs` (migrated below); `write-a-skill`, `caveman`, and
      # `zoom-out` no longer exist at this rev and were dropped.
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
          name = "handoff";
          path = "skills/productivity/handoff";
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
          disableModelInvocation = true;
        }
      ];
    }
    {
      input = inputs.proctmux;
      skills = [
        {
          name = "proctmux-config";
          path = "skills/proctmux-config";
        }
      ];
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
    }
    {
      input = inputs.playwright-cli-skills;
      skills = [
        {
          name = "playwright-cli";
          path = "skills/playwright-cli";
        }
      ];
    }
    {
      input = inputs.deepagents;
      skills = [
        {
          name = "web-research";
          path = "libs/code/examples/skills/web-research";
        }
      ];
    }
    {
      input = inputs.softaworks-agent-toolkit;
      skills = [
        {
          name = "mermaid-diagrams";
          path = "dist/plugins/mermaid-diagrams/skills/mermaid-diagrams";
        }
      ];
    }
    {
      input = inputs.workmux-skills;
      skills = [
        {
          name = "worktree";
          path = "skills/worktree";
        }
      ];
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
      # The repository stores this skill under `skills/no-ai-slop`.
      skills = [
        {
          name = "no-ai-slop";
          path = "skills/no-ai-slop";
        }
      ];
    }
    {
      input = inputs.humanlayer-skills;
      skills = [
        {
          name = "show-me";
          path = "plugins/show-me/skills/show-me";
        }
      ];
    }
    {
      input = inputs.builderio-skills;
      skills = [
        {
          name = "visual-explainer";
          path = "skills/visual-explainer";
        }
      ];
    }
    # Generic private skills (from napisani/monorepo priv/skills/)
    {
      input = inputs.private-skills;
      skills = [
        {
          name = "multi-valued-review";
          path = "priv/skills/multi-valued-review";
          disableModelInvocation = true;
        }
        {
          name = "mvr-suggestions";
          path = "priv/skills/mvr-suggestions";
          disableModelInvocation = true;
        }
        {
          name = "neovim-project-config";
          path = "priv/skills/neovim-project-config";
          disableModelInvocation = true;
        }
      ];
    }
    # Loancrate-only: private skills
    {
      input = inputs.private-skills;
      skills = [
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
          name = "loancrate-slack-relay";
          path = "priv/skills/loancrate-slack-relay";
        }
        {
          name = "loancrate-pr-maintainer";
          path = "priv/skills/loancrate-pr-maintainer";
          disableModelInvocation = true;
        }
      ];
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
      condition = isLoancrateMac;
    }
    {
      input = inputs.patricio0312rev-skills;
      skills = [
        {
          name = "rfc-generator";
          path = "architecture/rfc-generator";
          disableModelInvocation = true;
        }
      ];
    }
    {
      input = inputs.deepwiki-rs-skills;
      skills = [
        {
          name = "smart-docs";
          path = "skills/smart-docs";
          disableModelInvocation = true;
        }
      ];
    }
    {
      input = inputs.openclaw-skills;
      skills = [
        {
          name = "tmux";
          path = "skills/tmux";
          disableModelInvocation = true;
        }
      ];
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
      # Optional hook so an agent module can substitute a patched derivation
      # (see mkPatchedSkillSource) for skills where isSkillManualOnlyFor is
      # true, when this agent's own manual-only mechanism needs the skill's
      # own files changed (Pi's frontmatter, Codex's sibling openai.yaml)
      # rather than an external override file (Claude Code's skillOverrides).
      # Defaults to the identity function — most agents don't need it.
      patchSource ? (s: src: src),
    }:
    builtins.listToAttrs (
      lib.concatMap (
        source:
        map (s: {
          name = "${skillDirRelPath}/${s.name}";
          value = {
            source = patchSource s (skillSourcePath source s);
            force = true;
          };
        }) source.skills
      ) (builtins.filter (s: builtins.elem agentId (s.agents or allAgents)) enabledSkillSources)
    );

  # Attrset { skillName = "user-invocable-only"; ... } for every catalog skill
  # where isSkillManualOnlyFor is true for `agentId`. Feeds an agent's own
  # settings-based override mechanism (currently only Claude Code's
  # skillOverrides — see claude.nix) via managed-config-lib.nix's
  # mkJsonManagedMerge, so it's revocable the same way mcpServers is: drop the
  # flag, the override disappears on the next declared-set replace.
  mkSkillOverrides =
    { agentId }:
    builtins.listToAttrs (
      map (s: {
        inherit (s) name;
        value = "user-invocable-only";
      }) (
        builtins.filter (s: isSkillManualOnlyFor { inherit s agentId; }) (
          lib.concatMap (source: source.skills) enabledSkillSources
        )
      )
    );

  # Copy a skill's (read-only, pinned) store path into a new derivation and
  # apply small file-level patches on top — for agents whose manual-only
  # mechanism must live inside the skill's own files (Pi's `SKILL.md`
  # frontmatter, Codex's sibling `agents/openai.yaml`) rather than an external
  # override file. Agent-blind: takes a source path and generic patch specs,
  # not agent identity — callers (pi.nix, codex.nix) supply the agent-specific
  # patch content themselves.
  #   name             — the skill's own name, used only to make the
  #                      resulting store path identifiable (e.g. when
  #                      inspecting `nix build` output during validation)
  #   sourcePath       — the skill directory to copy and patch
  #   addFiles         — { relPath = content; ... } files to create/overwrite
  #   insertAfterLine  — optional { file; afterLine; text; }: splice `text` as
  #                      a new line immediately after line `afterLine` of
  #                      `file` (1-indexed) — e.g. inserting a frontmatter key
  #                      right after SKILL.md's opening `---`. Verified at
  #                      build time that `file`'s first line is exactly `---`,
  #                      so a skill whose frontmatter doesn't open on line 1
  #                      (BOM, leading blank line, no frontmatter at all)
  #                      fails the build loudly instead of silently landing
  #                      the patch outside the frontmatter block and leaving
  #                      the skill auto-invocable.
  mkPatchedSkillSource =
    {
      name,
      sourcePath,
      addFiles ? { },
      insertAfterLine ? null,
    }:
    pkgs-unstable.runCommand "patched-skill-${name}" { } (
      ''
        cp -r ${sourcePath} "$out"
        chmod -R u+w "$out"
      ''
      + lib.concatStrings (
        lib.mapAttrsToList (
          relPath: content:
          # Content goes through writeText (its own store path) rather than a
          # shell heredoc, so arbitrary file content never has to survive
          # quoting/indentation inside this derivation's builder script.
          ''
            mkdir -p "$(dirname "$out/${relPath}")"
            cp ${pkgs-unstable.writeText (builtins.replaceStrings [ "/" ] [ "_" ] relPath) content} "$out/${relPath}"
          ''
        ) addFiles
      )
      + lib.optionalString (insertAfterLine != null) ''
        _target="$out/${insertAfterLine.file}"
        if [ "$(sed -n '1p' "$_target")" != "---" ]; then
          echo "mkPatchedSkillSource: ${name}: expected '$_target' to open with a '---' frontmatter line, refusing to patch" >&2
          exit 1
        fi
        sed -i ${lib.escapeShellArg "${toString insertAfterLine.afterLine}a\\${insertAfterLine.text}"} "$_target"
      ''
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
    mkSkillOverrides
    mkPatchedSkillSource
    isSkillManualOnlyFor
    ;
}
