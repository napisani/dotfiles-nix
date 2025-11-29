{ ... }: {
  programs.bash = {
    shellAliases = {
      nixswitchup =
        "pushd ~/.config/home-manager; git pull && sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixswitch =
        "pushd ~/.config/home-manager; sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixup = "pushd ~/.config/home-manager; nix flake update; nixswitch; popd";
    };
  };
}
