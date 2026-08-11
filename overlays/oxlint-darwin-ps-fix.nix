# @napi-rs/cli >= 3.8 (pulled in by oxlint's napi build step) reads the
# process start time via `/bin/ps` while acquiring its filesystem
# reconciliation lock. The Darwin build sandbox denies that exec; Node
# raises it as a synchronous `spawn EPERM` from execFile, which escapes
# napi's callback-based error handling and fails the whole oxlint build.
#
# Fixed upstream in nixpkgs master (oxlint 1.78.0) by pointing the lookup at
# a store `ps` instead of the bare path; our pinned nixpkgs-unstable rev
# still carries the broken 1.77.0 derivation, so re-apply the same patch
# here until the fix is channel-promoted. See:
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ox/oxlint/package.nix
final: prev: {
  oxlint = prev.oxlint.overrideAttrs (old: {
    preBuild =
      (old.preBuild or "")
      + prev.lib.optionalString prev.stdenv.hostPlatform.isDarwin ''
        for cli in node_modules/.pnpm/@napi-rs+cli@*/node_modules/@napi-rs/cli/dist/cli.js; do
          substituteInPlace "$cli" \
            --replace-fail '"/bin/ps"' '"${prev.darwin.adv_cmds}/bin/ps"'
        done
      '';
  });
}
