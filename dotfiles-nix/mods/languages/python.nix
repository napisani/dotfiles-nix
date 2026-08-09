{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable;
[
  # python
  python3Packages.isort
  pyright
  black
  python3Packages.flake8
  mypy
  ruff
  yapf
  uv
  python312
  rye
]
