{ pkgs, pkgs-unstable, procmux, secret_inject, animal_rescue, ... }: {

  home.packages = with pkgs-unstable;
    [
      # firefox-devedition
    ];

}
