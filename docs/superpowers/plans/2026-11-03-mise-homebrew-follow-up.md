# Move remaining Homebrew ownership to mise

**Status:** declarations and operator workflow implemented; live maclab acceptance
pending. The user activated this follow-up in review R7, then replaced the
four-host reconstructed test loop with a user-run maclab pilot. See the
[runbook](../../../mise-migration/README.md).
**Intent:** Homebrew declarations are not a permanent exception to the long-term
mise direction. Move the remaining formulae, casks and necessary tap configuration
out of nix-darwin when supported, including installation and upgrade ownership.
The operator, not the agent, performs real switches and package transfers.

## Scope

- Inventory `homebrew.brews`, `homebrew.casks` and `homebrew.taps` across the
  shared and host-specific Darwin profiles. Audit unused taps rather than copying
  them blindly.
- Use mise `[tools]` for eligible versioned CLIs/runtimes; use native
  `[bootstrap.packages]` `brew:` and `brew-cask:` entries for retained Homebrew
  distributions. Keep host/platform selection explicit.
- Include GUI apps, rendering libraries and development dependencies, not only
  CLIs. Revisit retained ngrok, Session Manager, CocoaPods and Zulu 17 individually.
- Update native upgrade commands, ownership documentation and cutover guidance
  together. Do not leave both nix-darwin and mise declaring the same installation.
- Prefer native mise managers; do not implement a parallel Homebrew installer,
  ownership ledger or recovery engine.

## Constraints to resolve before implementation

The inspected mise 2026.10.25 documentation has these limitations. Recheck them
against the version chosen for this follow-up; they are not permanent assumptions:

- `brew:` formula installation is unsupported on Intel macOS. maclab needs
  verified upstream support or an explicitly approved temporary exception.
- `brew-cask:` supports Intel, but uses `/opt/homebrew/Caskroom`, not Intel
  Homebrew's `/usr/local/Caskroom`; formula-dependent casks have further limits.
- Detected Homebrew-owned casks remain Homebrew-owned for upgrades. Adding TOML
  entries alone does not complete the ownership transfer.
- Unsupported cask artifacts, tap features and installer steps can fail. Some
  operations need sudo; decide how provisioning fits activation and interactive
  setup rather than assuming unattended installation succeeds.
- Native Homebrew managers generally track current releases/versioned formula
  names, not arbitrary historical pins. Do not promise `[tools]`-style locking.

## Verification and cutover

Build a per-host compatibility inventory, then exercise representative formulae,
app bundles and installer-package casks in disposable environments where possible.
Verify install/status/upgrade behavior, existing-app handling and tap resolution
before removing their current declarations. Document unresolved entries explicitly.

Actual host migration requires separate approval. Preserve app data, credentials,
manual installations and rollback evidence; review adoption/replacement and macOS
privacy-permission effects. Never use blanket uninstall or prune as a migration.
Success means the intended entries are both declared and lifecycle-managed by
mise on their target hosts, with any temporary exceptions recorded—not merely
that the TOML parses.

References: [mise formula manager](https://mise.jdx.dev/bootstrap/packages/brew.html),
[mise cask manager](https://mise.jdx.dev/bootstrap/packages/brew-cask.html),
[current cutover notes](../../contracts/mise-cutover.md).
