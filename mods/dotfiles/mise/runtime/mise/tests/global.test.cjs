const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync, fork } = require("node:child_process");
const test = require("node:test");
const { environment, mise } = require("./test-fixtures/environment.cjs");

function fixture(t) {
  const root = fs.realpathSync(
    fs.mkdtempSync(path.join(os.tmpdir(), "mise-global-")),
  );
  const env = environment(root);
  const configFile = env.MISE_GLOBAL_CONFIG_FILE;
  delete env.MISE_GLOBAL_CONFIG_FILE;
  delete env.MISE_TRUSTED_CONFIG_PATHS;
  const bin = path.join(root, "bin");
  fs.mkdirSync(bin);
  fs.mkdirSync(env.HOME);
  fs.mkdirSync(path.dirname(configFile), { recursive: true });
  env.PATH = bin + ":" + env.PATH;
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  function plugin(name) {
    const dir = path.join(env.MISE_DATA_DIR, "plugins", name);
    fs.mkdirSync(path.dirname(dir), { recursive: true });
    fs.symlinkSync(path.join(__dirname, "../plugins", name), dir);
  }
  return {
    root,
    env,
    bin,
    plugin,
    configFile,
    configure(text) {
      fs.writeFileSync(configFile, text);
    },
    command(name, source) {
      fs.symlinkSync(source, path.join(bin, name));
    },
    run(args, extra = {}, cwd = root) {
      return spawnSync(mise, args, {
        cwd,
        env: { ...env, ...extra },
        encoding: "utf8",
        timeout: 30_000,
      });
    },
  };
}
function succeeded(result) {
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
}

test("agent executables use built-in aqua backends beside application package plugins", (t) => {
  const h = fixture(t);
  h.plugin("claude");
  h.plugin("pi");
  h.configure(
    '[tools]\n"aqua:anthropics/claude-code" = "1.0.0"\n"aqua:openai/codex" = "1.0.0"\n',
  );
  const result = h.run(["ls", "--current", "--json"], { MISE_OFFLINE: "1" });
  succeeded(result);
  const rows = JSON.parse(result.stdout);
  assert.deepEqual(Object.keys(rows).sort(), [
    "aqua:anthropics/claude-code",
    "aqua:openai/codex",
  ]);
  assert.ok(Object.values(rows).flat().every((row) => !row.installed));
});

test("manually linked Claude package hooks do not launch a Node adapter", (t) => {
  const h = fixture(t);
  succeeded(h.run(["plugins", "link", "-f", "claude", path.join(__dirname, "../plugins/claude")]));
  const node = path.join(h.root, "unexpected-node");
  const shell = process.env.TEST_SHELL || "/bin/sh";
  fs.writeFileSync(node, `#!${shell}\nexit 97\n`, { mode: 0o700 });
  h.command("node", node);
  const cli = path.join(h.root, "native-claude");
  fs.writeFileSync(
    cli,
    `#!${shell}
case "$1 $2" in
  "plugin list")
    if [ -f "$CLAUDE_INSTALL_STATE" ]; then
      printf '[{"id":"plugin@m","scope":"user","version":"1"}]'
    else
      printf '[]'
    fi ;;
  "plugin marketplace") printf '[{"name":"m"}]' ;;
  "plugin install") printf installed > "$CLAUDE_INSTALL_STATE" ;;
  "plugin uninstall") rm -f "$CLAUDE_INSTALL_STATE" ;;
  *) exit 2 ;;
esac
`,
    { mode: 0o700 },
  );
  h.command("claude", cli);
  const native = { CLAUDE_INSTALL_STATE: path.join(h.root, "installed") };
  h.configure('[bootstrap.packages]\n"claude:plugin@m" = "latest"\n');
  succeeded(
    h.run(["bootstrap", "packages", "apply", "--manager", "claude"], native),
  );
  succeeded(h.run(["bootstrap", "packages", "status", "--missing"], native));
  h.configure("[bootstrap.packages]\n");
  succeeded(
    h.run(
      ["bootstrap", "packages", "prune", "--manager", "claude", "--yes"],
      native,
    ),
  );
  assert.equal(fs.existsSync(native.CLAUDE_INSTALL_STATE), false);
});


function marketplaceFixture(t) {
  const h = fixture(t);
  h.plugin("claude");
  h.command("claude", path.join(__dirname, "test-fixtures/fake-claude/claude"));
  const settings = path.join(h.env.HOME, ".claude/settings.json");
  fs.mkdirSync(path.dirname(settings), { recursive: true });
  fs.writeFileSync(settings, JSON.stringify({
    extraKnownMarketplaces: { fresh: { source: { source: "github", repo: "owner/fresh" } } },
  }));
  const native = {
    CLAUDE_INSTALL_STATE: path.join(h.root, "installed.json"),
    CLAUDE_MARKETPLACE_STATE: path.join(h.root, "marketplaces.json"),
    CALL_LOG: path.join(h.root, "calls"),
  };
  fs.writeFileSync(native.CLAUDE_MARKETPLACE_STATE, '[{"name":"manual"}]');
  h.configure('[bootstrap.packages]\n"claude:plugin@fresh" = "latest"\n');
  return { ...h, native, settings, calls: () => fs.readFileSync(native.CALL_LOG, "utf8") };
}

test("Claude registers only missing requested marketplaces before install and upgrade", (t) => {
  const h = marketplaceFixture(t);
  const apply = ["bootstrap", "packages", "apply", "--manager", "claude"];
  succeeded(h.run([...apply, "--dry-run"], h.native));
  assert.doesNotMatch(h.calls(), /marketplace add|plugin install/);
  succeeded(h.run(apply, h.native));
  assert.match(h.calls(), /marketplace add owner\/fresh --scope user\nplugin install plugin@fresh --scope user/);
  succeeded(h.run(apply, h.native));
  assert.equal(h.calls().split("marketplace add").length - 1, 1);
  fs.writeFileSync(h.native.CLAUDE_MARKETPLACE_STATE, '[{"name":"manual"}]');
  succeeded(h.run(["bootstrap", "packages", "upgrade", "--manager", "claude"], h.native));
  assert.match(h.calls(), /marketplace add owner\/fresh --scope user\nplugin marketplace update fresh\nplugin update plugin@fresh/);
  assert.deepEqual(JSON.parse(fs.readFileSync(h.native.CLAUDE_MARKETPLACE_STATE)), [{ name: "manual" }, { name: "fresh" }]);
  assert.doesNotMatch(h.calls(), /marketplace (?:remove|update) manual/);
});

for (const failure of ["inventory-json", "inventory-shape", "declaration", "source-ref", "registration"]) {
  test(`Claude blocks installation on invalid marketplace ${failure}`, (t) => {
    const h = marketplaceFixture(t);
    const extra = failure === "inventory-json" ? { CLAUDE_MARKETPLACE_LIST_INVALID: "not-json" }
      : failure === "inventory-shape" ? { CLAUDE_MARKETPLACE_LIST_INVALID: "[{}]" }
      : failure === "registration" ? { CLAUDE_FAIL_MARKETPLACE_ADD: "1" } : {};
    if (failure === "declaration") fs.writeFileSync(h.settings, "{}");
    if (failure === "source-ref") {
      const settings = JSON.parse(fs.readFileSync(h.settings));
      settings.extraKnownMarketplaces.fresh.source.ref = "unhandled-pin";
      fs.writeFileSync(h.settings, JSON.stringify(settings));
    }
    const result = h.run(["bootstrap", "packages", "apply", "--manager", "claude"], { ...h.native, ...extra });
    assert.notEqual(result.status, 0);
    assert.doesNotMatch(h.calls(), /plugin install/);
    assert.equal(fs.existsSync(h.native.CLAUDE_INSTALL_STATE), false);
  });
}

for (const manager of ["claude", "pi"]) {
test(`${manager} command options bound inventories but leave mutations unbounded`, (t) => {
  const h = manager === "claude" ? marketplaceFixture(t) : fixture(t);
  if (manager === "pi") {
    h.plugin("pi");
    const fixtures = path.join(__dirname, "test-fixtures/fake-pi");
    h.command("pi", path.join(fixtures, "pi"));
    h.command("npm", path.join(fixtures, "npm"));
    h.native = { PI_INSTALL_STATE: path.join(h.root, "installed"), CALL_LOG: path.join(h.root, "calls"), NPM_CALL_LOG: path.join(h.root, "npm-calls") };
    h.configure('[bootstrap.packages]\n"pi:npm:fixture" = "1.0.0"\n');
  }
  const linked = path.join(h.env.MISE_DATA_DIR, "plugins", manager);
  const copied = path.join(h.root, "instrumented", manager);
  fs.cpSync(fs.realpathSync(linked), copied, { recursive: true, dereference: true });
  fs.unlinkSync(linked);
  fs.symlinkSync(copied, linked);
  for (const name of fs.readdirSync(path.join(copied, "hooks"))) {
    const file = path.join(copied, "hooks", name);
    fs.writeFileSync(file, `local cmd = require("cmd")
local exec = cmd.exec
cmd.exec = function(command, options)
  if command:find("'list'", 1, true) then
    assert(options.timeout == 120, "inventory must be bounded")
  else
    assert(options.timeout == nil, "mutation must have no timeout")
  end
  return exec(command, options)
end
` + fs.readFileSync(file, "utf8"));
  }
  succeeded(h.run(["bootstrap", "packages", "apply", "--manager", manager], h.native));
  succeeded(h.run(["bootstrap", "packages", "upgrade", "--manager", manager], h.native));
  h.configure("[bootstrap.packages]\n");
  succeeded(h.run(["bootstrap", "packages", "prune", "--manager", manager, "--yes"], h.native));
});
}

test("global npm tools use stock shims, project overrides, tracked configs, and symlinked declarations", async (t) => {
  const h = fixture(t);
  assert.ok(
    process.env.NPM_COMMAND,
    "set NPM_COMMAND to native npm, not a mise shim",
  );
  // Mise's npm wrapper resolves node relative to its own filename.
  h.env.FIXTURE_NPM = fs.realpathSync(process.env.NPM_COMMAND);
  const npmLauncher = path.join(h.root, "npm-launcher");
  fs.writeFileSync(npmLauncher, '#!/bin/sh\nexec "$FIXTURE_NPM" "$@"\n', { mode: 0o755 });
  h.command("npm", npmLauncher);
  const server = fork(path.join(__dirname, "test-fixtures/npm-registry.cjs"), [
    h.root,
  ], {
    env: h.env,
    stdio: ["ignore", "pipe", "pipe", "ipc"],
  });
  t.after(() => server.kill());
  const { port } = await new Promise((resolve, reject) => {
    server.once("message", resolve);
    server.once("error", reject);
    server.once("exit", (code) => reject(new Error("registry exited " + code)));
  });
  const native = {
    NPM_CONFIG_REGISTRY: "http://127.0.0.1:" + port,
    NPM_CONFIG_AUDIT: "false",
    NPM_CONFIG_PREFIX: path.join(h.env.HOME, ".local"),
  };
  const config = (version) =>
    '[settings.npm]\npackage_manager = "npm"\nshell_out = true\n[tools]\n"npm:fixture-tool" = {version="' +
    version + '", allow_builds=true, npm_args="--ignore-scripts=false"}\n';
  h.configure(config("1.0.0"));
  const authored = path.join(h.root, "declarations.toml");
  fs.renameSync(h.configFile, authored);
  const storeLink = path.join(h.root, "home-manager-link");
  fs.symlinkSync(authored, storeLink);
  fs.symlinkSync(storeLink, h.configFile);
  succeeded(h.run(["install"], native));
  const project = path.join(h.root, "project with spaces");
  fs.mkdirSync(project);
  fs.writeFileSync(path.join(project, "mise.toml"), config("2.0.0"));
  succeeded(h.run(["trust", path.join(project, "mise.toml")], native));
  succeeded(h.run(["install"], native, project));
  for (const [cwd, version] of [[h.root, "1.0.0"], [project, "2.0.0"]]) {
    const result = h.run(
      ["exec", "--", "fixture-tool", "two words", "--example"],
      native,
      cwd,
    );
    succeeded(result);
    assert.deepEqual(JSON.parse(result.stdout), {
      version,
      cwd,
      args: ["two words", "--example"],
      postinstall: true,
    });
  }
  const shim = path.join(h.env.MISE_DATA_DIR, "shims/fixture-tool");
  const launched = spawnSync(shim, ["argument"], {
    cwd: project,
    env: { ...h.env, ...native },
    encoding: "utf8",
  });
  succeeded(launched);
  assert.equal(JSON.parse(launched.stdout).version, "2.0.0");
  succeeded(
    h.run(["use", "--global", "--pin", "npm:fixture-tool@2.0.0"], native),
  );
  assert.ok(fs.lstatSync(h.configFile).isSymbolicLink());
  assert.match(fs.readFileSync(authored, "utf8"), /2\.0\.0/);
  h.configure("[tools]\n");
  succeeded(h.run(["prune", "--tools", "--yes"], native));
  const installed = JSON.parse(
    h.run(["ls", "--installed", "--json"], native).stdout,
  );
  assert.deepEqual(Object.values(installed).flat().map((row) => row.version), [
    "2.0.0",
  ]);
  fs.unlinkSync(path.join(project, "mise.toml"));
  succeeded(h.run(["prune", "--tools", "--yes"], native));
  assert.deepEqual(
    JSON.parse(h.run(["ls", "--installed", "--json"], native).stdout),
    {},
  );
});

test("native inventory failures block pruning instead of treating state as empty", (t) => {
  const h = fixture(t);
  h.plugin("claude");
  h.command(
    "claude",
    path.join(
      __dirname,
      "test-fixtures/fake-claude/claude",
    ),
  );
  const native = {
    CLAUDE_INSTALL_STATE: path.join(h.root, "installed.json"),
    CALL_LOG: path.join(h.root, "calls"),
  };
  h.configure('[bootstrap.packages]\n"claude:plugin@m" = "latest"\n');
  assert.notEqual(
    h.run(["bootstrap", "packages", "status", "--missing"], native).status,
    0,
  );
  assert.equal(fs.existsSync(native.CLAUDE_INSTALL_STATE), false);
  succeeded(
    h.run(["bootstrap", "packages", "apply", "--manager", "claude"], native),
  );
  const before = fs.readFileSync(native.CLAUDE_INSTALL_STATE, "utf8");
  const time = fs.statSync(native.CLAUDE_INSTALL_STATE).mtimeMs;
  succeeded(h.run(["bootstrap", "packages", "status", "--missing"], native));
  assert.equal(fs.statSync(native.CLAUDE_INSTALL_STATE).mtimeMs, time);
  h.configure("[bootstrap.packages]\n");
  const failed = h.run([
    "bootstrap",
    "packages",
    "prune",
    "--manager",
    "claude",
    "--yes",
  ], { ...native, CLAUDE_LIST_INVALID: "1" });
  assert.notEqual(failed.status, 0);
  assert.equal(fs.readFileSync(native.CLAUDE_INSTALL_STATE, "utf8"), before);
  succeeded(
    h.run(
      ["bootstrap", "packages", "prune", "--manager", "claude", "--yes"],
      native,
    ),
  );
});

test("Pi rejects npm ranges before invoking installers", (t) => {
  const h = fixture(t);
  h.plugin("pi");
  const fixtures = path.join(
    __dirname,
    "test-fixtures/fake-pi",
  );
  h.command("pi", path.join(fixtures, "pi"));
  h.command("npm", path.join(fixtures, "npm"));
  const log = path.join(h.root, "calls");
  h.configure('[bootstrap.packages]\n"pi:npm:fixture" = "^1.0.0"\n');
  assert.notEqual(
    h.run(["bootstrap", "packages", "apply", "--manager", "pi"], {
      PI_INSTALL_STATE: path.join(h.root, "pi-installed"),
      CALL_LOG: log,
    }).status,
    0,
  );
  assert.doesNotMatch(
    fs.readFileSync(log, "utf8"),
    /(?:install|update|remove) npm:/,
  );
});

test("Pi pins are native mise declarations and preserve unowned packages", (t) => {
  const h = fixture(t);
  h.plugin("pi");
  const fixtures = path.join(
    __dirname,
    "test-fixtures/fake-pi",
  );
  h.command("pi", path.join(fixtures, "pi"));
  h.command("npm", path.join(fixtures, "npm"));
  const native = {
    PI_INSTALL_STATE: path.join(h.root, "pi-installed"),
    CALL_LOG: path.join(h.root, "calls"),
    NPM_CALL_LOG: path.join(h.root, "npm-calls"),
  };
  fs.writeFileSync(native.PI_INSTALL_STATE, "npm:manual\n");
  const npmDir = path.join(h.env.HOME, ".pi/agent/npm");
  fs.mkdirSync(npmDir, { recursive: true });
  fs.writeFileSync(
    path.join(npmDir, "package.json"),
    JSON.stringify({ private: true, allowScripts: { approved: true } }),
  );
  const npmCalls = () =>
    fs.readFileSync(native.NPM_CALL_LOG, "utf8").trim().split("\n");
  h.configure('[bootstrap.packages]\n"pi:npm:fixture" = "1.0.0"\n');
  succeeded(
    h.run(["bootstrap", "packages", "apply", "--manager", "pi"], native),
  );
  assert.equal(npmCalls().length, 1);
  succeeded(
    h.run(["bootstrap", "packages", "apply", "--manager", "pi"], native),
  );
  assert.equal(npmCalls().length, 1, "healthy apply reran npm finalization");
  h.configure('[bootstrap.packages]\n"pi:npm:fixture" = "2.0.0"\n');
  succeeded(
    h.run(["bootstrap", "packages", "apply", "--manager", "pi"], native),
  );
  succeeded(h.run(["bootstrap", "packages", "status", "--missing"], native));
  assert.notEqual(
    h.run(["bootstrap", "packages", "upgrade", "--manager", "pi"], {
      ...native,
      NPM_FAIL_INSTALL: "1",
    }).status,
    0,
  );
  succeeded(
    h.run(["bootstrap", "packages", "upgrade", "--manager", "pi"], native),
  );
  h.configure("[bootstrap.packages]\n");
  succeeded(
    h.run(
      ["bootstrap", "packages", "prune", "--manager", "pi", "--yes"],
      native,
    ),
  );
  assert.equal(
    fs.readFileSync(native.PI_INSTALL_STATE, "utf8"),
    "npm:manual\n",
  );
  assert.equal(npmCalls().length, 5);
  assert.deepEqual(
    JSON.parse(fs.readFileSync(path.join(npmDir, "package.json"))).allowScripts,
    { approved: true },
  );
});

test("named Claude plugin works through ordinary global mise commands", (t) => {
  const h = fixture(t);
  h.plugin("claude");
  h.command(
    "claude",
    path.join(
      __dirname,
      "test-fixtures/fake-claude/claude",
    ),
  );
  const native = {
    CLAUDE_INSTALL_STATE: path.join(h.root, "installed.json"),
    CALL_LOG: path.join(h.root, "calls"),
  };
  const fragments = path.join(h.env.MISE_CONFIG_DIR, "conf.d");
  fs.mkdirSync(fragments);
  const hostConfig = path.join(fragments, "work.toml");
  fs.writeFileSync(
    hostConfig,
    '[bootstrap.packages]\n"claude:host@m" = "latest"\n',
  );
  h.configure('[bootstrap.packages]\n"claude:plugin@m" = "latest"\n');
  succeeded(
    h.run(["bootstrap", "packages", "apply", "--manager", "claude"], native),
  );
  assert.deepEqual(
    JSON.parse(fs.readFileSync(native.CLAUDE_INSTALL_STATE)).sort(),
    ["host@m", "plugin@m"],
  );
  succeeded(h.run(["bootstrap", "packages", "status", "--missing"], native));
  succeeded(
    h.run(["bootstrap", "packages", "upgrade", "--manager", "claude"], native),
  );
  h.configure("[bootstrap.packages]\n");
  succeeded(
    h.run(
      ["bootstrap", "packages", "prune", "--manager", "claude", "--yes"],
      native,
    ),
  );
  assert.deepEqual(JSON.parse(fs.readFileSync(native.CLAUDE_INSTALL_STATE)), [
    "host@m",
  ]);
  fs.unlinkSync(hostConfig);
  succeeded(
    h.run(
      ["bootstrap", "packages", "prune", "--manager", "claude", "--yes"],
      native,
    ),
  );
  assert.deepEqual(
    JSON.parse(fs.readFileSync(native.CLAUDE_INSTALL_STATE)),
    [],
  );
  assert.doesNotMatch(
    fs.readFileSync(native.CALL_LOG, "utf8"),
    /marketplace (add|remove)/,
  );
});
