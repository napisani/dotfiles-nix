# Sort agent assets into three layers by who writes the target path

**Status:** accepted

**Partially superseded by:** [ADR 0003](0003-declarative-agent-configuration-interface.md), which retains the ownership layers as adapter internals but reverses this ADR's decision against typed `agents.*` options.

ADR 0001 gave each agent its own module. This ADR settles *how* each asset is
installed, once per asset class, by a single question: **who else writes to
this path?** It supersedes the earlier assumption (see the original
`CONTEXT.md` "Revocable install" note) that every mechanism should reach
revocability the same way `skills.nix` did.

## Context

The post-0001 module was well-organized but leaned on imperative activation
scripts for work Nix could own outright, and traded away Nix's guarantees
invisibly:

- Community skills — immutable fetched content, the asset class Nix handles
  best — were installed by the *most* imperative mechanism: wipe the skill
  dir, then run `skills add` for ~17 repos × 4 agents (~70 network fetches)
  on every rebuild, unpinned (whatever upstream HEAD happened to be), with a
  destructive window where a failed fetch left skill dirs empty.
- Local skills, Pi extensions/themes, and Claude commands were symlink-managed
  by hand-rolled bash that re-implemented what home-manager's link generation
  does natively, including the "refuse to replace a non-symlink" guards.
- The JSON/TOML config merges carried per-key tracked-state files whose only
  purpose was preserving hand-added entries — itself a concession against the
  "everything declarative" goal.
- Soft-fail `|| echo WARNING` guards (needed so one broken step doesn't abort a
  `set -eu` activation) scrolled past unseen, so "switch succeeded" and
  "everything converged" were conflatable.
- Machine gating compared the flake hostname string, which fails silently if a
  machine is renamed.

## Decision

Sort every asset by who writes its path, and give each layer one mechanism:

- **Layer 0 — only Nix writes it** → `home.file`. Community skills become
  pinned flake inputs (`flake = false`, updated deliberately via `nix flake
  update`) linked as store symlinks; repo-local content (shared/local skills,
  commands, Pi extensions/themes, the `~/.agents/skills` store) is linked via
  `mkOutOfStoreSymlink` so edits stay live. Revocation and rollback come from
  home-manager's own bookkeeping; activation needs no network.
  - **Variant: patched store content.** Some agent-specific behavior (Pi's
    `disable-model-invocation` frontmatter key, Codex's sibling
    `agents/openai.yaml`) has to live inside a vendored skill's own files, but
    those files are read-only pinned store paths. `skills.nix`'s
    `mkPatchedSkillSource` copies the store path into a new derivation and
    applies the patch there, and that derivation is what gets `home.file`-
    linked instead of the raw input path. Still Layer 0: revocation is still
    home-manager's own link bookkeeping (drop the flag, the unpatched symlink
    comes back), it's just a derivation instead of a bare store path as the
    `home.file` source.
- **Layer 1 — Nix and the tool both write the file** → activation-time **full
  key ownership**. The declared set replaces the managed key (`mcpServers` /
  `mcp_servers`) each run; sibling keys the tool writes are preserved; the
  per-key state files are deleted. Hand-added entries under the managed key no
  longer survive — the deliberate trade for removing the state machinery.
- **Layer 2 — the tool's installer owns opaque state** → CLI driver +
  tracked-state diff (unchanged from before). Claude plugins, Pi packages, RTK
  hooks keep `~/.local/state/agents-nix/<stateId>.json`.

Supporting changes: a `nix flake check` that forces every merged activation
value (catches the option-merge collisions a real switch would hit); machine
gating via a flake-declared `roles` list (`machineRoles` specialArg) instead
of hostname strings; `mods/opencode.nix` merged into `mods/agents/opencode.nix`
so OpenCode stops spanning two files; and `report.nix`, which aggregates
soft-fail warnings into one end-of-activation summary.

## Considered options

- **Keep wipe-and-rebuild, just harden it** (install to a temp dir, swap on
  success). Rejected: it keeps the network dependency, the lack of pinning,
  and the re-implemented symlink logic. Moving skills to `home.file` deletes
  the mechanism instead of patching it.
- **Keep the `skills` CLI but point it at pinned store paths** (a permanent
  bridge, not just a migration step). Rejected: still an activation script
  doing what `home.file` does natively, with no rollback.
- **Typed home-manager module options** (`options.agents.*`) for MCP servers
  etc. Rejected for now: real boilerplate and an indirection layer, with
  little payoff in a single-contributor repo — the flake check already covers
  the collision risk that typing would catch.
- **Nixify npm globals** (`buildNpmPackage`/node2nix). Rejected: per-package
  hash maintenance for fast-moving CLIs is toil without payoff; ADR 0001 goal 4
  already accepted brew/npm as fine for package installs.

## Consequences

- Skills stop auto-updating on every rebuild; pulling upstream is now a
  deliberate `nix flake update <input>`. Reproducible and auditable; the cost
  is remembering to update.
- Hand-added MCP entries under a managed key are wiped on rebuild — experiments
  must be promoted to Nix to persist.
- `darwin-rebuild --rollback` now restores skills too (they're `home.file`),
  which it never did under the activation-script mechanism.
- ~200 lines of wipe/refetch/symlink bash and the config-merge state machinery
  are gone; what remains is smaller and layer-typed.
- The three-layer model is the decision procedure for any new asset: ask who
  writes the path, and the mechanism follows. It is documented for day-to-day
  use in the `agent-management` skill.
