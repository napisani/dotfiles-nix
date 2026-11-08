{
  config,
  pkgs,
  lib,
  ...
}:
{
  documentation.enable = false;

  programs = {
    bash = {
      enable = true;
      completion = {
        enable = true;
      };
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  environment.shells = [ pkgs.bash ];

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.symbols-only
  ];

  # CustomUserPreferences replaces the entire hotkey dictionary, including
  # unrelated user bindings; plutil preserves those entries and key parameters.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    USER_HOME="$(dscl . -read /Users/${config.system.primaryUser} NFSHomeDirectory | awk '{print $2}')"
    /usr/bin/plutil -replace AppleSymbolicHotKeys.64.enabled -bool NO \
      "$USER_HOME/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || true
    /usr/bin/plutil -replace AppleSymbolicHotKeys.65.enabled -bool NO \
      "$USER_HOME/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || true
  '';

  system = {
    primaryUser = "nick";

    defaults = {
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirst = true;
        FXDefaultSearchScope = "SCcf";
        FXPreferredViewStyle = "clmv";
        FXRemoveOldTrashItems = true;
        ShowPathbar = true;
        QuitMenuItem = true;
        ShowStatusBar = true;
      };

      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        AppleInterfaceStyle = "Dark";
        "com.apple.swipescrolldirection" = false;
      };
    };

    stateVersion = 4;
  };

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = lib.optionalString (
      config.nix.package == pkgs.nixVersions.stable
    ) "experimental-features = nix-command flakes";
    enable = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
  };

}
