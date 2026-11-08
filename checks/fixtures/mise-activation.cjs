const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const phases = JSON.parse(process.env.MISE_ACTIVATION_FIXTURES);
for (const [index, phase] of phases.entries()) {
  test(`activation ${index}: configuration is fatal; installers warn after LaunchAgents`, (t) => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "mise-activation-"));
    t.after(() => fs.rmSync(root, { recursive: true, force: true }));
    const shell = process.env.TEST_SHELL || "/bin/bash";
    const cli = path.join(root, "mise");
    const log = path.join(root, "calls");
    fs.writeFileSync(cli, `#!${shell}
case "$*" in
  *"--only dotfiles") printf 'dotfiles\\n' >> "$CALL_LOG"; exit "$DOTFILES_EXIT" ;;
  *"run skills:sync") printf 'skills\\n' >> "$CALL_LOG"; exit "$PACKAGES_EXIT" ;;
  *"--only tools") printf 'tools\\n' >> "$CALL_LOG"; exit "$PACKAGES_EXIT" ;;
  *"packages apply --manager claude") printf 'claude\\n' >> "$CALL_LOG"; exit "$PACKAGES_EXIT" ;;
  *"packages apply --manager pi") printf 'pi\\n' >> "$CALL_LOG"; exit "$PACKAGES_EXIT" ;;
  *) exit 99 ;;
esac
`, { mode: 0o700 });
    assert.ok(phase.after.includes("miseDotfiles"));
    if (phase.darwin) {
      assert.ok(phase.before.includes("setupLaunchAgents"));
      assert.ok(phase.after.includes("setupLaunchAgents"));
    }
    const replace = (script) => script.replace(/\/nix\/store\/[^\s"]+\/bin\/mise/g, JSON.stringify(cli));
    const body = `set -e
run() { if [ "$DRY_RUN" != 1 ]; then "$@"; fi; }
warnEcho() { printf '%s\\n' "$*"; }
launchAgents() { printf 'launchAgents\\n' >> "$CALL_LOG"; }
${replace(phase.dotfiles)}
${phase.darwin ? "run launchAgents" : ""}
${replace(phase.packages)}
`;
    for (const [dotfiles, packages, dry] of [[0, 0, 0], [0, 1, 0], [1, 0, 0], [1, 1, 1]]) {
      fs.writeFileSync(log, "");
      const result = spawnSync(shell, ["-c", body], {
        encoding: "utf8",
        env: { HOME: root, PATH: process.env.PATH, CALL_LOG: log, DOTFILES_EXIT: String(dotfiles), PACKAGES_EXIT: String(packages), DRY_RUN: String(dry) },
      });
      assert.ifError(result.error);
      assert.equal(result.status, !dry && dotfiles ? 1 : 0, result.stderr);
      const calls = fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean);
      const expected = dry ? [] : dotfiles ? ["dotfiles"] : ["dotfiles", ...(phase.darwin ? ["launchAgents"] : []), "skills", "tools", "claude", "pi"];
      assert.deepEqual(calls, expected);
      if (!dry && !dotfiles && packages) assert.match(result.stdout, /rerun: mise -C "\$HOME" run skills:sync/);
      else assert.equal(result.stdout, "");
    }
  });
}
