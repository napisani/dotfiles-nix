# Resolves desired skill names through the pure catalog and renders home.file
# entries. Agent adapters decide their target directory and any native patches;
# this module contains no machine or cross-agent selection policy.
{
  config,
  lib,
  pkgs-unstable,
  inputs,
  homeManagerRelPath,
  ...
}:
let
  shared = import ./lib.nix {
    inherit
      config
      lib
      pkgs-unstable
      inputs
      homeManagerRelPath
      ;
  };
  inherit (shared) dotfiles;

  cfg = config.agents;
  catalog = import ../../agents/skills.nix { inherit inputs; };
  catalogNames = builtins.attrNames catalog;

  manualOnlyCapableAgents = [
    "claude-code"
    "pi"
    "codex"
  ];
  agentOptionKeys = {
    claude-code = "claude";
    codex = "codex";
    pi = "pi";
    opencode = "opencode";
  };

  sharedSkillNames = map (selection: selection.name) cfg.skills.shared;
  perAgentSkillNamesFor = agent: map (selection: selection.name) cfg.skills.perAgent.${agent};
  skillSelectionsFor = agent: cfg.skills.shared ++ cfg.skills.perAgent.${agent};
  skillNamesFor = agent: sharedSkillNames ++ perAgentSkillNamesFor agent;

  unknownSkillNames = names: builtins.filter (name: !(builtins.hasAttr name catalog)) names;

  validateSkillNames =
    names:
    let
      unknown = unknownSkillNames names;
    in
    if unknown == [ ] then
      lib.unique names
    else
      throw "agents: unknown skill catalog entries: ${builtins.concatStringsSep ", " unknown}";

  skillEntry = name: catalog.${name} // { inherit name; };

  rawSkillSource =
    skill:
    if skill.kind == "pinned" then
      if skill.path == "." then "${skill.source}" else "${skill.source}/${skill.path}"
    else if skill.kind == "local" then
      config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${skill.path}"
    else
      throw "agents: skill '${skill.name}' has unsupported source kind '${skill.kind}'";

  skillSource =
    skill:
    let
      source = rawSkillSource skill;
    in
    if skill ? replacements then
      mkPatchedSkillSource {
        name = skill.name;
        sourcePath = source;
        replacements = skill.replacements;
      }
    else
      source;

  skillNamesByKind =
    kind: names: builtins.filter (name: catalog.${name}.kind == kind) (validateSkillNames names);

  isSkillManualOnlyFor =
    { skillName, agentId }:
    builtins.elem agentId manualOnlyCapableAgents
    && builtins.any (selection: selection.name == skillName && selection.manualOnly) (
      skillSelectionsFor agentOptionKeys.${agentId}
    );

  mkSkillFiles =
    {
      skillNames,
      targetDirRelPath,
      patchSource ? (_skill: source: source),
    }:
    builtins.listToAttrs (
      map (
        name:
        let
          skill = skillEntry name;
        in
        {
          name = "${targetDirRelPath}/${name}";
          value = {
            source = patchSource skill (skillSource skill);
            force = true;
          };
        }
      ) (validateSkillNames skillNames)
    );

  mkSkillOverrides =
    { agentId, skillNames }:
    builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = "user-invocable-only";
        })
        (
          builtins.filter (skillName: isSkillManualOnlyFor { inherit skillName agentId; }) (
            validateSkillNames skillNames
          )
        )
    );

  # Copy pinned skill content into a derivation and apply an agent-native patch.
  # Callers supply patch content; this utility has no agent-specific branches.
  mkPatchedSkillSource =
    {
      name,
      sourcePath,
      addFiles ? { },
      insertAfterLine ? null,
      replacements ? [ ],
    }:
    pkgs-unstable.runCommand "patched-skill-${name}" { } (
      ''
        cp -r ${sourcePath} "$out"
        chmod -R u+w "$out"
      ''
      + lib.concatStrings (
        lib.mapAttrsToList (relPath: content: ''
          mkdir -p "$(dirname "$out/${relPath}")"
          cp ${
            pkgs-unstable.writeText (builtins.replaceStrings [ "/" ] [ "_" ] relPath) content
          } "$out/${relPath}"
        '') addFiles
      )
      + lib.concatStrings (
        lib.imap0 (index: replacement: ''
          substituteInPlace "$out/SKILL.md" \
            --replace-fail ${lib.escapeShellArg replacement.from} ${lib.escapeShellArg "__SKILL_REWRITE_${toString index}__"}
        '') replacements
      )
      + lib.concatStrings (
        lib.imap0 (index: replacement: ''
          substituteInPlace "$out/SKILL.md" \
            --replace-fail ${lib.escapeShellArg "__SKILL_REWRITE_${toString index}__"} ${lib.escapeShellArg replacement.to}
        '') replacements
      )
      + lib.optionalString (insertAfterLine != null) ''
        _target="$out/${insertAfterLine.file}"
        if [ "$(sed -n '1p' "$_target")" != "---" ]; then
          echo "mkPatchedSkillSource: ${name}: expected '$_target' to open with a '---' frontmatter line, refusing to patch" >&2
          exit 1
        fi
        if ! grep -Fqx -- ${lib.escapeShellArg insertAfterLine.text} "$_target"; then
          sed -i ${lib.escapeShellArg "${toString insertAfterLine.afterLine}a\\${insertAfterLine.text}"} "$_target"
        fi
      ''
    );
in
{
  inherit
    catalog
    catalogNames
    isSkillManualOnlyFor
    mkPatchedSkillSource
    mkSkillFiles
    mkSkillOverrides
    perAgentSkillNamesFor
    sharedSkillNames
    skillNamesByKind
    skillNamesFor
    unknownSkillNames
    ;
}
