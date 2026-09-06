{
  self,
  lib,
  pkgs,
}:
let
  nativeScripts = import ../mods/internal/native-scripts.nix { inherit lib; };
  homes = map (system: system.config.home-manager.users.nick) (
    builtins.attrValues self.darwinConfigurations ++ builtins.attrValues self.nixosConfigurations
  );
  # This is the deployment regression: constructing new declarations must not
  # call reconciler code from an unrelated live checkout at activation time.
  boundToGeneration =
    home:
    lib.all (
      operation: lib.hasInfix (builtins.unsafeDiscardStringContext "${nativeScripts}/") operation.command
    ) (builtins.attrValues home.globalToolOperations);
in
assert lib.all boundToGeneration homes;
assert lib.all (
  home:
  lib.hasInfix (builtins.unsafeDiscardStringContext "${nativeScripts}/model-runtimes/scripts/apply-models.js") home.home.activation.installModelRuntimeModels.data
) homes;
assert lib.all (
  home:
  lib.all (entry: !lib.hasInfix "rtk init" entry.data) (builtins.attrValues home.home.activation)
) homes;
assert lib.all (
  home:
  lib.all (
    operation:
    !lib.hasInfix "npm install --prefix" operation.command && !lib.hasInfix "rtk init" operation.command
  ) (builtins.attrValues home.globalToolOperations)
) homes;
pkgs.runCommand "native-install-contract"
  {
    NODE_PATH = import ../mods/internal/agents/toml-node-path.nix { inherit pkgs; };
    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.python3
    ];
  }
  ''
    cp -R ${nativeScripts} fixture
    chmod -R u+w fixture
    ${lib.concatMapStringsSep "\n"
      (domain: ''
        cp ${../mods/internal + "/${domain}/scripts"}/*.test.cjs fixture/${domain}/scripts/
        cp -R ${
          ../mods/internal + "/${domain}/scripts/test-fixtures"
        } fixture/${domain}/scripts/test-fixtures
      '')
      [
        "agents"
        "npm"
        "uv"
      ]
    }
    cp ${../mods/internal/model-runtimes/scripts}/*.test.cjs fixture/model-runtimes/scripts/
    cp ${../mods/internal/scripts}/*.test.cjs fixture/scripts/
    cp -R ${../mods/internal/scripts/test-fixtures} fixture/scripts/test-fixtures
    cp ${../mods/internal/scripts/lib/reconcile-installs.test.cjs} fixture/scripts/lib/reconcile-installs.test.cjs
    # The adapters exercise real subprocess seams with standalone native CLI
    # fixtures. No registry, real user HOME, or installed agents are needed.
    node --test \
      fixture/scripts/lib/reconcile-installs.test.cjs \
      fixture/agents/scripts/*.test.cjs \
      fixture/npm/scripts/*.test.cjs \
      fixture/uv/scripts/*.test.cjs \
      fixture/model-runtimes/scripts/*.test.cjs \
      fixture/scripts/*.test.cjs
    touch "$out"
  ''
