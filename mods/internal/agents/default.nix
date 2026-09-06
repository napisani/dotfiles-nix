# Internal option validation and native adapter composition.
#
# `config.agents` is the public desired-state interface. Public mods/ and homes/
# modules declare policy; the per-agent modules consume that data and own its
# native realization. Catalog and adapter support modules contain no machine
# selection policy. See ADR 0003.
{
  config,
  inputs,
  lib,
  ...
}:
let
  skillCatalog = import ../../agents/skills.nix { inherit inputs; };
  skillSelectionsByAgent = lib.mapAttrs (
    _agent: selections: config.agents.skills.shared ++ selections
  ) config.agents.skills.perAgent;
  selectionNames = selections: map (selection: selection.name) selections;
  configuredSkillNames = selectionNames (
    config.agents.skills.shared ++ lib.concatLists (builtins.attrValues config.agents.skills.perAgent)
  );
  unknownSkillNames = builtins.filter (
    name: !(builtins.hasAttr name skillCatalog)
  ) configuredSkillNames;
  duplicateSkillSelections = lib.filterAttrs (
    _agent: selections:
    let
      names = selectionNames selections;
    in
    builtins.length names != builtins.length (lib.unique names)
  ) skillSelectionsByAgent;
  opencodeManualOnlySelections = builtins.filter (
    selection: selection.manualOnly
  ) skillSelectionsByAgent.opencode;
in
{
  imports = [
    ./options.nix
    ./claude.nix
    ./codex.nix
    ./opencode.nix
    ./pi.nix
    ./shared-store.nix
  ];

  home.packages = lib.optional config.agents.enable config.agents.rtkPackage;

  warnings =
    lib.optional
      (config.agents.enable && config.agents.opencode.enable && opencodeManualOnlySelections != [ ])
      "agents: OpenCode cannot enforce manualOnly skill selections; those skills remain implicitly invocable there";

  assertions = [
    {
      assertion = unknownSkillNames == [ ];
      message = "agents: unknown skill catalog entries: ${builtins.concatStringsSep ", " unknownSkillNames}";
    }
    {
      assertion = duplicateSkillSelections == { };
      message = "agents: duplicate skill selections for: ${builtins.concatStringsSep ", " (builtins.attrNames duplicateSkillSelections)}";
    }
    {
      assertion = !config.agents.enable || config.agents.instructions != null;
      message = "agents: instructions must be declared when agent configuration is enabled";
    }
    {
      assertion = config.agents.codex.settings == { };
      message = "agents: Codex settings declarations are not supported by the adapter yet";
    }
  ];
}
