#!/usr/bin/env bash
nix run nixpkgs#node2nix -- -i package.json -o node-packages.nix
