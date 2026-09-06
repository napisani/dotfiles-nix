# model-runtimes.nix — declarative model management for the local LLM runtime.
#
# Each system uses Ollama. This module manages its local model set
# declaratively — pull declared, prune previously-managed-but-undeclared — via
# the backend-agnostic engine in dotfiles/model-runtimes/scripts/apply-models.js.
# It does NOT install/configure the runtime itself (that stays in the brew/cask
# in systems/profiles/darwin-base.nix). This is a Layer 2 tracked-state
# mechanism outside the agents domain — see docs/adr/0002-layered-asset-management.md
# and docs/superpowers/specs/2026-07-27-declarative-model-runtimes-design.md.
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
let
  cfg = config.modelRuntimes;
  nativeScripts = import ./native-scripts.nix { inherit lib; };
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  script = "${nativeScripts}/model-runtimes/scripts/apply-models.js";
  stateFile = "${config.home.homeDirectory}/.local/state/nix-models/${cfg.backend}.json";

  # Home-manager activation has a minimal PATH, so use an absolute `awk` path.
  awk = "${pkgs.gawk}/bin/awk";
  adapter = {
    probe = "ollama";
    # `ollama list` is a `NAME ID SIZE MODIFIED` table; skip its header and
    # keep explicit tags.
    list = "ollama list | ${awk} 'NR>1{print $1}'";
    install = "ollama pull";
    remove = "ollama rm";
  };
  models = cfg.declaredModels.ollama or [ ];
  createCustomModel =
    name: model:
    let
      modelfile = pkgs.writeText "ollama-Modelfile" (
        "FROM ${model.from}\n"
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            parameter: value: "PARAMETER ${parameter} ${builtins.toJSON value}"
          ) model.parameters
        )
        + "\n"
      );
    in
    ''
      if ollama show ${lib.escapeShellArg model.from} >/dev/null 2>&1; then
        ollama create ${lib.escapeShellArg name} -f ${modelfile}
      else
        echo ${lib.escapeShellArg "model-runtimes: ${model.from} unavailable; skipping ${name}"} >&2
      fi
    '';
in
{
  options.modelRuntimes = {
    backend = lib.mkOption {
      type = lib.types.enum [ "ollama" ];
      default = "ollama";
      description = "The local model runtime. Ollama is used on every host.";
    };
    declaredModels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Per-backend list of model ids to keep installed. Only the active backend's list is managed.";
    };
  };

  options.modelRuntimes.customModels = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          from = lib.mkOption {
            type = lib.types.str;
            description = "Base model to derive from; declare it in declaredModels as well.";
          };
          parameters = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.oneOf [
                lib.types.str
                lib.types.int
                lib.types.float
              ]
            );
            default = { };
            description = "Native Ollama PARAMETER values.";
          };
        };
      }
    );
    description = "Named Ollama models to create from available bases. Creation only; removal does not prune existing custom models.";
  };

  # Trusted-path-first PATH (matches the agents CLI installers) so a planted
  # binary in a user-writable dir can't shadow the real ollama binary.
  # Soft-fails: a bad pull/scan warns (and feeds the global-tools report
  # via GLOBAL_TOOLS_WARN_FILE) instead of aborting the whole switch under set -eu.
  config.home.activation.installModelRuntimeModels = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
    if command -v ${adapter.probe} >/dev/null 2>&1; then
      BACKEND=${lib.escapeShellArg cfg.backend} \
      DECLARED_MODELS=${lib.escapeShellArg (builtins.toJSON models)} \
      STATE_FILE=${lib.escapeShellArg stateFile} \
      LIST_CMD=${lib.escapeShellArg adapter.list} \
      INSTALL_CMD=${lib.escapeShellArg adapter.install} \
      REMOVE_CMD=${lib.escapeShellArg adapter.remove} \
        ${nodeBin}/node ${lib.escapeShellArg script} \
        || echo "model-runtimes: WARNING: model sync failed for ${cfg.backend} — continuing activation" >&2
    else
      echo "model-runtimes: ${adapter.probe} not found on PATH — skipping model sync for ${cfg.backend}" >&2
    fi
  '';

  config.home.activation.createConfiguredOllamaModels = lib.mkIf (cfg.customModels != { }) (
    lib.hm.dag.entryAfter [ "installModelRuntimeModels" ] (
      ''
        export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
      ''
      + lib.concatStringsSep "\n" (lib.mapAttrsToList createCustomModel cfg.customModels)
    )
  );
}
