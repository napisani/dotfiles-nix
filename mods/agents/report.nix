# agents/report.nix — end-of-activation convergence report.
#
# The soft-fail `|| warn` guards elsewhere keep one broken mechanism from
# aborting the whole activation (which runs under `set -eu`), but their
# warnings scroll past unseen in `darwin-rebuild switch` output. This module
# collects them into one file during activation and prints a summary at the
# very end, so "activation succeeded" and "everything actually converged" stop
# being conflatable. See docs/adr/0002-layered-asset-management.md.
#
# Warnings are emitted by shared.mkWarn (lib.nix), which appends to
# $AGENTS_WARN_FILE — exported by the init entry below — falling back to
# /dev/null if a warn fires before init runs, so nothing can abort.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  inputs ? { },
  homeManagerRelPath,
  ...
}:
let
  shared = import ./lib.nix {
    inherit config lib pkgs-unstable hostname machineRoles inputs homeManagerRelPath;
  };
  warnFile = "${shared.home}/.local/state/agents-nix/last-activation-warnings.txt";
in
{
  # Before linkGeneration so it clears the warn file ahead of every warning
  # site (all anchored entryAfter linkGeneration or on installNpmxTools, which
  # depends on this entry explicitly).
  home.activation.agentsWarnReportInit = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    export AGENTS_WARN_FILE=${lib.escapeShellArg warnFile}
    mkdir -p "$(dirname "$AGENTS_WARN_FILE")"
    : > "$AGENTS_WARN_FILE"
  '';

  # Runs after every agent's last step and installNpmxTools. Home-manager
  # ignores DAG references to entries that don't exist on a given machine, so
  # this list can safely name all of them.
  home.activation.agentsWarnReportSummary =
    lib.hm.dag.entryAfter [
      "writeClaudeInstructions"
      "configureClaudeMcpServers"
      "installClaudePlugins"
      "applyClaudeWorkmuxHooks"
      "applyLoancrateConfig"
      "writeCodexInstructions"
      "configureCodexMcpServers"
      "applyCodexWorkmuxHooks"
      "writeOpencodeInstructions"
      "writePiInstructions"
      "configurePiMcpServers"
      "installPiPackages"
      "installPiConfig"
      "installNpmxTools"
    ] ''
      _wf=${lib.escapeShellArg warnFile}
      if [ -s "$_wf" ]; then
        echo "" >&2
        echo "agents: ⚠ $(wc -l < "$_wf" | tr -d ' ') warning(s) this activation (also saved to $_wf):" >&2
        sed 's/^/agents:   - /' "$_wf" >&2
      else
        echo "agents: all managed agent assets converged cleanly"
      fi
    '';
}
