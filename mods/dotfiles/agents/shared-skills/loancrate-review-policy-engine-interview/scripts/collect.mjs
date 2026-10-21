#!/usr/bin/env node
/**
 * Deterministic fact collection for a Policy Engine interview submission.
 *
 *   node collect.mjs <candidateDir> [--golden <dir>] [--out <dir>] [--ref <gitref>]
 *                    [--reinstall] [--gate-only]
 *
 * golden/ is found beside <candidateDir>, else under $POLICY_ENGINE_INTERVIEWS (paths.mjs).
 *
 * Everything runs in a clean snapshot of <ref> (default HEAD) so untracked files in
 * the candidate's clone can't skew results. Writes <out>/facts.json and logs under
 * <out>/logs/. Exits non-zero only when collection itself breaks — failing candidate
 * tests are facts, not errors.
 *
 * --gate-only re-runs just the starter + hidden tests against the existing snapshot
 * (use after hand-fixing a shim in <out>/snapshot/<testDir>/__review__/).
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { EXIT_SETUP, SETUP_HINT, findGolden } from "./paths.mjs";

const SKIP_DIRS = new Set(["node_modules", ".git", "dist", "build", "coverage", ".turbo", ".next", "__review__"]);
const LOCKFILES = new Set(["package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb", "npm-shrinkwrap.json"]);
const CODE_EXT = /\.(?:[cm]?[jt]sx?)$/;
const TEST_PATH = /(?:^|\/)(?:test|tests|__tests__|spec)\/|\.(?:test|spec)\.[cm]?[jt]sx?$/;
const CANDIDATE_SCRIPTS = ["typecheck", "lint", "build", "test"];

// ─── CLI ─────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--")) args._.push(a);
    else if (["--reinstall", "--gate-only"].includes(a)) args[a.slice(2)] = true;
    else args[a.slice(2)] = argv[++i];
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const candidateDir = path.resolve(args._[0] ?? process.cwd());
const candidateSlug = path.basename(candidateDir);
const goldenDir = args.golden ? path.resolve(args.golden) : findGolden(candidateDir);
const outDir = path.resolve(args.out ?? path.join(path.dirname(candidateDir), "_reviews", candidateSlug));
const snapshotDir = path.join(outDir, "snapshot");
const logsDir = path.join(outDir, "logs");
const factsPath = path.join(outDir, "facts.json");

// ─── Process helpers ─────────────────────────────────────────────────────────

function run(cmd, cmdArgs, { cwd, timeoutMs = 600_000, log, env } = {}) {
  const started = Date.now();
  const r = spawnSync(cmd, cmdArgs, {
    cwd,
    encoding: "utf8",
    timeout: timeoutMs,
    maxBuffer: 256 * 1024 * 1024,
    env: { ...process.env, CI: "1", NO_COLOR: "1", FORCE_COLOR: "0", ...env },
  });
  const stdout = r.stdout ?? "";
  const stderr = r.stderr ?? "";
  if (log) {
    fs.writeFileSync(path.join(logsDir, log), `$ ${cmd} ${cmdArgs.join(" ")}\n# cwd: ${cwd}\n\n${stdout}${stderr}`);
  }
  return {
    exitCode: r.status ?? 1,
    timedOut: r.error?.code === "ETIMEDOUT",
    stdout,
    stderr,
    durationMs: Date.now() - started,
  };
}

function git(...gitArgs) {
  const r = run("git", ["-C", candidateDir, ...gitArgs]);
  if (r.exitCode !== 0) throw new Error(`git ${gitArgs.join(" ")} failed:\n${r.stderr}`);
  return r.stdout;
}

function die(message, code = 2) {
  console.error(`collect: ${message}`);
  process.exit(code);
}

// ─── File helpers ────────────────────────────────────────────────────────────

/** Relative posix paths of every file under root, skipping build output and deps. */
function walk(root, rel = "") {
  const out = [];
  for (const entry of fs.readdirSync(path.join(root, rel), { withFileTypes: true })) {
    const relPath = rel ? `${rel}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(entry.name)) out.push(...walk(root, relPath));
    } else if (entry.isFile()) {
      out.push(relPath);
    }
  }
  return out;
}

function readText(file) {
  try {
    const buf = fs.readFileSync(file);
    if (buf.length > 2_000_000 || buf.includes(0)) return undefined;
    return buf.toString("utf8");
  } catch {
    return undefined;
  }
}

function lineCount(text) {
  if (!text) return 0;
  return text.split("\n").length - (text.endsWith("\n") ? 1 : 0);
}

function classify(rel) {
  const base = path.posix.basename(rel);
  if (LOCKFILES.has(base)) return "lockfile";
  if (/^\.github\/workflows\/|^\.gitlab-ci|^\.circleci\/|^\.buildkite\//.test(rel)) return "ci";
  if (/\.(?:md|mdx|txt|adoc|rst)$/i.test(base)) return "docs";
  if (CODE_EXT.test(base)) return TEST_PATH.test(rel) ? "test" : "code";
  return "config";
}

function importSpecifier(fromDir, toFile) {
  let rel = path.relative(fromDir, toFile).split(path.sep).join("/");
  rel = rel.replace(/\.(m|c)?tsx?$/, (_, m) => `.${m ?? ""}js`);
  return rel.startsWith(".") ? rel : `./${rel}`;
}

/** Up to `limit` matching lines across files: { file, line, text }. */
function grepFiles(root, files, pattern, limit = 6) {
  const hits = [];
  for (const rel of files) {
    const text = readText(path.join(root, rel));
    if (!text) continue;
    const lines = text.split("\n");
    for (let i = 0; i < lines.length && hits.length < limit; i++) {
      if (pattern.test(lines[i])) hits.push({ file: rel, line: i + 1, text: lines[i].trim().slice(0, 160) });
    }
    if (hits.length >= limit) break;
  }
  return hits;
}

// ─── Snapshot & install ──────────────────────────────────────────────────────

function createSnapshot(sha) {
  fs.rmSync(snapshotDir, { recursive: true, force: true });
  fs.mkdirSync(snapshotDir, { recursive: true });
  const archive = spawnSync("bash", [
    "-o", "pipefail", "-c",
    `git -C ${JSON.stringify(candidateDir)} archive ${sha} | tar -x -C ${JSON.stringify(snapshotDir)}`,
  ]);
  if (archive.status !== 0) die(`git archive failed: ${archive.stderr}`);
  // export-ignore attributes can drop tracked files from the archive; restore any that are missing.
  const tracked = git("ls-tree", "-r", sha)
    .split("\n")
    .filter((l) => l.includes(" blob "))
    .map((l) => l.split("\t")[1]);
  const restored = [];
  for (const rel of tracked) {
    const dest = path.join(snapshotDir, rel);
    if (fs.existsSync(dest)) continue;
    const blob = spawnSync("git", ["-C", candidateDir, "show", `${sha}:${rel}`]);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, blob.stdout);
    restored.push(rel);
  }
  return { trackedFiles: tracked.length, restoredFromExportIgnore: restored };
}

function detectPackageManager(dir) {
  if (fs.existsSync(path.join(dir, "package-lock.json"))) return "npm";
  if (fs.existsSync(path.join(dir, "pnpm-lock.yaml"))) return "pnpm";
  if (fs.existsSync(path.join(dir, "yarn.lock"))) return "yarn";
  return "npm";
}

/** Declared dependencies of the submitted package.json that node_modules lacks (stale install). */
function missingDependencies(nodeModules) {
  const pkg = JSON.parse(fs.readFileSync(path.join(snapshotDir, "package.json"), "utf8"));
  const declared = Object.keys({ ...pkg.dependencies, ...pkg.devDependencies });
  return declared.filter((name) => !fs.existsSync(path.join(nodeModules, name, "package.json")));
}

function ensureInstall(pm) {
  const nodeModules = path.join(candidateDir, "node_modules");
  const missing = fs.existsSync(nodeModules) ? missingDependencies(nodeModules) : ["(no node_modules)"];
  if (missing.length === 0 && !args.reinstall) return { performed: false, pm };
  const attempts = {
    npm: [["ci", "--no-audit", "--no-fund"], ["install", "--no-save", "--no-audit", "--no-fund"]],
    pnpm: [["install", "--frozen-lockfile"], ["install"]],
    yarn: [["install", "--frozen-lockfile"], ["install"]],
  }[pm];
  for (const [i, attempt] of attempts.entries()) {
    const r = run(pm, attempt, { cwd: candidateDir, timeoutMs: 600_000, log: `install-${i}.log` });
    if (r.exitCode === 0) {
      return { performed: true, pm, command: `${pm} ${attempt.join(" ")}`, fellBack: i > 0, reason: args.reinstall ? "--reinstall" : `missing: ${missing.join(", ")}` };
    }
  }
  die(`dependency install failed (see ${logsDir}/install-*.log)`);
}

// ─── Candidate's own checks ──────────────────────────────────────────────────

function parseVitestSummary(output) {
  const m = output.match(/^\s*Tests\s+(.+?)\s*\((\d+)\)\s*$/m);
  if (!m) return undefined;
  const part = (label) => Number(m[1].match(new RegExp(`(\\d+) ${label}`))?.[1] ?? 0);
  return { total: Number(m[2]), passed: part("passed"), failed: part("failed"), skipped: part("skipped") + part("todo") };
}

/**
 * Runs through `npm run` whatever the package manager: it only needs node_modules/.bin on
 * PATH, while pnpm's verify-deps-before-run refuses the snapshot's symlinked node_modules.
 */
function runCandidateChecks(scripts) {
  const checks = [];
  for (const name of CANDIDATE_SCRIPTS) {
    if (!scripts[name]) continue;
    const r = run("npm", ["run", name], { cwd: snapshotDir, timeoutMs: 300_000, log: `check-${name}.log` });
    const combined = `${r.stdout}${r.stderr}`;
    checks.push({
      script: name,
      command: scripts[name],
      exitCode: r.exitCode,
      passed: r.exitCode === 0,
      timedOut: r.timedOut,
      durationMs: r.durationMs,
      log: `logs/check-${name}.log`,
      summary: name === "test" ? parseVitestSummary(combined) : undefined,
      tail: r.exitCode === 0 ? undefined : combined.trim().split("\n").slice(-15).join("\n"),
    });
  }
  return checks;
}

// ─── Module resolution for the review harness ────────────────────────────────

function namedImports(source, specifierPattern) {
  const names = [];
  for (const m of source.matchAll(/import\s+(?:type\s+)?\{([^}]*)\}\s+from\s+["']([^"']+)["']/g)) {
    if (!specifierPattern.test(m[2])) continue;
    for (const raw of m[1].split(",")) {
      const name = raw.trim().replace(/^type\s+/, "").split(/\s+as\s+/)[0];
      if (name) names.push(name);
    }
  }
  return names;
}

function byPreference(prefer) {
  return (a, b) => {
    const pa = prefer(a);
    const pb = prefer(b);
    if (pa !== pb) return pa - pb;
    return a.split("/").length - b.split("/").length || a.localeCompare(b);
  };
}

function resolveHarnessModules(files, fixtureNames) {
  const code = files.filter((f) => CODE_EXT.test(f) && !f.endsWith(".d.ts"));
  const texts = new Map(code.map((f) => [f, readText(path.join(snapshotDir, f)) ?? ""]));
  const nonTest = code.filter((f) => !TEST_PATH.test(f) || /fixture/i.test(f));

  const fixtureModules = {};
  const missingFixtures = [];
  for (const name of fixtureNames) {
    const def = new RegExp(
      `export\\s+(?:const|let|var|function)\\s+${name}\\b|export\\s*\\{[^}]*\\b${name}\\b[^}]*\\}(?!\\s*from)`,
    );
    const hits = code.filter((f) => def.test(texts.get(f))).sort(byPreference((f) => (/fixture/i.test(f) ? 0 : 1)));
    if (hits.length === 0) missingFixtures.push(name);
    else fixtureModules[name] = hits[0];
  }

  const appPattern = /\bexpress\s*\(\s*\)|export\s+(?:async\s+)?function\s+(?:create|build|make)App\b|export\s+const\s+(?:create|build|make)App\b/;
  const appCandidates = nonTest
    .filter((f) => appPattern.test(texts.get(f)) && /\bexport\b/.test(texts.get(f)))
    .sort(
      byPreference((f) => {
        const t = texts.get(f);
        const base = path.posix.basename(f);
        return (/^app\./.test(base) ? 0 : 4) + (/export\s+default/.test(t) ? 0 : 1) + (/\.listen\(/.test(t) ? 2 : 0);
      }),
    );

  const typesModule = nonTest.find((f) => /export\s+(?:interface|type)\s+EvaluationResult\b/.test(texts.get(f)));

  const ruleDefinitionModules = nonTest.filter(
    (f) => /ruleId\s*:\s*["'][A-Z0-9]+-[A-Z0-9-]+["']/.test(texts.get(f)) && !/fixture/i.test(f),
  );
  const ruleDataFiles = files.filter((f) => /\.(?:json|ya?ml)$/.test(f) && !LOCKFILES.has(path.posix.basename(f)) && /["']?ruleId["']?\s*:/.test(readText(path.join(snapshotDir, f)) ?? ""));

  return { fixtureModules, missingFixtures, appModule: appCandidates[0], appCandidates, typesModule, ruleDefinitionModules, ruleDataFiles };
}

function writeHarness(reviewDir, modules, fixtureNames) {
  fs.rmSync(reviewDir, { recursive: true, force: true });
  fs.mkdirSync(reviewDir, { recursive: true });

  const appSpec = modules.appModule ? importSpecifier(reviewDir, path.join(snapshotDir, modules.appModule)) : undefined;
  const appShim = appSpec
    ? `// Generated by review-policy-engine: adapts the candidate's app export to the default export the hidden tests expect.
import * as appModule from ${JSON.stringify(appSpec)};

type Listenable = { listen: (...args: unknown[]) => unknown };
const mod = appModule as Record<string, unknown>;
const isApp = (v: unknown): v is Listenable =>
  typeof v === "function" && typeof (v as { listen?: unknown }).listen === "function";

async function resolveApp(): Promise<Listenable> {
  if (isApp(mod.default)) return mod.default;
  if (isApp(mod.app)) return mod.app;
  for (const value of Object.values(mod)) if (isApp(value)) return value;
  for (const key of ["createApp", "buildApp", "makeApp", "default"]) {
    const factory = mod[key];
    if (typeof factory !== "function") continue;
    const built = await (factory as () => unknown)();
    if (isApp(built)) return built;
  }
  throw new Error("review shim: no Express app export found in ${modules.appModule}");
}

const app = await resolveApp();
export default app;
`
    : `throw new Error("review shim: no module creating an Express app was found");\nexport default undefined;\n`;
  fs.writeFileSync(path.join(reviewDir, "app.shim.ts"), appShim);

  const byModule = new Map();
  for (const name of fixtureNames) {
    const mod = modules.fixtureModules[name];
    if (!mod) continue;
    byModule.set(mod, [...(byModule.get(mod) ?? []), name]);
  }
  const fixtureLines = [...byModule.entries()].map(
    ([mod, names]) => `export { ${names.join(", ")} } from ${JSON.stringify(importSpecifier(reviewDir, path.join(snapshotDir, mod)))};`,
  );
  fs.writeFileSync(
    path.join(reviewDir, "fixtures.shim.ts"),
    `// Generated by review-policy-engine: re-exports the starter fixtures from wherever the candidate moved them.\n${fixtureLines.join("\n")}\n`,
  );

  const typesSpec = modules.typesModule
    ? importSpecifier(reviewDir, path.join(snapshotDir, modules.typesModule))
    : "./fixtures.shim.js";
  const rewrite = (source) =>
    source
      .replace(/from\s+["']\.\.\/src\/app\.js["']/g, 'from "./app.shim.js"')
      .replace(/from\s+["']\.\.\/src\/fixtures\.js["']/g, 'from "./fixtures.shim.js"')
      .replace(/from\s+["']\.\.\/src\/types\.js["']/g, `from ${JSON.stringify(typesSpec)}`);

  fs.writeFileSync(
    path.join(reviewDir, "evaluate.provided.test.ts"),
    rewrite(fs.readFileSync(path.join(goldenDir, "test/evaluate.test.ts"), "utf8")),
  );
  fs.writeFileSync(
    path.join(reviewDir, "evaluate.undisclosed.test.ts"),
    rewrite(fs.readFileSync(path.join(goldenDir, "test/evaluate.undisclosed.test.ts"), "utf8")),
  );
}

// ─── Gate: starter + hidden tests ────────────────────────────────────────────

function countTests(file) {
  return (fs.readFileSync(file, "utf8").match(/\bit\(\s*["'`]/g) ?? []).length;
}

function runGate(reviewDirRel) {
  const vitestBin = path.join(snapshotDir, "node_modules/.bin/vitest");
  const bin = fs.existsSync(vitestBin) ? vitestBin : "npx";
  const baseArgs = bin === "npx" ? ["vitest"] : [];
  const files = [`${reviewDirRel}/evaluate.provided.test.ts`, `${reviewDirRel}/evaluate.undisclosed.test.ts`];
  const jsonPath = path.join(outDir, "gate-results.json");

  const attempt = (extraArgs, log) => {
    fs.rmSync(jsonPath, { force: true });
    const r = run(bin, [...baseArgs, "run", ...extraArgs, "--reporter=default", "--reporter=json", `--outputFile.json=${jsonPath}`], {
      cwd: snapshotDir,
      timeoutMs: 300_000,
      log,
    });
    const report = fs.existsSync(jsonPath) ? JSON.parse(fs.readFileSync(jsonPath, "utf8")) : undefined;
    return { r, report };
  };

  let usedFallbackConfig = false;
  let { r, report } = attempt(files, "gate.log");
  if (!report?.testResults?.length) {
    // The candidate's vitest config may not include our directory; retry with a minimal config.
    const configRel = `${reviewDirRel}/vitest.review.config.mjs`;
    fs.writeFileSync(
      path.join(snapshotDir, configRel),
      `export default { test: { include: [${JSON.stringify(`${reviewDirRel}/*.test.ts`)}] } };\n`,
    );
    usedFallbackConfig = true;
    ({ r, report } = attempt(["--config", configRel], "gate-fallback.log"));
  }

  const expected = {
    provided: countTests(path.join(goldenDir, "test/evaluate.test.ts")),
    hidden: countTests(path.join(goldenDir, "test/evaluate.undisclosed.test.ts")),
  };
  const tests = [];
  const loadErrors = [];
  for (const file of report?.testResults ?? []) {
    const group = file.name.endsWith("evaluate.undisclosed.test.ts") ? "hidden" : "provided";
    if (file.assertionResults.length === 0 && file.status === "failed") {
      loadErrors.push({ group, message: (file.message ?? "").slice(0, 3000) });
    }
    for (const a of file.assertionResults) {
      tests.push({
        group,
        suite: a.ancestorTitles.join(" › "),
        title: a.title,
        status: a.status,
        failure: a.failureMessages?.[0]?.split("\n").slice(0, 8).join("\n"),
      });
    }
  }
  const tally = (group) => {
    const inGroup = tests.filter((t) => t.group === group);
    return { passed: inGroup.filter((t) => t.status === "passed").length, total: expected[group], ran: inGroup.length };
  };
  const provided = tally("provided");
  const hidden = tally("hidden");
  const harnessSuspect =
    loadErrors.length > 0 ||
    (!report?.testResults?.length) ||
    tests.some((t) => /review shim/.test(t.failure ?? ""));

  const liveCommand = usedFallbackConfig
    ? `npx vitest run --config ${reviewDirRel}/vitest.review.config.mjs`
    : `npx vitest run ${reviewDirRel}`;

  return {
    passed: !harnessSuspect && provided.passed === provided.total && hidden.passed === hidden.total,
    provided,
    hidden,
    tests,
    loadErrors,
    harnessSuspect,
    usedFallbackConfig,
    exitCode: r.exitCode,
    log: usedFallbackConfig ? "logs/gate-fallback.log" : "logs/gate.log",
    liveCommand,
  };
}

// ─── Starter comparison (rules, fixtures) via tsx ────────────────────────────

const INSPECT_SOURCE = `import { isDeepStrictEqual } from "node:util";
import fs from "node:fs";
import { pathToFileURL } from "node:url";

const cfg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const load = (file) => import(pathToFileURL(file).href);
const isRule = (v) => v && typeof v === "object" && typeof v.ruleId === "string" && v.condition && typeof v.condition === "object";
const result = { errors: [] };

const golden = (await load(cfg.goldenRules)).rules;
const candidateRules = new Map();
for (const file of cfg.ruleModules) {
  try {
    const mod = await load(file);
    for (const value of Object.values(mod)) {
      const list = Array.isArray(value) ? value : [value];
      for (const item of list) if (isRule(item) && !candidateRules.has(item.ruleId)) candidateRules.set(item.ruleId, item);
    }
  } catch (err) {
    result.errors.push(\`import \${file}: \${String(err?.message ?? err).split("\\n")[0]}\`);
  }
}
for (const file of cfg.ruleDataFiles) {
  if (!file.endsWith(".json")) continue;
  try {
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    const list = Array.isArray(data) ? data : Array.isArray(data.rules) ? data.rules : [];
    for (const item of list) if (isRule(item) && !candidateRules.has(item.ruleId)) candidateRules.set(item.ruleId, item);
  } catch (err) {
    result.errors.push(\`parse \${file}: \${String(err?.message ?? err)}\`);
  }
}

const unchanged = [];
const modified = [];
const removed = [];
const extraFields = {};
for (const g of golden) {
  const c = candidateRules.get(g.ruleId);
  if (!c) { removed.push(g.ruleId); continue; }
  const changedFields = ["resourceType", "severity", "description", "condition"].filter((k) => !isDeepStrictEqual(c[k], g[k]));
  if (changedFields.length) modified.push({ ruleId: g.ruleId, changedFields });
  else unchanged.push(g.ruleId);
}
for (const c of candidateRules.values()) {
  for (const key of Object.keys(c)) {
    if (!["ruleId", "resourceType", "severity", "description", "condition"].includes(key)) {
      extraFields[key] = (extraFields[key] ?? 0) + 1;
    }
  }
}
const goldenIds = new Set(golden.map((r) => r.ruleId));
result.rules = {
  goldenCount: golden.length,
  candidateCount: candidateRules.size,
  unchanged,
  modified,
  removed,
  added: [...candidateRules.values()].filter((r) => !goldenIds.has(r.ruleId)).map((r) => ({
    ruleId: r.ruleId, resourceType: r.resourceType, severity: r.severity, description: r.description,
  })),
  resourceTypes: [...new Set([...candidateRules.values()].map((r) => r.resourceType))],
  extraFields,
};

const goldenFixtures = await load(cfg.goldenFixtures);
let candidateFixtures = {};
try { candidateFixtures = await load(cfg.fixtureShim); } catch (err) { result.errors.push(\`fixtures shim: \${String(err?.message ?? err).split("\\n")[0]}\`); }
const changed = [];
const missing = [];
for (const [name, g] of Object.entries(goldenFixtures)) {
  const c = candidateFixtures[name];
  if (c === undefined) { missing.push(name); continue; }
  if (isDeepStrictEqual(c, g)) continue;
  const keys = new Set([...Object.keys(g.properties ?? {}), ...Object.keys(c.properties ?? {})]);
  const props = [...keys].filter((k) => !isDeepStrictEqual(c.properties?.[k], g.properties?.[k]));
  const top = ["resourceType", "resourceId", "name", "tags"].filter((k) => !isDeepStrictEqual(c[k], g[k]));
  changed.push({ name, changedProperties: props, changedFields: top });
}
result.fixtures = { goldenCount: Object.keys(goldenFixtures).length, changed, missing };

fs.writeFileSync(cfg.out, JSON.stringify(result, null, 2));
process.exit(0);
`;

function compareToStarter(modules) {
  const inspectDir = path.join(snapshotDir, ".review-inspect");
  fs.mkdirSync(inspectDir, { recursive: true });
  const script = path.join(inspectDir, "inspect.mts");
  const cfgPath = path.join(inspectDir, "config.json");
  const out = path.join(outDir, "starter-diff.json");
  fs.writeFileSync(script, INSPECT_SOURCE);

  // A full-fixture shim: every golden fixture name, so the diff covers all of them.
  const goldenFixtureNames = [...fs.readFileSync(path.join(goldenDir, "src/fixtures.ts"), "utf8").matchAll(/export\s+const\s+(\w+)/g)].map((m) => m[1]);
  const allModules = resolveHarnessModules(walk(snapshotDir), goldenFixtureNames);
  const byModule = new Map();
  for (const [name, mod] of Object.entries(allModules.fixtureModules)) byModule.set(mod, [...(byModule.get(mod) ?? []), name]);
  const fullShim = path.join(inspectDir, "fixtures.all.ts");
  fs.writeFileSync(
    fullShim,
    [...byModule.entries()].map(([mod, names]) => `export { ${names.join(", ")} } from ${JSON.stringify(importSpecifier(inspectDir, path.join(snapshotDir, mod)))};`).join("\n") + "\n",
  );

  fs.writeFileSync(
    cfgPath,
    JSON.stringify({
      goldenRules: path.join(goldenDir, "src/rules.ts"),
      goldenFixtures: path.join(goldenDir, "src/fixtures.ts"),
      ruleModules: modules.ruleDefinitionModules.map((f) => path.join(snapshotDir, f)),
      ruleDataFiles: modules.ruleDataFiles.map((f) => path.join(snapshotDir, f)),
      fixtureShim: fullShim,
      out,
    }),
  );
  const tsxBin = path.join(snapshotDir, "node_modules/.bin/tsx");
  const r = fs.existsSync(tsxBin)
    ? run(tsxBin, [script, cfgPath], { cwd: snapshotDir, timeoutMs: 60_000, log: "starter-diff.log" })
    : run("npx", ["--yes", "tsx", script, cfgPath], { cwd: snapshotDir, timeoutMs: 120_000, log: "starter-diff.log" });
  fs.rmSync(inspectDir, { recursive: true, force: true });
  if (r.exitCode !== 0 || !fs.existsSync(out)) {
    return { error: `inspection failed (exit ${r.exitCode}); see logs/starter-diff.log` };
  }
  return JSON.parse(fs.readFileSync(out, "utf8"));
}

// ─── Git history ─────────────────────────────────────────────────────────────

function normalizeRenamePath(p) {
  return p.replace(/\{([^}]*) => ([^}]*)\}/, "$2").replace(/^.* => /, "").replace(/\/\//g, "/");
}

/**
 * Per-file deleted/added line contents of one commit (lockfiles skipped), so moved
 * code can be told apart from rewritten code.
 */
function commitLineChanges(sha) {
  const diff = git("show", "--format=", "--unified=0", "--no-color", "-M", sha);
  const deleted = [];
  const added = [];
  let file;
  for (const line of diff.split("\n")) {
    if (line.startsWith("+++ ")) {
      file = line.replace(/^\+\+\+ (?:b\/)?/, "");
      continue;
    }
    if (line.startsWith("--- ") || line.startsWith("diff --git")) continue;
    if (!file || LOCKFILES.has(path.posix.basename(file))) continue;
    if (line.startsWith("-")) deleted.push({ file, text: line.slice(1) });
    else if (line.startsWith("+")) added.push(line.slice(1));
  }
  return { deleted, added };
}

const normalizeLine = (text) => text.trim().replace(/\s+/g, " ");
const isTrivialLine = (text) => normalizeLine(text).replace(/[\s{}()[\];,]/g, "").length < 4;

function collectHistory(sha) {
  const meta = git("log", "--reverse", "--format=%H%x1f%an%x1f%ae%x1f%aI%x1f%at%x1f%s%x1f%b%x1e", sha)
    .split("\x1e")
    .map((r) => r.trim())
    .filter(Boolean)
    .map((r) => {
      const [hash, author, email, iso, epoch, subject, body = ""] = r.split("\x1f");
      return { sha: hash, author, email, date: iso, epoch: Number(epoch), subject, body: body.trim() };
    });

  const stats = new Map();
  for (const rec of git("log", "--reverse", "--format=%x1e%H", "--numstat", "-M", sha).split("\x1e").filter((s) => s.trim())) {
    const [hash, ...lines] = rec.trim().split("\n");
    const files = lines
      .filter((l) => /^\S+\t\S+\t/.test(l))
      .map((l) => {
        const [added, deleted, ...rest] = l.split("\t");
        const raw = rest.join("\t");
        return { path: normalizeRenamePath(raw), added: Number(added) || 0, deleted: Number(deleted) || 0, binary: added === "-" };
      });
    stats.set(hash, files);
  }

  const status = new Map();
  for (const rec of git("log", "--reverse", "--format=%x1e%H", "--name-status", "-M", sha).split("\x1e").filter((s) => s.trim())) {
    const [hash, ...lines] = rec.trim().split("\n");
    status.set(
      hash,
      lines
        .filter((l) => /^[AMDRCT]\d*\t/.test(l))
        .map((l) => {
          const [code, a, b] = l.split("\t");
          return { code: code[0], path: b ?? a, from: b ? a : undefined };
        }),
    );
  }

  const touchedByCandidate = new Set();
  const commits = meta.map((c, i) => {
    const files = (stats.get(c.sha) ?? []).filter((f) => !LOCKFILES.has(path.posix.basename(f.path)));
    const lockfileChurn = (stats.get(c.sha) ?? []).filter((f) => LOCKFILES.has(path.posix.basename(f.path))).reduce((s, f) => s + f.added + f.deleted, 0);
    const changes = status.get(c.sha) ?? [];
    const renames = changes.filter((s) => s.code === "R");
    // Deleted lines of the candidate's own earlier work: content re-added elsewhere in the
    // same commit counts as moved; the rest counts as revised (rewritten or removed).
    let revisedLines = 0;
    let movedLines = 0;
    const revisedFiles = new Set();
    if (i > 0) {
      const { deleted, added: addedLines } = commitLineChanges(c.sha);
      const pool = new Map();
      for (const text of addedLines) {
        if (isTrivialLine(text)) continue;
        const key = normalizeLine(text);
        pool.set(key, (pool.get(key) ?? 0) + 1);
      }
      const originOf = (p) => renames.find((r) => r.path === p)?.from ?? p;
      for (const d of deleted) {
        if (isTrivialLine(d.text)) continue;
        if (!touchedByCandidate.has(d.file) && !touchedByCandidate.has(originOf(d.file))) continue;
        const key = normalizeLine(d.text);
        const available = pool.get(key) ?? 0;
        if (available > 0) {
          pool.set(key, available - 1);
          movedLines += 1;
        } else {
          revisedLines += 1;
          revisedFiles.add(d.file);
        }
      }
      for (const s of changes) if (s.code !== "D") touchedByCandidate.add(s.path);
    }
    const added = files.reduce((s, f) => s + f.added, 0);
    const deleted = files.reduce((s, f) => s + f.deleted, 0);
    const prev = meta[i - 1];
    const gapSeconds = prev ? c.epoch - prev.epoch : undefined;
    const coAuthors = c.body.split("\n").filter((l) => /^co-authored-by:/i.test(l.trim())).map((l) => l.trim());
    const aiMarkers = c.body.split("\n").filter((l) => /\b(claude|copilot|cursor|chatgpt|codex|gemini|aider|devin|windsurf)\b|generated with|🤖/i.test(l)).map((l) => l.trim());
    const flags = [];
    if (i === 0) flags.push("starter");
    if (revisedLines >= 5) flags.push("revises-earlier-work");
    if (renames.length >= 3 || movedLines >= 50) flags.push("restructure");
    if (/^(?:fix|revert)(?:\(.+\))?!?:|^(?:fix|revert|undo|rework|oops)\b|\b(?:revert|undo|rework|oops|roll ?back)\b/i.test(c.subject)) flags.push("fix-or-revert");
    if (gapSeconds !== undefined && gapSeconds < 60) flags.push("burst");
    if (added > 800) flags.push("large");
    return {
      sha: c.sha,
      short: c.sha.slice(0, 7),
      date: c.date,
      author: c.author,
      subject: c.subject,
      bodyPreview: c.body.split("\n").slice(0, 8).join("\n"),
      added,
      deleted,
      lockfileChurn,
      filesChanged: files.length,
      files: files.map((f) => ({ path: f.path, added: f.added, deleted: f.deleted })),
      renames: renames.map((r) => ({ from: r.from, to: r.path })),
      revisedLines,
      movedLines,
      revisedFiles: [...revisedFiles],
      gapSeconds,
      coAuthors,
      aiMarkers,
      flags,
    };
  });

  const first = meta[0];
  const last = meta[meta.length - 1];
  const candidateCommits = commits.slice(1);
  const conventional = candidateCommits.filter((c) => /^(feat|fix|chore|docs|refactor|test|ci|build|perf|style|revert)(\(.+\))?!?:/.test(c.subject)).length;
  return {
    commitCount: commits.length,
    firstCommitAt: first?.date,
    lastCommitAt: last?.date,
    elapsedMinutes: first && last ? Math.round((last.epoch - first.epoch) / 60) : 0,
    authors: [...new Set(meta.map((c) => c.author))],
    totals: {
      added: candidateCommits.reduce((s, c) => s + c.added, 0),
      deleted: candidateCommits.reduce((s, c) => s + c.deleted, 0),
      revisedLines: candidateCommits.reduce((s, c) => s + c.revisedLines, 0),
      movedLines: candidateCommits.reduce((s, c) => s + c.movedLines, 0),
    },
    commitsRevisingEarlierWork: candidateCommits.filter((c) => c.flags.includes("revises-earlier-work")).length,
    conventionalCommitRatio: candidateCommits.length ? Number((conventional / candidateCommits.length).toFixed(2)) : 0,
    burstCommits: commits.filter((c) => c.flags.includes("burst")).length,
    commitsWithAiMarkers: commits.filter((c) => c.aiMarkers.length || c.coAuthors.length).length,
    commits,
  };
}

function starterIntegrity(rootSha) {
  const excluded = new Set(["src/engine.reference.ts", "swap-engine.sh", "test/evaluate.undisclosed.test.ts"]);
  const goldenFiles = walk(goldenDir).filter((f) => !excluded.has(f));
  const mismatched = [];
  for (const rel of goldenFiles) {
    const r = spawnSync("git", ["-C", candidateDir, "show", `${rootSha}:${rel}`], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    if (r.status !== 0) mismatched.push(`${rel} (missing)`);
    else if (r.stdout !== fs.readFileSync(path.join(goldenDir, rel), "utf8")) mismatched.push(rel);
  }
  return { rootMatchesStarter: mismatched.length === 0, mismatched };
}

// ─── Inventory & detections ──────────────────────────────────────────────────

const GUIDANCE_PATTERNS = [
  [/(?:^|\/)(?:CLAUDE|AGENTS|GEMINI|AI_WORKFLOW|CONVENTIONS)\.md$/i, "agent instructions"],
  [/(?:^|\/)CONTEXT\.md$/, "context doc"],
  [/^\.claude\//, ".claude config"],
  [/^\.cursor\/|(?:^|\/)\.cursorrules$/, "cursor rules"],
  [/(?:^|\/)\.windsurfrules$|^\.clinerules/, "editor agent rules"],
  [/^\.github\/(?:copilot-instructions\.md|instructions\/|prompts\/|agents\/|chatmodes\/)/, "copilot instructions"],
  [/^\.agents\/|^\.kiro\/|^\.specify\/|^memory-bank\//, "agent workspace"],
  [/^openspec\//, "openspec"],
  [/^specs?\/.*\.md$/, "specs"],
];

const ROADMAP_HEADING = /roadmap|future|next steps?|if i had more time|what i(?:'|’)?d do|todo|follow[- ]?ups?|\bextend|extensions?|improvements?|enhancements?|production|deferred|out of scope|not (?:yet )?(?:done|implemented|built)|limitations|trade-?offs|known (?:issues|gaps)|what'?s missing|backlog|\bphase\b|planned|^(?:now|next|later|status)$/i;
const ROADMAP_FILE = /(?:^|\/)[^/]*(?:roadmap|plan|todo|backlog|next[-_]?steps)[^/]*\.mdx?$/i;

function markdownDocs(files) {
  const docs = [];
  for (const rel of files.filter((f) => /\.mdx?$/i.test(f))) {
    const text = readText(path.join(snapshotDir, rel));
    if (!text) continue;
    const lines = text.split("\n");
    if (ROADMAP_FILE.test(rel)) {
      docs.push({
        path: rel,
        lines: lines.length,
        roadmapFile: true,
        headings: lines.flatMap((l, i) => (/^#{1,4}\s/.test(l) ? [{ level: l.match(/^#+/)[0].length, text: l.replace(/^#+\s+/, "").trim(), line: i + 1 }] : [])).slice(0, 60),
        roadmapSections: [{ heading: "(whole file)", line: 1, excerpt: lines.slice(0, 200).join("\n"), truncated: lines.length > 200 }],
      });
      continue;
    }
    const headings = [];
    const roadmapSections = [];
    lines.forEach((line, i) => {
      const m = line.match(/^(#{1,4})\s+(.*)$/);
      if (!m) return;
      headings.push({ level: m[1].length, text: m[2].trim(), line: i + 1 });
    });
    for (const [idx, h] of headings.entries()) {
      if (!ROADMAP_HEADING.test(h.text)) continue;
      const next = headings.slice(idx + 1).find((n) => n.level <= h.level);
      const end = next ? next.line - 1 : lines.length;
      const body = lines.slice(h.line, Math.min(end, h.line + 80)).join("\n").trim();
      roadmapSections.push({ heading: h.text, line: h.line, excerpt: body, truncated: end - h.line > 80 });
    }
    docs.push({ path: rel, lines: lines.length, headings: headings.slice(0, 40), roadmapSections });
  }
  return docs;
}

function packageDiff() {
  const read = (dir) => JSON.parse(fs.readFileSync(path.join(dir, "package.json"), "utf8"));
  const g = read(goldenDir);
  const c = read(snapshotDir);
  const diff = (a = {}, b = {}) => ({
    added: Object.fromEntries(Object.entries(b).filter(([k]) => !(k in a))),
    removed: Object.keys(a).filter((k) => !(k in b)),
    changed: Object.fromEntries(Object.entries(b).filter(([k, v]) => k in a && a[k] !== v)),
  });
  return {
    dependencies: diff(g.dependencies, c.dependencies),
    devDependencies: diff(g.devDependencies, c.devDependencies),
    scripts: diff(g.scripts, c.scripts),
  };
}

function inventory(files) {
  const byKind = {};
  const codeFiles = [];
  for (const rel of files) {
    const kind = classify(rel);
    if (kind === "lockfile") continue;
    const lines = lineCount(readText(path.join(snapshotDir, rel)));
    byKind[kind] = byKind[kind] ?? { files: 0, lines: 0 };
    byKind[kind].files += 1;
    byKind[kind].lines += lines;
    if (kind === "code") codeFiles.push({ path: rel, lines });
  }
  codeFiles.sort((a, b) => b.lines - a.lines);
  const topDirs = [...new Set(files.map((f) => f.split("/")[0]))].sort();
  return { byKind, largestCodeFiles: codeFiles.slice(0, 10), topLevel: topDirs, codeFiles: codeFiles.map((f) => f.path).sort() };
}

function detections(files) {
  const code = files.filter((f) => CODE_EXT.test(f) && !f.endsWith(".d.ts") && !TEST_PATH.test(f));
  const g = (re, limit) => grepFiles(snapshotDir, code, re, limit);
  const guidance = [];
  for (const rel of files) {
    const match = GUIDANCE_PATTERNS.find(([re]) => re.test(rel));
    if (match) guidance.push({ path: rel, kind: match[1], lines: lineCount(readText(path.join(snapshotDir, rel))) });
  }
  return {
    agentGuidance: { files: guidance, totalLines: guidance.reduce((s, f) => s + f.lines, 0) },
    ci: files.filter((f) => classify(f) === "ci"),
    container: files.filter((f) => /(?:^|\/)(?:Dockerfile[^/]*|docker-compose[^/]*\.ya?ml|compose\.ya?ml|\.dockerignore|Containerfile)$/.test(f)),
    lintFormat: files.filter((f) => /(?:^|\/)(?:eslint\.config\.[cm]?[jt]s|\.eslintrc[^/]*|\.prettierrc[^/]*|prettier\.config\.[cm]?js|biome\.jsonc?|knip\.jsonc?|\.editorconfig|\.oxlintrc[^/]*)$/.test(f)),
    apiDocs: files.filter((f) => /(?:openapi|swagger)[^/]*\.(?:ya?ml|json)$|\.bru$|\.http$|postman/i.test(f)),
    envExamples: files.filter((f) => /(?:^|\/)\.env(?:\.[\w-]+)?\.example$|(?:^|\/)\.env\.sample$/.test(f)),
    signals: {
      loggingLibrary: g(/from\s+["'](?:pino|winston|bunyan|pino-http|morgan)["']/),
      consoleLogging: g(/\bconsole\.(?:log|info|warn|error)\(/, 4),
      metricsTracing: g(/prom-client|@opentelemetry|dd-trace|statsd|metrics\./),
      healthEndpoint: g(/["'`]\/(?:health|healthz|ready|readyz|livez|status)["'`]/),
      gracefulShutdown: g(/SIGTERM|SIGINT/),
      envConfig: g(/process\.env\.[A-Z_]+/),
      schemaValidationLibrary: g(/from\s+["'](?:zod|ajv|@sinclair\/typebox|typebox|valibot|joi|yup|superstruct)["']/),
      securityMiddleware: g(/\bhelmet\b|express-rate-limit|rateLimit\(|\bcors\(/),
      bodySizeLimit: g(/express\.json\(\s*\{[^}]*limit/),
      ruleLoadingFromData: g(/readFile[^;\n]*rule|loadRules|rules?\.(?:ya?ml|json)["'`]|YAML\.parse|yaml\.load|parseYaml/i),
      ruleMutationRoutes: g(/\.(?:post|put|patch|delete)\(\s*["'`]\/rules/i),
      ruleVersionField: g(/\bruleVersion\b|\bversion\s*\??:\s*(?:number|string)/),
      conditionDispatch: g(/case\s+["'](?:field|array|and|or|not)["']|\[\s*condition\.type\s*\]|evaluators?\s*\[|handlers?\s*\[|Record<\s*Condition\[["']type["']\]/, 12),
      operatorRegistry: g(/Record<[^>]*operator[^>]*>|operators?\s*[:=]\s*\{|\bnew Map<[^>]*Operator/i, 4),
    },
  };
}

// ─── Main ────────────────────────────────────────────────────────────────────

function remoteInfo() {
  const r = run("git", ["-C", candidateDir, "remote", "get-url", "origin"]);
  const url = r.stdout.trim();
  const m = url.match(/github\.com[/:]([^/]+)\/(.+?)(?:\.git)?$/);
  return { url: url || undefined, githubBase: m ? `https://github.com/${m[1]}/${m[2]}` : undefined };
}

function gateOnly() {
  if (!fs.existsSync(factsPath)) die("--gate-only needs an existing facts.json; run a full collection first");
  const facts = JSON.parse(fs.readFileSync(factsPath, "utf8"));
  fs.mkdirSync(logsDir, { recursive: true });
  facts.gate = runGate(facts.harness.reviewDir);
  fs.writeFileSync(factsPath, JSON.stringify(facts, null, 2));
  printSummary(facts);
}

function printSummary(facts) {
  const { gate } = facts;
  console.log(`candidate   ${facts.candidate.displayName} (${facts.candidate.slug}) @ ${facts.candidate.headShort}`);
  console.log(`gate        ${gate.passed ? "PASS" : "FAIL"}  provided ${gate.provided.passed}/${gate.provided.total}  hidden ${gate.hidden.passed}/${gate.hidden.total}${gate.harnessSuspect ? "  ⚠ harness suspect — check shims" : ""}`);
  for (const c of facts.checks ?? []) console.log(`check       ${c.script.padEnd(10)} ${c.passed ? "pass" : `FAIL (exit ${c.exitCode})`}${c.summary ? `  ${c.summary.passed}/${c.summary.total} tests` : ""}`);
  console.log(`history     ${facts.history.commitCount} commits over ${facts.history.elapsedMinutes} min`);
  console.log(`facts       ${factsPath}`);
}

function main() {
  if (!fs.existsSync(path.join(candidateDir, ".git"))) die(`${candidateDir} is not a git repository`);
  if (!goldenDir) die(`no golden/ beside ${candidateDir}; pass --golden <dir> or ${SETUP_HINT}`, EXIT_SETUP);
  for (const f of ["test/evaluate.test.ts", "test/evaluate.undisclosed.test.ts", "src/rules.ts", "src/fixtures.ts", "package.json"]) {
    if (!fs.existsSync(path.join(goldenDir, f))) die(`golden repo at ${goldenDir} is missing ${f}`);
  }
  if (args["gate-only"]) return gateOnly();

  fs.mkdirSync(logsDir, { recursive: true });
  const sha = git("rev-parse", args.ref ?? "HEAD").trim();
  const rootSha = git("rev-list", "--max-parents=0", sha).trim().split("\n").pop();

  const snapshot = createSnapshot(sha);
  const pm = detectPackageManager(snapshotDir);
  const install = ensureInstall(pm);
  fs.symlinkSync(path.join(candidateDir, "node_modules"), path.join(snapshotDir, "node_modules"), "dir");

  const pkg = JSON.parse(fs.readFileSync(path.join(snapshotDir, "package.json"), "utf8"));
  const files = walk(snapshotDir);

  // Candidate checks run on the pristine snapshot, before any review files exist.
  const checks = runCandidateChecks(pkg.scripts ?? {});

  const fixtureNames = [
    ...new Set([
      ...namedImports(fs.readFileSync(path.join(goldenDir, "test/evaluate.test.ts"), "utf8"), /\/fixtures\.js$/),
      ...namedImports(fs.readFileSync(path.join(goldenDir, "test/evaluate.undisclosed.test.ts"), "utf8"), /\/fixtures\.js$/),
    ]),
  ];
  const modules = resolveHarnessModules(files, fixtureNames);
  const providedTest = files.find((f) => /(?:^|\/)evaluate\.test\.ts$/.test(f));
  const testDirRel = providedTest ? path.posix.dirname(providedTest) : "test";
  const reviewDirRel = `${testDirRel}/__review__`;
  writeHarness(path.join(snapshotDir, reviewDirRel), modules, fixtureNames);
  const gate = runGate(reviewDirRel);

  // Leave the harness in the candidate's clone so the hidden tests can be re-run live.
  const liveReviewDir = path.join(candidateDir, reviewDirRel);
  fs.rmSync(liveReviewDir, { recursive: true, force: true });
  fs.cpSync(path.join(snapshotDir, reviewDirRel), liveReviewDir, { recursive: true });

  const starterDiff = compareToStarter(modules);
  const history = collectHistory(sha);
  const remote = remoteInfo();
  const gitAuthor = history.commits.slice(1).map((c) => c.author).find(Boolean) ?? history.commits[0]?.author;
  // Review folders are named after the candidate; git author names are sometimes handles.
  const displayName = candidateSlug.split(/[-_]/).map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
  const nvmrc = readText(path.join(snapshotDir, ".nvmrc"))?.trim();

  const facts = {
    schema: 1,
    collectedAt: new Date().toISOString(),
    candidate: {
      slug: candidateSlug,
      displayName,
      gitAuthor,
      dir: candidateDir,
      ref: args.ref ?? "HEAD",
      headSha: sha,
      headShort: sha.slice(0, 7),
      rootSha,
      remote,
    },
    paths: { outDir, snapshotDir, goldenDir, factsPath },
    environment: { node: process.version, nvmrc, packageManager: pm, install },
    snapshot,
    starter: starterIntegrity(rootSha),
    checks,
    harness: {
      reviewDir: reviewDirRel,
      liveReviewDir,
      modules: {
        app: modules.appModule,
        appCandidates: modules.appCandidates,
        types: modules.typesModule,
        fixtures: modules.fixtureModules,
        missingFixtures: modules.missingFixtures,
        ruleDefinitionModules: modules.ruleDefinitionModules,
        ruleDataFiles: modules.ruleDataFiles,
      },
    },
    gate,
    starterDiff,
    history,
    inventory: inventory(files),
    packageDiff: packageDiff(),
    docs: markdownDocs(files),
    detections: detections(files),
  };
  fs.writeFileSync(factsPath, JSON.stringify(facts, null, 2));
  printSummary(facts);
}

main();
