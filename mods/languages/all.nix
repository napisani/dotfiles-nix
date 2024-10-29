{ pkgs, pkgs-unstable, ... }:
let
  jsPackages = import ./javascript.nix { inherit pkgs pkgs-unstable; };
  pythonPackages = import ./python.nix { inherit pkgs pkgs-unstable; };

  golangPackages = import ./golang.nix { inherit pkgs pkgs-unstable; };

  rustPackages = import ./rust.nix { inherit pkgs pkgs-unstable; };

  ocamlPackages = import ./ocaml.nix { inherit pkgs pkgs-unstable; };

  # javaPackages = import ./java.nix { inherit pkgs pkgs-unstable; };

  luaPackages = import ./lua.nix { inherit pkgs pkgs-unstable; };
  nixPackages = import ./nix.nix { inherit pkgs pkgs-unstable; };
  bashPackages = import ./bash.nix { inherit pkgs pkgs-unstable; };
  miscPackages = import ./misc.nix { inherit pkgs pkgs-unstable; };
in with pkgs-unstable;
jsPackages ++ pythonPackages ++ golangPackages ++ rustPackages ++ ocamlPackages
++ luaPackages ++ nixPackages ++ bashPackages ++ miscPackages

