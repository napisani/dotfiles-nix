{
  programs.git = {
    enable = true;
    ignores = [
      "*~"
      ".DS_Store"
      ".direnv"
      ".env.local"
      ".env"
      ".rgignore"
    ];

    settings = {
      user = {
        name = "Nick Pisani";
        email = "napisani@yahoo.com";
      };
      # `git dv [...args]`  for doing diffs with diffview
      alias = {
        dv = ''! args=$@; shift $#; nvim -c "DiffviewOpen $args"'';
      };
      # https://blog.gitbutler.com/how-git-core-devs-configure-git/
      core = {
        editor = "nvim";
      };
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      commit = {
        verbose = true;
      };
      branch = {
        sort = "-committerdate";
      };
      column = {
        ui = "auto";
      };
      init = {
        defaultBranch = "main";
      };
      rebase = {
        updateRefs = true;
        autoSquash = true;
      };

      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };

      tag = {
        sort = "version:refname";
      };

      "filter \"lfs\"" = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };
    };
  };
}
