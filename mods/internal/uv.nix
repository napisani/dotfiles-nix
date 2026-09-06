{
  config,
  lib,
  pkgs,
  ...
}:
let
  nativeScripts = import ./native-scripts.nix { inherit lib; };
  inherit (lib) mkOption types;
  cfg = config.nativeTools.uv;
in
{
  options.nativeTools.uv = {
    tools = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            package = mkOption { type = types.str; };
            extras = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
            "with" = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
          };
        }
      );
      description = "Native uv registry tools and their required extras/dependencies.";
    };
    toolbox = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Editable project discovery directory; null removes previously tracked projects.";
    };
  };
  config = {
    home.packages = [ pkgs.uv ];

    globalToolOperations.uv.command = ''
      DECLARED_TOOLS=${lib.escapeShellArg (builtins.toJSON cfg.tools)} \
      TOOLBOX=${lib.escapeShellArg (if cfg.toolbox == null then "" else cfg.toolbox)} \
      STATE_FILE=${lib.escapeShellArg "${config.home.homeDirectory}/.local/state/agents-nix/uvx-tools.json"} \
      UV_COMMAND=${pkgs.uv}/bin/uv \
      PYTHON_COMMAND=${pkgs.python3}/bin/python3 \
      FORCE_REPAIR="''${GLOBAL_TOOLS_FORCE_REPAIR:-}" \
        ${pkgs.nodejs}/bin/node ${nativeScripts}/uv/scripts/apply-uv-tools.js
    '';
  };
}
