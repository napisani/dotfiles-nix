# OpenCode (~/.config/opencode) — declarative layout:
# - Dotfiles: config, commands, agents, modes, themes → symlinks into mods/dotfiles (edit without rebuild).
# - plugins/: Nix store paths (e.g. superpowers.js) + symlinked repo files.
# - skills:
#   - local/     → symlink mods/dotfiles/opencode/local-skills (your custom skills)
#   - superpowers/ → flake input obra/superpowers
#   - other dirs → community skills from `opencodeCommunitySkillSources` (npx skills add, additive)
{
  config,
  lib,
  inputs,
  pkgs-unstable,
  ...
}:
let
  mkSym =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/${path}";
  mkForcedSym = path: {
    source = mkSym path;
    force = true;
  };

  # Git-hosted skills: copied into ~/.config/opencode/skills/<name> (does not replace local/ or superpowers/).
  opencodeCommunitySkillSources = [
    {
      repo = "https://github.com/anthropics/skills";
      skills = [
        "skill-creator"
        "doc-coauthoring"
      ];
    }
    {
      repo = "https://github.com/langchain-ai/deepagents";
      skills = [ "web-research" ];
    }
  ];

  mkSkillInstallCommand =
    source:
    let
      skillArgs = builtins.concatStringsSep " " (
        map (skillName: "--skill ${lib.escapeShellArg skillName}") source.skills
      );
    in
    ''
      npx --yes skills@latest add ${lib.escapeShellArg source.repo} --global --agent opencode --yes --copy ${skillArgs}
    '';

  opencodeSkillInstallCommands = builtins.concatStringsSep "\n" (
    map mkSkillInstallCommand opencodeCommunitySkillSources
  );

  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
in
{
  home = {
    activation = {
      # plugins/skills must be directories; broken symlinks slip past `test -e`.
      fixOpencodePathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
        for p in "$HOME/.config/opencode/plugins" "$HOME/.config/opencode/skills"; do
          if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
            echo "home-manager: removing stale path at $p (OpenCode expects a directory here)"
            rm -rf "$p"
          fi
        done
      '';

      # After skills/{local,superpowers} symlinks exist. npx (not ~/.local/bin/skills) so npmx.nix is optional.
      installOpencodeCommunitySkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        _oc_skills="$HOME/.config/opencode/skills"
        if [ -L "$_oc_skills" ] || { [ -e "$_oc_skills" ] && [ ! -d "$_oc_skills" ]; }; then
          echo "installOpencodeCommunitySkills: removing stale path at $_oc_skills"
          rm -rf "$_oc_skills"
        fi
        mkdir -p "$_oc_skills"

        export DISABLE_TELEMETRY=1
        export NPM_CONFIG_PREFIX="$HOME/.local"
        export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

        ${opencodeSkillInstallCommands}
      '';
    };

    file = {
      ".config/opencode/config.json" = mkForcedSym "opencode-config.json";
      ".config/opencode/commands" = mkForcedSym "opencode/commands";
      ".config/opencode/agents" = mkForcedSym "opencode/agents";
      ".config/opencode/modes" = mkForcedSym "opencode/modes";
      ".config/opencode/themes" = mkForcedSym "opencode/themes";

      ".config/opencode/plugins/superpowers.js".source =
        inputs.superpowers-src + "/.opencode/plugins/superpowers.js";
      ".config/opencode/plugins/tmux-status.ts" = mkForcedSym "opencode/plugins/tmux-status.ts";

      ".config/opencode/skills/local" = mkForcedSym "opencode/local-skills";
      ".config/opencode/skills/superpowers".source = inputs.superpowers-src + "/skills";
    };
  };
}
