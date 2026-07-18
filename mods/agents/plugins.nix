# agents/plugins.nix — Claude Code plugin installation
#
# agentPluginSources declares plugin marketplaces and the plugins to install.
# Both `claude plugin marketplace add` and `claude plugin install` are idempotent.
#
# Fields:
#   marketplace     — GitHub owner/repo (optionally with #branch, e.g. "owner/repo#workmux")
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
      marketplace = "loancrate/org-claude-skills#workmux";
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
      reinstallCmds = builtins.concatStringsSep "\n" (
        map (p: ''
          claude plugin uninstall ${lib.escapeShellArg "${p}@${source.marketplaceName}"} --scope user 2>/dev/null || true
          claude plugin install ${lib.escapeShellArg "${p}@${source.marketplaceName}"} --scope user
        '') source.plugins
      );
    in
    ''
      claude plugin marketplace add ${lib.escapeShellArg source.marketplace} --scope user
      ${reinstallCmds}
    '';

  claudePluginCmds = builtins.concatStringsSep "\n" (
    map mkClaudePluginCmds enabledPluginSources
  );
in
{
  # NB: when no plugin sources are enabled, claudePluginCmds is empty and bash
  # rejects an empty `then` block — emit a no-op (`:`) in that case.
  home.activation.installClaudePlugins = lib.hm.dag.entryAfter [ "installAgentSkills" ] ''
    export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
    if command -v claude >/dev/null 2>&1; then
      ${if claudePluginCmds == "" then ":" else claudePluginCmds}
    else
      echo "agents: 'claude' CLI not found — skipping Claude Code plugin installs" >&2
    fi
  '';
}
