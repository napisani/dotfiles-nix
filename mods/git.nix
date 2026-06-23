{ lib, ... }:
{
  # Seed every new repo (git init / git clone) with .gitignore_local in
  # info/exclude so the file is silently excluded without touching each
  # project's committed .gitignore. For existing repos, run `git-local-ignore`
  # (defined in .bashrc.d/0070_git.bashrc) once from inside the repo.
  home.file.".config/git/template/info/exclude".text = ''
    # Per-repo local gitignore — not committed to the repository.
    # Add personal patterns here (editor temp files, local build artifacts, etc.)
    .gitignore_local
  '';

  programs.git = {
    enable = true;
    signing.format = "openpgp";
    ignores = [
      "*~"
      ".DS_Store"
      ".direnv"
      ".env.local"
      ".env"
      ".rgignore"
      ".gitignore_local"
    ];

    # Any repo under ~/ automatically uses a local .gitignore_local file (if
    # present) as its per-repo exclude file. The file is ignored globally above
    # so it never shows up as untracked without per-project .gitignore changes.
    includes = [
      {
        condition = "gitdir:~/";
        contents = {
          core.excludesFile = ".gitignore_local";
        };
      }
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
        templateDir = "~/.config/git/template";
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
