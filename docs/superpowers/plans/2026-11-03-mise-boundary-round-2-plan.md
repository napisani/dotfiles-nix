# Mise boundary, round 2: implementation plan

**Audience:** the implementation agent continuing the uncommitted `mise` worktree.
**Status:** approved direction, 2026-11-03. Decisions below are settled; build on them.

Read first: `docs/code-style.md`, `pub/dotfiles-nix/AGENTS.md`,
[ADR 0004](../../adr/0004-global-mise-lifecycles.md), the
[tooling contract](../../contracts/declarative-tooling.md) and the repository
`monorepo-deps` skill (for every pin you add or move).

## Execution progress

- **W0 implemented.** Removed live OpenCode installs, assets, declarations,
  editor/shell integrations and project configuration. Scute's three plans and
  homelab's four skills moved unchanged (SHA-256 verified). Host cleanup remains
  manual; see [cutover notes](../../contracts/mise-cutover.md#retired-coding-agent-cleanup).
- **W0 verification:** 10 disposable configuration tests and 46 lifecycle/writer
  tests passed, plus isolated Neovim module checks, shell smoke, focused
  Statix/StyLua and diff checks. All-system `nix flake check --no-build` and all
  four host build `--dry-run` commands passed. No builds or host activation ran;
  foreign-platform execution remains unverified.
- **Scan qualification:** no references remain in live dotfiles, Nix modules,
  host declarations or checks. Remaining mentions are historical/product
  documentation, generic upstream skill reference material, news-source coverage,
  and the explicit cutover instructions. Those do not configure an installation
  and were retained rather than rewriting unrelated material to satisfy a grep.
- **W1 implemented.** Home Manager generates additive `conf.d/nix.toml` for
  built assets, RTK instructions, private inputs and the post-hook. The hook uses
  absolute Nix Node/Bash paths; runtime and node_modules HOME links are removed.
  Native INI merges own npmrc and preserve unmanaged keys. Missing package
  plugins warn and skip, so package declarations remain portable. All 14 config
  tests and all-system no-build evaluation passed; no fragment overrides core.
- **W2 complete.** proctmux and Scute use relative local `path:` inputs;
  procmux plumbing and Scute's npm installation are removed. Pi templates use
  `vars.monorepo_root`. The user explicitly approved package-only builds.
  Scute now uses hash-pinned dependency archives, offline extraction and
  `dontStrip`; its generator validates Bun's lock through Zod and checks manifest
  freshness. Standalone and actual dotfiles-selected ARM macOS packages build in
  the sandbox and report version 0.0.19 in disposable HOME directories.
- **W3 complete with recorded exceptions.** Eligible prebuilt CLIs moved to mise;
  Python `pipx:yq` preserves the old interface. TPM moved to a pinned native
  repository and the warning-only activation phase includes repos. btop,
  Atuin/delta, tmux and fff remain Nix-owned: missing platform artifacts, absent
  lock-resolved downloads, or an unverified fleet-wide binary route. In particular,
  tmux's successful native lock exit did not supply any platform artifacts; it
  was returned to Nix rather than treating that exit as sufficient evidence.
- **W4 complete with recorded exceptions.** Runtimes, eligible language tooling
  and host Homebrew CLIs moved atomically. NVM is no longer loaded. Nix's Neovim
  wrapper retains providers, drops `extraPackages` and adds mise shims. Its actual
  ARM macOS package passed GUI-style clean-environment and isolated-tmux PATH
  probes. Mason's registry covers removed servers, using basedpyright/vtsls/expert
  in place of pyright/typescript-language-server/elixir-ls. Erlang/Elixir,
  google-java-format, Mermaid CLI, gotools and gh-stack remain Nix-owned for the
  reasons in [ADR 0004](../../adr/0004-global-mise-lifecycles.md#nix-exceptions).
- **W5 complete.** Generic registry/aqua/GitHub, npm and pipx dependency families
  cover every tool declaration; all three `deps-check` runs succeeded without
  moving pins. Java numeric build revisions are compared without changing vendor.
  Native global and host lockfiles are checkout-owned through existing-file
  symlinks, verified to survive writes; sidecars resolve beside their physical
  targets. Dangling symlinks are not supported, so the fleet-lock task requires
  targets to exist. No sidecar-directory link or synchronization engine is used.
  The core has 51 tools and host overlays have eight declarations (helm appears
  on two hosts). Binary entries have all three platform URLs/checksums; pipx uses
  native uv sidecars. Native npm shell-out pins top-level versions only, not a
  transitive graph. Dependency updates regenerate locks before verification.
- **W6 complete.** ADR, contract, README, shell ownership, management/dependency
  skills and cutover notes describe the current owners. Legacy TPM links,
  Homebrew formulae, npm/NVM environments and lockfile collisions require reviewed
  host-side cleanup. No host has switched; all Next steps remain deferred.
- **Final verification:** 46 lifecycle/writer + 14 configuration + four activation
  + 27 root tests passed (91 total), as did Scute's project check, focused
  generator lint, shell smoke, all-system no-build evaluation, all four host
  build dry-runs, Nix formatting/Statix, Lua formatting and diff whitespace checks.
  Full `make lint` remains red: five existing errors in unchanged Scute files and
  missing `@oxlint/plugins` in vantage-nvim, mushy-lint and pi-surface. No new
  generator lint errors remain. The full build-producing dotfiles check gate
  was not run: package-only builds were approved, not system/check-closure builds.
  Foreign-platform compilation/runtime, full Neovim server startup and actual
  fleet cutover remain unverified. No commit, host activation or cleanup ran.

## Baseline

The worktree already contains the round-1 fixes. Confirm each still holds, then
build on it:

- mise pinned at `min_version = "2026.10.25"`, built from `mise-src` when
  nixpkgs lags (`mods/internal/mise-package.nix`).
- Native `merge` entries own scalar settings for Claude, Pi, the Pi relay and Codex.
- Activation: `miseDotfiles` is fatal and runs before `setupLaunchAgents`;
  `misePackages` (`tools,packages`) runs after it and warns on failure.
- The Claude plugin registers missing marketplaces before installing.
- macOS-only dotfiles carry `variants`; Pi themes/extensions use `symlink-each`.
- `read-aloud` and the `uv-editable` plugin are gone.

## Settled decisions

**D1. Boundary rule.** Each tool has exactly one owner across every host.
- **mise tools:** user CLIs and language runtimes with prebuilt macOS and Linux
  binaries from the mise registry, GitHub releases, npm or PyPI.
- **mise package plugins:** inventories owned by another application (Claude
  plugins, Pi packages).
- **Nix:** the OS and services, fonts, Nix tooling, the base userland, anything
  built or patched from source, and every tool built from this monorepo.
- **Homebrew (declared by nix-darwin):** GUI apps and native libraries.

**D2. Monorepo-built tools stay Nix-built from the local checkout** (`path:`
flake inputs). They never come from published artifacts: no GitHub releases, no
npm packages, no public mirrors.

**D3. Activation** stays as in the baseline.

**D4. Config writers.** Native `merge` for scalar settings. Custom writers remain
only for whole-map MCP ownership (removal must propagate) and Claude/Codex hooks.

**D5. Layering.** A portable core config that references nothing Nix-built, plus a
Nix-generated `~/.config/mise/conf.d/nix.toml` for everything that does.

**D6. Editor tooling.** Mason owns LSP servers. mise owns runtimes, formatters,
linters and CLIs. The Nix neovim wrapper keeps its providers and loses
`extraPackages`.

**D7. Out of scope this round:** Homebrew casks/brews moving to mise
`[bootstrap.packages]`, macOS defaults moving to `[bootstrap.macos.*]`, rtk and
the agent-skills pipeline, dotfile group restructuring, and everything under
[Next steps](#next-steps).

**D8. A move is atomic:** declare the tool in mise and delete it from Nix/Homebrew
in the same change, so no host ever has two owners or zero owners.

**D9. OpenCode is retired.** It is unused. Delete it from every live config, build
input and tool list rather than migrating it.

## Workstreams

Work in order. W0 shrinks the agent surface the later workstreams touch, and W1
changes where the W3/W4 declarations land.

### W0. Remove OpenCode

Delete, or edit the line, at every live reference. Find them with
`rg -il opencode --hidden -g '!.git'` and `git ls-files | grep -i opencode`:

- **Nix agent assets:** delete `mods/internal/agents/opencode.nix`. Remove its
  import in `assets.nix`, the `"opencode"` entry in the `perAgent` list in
  `options.nix`, the OpenCode warning in `default.nix` and the agent-id entry in
  `skill-files.nix`. Remove the `opencode/rtk.ts` cases from `checks/rtk-runtime.nix`,
  `checks/rtk-reproducibility.sh` and `checks/fixtures/config-writers.cjs`.
- **Installs:** `"opencode"` in the darwin-base and darwin-loancrate Homebrew
  brews, and `opencode` in supermicro's `mods/system-packages.nix`.
- **mise config:** every `~/.config/opencode/*` entry in `mods/dotfiles/mise/config.toml`.
  Delete `mise/apps/opencode-config.json.tera`, `mise/apps/{common,work}/opencode-mcp.json`
  and the old `mods/dotfiles/opencode-config.json` if it is still tracked.
- **Authored trees:** delete `mods/dotfiles/opencode/` and `mods/dotfiles/agents/opencode/`.
- **Shell and editor:**
  - the `opencode)` case in `shell/bash/rc.d/45-ai.sh`;
  - the OpenCode target in `nvim/lua/user/plugins/ai/wiremux.lua`;
  - the `opencode` entry in `nvim/lua/user/snacks/ai_skills.lua`;
  - the stale opencode.nvim comments in `nvim/lua/user/keymaps.lua`;
  - in `.tmux.conf`, the commented OpenCode popup binding and the `@opencode_state`
    `pane-exited` hook.
- **Project-level OpenCode config:**
  - Delete `pub/dotfiles-nix/.opencode/`; its skills are symlinks into `.agents/skills`.
  - Delete `pub/scute/opencode.json` and `pub/scute/.opencode/`. First move its three
    `plans/*.md` into `pub/scute/docs/superpowers/plans/`.
  - Delete `priv/kube-home-lab/opencode.json` and `priv/kube-home-lab/.opencode/`. First
    move its four skills (`add-helm-chart`, `add-home-app`, `deploy-and-debug`,
    `diagnose-homelab`) into `priv/kube-home-lab/.agents/skills/`. They exist nowhere else.
  - Remove the `.opencode` lockfile rows from
    `priv/skills/homelab/monorepo-dependency-updater/SKILL.md`.
- **Current-behaviour docs:** the tooling contract, `WORKAROUNDS.md` and the
  agent-management skill.

Leave historical records as written: ADRs 0001–0003, dated plans and specs,
audits and research reports. `pub/vantage-nvim` names opencode as one adjacent
agent it can read context from. That is product documentation, so leave it.

Host state stays untouched. Your report lists the manual per-host cleanup:
`brew uninstall opencode` on the Macs, and removing `~/.config/opencode` after a look.
Removing the nix-darwin entry does not uninstall the formula (`cleanup = "none"`),
and deleting a mise dotfile entry leaves its existing links in place.

Done when `rg -il opencode --hidden -g '!.git'` matches only the historical
records and vantage-nvim, and `nix flake check` passes.

### W1. Portable core and Nix fragment

Today `mods/dotfiles/mise/config.toml` references `~/.local/share/dotfiles-nix/`
for the agent-assets group, the four RTK files, gh-stack, tpm and the
`post-dotfiles` hook. On a host without Nix, `mise dot apply` fails at that hook.

1. Generate `~/.config/mise/conf.d/nix.toml` from Home Manager (`mods/mise.nix`) with
   every Nix-dependent entry, using direct store paths instead of
   `~/.local/share/dotfiles-nix/...` indirection where that removes a link:
   - the `agent-assets` dotfile group and the RTK files;
   - gh-stack (until W4e decides otherwise) and tpm (until W3 moves it);
   - the `configure-apps.sh` hook, invoking Nix's node by absolute store path
     rather than relying on `runtimePath`.
2. Move the configuration pipeline's private inputs out of the portable layer.
   Today core and host fragments declare `~/.config/dotfiles/apps/*` links that
   only `configure-apps.sh` reads. Let the Nix side own that selection; it knows the
   host and its profile. Authored data stays in `mods/dotfiles/mise/apps/`; Nix
   only chooses which file to use.
3. Put npm configuration in the core, because npm tools need it on every host.
   Prefer a native `merge` entry with `format = "ini"` on `~/.npmrc` if the pinned
   mise supports INI merge; otherwise use a `template` entry. Then delete the
   `apply-managed-file.js` call from `configure-apps.sh`.
4. Find out what the pinned mise does when `[bootstrap.packages]` names the
   `claude:`/`pi:` managers while their plugins are absent. If that fails the run
   rather than skipping, move those declarations into the Nix fragment as well.
5. Shrink `runtimePath` to what remains necessary, and justify each entry
   (`bun` currently has no visible consumer).

Done when:
- `rg -n 'dotfiles-nix' mods/dotfiles/mise homes/*/mise.toml` returns nothing.
- In a disposable `HOME` with only the core config and one host fragment linked,
  `mise -C "$HOME" bootstrap --only dotfiles` succeeds and runs no Nix hook.
- With the fragment present, `checks/config-writers.nix` passes for all four hosts.
- `conf.d` has lower precedence than `config.toml` (already verified), which is fine
  because fragment entries are additive. Report any fragment key that needs to
  override the core rather than adding a workaround.

### W2. Monorepo tools built locally (option 1)

1. Change the `proctmux` input to `path:../proctmux`.
2. Replace `"npm:@napisani/scute"` in the mise config with `pub/scute`'s flake as a
   `path:../scute` input installed through Home Manager. Remove its npm
   dependency rule from `deps.json`.
3. Delete the unused `procmux` input and its plumbing in `mods/base-packages.nix`
   and `lib/builders.nix`.
4. Add one `[vars]` entry for the monorepo root. Use it wherever templates
   hard-code `~/code/monorepo` (currently `pi-settings.json.tera`).

Done when `rg -n 'github:napisani' flake.nix` is empty, no mise config names a
monorepo package, and every monorepo tool resolves from a `path:` input.

### W3. Tier 1: prebuilt CLIs

Move these to the core `[tools]` and delete them from Nix or Homebrew:

| Tool | mise spec | Remove from |
|---|---|---|
| bat, btop, ripgrep, fd, k9s, lazydocker, tree-sitter, git-lfs, jq, yq, delta | registry short name | `base-packages.nix`, `languages/*.nix` |
| fzf, gh, starship | registry short name | `shell.nix` |
| atuin | `atuin` | `shell.nix`, including the whole `overrideAttrs` block |
| tmux | `aqua:tmux/tmux-builds` | `base-packages.nix` |
| doppler | `github:DopplerHQ/cli` | `base-packages.nix` |
| pet, lazysql | `github:knqyf263/pet`, `github:jorgerojas26/lazysql` | `base-packages.nix` |
| gogcli | `github:openclaw/gogcli` | `base-packages.nix`, maclab Homebrew |
| workmux | `github:raine/workmux` | darwin-base Homebrew and its tap |
| fff | find a release-backed source; if none exists, keep it in Nix and record it as an exception | |

tpm moves to the core as
`[bootstrap.repos] "~/.tmux/plugins/tpm" = { url = "https://github.com/tmux-plugins/tpm", ref = "<locked rev>" }`.
Take the rev from `flake.lock`, then drop the `tmux-tpm` input and its
`shell-assets` entry.

Done when every row resolves on all four platforms (see Verification) and no
row's tool remains in any Nix package list or Homebrew declaration.

### W4. Tier 2: runtimes, language tooling, Homebrew CLIs

**4a. Runtimes** into the core `[tools]`: node, python, go, deno, bun, zig, and
java as `temurin-11` (replacing `openjdk11`). Move elixir and erlang only if the
pinned mise installs erlang precompiled on macOS and Linux. Otherwise keep both
in Nix and record the exception. Delete `nodejs` from `mods/internal/npm.nix`;
delete the module if only `git` remains, since `git.nix` owns git.

**4b. Formatters, linters and CLIs.**
- Registry: ruff, uv, black, stylua, shellcheck, shfmt, gofumpt, prettier,
  oxlint, cspell, google-java-format, cmake, gradle.
- `npm:` mermaid-cli (`@mermaid-js/mermaid-cli`), eslint_d, fixjson, nodemon, typescript.
- `pipx:` mypy, isort, flake8, yapf.

**4c. Language servers (D6).** Remove `extraPackages` from `mods/neovim.nix`.
Account for every language server Nix supplied today: pyright,
typescript-language-server, vscode-langservers-extracted, the tailwind language
server, elixir-ls, zls and efm-langserver. Each must be in Mason's configured
set (`lua/user/lsp/registry.lua`) or explicitly listed as a Nix exception. `nil`
stays in Nix as Nix tooling. Confirm the formatters Neovim invokes resolve
through mise shims when nvim starts from tmux and from a GUI launcher.

**4d. Homebrew CLIs.** Move awscli, pulumi, actionlint, coder,
`github:buildkite/cli` and `github:conductorone/cone` to
`homes/nicks-loancrate-mbp/mise.toml`. Move helm to the nicks-mbp and maclab
fragments. Delete `nvm`. Remove each tap whose last formula moved. Native
libraries (ghostscript, graphicsmagick, pango, poppler, cocoapods) stay in
Homebrew. Confirm buildkite publishes darwin binaries before moving `bk`.

**4e. gh-stack.** `gh stack` needs the binary inside
`~/.local/share/gh/extensions/gh-stack/`. Use a mise-native install that
preserves that layout if one exists. Otherwise leave it in the Nix fragment and
record why.

Done when:
- `mods/languages/*.nix` holds only exceptions (statix, nixfmt, nil, gcc,
  luajit, luarocks, chromium on Linux, plus anything recorded above).
- `base-packages.nix` holds only the base userland, Nix tooling and monorepo
  builds.
- Every removed language server is in Mason's set or listed as an exception.

### W5. Pins and reproducibility

1. Track `[tools]` pins with one generic `deps.json` matcher per spec family
   (registry/aqua/github, npm, pipx). Do not add one regex per tool. Keep a
   single version-check group (deps domain) per family so `make deps-check`
   stays legible. Fold the existing per-tool Claude and Codex matchers into it.
2. Enable the global lockfile and lock all fleet platforms:
   `mise lock -g --platform macos-arm64,macos-x64,linux-x64`. mise writes it to
   `~/.config/mise/mise.lock`. Make it land in the checkout next to
   `config.toml`, for example with an out-of-store link. First confirm that mise
   writes *through* that link rather than replacing it. If mise replaces the
   link, stop and report rather than inventing a sync step.

Done when `make deps-check` lists every moved tool and native locks cover the
fleet: binary entries have URLs/checksums on all three platforms, pipx entries
have dependency sidecars, and native npm shell-out entries pin their top-level
version. The latter does not provide a transitive dependency lock.

### W6. Documentation

- **ADR 0004:** lead with the D1 boundary rule, followed by the exception list.
  One line points to [Next steps](#next-steps).
- **Contract, README, `shell/OWNERSHIP.md`, agent-management skill:** describe the
  new owners as current behaviour.
- **Cutover notes:** keep until every host has switched, then delete.

## Exceptions that stay in Nix

| What | Why |
|---|---|
| OS config, services, fonts, Touch ID for sudo, login shell, supermicro system packages | OS layer |
| `programs.nix-ld` on supermicro | Prebuilt dynamically linked binaries (node, Claude, Mason servers) need it |
| statix, nixfmt, nil, nix-search-cli, nix-direnv/direnv | Nix tooling |
| bash, coreutils, gnugrep, gnumake, gcc, git, wget, watch, tree, ncdu, gnupg, unzip, bash-completion, luajit, luarocks | Base userland with no prebuilt backends |
| neovim and its providers, omniwm, rtk, agent skills | Built, wrapped or patched artifacts |
| stackman, secret_inject, tmux-picker, mushy-lint, animalcontrol, proctmux, scute | Monorepo builds (D2) |
| mise itself | Bootstrap prerequisite |

## Verification

Never switch or activate a host. Run tests only in disposable profiles.

- `cd pub/dotfiles-nix && nix flake check`, plus the per-host `--dry-run` builds
  from `AGENTS.md`.
- The W1 core-only bootstrap in a disposable `HOME`.
- W5 native multi-platform locking plus the artifact-coverage assertions in
  `checks/native-installs.nix`. A successful `mise lock` exit alone is insufficient
  (the tmux backend supplied no platform downloads). Resolution does not prove
  runtime behavior on maclab (macos-x64) or supermicro (linux-x64).
- The existing focused suites: `checks/config-writers.nix`,
  `checks/native-installs.nix`, `mods/internal/mise/tests/`. Update their host
  package assertions for moved tools.
- `make check FILTER=dotfiles-nix` and `make lint` from the monorepo root.

Finish with a short report: what moved, what stayed as a recorded exception and
why, and anything you stopped on.

## Next steps

Not this round. These are recorded here so the direction survives.

**Option 2: mise builds monorepo tools from the checkout.** A small backend plugin
(e.g. `mono`) installs `"mono:<tool>" = "latest"`:
- It runs `make -C <root>/pub/<tool> install PREFIX=<install_path>`, so each
  subproject's Makefile owns its build.
- Its version list returns the committed subtree hash
  (`git rev-parse HEAD:pub/<tool>`), so a new commit means a rebuild and
  uncommitted edits never leak into installed tools.
- The root comes from where the plugin is linked
  (`mise plugins link mono <checkout>/...`).
- Toolchains come from mise (W4a).

Already verified: `path:` versions only work for tools in the registry, so the
plugin is required. Still unverified: whether backend hooks see global tools on
PATH, and whether the tool `depends` option orders installs. Prototype on
proctmux, then move all monorepo tools together and drop their `path:` inputs
from dotfiles-nix. The subprojects keep their own flakes.

**Package plugins delivered from the checkout.** Link `claude` and `pi` with
`mise plugins link` from the checkout instead of Home Manager's store link. With
that, a host without Nix can apply the core config's packages.

**Stow-style dotfile groups.** Restructure `mods/dotfiles` into home-shaped trees
per role (`base`, `macos`, `agents`, `work`), with hosts selecting groups through
`[bootstrap] dotfile_groups`. Already verified on 2026.10.3: relative group
roots under `dotfiles.root` and per-host group selection both work. This replaces
the explicit entry list, the OS variants and host dotfile overrides.

**Non-Nix proof.** Run a plain Linux container check: apply the core config with
`mise bootstrap --only dotfiles,tools`, and `apt:` entries supply the base userland.

**Test focus.** Drop the tests that exercise mise's own ownership, prune and
concurrency semantics (`package-lifecycle.test.cjs`), and the tests that assert
the retired design is absent. Add a real-CLI contract test for each plugin,
opt-in because it needs network access.

**Homebrew ownership: activated in review R7.** Formulae, casks and App Store
entries are declared in mise, with a [user-run maclab pilot](../../../mise-migration/README.md)
for data preservation, ownership transfer, cleanup and tool availability. No
live-host acceptance has been recorded. The [standalone follow-up](2026-11-03-mise-homebrew-follow-up.md)
tracks the remaining platform and installer constraints.

**Skills/RTK implemented in R8.** Offline `skills:prepare` plus native groups
replace Nix skill builds; explicit guarded `rtk:setup` uses the pinned upstream
CLI. Live-host handoff remains operator-run; see the cutover contract.

**Other deferred tier 3 work.** macOS defaults to `[bootstrap.macos.*]`.
