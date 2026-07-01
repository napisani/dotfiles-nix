# agents/loancrate-config.nix — Manages ~/.claude/loancrate.json (loancrate system only)
#
# Merges the declared base config on every rebuild via apply-loancrate-config.js.
# Skill-discovered keys (e.g. linear_team_statuses, gh_username) that are absent
# from the base are preserved — the merge is non-destructive for unknown keys.
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  shared = import ./lib.nix { inherit config pkgs-unstable; };
  inherit (shared) isLoancrateMac home nodeBin;

  scriptsDir = "${home}/.config/home-manager/mods/dotfiles/agents/scripts";

  baseConfig = builtins.toJSON {
    user_prefix = "nick";
    work_root = "${home}/Work";
    team_repos = {
      lc = "${home}/code/loancrate/loancrate";
    };
  };
in
lib.mkIf isLoancrateMac {
  home.activation.applyLoancrateConfig = lib.hm.dag.entryAfter [ "installClaudePlugins" ] ''
    export PATH="${nodeBin}:$PATH"
    LOANCRATE_BASE_CONFIG=${lib.escapeShellArg baseConfig} \
      ${nodeBin}/node ${scriptsDir}/apply-loancrate-config.js
  '';
}
