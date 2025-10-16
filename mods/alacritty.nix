{
  programs.alacritty = { enable = true; };
  home.file.".config/alacritty/alacritty.toml".source =
    ./dotfiles/alacritty.toml;
}
