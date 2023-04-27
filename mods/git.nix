{
  programs.git = {
    enable = true;
    userName = "Nick Pisani";
    userEmail = "napisani@yahoo.com";
    ignores = [ "*~" ".DS_Store" ".direnv" ".env.local" ".env" ".rgignore" ];
    extraConfig = {
      init = { defaultBranch = "main"; };
    };
  };
}
