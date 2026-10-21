#!/usr/bin/env node
/**
 * Deterministic fact collection for a Filters interview submission.
 *
 *   node collect.mjs <candidateDir> [--golden <dir>] [--out <dir>] [--ref <gitref>] [--reinstall]
 *
 * golden/ is found beside <candidateDir>, else under $FILTERS_INTERVIEWS (paths.mjs).
 *
 * Everything runs in a clean snapshot of <ref> (default HEAD) so untracked files in the
 * candidate's clone can't skew results. Dependencies are installed inside the snapshot
 * (workspaces and pnpm keep per-package node_modules, so a symlink to the clone's would
 * not do). Writes <out>/facts.json and logs under <out>/logs/. Exits non-zero only when
 * collection itself breaks — failing candidate checks are facts, not errors.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { EXIT_SETUP, SETUP_HINT, findGolden } from "./paths.mjs";
import { restorePatches } from "./app.mjs";

const SKIP_DIRS = new Set(["node_modules", ".git", "dist", "build", "coverage", ".turbo", ".next", ".vite", "test-results", "playwright-report"]);
const LOCKFILES = new Set(["package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb", "bun.lock", "npm-shrinkwrap.json"]);
const CODE_EXT = /\.(?:[cm]?[jt]sx?)$/;
const STYLE_EXT = /\.(?:css|scss|sass|less)$/;
const TEST_PATH = /(?:^|\/)(?:test|tests|__tests__|spec|e2e)\/|\.(?:test|spec)\.[cm]?[jt]sx?$/;
const DATA_FILE = /(?:^|\/)borrowers[^/]*\.json$/;
const CANDIDATE_SCRIPTS = ["typecheck", "lint", "build", "test"];
const TIME_BOX_MINUTES = 120;

// ─── CLI ─────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--")) args._.push(a);
    else if (a === "--reinstall") args.reinstall = true;
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
const shaMarker = path.join(snapshotDir, ".review-sha");

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
  return { exitCode: r.status ?? 1, timedOut: r.error?.code === "ETIMEDOUT", stdout, stderr, durationMs: Date.now() - started };
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
    } else if (entry.isFile() && relPath !== ".review-sha") {
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

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
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
  if (DATA_FILE.test(rel)) return "data";
  if (/^\.github\/workflows\/|^\.gitlab-ci|^\.circleci\/|^\.buildkite\//.test(rel)) return "ci";
  if (/\.(?:md|mdx|txt|adoc|rst)$/i.test(base)) return "docs";
  if (STYLE_EXT.test(base)) return "style";
  if (CODE_EXT.test(base)) return TEST_PATH.test(rel) ? "test" : "code";
  if (/\.(?:png|jpe?g|gif|svg|ico|webp|woff2?)$/i.test(base)) return "asset";
  return "config";
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
  // Lifecycle scripts like `prepare: git config core.hooksPath …` fail outside a repository.
  spawnSync("git", ["init", "-q"], { cwd: snapshotDir });
  return { trackedFiles: tracked.length, restoredFromExportIgnore: restored };
}

function detectPackageManager(dir) {
  if (fs.existsSync(path.join(dir, "pnpm-lock.yaml"))) return "pnpm";
  if (fs.existsSync(path.join(dir, "yarn.lock"))) return "yarn";
  if (fs.existsSync(path.join(dir, "bun.lock")) || fs.existsSync(path.join(dir, "bun.lockb"))) return "bun";
  return "npm";
}

function install(pm) {
  const attempts = {
    npm: [["ci", "--no-audit", "--no-fund"], ["install", "--no-audit", "--no-fund"]],
    pnpm: [["install", "--frozen-lockfile"], ["install"]],
    yarn: [["install", "--frozen-lockfile"], ["install"]],
    bun: [["install", "--frozen-lockfile"], ["install"]],
  }[pm];
  for (const [i, attempt] of attempts.entries()) {
    const r = run(pm, attempt, { cwd: snapshotDir, timeoutMs: 900_000, log: `install-${i}.log` });
    if (r.exitCode === 0) return { performed: true, pm, command: `${pm} ${attempt.join(" ")}`, fellBack: i > 0, durationMs: r.durationMs };
  }
  die(`dependency install failed (see ${logsDir}/install-*.log); fix the environment, then re-run`);
}

/** Reuses an installed snapshot of the same commit; anything else gets a fresh snapshot and install. */
function prepareSnapshot(sha) {
  restorePatches(outDir);
  const reusable =
    !args.reinstall &&
    fs.existsSync(path.join(snapshotDir, "node_modules")) &&
    readText(shaMarker)?.trim() === sha;
  if (reusable) return { snapshot: { reused: true }, install: { performed: false, pm: detectPackageManager(snapshotDir), reason: "snapshot of this commit already installed" } };
  const snapshot = createSnapshot(sha);
  const pm = detectPackageManager(snapshotDir);
  const installed = install(pm);
  fs.writeFileSync(shaMarker, `${sha}\n`);
  return { snapshot, install: installed };
}

// ─── Workspaces ──────────────────────────────────────────────────────────────

/** Workspace package dirs (relative), from package.json workspaces or pnpm-workspace.yaml. */
function workspaceDirs() {
  const pkg = readJson(path.join(snapshotDir, "package.json")) ?? {};
  let patterns = Array.isArray(pkg.workspaces) ? pkg.workspaces : pkg.workspaces?.packages ?? [];
  const pnpmWs = readText(path.join(snapshotDir, "pnpm-workspace.yaml"));
  if (pnpmWs) patterns = [...patterns, ...[...pnpmWs.matchAll(/^\s*-\s*["']?([^"'\n]+)["']?\s*$/gm)].map((m) => m[1])];
  const dirs = new Set();
  for (const pattern of patterns) {
    if (pattern.endsWith("/*")) {
      const base = pattern.slice(0, -2);
      const abs = path.join(snapshotDir, base);
      if (!fs.existsSync(abs)) continue;
      for (const entry of fs.readdirSync(abs, { withFileTypes: true })) {
        if (entry.isDirectory() && fs.existsSync(path.join(abs, entry.name, "package.json"))) dirs.add(`${base}/${entry.name}`);
      }
    } else if (fs.existsSync(path.join(snapshotDir, pattern, "package.json"))) {
      dirs.add(pattern);
    }
  }
  return [...dirs].sort();
}

// ─── Candidate's own checks ──────────────────────────────────────────────────

/** Sums every vitest, jest and node:test summary in the output (one per workspace). */
function parseTestSummary(output) {
  let total = 0;
  let passed = 0;
  let failed = 0;
  let found = false;
  for (const m of output.matchAll(/^\s*Tests\s+(.+?)\s*\((\d+)\)\s*$/gm)) {
    found = true;
    total += Number(m[2]);
    passed += Number(m[1].match(/(\d+) passed/)?.[1] ?? 0);
    failed += Number(m[1].match(/(\d+) failed/)?.[1] ?? 0);
  }
  for (const m of output.matchAll(/^Tests:\s+(.+?)\s*$/gm)) {
    found = true;
    const n = (label) => Number(m[1].match(new RegExp(`(\\d+) ${label}`))?.[1] ?? 0);
    passed += n("passed");
    failed += n("failed");
    total += n("total");
  }
  for (const m of output.matchAll(/^ℹ tests (\d+)\s*\nℹ suites \d+\s*\nℹ pass (\d+)\s*\nℹ fail (\d+)/gm)) {
    found = true;
    total += Number(m[1]);
    passed += Number(m[2]);
    failed += Number(m[3]);
  }
  return found ? { total, passed, failed } : undefined;
}

/**
 * Root scripts first; a script the root lacks but workspaces define runs in each of them
 * (the starter has no root test script, so workspace-level tests are common).
 */
function runCandidateChecks(pm, workspaces) {
  const rootScripts = readJson(path.join(snapshotDir, "package.json"))?.scripts ?? {};
  const checks = [];
  for (const name of CANDIDATE_SCRIPTS) {
    const targets = rootScripts[name]
      ? [{ dir: ".", command: rootScripts[name] }]
      : workspaces
          .map((dir) => ({ dir, command: readJson(path.join(snapshotDir, dir, "package.json"))?.scripts?.[name] }))
          .filter((t) => t.command);
    if (targets.length === 0) continue;
    let combined = "";
    let exitCode = 0;
    let timedOut = false;
    let durationMs = 0;
    for (const t of targets) {
      const r = run(pm, ["run", name], { cwd: path.join(snapshotDir, t.dir), timeoutMs: 300_000 });
      combined += `\n# ${t.dir}: ${pm} run ${name}  (${t.command})\n${r.stdout}${r.stderr}`;
      if (r.exitCode !== 0) exitCode = r.exitCode;
      timedOut ||= r.timedOut;
      durationMs += r.durationMs;
    }
    fs.writeFileSync(path.join(logsDir, `check-${name}.log`), combined);
    checks.push({
      script: name,
      where: targets.map((t) => t.dir),
      command: targets.map((t) => t.command).join(" ; "),
      exitCode,
      passed: exitCode === 0,
      timedOut,
      durationMs,
      log: `logs/check-${name}.log`,
      summary: name === "test" ? parseTestSummary(combined) : undefined,
      tail: exitCode === 0 ? undefined : combined.trim().split("\n").slice(-20).join("\n"),
    });
  }
  return checks;
}

// ─── Runtime facts: dataset, ports, start commands ───────────────────────────

/** The borrower data the server most likely serves, compared with the starter's. */
function datasetFacts(files) {
  const goldenData = readJson(path.join(goldenDir, "packages/server/borrowers.json")) ?? [];
  const candidates = files.filter((f) => DATA_FILE.test(f) && !TEST_PATH.test(f));
  const pick = candidates.find((f) => f === "packages/server/borrowers.json") ?? candidates.sort((a, b) => a.split("/").length - b.split("/").length)[0];
  const data = pick ? readJson(path.join(snapshotDir, pick)) : undefined;
  const list = Array.isArray(data) ? data : Array.isArray(data?.borrowers) ? data.borrowers : undefined;
  const goldenIds = new Set(goldenData.map((b) => b.id));
  return {
    file: pick ?? null,
    candidates,
    count: list?.length ?? null,
    goldenCount: goldenData.length,
    sameAsStarter: list ? list.length === goldenData.length && list.every((b) => goldenIds.has(b.id)) && JSON.stringify(list) === JSON.stringify(goldenData) : false,
    sameIdsAsStarter: list ? list.length === goldenData.length && list.every((b) => goldenIds.has(b.id)) : false,
  };
}

/** Ports hard-coded in the server and client sources (the starter uses 1337 and 1234). */
function portFacts(files) {
  const code = files.filter((f) => (CODE_EXT.test(f) || /(?:^|\/)\.env[^/]*$/.test(f)) && !TEST_PATH.test(f) && !f.includes("node_modules"));
  const serverFiles = code.filter((f) => /(?:^|\/)(?:packages|apps)\/(?:server|api|backend)\//.test(f) || /^server\//.test(f));
  const clientFiles = code.filter((f) => /vite\.config|webpack\.config|next\.config/.test(f));
  const portIn = (list, patterns) => {
    for (const rel of list) {
      const text = readText(path.join(snapshotDir, rel)) ?? "";
      for (const re of patterns) {
        const m = text.match(re);
        if (m) return { port: Number(m[1]), file: rel };
      }
    }
    return undefined;
  };
  const server = portIn(serverFiles, [/\bPORT\b[^\n=]*=[^\n]*?\b(\d{4,5})\b/, /\.listen\(\s*(\d{4,5})/, /\bport\s*[:=]\s*(\d{4,5})/i]);
  const client = portIn(clientFiles, [/\bport\s*:\s*(\d{4,5})/]);
  const referenced = new Set();
  for (const rel of code) {
    for (const m of (readText(path.join(snapshotDir, rel)) ?? "").matchAll(/localhost:(\d{4,5})/g)) referenced.add(Number(m[1]));
  }
  return {
    server: server?.port ?? 1337,
    serverSource: server?.file ?? "starter default",
    client: client?.port ?? 1234,
    clientSource: client?.file ?? "starter default",
    referenced: [...referenced].sort(),
  };
}

function startFacts(pm, workspaces) {
  const scripts = readJson(path.join(snapshotDir, "package.json"))?.scripts ?? {};
  const wsWith = (re) => workspaces.find((d) => re.test(path.posix.basename(d)) && readJson(path.join(snapshotDir, d, "package.json"))?.scripts?.dev);
  const serverWs = wsWith(/server|api|backend/);
  const clientWs = wsWith(/client|web|frontend|app/);
  return {
    server: scripts["dev:server"] ? `${pm} run dev:server` : serverWs ? `cd ${serverWs} && ${pm} run dev` : null,
    client: scripts["dev:client"] ? `${pm} run dev:client` : clientWs ? `cd ${clientWs} && ${pm} run dev` : null,
    both: scripts.dev ? `${pm} run dev` : scripts.start ? `${pm} start` : null,
  };
}

// ─── Git history ─────────────────────────────────────────────────────────────

function normalizeRenamePath(p) {
  return p.replace(/\{([^}]*) => ([^}]*)\}/, "$2").replace(/^.* => /, "").replace(/\/\//g, "/");
}

/** Per-file deleted/added line contents of one commit (lockfiles and data skipped). */
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
    if (!file || LOCKFILES.has(path.posix.basename(file)) || DATA_FILE.test(file)) continue;
    if (line.startsWith("-")) deleted.push({ file, text: line.slice(1) });
    else if (line.startsWith("+")) added.push(line.slice(1));
  }
  return { deleted, added };
}

const normalizeLine = (text) => text.trim().replace(/\s+/g, " ");
const isTrivialLine = (text) => normalizeLine(text).replace(/[\s{}()[\];,]/g, "").length < 4;
const isNoise = (p) => LOCKFILES.has(path.posix.basename(p)) || DATA_FILE.test(p);

function collectHistory(sha) {
  const meta = git("log", "--reverse", "--format=%H%x1f%an%x1f%ae%x1f%aI%x1f%at%x1f%ct%x1f%P%x1f%s%x1f%b%x1e", sha)
    .split("\x1e")
    .map((r) => r.trim())
    .filter(Boolean)
    .map((r) => {
      const [hash, author, email, iso, epoch, commitEpoch, parents, subject, body = ""] = r.split("\x1f");
      return { sha: hash, author, email, date: iso, epoch: Number(epoch), commitEpoch: Number(commitEpoch), merge: parents.trim().split(" ").length > 1, subject, body: body.trim() };
    });

  const stats = new Map();
  for (const rec of git("log", "--reverse", "--format=%x1e%H", "--numstat", "-M", sha).split("\x1e").filter((s) => s.trim())) {
    const [hash, ...lines] = rec.trim().split("\n");
    stats.set(
      hash,
      lines
        .filter((l) => /^\S+\t\S+\t/.test(l))
        .map((l) => {
          const [added, deleted, ...rest] = l.split("\t");
          return { path: normalizeRenamePath(rest.join("\t")), added: Number(added) || 0, deleted: Number(deleted) || 0 };
        }),
    );
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

  const epochCounts = new Map();
  for (const c of meta) epochCounts.set(c.epoch, (epochCounts.get(c.epoch) ?? 0) + 1);
  const startEpoch = meta[0]?.epoch ?? 0;

  const touchedByCandidate = new Set();
  const commits = meta.map((c, i) => {
    const all = stats.get(c.sha) ?? [];
    const files = all.filter((f) => !isNoise(f.path));
    const lockfileChurn = all.filter((f) => isNoise(f.path)).reduce((s, f) => s + f.added + f.deleted, 0);
    const changes = status.get(c.sha) ?? [];
    const renames = changes.filter((s) => s.code === "R");
    // Deleted lines of the candidate's own earlier work: content re-added elsewhere in the
    // same commit counts as moved; the rest counts as revised (rewritten or removed).
    let revisedLines = 0;
    let movedLines = 0;
    const revisedFiles = new Set();
    if (i > 0 && !c.merge) {
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
    }
    if (i > 0) for (const s of changes) if (s.code !== "D") touchedByCandidate.add(s.path);
    const added = c.merge ? 0 : files.reduce((s, f) => s + f.added, 0);
    const deleted = c.merge ? 0 : files.reduce((s, f) => s + f.deleted, 0);
    const prev = meta[i - 1];
    const gapSeconds = prev ? c.epoch - prev.epoch : undefined;
    const minutesFromStart = Math.round((c.epoch - startEpoch) / 60);
    const coAuthors = c.body.split("\n").filter((l) => /^co-authored-by:/i.test(l.trim())).map((l) => l.trim());
    const aiMarkers = c.body.split("\n").filter((l) => /\b(claude|copilot|cursor|chatgpt|codex|gemini|aider|devin|windsurf)\b|generated with|🤖/i.test(l)).map((l) => l.trim());
    const flags = [];
    if (i === 0) flags.push("starter");
    if (c.merge) flags.push("merge");
    if (revisedLines >= 5) flags.push("revises-earlier-work");
    if (renames.length >= 3 || movedLines >= 50) flags.push("restructure");
    if (/^(?:fix|revert)(?:\(.+\))?!?:|^(?:fix|revert|undo|rework|oops)\b|\b(?:revert|undo|rework|oops|roll ?back)\b/i.test(c.subject)) flags.push("fix-or-revert");
    if (gapSeconds !== undefined && gapSeconds < 60) flags.push("burst");
    if (added > 800) flags.push("large");
    if (epochCounts.get(c.epoch) > 1) flags.push("same-timestamp");
    if (minutesFromStart > TIME_BOX_MINUTES + 15) flags.push("past-time-box");
    return {
      sha: c.sha,
      short: c.sha.slice(0, 7),
      date: c.date,
      minutesFromStart,
      committerLagMinutes: Math.round((c.commitEpoch - c.epoch) / 60),
      author: c.author,
      subject: c.subject,
      bodyPreview: c.body.split("\n").slice(0, 8).join("\n"),
      added,
      deleted,
      lockfileChurn,
      filesChanged: files.length,
      files: files.slice(0, 40).map((f) => ({ path: f.path, added: f.added, deleted: f.deleted })),
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
  const work = commits.slice(1).filter((c) => !c.flags.includes("merge"));
  const sameTimestampCommits = commits.filter((c) => c.flags.includes("same-timestamp")).length;
  // A few commits in one second happen when an agent commits in a batch; a large group means rebased or squashed history.
  const largestSameTimestampGroup = Math.max(0, ...epochCounts.values());
  return {
    commitCount: commits.length,
    firstCommitAt: first?.date,
    lastCommitAt: last?.date,
    elapsedMinutes: first && last ? Math.round((last.epoch - first.epoch) / 60) : 0,
    timeBoxMinutes: TIME_BOX_MINUTES,
    commitsPastTimeBox: commits.filter((c) => c.flags.includes("past-time-box")).length,
    sameTimestampCommits,
    largestSameTimestampGroup,
    timestampsLookRewritten: largestSameTimestampGroup >= 4,
    authors: [...new Set(meta.map((c) => c.author))],
    totals: {
      added: work.reduce((s, c) => s + c.added, 0),
      deleted: work.reduce((s, c) => s + c.deleted, 0),
      revisedLines: work.reduce((s, c) => s + c.revisedLines, 0),
      movedLines: work.reduce((s, c) => s + c.movedLines, 0),
    },
    commitsRevisingEarlierWork: work.filter((c) => c.flags.includes("revises-earlier-work")).length,
    mergeCommits: commits.filter((c) => c.flags.includes("merge")).length,
    commitsWithAiMarkers: commits.filter((c) => c.aiMarkers.length || c.coAuthors.length).length,
    commits,
  };
}

/**
 * Whether the candidate's first commit is the untouched starter (work before the clock
 * shows here). Compared against every golden commit, since the zip candidates download
 * can lag golden's HEAD.
 */
function starterIntegrity(rootSha) {
  const show = (dir, ref, rel) => {
    const r = spawnSync("git", ["-C", dir, "show", `${ref}:${rel}`], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    return r.status === 0 ? r.stdout : undefined;
  };
  const lsTree = (dir, ref) => (spawnSync("git", ["-C", dir, "ls-tree", "-r", "--name-only", ref], { encoding: "utf8" }).stdout ?? "").split("\n").filter((f) => f && !LOCKFILES.has(path.posix.basename(f)));
  const rootFiles = lsTree(candidateDir, rootSha);
  const goldenRefs = (spawnSync("git", ["-C", goldenDir, "rev-list", "HEAD"], { encoding: "utf8" }).stdout ?? "").split("\n").filter(Boolean).slice(0, 30);
  let best;
  for (const ref of goldenRefs.length ? goldenRefs : ["HEAD"]) {
    const goldenFiles = lsTree(goldenDir, ref);
    const mismatched = goldenFiles.filter((rel) => {
      const theirs = show(candidateDir, rootSha, rel);
      return theirs === undefined || theirs !== show(goldenDir, ref, rel);
    });
    const goldenSet = new Set(goldenFiles);
    const extra = rootFiles.filter((f) => !goldenSet.has(f));
    if (!best || mismatched.length + extra.length < best.mismatched.length + best.extra.length) best = { ref, mismatched, extra };
    if (mismatched.length + extra.length === 0) break;
  }
  return {
    starterRef: best.ref.slice(0, 7),
    rootMatchesStarter: best.mismatched.length === 0 && best.extra.length === 0,
    mismatched: best.mismatched,
    extraFilesInFirstCommit: best.extra.slice(0, 30),
  };
}

// ─── Inventory, docs & detections ────────────────────────────────────────────

const GUIDANCE_PATTERNS = [
  [/(?:^|\/)(?:CLAUDE|AGENTS|GEMINI|AI_WORKFLOW|CONVENTIONS)\.md$/i, "agent instructions"],
  [/(?:^|\/)CONTEXT\.md$/, "context doc"],
  [/^\.claude\//, ".claude config"],
  [/^\.cursor\/|(?:^|\/)\.cursorrules$/, "cursor rules"],
  [/(?:^|\/)\.windsurfrules$|^\.clinerules/, "editor agent rules"],
  [/^\.github\/(?:copilot-instructions\.md|instructions\/|prompts\/|agents\/|chatmodes\/)/, "copilot instructions"],
  [/^\.agents\/|^\.kiro\/|^\.specify\/|^memory-bank\//, "agent workspace"],
  [/^openspec\//, "openspec"],
  [/(?:^|\/)(?:PLAN|SPEC)\.md$|^docs\/plans?\//i, "plans/specs"],
  [/^specs?\/.*\.md$/, "specs"],
];

const ROADMAP_HEADING = /roadmap|future|next steps?|if i had more time|what i(?:'|’)?d do|todo|follow[- ]?ups?|improvements?|enhancements?|production|deferred|out of scope|not (?:yet )?(?:done|implemented|built)|limitations|trade-?offs|known (?:issues|gaps)|what'?s missing|backlog|\bphase\b|planned|assumptions?|decisions?|scal(?:e|ing)/i;
const ROADMAP_FILE = /(?:^|\/)[^/]*(?:roadmap|plan|todo|backlog|next[-_]?steps|notes|discussion)[^/]*\.mdx?$/i;

function markdownDocs(files) {
  const docs = [];
  for (const rel of files.filter((f) => /\.mdx?$/i.test(f))) {
    const text = readText(path.join(snapshotDir, rel));
    if (!text) continue;
    const lines = text.split("\n");
    const headings = lines.flatMap((l, i) => {
      const m = l.match(/^(#{1,4})\s+(.*)$/);
      return m ? [{ level: m[1].length, text: m[2].trim(), line: i + 1 }] : [];
    });
    const roadmapSections = [];
    if (ROADMAP_FILE.test(rel)) {
      roadmapSections.push({ heading: "(whole file)", line: 1, excerpt: lines.slice(0, 150).join("\n"), truncated: lines.length > 150 });
    } else {
      for (const [idx, h] of headings.entries()) {
        if (!ROADMAP_HEADING.test(h.text)) continue;
        const next = headings.slice(idx + 1).find((n) => n.level <= h.level);
        const end = next ? next.line - 1 : lines.length;
        roadmapSections.push({ heading: h.text, line: h.line, excerpt: lines.slice(h.line, Math.min(end, h.line + 60)).join("\n").trim(), truncated: end - h.line > 60 });
      }
    }
    docs.push({ path: rel, lines: lines.length, headings: headings.slice(0, 50), roadmapSections });
  }
  return docs;
}

function packageDiff(workspaces) {
  const diff = (a = {}, b = {}) => ({
    added: Object.fromEntries(Object.entries(b).filter(([k]) => !(k in a))),
    removed: Object.keys(a).filter((k) => !(k in b)),
    changed: Object.fromEntries(Object.entries(b).filter(([k, v]) => k in a && a[k] !== v)),
  });
  const out = {};
  for (const dir of [".", ...workspaces]) {
    const c = readJson(path.join(snapshotDir, dir, "package.json"));
    if (!c) continue;
    const g = readJson(path.join(goldenDir, dir, "package.json")) ?? {};
    out[dir] = {
      dependencies: diff(g.dependencies, c.dependencies),
      devDependencies: diff(g.devDependencies, c.devDependencies),
      scripts: diff(g.scripts, c.scripts),
    };
  }
  return out;
}

function inventory(files) {
  const byKind = {};
  const codeFiles = [];
  for (const rel of files) {
    const kind = classify(rel);
    if (kind === "lockfile") continue;
    const lines = kind === "data" || kind === "asset" ? 0 : lineCount(readText(path.join(snapshotDir, rel)));
    byKind[kind] = byKind[kind] ?? { files: 0, lines: 0 };
    byKind[kind].files += 1;
    byKind[kind].lines += lines;
    if (kind === "code") codeFiles.push({ path: rel, lines });
  }
  codeFiles.sort((a, b) => b.lines - a.lines);
  return {
    byKind,
    largestCodeFiles: codeFiles.slice(0, 12),
    topLevel: [...new Set(files.map((f) => f.split("/")[0]))].sort(),
    codeFiles: codeFiles.map((f) => f.path).sort(),
    testFiles: files.filter((f) => classify(f) === "test"),
  };
}

/**
 * Test files grouped by layer, judged from path and imports: e2e (Playwright/Cypress),
 * api (supertest or HTTP calls against the app), database, component (Testing Library),
 * and unit for the rest.
 */
function testLayers(files) {
  const layers = { unit: [], component: [], api: [], e2e: [], database: [] };
  for (const rel of files.filter((f) => classify(f) === "test")) {
    const text = readText(path.join(snapshotDir, rel)) ?? "";
    const layer = /(?:^|\/)e2e\/|from\s+["']@playwright\/test["']|\bcy\.\w+\(/.test(rel + "\n" + text)
      ? "e2e"
      : /from\s+["'](?:better-sqlite3|sqlite3?|pg|postgres|@prisma\/client|drizzle-orm[^"']*|knex|kysely|mongoose|typeorm)["']|testcontainers/.test(text)
        ? "database"
        : /from\s+["']supertest["']|request\(\s*app\s*\)|\.listen\(|fetch\(\s*[`"']http|createCaller\(|app\.inject\(/.test(text)
          ? "api"
          : /from\s+["']@testing-library\//.test(text)
            ? "component"
            : "unit";
    layers[layer].push(rel);
  }
  const configs = files.filter((f) => /(?:^|\/)(?:playwright|cypress)\.config\.[cm]?[jt]s$/.test(f));
  return {
    counts: Object.fromEntries(Object.entries(layers).map(([k, v]) => [k, v.length])),
    files: Object.fromEntries(Object.entries(layers).map(([k, v]) => [k, v.slice(0, 12)])),
    e2eConfigs: configs,
  };
}

function detections(files, workspaces) {
  const code = files.filter((f) => CODE_EXT.test(f) && !f.endsWith(".d.ts") && !TEST_PATH.test(f) && !/makeBorrowersFile/.test(f));
  const inPkg = (re) => code.filter((f) => re.test(f));
  const clientCode = inPkg(/(?:^|\/)(?:client|web|frontend|app)\//);
  const serverCode = inPkg(/(?:^|\/)(?:server|api|backend)\//);
  const sharedCode = inPkg(/(?:^|\/)shared\//);
  const g = (list, re, limit) => grepFiles(snapshotDir, list, re, limit);
  const guidance = [];
  for (const rel of files) {
    const match = GUIDANCE_PATTERNS.find(([re]) => re.test(rel));
    if (match) guidance.push({ path: rel, kind: match[1], lines: lineCount(readText(path.join(snapshotDir, rel))) });
  }
  const allDeps = new Set();
  for (const dir of [".", ...workspaces]) {
    const pkg = readJson(path.join(snapshotDir, dir, "package.json")) ?? {};
    for (const name of Object.keys({ ...pkg.dependencies, ...pkg.devDependencies })) allDeps.add(name);
  }
  const deps = (re) => [...allDeps].filter((d) => re.test(d)).sort();
  return {
    agentGuidance: { files: guidance, totalLines: guidance.reduce((s, f) => s + f.lines, 0) },
    ci: files.filter((f) => classify(f) === "ci"),
    container: files.filter((f) => /(?:^|\/)(?:Dockerfile[^/]*|docker-compose[^/]*\.ya?ml|compose\.ya?ml|Containerfile)$/.test(f)),
    lintFormat: files.filter((f) => /(?:^|\/)(?:eslint\.config\.[cm]?[jt]s|\.eslintrc[^/]*|\.prettierrc[^/]*|prettier\.config\.[cm]?js|biome\.jsonc?|knip\.jsonc?|\.editorconfig|\.oxlintrc[^/]*|\.husky\/.*|\.vite-hooks\/.*|lefthook\.ya?ml)$/.test(f)),
    envExamples: files.filter((f) => /(?:^|\/)\.env(?:\.[\w-]+)?\.example$|(?:^|\/)\.env\.sample$/.test(f)),
    deploy: files.filter((f) => /(?:^|\/)(?:vercel\.json|netlify\.toml|fly\.toml|render\.ya?ml|railway\.(?:json|toml)|Procfile|app\.ya?ml|nixpacks\.toml|amplify\.ya?ml|serverless\.ya?ml|wrangler\.toml|skaffold\.ya?ml|Chart\.yaml)$|(?:^|\/)(?:k8s|kubernetes|helm|deploy|infra|terraform)\/|\.tf$/.test(f)),
    libraries: {
      styling: deps(/tailwind|shadcn|radix|@mui|@chakra|styled-components|@emotion|mantine|antd|bootstrap|lucide|headlessui|class-variance-authority|clsx/),
      dataFetching: deps(/@tanstack\/react-query|swr|@trpc|apollo|urql|graphql/),
      table: deps(/@tanstack\/react-table|ag-grid|react-table|react-virtual|@tanstack\/react-virtual|react-window/),
      validation: deps(/^zod$|ajv|typebox|valibot|^joi$|^yup$|superstruct/),
      testing: deps(/vitest|jest|@testing-library|playwright|cypress|supertest|msw/),
      ai: deps(/openai|anthropic|@ai-sdk|^ai$|ollama|langchain|@google\/generative-ai|@google\/genai/),
      persistence: deps(/sqlite|better-sqlite3|prisma|drizzle|knex|^pg$|postgres|mongoose|typeorm|kysely|lowdb/),
      lint: deps(/eslint|oxlint|biome|prettier|knip|vite-plus/),
    },
    signals: {
      sharedImportsInClient: g(clientCode, /from\s+["'](?:shared|@[\w-]+\/shared|\.\.\/shared)[^"']*["']/, 8),
      sharedImportsInServer: g(serverCode, /from\s+["'](?:shared|@[\w-]+\/shared|\.\.\/shared)[^"']*["']/, 8),
      fieldTypeMap: g([...sharedCode, ...serverCode, ...clientCode], /(?:FIELD_TYPES|FIELD_CONFIG|fieldTypes|fieldConfig|FIELD_DEFINITIONS|FILTERABLE_FIELDS|OPERATORS_BY|operatorsFor|FieldType\b)/, 10),
      dateParsing: g([...sharedCode, ...serverCode], /new Date\(|Date\.parse|Date\.UTC|dayjs|date-fns|luxon|moment|split\(["']\/["']\)|split\(["']-["']\)/, 10),
      caseHandling: g([...sharedCode, ...serverCode], /toLowerCase\(|toLocaleLowerCase\(|localeCompare|caseSensitive|\/i\b|Intl\.Collator/, 6),
      debounce: g(clientCode, /debounce|useDeferredValue|useDebounce/i, 4),
      requestCancellation: g(clientCode, /AbortController|signal\s*[:,]|ignore\s*=\s*true|cancelled\s*=\s*true|isStale|latestRequest|requestId/, 4),
      urlState: g(clientCode, /URLSearchParams|history\.(?:push|replace)State|useSearchParams|location\.search/, 4),
      pagination: g([...serverCode, ...sharedCode], /\b(?:page(?:Size)?|limit|offset|cursor)\b/, 6),
      sorting: g([...serverCode, ...clientCode], /\bsort(?:By|Borrowers|Direction|Key)?\b|\.sort\(/, 6),
      exportCsv: g([...serverCode, ...clientCode], /\bcsv\b|xlsx|exceljs|text\/csv/i, 4),
      aiCalls: g([...serverCode, ...clientCode], /openai|anthropic|ollama|generateText|chat\.completions|messages\.create|gemini/i, 6),
      requestValidation: g(serverCode, /status\(\s*4\d\d\s*\)|\.parse\(|safeParse|validate\w*\(/, 8),
      // Handlers usually span several lines, so match names and types rather than the full signature.
      errorMiddleware: g(serverCode, /ErrorRequestHandler|function\s+\w*error\w*Handler|\b(?:errorHandler|handleErrors?)\b\s*[=(]|\(\s*err(?:or)?\s*[:,][^)]*,\s*_?req/i, 3),
      healthEndpoint: g(serverCode, /["'`]\/(?:health|healthz|ready|readyz|livez|status)["'`]/, 2),
      gracefulShutdown: g(serverCode, /SIGTERM|SIGINT|server\.close\(/, 2),
      securityMiddleware: g(serverCode, /\bhelmet\b|express-rate-limit|rateLimit\(|cors\(\s*\{|json\(\s*\{[^}]*limit/, 4),
      envConfig: g([...serverCode, ...clientCode], /process\.env\.[A-Z_]+|import\.meta\.env\.[A-Z_]+/, 4),
      errorBoundary: g(clientCode, /ErrorBoundary|componentDidCatch|getDerivedStateFromError/, 2),
      piiHandling: g([...serverCode, ...clientCode, ...sharedCode], /\bpii\b|redact|mask(?:ed|ing)?\b|sanitiz/i, 4),
      logging: g(serverCode, /from\s+["'](?:pino|winston|bunyan|pino-http|morgan)["']|requestLogger/, 3),
      caching: g(serverCode, /\bcache\b|lru|memoize|Map<string,/i, 4),
    },
    testLayers: testLayers(files),
    styleLines: files.filter((f) => STYLE_EXT.test(f)).reduce((s, f) => s + lineCount(readText(path.join(snapshotDir, f))), 0),
  };
}

// ─── Main ────────────────────────────────────────────────────────────────────

function remoteInfo() {
  const r = run("git", ["-C", candidateDir, "remote", "get-url", "origin"]);
  const url = r.stdout.trim();
  const m = url.match(/github\.com[/:]([^/]+)\/(.+?)(?:\.git)?$/);
  return { url: url || undefined, githubBase: m ? `https://github.com/${m[1]}/${m[2]}` : undefined };
}

function printSummary(facts) {
  const { history: h, dataset, ports } = facts;
  console.log(`candidate   ${facts.candidate.displayName} (${facts.candidate.slug}) @ ${facts.candidate.headShort}`);
  console.log(`install     ${facts.environment.install.performed ? facts.environment.install.command : facts.environment.install.reason}`);
  for (const c of facts.checks) console.log(`check       ${c.script.padEnd(10)} ${c.passed ? "pass" : `FAIL (exit ${c.exitCode})`}${c.summary ? `  ${c.summary.passed}/${c.summary.total} tests` : ""}  [${c.where.join(", ")}]`);
  if (facts.checks.length === 0) console.log("check       (no typecheck/lint/build/test scripts)");
  console.log(`dataset     ${dataset.file ?? "NOT FOUND"} · ${dataset.count ?? "?"} borrowers${dataset.sameAsStarter ? " (starter data)" : " (changed from starter)"}`);
  console.log(`ports       server ${ports.server} (${ports.serverSource}) · client ${ports.client} (${ports.clientSource})`);
  console.log(`history     ${h.commitCount} commits over ${h.elapsedMinutes} min${h.commitsPastTimeBox ? ` · ${h.commitsPastTimeBox} past the 2h box` : ""}${h.timestampsLookRewritten ? " · ⚠ timestamps look rewritten" : ""}`);
  console.log(`facts       ${factsPath}`);
}

function main() {
  if (!fs.existsSync(path.join(candidateDir, ".git"))) die(`${candidateDir} is not a git repository`);
  if (!goldenDir) die(`no golden/ beside ${candidateDir}; pass --golden <dir> or ${SETUP_HINT}`, EXIT_SETUP);
  for (const f of ["packages/server/index.ts", "packages/shared/index.ts", "packages/server/borrowers.json", "package.json"]) {
    if (!fs.existsSync(path.join(goldenDir, f))) die(`golden repo at ${goldenDir} is missing ${f}`);
  }

  fs.mkdirSync(logsDir, { recursive: true });
  const sha = git("rev-parse", args.ref ?? "HEAD").trim();
  const rootSha = git("rev-list", "--max-parents=0", sha).trim().split("\n").pop();

  const { snapshot, install: installed } = prepareSnapshot(sha);
  const pm = installed.pm;
  const files = walk(snapshotDir);
  const workspaces = workspaceDirs();
  const checks = runCandidateChecks(pm, workspaces);

  const history = collectHistory(sha);
  // Review folders are named after the candidate; git author names are sometimes handles.
  const displayName = candidateSlug.split(/[-_]/).map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
  const gitAuthor = history.commits.slice(1).map((c) => c.author).find(Boolean) ?? history.commits[0]?.author;

  const facts = {
    schema: 1,
    collectedAt: new Date().toISOString(),
    candidate: { slug: candidateSlug, displayName, gitAuthor, dir: candidateDir, ref: args.ref ?? "HEAD", headSha: sha, headShort: sha.slice(0, 7), rootSha, remote: remoteInfo() },
    paths: { outDir, snapshotDir, goldenDir, factsPath },
    environment: { node: process.version, nvmrc: readText(path.join(snapshotDir, ".nvmrc"))?.trim(), packageManager: pm, install: installed },
    snapshot,
    workspaces,
    starter: starterIntegrity(rootSha),
    checks,
    dataset: datasetFacts(files),
    ports: portFacts(files),
    start: startFacts(pm, workspaces),
    history,
    inventory: inventory(files),
    packageDiff: packageDiff(workspaces),
    docs: markdownDocs(files),
    detections: detections(files, workspaces),
  };
  // Keep a probe result from an earlier run of the same commit; probe.mjs owns that key.
  const previous = readJson(factsPath);
  if (previous?.probe && previous.candidate?.headSha === sha) facts.probe = previous.probe;
  fs.writeFileSync(factsPath, JSON.stringify(facts, null, 2));
  printSummary(facts);
}

main();
