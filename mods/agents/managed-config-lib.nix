# agents/managed-config-lib.nix — JSON/TOML managed-key merge+prune utilities
#
# Format-specific, agent-blind utilities (see docs/adr/0001-per-agent-modules.md):
# each takes a target file, a key within it, and this run's full declared
# entry set, and merges + prunes that one key — true revocation, not just
# add/update. Tracks which entry names were Nix-managed in a small state
# file so removing a Nix declaration actually removes it next run, while
# never touching keys the user added by hand outside of Nix.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname; };
  inherit (shared) dotfiles nodeBin home;

  scriptsDir = "${dotfiles}/agents/scripts";

  # Where the "previously managed" name set for one (target, key) pair is
  # tracked across activations. `stateId` is a caller-supplied stable name
  # (e.g. "claude-mcp-servers") — kept explicit and readable rather than
  # derived/hashed, so the state file is easy to find and inspect by hand.
  mkStateFile = stateId: "${home}/.local/state/agents-nix/${stateId}.json";

  # Note: home-manager's generated activation script runs under `set -eu` +
  # `pipefail` — any command that exits non-zero aborts the *entire*
  # activation, not just this step. Both scripts below can legitimately
  # exit non-zero (invalid target JSON/TOML, missing @iarna/toml), so their
  # invocations are deliberately `|| true`-guarded with a loud warning,
  # trading "this one merge didn't apply" for "the rest of activation still
  # runs" rather than silently downgrading the script's own exit code.
  mkJsonManagedMerge =
    {
      targetFile,
      managedKey,
      declaredEntries,
      stateId,
    }:
    ''
      TARGET_FILE=${lib.escapeShellArg targetFile} \
      MANAGED_KEY=${lib.escapeShellArg managedKey} \
      DECLARED_ENTRIES=${lib.escapeShellArg (builtins.toJSON declaredEntries)} \
      STATE_FILE=${lib.escapeShellArg (mkStateFile stateId)} \
        ${nodeBin}/node ${scriptsDir}/apply-managed-json-keys.js \
        || echo "agents: WARNING: failed to apply managed '${managedKey}' entries to ${targetFile} — continuing activation" >&2
    '';

  mkTomlManagedMerge =
    {
      targetFile,
      managedKey,
      declaredEntries,
      stateId,
    }:
    ''
      # apply-managed-toml-keys.js needs @iarna/toml (parse + stringify); it's
      # declared in scripts/package.json and installed into scripts/node_modules
      # the first time, so Node's normal module resolution finds it with no
      # global install or NODE_PATH.
      if [ ! -d "${scriptsDir}/node_modules/@iarna/toml" ]; then
        ${nodeBin}/npm install --prefix ${scriptsDir} --no-audit --no-fund --silent
      fi

      TARGET_FILE=${lib.escapeShellArg targetFile} \
      MANAGED_KEY=${lib.escapeShellArg managedKey} \
      DECLARED_ENTRIES=${lib.escapeShellArg (builtins.toJSON declaredEntries)} \
      STATE_FILE=${lib.escapeShellArg (mkStateFile stateId)} \
        ${nodeBin}/node ${scriptsDir}/apply-managed-toml-keys.js \
        || echo "agents: WARNING: failed to apply managed '${managedKey}' entries to ${targetFile} — continuing activation" >&2
    '';

  # Same diff-and-prune shape, driving `claude plugin` CLI commands instead
  # of merging a config file. Uninstalls anything this mechanism previously
  # installed but is no longer declared; never touches plugins Claude itself
  # or the user installed outside of Nix (they never enter the tracked
  # managed-set, so they're never pruned). `marketplace` is a single value
  # (not a list) since no current caller ever needs more than one.
  #
  # Trusted-path-first PATH: Homebrew/system before $HOME/.local/bin, so a
  # file planted in the user-writable npm-global bin dir (where ~9 packages
  # get `npm install -g`'d) can't shadow the real `claude` binary for this
  # destructively-acting, unattended script.
  mkClaudePluginInstall =
    {
      marketplace ? null,
      declaredPlugins,
      stateId,
    }:
    ''
      export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
      if command -v claude >/dev/null 2>&1; then
        MARKETPLACE=${lib.escapeShellArg (if marketplace == null then "" else marketplace)} \
        DECLARED_PLUGINS=${lib.escapeShellArg (builtins.toJSON declaredPlugins)} \
        STATE_FILE=${lib.escapeShellArg (mkStateFile stateId)} \
          ${nodeBin}/node ${scriptsDir}/apply-claude-plugins.js
      else
        echo "agents: 'claude' CLI not found — skipping Claude plugin installs" >&2
      fi
    '';

  # Same diff-and-prune shape, driving `pi install`/`pi remove` instead of
  # merging a config file. Removes anything this mechanism previously
  # installed but is no longer declared; never touches packages Pi itself or
  # the user installed outside of Nix (they never enter the tracked
  # managed-set, so they're never pruned — confirmed via `pi list` showing
  # packages like npm:@ayulab/pi-rewind that aren't Nix-declared).
  #
  # `legacySeed` is an optional one-time bootstrap: package specs that used
  # to be actively removed by an older, differently-tracked mechanism (see
  # npmx.nix's now-deleted removedPiPackages). Seeding them into the state
  # file only when it doesn't exist yet ensures they're still pruned on the
  # very first run of this mechanism, instead of silently persisting forever
  # just because they predate this tracking.
  #
  # Same trusted-path-first PATH rationale as mkClaudePluginInstall above.
  mkPiPackageInstall =
    {
      declaredPackages,
      stateId,
      legacySeed ? [ ],
    }:
    ''
      export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
      if command -v pi >/dev/null 2>&1; then
        DECLARED_PACKAGES=${lib.escapeShellArg (builtins.toJSON declaredPackages)} \
        LEGACY_SEED=${lib.escapeShellArg (builtins.toJSON legacySeed)} \
        STATE_FILE=${lib.escapeShellArg (mkStateFile stateId)} \
          ${nodeBin}/node ${scriptsDir}/apply-pi-packages.js
      else
        echo "agents: 'pi' CLI not found — skipping Pi package installs" >&2
      fi
    '';
in
{
  inherit
    mkJsonManagedMerge
    mkTomlManagedMerge
    mkClaudePluginInstall
    mkPiPackageInstall
    ;
}
