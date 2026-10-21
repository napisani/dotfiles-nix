#!/usr/bin/env node
/**
 * Runs the candidate's app from the review snapshot on free ports.
 *
 *   node app.mjs start <outDir> [--server-only]   start, wait until listening, print JSON
 *   node app.mjs stop <outDir>                    stop it and restore patched files
 *   node app.mjs status <outDir>
 *
 * Their hard-coded ports (facts.ports, or `ports` in <outDir>/probe/adapter.mjs) are
 * rewritten to free ones inside the snapshot only, so a review never collides with
 * another review or with a dev server the reviewer already has open. Originals are
 * backed up under <outDir>/run/ and put back by `stop` (and by the next collect.mjs run
 * if a stop was missed). Start commands come from facts.start, overridable via `start`
 * in the adapter. The server runs with TZ=America/New_York (see SERVER_TZ).
 */
import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { pathToFileURL } from "node:url";

// A negative UTC offset surfaces the classic off-by-one from parsing "YYYY-MM-DD" as UTC
// but "M/D/YYYY" as local time; in UTC both parse alike and the bug hides.
const SERVER_TZ = "America/New_York";
const CODE_OR_CONFIG = /\.(?:[cm]?[jt]sx?|json|html)$|(?:^|\/)\.env[^/]*$/;
const SKIP = /(?:^|\/)(?:node_modules|\.git|dist|build|coverage)\/|(?:^|\/)borrowers[^/]*\.json$|(?:package-lock|pnpm-lock|npm-shrinkwrap)\.json$|\.(?:test|spec)\.[cm]?[jt]sx?$|(?:^|\/)(?:test|tests|__tests__|e2e)\//;
const READY_TIMEOUT_MS = 120_000;

const runDir = (outDir) => path.join(outDir, "run");
const statePath = (outDir) => path.join(runDir(outDir), "state.json");
const patchesPath = (outDir) => path.join(runDir(outDir), "patched.json");

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return undefined;
  }
}

/** Puts back every snapshot file a previous start rewrote. Safe to call when nothing is patched. */
export function restorePatches(outDir) {
  const patched = readJson(patchesPath(outDir));
  if (!patched) return [];
  const snapshotDir = path.join(outDir, "snapshot");
  for (const rel of patched.files) {
    const backup = path.join(runDir(outDir), "backup", rel);
    if (fs.existsSync(backup)) fs.copyFileSync(backup, path.join(snapshotDir, rel));
  }
  fs.rmSync(path.join(runDir(outDir), "backup"), { recursive: true, force: true });
  fs.rmSync(patchesPath(outDir), { force: true });
  return patched.files;
}

function walk(root, rel = "") {
  const out = [];
  for (const entry of fs.readdirSync(path.join(root, rel), { withFileTypes: true })) {
    const relPath = rel ? `${rel}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      if (!["node_modules", ".git", "dist", "build", "coverage"].includes(entry.name)) out.push(...walk(root, relPath));
    } else if (entry.isFile()) {
      out.push(relPath);
    }
  }
  return out;
}

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on("error", reject);
    srv.listen(0, "127.0.0.1", () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
}

function connects(port, host) {
  return new Promise((resolve) => {
    const sock = net.connect({ port, host });
    sock.once("connect", () => {
      sock.destroy();
      resolve(true);
    });
    sock.once("error", () => resolve(false));
    sock.setTimeout(1000, () => {
      sock.destroy();
      resolve(false);
    });
  });
}

/** The loopback address answering on port ("localhost" can bind either family), or undefined. */
async function listeningHost(port) {
  for (const host of ["127.0.0.1", "::1"]) if (await connects(port, host)) return host;
  return undefined;
}

async function waitForPort(port, child, logFile) {
  const deadline = Date.now() + READY_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const host = await listeningHost(port);
    if (host) return host.includes(":") ? `http://[${host}]:${port}` : `http://${host}:${port}`;
    if (child.exitCode !== null) throw new Error(`process exited (code ${child.exitCode}) before listening on ${port}; see ${logFile}`);
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`nothing listening on ${port} after ${READY_TIMEOUT_MS / 1000}s; see ${logFile}`);
}

/** Rewrites each original port to its replacement across the snapshot's code and config. */
function patchPorts(outDir, portMap) {
  restorePatches(outDir);
  const snapshotDir = path.join(outDir, "snapshot");
  const files = [];
  for (const rel of walk(snapshotDir)) {
    if (!CODE_OR_CONFIG.test(rel) || SKIP.test(rel)) continue;
    const abs = path.join(snapshotDir, rel);
    const text = fs.readFileSync(abs, "utf8");
    let next = text;
    for (const [from, to] of Object.entries(portMap)) next = next.replace(new RegExp(`(?<![\\d.])${from}(?!\\d)`, "g"), String(to));
    if (next === text) continue;
    const backup = path.join(runDir(outDir), "backup", rel);
    fs.mkdirSync(path.dirname(backup), { recursive: true });
    fs.copyFileSync(abs, backup);
    fs.writeFileSync(abs, next);
    files.push(rel);
  }
  fs.writeFileSync(patchesPath(outDir), JSON.stringify({ portMap, files }, null, 2));
  return files;
}

async function loadAdapter(outDir) {
  const file = path.join(outDir, "probe", "adapter.mjs");
  if (!fs.existsSync(file)) return {};
  return import(`${pathToFileURL(file).href}?t=${Date.now()}`);
}

function launch(command, { cwd, env, logFile }) {
  const log = fs.openSync(logFile, "w");
  fs.writeSync(log, `$ ${command}\n# cwd: ${cwd}\n\n`);
  const child = spawn("bash", ["-lc", command], { cwd, env: { ...process.env, ...env }, detached: true, stdio: ["ignore", log, log] });
  child.unref();
  return child;
}

function killGroup(pid, signal) {
  try {
    process.kill(-pid, signal);
    return true;
  } catch {
    return false;
  }
}

function alive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

export function appStatus(outDir) {
  const state = readJson(statePath(outDir));
  if (!state) return { running: false };
  const running = [state.server?.pid, state.client?.pid].filter(Boolean).some(alive);
  return { running, ...state };
}

/** Starts the server (and the client unless serverOnly); reuses an already-running app. */
export async function startApp(outDir, { serverOnly = false } = {}) {
  const current = appStatus(outDir);
  if (current.running && (serverOnly || current.client)) return { ...current, reused: true };
  if (current.running) await stopApp(outDir);

  const facts = readJson(path.join(outDir, "facts.json"));
  if (!facts) throw new Error(`no facts.json in ${outDir}; run collect.mjs first`);
  const adapter = await loadAdapter(outDir);
  const ports = { ...facts.ports, ...adapter.ports };
  const start = { ...facts.start, ...adapter.start };
  const snapshotDir = facts.paths.snapshotDir;
  fs.mkdirSync(runDir(outDir), { recursive: true });
  const logs = path.join(outDir, "logs");
  fs.mkdirSync(logs, { recursive: true });

  const serverPort = await freePort();
  let clientPort = await freePort();
  while (clientPort === serverPort) clientPort = await freePort();
  const portMap = { [ports.server]: serverPort, [ports.client]: clientPort };
  const patchedFiles = patchPorts(outDir, portMap);

  const state = { startedAt: new Date().toISOString(), portMap, patchedFiles, tz: SERVER_TZ };
  const env = { TZ: SERVER_TZ, BROWSER: "none", FORCE_COLOR: "0" };
  try {
    const separate = start.server && (serverOnly || start.client);
    if (separate) {
      const logFile = path.join(logs, "app-server.log");
      const child = launch(start.server, { cwd: snapshotDir, env: { ...env, PORT: String(serverPort) }, logFile });
      state.server = { pid: child.pid, port: serverPort, url: `http://localhost:${serverPort}`, command: start.server, log: logFile };
      fs.writeFileSync(statePath(outDir), JSON.stringify(state, null, 2));
      state.server.baseUrl = await waitForPort(serverPort, child, logFile);
      fs.writeFileSync(statePath(outDir), JSON.stringify(state, null, 2));
      if (!serverOnly) {
        const clientLog = path.join(logs, "app-client.log");
        const clientChild = launch(start.client, { cwd: snapshotDir, env, logFile: clientLog });
        state.client = { pid: clientChild.pid, port: clientPort, url: `http://localhost:${clientPort}`, command: start.client, log: clientLog };
        fs.writeFileSync(statePath(outDir), JSON.stringify(state, null, 2));
        await waitForPort(clientPort, clientChild, clientLog);
      }
    } else {
      const command = start.both ?? start.server;
      if (!command) throw new Error("no start command found; set `start` in the adapter (see references/adapter.md)");
      const logFile = path.join(logs, "app.log");
      const child = launch(command, { cwd: snapshotDir, env, logFile });
      state.server = { pid: child.pid, port: serverPort, url: `http://localhost:${serverPort}`, command, log: logFile };
      if (!serverOnly) state.client = { pid: child.pid, port: clientPort, url: `http://localhost:${clientPort}`, command, log: logFile };
      fs.writeFileSync(statePath(outDir), JSON.stringify(state, null, 2));
      state.server.baseUrl = await waitForPort(serverPort, child, logFile);
      if (!serverOnly) await waitForPort(clientPort, child, logFile);
      fs.writeFileSync(statePath(outDir), JSON.stringify(state, null, 2));
    }
  } catch (err) {
    await stopApp(outDir);
    throw err;
  }
  return { running: true, ...state };
}

export async function stopApp(outDir) {
  const state = readJson(statePath(outDir));
  const pids = [...new Set([state?.server?.pid, state?.client?.pid].filter(Boolean))];
  for (const pid of pids) killGroup(pid, "SIGTERM");
  const deadline = Date.now() + 5000;
  while (pids.some(alive) && Date.now() < deadline) await new Promise((r) => setTimeout(r, 200));
  for (const pid of pids) if (alive(pid)) killGroup(pid, "SIGKILL");
  // Dev servers sometimes outlive their group (nodemon, vite); free the ports explicitly.
  for (const port of [state?.server?.port, state?.client?.port].filter(Boolean)) {
    const r = spawnSync("lsof", ["-ti", `tcp:${port}`, "-sTCP:LISTEN"], { encoding: "utf8" });
    for (const pid of (r.stdout ?? "").split("\n").filter(Boolean)) {
      try {
        process.kill(Number(pid), "SIGKILL");
      } catch {}
    }
  }
  const restored = restorePatches(outDir);
  fs.rmSync(statePath(outDir), { force: true });
  return { stopped: pids.length > 0, restored };
}

async function main() {
  const [command, outArg, ...rest] = process.argv.slice(2);
  if (!command || !outArg) {
    console.error("usage: app.mjs start|stop|status <outDir> [--server-only]");
    process.exit(2);
  }
  const outDir = path.resolve(outArg);
  try {
    let result;
    if (command === "start") result = await startApp(outDir, { serverOnly: rest.includes("--server-only") });
    else if (command === "stop") result = await stopApp(outDir);
    else if (command === "status") result = appStatus(outDir);
    else throw new Error(`unknown command ${command}`);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    console.log(JSON.stringify({ ok: false, error: err.message }, null, 2));
    process.exit(1);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) main();
