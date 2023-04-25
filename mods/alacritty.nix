
{
  programs.alacritty = {
    enable = true;
  };
  home.file.".config/alacritty/alacritty.yml".source = ./dotfiles/alacritty.yml;
}
