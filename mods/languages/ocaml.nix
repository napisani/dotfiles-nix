{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable; [
  opam
  ocamlPackages.ocaml
  ocamlPackages.dune_3
  ocamlPackages.findlib
  ocamlPackages.utop
  ocamlPackages.odoc
  ocamlPackages.ocaml-lsp
  ocamlformat
]

