# model-runtimes.nix — declarative model management for the local LLM runtime.
#
# Each system runs exactly one "ollama-compliant" runtime (ollama on Intel Macs,
# mlx-lm on Apple Silicon, ...). This module manages that runtime's *model set*
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
  dotfiles = "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  script = "${dotfiles}/model-runtimes/scripts/apply-models.js";
  stateFile = "${config.home.homeDirectory}/.local/state/nix-models/${cfg.backend}.json";

  # Text utilities referenced by absolute nixpkgs store path: home-manager
  # activation runs with a minimal PATH that lacks /usr/bin, so `awk`/`yes`
  # aren't found there (only the Homebrew CLIs on the PATH export below are).
  awk = "${pkgs.gawk}/bin/awk";
  yes = "${pkgs.coreutils}/bin/yes";

  # Per-backend adapters: three command strings, the only backend-specific bit.
  # Commands verified against ollama's CLI docs and mlx-lm's manage.py source.
  adapters = {
    ollama = {
      probe = "ollama";
      # `ollama list` is a `NAME ID SIZE MODIFIED` table; skip the header row
      # (NR>1) and take col-1 NAME. NAMEs carry the tag (qwen3:1.7b) — declare
      # ids with explicit tags.
      list = "ollama list | ${awk} 'NR>1{print $1}'";
      install = "ollama pull";
      remove = "ollama rm";
    };
    "mlx-lm" = {
      probe = "mlx_lm.manage";
      # `--scan` prints a table (a "Scanning..." line, a REPO ID header, a
      # dashes row, then rows). Repo ids are the only col-1 tokens containing
      # "/", so that filter extracts them past the header noise. `--pattern /`
      # matches every cached repo (all HF ids contain "/"), so a declared id
      # that isn't an mlx-community/* repo is still seen as installed.
      list = "mlx_lm.manage --scan --pattern / 2>/dev/null | ${awk} '$1 ~ \"/\" {print $1}'";
      # mlx-lm has no download subcommand; hf (huggingface_hub) pre-fetches to
      # the same cache scan_cache_dir reads.
      install = "hf download";
      # `--delete --pattern` is a SUBSTRING match and prompts Y/N (empty = no);
      # pass the full repo id and auto-confirm with `yes`. Verified in manage.py.
      remove = "${yes} | mlx_lm.manage --delete --pattern";
    };
  };
  a = adapters.${cfg.backend};
  models = cfg.declaredModels.${cfg.backend} or [ ];
in
{
  options.modelRuntimes = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "ollama"
        "mlx-lm"
      ];
      default =
        if pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin then "mlx-lm" else "ollama";
      description = ''
        The local model runtime this host uses; models are managed for it.
        Defaults by platform (aarch64-darwin -> mlx-lm, else ollama); override
        per host in that machine's homes/home-*.nix.
      '';
    };
    declaredModels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      # Light default (just the ~1GB 1.7B model per backend) so a first rebuild
      # doesn't pull gigabytes unasked. Add more (e.g. the coder models below)
      # or override per host in that machine's homes/home-*.nix. A machine-level
      # definition replaces this default rather than merging with it.
      default = {
        ollama = [
          "qwen3:1.7b"
          # "qwen2.5-coder:14b"
        ];
        "mlx-lm" = [
          "mlx-community/Qwen3-1.7B-4bit"
          # "mlx-community/Qwen2.5-Coder-14B-Instruct-4bit"
        ];
      };
      description = "Per-backend list of model ids to keep installed. Only the active backend's list is managed.";
    };
  };

  # Trusted-path-first PATH (matches the agents CLI installers) so a planted
  # binary in a user-writable dir can't shadow the real ollama/mlx_lm/hf.
  # Soft-fails: a bad pull/scan warns (and feeds the agents convergence report
  # via AGENTS_WARN_FILE) instead of aborting the whole switch under set -eu.
  config.home.activation.installModelRuntimeModels = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
    if command -v ${a.probe} >/dev/null 2>&1; then
      BACKEND=${lib.escapeShellArg cfg.backend} \
      DECLARED_MODELS=${lib.escapeShellArg (builtins.toJSON models)} \
      STATE_FILE=${lib.escapeShellArg stateFile} \
      LIST_CMD=${lib.escapeShellArg a.list} \
      INSTALL_CMD=${lib.escapeShellArg a.install} \
      REMOVE_CMD=${lib.escapeShellArg a.remove} \
        ${nodeBin}/node ${lib.escapeShellArg script} \
        || echo "model-runtimes: WARNING: model sync failed for ${cfg.backend} — continuing activation" >&2
    else
      echo "model-runtimes: ${a.probe} not found on PATH — skipping model sync for ${cfg.backend}" >&2
    fi
  '';
}
