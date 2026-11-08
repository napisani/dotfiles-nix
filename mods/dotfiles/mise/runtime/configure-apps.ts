/**
 * Reconciles the agent configuration fields native mise merges cannot own:
 * whole-map MCP declarations, managed hooks and transitional Pi skill paths.
 * Every target is shared with its application, so sibling keys, manual hooks
 * and credentials are preserved.
 *
 * Usage: configure-apps.ts DOTFILES PROFILE SKILL_OVERRIDES_FILE
 * With RECONCILE_MODE=status it reports drift and exits 1 without writing.
 *
 * @module
 */
import { parse as parseToml, stringify as stringifyToml } from "@std/toml";
import { dirname, join } from "node:path";

/** A parsed JSON object. */
export type JsonObject = Record<string, unknown>;

/** Whether a hook group or handler belongs to the declared workmux hooks. */
export type ManagedPredicate = (value: unknown) => boolean;

/** Compares projected bytes, then writes atomically or records drift. */
export class ConfigWriter {
  /** Whether a status run found a file that would change. */
  drift = false;

  /** @param mode `apply` writes; `status` only reports drift. */
  constructor(readonly mode: "apply" | "status" = "apply") {}

  /** Writes `content` unless the regular file already holds it. Returns whether it changed. */
  write(file: string, content: string): boolean {
    const stat = lstatOrNull(file);
    if (stat?.isFile && Deno.readTextFileSync(file) === content) return false;
    if (this.mode === "status") {
      console.log(`config: drift at ${file}`);
      this.drift = true;
      return false;
    }
    Deno.mkdirSync(dirname(file), { recursive: true });
    const temporary = `${file}.tmp.${Deno.pid}.${Date.now()}`;
    // A replaced symlink's permissions must not carry into writable config.
    const mode = stat?.isFile ? stat.mode! & 0o777 : 0o600;
    try {
      Deno.writeTextFileSync(temporary, content, { createNew: true, mode });
      Deno.renameSync(temporary, file);
    } finally {
      if (lstatOrNull(temporary)) Deno.removeSync(temporary);
    }
    return true;
  }

  /** Writes `value` as two-space JSON. */
  writeJson(file: string, value: unknown): boolean {
    return this.write(file, JSON.stringify(value, null, 2) + "\n");
  }
}

function lstatOrNull(file: string): Deno.FileInfo | null {
  try {
    return Deno.lstatSync(file);
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return null;
    throw error;
  }
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Reads a JSON object, or `fallback` when the file is missing. Throws on any other shape. */
export function readJsonObject(
  file: string,
  fallback?: JsonObject,
): JsonObject {
  if (!lstatOrNull(file) && fallback) return fallback;
  let value: unknown;
  try {
    value = JSON.parse(Deno.readTextFileSync(file));
  } catch (error) {
    throw new Error(
      `refusing to update invalid JSON at ${file}: ${(error as Error).message}`,
    );
  }
  if (!isObject(value)) {
    throw new Error(
      `refusing to update ${file}: top-level value is not a JSON object`,
    );
  }
  return value;
}

/** Replaces the managed hooks in each event, keeping every other group and handler. */
export function replaceManagedHooks(
  current: JsonObject,
  desired: JsonObject,
  isManaged: ManagedPredicate,
): JsonObject {
  const result: JsonObject = {};
  for (
    const event of new Set([...Object.keys(current), ...Object.keys(desired)])
  ) {
    const groups = (current[event] ?? []) as JsonObject[];
    const retained = groups.flatMap((group) => {
      if (!Array.isArray(group?.hooks)) return isManaged(group) ? [] : [group];
      const hooks = group.hooks.filter((handler) => !isManaged(handler));
      return hooks.length || !group.hooks.length ? [{ ...group, hooks }] : [];
    });
    const entries = [...retained, ...((desired[event] ?? []) as JsonObject[])];
    if (entries.length) result[event] = entries;
  }
  return result;
}

const WORKMUX = "workmux set-window-status";

/** Claude hooks are managed when any string inside them runs workmux. */
export function containsManagedCommand(value: unknown): boolean {
  if (typeof value === "string") return value.includes(WORKMUX);
  if (Array.isArray(value)) return value.some(containsManagedCommand);
  if (isObject(value)) return Object.values(value).some(containsManagedCommand);
  return false;
}

/** Codex hooks are managed when their command runs workmux. */
export function isManagedCodexHandler(value: unknown): boolean {
  return isObject(value) && typeof value.command === "string" &&
    value.command.includes(WORKMUX);
}

/** Owns `key` in a shared JSON file outright: exactly the declared entries remain. */
export function applyManagedKey(
  writer: ConfigWriter,
  file: string,
  key: string,
  declared: unknown,
): void {
  if (!isObject(declared)) {
    throw new Error(`invalid declared entries for ${key}`);
  }
  const config = readJsonObject(file, {});
  config[key] = declared;
  if (writer.writeJson(file, config)) {
    console.log(`agents: applied managed '${key}' entries -> ${file}`);
  }
}

/** Claude settings: managed workmux hooks plus the wholly owned skill overrides, in one write. */
export function applyClaudeSettings(
  writer: ConfigWriter,
  file: string,
  declaredHooks: JsonObject,
  skillOverrides: unknown,
): void {
  if (!isObject(skillOverrides)) {
    throw new Error("invalid Claude skill overrides");
  }
  const settings = readJsonObject(file, {});
  const hooks = isObject(settings.hooks) ? settings.hooks : {};
  settings.hooks = replaceManagedHooks(
    hooks,
    declaredHooks,
    containsManagedCommand,
  );
  settings.skillOverrides = skillOverrides;
  writer.writeJson(file, settings);
}

/** Codex hooks.json: managed workmux hooks beside RTK's and the user's. */
export function applyCodexHooks(
  writer: ConfigWriter,
  file: string,
  declaredHooks: JsonObject,
): void {
  const target = readJsonObject(file, {});
  const hooks = isObject(target.hooks) ? target.hooks : {};
  target.hooks = replaceManagedHooks(
    hooks,
    declaredHooks,
    isManagedCodexHandler,
  );
  writer.writeJson(file, target);
}

/**
 * Codex config.toml: owns `mcp_servers` and re-enables managed hooks the user
 * disabled. Codex keys hook state as "<hooksFile>:<snake_case_event>:<group>:<index>".
 */
export function applyCodexConfig(
  writer: ConfigWriter,
  file: string,
  mcpServers: unknown,
  hooksFile: string,
): void {
  if (!isObject(mcpServers)) throw new Error("invalid Codex MCP servers");
  const original = lstatOrNull(file) ? Deno.readTextFileSync(file) : "";
  const config = original.trim() ? parseToml(original) as JsonObject : {};
  config.mcp_servers = mcpServers;
  const hooks = readJsonObject(hooksFile, {}).hooks ?? {};
  const state = isObject(config.hooks) && isObject(config.hooks.state)
    ? config.hooks.state
    : {};
  for (const [event, groups] of Object.entries(hooks as JsonObject)) {
    if (!Array.isArray(groups)) {
      throw new Error(`invalid Codex hook event ${event}`);
    }
    const eventKey = event.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
    groups.forEach((group: JsonObject, groupIndex: number) => {
      ((group.hooks ?? []) as unknown[]).forEach((handler, index) => {
        const entry = state[`${hooksFile}:${eventKey}:${groupIndex}:${index}`];
        if (
          isManagedCodexHandler(handler) && isObject(entry) &&
          entry.enabled === false
        ) entry.enabled = true;
      });
    });
  }
  writer.write(file, stringifyToml(config));
}

// Declared before skill paths were recorded, so no state file names them.
// Pi also reads the glob as a filter that hid every other skill.
const RETIRED_SKILL_PATHS = [
  "~/code/*/apps/*/.agents/skills",
  "~/code/monorepo/pub/pi-surface/skills",
];

/** Pi settings: declared skill paths are added and earlier declarations retired; hand-added paths stay. */
export function applyPiSkillPaths(
  writer: ConfigWriter,
  settingsFile: string,
  declared: unknown,
  stateFile: string,
): void {
  if (
    !Array.isArray(declared) ||
    !declared.every((item) => typeof item === "string")
  ) {
    throw new Error("invalid Pi skill paths");
  }
  const settings = readJsonObject(settingsFile, {});
  const before = JSON.stringify(settings);
  let previous: string[] = [];
  try {
    const recorded = JSON.parse(Deno.readTextFileSync(stateFile));
    if (Array.isArray(recorded)) {
      previous = recorded.filter((item) => typeof item === "string");
    }
  } catch {
    // An absent or unreadable record only means nothing earlier can be pruned.
  }
  const stale = new Set(
    [...previous, ...RETIRED_SKILL_PATHS].filter((path) =>
      !declared.includes(path)
    ),
  );
  if (Array.isArray(settings.skills) || declared.length) {
    const skills = (Array.isArray(settings.skills) ? settings.skills : [])
      .filter((path) => !stale.has(path));
    for (const path of declared) if (!skills.includes(path)) skills.push(path);
    settings.skills = skills;
  }
  // Pi reads custom providers from models.json, so a providers map here is stale.
  delete settings.providers;
  if (
    JSON.stringify(settings) !== before &&
    writer.writeJson(settingsFile, settings)
  ) {
    console.log("agents: applied declared Pi settings");
  }
  writer.write(stateFile, JSON.stringify(declared) + "\n");
}

/** Applies every managed field for one agent profile under `home`. */
export function configureApps(
  writer: ConfigWriter,
  home: string,
  dotfiles: string,
  profile: string,
  skillOverridesFile: string,
): void {
  const apps = join(dotfiles, "mise/apps");
  const hooks = join(dotfiles, "agents/workmux-status");
  const read = (file: string) => JSON.parse(Deno.readTextFileSync(file));
  applyManagedKey(
    writer,
    join(home, ".claude.json"),
    "mcpServers",
    read(join(apps, profile, "claude-mcp.json")),
  );
  applyClaudeSettings(
    writer,
    join(home, ".claude/settings.json"),
    readJsonObject(join(hooks, "claude-hooks.json")),
    read(skillOverridesFile),
  );
  const codexHooks = join(home, ".codex/hooks.json");
  applyCodexHooks(
    writer,
    codexHooks,
    readJsonObject(join(hooks, "codex-hooks.json")),
  );
  applyCodexConfig(
    writer,
    join(home, ".codex/config.toml"),
    read(join(apps, profile, "codex-mcp.json")),
    codexHooks,
  );
  applyManagedKey(
    writer,
    join(home, ".pi/agent/mcp.json"),
    "mcpServers",
    read(join(apps, profile, "pi-mcp.json")),
  );
  applyManagedKey(
    writer,
    join(home, ".pi/agent/npm/package.json"),
    "allowScripts",
    read(join(apps, "pi-allow-scripts.json")),
  );
  applyPiSkillPaths(
    writer,
    join(home, ".pi/agent/settings.json"),
    read(join(apps, "pi-skill-paths.json")),
    join(home, ".local/state/agents-nix/pi-skill-paths.json"),
  );
}

if (import.meta.main) {
  const [dotfiles, profile, skillOverrides] = Deno.args;
  const mode = Deno.env.get("RECONCILE_MODE") ?? "apply";
  const home = Deno.env.get("HOME");
  if (
    !dotfiles || !profile || !skillOverrides || !home ||
    (mode !== "apply" && mode !== "status")
  ) {
    console.error(
      "usage: configure-apps.ts DOTFILES PROFILE SKILL_OVERRIDES_FILE (RECONCILE_MODE=apply|status)",
    );
    Deno.exit(2);
  }
  const writer = new ConfigWriter(mode);
  try {
    configureApps(writer, home, dotfiles, profile, skillOverrides);
  } catch (error) {
    console.error(`agents: ${(error as Error).message}`);
    Deno.exit(1);
  }
  if (writer.drift) Deno.exit(1);
}
