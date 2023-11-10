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

# install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
# or this
nix build  --extra-experimental-features "nix-command flakes" .#${MY_HOST}.system
```
4. Then apply the nix flake:
```bash
./result/sw/bin/darwin-rebuild switch --flake ./.#
```
5. set the shell 
```bash
# make this bash shell considered a "standard shell" 
echo /run/current-system/sw/bin/bash | sudo tee -a /etc/shells
 -s /run/current-system/sw/bin/bash
```

Helpful github issue thread for diagnosing any initial Karabiner problems:
```
https://github.com/LnL7/nix-darwin/issues/564
```
