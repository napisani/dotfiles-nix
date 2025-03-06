{
  programs.git = {
    enable = true;
    userName = "Nick Pisani";
    userEmail = "napisani@yahoo.com";
    ignores = [ "*~" ".DS_Store" ".direnv" ".env.local" ".env" ".rgignore" ];

    # `git dv [...args]`  for doing diffs with diffview
    aliases = { dv = ''! args=$@; shift $#; nvim -c "DiffviewOpen $args"''; };
    extraConfig = {
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
      init = { defaultBranch = "main"; };
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
