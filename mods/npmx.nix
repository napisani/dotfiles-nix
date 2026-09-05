{
  config,
  lib,
  pkgs-unstable,
  machineRoles ? [ ],
  homeManagerRelPath,
  ...
}:

let
  # The public desired state uses a name -> exact-version map. This adapter
  # translates it to the reconciler's ordered native declaration shape.
  npmxTools = lib.mapAttrsToList (name: version: {
    inherit name version;
  }) config.agents.globalNpmTools;

  removedNpmPackages = [
    "@mariozechner/pi-coding-agent"
    "pi-skillful"
    # Duplicated `rtk init -g --opencode`'s own generated plugin
    # (~/.config/opencode/plugins/rtk.ts) — keep just the one rtk source.
    "openrtk"
    "@agentmemory/mcp"
    "@agentmemory/agentmemory"
  ];

  # Pi packages are declared in config.agents.pi.packages and diff-pruned by
  # the Pi adapter's installPiPackages activation — not here. That mechanism tracks Nix-managed state and removes anything
  # undeclared automatically, replacing this file's old manually-maintained
  # removedPiPackages list.

  npm = "${pkgs-unstable.nodejs}/bin/npm";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
  home = config.home.homeDirectory;
  npmPrefix = "${home}/.local";
  scriptsDir = "${home}/${homeManagerRelPath}/mods/dotfiles/agents/scripts";
  stateFile = "${home}/.local/state/agents-nix/npmx-tools.json";

  # ~/.npmrc used to be declared via home.file (mods/shell.nix), which Home
  # Manager links as a read-only symlink into /nix/store. That's fine as
  # long as nothing ever tries to write to it again later — but this module
  # used to also run `npm config set prefix ... --location=user`, which
  # always failed EACCES against that immutable target (npm's own error
  # message misleadingly blamed a root-owned ~/.npm cache instead). Writing
  # ~/.npmrc imperatively here, as a real file, keeps it colocated with the
  # rest of this module's npm setup and keeps any future imperative
  # `npm config` write actually usable. See WORKAROUNDS.md "npm config set
  # prefix vs. immutable ~/.npmrc".
  npmrcContent =
    "prefix=${npmPrefix}\n"
    + lib.optionalString (builtins.elem "loancrate" machineRoles) "//registry.npmjs.org/:_authToken=\${NODE_AUTH_TOKEN}\n";

  agentsCheckUpdates = pkgs-unstable.writeShellApplication {
    name = "agents-check-updates";
    text = ''
      DECLARED_TOOLS=${lib.escapeShellArg (builtins.toJSON npmxTools)} \
      NPM_COMMAND=${lib.escapeShellArg npm} \
        ${nodeBin}/node ${scriptsDir}/check-npm-tool-updates.js
    '';
  };
in
{
  home.packages = [
    pkgs-unstable.nodejs
    pkgs-unstable.git
    agentsCheckUpdates
  ];

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = npmPrefix;
  };

  # Keep ~/.npmrc a plain writable file, but avoid changing its mtime when the
  # desired content already matches. A legacy Home Manager symlink is always
  # replaced even if its contents happen to match.
  home.activation.writeNpmrc = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    npmrc_target="${home}/.npmrc"
    npmrc_tmp="$npmrc_target.tmp.$$"
        cat > "$npmrc_tmp" <<'NPMRC_EOF'
    ${npmrcContent}NPMRC_EOF
    if [ ! -L "$npmrc_target" ] && [ -f "$npmrc_target" ] && cmp -s "$npmrc_tmp" "$npmrc_target"; then
      rm -f "$npmrc_tmp"
    else
      mv -f "$npmrc_tmp" "$npmrc_target"
    fi
  '';

  home.activation.installNpmxTools = lib.mkIf config.agents.enable (
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "agentsWarnReportInit"
        "writeNpmrc"
      ]
      ''
        export NPM_CONFIG_PREFIX="${npmPrefix}"
        mkdir -p "$NPM_CONFIG_PREFIX/bin" "$NPM_CONFIG_PREFIX/lib"
        export DISABLE_TELEMETRY=1
        # Home Manager activation runs with a minimal PATH; ensure npm scripts can
        # find `node` and git while preserving the managed prefix's executables.
        export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

        if ! DECLARED_TOOLS=${lib.escapeShellArg (builtins.toJSON npmxTools)} \
          LEGACY_SEED=${
            lib.escapeShellArg (
              builtins.toJSON (removedNpmPackages ++ builtins.attrNames config.agents.globalNpmTools)
            )
          } \
          NPM_COMMAND=${lib.escapeShellArg npm} \
          STATE_FILE=${lib.escapeShellArg stateFile} \
          FORCE_REPAIR="''${AGENTS_FORCE_REPAIR:-}" \
          ${nodeBin}/node ${scriptsDir}/apply-npmx-tools.js; then
          echo "installNpmxTools: npm tool reconciliation failed; retry with network access or run a forced repair." >&2
          printf '%s\n' "npmx: npm tool reconciliation failed" >> "''${AGENTS_WARN_FILE:-/dev/null}"
        fi

        # Some npm packages ship their bin entrypoints without the executable bit.
        # Ensure anything linked into ~/.local/bin is runnable.
        chmod -R u+rx "$NPM_CONFIG_PREFIX/bin" 2>/dev/null || true
      ''
  );
}
