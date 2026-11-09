# Portable mise runtime

`bootstrap.sh [MACHINE]` links the Claude/Pi package plugins and canonical configuration
sources. Official standalone mise >=2026.11.2 owns lifecycle tracking; there is
no Nix-generated fragment, immutable runtime wrapper or Home Manager activation.

`runtime:prepare` installs the locked uv environment for skill preparation.
`skills:prepare` validates available pinned sources offline and stages complete
views. Missing sources preserve the last-good view; dirty or malformed sources
fail. `apps:configure`, called after tools installation, prepares the Neovim
provider, reconciles managed fields and deploys the prepared skill group.
`skills:sync` fetches sources explicitly. RTK initialization is separate.

## Native plugins and writers

Claude/Pi plugins use mise's Lua command, JSON and filesystem APIs. Each handles
its own native CLI; shared helpers quote arguments and decode data without
selecting host policy. Inventory has a bounded timeout; package mutations retain
the native CLI's no-timeout behavior. Only explicitly requested packages change;
unknown/manual inventory is not proof of ownership.

Claude registers missing declared GitHub marketplaces before installation.
Pi finalizes its npm root after mutations so shared peers resolve. Native mise
owns package tracking and explicit pruning. Executables use built-in tool
backends; Python CLIs use isolated pipx environments.

Native merges handle additive settings and preserve app-written siblings.
`../configure_apps.py` handles whole-map revocation, managed hooks and
transitional skill-path retirement. Fragments live in `mise/apps/`; host policy
lives in `homes/<machine>/mise.toml`. Authentication stays in app state or literal
environment references. File history is disabled to avoid credential-bearing
preimages. Native merges write in place; remaining writers use atomic replacement.

`check-omniwm-handoff.sh` is only a preflight: it rejects a remaining legacy
plist/job or missing native app. Native mise writes and controls the replacement
LaunchAgent. The migration harness, not this guard, retires the reviewed old job.

See the [ownership contract](../../../../../docs/contracts/declarative-tooling.md)
and [cutover notes](../../../../../docs/contracts/mise-cutover.md).

## Tests

From `pub/dotfiles-nix`, with the declared runtimes active:

```sh
mise run test
mise run lint
mise run test:portable-runtime
mise run test:editor-lsp
```

`test` installs locked test dependencies, validates fleet locks, runs Python
and Node contracts, and exercises all four host overlays against native mise.
It covers privacy, idempotence, interrupted applies, source handoffs, shared
settings, revocation and shell ordering. RTK's real upstream initialization is
required in the isolated fixture. Package CLI and loopback registry fakes cannot
certify a live application deployment.

`test:portable-runtime` retains its disposable HOME and executes native provider
and DAP checks. `test:editor-lsp` uses locked plugins and real language servers;
its default scope reports the separately Nix-owned nil server as untested.
Use `tests/editor-lsp.py --nil /path/to/nil` to include it.

OmniWM tests exercise native mise's plist renderer and hook ordering with a fake
launchctl, while a macOS sandbox denies execution of the real launchctl. They do
not activate OmniWM or certify Accessibility permissions. Host activation and
application acceptance remain separate, explicitly authorized operations.
