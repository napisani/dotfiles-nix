{
  self,
  lib,
  pkgs,
}:
let
  nativeScripts = import ../mods/native-scripts.nix { inherit lib; };
  homes = map (system: system.config.home-manager.users.nick) (
    builtins.attrValues self.darwinConfigurations ++ builtins.attrValues self.nixosConfigurations
  );
  # This is the deployment regression: constructing new declarations must not
  # call reconciler code from an unrelated live checkout at activation time.
  boundToGeneration =
    home:
    lib.all
      (
        entry:
        !builtins.hasAttr entry home.home.activation
        ||
          lib.hasInfix (builtins.unsafeDiscardStringContext "${nativeScripts}/agents/scripts/")
            home.home.activation.${entry}.data
      )
      [
        "installPiPackages"
        "installPiConfig"
        "installClaudePlugins"
        "installNpmxTools"
        "installUvTools"
      ];
in
assert lib.all boundToGeneration homes;
pkgs.runCommand "native-install-contract"
  {
    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.python3
    ];
  }
  ''
    cp -R ${nativeScripts} fixture
    chmod -R u+w fixture
    cp ${../mods/dotfiles/agents/scripts}/*.test.cjs fixture/agents/scripts/
    cp -R ${../mods/dotfiles/agents/scripts/test-fixtures} fixture/agents/scripts/test-fixtures
    cp ${../mods/dotfiles/scripts/lib/reconcile-installs.test.cjs} fixture/scripts/lib/reconcile-installs.test.cjs
    # The adapters exercise real subprocess seams with standalone native CLI
    # fixtures. No registry, real user HOME, or installed agents are needed.
    node --test \
      fixture/scripts/lib/reconcile-installs.test.cjs \
      fixture/agents/scripts/apply-pi-packages.test.cjs \
      fixture/agents/scripts/apply-npmx-tools.test.cjs \
      fixture/agents/scripts/apply-uv-tools.test.cjs
    touch "$out"
  ''
