{
  config,
  lib,
  pkgs-unstable,
  ...
}:

let
  # The public desired state uses a name -> exact-version map. This adapter
  # translates it to the reconciler's ordered native declaration shape.
  npmxTools = lib.mapAttrsToList (name: version: {
    inherit name version;
  }) config.nativeTools.npm.tools;
  invalidVersions = lib.filterAttrs (
    _name: version: builtins.match "^[0-9]+\\.[0-9]+\\.[0-9]+([+-][0-9A-Za-z.-]+)?$" version == null
  ) config.nativeTools.npm.tools;

  npm = "${pkgs-unstable.nodejs}/bin/npm";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
  home = config.home.homeDirectory;
  npmPrefix = "${home}/.local";
  nativeScripts = import ./native-scripts.nix { inherit lib; };
  scriptsDir = "${nativeScripts}/npm/scripts";
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
  npmrcContent = "prefix=${npmPrefix}\n" + config.nativeTools.npm.extraNpmrc;

  globalToolsCheckUpdates = pkgs-unstable.writeShellApplication {
    name = "global-tools-check-updates";
    text = config.globalToolOperations.npm.checkUpdates;
  };
in
{
  options.nativeTools.npm = {
    tools = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Global npm package names mapped to exact desired versions.";
    };
    extraNpmrc = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional declarative lines in the managed npmrc file.";
    };
  };
  config = {
    assertions = [
      {
        assertion = invalidVersions == { };
        message = "npm: global tools require exact semantic versions: ${builtins.concatStringsSep ", " (builtins.attrNames invalidVersions)}";
      }
    ];
    home.packages = [
      pkgs-unstable.nodejs
      pkgs-unstable.git
      globalToolsCheckUpdates
    ];

    home.sessionVariables = {
      NPM_CONFIG_PREFIX = npmPrefix;
    };

    globalToolOperations.npm-config = {
      command = ''
        TARGET_FILE=${lib.escapeShellArg "${home}/.npmrc"} \
        DECLARED_CONTENT=${lib.escapeShellArg npmrcContent} \
          ${nodeBin}/node ${nativeScripts}/scripts/apply-managed-file.js
      '';
    };

    globalToolOperations.npm = {
      after = [ "npm-config" ];
      checkUpdates = ''
        DECLARED_TOOLS=${lib.escapeShellArg (builtins.toJSON npmxTools)} \
        NPM_COMMAND=${lib.escapeShellArg npm} \
          ${nodeBin}/node ${scriptsDir}/check-npm-tool-updates.js
      '';
      command = ''
        export NPM_CONFIG_PREFIX="${npmPrefix}"
        export DISABLE_TELEMETRY=1
        export PATH="${gitBin}:${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"
        DECLARED_TOOLS=${lib.escapeShellArg (builtins.toJSON npmxTools)} \
        NPM_COMMAND=${lib.escapeShellArg npm} \
        STATE_FILE=${lib.escapeShellArg stateFile} \
        FORCE_REPAIR="''${GLOBAL_TOOLS_FORCE_REPAIR:-}" \
          ${nodeBin}/node ${scriptsDir}/apply-npmx-tools.js
      '';
    };

  };
}
