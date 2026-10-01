{
  self,
  lib,
  pkgs,
}:
let
  systems =
    builtins.attrValues self.darwinConfigurations ++ builtins.attrValues self.nixosConfigurations;
  nativeHost = lib.findFirst (
    system: system.pkgs.stdenv.hostPlatform.system == pkgs.stdenv.hostPlatform.system
  ) (throw "no native host") systems;
  home = nativeHost.config.home-manager.users.nick;
  localPatched = home.home.file.".codex/skills/classify".source;
  pinnedPatched = home.home.file.".codex/skills/brainstorming".source;
  localLive = home.home.file.".agents/skills/classify".source;
in
pkgs.runCommand "skill-patching" { } ''
  test ! -L ${localPatched}
  test -s ${localPatched}/SKILL.md
  test -s ${localPatched}/evals/evals.json
  grep -Fx 'disable-model-invocation: true' ${localPatched}/SKILL.md
  grep -Fx '  allow_implicit_invocation: false' ${localPatched}/agents/openai.yaml
  test -s ${pinnedPatched}/SKILL.md
  grep -Fx '  allow_implicit_invocation: false' ${pinnedPatched}/agents/openai.yaml
  test -L ${localLive}
  touch "$out"
''
