{
  pkgs,
  user,
  overlays,
  ...
}:
{
  imports = [
    # if you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homemanagermodule

    # you can also split up your configuration and import pieces of it here:
    ../mods/base-packages.nix
    ../mods/shell.nix
    ../mods/git.nix
    ../mods/neovim.nix
  ];

  nixpkgs = {
    # you can add overlays here
    overlays = overlays;

    # configure your nixpkgs instance
    config = {
      # disable if you don't want unfree packages
      allowUnfree = true;
      # workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
      # packageoverrides = pkgs: rec {
      # secret_inject = pkgs.callpackage ../mods/secret_inject.nix { };
      # };
    };
  };

  home = {
    username = user;
    # homedirectory = "/users/nick";
    sessionVariables = {
      MACHINE_NAME = "supermicro";
    };
  };

  home.packages = with pkgs; [ gcc ];

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  # programs.git.enable = true;

  # programs.bash is gone: ~/.bashrc and friends are native dotfiles now (see
  # mods/dotfiles/shell/OWNERSHIP.md). The three supermicro-only aliases moved
  # to bash/rc.d/80-machine.sh, keyed off MACHINE_NAME, and SHELL is resolved at
  # runtime in bash/profile instead of being pinned to a bashInteractive store
  # path.

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";

}
