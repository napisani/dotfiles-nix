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
  machineRoles ? [ ],
  ...
}:
let
  cfg = config.modelRuntimes;
  isLoancrateMac = builtins.elem "loancrate" machineRoles;
  dotfiles = "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  script = "${dotfiles}/model-runtimes/scripts/apply-models.js";
  stateFile = "${config.home.homeDirectory}/.local/state/nix-models/${cfg.backend}.json";

  # Home-manager activation has a minimal PATH, so use an absolute `awk` path.
  awk = "${pkgs.gawk}/bin/awk";
  mktemp = "${pkgs.coreutils}/bin/mktemp";
  rm = "${pkgs.coreutils}/bin/rm";
  adapter = {
    probe = "ollama";
    # `ollama list` is a `NAME ID SIZE MODIFIED` table; skip its header and
    # keep explicit tags (for example, qwen3:1.7b).
    list = "ollama list | ${awk} 'NR>1{print $1}'";
    install = "ollama pull";
    remove = "ollama rm";
  };
  models = cfg.declaredModels.ollama;
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
      # Light default (just the ~1GB 1.7B model per backend) so a first rebuild
      # doesn't pull gigabytes unasked. Add more (e.g. the coder models below)
      # or override per host in that machine's homes/home-*.nix. A machine-level
      # definition replaces this default rather than merging with it.
      default = {
        ollama = [ "qwen3:1.7b" ]
        ++ lib.optionals isLoancrateMac [ "qwen3.6:35b-a3b-mxfp8" ];
      };
      description = "Per-backend list of model ids to keep installed. Only the active backend's list is managed.";
    };
  };

  # Trusted-path-first PATH (matches the agents CLI installers) so a planted
  # binary in a user-writable dir can't shadow the real ollama binary.
  # Soft-fails: a bad pull/scan warns (and feeds the agents convergence report
  # via AGENTS_WARN_FILE) instead of aborting the whole switch under set -eu.
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

  config.home.activation.createLoancrateQwenCodingModel = lib.mkIf isLoancrateMac (
    lib.hm.dag.entryAfter [ "installModelRuntimeModels" ] ''
      export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
      if ollama show qwen3.6:35b-a3b-mxfp8 >/dev/null 2>&1; then
        _ollama_modelfile="${mktemp}"
        trap '${rm} -f "$_ollama_modelfile"' EXIT
        cat > "$_ollama_modelfile" <<'EOF'
FROM qwen3.6:35b-a3b-mxfp8
PARAMETER num_ctx 16384
PARAMETER presence_penalty 0
PARAMETER temperature 0.7
EOF
        ollama create qwen3.6-coding -f "$_ollama_modelfile"
      else
        echo "model-runtimes: qwen3.6:35b-a3b-mxfp8 unavailable; skipping qwen3.6-coding" >&2
      fi
    ''
  );
}
