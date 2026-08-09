{ pkgs, rift, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  homeManagerDir = "~/.config/home-manager";
  switchCommand = "sudo darwin-rebuild switch --show-trace --no-update-lock-file --flake ~/.config/home-manager/.#";
  flakeUpdateCommand = "pushd ${homeManagerDir}; nix flake update --refresh && ${switchCommand}; popd";
in
{
  home.packages = [
    rift.packages.${system}.default
  ];

  programs.bash = {
    shellAliases = {
      nixswitchup = "pushd ${homeManagerDir}; git pull && ${switchCommand}; popd";
      nixswitch = "pushd ${homeManagerDir}; ${switchCommand}; popd";
      nixflakeup = flakeUpdateCommand;
      nixupgrade = flakeUpdateCommand;
      nixclean = "echo 'Collecting garbage...'; nix-collect-garbage -d && echo 'Optimizing store...'; nix store optimise && echo 'Cleaning up old profiles...'; sudo nix-collect-garbage -d && echo 'Done! Space freed.'";
    };
  };
}
