{
  self,
  lib,
  pkgs,
}:
let
  systems =
    builtins.attrValues self.darwinConfigurations ++ builtins.attrValues self.nixosConfigurations;
  homes = map (system: system.config.home-manager.users.nick) systems;
  nativeHost = lib.findFirst (
    system: system.pkgs.stdenv.hostPlatform.system == pkgs.stdenv.hostPlatform.system
  ) (throw "no native host") systems;
  home = nativeHost.config.home-manager.users.nick;
  withoutRtk =
    (nativeHost.extendModules {
      modules = [
        {
          home-manager.users.nick.agents = lib.genAttrs [ "claude" "codex" "pi" "opencode" ] (_: {
            rtk.enable = lib.mkForce false;
          });
        }
      ];
    }).config.home-manager.users.nick;
  paths = [
    ".claude/RTK.md"
    ".codex/RTK.md"
    ".pi/agent/extensions/rtk.ts"
    ".config/opencode/plugins/rtk.ts"
  ];
  instructions = [
    ".claude/CLAUDE.md"
    ".codex/AGENTS.md"
    ".pi/agent/AGENTS.md"
    ".config/opencode/AGENTS.md"
  ];
in
assert lib.all (
  home: lib.all (path: builtins.hasAttr path home.home.file) (paths ++ instructions)
) homes;
assert lib.all (path: !builtins.hasAttr path withoutRtk.home.file) paths;
assert !lib.hasInfix "@RTK.md" withoutRtk.home.file.".claude/CLAUDE.md".text;
assert !lib.hasInfix "/.codex/RTK.md" withoutRtk.home.file.".codex/AGENTS.md".text;
pkgs.runCommand "rtk-runtime" { } ''
  ${lib.concatMapStringsSep "\n" (path: "test -s ${home.home.file.${path}.source}") paths}
  grep -F '${home.agents.rtkPackage}/bin/rtk' ${home.home.file.".pi/agent/extensions/rtk.ts".source}
  grep -F '${home.agents.rtkPackage}/bin/rtk' ${
    home.home.file.".config/opencode/plugins/rtk.ts".source
  }
  grep -F '@RTK.md' ${home.home.file.".claude/CLAUDE.md".source}
  grep -F '@${home.home.homeDirectory}/.codex/RTK.md' ${home.home.file.".codex/AGENTS.md".source}
  export HOME="$TMPDIR/rtk-probe"
  mkdir -p "$HOME"
  # Native RTK uses exit 3 for advisory rewrites, not just 0 for rewrites.
  status=0
  rewritten="$(${home.agents.rtkPackage}/bin/rtk rewrite 'git status')" || status=$?
  test "$status" -eq 0 || test "$status" -eq 3
  printf '%s\n' "$rewritten" | grep -F 'rtk git status'
  touch "$out"
''
