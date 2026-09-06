# Full ownership of a JSON key. These commands return real failures;
# activation's dispatcher reports them without aborting unrelated components.
{ lib, pkgs-unstable, ... }:
let
  nativeScripts = import ../native-scripts.nix { inherit lib; };
  scriptsDir = "${nativeScripts}/agents/scripts";
  node = "${pkgs-unstable.nodejs}/bin/node";
in
{
  mkJsonManagedMerge =
    {
      targetFile,
      managedKey,
      declaredEntries,
    }:
    ''
      TARGET_FILE=${lib.escapeShellArg targetFile} \
      MANAGED_KEY=${lib.escapeShellArg managedKey} \
      DECLARED_ENTRIES=${lib.escapeShellArg (builtins.toJSON declaredEntries)} \
        ${node} ${scriptsDir}/apply-managed-json-keys.js
    '';
}
