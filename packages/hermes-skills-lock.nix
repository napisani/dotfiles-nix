# The skills priv/kube-home-lab installs in Hermes, as plain JSON so its synth
# never runs Nix. Reads commits from flake.lock and never fetches an input.
{
  pkgs,
  lib,
  inputs,
}:
let
  catalog = import ../mods/agents/skills.nix { inherit inputs; };
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);

  shared = map (s: if builtins.isString s then s else s.name) (
    import ../mods/agents/shared-skills.nix
  );
  # The Hermes pod has neither workmux nor stackman.
  needsMissingTool = name: lib.hasPrefix "workmux-" name || name == "stackman-rebase-conflicts";
  names = builtins.filter (name: !needsMissingTool name) shared;

  normalize =
    p:
    lib.concatStringsSep "/" (
      lib.foldl' (
        acc: seg:
        if seg == ".." then
          lib.init acc
        else if seg == "." || seg == "" then
          acc
        else
          acc ++ [ seg ]
      ) [ ] (lib.splitString "/" p)
    );

  entry =
    name:
    let
      skill = catalog.${name};
      locked = lock.nodes.${lock.nodes.root.inputs.${skill.input}}.locked;
    in
    if skill.kind == "local" then
      {
        inherit name;
        kind = "local";
        monorepoPath = "pub/dotfiles-nix/mods/dotfiles/${skill.path}";
      }
    else if locked.type == "github" then
      {
        inherit name;
        kind = "remote";
        repo = "${locked.owner}/${locked.repo}";
        inherit (locked) rev;
        inherit (skill) path;
      }
    else if locked.type == "path" then
      {
        inherit name;
        kind = "local";
        monorepoPath = normalize "pub/dotfiles-nix/${locked.path}/${skill.path}";
      }
    else
      throw "hermes-skills-lock: ${name} comes from a ${locked.type} input, which the Hermes image build can't fetch";
in
pkgs.runCommand "hermes-skills.lock.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
  jq . ${pkgs.writeText "hermes-skills.raw.json" (builtins.toJSON (map entry names))} > "$out"
''
