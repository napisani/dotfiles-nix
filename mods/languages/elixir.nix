{ pkgs, pkgs-unstable, ... }:

with pkgs-unstable; [
  # Elixir runtime and build tool
  elixir

  # Language server for Elixir
  elixir-ls

  # Code formatter (built into Elixir, but including for completeness)
  # mix format is built-in

]
