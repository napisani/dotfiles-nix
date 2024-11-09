{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable; [
  openjdk11
  gradle
  google-java-format
]

