{
  self,
  lib,
  pkgs,
}:
let
  systems =
    builtins.attrValues self.darwinConfigurations ++ builtins.attrValues self.nixosConfigurations;
  host = lib.findFirst (
    system: system.pkgs.stdenv.hostPlatform.system == pkgs.stdenv.hostPlatform.system
  ) (throw "no native host") systems;
  home = host.config.home-manager.users.nick;
  withoutAgents =
    (host.extendModules {
      modules = [ { home-manager.users.nick.agents.enable = lib.mkForce false; } ];
    }).config.home-manager.users.nick;
  unrelated = [
    ".claude/unrelated"
    ".codex/unrelated"
    ".pi/agent/unrelated"
    ".config/opencode/unrelated"
    ".agents/unrelated"
  ];
  extended =
    (host.extendModules {
      modules = [
        {
          home-manager.users.nick.home.file = lib.genAttrs unrelated (_: {
            text = "another module owns this";
          });
        }
      ];
    }).config.home-manager.users.nick;
  manifest = pkgs.writeText "config-operations.json" (
    builtins.toJSON {
      home = home.home.homeDirectory;
      commands =
        map
          (name: {
            inherit name;
            inherit (home.globalToolOperations.${name}) command;
          })
          (
            builtins.filter (
              name:
              builtins.elem name [
                "npm-config"
                "claude-mcp"
                "claude-settings"
                "claude-loancrate"
                "codex-hooks"
                "codex-config"
                "pi-mcp"
                "pi-settings"
                "pi-models"
              ]
            ) ((import ../mods/internal/operation-plan.nix { inherit lib; }) home.globalToolOperations)
          );
    }
  );
in
assert withoutAgents.globalToolOperations.npm.command == home.globalToolOperations.npm.command;
assert withoutAgents.globalToolOperations.uv.command == home.globalToolOperations.uv.command;
assert lib.all (name: !builtins.elem name extended.nativeManagedFiles) unrelated;
assert home.globalToolOperations ? claude-mcp;
assert home.globalToolOperations ? claude-settings;
pkgs.runCommand "global-tools-config"
  {
    TEST_BASH = "${pkgs.bash}/bin/bash";
    TEST_PYTHON = "${pkgs.python3}/bin/python3";
    GLOBAL_TOOLS_CLI = "${
      import ../mods/internal/native-scripts.nix { inherit lib; }
    }/scripts/global-tools.js";
  }
  ''
    ${pkgs.nodejs}/bin/node ${./fixtures/global-tools-config.cjs} ${manifest}
    ${pkgs.nodejs}/bin/node ${./fixtures/audit-managed-mcp.cjs} ${./audit-managed-mcp.py}
    touch "$out"
  ''
