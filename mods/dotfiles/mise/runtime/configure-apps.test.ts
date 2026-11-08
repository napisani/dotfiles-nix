import assert from "node:assert/strict";
import { join } from "node:path";
import { parse as parseToml, stringify as stringifyToml } from "@std/toml";
import {
  applyClaudeSettings,
  applyCodexConfig,
  applyCodexHooks,
  applyManagedKey,
  applyPiSkillPaths,
  ConfigWriter,
} from "./configure-apps.ts";

const SCRIPT = new URL("./configure-apps.ts", import.meta.url).pathname;
const DOTFILES = new URL("../..", import.meta.url).pathname;

const ROOT = Deno.realPathSync(
  Deno.makeTempDirSync({ prefix: "configure-apps-" }),
);
addEventListener("unload", () => Deno.removeSync(ROOT, { recursive: true }));
const temporary = () => Deno.makeTempDirSync({ dir: ROOT });
const readJson = (file: string) => JSON.parse(Deno.readTextFileSync(file));
const writeJson = (file: string, value: unknown) =>
  Deno.writeTextFileSync(file, JSON.stringify(value));
const apply = new ConfigWriter("apply");

Deno.test("managed keys are owned outright while sibling keys survive", () => {
  const target = join(temporary(), "target.json");
  writeJson(target, {
    mcpServers: { stale: {}, userAdded: { command: "manual" } },
    oauthAccount: { token: "secret" },
  });
  Deno.chmodSync(target, 0o640);
  applyManagedKey(apply, target, "mcpServers", {
    linear: { url: "https://mcp.linear.app/mcp" },
  });
  assert.deepEqual(readJson(target), {
    mcpServers: { linear: { url: "https://mcp.linear.app/mcp" } },
    oauthAccount: { token: "secret" },
  });
  assert.equal(Deno.statSync(target).mode! & 0o777, 0o640);
});

Deno.test("a missing target is created privately with just the managed key", () => {
  const target = join(temporary(), "nested/target.json");
  applyManagedKey(apply, target, "mcpServers", { linear: {} });
  assert.deepEqual(readJson(target), { mcpServers: { linear: {} } });
  assert.equal(Deno.statSync(target).mode! & 0o777, 0o600);
});

Deno.test("invalid targets and declarations fail without changing shared state", () => {
  const target = join(temporary(), "target.json");
  Deno.writeTextFileSync(target, "not json {{{");
  assert.throws(
    () => applyManagedKey(apply, target, "mcpServers", {}),
    /invalid JSON/,
  );
  assert.equal(Deno.readTextFileSync(target), "not json {{{");
  Deno.writeTextFileSync(target, "[]");
  assert.throws(
    () => applyManagedKey(apply, target, "mcpServers", {}),
    /not a JSON object/,
  );
  const original = '{"oauth":"private","mcpServers":{}}';
  Deno.writeTextFileSync(target, original);
  for (const declared of [null, [], "wrong-shape", 1]) {
    assert.throws(
      () => applyManagedKey(apply, target, "mcpServers", declared),
      /invalid declared/,
    );
    assert.equal(Deno.readTextFileSync(target), original);
  }
});

Deno.test("Claude workmux hooks replace and revoke without touching RTK or manual hooks", () => {
  const target = join(temporary(), "settings.json");
  const unmanaged = {
    matcher: "Bash",
    hooks: [{ type: "command", command: "my-personal-hook" }, {
      type: "command",
      command: "rtk hook claude",
    }],
  };
  writeJson(target, { hooks: { PreToolUse: [unmanaged] } });
  for (const status of ["waiting", "running"]) {
    const managed = {
      matcher: "Bash",
      hooks: [{
        type: "command",
        command: `workmux set-window-status ${status}`,
      }],
    };
    applyClaudeSettings(apply, target, { PreToolUse: [managed] }, {
      skill: "user-invocable-only",
    });
    assert.deepEqual(readJson(target).hooks.PreToolUse, [unmanaged, managed]);
    const before = Deno.statSync(target).mtime;
    applyClaudeSettings(apply, target, { PreToolUse: [managed] }, {
      skill: "user-invocable-only",
    });
    assert.deepEqual(Deno.statSync(target).mtime, before);
  }
  const status = new ConfigWriter("status");
  const before = Deno.readTextFileSync(target);
  applyClaudeSettings(status, target, {}, {});
  assert.equal(status.drift, true);
  assert.equal(Deno.readTextFileSync(target), before);
  applyClaudeSettings(apply, target, {}, {});
  assert.deepEqual(readJson(target).hooks.PreToolUse, [unmanaged]);
  assert.deepEqual(readJson(target).skillOverrides, {});
});

Deno.test("corrupt hook targets fail closed", () => {
  const dir = temporary();
  for (
    const [name, applyHooks] of [
      [
        "settings.json",
        (file: string) => applyClaudeSettings(apply, file, {}, {}),
      ],
      ["hooks.json", (file: string) => applyCodexHooks(apply, file, {})],
    ] as const
  ) {
    const target = join(dir, name);
    Deno.writeTextFileSync(target, "not-json");
    assert.throws(() => applyHooks(target), /invalid JSON/);
    assert.equal(Deno.readTextFileSync(target), "not-json");
  }
});

Deno.test("Codex config replaces MCP and re-enables only managed hook state", () => {
  const dir = temporary();
  const hooks = join(dir, "hooks.json"), config = join(dir, "config.toml");
  const managedKey = `${hooks}:stop:0:0`, manualKey = `${hooks}:stop:0:1`;
  writeJson(hooks, {
    hooks: {
      Stop: [{
        hooks: [{ command: "workmux set-window-status done" }, {
          command: "manual",
        }],
      }],
    },
  });
  const before = stringifyToml({
    model: "keep",
    features: { hooks: false, other: true },
    mcp_servers: { old: { command: "old" } },
    hooks: {
      state: {
        [managedKey]: { enabled: false },
        [manualKey]: { enabled: false },
      },
    },
  });
  Deno.writeTextFileSync(config, before);
  const status = new ConfigWriter("status");
  applyCodexConfig(status, config, { new: { command: "new" } }, hooks);
  assert.equal(status.drift, true);
  assert.equal(Deno.readTextFileSync(config), before);
  applyCodexConfig(apply, config, { new: { command: "new" } }, hooks);
  type CodexConfig = {
    model: string;
    features: Record<string, boolean>;
    mcp_servers: Record<string, unknown>;
    hooks: { state: Record<string, { enabled: boolean }> };
  };
  const result = parseToml(Deno.readTextFileSync(config)) as CodexConfig;
  assert.deepEqual(Object.keys(result.mcp_servers), ["new"]);
  assert.equal(result.model, "keep");
  assert.deepEqual(result.features, { hooks: false, other: true });
  assert.equal(result.hooks.state[managedKey].enabled, true);
  assert.equal(result.hooks.state[manualKey].enabled, false);
  const healthy = new ConfigWriter("status");
  applyCodexConfig(healthy, config, { new: { command: "new" } }, hooks);
  assert.equal(healthy.drift, false);
});

Deno.test("Pi skill paths add declarations, retire earlier ones and keep hand-added paths", () => {
  const dir = temporary();
  const settings = join(dir, "settings.json"),
    state = join(dir, "state/pi-skill-paths.json");
  writeJson(settings, {
    custom: true,
    packages: ["manual-package"],
    providers: { stale: {} },
    skills: ["~/manual-skills", "~/code/*/apps/*/.agents/skills"],
  });
  applyPiSkillPaths(apply, settings, ["~/old-skills", "~/kept-skills"], state);
  applyPiSkillPaths(apply, settings, ["~/kept-skills"], state);
  assert.deepEqual(readJson(settings), {
    custom: true,
    packages: ["manual-package"],
    skills: ["~/manual-skills", "~/kept-skills"],
  });
  assert.deepEqual(readJson(state), ["~/kept-skills"]);
  const before = Deno.readTextFileSync(settings);
  assert.throws(
    () => applyPiSkillPaths(apply, settings, "not-a-list", state),
    /invalid Pi skill paths/,
  );
  assert.equal(Deno.readTextFileSync(settings), before);
});

Deno.test("the command reports drift without writing, then converges", () => {
  const home = temporary();
  const overrides = join(home, "overrides.json");
  writeJson(overrides, { classify: "user-invocable-only" });
  const run = (mode: string) =>
    new Deno.Command(Deno.execPath(), {
      args: [
        "run",
        "--frozen",
        "--cached-only",
        "--allow-read",
        "--allow-write",
        "--allow-env",
        SCRIPT,
        DOTFILES,
        "work",
        overrides,
      ],
      env: { HOME: home, RECONCILE_MODE: mode, DENO_DIR: join(ROOT, "deno") },
    }).outputSync();
  const before = [...Deno.readDirSync(home)].map((entry) => entry.name);
  const status = run("status");
  assert.equal(status.code, 1);
  assert.match(new TextDecoder().decode(status.stdout), /config: drift/);
  assert.deepEqual(
    [...Deno.readDirSync(home)].map((entry) => entry.name),
    before,
  );
  assert.equal(run("apply").code, 0);
  assert.equal(Deno.statSync(join(home, ".claude.json")).mode! & 0o777, 0o600);
  const healthy = run("status");
  assert.equal(healthy.code, 0, new TextDecoder().decode(healthy.stdout));
});
