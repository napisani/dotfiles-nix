# Internal command registrations, not another public capability model or
# reconciler. Activation and the operations CLI execute identical commands.
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  inherit (lib) mkOption types;
  scripts = import ./native-scripts.nix { inherit lib; };
  plan = (import ./operation-plan.nix { inherit lib; }) config.globalToolOperations;
  entries = map (
    name:
    let
      op = config.globalToolOperations.${name};
    in
    {
      inherit name;
      inherit (op) canUpdate;
      command = pkgs-unstable.writeShellScript "global-tools-${name}" ("set -eu\n" + op.command);
      checkUpdates =
        if op.checkUpdates == null then
          null
        else
          pkgs-unstable.writeShellScript "global-tools-${name}-check-updates" ("set -eu\n" + op.checkUpdates);
    }
  ) plan;
  managedFiles = lib.filterAttrs (
    name: file: file.enable && builtins.elem name config.nativeManagedFiles
  ) config.home.file;
  manifest = pkgs-unstable.writeText "global-tools-operations.json" (
    builtins.toJSON {
      operations = entries;
      files = lib.mapAttrsToList (_: file: {
        target = "${config.home.homeDirectory}/${file.target}";
        source = toString file.source;
      }) managedFiles;
    }
  );
  cli = pkgs-unstable.writeShellScriptBin "global-tools" ''
    exec ${pkgs-unstable.nodejs}/bin/node ${scripts}/scripts/global-tools.js ${manifest} "$@"
  '';
in
{
  imports = [ ./global-tools-report.nix ];
  options.nativeManagedFiles = mkOption {
    internal = true;
    type = types.listOf types.str;
    default = [ ];
    description = "Adapter-owned Home Manager targets to inspect; paths are not interpreted by the dispatcher.";
  };
  options.globalToolOperations = mkOption {
    internal = true;
    default = { };
    type = types.attrsOf (
      types.submodule {
        options = {
          command = mkOption { type = types.lines; };
          checkUpdates = mkOption {
            type = types.nullOr types.lines;
            default = null;
          };
          canUpdate = mkOption {
            type = types.bool;
            default = false;
          };
          after = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Ordering only: dependents still run after predecessor failure. Success-gated dependencies are not supported.";
          };
        };
      }
    );
    description = "Adapter-owned operational commands; no dispatch policy in the CLI.";
  };
  config = {
    home.packages = [ cli ];
    home.activation = builtins.listToAttrs (
      lib.imap0 (index: entry: {
        name = "reconcileGlobalTools-${entry.name}";
        value =
          lib.hm.dag.entryAfter
            (
              [
                "linkGeneration"
                "globalToolsReportInit"
              ]
              # HM is sequential too. Chain the computed plan so its relative
              # operation order is exactly the same as the CLI's, including ties.
              ++ lib.optional (index > 0) "reconcileGlobalTools-${builtins.elemAt plan (index - 1)}"
            )
            ''
              ${entry.command} || {
                printf '%s\n' ${lib.escapeShellArg "global-tools: ${entry.name} failed; run global-tools status ${entry.name}"} >&2
                printf '%s\n' ${lib.escapeShellArg "${entry.name}: reconciliation failed"} >> "''${GLOBAL_TOOLS_WARN_FILE:-/dev/null}"
              }
            '';
      }) entries
    );
  };
}
