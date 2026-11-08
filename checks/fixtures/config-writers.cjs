const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const assert = require("node:assert/strict");
const { spawn, spawnSync } = require("node:child_process");
const { setTimeout: delay } = require("node:timers/promises");
const { test } = require("node:test");

const source = process.env.DOTFILES_SOURCE || path.resolve(__dirname, "../../mods/dotfiles");
const mise = process.env.MISE_TEST_BINARY || "mise";
const toml = require("./toml.cjs");
const denoDirectory = path.dirname(require("node:child_process").execFileSync("deno", ["eval", "console.log(Deno.execPath())"], { encoding: "utf8" }).trim());

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, { mode: 0o600 });
}
function json(file, value) {
  write(file, JSON.stringify(value, null, 2) + "\n");
}
function snapshot(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).sort().flatMap((name) => {
    const file = path.join(dir, name), stat = fs.lstatSync(file);
    if (stat.isDirectory()) return snapshot(file);
    return [[file, stat.isSymbolicLink() ? fs.readlinkSync(file) : fs.readFileSync(file, "utf8"), stat.mtimeMs, stat.mode]];
  });
}
function fixture(t, machine = "nicks-loancrate-mbp", withWriters = true) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "mise-config-writers-")));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const home = path.join(root, "home with 'quote"), checkout = path.join(root, "checkout");
  const dotfiles = path.join(checkout, "mods/dotfiles");
  fs.cpSync(source, dotfiles, {
    recursive: true,
    filter: (file) => !["node_modules", ".venv", "__pycache__"].includes(path.basename(file)),
  });
  const config = path.join(home, ".config/mise");
  fs.mkdirSync(config, { recursive: true });
  fs.symlinkSync(path.join(dotfiles, "mise/config.toml"), path.join(config, "config.toml"));
  fs.symlinkSync(dotfiles, path.join(config, "dotfiles"));
  const hostSource = process.env.CONFIG_WRITER_HOSTS || path.resolve(source, "../../homes");
  fs.symlinkSync(path.join(hostSource, machine, "mise.toml"), path.join(config, "config.local.toml"));
  const artifacts = path.join(home, ".local/share/dotfiles-nix");
  fs.mkdirSync(path.join(artifacts, "agent-assets/links/.agents/skills"), { recursive: true });
  const assetResources = path.join(artifacts, "agent-assets/resources");
  json(path.join(assetResources, "claude/skill-overrides.json"), { classify: "user-invocable-only" });
  const skill = path.join(root, "live-skill");
  write(path.join(skill, "SKILL.md"), "live skill\n");
  fs.symlinkSync(skill, path.join(artifacts, "agent-assets/links/.agents/skills/example"));
  const builtAssets = path.join(root, "build-1");
  fs.renameSync(path.join(artifacts, "agent-assets"), builtAssets);
  fs.symlinkSync(builtAssets, path.join(artifacts, "agent-assets"));
  const coreFile = path.join(dotfiles, "mise/config.toml");
  const core = toml.parse(fs.readFileSync(coreFile, "utf8"));
  // Dependency installation and preparation have separate cold-start and policy tests.
  core.tasks["runtime:prepare"].run = ":";
  core.tasks["nvim:prepare"].run = ":";
  core.tasks["skills:prepare"].run = ":";
  if (withWriters) core.dotfile_groups["agent-assets"].root = path.join(artifacts, "agent-assets/links");
  else fs.mkdirSync(path.join(home, ".local/share/dotfiles/skills/links"), { recursive: true });
  fs.writeFileSync(coreFile, toml.stringify(core));
  const policy = path.join(home, ".local/share/dotfiles/skills/claude-overrides.json");
  fs.mkdirSync(path.dirname(policy), { recursive: true });
  fs.symlinkSync(path.join(assetResources, "claude/skill-overrides.json"), policy);
  const env = {
    ...process.env,
    HOME: home,
    // Fixture mise runs enable no tools, so pass the test runtimes' own directories.
    PATH: `${path.dirname(process.execPath)}:${denoDirectory}:${process.env.PATH}`,
    XDG_CONFIG_HOME: path.join(home, ".config"),
    XDG_DATA_HOME: path.join(home, ".local/share"),
    XDG_STATE_HOME: path.join(home, ".local/state"),
    XDG_CACHE_HOME: path.join(home, ".cache"),
    MISE_CONFIG_DIR: config,
    MISE_DATA_DIR: path.join(root, "mise-data"),
    MISE_STATE_DIR: path.join(root, "mise-state"),
    MISE_CACHE_DIR: path.join(root, "mise-cache"),
    MISE_SYSTEM_CONFIG_DIR: path.join(root, "system"),
    MISE_YES: "1",
    MISE_ENABLE_TOOLS: "",
    // Deno's cache is not application state; keep it out of HOME snapshots.
    DENO_DIR: path.join(root, "deno"),
    // Native macOS package managers write fixed system paths, not the fixture HOME.
    MISE_SYSTEM_PACKAGES_MANAGERS: "claude,pi",
    NO_COLOR: "1",
    NODE_AUTH_TOKEN: "must-not-render-secret",
  };
  for (const key of ["MISE_GLOBAL_CONFIG_FILE", "MISE_CONFIG_FILE", "MISE_ENV", "MISE_TRUSTED_CONFIG_PATHS", "BASH_ENV", "ENV", "RECONCILE_MODE", "MISE_HISTORY_ENABLED"]) delete env[key];
  function run(args, extra = {}) {
    const result = spawnSync(mise, args, { cwd: home, env: { ...env, ...extra }, encoding: "utf8", timeout: 30000 });
    assert.ifError(result.error);
    return result;
  }
  function apply(extra = []) {
    return run(["bootstrap", "--only", withWriters ? "dotfiles,tools" : "dotfiles", ...extra]);
  }
  function writers(status = false) {
    const profile = toml.parse(fs.readFileSync(path.join(config, "config.local.toml"), "utf8")).vars?.agent_profile || "common";
    return spawnSync("deno", ["run", "--frozen", "--cached-only", "--config", path.join(dotfiles, "mise/runtime/deno.json"), "--allow-read", "--allow-write", "--allow-env", path.join(dotfiles, "mise/runtime/configure-apps.ts"), dotfiles, profile, path.join(assetResources, "claude/skill-overrides.json")], {
      cwd: home, env: { ...env, RECONCILE_MODE: status ? "status" : "apply" }, encoding: "utf8",
    });
  }
  return { root, home, env, dotfiles, artifacts, skill, apply, run, writers };
}
function success(result) {
  assert.equal(result.status, 0, result.stdout + result.stderr);
}

for (const machine of ["nicks-loancrate-mbp", "nicks-mbp", "maclab", "supermicro"]) {
  test(`portable core applies ${machine} without Nix artifacts or hooks`, (t) => {
    const h = fixture(t, machine, false);
    fs.rmSync(h.artifacts, { recursive: true, force: true });
    success(h.apply());
    assert.ok(fs.existsSync(path.join(h.home, ".npmrc")));
    assert.equal(fs.existsSync(path.join(h.home, ".claude.json")), false);
    assert.equal(fs.existsSync(path.join(h.home, ".config/dotfiles/apps")), false);
    success(h.run(["bootstrap", "--only", "packages"]));
  });
  test(`mise deploys ${machine} declarations and preserves shared app state`, (t) => {
    const h = fixture(t, machine);
    const app = (file) => path.join(h.home, file);
    const token = "fake-private-token-must-not-enter-mise-history";
    const omniwm = ["nicks-loancrate-mbp", "nicks-mbp"].includes(machine);
    if (omniwm) write(app(".config/omniwm/settings.toml"), "# GUI settings\n");
    json(app(".claude.json"), { oauthState: token, mcpServers: { retired: {} } });
    json(app(".claude/settings.json"), { manual: true, hooks: { Stop: [{ hooks: [{ type: "command", command: "manual-hook" }] }], PreToolUse: [{ matcher: "Bash", hooks: [{ type: "command", command: "rtk hook claude" }] }] } });
    write(app(".pi/agent/extensions/rtk.ts"), "// native RTK extension\n");
    json(app(".codex/hooks.json"), { hooks: { Stop: [{ hooks: [{ type: "command", command: "manual-codex-hook" }] }] } });
    write(app(".codex/config.toml"), 'model = "manual-model"\n[features]\nhooks = false\n[mcp_servers.retired]\nurl = "https://retired.invalid"\n');
    json(app(".pi/agent/settings.json"), { packages: ["npm:manually-installed@1.0.0"], manual: true, openaiReasoningMode: { manual: true } });
    json(app(".pi/agent/mcp.json"), { oauthState: token });
    json(app(".pi/remote/config.json"), { auth: token });
    json(app(".pi/agent/npm/package.json"), { dependencies: { manual: "1.0.0" } });
    json(app(".claude/loancrate.json"), { team_repos: { manual: "keep" }, cached: true });
    write(app(".agents/skills/manual/SKILL.md"), "manual skill\n");
    write(app(".npmrc"), "save-exact=true\n//private.invalid/:_authToken=synthetic-private-token\n");
    const before = snapshot(h.home);
    const status = h.run(["bootstrap", "dotfiles", "status"]);
    assert.ok([0, 1].includes(status.status), status.stderr);
    assert.deepEqual(snapshot(h.home), before, "dotfile status mutated application files");
    success(h.apply(["--dry-run"]));
    // mise may register the trusted global config, but must not run writers.
    assert.deepEqual(snapshot(h.home).filter(([p]) => !p.includes("/.cache/")), before);
    success(h.apply());
    assert.match(fs.readFileSync(app(".local/share/bash-completion/completions/mise"), "utf8"), /^# @generated by usage/);
    const read = (file) => JSON.parse(fs.readFileSync(app(file), "utf8"));
    assert.equal(read(".claude.json").oauthState, token);
    assert.equal(read(".claude/settings.json").manual, true);
    assert.match(JSON.stringify(read(".claude/settings.json").hooks), /manual-hook/);
    assert.match(JSON.stringify(read(".claude/settings.json").hooks), /rtk hook claude/);
    assert.equal(read(".claude/settings.json").skillOverrides.classify, "user-invocable-only");
    assert.match(JSON.stringify(read(".codex/hooks.json")), /manual-codex-hook/);
    assert.match(fs.readFileSync(app(".codex/config.toml"), "utf8"), /manual-model/);
    assert.doesNotMatch(fs.readFileSync(app(".codex/config.toml"), "utf8"), /retired/);
    assert.equal(toml.parse(fs.readFileSync(app(".codex/config.toml"), "utf8")).features.hooks, true);
    assert.deepEqual(read(".pi/agent/settings.json").packages, ["npm:manually-installed@1.0.0"]);
    assert.equal(read(".pi/agent/settings.json").openaiReasoningMode.manual, true);
    assert.equal(read(".pi/agent/settings.json").transport, "sse");
    assert.equal(read(".pi/agent/mcp.json").oauthState, token);
    assert.equal(read(".pi/remote/config.json").auth, token);
    assert.equal(read(".pi/remote/config.json").relay, "https://remote-pi.napisani.xyz");
    assert.deepEqual(read(".pi/agent/npm/package.json").dependencies, { manual: "1.0.0" });
    assert.equal(read(".pi/agent/npm/package.json").allowScripts.sharp, true);
    assert.equal(read(".claude/loancrate.json").team_repos.manual, "keep");
    const work = machine === "nicks-loancrate-mbp";
    if (omniwm) {
      assert.equal(fs.lstatSync(app(".config/omniwm/settings.toml")).isSymbolicLink(), false);
      assert.equal(fs.readFileSync(app(".config/omniwm/settings.toml"), "utf8"), fs.readFileSync(path.join(h.dotfiles, "omniwm-settings.toml"), "utf8"));
    } else assert.equal(fs.existsSync(app(".config/omniwm/settings.toml")), false);
    const servers = JSON.parse(fs.readFileSync(path.join(h.dotfiles, `mise/apps/${work ? "work" : "common"}/pi-mcp.json`), "utf8"));
    assert.deepEqual(read(".pi/agent/mcp.json").mcpServers, servers);
    assert.equal(Boolean(read(".claude/settings.json").extraKnownMarketplaces.lc), work);
    const npmrc = fs.readFileSync(app(".npmrc"), "utf8");
    assert.equal(npmrc.includes("${NODE_AUTH_TOKEN}"), work);
    assert.ok(!npmrc.includes("must-not-render-secret"));
    assert.ok(npmrc.includes("save-exact=true"));
    assert.ok(npmrc.includes("//private.invalid/:_authToken=synthetic-private-token"));
    assert.equal(fs.readFileSync(app(".agents/skills/manual/SKILL.md"), "utf8"), "manual skill\n");
    assert.ok(fs.lstatSync(app(".agents/skills/example")).isSymbolicLink());
    write(path.join(h.skill, "new.md"), "new live helper\n");
    assert.equal(fs.readFileSync(app(".agents/skills/example/new.md"), "utf8"), "new live helper\n");
    assert.ok(fs.lstatSync(app(".bashrc")).isSymbolicLink());
    assert.equal(fs.realpathSync(app(".config/scute/config.yaml")), fs.realpathSync(path.join(h.dotfiles, "scute.yml")));
    const secretInject = read(".config/.secret_inject.json").sources.doppler;
    const doppler = work ? "loancrate" : "personal";
    assert.deepEqual([secretInject.env, secretInject.credential.name], [doppler, `${doppler}-doppler`]);
    assert.equal(fs.statSync(app(".config/.secret_inject.json")).mode & 0o777, 0o600);
    assert.ok(fs.lstatSync(app(".config/nvim/init.vim")).isSymbolicLink());
    assert.equal(fs.existsSync(app(".config/nvim/init.lua")), false, "Neovim must load authored init.vim; the Nix wrapper sideloads providers");
    assert.match(fs.readFileSync(app(".claude/CLAUDE.md"), "utf8"), /@RTK\.md/);
    assert.ok(fs.readFileSync(app(".codex/AGENTS.md"), "utf8").includes(`@${h.home}/.codex/RTK.md`));
    for (const file of fs.readdirSync(path.join(h.dotfiles, "agents/pi/extensions"))) {
      assert.equal(fs.existsSync(app(`.pi/agent/extensions/${file}`)), !/\.(?:test|spec)\./.test(file), file);
    }
    assert.equal(fs.readFileSync(app(".pi/agent/extensions/rtk.ts"), "utf8"), "// native RTK extension\n");
    assert.equal(fs.lstatSync(app(".pi/agent/extensions/rtk.ts")).isSymbolicLink(), false);
    for (const file of [".aerospace.toml", ".yabairc", ".look/config", ".config/karabiner/karabiner.json", "Library/Application Support/com.mitchellh.ghostty/config", "Library/Application Support/discordo/config.toml"]) {
      assert.equal(fs.existsSync(app(file)), process.platform === "darwin", file);
    }
    const healthy = snapshot(h.home);
    success(h.writers(true));
    assert.deepEqual(snapshot(h.home), healthy, "configuration status mutated files");
    success(h.apply());
    assert.deepEqual(snapshot(h.home), healthy, "repeat changed configuration");
    const privateFiles = [".claude.json", ".claude/settings.json", ".codex/config.toml", ".pi/agent/settings.json"];
    for (const file of privateFiles) assert.equal(fs.statSync(app(file)).mode & 0o777, 0o600, file);
    const miseRecords = snapshot(path.join(h.root, "mise-data")).concat(snapshot(path.join(h.root, "mise-state")));
    assert.ok(!miseRecords.some(([, contents]) => contents.includes(token)), "mise history captured application secrets");
  });
}

test("mise hands off skill source roots and revokes managed keys without pruning manual state", (t) => {
  const h = fixture(t);
  write(path.join(h.home, ".pi/agent/extensions/rtk.ts"), "// native RTK extension\n");
  fs.symlinkSync(h.skill, path.join(h.artifacts, "agent-assets/links/.agents/skills/survivor"));
  const manual = path.join(h.home, ".agents/skills/manual/SKILL.md");
  write(manual, "manual skill\n");
  json(path.join(h.home, ".pi/agent/mcp.json"), { oauthState: "keep-private" });
  success(h.apply());
  success(h.run(["dot", "unapply", "--group", "agent-assets", "--yes"]));
  assert.equal(fs.readFileSync(manual, "utf8"), "manual skill\n");
  const bridge = path.join(h.artifacts, "agent-assets");
  const next = path.join(h.root, "build-2");
  fs.cpSync(fs.realpathSync(bridge), next, { recursive: true });
  fs.unlinkSync(path.join(next, "links/.agents/skills/example"));
  const nextSkill = path.join(h.root, "next-skill");
  write(path.join(nextSkill, "SKILL.md"), "prepared replacement\n");
  fs.unlinkSync(path.join(next, "links/.agents/skills/survivor"));
  fs.symlinkSync(nextSkill, path.join(next, "links/.agents/skills/survivor"));
  const fragmentFile = path.join(h.dotfiles, "mise/config.toml");
  const fragment = toml.parse(fs.readFileSync(fragmentFile, "utf8"));
  fragment.dotfile_groups["agent-assets"].root = path.join(next, "links");
  fs.writeFileSync(fragmentFile, toml.stringify(fragment));
  const overrides = path.join(next, "resources/claude/skill-overrides.json");
  fs.unlinkSync(overrides);
  json(overrides, {});
  fs.unlinkSync(bridge);
  fs.symlinkSync(next, bridge);
  const declarations = path.join(h.dotfiles, "mise/apps/work/pi-mcp.json");
  const servers = JSON.parse(fs.readFileSync(declarations, "utf8"));
  delete servers.figma;
  json(declarations, servers);
  const approvals = path.join(h.dotfiles, "mise/apps/pi-allow-scripts.json");
  const allowed = JSON.parse(fs.readFileSync(approvals, "utf8"));
  delete allowed.sharp;
  json(approvals, allowed);
  const extension = "inline-slash-enter-accept.js";
  fs.unlinkSync(path.join(h.dotfiles, "agents/pi/extensions", extension));
  write(path.join(h.home, ".pi/agent/extensions/manual.js"), "export {};\n");
  write(path.join(h.dotfiles, "agents/pi/extensions/hidden.spec.ts"), "throw new Error();\n");
  const global = path.join(h.dotfiles, "mise/config.toml");
  const updated = toml.parse(fs.readFileSync(global, "utf8"));
  updated.dotfiles["~/.inputrc"] = { mode: "absent" };
  fs.writeFileSync(global, toml.stringify(updated));
  success(h.apply());
  assert.throws(() => fs.lstatSync(path.join(h.home, ".agents/skills/example")), { code: "ENOENT" });
  assert.equal(fs.realpathSync(path.join(h.home, ".agents/skills/survivor")), fs.realpathSync(nextSkill));
  assert.throws(() => fs.lstatSync(path.join(h.home, ".inputrc")), { code: "ENOENT" });
  assert.equal(fs.readFileSync(manual, "utf8"), "manual skill\n");
  const mcp = JSON.parse(fs.readFileSync(path.join(h.home, ".pi/agent/mcp.json"), "utf8"));
  assert.equal(mcp.oauthState, "keep-private");
  assert.deepEqual(mcp.mcpServers, servers);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(h.home, ".pi/agent/npm/package.json"), "utf8")).allowScripts, allowed);
  assert.equal(fs.existsSync(path.join(h.home, ".pi/agent/extensions", extension)), false);
  assert.equal(fs.existsSync(path.join(h.home, ".pi/agent/extensions/hidden.spec.ts")), false);
  assert.ok(fs.existsSync(path.join(h.home, ".pi/agent/extensions/manual.js")));
  assert.ok(fs.existsSync(path.join(h.home, ".pi/agent/extensions/rtk.ts")));
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(h.home, ".claude/settings.json"), "utf8")).skillOverrides, {});
});

test("mise rejects malformed shared files without replacing their contents", (t) => {
  const h = fixture(t);
  success(h.apply());
  for (const [file, invalid] of [[".claude.json", "not-json"], [".claude/settings.json", "broken-json"], [".codex/config.toml", "not = = toml"], [".pi/agent/settings.json", "invalid-json"]]) {
    const target = path.join(h.home, file), original = fs.readFileSync(target, "utf8");
    fs.writeFileSync(target, invalid);
    assert.notEqual(h.apply().status, 0, file);
    assert.equal(fs.readFileSync(target, "utf8"), invalid);
    fs.writeFileSync(target, original);
  }
  for (const [source, destination] of [
    ["work/pi-mcp.json", ".pi/agent/mcp.json"],
    ["claude-settings.json.tera", ".claude/settings.json"],
    ["work/loancrate.json.tera", ".claude/loancrate.json"],
  ]) {
    const declaration = path.join(h.dotfiles, "mise/apps", source);
    const target = path.join(h.home, destination);
    const before = fs.readFileSync(target, "utf8"), original = fs.readFileSync(declaration, "utf8");
    fs.writeFileSync(declaration, "[]");
    assert.notEqual(h.apply().status, 0, source);
    assert.equal(fs.readFileSync(target, "utf8"), before, "invalid desired data overwrote shared state");
    fs.writeFileSync(declaration, original);
  }
});

test("mise leaves conflicting user dotfiles and external directory targets intact", (t) => {
  const h = fixture(t);
  const external = path.join(h.root, "external"), sentinel = path.join(external, "sentinel");
  write(sentinel, "keep external state\n");
  fs.symlinkSync(external, path.join(h.home, ".agents"));
  write(path.join(h.home, ".bashrc"), "manual bashrc\n");
  assert.notEqual(h.apply().status, 0);
  assert.equal(fs.readFileSync(path.join(h.home, ".bashrc"), "utf8"), "manual bashrc\n");
  assert.equal(fs.readFileSync(sentinel, "utf8"), "keep external state\n");
});

test("native merges create private regular files and disable credential-bearing history", (t) => {
  const h = fixture(t);
  success(h.apply());
  const targets = [".npmrc", ".claude/settings.json", ".claude/loancrate.json", ".codex/config.toml", ".pi/agent/settings.json", ".pi/remote/config.json"];
  assert.equal(fs.existsSync(path.join(h.home, ".config/dotfiles/apps")), false);
  for (const file of targets) {
    const target = path.join(h.home, file);
    assert.equal(fs.lstatSync(target).isSymbolicLink(), false, file);
    assert.equal(fs.statSync(target).mode & 0o777, 0o600, file);
  }
  const token = "synthetic-native-merge-private-state";
  json(path.join(h.home, ".pi/remote/config.json"), { relay: "https://old.invalid", auth: token });
  write(path.join(h.home, ".claude.json"), "invalid-json");
  assert.notEqual(h.apply().status, 0);
  assert.equal(JSON.parse(fs.readFileSync(path.join(h.home, ".pi/remote/config.json"))).auth, token);
  assert.equal(fs.existsSync(path.join(h.env.MISE_STATE_DIR, "history")), false);
});

test("dotfile entry points defer app writers until the post-tools hook", (t) => {
  const h = fixture(t);
  const target = path.join(h.home, ".claude.json");
  for (const args of [["bootstrap", "--only", "dotfiles"], ["bootstrap", "dotfiles", "apply"], ["dot", "apply"]]) {
    json(target, { auth: "keep", mcpServers: { retired: {} } });
    success(h.run(args));
    assert.deepEqual(JSON.parse(fs.readFileSync(target)).mcpServers, { retired: {} });
    success(h.run(["bootstrap", "--only", "tools"]));
    const current = JSON.parse(fs.readFileSync(target));
    assert.equal(current.auth, "keep");
    assert.deepEqual(current.mcpServers, JSON.parse(fs.readFileSync(path.join(h.dotfiles, "mise/apps/work/claude-mcp.json"))));
  }
});

test("interrupted native configuration does not leave credential recovery preimages", async (t) => {
  const h = fixture(t);
  const token = "synthetic-interrupted-merge-private-state";
  json(path.join(h.home, ".pi/remote/config.json"), { relay: "https://old.invalid", auth: token });
  const file = path.join(h.dotfiles, "mise/config.toml");
  const fragment = toml.parse(fs.readFileSync(file, "utf8"));
  fragment.bootstrap.hooks["post-tools"].run = ': > "$HOME/native-ready"; while :; do sleep 1; done';
  fs.writeFileSync(file, toml.stringify(fragment));
  const child = spawn(mise, ["bootstrap", "--only", "dotfiles,tools"], { cwd: h.home, env: h.env, detached: true, stdio: "ignore" });
  const closed = new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("close", resolve);
  });
  try {
    const deadline = Date.now() + 10000;
    while (!fs.existsSync(path.join(h.home, "native-ready")) && Date.now() < deadline) await delay(20);
    assert.ok(fs.existsSync(path.join(h.home, "native-ready")), "post-hook never started");
    assert.equal(fs.existsSync(path.join(h.env.MISE_STATE_DIR, "history")), false);
  } finally {
    try { process.kill(-child.pid, "SIGKILL"); } catch (error) { if (error.code !== "ESRCH") throw error; }
    await closed;
  }
  assert.equal(JSON.parse(fs.readFileSync(path.join(h.home, ".pi/remote/config.json"))).auth, token);
  assert.equal(fs.existsSync(path.join(h.env.MISE_STATE_DIR, "history")), false);
});
