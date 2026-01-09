{
  xdg.configFile."git/template/config".text = builtins.concatStringsSep "\n" [
    "[core]"
    "    excludesFile = .gitignore_local"
    ""
  ];

  xdg.configFile."git/template/info/exclude".text =
    builtins.concatStringsSep "\n" [ ".gitignore_local" "" ];

  programs.git = {
    enable = true;
    ignores = [ "*~" ".DS_Store" ".direnv" ".env.local" ".env" ".rgignore" ];

    settings = {
      user = {
        name = "Nick Pisani";
        email = "napisani@yahoo.com";
      };
      # `git dv [...args]`  for doing diffs with diffview
      alias = { dv = ''! args=$@; shift $#; nvim -c "DiffviewOpen $args"''; };
      # https://blog.gitbutler.com/how-git-core-devs-configure-git/
      core = { editor = "nvim"; };
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      commit = { verbose = true; };
      branch = { sort = "-committerdate"; };
      column = { ui = "auto"; };
      init = {
        defaultBranch = "main";
        templateDir = "~/.config/git/template";
      };
      rebase = {
        updateRefs = true;
        autoSqaush = true;
      };

      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };

      tag = { sort = "version:refname"; };
    };
  };
}
