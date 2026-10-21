#!/usr/bin/env node
/**
 * Intake for a new submission: work out the candidate's name, clone their repo into the
 * interviews directory as <first-last>, and open it in the editor.
 *
 *   node intake.mjs <git-url> [--name "First Last"] [--root <dir>] [--no-open] [--dry-run]
 *
 * The interviews folder comes from --root, $FILTERS_INTERVIEWS, or the current
 * directory (or its parent) when it holds golden/; see paths.mjs.
 *
 * Name resolution, in order:
 *   1. --name
 *   2. the calendar: the "<Name> // … Filters …" event nearest now (upcoming Review
 *      first), read through a weekly-report skill's cal-events.py when one is installed
 *   3. the repo owner's GitHub profile name (gh api)
 * When the calendar and GitHub names share no word, `nameMismatch` is set so the caller
 * can confirm before reviewing the wrong person's repo.
 *
 * Prints one JSON object to stdout. Exit 3 = no name found (pass --name); exit 4 = the
 * target directory exists with a different remote; exit 5 = no interviews folder with
 * golden/ (see AGENTS.md); exit 2 = anything else.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { EXIT_SETUP, ROOT_ENV, SETUP_HINT, findInterviewsRoot, hasGolden } from "./paths.mjs";

const CAL_SCRIPT = path.join(os.homedir(), ".claude/skills/weekly-report/scripts/cal-events.py");
const AGENT_SKILLS_CONFIG = path.join(os.homedir(), ".claude/agent-skills.json");
const EVENT_TITLE = /^\s*(.+?)\s*\/\/\s*(?:[\w ]*?\s)?Filters\b(.*)$/i;
const WINDOW_BEFORE_MS = 4 * 3600_000;
const WINDOW_AFTER_MS = 3 * 3600_000;

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--")) args._.push(a);
    else if (["--no-open", "--dry-run"].includes(a)) args[a.slice(2)] = true;
    else args[a.slice(2)] = argv[++i];
  }
  return args;
}

function fail(code, message, extra = {}) {
  console.log(JSON.stringify({ ok: false, error: message, ...extra }, null, 2));
  process.exit(code);
}

function run(cmd, cmdArgs, opts = {}) {
  const r = spawnSync(cmd, cmdArgs, { encoding: "utf8", timeout: 60_000, ...opts });
  return { code: r.status ?? 1, stdout: r.stdout ?? "", stderr: r.stderr ?? "" };
}

/** owner/repo from https, ssh or scp-style GitHub URLs. */
function parseRepo(url) {
  const m = url.trim().match(/github\.com[/:]([^/]+)\/([^/]+?)(?:\.git)?\/?$/);
  return m ? { owner: m[1], repo: m[2], canonical: `https://github.com/${m[1]}/${m[2]}` } : undefined;
}

function slugify(name) {
  return name
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/** The interview event nearest now: an upcoming (or just-started) Review wins, else the closest match in the window. */
function nameFromCalendar(now) {
  if (!fs.existsSync(CAL_SCRIPT)) return { skipped: `calendar script not found at ${CAL_SCRIPT}` };
  const day = (offsetDays) => new Date(now + offsetDays * 86400_000).toISOString().slice(0, 10);
  const r = run("python3", [CAL_SCRIPT, "--since", day(-1), "--until", day(2), "--format", "json", "--include-recurring"]);
  if (r.code !== 0) return { skipped: `calendar lookup failed: ${r.stderr.trim().split("\n").pop()}` };
  const events = r.stdout
    .split("\n")
    .filter((l) => l.trim())
    .map((l) => JSON.parse(l))
    .map((e) => ({ ...e, match: e.title.match(EVENT_TITLE), startMs: Date.parse(e.start) }))
    .filter((e) => e.match && e.startMs >= now - WINDOW_BEFORE_MS && e.startMs <= now + WINDOW_AFTER_MS);
  if (events.length === 0) return { skipped: "no '<Name> // … Filters' event within the last 4h or next 3h" };
  const upcomingReviews = events
    .filter((e) => /review/i.test(e.match[2]) && e.startMs >= now - 30 * 60_000)
    .sort((a, b) => a.startMs - b.startMs);
  const pick = upcomingReviews[0] ?? [...events].sort((a, b) => Math.abs(a.startMs - now) - Math.abs(b.startMs - now))[0];
  return { name: pick.match[1], event: { title: pick.title, start: pick.start } };
}

function nameFromGitHub(owner) {
  const r = run("gh", ["api", `users/${owner}`, "--jq", ".name // empty"], { timeout: 20_000 });
  return r.code === 0 && r.stdout.trim() ? r.stdout.trim() : undefined;
}

function editorCommand() {
  try {
    return JSON.parse(fs.readFileSync(AGENT_SKILLS_CONFIG, "utf8")).editor_command || "code";
  } catch {
    return "code";
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const url = args._[0];
  if (!url) fail(2, "usage: intake.mjs <git-url> [--name \"First Last\"] [--root <dir>] [--no-open] [--dry-run]");
  const repo = parseRepo(url);
  const root = findInterviewsRoot(args.root);
  if (!root) fail(EXIT_SETUP, `no interviews folder: pass --root, set ${ROOT_ENV}, or run from the folder that holds golden/; ${SETUP_HINT}`);
  if (!hasGolden(root)) fail(EXIT_SETUP, `${root} has no golden/ checkout; ${SETUP_HINT}`);

  const now = Date.now();
  const calendar = args.name ? { skipped: "--name given" } : nameFromCalendar(now);
  const githubName = repo ? nameFromGitHub(repo.owner) : undefined;
  const name = args.name ?? calendar.name ?? githubName;
  const nameSource = args.name ? "--name" : calendar.name ? "calendar" : githubName ? "github" : undefined;
  if (!name) fail(3, "could not determine the candidate's name; pass --name \"First Last\"", { calendar: calendar.skipped });

  const words = (s) => new Set(slugify(s ?? "").split("-").filter(Boolean));
  const nameMismatch =
    nameSource === "calendar" && githubName !== undefined && ![...words(name)].some((w) => words(githubName).has(w));

  const slug = slugify(name);
  const dir = path.join(root, slug);
  const result = {
    ok: true,
    name,
    slug,
    dir,
    nameSource,
    event: calendar.event,
    calendarNote: calendar.skipped,
    githubName,
    nameMismatch,
    repo: repo?.canonical ?? url,
  };

  if (args["dry-run"]) {
    console.log(JSON.stringify({ ...result, dryRun: true }, null, 2));
    return;
  }

  if (fs.existsSync(dir)) {
    const origin = run("git", ["-C", dir, "remote", "get-url", "origin"]).stdout.trim();
    const same = repo && parseRepo(origin)?.canonical.toLowerCase() === repo.canonical.toLowerCase();
    if (!same) fail(4, `${dir} already exists with a different remote (${origin || "none"})`, result);
    const pull = run("git", ["-C", dir, "pull", "--ff-only"], { timeout: 120_000 });
    if (pull.code !== 0) fail(2, `git pull failed in ${dir}: ${pull.stderr.trim()}`, result);
    result.clone = "updated existing clone";
  } else {
    const clone = run("git", ["clone", url, dir], { timeout: 300_000 });
    if (clone.code !== 0) fail(2, `git clone failed: ${clone.stderr.trim()}`, result);
    result.clone = "cloned";
  }

  if (!args["no-open"]) {
    const editor = editorCommand();
    const opened = spawnSync(editor, [dir], { stdio: "ignore", timeout: 30_000 });
    result.opened = opened.status === 0 ? `${editor} ${dir}` : `failed to run ${editor} (open it yourself)`;
  }
  console.log(JSON.stringify(result, null, 2));
}

main();
