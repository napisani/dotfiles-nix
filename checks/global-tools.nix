{
  self,
  lib,
  pkgs,
}:
let
  mkHome =
    modules:
    self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.pkgs-unstable = pkgs;
      modules = [
        ../mods/internal/global-tools.nix
        {
          home.username = "fixture";
          home.homeDirectory = "/tmp/global-tools-contract";
          home.stateVersion = "24.11";
          # Exercise the module against the check's package set, not a host profile.
          home.enableNixpkgsReleaseCheck = false;
        }
      ]
      ++ modules;
    };
  home =
    (mkHome [
      {
        globalToolOperations = {
          a = {
            after = [ "z" ];
            command = "printf 'ran:a\\n'";
          };
          b = {
            after = [ "z" ];
            command = "printf 'ran:b\\n'";
          };
          z.command = "printf 'ran:z\\n'; if [ \"\${FAIL_PREDECESSOR:-}\" = 1 ]; then exit 1; fi";
        };
      }
    ]).config;
  uvOnly = (mkHome [ ../mods/internal/uv.nix ]).config;
  toolsOnly =
    (mkHome [
      ../mods/internal/npm.nix
      ../mods/internal/uv.nix
      {
        nativeTools.npm.tools."@scope/example" = "1.2.3";
      }
    ]).config;
  invalid =
    (mkHome [
      ../mods/internal/npm.nix
      { nativeTools.npm.tools.bad = "latest"; }
    ]).config;
  cli = lib.findFirst (p: p.name == "global-tools") (throw "missing CLI") home.home.packages;
  dag = import "${self.inputs.home-manager}/modules/lib/dag.nix" { inherit lib; };
  activation = dag.topoSort (
    lib.filterAttrs (name: _: lib.hasPrefix "reconcileGlobalTools-" name) home.home.activation
  );
  runActivation = pkgs.writeShellScript "fixture-activation" (
    lib.concatMapStringsSep "\n" (entry: entry.data) activation.result
  );
in
assert !(uvOnly ? agents);
assert uvOnly.globalToolOperations ? uv;
assert !(toolsOnly ? agents);
assert !(builtins.tryEval invalid).success;
assert lib.hasInfix "@scope/example" toolsOnly.globalToolOperations.npm.command;
pkgs.runCommand "global-tools-contract" { } ''
  ${cli}/bin/global-tools status | grep '^ran:' > cli-order
  ${runActivation} | grep '^ran:' > activation-order
  printf 'ran:z\nran:a\nran:b\n' > expected-order
  cmp expected-order cli-order
  cmp cli-order activation-order

  # Ordering is not success gating. CLI fails overall; activation reports the
  # failure through the shared warning variable. Both still execute a and b.
  export FAIL_PREDECESSOR=1 GLOBAL_TOOLS_WARN_FILE="$TMPDIR/warnings"
  if ${cli}/bin/global-tools apply > failed-cli; then
    echo 'CLI swallowed predecessor failure' >&2
    exit 1
  fi
  grep '^ran:' failed-cli > failed-order
  cmp expected-order failed-order
  ${runActivation} | grep '^ran:' > failed-activation-order
  cmp expected-order failed-activation-order
  grep -Fx 'z: reconciliation failed' "$GLOBAL_TOOLS_WARN_FILE"
  touch "$out"
''
