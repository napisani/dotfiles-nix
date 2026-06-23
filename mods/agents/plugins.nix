# agents/plugins.nix — Claude Code plugin installation
#
# agentPluginSources declares plugin marketplaces and the plugins to install.
# Both `claude plugin marketplace add` and `claude plugin install` are idempotent.
#
# Fields:
#   marketplace     — GitHub owner/repo of the marketplace
#   marketplaceName — the `name` field in the repo's .claude-plugin/marketplace.json
#   plugins         — plugin names to install (installed as <name>@<marketplaceName>)
#   condition       — boolean; when false the entry is skipped (default: true)
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  shared = import ./lib.nix { inherit config pkgs-unstable; };
  inherit (shared) isLoancrateMac;

  agentPluginSources = [
    # Loancrate org skills package — provides lc@ and code@ plugins
    {
      marketplace = "loancrate/org-claude-skills";
      marketplaceName = "lc";
      plugins = [
        "lc"
        "code"
      ];
      condition = isLoancrateMac;
    }
  ];

  enabledPluginSources = builtins.filter (s: s.condition or true) agentPluginSources;

  mkClaudePluginCmds =
    source:
    let
      installCmds = builtins.concatStringsSep "\n" (
        map (
          p: "claude plugin install ${lib.escapeShellArg "${p}@${source.marketplaceName}"} --scope user"
        ) source.plugins
      );
    in
    ''
      claude plugin marketplace add ${lib.escapeShellArg source.marketplace} --scope user
      ${installCmds}
    '';

  claudePluginCmds = builtins.concatStringsSep "\n" (
    map mkClaudePluginCmds enabledPluginSources
  );
in
{
  home.activation.installClaudePlugins = lib.hm.dag.entryAfter [ "installAgentSkills" ] ''
    export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
    if command -v claude >/dev/null 2>&1; then
      ${claudePluginCmds}
    else
      echo "agents: 'claude' CLI not found — skipping Claude Code plugin installs" >&2
    fi
  '';
}
