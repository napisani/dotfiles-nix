# Generic execution report. Keep the historical state path for existing
# consumers; the warning report grants no installation ownership.
{ config, lib, ... }:
let
  warnFile = "${config.home.homeDirectory}/.local/state/agents-nix/last-activation-warnings.txt";
in
{
  home.activation.globalToolsReportInit = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    export GLOBAL_TOOLS_WARN_FILE=${lib.escapeShellArg warnFile}
    mkdir -p "$(dirname "$GLOBAL_TOOLS_WARN_FILE")"
    : > "$GLOBAL_TOOLS_WARN_FILE"
  '';
  home.activation.globalToolsReportSummary =
    lib.hm.dag.entryAfter
      (
        [ "globalToolsReportInit" ]
        ++ map (name: "reconcileGlobalTools-${name}") (builtins.attrNames config.globalToolOperations)
      )
      ''
        _wf=${lib.escapeShellArg warnFile}
        if [ -s "$_wf" ]; then
          echo "global-tools: ⚠ $(wc -l < "$_wf" | tr -d ' ') warning(s) this activation (also saved to $_wf):" >&2
          sed 's/^/global-tools:   - /' "$_wf" >&2
        else
          echo "global-tools: all registered operations converged cleanly"
        fi
      '';
}
