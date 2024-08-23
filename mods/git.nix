{
  programs.git = {
    enable = true;
    userName = "Nick Pisani";
    userEmail = "napisani@yahoo.com";
    ignores = [ "*~" ".DS_Store" ".direnv" ".env.local" ".env" ".rgignore" ];

    # `git dv [...args]`  for doing diffs with diffview
    aliases = { dv = ''! args=$@; shift $#; nvim -c "DiffviewOpen $args"''; };
    extraConfig = {
      core = { editor = "nvim"; };
      init = { defaultBranch = "main"; };
      rebase = {
        updateRefs = true;
        autoSqaush = true;
      };
    };
  };
}
