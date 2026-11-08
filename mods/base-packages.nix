{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
{
  environment.systemPackages = [
    pkgs.bashInteractive
    pkgs.nil
    pkgs.nixfmt
    pkgs.nix-search-cli
  ]
  ++ map (name: inputs.${name}.packages.${system}.default) [
    "secret_inject"
    "tmux_picker"
    "mushy_lint"
    "animal_rescue"
    "proctmux"
    "stackman"
    "scute"
  ]
  # Conda GnuPG's default pinentry executable is absent on macOS.
  ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    pkgs.gnupg
    pkgs.man
    pkgs.ncurses
  ];
  environment.extraOutputsToInstall = [ "man" ];
  environment.pathsToLink = [
    "/share/man"
    "/share/terminfo"
  ];
}
