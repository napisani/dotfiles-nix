{ pkgs, rift, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.packages = [
    rift.packages.${system}.default
  ];

  programs.bash = {
    shellAliases = {
      nixswitchup = "pushd ~/.config/home-manager; git pull && sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixswitch = "pushd ~/.config/home-manager; sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixflakeup = "pushd ~/.config/home-manager; nix flake update && nix flake lock --override-input workmux github:raine/workmux/1764fe71affc24984b084e1ce9409985a0d11afb && nixswitch; popd";
      nixclean = "echo 'Collecting garbage...'; nix-collect-garbage -d && echo 'Optimizing store...'; nix store optimise && echo 'Cleaning up old profiles...'; sudo nix-collect-garbage -d && echo 'Done! Space freed.'";
    };
  };
}
