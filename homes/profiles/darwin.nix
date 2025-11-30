{ ... }: {
  programs.bash = {
    shellAliases = {
      nixswitchup =
        "pushd ~/.config/home-manager; git pull && sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixswitch =
        "pushd ~/.config/home-manager; sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixup = "pushd ~/.config/home-manager; nix flake update; nixswitch; popd";
      nixclean =
        "echo 'Collecting garbage...'; nix-collect-garbage -d && echo 'Optimizing store...'; nix store optimise && echo 'Cleaning up old profiles...'; sudo nix-collect-garbage -d && echo 'Done! Space freed.'";
    };
  };
}
