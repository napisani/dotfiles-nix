{ config, pkgs, lib, ... }:{

  homebrew = {
    masApps = {
       /* "Apple Configurator" = 1037126344; */
    };
    # anything installed with brew cask
    casks = [
      "slack"
      "discord"
    ];
    # anything installed with brew (non-casks)
    brews = [
      /* "procmux" */
      /* "mkcert" */
    ];
    # any custom taps / repos
    taps = [
    ];
  };
}
