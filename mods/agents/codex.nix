# agents/codex.nix — Codex CLI: complete installation story
#
# Owns everything specific to Codex: skills, RTK hooks (+ the AGENTS.md
# `@RTK.md` reference, which must be reapplied after writing shared
# instructions since that overwrite would otherwise silently drop it — see
# docs/adr/0001-per-agent-modules.md), MCP servers (TOML), and Workmux status
# hooks.
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
    inherit config lib pkgs-unstable hostname machineRoles inputs homeManagerRelPath;
  };
  inherit (shared) home dotfiles nodeBin callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  instructionsTarget = "${home}/.codex/AGENTS.md";
  configTomlFile = "${home}/.codex/config.toml";
  hooksTargetFile = "${home}/.codex/hooks.json";
  scriptsDir = "${dotfiles}/agents/scripts";
  workmuxStatusDir = "${dotfiles}/agents/workmux-status";

  mcpSources = [
    {
      name = "linear";
      condition = shared.isLoancrateMac;
      config.url = "https://mcp.linear.app/mcp";
    }
    {
      name = "figma";
      condition = shared.isLoancrateMac;
      config.url = "https://mcp.figma.com/mcp";
    }
    {
      name = "bde";
      condition = shared.isLoancrateMac;
      config.url = "https://bde.dsci.loancrate.dev/mcp";
    }
  ];
  declaredMcpEntries = shared.mkDeclaredEntriesFromSources mcpSources;

  # Codex's real manual-only control isn't the `disable-model-invocation`
  # frontmatter field — it's a sibling `agents/openai.yaml` with
  # `policy.allow_implicit_invocation: false` (see
  # github.com/mattpocock/skills#516). Catalog skills are read-only pinned
  # store paths, so a skill with disableModelInvocation = true gets that
  # file injected into a patched copy instead.
  patchCodexSkillSource =
    s: src:
    if skills.isSkillManualOnlyFor { inherit s; agentId = "codex"; } then
      skills.mkPatchedSkillSource {
        name = s.name;
        sourcePath = src;
        addFiles."agents/openai.yaml" = ''
          policy:
            allow_implicit_invocation: false
        '';
      }
    else
      src;
in
{
  # Skills are Layer 0 (only Nix writes ~/.codex/skills): home.file links, not
  # an activation script. Codex's own hidden .system dir under ~/.codex/skills
  # is left untouched — home.file manages only the named skill entries beside
  # it. See docs/adr/0002-layered-asset-management.md.
  home.file =
    skills.mkCommunitySkillFiles {
      agentId = "codex";
      skillDirRelPath = ".codex/skills";
      patchSource = patchCodexSkillSource;
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/shared-skills";
      targetDirRelPath = ".codex/skills";
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/codex/skills";
      targetDirRelPath = ".codex/skills";
    };

  home.activation.prepareCodexInstructionsForRtk = lib.hm.dag.entryBefore [ "installCodexRtkHooks" ] (
    instructions.removeStaleInstructionSymlink { target = instructionsTarget; }
  );

  home.activation.installCodexRtkHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--codex";
      label = "codex";
    }
  );

  # Write shared instructions, then immediately reapply RTK's `@RTK.md`
  # reference — the overwrite above would otherwise drop it every time,
  # since it's not part of the shared source file. Same-file, same-module
  # sequence now instead of a cross-file dependency on a shared step name.
  home.activation.writeCodexInstructions = lib.hm.dag.entryAfter [ "installCodexRtkHooks" ] ''
    ${instructions.writeAgentInstructions { target = instructionsTarget; }}

    ${shared.mkRtkHookInstall {
      rtkArgs = "--codex";
      label = "codex (re-applying RTK.md reference)";
    }}
  '';

  home.activation.configureCodexMcpServers = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkTomlManagedMerge {
      targetFile = configTomlFile;
      managedKey = "mcp_servers";
      declaredEntries = declaredMcpEntries;
    }
  );

  # Ordered explicitly after configureCodexMcpServers: both write
  # ~/.codex/config.toml (one via a full TOML parse+stringify, the other via
  # raw line-based text search/replace) — an explicit order removes any
  # doubt about interaction between the two, even though a real round-trip
  # test (realistic hook-state keys, colons and all) found no actual
  # breakage either order.
  home.activation.applyCodexWorkmuxHooks = lib.hm.dag.entryAfter [ "configureCodexMcpServers" ] ''
    HOOKS_TARGET_FILE=${lib.escapeShellArg hooksTargetFile} \
    HOOKS_SOURCE_FILE=${lib.escapeShellArg "${workmuxStatusDir}/codex-hooks.json"} \
    CONFIG_TOML_FILE=${lib.escapeShellArg configTomlFile} \
      ${nodeBin}/node ${scriptsDir}/apply-codex-hooks.js
  '';
}
