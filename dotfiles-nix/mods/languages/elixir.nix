{ pkgs, pkgs-unstable, ... }:

with pkgs-unstable; [
  # Elixir runtime and build tool (top-level `elixir` is deprecated in favor
  # of the beamPackages set).
  beamPackages.elixir

  # Language server for Elixir
  elixir-ls

  # Code formatter (built into Elixir, but including for completeness)
  # mix format is built-in

]
