# Dotfiles.nix

Dotfiles, powered by [Nix](https://nixos.org/nix/) and [home-manager](https://github.com/rycee/home-manager).

## How to use (Mac)

1. Install Nix:
```bash
sh <(curl -L https://nixos.org/nix/install)

# install home manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

nix-shell '<home-manager>' -A install
```
2. Go inside your `~/.config` directory and clone this repo:
```bash
mkdir ~/.config && cd ~/.config && \
git clone https://github.com/napisani/dotfiles-nix.git home-manager && cd home-manager 
```
3. one-time build of the  `darwin-rebuild` binary
```bash
export MY_HOST=nick-mb
nix build  --extra-experimental-features "nix-command flakes" .#darwinConfigurations.$MY_HOST.system
```
4. Then apply the nix flake:
```bash
./result/sw/bin/darwin-rebuild switch --flake ./.#
```

