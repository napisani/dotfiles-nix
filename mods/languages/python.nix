{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable; [
  # python
  python3Packages.isort
  pyright
  black
  python3Packages.flake8
  mypy
  ruff
  yapf

  (pkgs-unstable.python310.withPackages (p: [
    p.ipython # interactive shell
    p.pipx
    # p.tiktoken
  ]))
  rye
]

