{
  self,
  lib,
  pkgs,
}:
let
  systems =
    builtins.attrValues self.darwinConfigurations ++ builtins.attrValues self.nixosConfigurations;
  homes = map (system: system.config.home-manager.users.nick) systems;
  runtimePath = ".local/share/nvim/vocal-python";
  nativeHost =
    {
      aarch64-darwin = self.darwinConfigurations.nicks-mbp;
      x86_64-darwin = self.darwinConfigurations.maclab;
      x86_64-linux = self.nixosConfigurations.supermicro;
    }
    .${pkgs.stdenv.hostPlatform.system};
  runtime = nativeHost.config.home-manager.users.nick.home.file.${runtimePath}.source;
in
# Every host gets a revocable Home Manager link, not an activation-time venv.
assert lib.all (home: builtins.hasAttr runtimePath home.home.file) homes;
assert lib.all (home: !(lib.hasInfix "VOCAL_VENV" home.globalToolOperations.uv.command)) homes;
pkgs.runCommand "vocal-runtime"
  {
    nativeBuildInputs = [ pkgs.neovim-unwrapped ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.local/share/nvim"
    ln -s ${runtime} "$HOME/${runtimePath}"
    export PATH="${./fixtures/project-python}:$PATH"
    nvim --headless -u NONE -i NONE -l ${./fixtures/vocal-runtime.lua} \
      ${../mods/dotfiles/nvim/lua/user/plugins/ai/vocal.lua}
    touch "$out"
  ''
