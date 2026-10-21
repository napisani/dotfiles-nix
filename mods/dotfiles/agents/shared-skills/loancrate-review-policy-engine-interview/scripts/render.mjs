#!/usr/bin/env node
/**
 * Renders the interviewer brief from <outDir>/facts.json + <outDir>/review.json into
 * <outDir>/review.html.
 *
 *   node render.mjs <outDir>
 *
 * Validates review.json against references/schemas.md (including the one-line length
 * limits) and exits 1 listing every problem. The headline is computed here (gate +
 * signals + red flags) so it is consistent run to run; review.json can override it only
 * with a written reason. Code snippets are read from the snapshot of the reviewed commit,
 * so they always match the cited lines.
 */
import fs from "node:fs";
import path from "node:path";

const SIGNALS = [
  ["generic-engine", "Generic recursive engine"],
  ["extensible-dispatch", "Extension points"],
  ["organized-for-growth", "Organized for growth"],
  ["rules-as-data", "Rules externalizable"],
  ["rule-versioning", "Rule versioning"],
  ["api-hardening", "API boundary hardening"],
  ["tests-beyond", "Own test investment"],
  ["ci-cd", "CI/CD"],
  ["deployable", "Deployable"],
  ["observability", "Observability"],
  ["domain-depth", "Domain depth"],
  ["roadmap", "Roadmap written"],
  ["roadmap-execution", "Executed on plan"],
  ["agent-guidance", "Agent guidance in repo"],
  ["iteration-visible", "Visible iteration"],
  ["docs", "Docs for humans"],
];
const SIGNAL_LABEL = Object.fromEntries(SIGNALS);
const RED_FLAGS = new Set(["nothing-beyond-core", "messy-organization", "hardcoded-engine", "missing-basics-unplanned", "broken-own-checks"]);
const HEADLINES = {
  rocket3: { mark: "🚀🚀🚀", label: "Triple rocket", line: "Above and beyond, across the board", scale: [4] },
  rocket2: { mark: "🚀🚀", label: "Double rocket", line: "Strong yes territory", scale: [4] },
  rocket1: { mark: "🚀", label: "Rocket", line: "Beyond the bar — the Q&A decides 3 or 4", scale: [3, 4] },
  yes: { mark: "👍", label: "Yes", line: "Meets the bar", scale: [3] },
  qualified: { mark: "🤔", label: "Qualified", line: "Passes, with a real concern — hinges on Q&A", scale: [2, 3] },
  no: { mark: "👎", label: "No", line: "Core tests fail", scale: [1, 2] },
};
const SCALE = [
  [1, "strong no"],
  [2, "no"],
  [3, "yes"],
  [4, "strong yes"],
];
/** Signal-score floors for 🚀, 🚀🚀 and 🚀🚀🚀 once the gate passes with no red flags. */
const ROCKET_TIERS = [0.6, 0.75, 0.9];
const MAX_STARS = 3;
const ONE_LINE = 120;
const SENTENCES = 320;
const SNIPPET_MAX_LINES = 20;
const INPUT_MAX_LINES = 24;
const CHALLENGE_WORDS = { design: "pushes on a design choice", gap: "points at a gap", detail: "small fix" };

// ─── Load & validate ─────────────────────────────────────────────────────────

const outDir = path.resolve(process.argv[2] ?? ".");
const facts = JSON.parse(fs.readFileSync(path.join(outDir, "facts.json"), "utf8"));
const review = JSON.parse(fs.readFileSync(path.join(outDir, "review.json"), "utf8"));
const snapshotDir = facts.paths.snapshotDir;
const problems = [];
const warnings = [];

const fileLines = new Map();
function linesOf(file) {
  if (!fileLines.has(file)) {
    const abs = path.join(snapshotDir, file);
    fileLines.set(file, fs.existsSync(abs) ? fs.readFileSync(abs, "utf8").split("\n") : undefined);
  }
  return fileLines.get(file);
}

function checkRef(ref, where) {
  if (!ref) return;
  if (typeof ref.file !== "string") return problems.push(`${where}: ref.file missing`);
  const lines = linesOf(ref.file);
  if (!lines) return problems.push(`${where}: ${ref.file} does not exist in the snapshot`);
  if (ref.start === undefined) return;
  if (!(ref.start >= 1) || !(ref.end >= ref.start)) problems.push(`${where}: bad line range ${ref.start}-${ref.end}`);
  if (ref.end > lines.length) warnings.push(`${where}: ${ref.file} has ${lines.length} lines; end ${ref.end} clamped`);
}

function checkText(text, where, max) {
  if (!text) return problems.push(`${where}: missing`);
  if (String(text).length > max) problems.push(`${where}: ${String(text).length} chars, limit ${max} — tighten it`);
}

const signalIds = new Set(SIGNALS.map(([id]) => id));
const seen = new Set();
for (const s of review.signals ?? []) {
  if (!signalIds.has(s.id)) problems.push(`signals: unknown id "${s.id}"`);
  if (seen.has(s.id)) problems.push(`signals: duplicate id "${s.id}"`);
  seen.add(s.id);
  if (!["yes", "partial", "no"].includes(s.status)) problems.push(`signals.${s.id}: bad status "${s.status}"`);
  if (s.star && s.status !== "yes") problems.push(`signals.${s.id}: only "yes" signals can be starred`);
  checkText(s.evidence, `signals.${s.id}.evidence`, ONE_LINE);
  checkRef(s.ref, `signals.${s.id}`);
}
for (const [id] of SIGNALS) if (!seen.has(id)) problems.push(`signals: missing "${id}"`);
const starCount = (review.signals ?? []).filter((s) => s.star).length;
if (starCount > MAX_STARS) problems.push(`signals: ${starCount} stars; at most ${MAX_STARS}`);

for (const [i, c] of (review.concerns ?? []).entries()) {
  if (!["red-flag", "watch"].includes(c.severity)) problems.push(`concerns[${i}]: bad severity`);
  if (c.severity === "red-flag" && !RED_FLAGS.has(c.flag)) problems.push(`concerns[${i}]: red-flag needs a known flag id`);
  checkText(c.text, `concerns[${i}].text`, ONE_LINE);
  checkRef(c.ref, `concerns[${i}]`);
}

const challenge = review.challenge;
if (!challenge || Array.isArray(challenge)) {
  problems.push("challenge: expected exactly one challenge object");
} else {
  checkText(challenge.title, "challenge.title", 100);
  checkText(challenge.intent, "challenge.intent", ONE_LINE);
  checkText(challenge.cause, "challenge.cause", 160);
  checkText(challenge.ask, "challenge.ask", 240);
  if (/if this were a pr/i.test(challenge.ask ?? "")) problems.push('challenge.ask: drop the "If this were a PR" preamble; ask about the example directly');
  checkText(challenge.why, "challenge.why", SENTENCES);
  const example = challenge.example;
  if (!example || typeof example !== "object") {
    problems.push("challenge.example: missing (a `given` situation, the whole `input`, and 1–3 `rows`)");
  } else {
    checkText(example.given, "challenge.example.given", ONE_LINE);
    const input = example.input;
    if (!input || typeof input.code !== "string" || !input.code.trim()) {
      problems.push("challenge.example.input: missing; give the whole, realistic input the reviewer can paste (e.g. the POST /evaluate body)");
    } else {
      const inputLines = input.code.split("\n").length;
      if (inputLines > INPUT_MAX_LINES) problems.push(`challenge.example.input: ${inputLines} lines, limit ${INPUT_MAX_LINES}; drop fields that don't matter, keep it valid`);
      if (input.label !== undefined) checkText(input.label, "challenge.example.input.label", 60);
      if ((input.lang ?? "json") === "json") {
        try {
          JSON.parse(input.code);
        } catch (err) {
          problems.push(`challenge.example.input: not valid JSON (${err.message}); it has to paste as-is`);
        }
      }
      for (const n of input.hl ?? []) {
        if (!Number.isInteger(n) || n < 1 || n > inputLines) problems.push(`challenge.example.input.hl: line ${n} is outside 1–${inputLines}`);
      }
    }
    if (!Array.isArray(example.rows) || example.rows.length < 1 || example.rows.length > 3) problems.push("challenge.example: needs 1–3 rows");
    for (const [j, row] of (example.rows ?? []).entries()) {
      const where = `challenge.example.rows[${j}]`;
      checkText(row.label, `${where}.label`, 60);
      checkText(row.code, `${where}.code`, 240);
      if (String(row.code ?? "").split("\n").length > 3) problems.push(`${where}.code: more than 3 lines; show the smallest case`);
      checkText(row.result, `${where}.result`, 80);
      if (typeof row.ok !== "boolean") problems.push(`${where}.ok: true when the outcome matches their intent, false for the gap`);
    }
  }
  if (!Array.isArray(challenge.goodAnswers) || challenge.goodAnswers.length < 1 || challenge.goodAnswers.length > 3) {
    problems.push("challenge: needs 1–3 goodAnswers");
  }
  for (const [j, a] of (challenge.goodAnswers ?? []).entries()) checkText(a, `challenge.goodAnswers[${j}]`, 200);
  if (!Array.isArray(challenge.refs) || challenge.refs.length < 1 || challenge.refs.length > 3) problems.push("challenge: needs 1–3 refs");
  for (const [j, r] of (challenge.refs ?? []).entries()) {
    checkRef(r, `challenge.refs[${j}]`);
    if (r.start === undefined) problems.push(`challenge.refs[${j}]: snippet refs need start/end`);
    else if (r.end - r.start + 1 > SNIPPET_MAX_LINES) problems.push(`challenge.refs[${j}]: ${r.end - r.start + 1} lines; cut it to ${SNIPPET_MAX_LINES} around the point`);
    for (const n of r.hl ?? []) {
      if (!Number.isInteger(n) || n < r.start || n > r.end) problems.push(`challenge.refs[${j}].hl: line ${n} is outside ${r.start}–${r.end}`);
    }
  }
  if (challenge.signal && !signalIds.has(challenge.signal)) problems.push(`challenge.signal: unknown id "${challenge.signal}"`);
}

const bullets = review.externalization?.bullets ?? [];
if (!review.externalization) problems.push("externalization: missing");
if (bullets.length > 4) problems.push(`externalization.bullets: ${bullets.length}; at most 4`);
for (const [i, b] of bullets.entries()) {
  if (!["has", "missing"].includes(b.kind)) problems.push(`externalization.bullets[${i}]: kind must be has|missing`);
  checkText(b.text, `externalization.bullets[${i}].text`, ONE_LINE);
  checkRef(b.ref, `externalization.bullets[${i}]`);
}
for (const [i, it] of (review.roadmap?.items ?? []).entries()) {
  if (!["done", "partial", "planned"].includes(it.status)) problems.push(`roadmap.items[${i}]: bad status`);
  checkText(`${it.item} — ${it.note ?? ""}`, `roadmap.items[${i}]`, ONE_LINE + 20);
}
if ((review.roadmap?.items ?? []).length > 8) problems.push("roadmap.items: at most 8");
if (review.flow) {
  const ids = new Set((review.flow.participants ?? []).map((p) => p.id));
  if (ids.size < 2 || ids.size > 8) problems.push(`flow.participants: expected 2–8, got ${ids.size}`);
  for (const [i, p] of (review.flow.participants ?? []).entries()) {
    if ((p.label ?? "").length > 16) problems.push(`flow.participants[${i}].label: over 16 chars won't fit the box`);
    if ((p.sub ?? "").length > 19) problems.push(`flow.participants[${i}].sub: over 19 chars won't fit the box`);
  }
  let depth = 0;
  for (const [i, s] of (review.flow.steps ?? []).entries()) {
    if (s.kind === "loop-start") depth += 1;
    else if (s.kind === "loop-end") depth -= 1;
    else if (!ids.has(s.from) || !ids.has(s.to)) problems.push(`flow.steps[${i}]: unknown participant`);
    if (depth < 0) problems.push(`flow.steps[${i}]: loop-end without loop-start`);
  }
  if (depth !== 0) problems.push("flow.steps: unclosed loop");
}
if ((review.focusAreas ?? []).length > 4) problems.push("focusAreas: at most 4");
for (const [i, f] of (review.focusAreas ?? []).entries()) checkText(`${f.area} ${f.text}`, `focusAreas[${i}]`, ONE_LINE);
checkText(review.verdict?.summary, "verdict.summary", SENTENCES);
for (const key of ["aiUsage", "agentGuidance", "iteration"]) checkText(review[key]?.summary, `${key}.summary`, SENTENCES);
if (review.roadmap) checkText(review.roadmap.summary, "roadmap.summary", SENTENCES);
if (review.verdict?.override && !(review.verdict.override.headline in HEADLINES)) {
  problems.push(`verdict.override.headline: must be one of ${Object.keys(HEADLINES).join(", ")}`);
}
if (facts.gate.harnessSuspect && !review.verdict?.override) {
  problems.push("gate.harnessSuspect is set: fix the review harness and re-run `collect.mjs --gate-only`, or override the verdict with a reason");
}

for (const w of warnings) console.error(`warning: ${w}`);
if (problems.length) {
  console.error(`review.json has ${problems.length} problem(s):\n- ${problems.join("\n- ")}`);
  process.exit(1);
}

// ─── Verdict ─────────────────────────────────────────────────────────────────

const statusWeight = { yes: 1, partial: 0.5, no: 0 };
const signalPoints = review.signals.reduce((sum, s) => sum + statusWeight[s.status], 0);
const signalRatio = signalPoints / SIGNALS.length;
const redFlags = (review.concerns ?? []).filter((c) => c.severity === "red-flag");
const rockets = ROCKET_TIERS.filter((floor) => signalRatio >= floor).length;
const computed = !facts.gate.passed ? "no" : redFlags.length ? "qualified" : rockets ? `rocket${rockets}` : "yes";
const headlineKey = review.verdict.override?.headline ?? computed;
const headline = HEADLINES[headlineKey];
const points = signalPoints.toFixed(1).replace(/\.0$/, "");

// ─── HTML helpers ────────────────────────────────────────────────────────────

const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
/** Escaped text with `inline code` support. */
const rich = (s) => esc(s).replace(/`([^`]+)`/g, "<code>$1</code>");
const gh = facts.candidate.remote?.githubBase;
const sha = facts.candidate.headSha;

function refHref(ref) {
  if (!gh) return undefined;
  const lines = ref.start ? `#L${ref.start}${ref.end && ref.end !== ref.start ? `-L${ref.end}` : ""}` : "";
  return `${gh}/blob/${sha}/${ref.file.split("/").map(encodeURIComponent).join("/")}${lines}`;
}
function refLabel(ref) {
  return `${ref.file}${ref.start ? `:${ref.start}${ref.end && ref.end !== ref.start ? `–${ref.end}` : ""}` : ""}`;
}
/** Full path label for snippet captions; a compact "↗ file.ts" link inline in one-liners. */
function refLink(ref, { compact = false } = {}) {
  if (!ref) return "";
  const href = refHref(ref);
  const label = compact ? `↗ ${path.posix.basename(ref.file)}` : refLabel(ref);
  const title = esc(refLabel(ref));
  return href
    ? `<a class="ref" href="${esc(href)}" title="${title}" target="_blank" rel="noopener">${esc(label)}</a>`
    : `<span class="ref" title="${title}">${esc(label)}</span>`;
}
function commitLink(short) {
  const full = facts.history.commits.find((c) => c.short === short || c.sha.startsWith(short))?.sha;
  return gh && full ? `<a class="sha" href="${esc(`${gh}/commit/${full}`)}" target="_blank" rel="noopener">${esc(short)}</a>` : `<span class="sha">${esc(short)}</span>`;
}

function languageOf(file) {
  const base = path.basename(file);
  if (/^Dockerfile/.test(base)) return "dockerfile";
  const ext = path.extname(base).slice(1);
  return { ts: "typescript", tsx: "typescript", mts: "typescript", js: "javascript", mjs: "javascript", cjs: "javascript", json: "json", yml: "yaml", yaml: "yaml", md: "markdown" }[ext] ?? "plaintext";
}

// Bands sit behind the code so syntax highlighting stays intact; one per line, same height.
function hlBands(count, isOn) {
  const spans = Array.from({ length: count }, (_, i) => `<span${isOn(i) ? ' class="on"' : ""}></span>`).join("");
  return `<span class="hl-layer" aria-hidden="true">${spans}</span>`;
}

function snippet(ref) {
  const lines = linesOf(ref.file);
  const start = ref.start;
  const end = Math.min(ref.end ?? ref.start, lines.length);
  const shownEnd = Math.min(end, start + SNIPPET_MAX_LINES - 1);
  const body = lines.slice(start - 1, shownEnd);
  const hl = new Set(ref.hl ?? []);
  const numbers = body.map((_, i) => (hl.has(start + i) ? `<b class="hl-n">${start + i}</b>` : start + i)).join("\n");
  const bands = hl.size ? hlBands(body.length, (i) => hl.has(start + i)) : "";
  const more = end > shownEnd ? `<div class="snip-more">${end - shownEnd} more lines — open on GitHub</div>` : "";
  return `<figure class="snip">
  <figcaption>${refLink(ref)}${ref.note ? `<span class="snip-note">${rich(ref.note)}</span>` : ""}</figcaption>
  <div class="snip-body"><pre class="gutter" aria-hidden="true">${numbers}</pre><pre class="code">${bands}<code class="language-${languageOf(ref.file)}">${esc(body.join("\n"))}</code></pre></div>
  ${more}
</figure>`;
}

function formatTime(iso) {
  const m = iso.match(/T(\d{2}:\d{2}).*([+-]\d{2}):?(\d{2})$/);
  if (!m) return esc(iso);
  const offset = `UTC${m[2].replace("-", "−")}${m[3] === "00" ? "" : `:${m[3]}`}`;
  return `${m[1]} <span class="tz">${offset}</span>`;
}

const statusGlyph = { yes: "✓", partial: "◐", no: "✕" };
const statusWord = { yes: "Yes", partial: "Partly", no: "No" };

/** How a commit reads on the cadence graph: new work, reworking their own code, or moving it. */
function commitKind(c) {
  if (c.flags.includes("restructure")) return "restructured";
  if (c.flags.includes("revises-earlier-work")) return "reworked";
  return "new";
}

// ─── Sections ────────────────────────────────────────────────────────────────

const { candidate, gate, history } = facts;
const startEpoch = Date.parse(history.firstCommitAt);

function renderMast() {
  const repo = gh ? `<a href="${esc(gh)}" target="_blank" rel="noopener">${esc(gh.replace("https://github.com/", ""))}</a>` : esc(candidate.remote?.url ?? candidate.dir);
  return `<header class="mast">
  <p class="eyebrow">Policy Engine interview · reviewer brief</p>
  <h1>${esc(candidate.displayName)}</h1>
  <p class="meta">${repo} · commit ${commitLink(candidate.headShort)} · ${history.commitCount} commits over ${history.elapsedMinutes} min · reviewed ${esc(facts.collectedAt.slice(0, 10))}</p>
</header>`;
}

function renderVerdict() {
  const scale = SCALE.map(
    ([n, word]) => `<li class="${headline.scale.includes(n) ? "on" : ""}"><span class="n">${n}</span><span class="w">${word}</span></li>`,
  ).join("");
  const basis = [
    gate.passed ? "Gate passed" : "Gate failed",
    `signals ${points}/${SIGNALS.length} (${Math.round(signalRatio * 100)}%)`,
    `${starCount} ⭐`,
    redFlags.length ? `${redFlags.length} red flag${redFlags.length > 1 ? "s" : ""}` : "no red flags",
  ].join(" · ");
  const override = review.verdict.override
    ? `<p class="override">Overridden from ${esc(HEADLINES[computed].label)}: ${rich(review.verdict.override.reason)}</p>`
    : "";
  return `<section class="verdict v-${headlineKey}" aria-label="Verdict">
  <div class="mark" aria-hidden="true">${headline.mark}</div>
  <div class="verdict-body">
    <p class="verdict-label">${esc(headline.label)} <span>· ${esc(headline.line)}</span></p>
    <p class="verdict-summary">${rich(review.verdict.summary)}</p>
    <div class="scale-row"><span class="scale-cap">Suggested score</span><ol class="scale">${scale}</ol></div>
    <p class="basis">${esc(basis)}</p>
    ${override}
  </div>
</section>`;
}

function renderGate() {
  const chip = (label, ok, value) => `<li class="chip ${ok ? "ok" : "bad"}"><span class="chip-glyph">${ok ? "✓" : "✕"}</span>${esc(label)}${value ? ` <b>${esc(value)}</b>` : ""}</li>`;
  const chips = [
    chip("Starter tests", gate.provided.passed === gate.provided.total, `${gate.provided.passed}/${gate.provided.total}`),
    chip("Hidden tests", gate.hidden.passed === gate.hidden.total, `${gate.hidden.passed}/${gate.hidden.total}`),
    ...facts.checks.map((c) =>
      chip(`Their ${c.script}`, c.passed, c.summary ? `${c.summary.passed}/${c.summary.total}` : c.passed ? "" : `exit ${c.exitCode}`),
    ),
  ].join("");
  const failures = gate.tests.filter((t) => t.status !== "passed");
  const failureList = failures.length
    ? `<ul class="failures">${failures.map((t) => `<li><b>${esc(t.group)}</b> · ${esc(t.suite)} › ${esc(t.title)}<pre>${esc(t.failure ?? "")}</pre></li>`).join("")}</ul>`
    : "";
  const concerns = [...(review.concerns ?? [])].sort((a, b) => (a.severity === b.severity ? 0 : a.severity === "red-flag" ? -1 : 1));
  const concernList = concerns.length
    ? `<ul class="concerns">${concerns.map((c) => `<li class="${c.severity}"><span class="sev">${c.severity === "red-flag" ? "Red flag" : "Watch"}</span><span>${rich(c.text)} ${refLink(c.ref, { compact: true })}</span></li>`).join("")}</ul>`
    : `<p class="none">No red flags or concerns.</p>`;
  return `<section id="gate" class="block">
  <h2>Gate &amp; concerns</h2>
  <ul class="chips">${chips}</ul>
  ${failureList}
  ${concernList}
  <div class="rerun"><span>Re-run hidden tests live:</span><code id="rerun-cmd">${esc(gate.liveCommand)}</code><button type="button" class="copy" data-copy="rerun-cmd">Copy</button></div>
</section>`;
}

/**
 * Request-flow sequence diagram from review.flow: participants become lifelines, steps
 * become calls (solid), returns (dashed), self-steps, spanning notes and loop frames.
 * Anything marked `added` (beyond the exercise's core) draws in the accent color.
 */
function renderFlow() {
  const f = review.flow;
  if (!f) return "";
  const P = f.participants;
  const W = 952;
  const padX = 16;
  const colW = (W - 2 * padX) / P.length;
  const cx = (id) => padX + colW * (P.findIndex((p) => p.id === id) + 0.5);
  const cls = (base, added) => `${base}${added ? " added" : ""}`;
  const els = [];
  const loops = [];
  let y = 78;
  const widen = (x1, x2) => {
    for (const l of loops) {
      l.minX = Math.min(l.minX, x1, x2);
      l.maxX = Math.max(l.maxX, x1, x2);
    }
  };
  for (const s of f.steps) {
    if (s.kind === "loop-start") {
      loops.push({ label: s.text, top: y, minX: Infinity, maxX: -Infinity });
      y += 24;
      continue;
    }
    if (s.kind === "loop-end") {
      const l = loops.pop();
      const x1 = l.minX - colW * 0.42;
      const x2 = l.maxX + colW * 0.42;
      const tabW = Math.min(x2 - x1, 16 + l.label.length * 6.4);
      els.push(
        `<rect x="${x1}" y="${l.top}" width="${x2 - x1}" height="${y - l.top}" rx="6" class="fl-loop"/>` +
          `<path d="M${x1} ${l.top + 18} H${x1 + tabW - 8} L${x1 + tabW} ${l.top + 10} V${l.top} H${x1 + 6} Q${x1} ${l.top} ${x1} ${l.top + 6} Z" class="fl-loop-tab"/>` +
          `<text x="${x1 + 8}" y="${l.top + 13}" class="fl-loop-label">${esc(l.label)}</text>`,
      );
      y += 14;
      continue;
    }
    const x1 = cx(s.from);
    const x2 = cx(s.to);
    if (s.kind === "note") {
      const left = Math.min(x1, x2) - colW * 0.45;
      const right = Math.max(x1, x2) + colW * 0.45;
      els.push(
        `<rect x="${left}" y="${y}" width="${right - left}" height="24" rx="5" class="${cls("fl-note", s.added)}"/>` +
          `<text x="${(left + right) / 2}" y="${y + 16}" text-anchor="middle" class="${cls("fl-label", s.added)}">${esc(s.text)}</text>`,
      );
      y += 36;
      continue;
    }
    const row = y + 18;
    if (s.from === s.to) {
      const toLeft = x1 > W * 0.6;
      const dx = toLeft ? -22 : 22;
      els.push(
        // Out to the side, down, and back to 3px short of the lifeline so the arrowhead lands on it.
        `<path d="M${x1} ${row - 8} h${dx} v14 h${-dx + (toLeft ? -3 : 3)}" class="${cls("fl-msg", s.added)}" marker-end="url(#fl-arrow${s.added ? "-added" : ""})"/>` +
          `<text x="${x1 + (toLeft ? -30 : 30)}" y="${row + 3}" text-anchor="${toLeft ? "end" : "start"}" class="${cls("fl-label", s.added)}">${esc(s.text)}</text>`,
      );
      widen(x1 + dx, x1);
    } else {
      const dir = Math.sign(x2 - x1);
      els.push(
        `<line x1="${x1}" y1="${row}" x2="${x2 - dir * 3}" y2="${row}" class="${cls(`fl-msg${s.return ? " ret" : ""}`, s.added)}" marker-end="url(#fl-arrow${s.added ? "-added" : ""})"/>` +
          `<text x="${(x1 + x2) / 2}" y="${row - 6}" text-anchor="middle" class="${cls("fl-label", s.added)}">${esc(s.text)}</text>`,
      );
      widen(x1, x2);
    }
    y += 34;
  }
  const H = y + 10;
  const heads = P.map((p) => {
    const x = cx(p.id);
    return (
      `<line x1="${x}" y1="56" x2="${x}" y2="${H - 4}" class="fl-life"/>` +
      `<rect x="${x - colW / 2 + 5}" y="8" width="${colW - 10}" height="46" rx="8" class="${cls("fl-box", p.added)}"/>` +
      `<text x="${x}" y="28" text-anchor="middle" class="${cls("fl-title", p.added)}">${esc(p.label)}</text>` +
      (p.sub ? `<text x="${x}" y="44" text-anchor="middle" class="fl-sub">${esc(p.sub)}</text>` : "")
    );
  }).join("");
  const marker = (id, klass) =>
    `<marker id="${id}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" class="${klass}"/></marker>`;
  return `<section id="flow" class="block">
  <h2>How a request flows</h2>
  <figure class="flow">
    <div class="flow-scroll"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(f.caption ?? "Request flow sequence diagram")}">
      <defs>${marker("fl-arrow", "mk-core")}${marker("fl-arrow-added", "mk-added")}</defs>
      ${heads}
      ${els.join("")}
    </svg></div>
    <figcaption><span class="legend"><span class="key key-core"></span>the exercise's core <span class="key key-added"></span>added by the candidate · solid = call · dashed = return</span>${f.caption ? `<span>${rich(f.caption)}</span>` : ""}</figcaption>
  </figure>
</section>`;
}

function renderSignals() {
  const byId = new Map(review.signals.map((s) => [s.id, s]));
  const rows = SIGNALS.map(([id, label]) => {
    const s = byId.get(id);
    return `<li class="sig s-${s.status}${s.star ? " starred" : ""}"><span class="sig-glyph" title="${statusWord[s.status]}">${statusGlyph[s.status]}</span><span class="sig-label">${esc(label)}${s.star ? ' <span class="star" title="Above and beyond">⭐</span>' : ""}</span><span class="sig-ev">${rich(s.evidence)} ${refLink(s.ref, { compact: true })}</span></li>`;
  }).join("");
  return `<section id="signals" class="block">
  <h2>Signals beyond the core <span class="h2-note">${points} of ${SIGNALS.length} · ⭐ = above and beyond · 🚀 at ${ROCKET_TIERS.map((floor) => Math.round(floor * 100)).join(" · ")}%</span></h2>
  <ul class="signals">${rows}</ul>
</section>`;
}

function renderChallenge() {
  const c = challenge;
  const pills = [
    `<span class="pill impact-${esc(c.impact ?? "high")}">${esc(c.impact ?? "high")} impact</span>`,
    c.challenge ? `<span class="pill quiet">${esc(CHALLENGE_WORDS[c.challenge] ?? c.challenge)}</span>` : "",
    c.signal ? `<span class="pill quiet">${esc(SIGNAL_LABEL[c.signal])}</span>` : "",
  ].join("");
  const lang = c.example.lang ?? "typescript";
  const rows = c.example.rows
    .map(
      (r) => `<li class="case-row ${r.ok ? "ok" : "bad"}"><span class="row-label">${rich(r.label)}</span><pre class="code"><code class="language-${esc(lang)}">${esc(r.code)}</code></pre><span class="row-result" title="${r.ok ? "As they intended" : "Not what they intended"}">${r.ok ? "✓" : "✕"} ${esc(r.result)}</span></li>`,
    )
    .join("");
  const input = c.example.input;
  const inputHl = new Set(input.hl ?? []);
  const inputBands = inputHl.size ? hlBands(input.code.split("\n").length, (i) => inputHl.has(i + 1)) : "";
  const inputBlock = `<figure class="snip case-input">
  <figcaption><span class="input-label">${rich(input.label ?? "Input")}</span><button type="button" class="copy" data-copy="case-input">Copy</button></figcaption>
  <div class="snip-body"><pre class="code">${inputBands}<code id="case-input" class="language-${esc(input.lang ?? "json")}">${esc(input.code)}</code></pre></div>
</figure>`;
  return `<section id="question" class="block">
  <h2>The question to ask</h2>
  <article class="challenge">
    <header><h3>${rich(c.title)}</h3><div class="pills">${pills}</div></header>
    <dl class="brief">
      <dt>Their aim</dt><dd>${rich(c.intent)}</dd>
      <dt>The case</dt><dd class="case"><p>${rich(c.example.given)}</p>${inputBlock}<ul class="case-rows">${rows}</ul><p class="case-key">✓ as they intended · ✕ the gap</p></dd>
      <dt>Why</dt><dd>${rich(c.cause)}</dd>
    </dl>
    <blockquote class="ask"><span class="ask-cap">Ask</span>${rich(c.ask)}</blockquote>
    <dl class="brief">
      <dt>Good answers</dt><dd><ul class="answers">${c.goodAnswers.map((a) => `<li>${rich(a)}</li>`).join("")}</ul></dd>
      <dt>Why it matters</dt><dd>${rich(c.why)}</dd>
    </dl>
    ${c.alreadyDocumented ? `<p class="documented">They addressed this in ${rich(c.alreadyDocumented)}: ask them to defend or revisit it.</p>` : ""}
    <div class="evidence"><h4>Look at</h4>${c.refs.map(snippet).join("")}</div>
  </article>
</section>`;
}

function renderExternalization() {
  const x = review.externalization;
  const statusText = { "headed-there": "Headed there", partial: "Partway", "not-started": "Not started" }[x.status] ?? x.status;
  const items = (x.bullets ?? [])
    .map((b) => `<li class="k-${esc(b.kind)}"><span class="k-glyph">${b.kind === "has" ? "✓" : "✕"}</span><span>${rich(b.text)} ${refLink(b.ref, { compact: true })}</span></li>`)
    .join("");
  return `<section id="externalization" class="block">
  <h2>Your thread: externalized, versioned rules <span class="pill st-${esc(x.status)}">${esc(statusText)}</span></h2>
  <ul class="xlist">${items}</ul>
</section>`;
}

function renderRoadmap() {
  const r = review.roadmap;
  if (!r) return "";
  const order = { done: 0, partial: 1, planned: 2 };
  const statusText = { done: "Done", partial: "Partial", planned: "Planned" };
  const items = [...(r.items ?? [])]
    .sort((a, b) => order[a.status] - order[b.status])
    .map((it) => `<li><span class="pill rm-${esc(it.status)}">${esc(statusText[it.status])}</span><span><b>${rich(it.item)}</b>${it.note ? ` <span class="muted">— ${rich(it.note)}</span>` : ""}</span></li>`)
    .join("");
  return `<section id="roadmap" class="block">
  <h2>Roadmap vs delivery ${r.source ? `<span class="h2-note src">${esc(r.source)}</span>` : ""}</h2>
  <p>${rich(r.summary)}</p>
  ${items ? `<ul class="rmlist">${items}</ul>` : ""}
</section>`;
}

function renderHowTheyWorked() {
  const focus = (review.focusAreas ?? [])
    .map((f) => `<li><span class="weight w-${esc(f.weight)}">${esc(f.weight)}</span><span><b>${esc(f.area)}</b> <span class="muted">${rich(f.text)}</span></span></li>`)
    .join("");
  return `<section id="how" class="block">
  <h2>How they worked</h2>
  <dl class="notes">
    <dt>AI usage</dt><dd>${rich(review.aiUsage.summary)}</dd>
    <dt>Agent guidance</dt><dd>${rich(review.agentGuidance.summary)}</dd>
  </dl>
  ${focus ? `<ul class="focus">${focus}</ul>` : ""}
  ${renderCadence()}
  ${renderTimeline()}
</section>`;
}

/** Commit cadence: x = minutes since the starter commit, bar = lines changed (√), color = kind of change. */
function renderCadence() {
  const commits = history.commits.slice(1);
  if (commits.length === 0) return "";
  const W = 720;
  const H = 124;
  const padL = 36;
  const padR = 12;
  const top = 10;
  const base = 90;
  const span = Math.max(history.elapsedMinutes, 30);
  const tickStep = span > 180 ? 60 : 30;
  const churn = (c) => c.added + c.deleted;
  const maxLines = Math.max(...commits.map(churn), 1);
  const x = (min) => padL + (min / span) * (W - padL - padR);
  const h = (lines) => Math.max((Math.sqrt(lines) / Math.sqrt(maxLines)) * (base - top), 2);
  const ticks = [];
  for (let m = 0; m <= span; m += tickStep) {
    ticks.push(`<line x1="${x(m)}" x2="${x(m)}" y1="${top}" y2="${base}" class="grid"/><text x="${x(m)}" y="${base + 16}" text-anchor="middle" class="axis">${m}</text>`);
  }
  const bars = commits
    .map((c) => {
      const min = (Date.parse(c.date) - startEpoch) / 60000;
      const kind = commitKind(c);
      const detail = kind === "reworked" ? `, rewrote ${c.revisedLines} of their own lines` : kind === "restructured" ? `, moved ${c.movedLines} lines` : "";
      return `<g><title>${esc(`${c.short} +${c.added} −${c.deleted}${detail} — ${c.subject}`)}</title><rect x="${x(min) - 3.5}" y="${base - h(churn(c))}" width="7" height="${h(churn(c))}" rx="1.5" class="bar-${kind}"/></g>`;
    })
    .join("");
  const count = (kind) => commits.filter((c) => commitKind(c) === kind).length;
  const stats = `${count("reworked")} reworked and ${count("restructured")} restructured of ${commits.length} commits`;
  return `<figure class="cadence">
  <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Commit cadence over ${history.elapsedMinutes} minutes: ${stats}">
    ${ticks.join("")}
    <line x1="${padL}" x2="${W - padR}" y1="${base}" y2="${base}" class="baseline"/>
    ${bars}
    <text x="${W - padR}" y="${base + 32}" text-anchor="end" class="axis">minutes since starter commit · bar height ∝ √lines changed</text>
  </svg>
  <figcaption><span class="legend"><span class="key key-new"></span>new work <span class="key key-reworked"></span>reworked own code <span class="key key-restructured"></span>restructured</span><span><b>${esc(stats)}.</b> ${rich(review.iteration.summary)}</span></figcaption>
</figure>`;
}

function renderTimeline() {
  const rows = history.commits
    .map((c, i) => {
      const min = Math.round((Date.parse(c.date) - startEpoch) / 60000);
      const kind = i === 0 ? "starter" : commitKind(c);
      const tag = kind === "new" ? "" : `<span class="flag f-${kind}">${kind}</span>`;
      return `<tr><td class="num">${formatTime(c.date)}</td><td class="num">+${min}</td><td>${commitLink(c.short)}</td><td>${esc(c.subject)} ${tag}</td><td class="num">+${c.added}</td><td class="num">−${c.deleted}</td></tr>`;
    })
    .join("");
  return `<details class="timeline"><summary>Commit timeline · ${history.commitCount} commits · ${history.totals.added.toLocaleString("en-US")} lines added</summary>
  <div class="table-wrap"><table><thead><tr><th>Time</th><th>Min</th><th>Commit</th><th>Subject</th><th>Added</th><th>Removed</th></tr></thead><tbody>${rows}</tbody></table></div>
</details>`;
}

// ─── Page ────────────────────────────────────────────────────────────────────

const STYLE = `
/* Layout: one reading column, summary first; the question card is the only boxed object. */
:root {
  --bg: #f4f5f8; --surface: #ffffff; --ink: #141a22; --muted: #5a6472; --line: #dde1e8;
  --accent: #2f4bd6; --accent-soft: #e7ebfc; --star: #a86b00; --star-soft: #fdf4dd;
  --ok: #1d7a4c; --ok-soft: #e2f2e9; --warn: #946000; --warn-soft: #fbefd6; --bad: #b3261e; --bad-soft: #f9e2df;
  --hl: #fff0b8; --code-bg: #f0f2f6; --syn-kw: #7a3fc4; --syn-str: #1d7a4c; --syn-com: #7b8594; --syn-num: #b35400; --syn-fn: #2f4bd6; --syn-type: #a3237a;
  --display: "Archivo", "Helvetica Neue", Arial, sans-serif;
  --body: "IBM Plex Sans", -apple-system, "Segoe UI", sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, "SF Mono", Menlo, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #0e1116; --surface: #151a21; --ink: #e6eaf0; --muted: #9aa4b2; --line: #2a313b;
  --accent: #93a5ff; --accent-soft: #1c2342; --star: #f2c14e; --star-soft: #2a2410;
  --ok: #62d39c; --ok-soft: #12281d; --warn: #e8b55c; --warn-soft: #2a2112; --bad: #ff8b80; --bad-soft: #2e1714;
  --hl: #3d3414; --code-bg: #0b0f14; --syn-kw: #c49cff; --syn-str: #7fd6a3; --syn-com: #6f7a89; --syn-num: #f0a868; --syn-fn: #93a5ff; --syn-type: #f28bc8;
  color-scheme: dark; } }
:root[data-theme="dark"] {
  --bg: #0e1116; --surface: #151a21; --ink: #e6eaf0; --muted: #9aa4b2; --line: #2a313b;
  --accent: #93a5ff; --accent-soft: #1c2342; --star: #f2c14e; --star-soft: #2a2410;
  --ok: #62d39c; --ok-soft: #12281d; --warn: #e8b55c; --warn-soft: #2a2112; --bad: #ff8b80; --bad-soft: #2e1714;
  --hl: #3d3414; --code-bg: #0b0f14; --syn-kw: #c49cff; --syn-str: #7fd6a3; --syn-com: #6f7a89; --syn-num: #f0a868; --syn-fn: #93a5ff; --syn-type: #f28bc8;
  color-scheme: dark; }

body { background: var(--bg); color: var(--ink); font: 15px/1.55 var(--body); }
.page { max-width: 62rem; margin: 0 auto; padding-inline: 20px; padding-block: 28px 64px; display: grid; gap: 30px; }
a { color: var(--accent); text-decoration-thickness: 1px; text-underline-offset: 2px; }
a:focus-visible, button:focus-visible, summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
code, pre, .sha, .ref { font-family: var(--mono); }
code { font-size: 0.88em; background: var(--code-bg); padding: 0.05em 0.35em; border-radius: 4px; }
h1, h2, h3, h4 { font-family: var(--display); text-wrap: balance; margin: 0; }
h2 { font-size: 1.2rem; font-weight: 700; font-stretch: 85%; letter-spacing: 0.01em; display: flex; flex-wrap: wrap; align-items: baseline; gap: 0.6rem; }
h3 { font-size: 1.12rem; font-weight: 700; }
h4 { font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); margin-bottom: 0.35rem; }
p { margin: 0; }
ul { margin: 0; padding-left: 1.1rem; }
.muted, .h2-note { color: var(--muted); }
.h2-note { font-size: 0.82rem; font-family: var(--body); font-weight: 400; letter-spacing: 0; }
.block { display: grid; gap: 12px; min-width: 0; }

.mast { display: grid; gap: 4px; }
.eyebrow { font: 600 0.74rem var(--body); text-transform: uppercase; letter-spacing: 0.12em; color: var(--muted); }
.mast h1 { font-size: clamp(2rem, 5vw, 2.8rem); font-weight: 800; font-stretch: 80%; line-height: 1.05; }
.meta { color: var(--muted); font-size: 0.88rem; }

.verdict { display: grid; grid-template-columns: auto 1fr; gap: 18px; padding: 20px 22px; border-radius: 14px; background: var(--surface); border: 1px solid var(--line); border-left: 6px solid var(--verdict); }
.v-rocket1, .v-rocket2, .v-rocket3 { --verdict: var(--accent); } .v-yes { --verdict: var(--ok); } .v-qualified { --verdict: var(--warn); } .v-no { --verdict: var(--bad); }
.mark { font-size: 3rem; line-height: 1; white-space: nowrap; }
.v-rocket2 .mark { font-size: 2.25rem; } .v-rocket3 .mark { font-size: 1.75rem; }
.verdict-body { display: grid; gap: 10px; min-width: 0; }
.verdict-label { font: 800 1.5rem/1.1 var(--display); font-stretch: 85%; color: var(--verdict); }
.verdict-label span { font: 500 1rem var(--body); color: var(--muted); }
.verdict-summary { font-size: 1.05rem; max-width: 65ch; }
.scale-row { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; }
.scale-cap { font-size: 0.78rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; }
.scale { display: flex; flex-wrap: wrap; gap: 4px; list-style: none; padding: 0; margin: 0; }
.scale li { display: flex; align-items: baseline; gap: 5px; padding: 3px 9px; border: 1px solid var(--line); border-radius: 999px; font-size: 0.82rem; color: var(--muted); }
.scale li.on { background: var(--verdict); border-color: var(--verdict); color: var(--surface); font-weight: 600; }
.scale .n { font-family: var(--mono); font-weight: 600; }
.basis { font-size: 0.82rem; color: var(--muted); font-variant-numeric: tabular-nums; }
.override { font-size: 0.85rem; color: var(--warn); }

.chips { display: flex; flex-wrap: wrap; gap: 8px; list-style: none; padding: 0; }
.chip { display: flex; align-items: center; gap: 6px; padding: 5px 11px; border-radius: 999px; font-size: 0.86rem; font-variant-numeric: tabular-nums; }
.chip.ok { background: var(--ok-soft); color: var(--ok); } .chip.bad { background: var(--bad-soft); color: var(--bad); }
.chip b { font-family: var(--mono); font-weight: 600; }
.failures { display: grid; gap: 8px; } .failures li { min-width: 0; } .failures pre { white-space: pre-wrap; overflow-wrap: anywhere; font-size: 0.78rem; background: var(--code-bg); padding: 8px; border-radius: 6px; overflow-x: auto; }
.concerns { list-style: none; padding: 0; display: grid; gap: 6px; }
.concerns li { display: grid; grid-template-columns: 5.2rem 1fr; gap: 10px; align-items: baseline; }
.sev { font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; padding: 2px 8px; border-radius: 999px; text-align: center; }
.red-flag .sev { background: var(--bad-soft); color: var(--bad); } .watch .sev { background: var(--warn-soft); color: var(--warn); }
.none { color: var(--ok); font-weight: 500; }
.rerun { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; font-size: 0.84rem; color: var(--muted); }
.rerun code { color: var(--ink); overflow-wrap: anywhere; }
.copy { font: 600 0.78rem var(--body); padding: 3px 10px; border-radius: 6px; border: 1px solid var(--line); background: var(--surface); color: var(--ink); cursor: pointer; }
.copy:hover { border-color: var(--accent); }
.ref { font-size: 0.78rem; white-space: nowrap; }
.sha { font-size: 0.84rem; }

.signals { list-style: none; padding: 0; display: grid; }
.sig { display: grid; grid-template-columns: 1.4rem 13rem 1fr; gap: 10px; align-items: baseline; padding: 6px 8px; border-bottom: 1px solid var(--line); min-width: 0; }
.sig.starred { background: var(--star-soft); border-radius: 6px; border-bottom-color: transparent; }
.sig-glyph { font-weight: 700; text-align: center; }
.s-yes .sig-glyph { color: var(--ok); } .s-partial .sig-glyph { color: var(--warn); } .s-no .sig-glyph { color: var(--bad); }
.sig-label { font-weight: 600; }
.star { font-size: 0.9em; }
.sig-ev { color: var(--muted); font-size: 0.92rem; min-width: 0; }
.starred .sig-ev { color: var(--ink); }
@media (max-width: 36rem) { .sig { grid-template-columns: 1.4rem 1fr; } .sig-ev { grid-column: 2; } }

.challenge { background: var(--surface); border: 1px solid var(--line); border-radius: 14px; padding: 18px 20px; display: grid; gap: 14px; min-width: 0; }
.challenge header { display: grid; gap: 8px; }
.pills { display: flex; flex-wrap: wrap; gap: 6px; }
.pill { display: inline-block; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; padding: 2px 9px; border-radius: 999px; background: var(--accent-soft); color: var(--accent); white-space: nowrap; font-family: var(--body); }
.pill.quiet { background: var(--code-bg); color: var(--muted); }
.impact-medium, .impact-low { background: var(--warn-soft); color: var(--warn); }
.ask { margin: 0; padding: 10px 14px; border-radius: 10px; background: var(--accent-soft); font-size: 1.02rem; }
.ask-cap { display: block; margin-bottom: 2px; font: 700 0.7rem var(--body); text-transform: uppercase; letter-spacing: 0.1em; color: var(--accent); }
.brief { display: grid; grid-template-columns: 7.5rem 1fr; gap: 10px 14px; margin: 0; align-items: baseline; }
.brief dt { font: 700 0.7rem var(--body); text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); }
.brief dd { margin: 0; min-width: 0; max-width: 72ch; }
@media (max-width: 36rem) { .brief { grid-template-columns: 1fr; gap: 4px; } .brief dd { margin-bottom: 8px; } }
.brief dd.case { display: grid; gap: 6px; max-width: none; }
.case-rows { list-style: none; padding: 0; display: grid; gap: 6px; }
.case-row { display: grid; grid-template-columns: 10rem 1fr auto; gap: 10px; align-items: center; padding: 7px 10px; border-radius: 8px; background: var(--code-bg); border-left: 4px solid var(--row); }
.case-row.ok { --row: var(--ok); } .case-row.bad { --row: var(--bad); }
.row-label { font-size: 0.84rem; font-weight: 600; }
.case-row pre { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; font-size: 0.8rem; line-height: 1.45; min-width: 0; }
.case-row pre code { background: none; padding: 0; font-size: inherit; }
.row-result { font-weight: 700; font-size: 0.84rem; padding: 2px 10px; border-radius: 999px; white-space: nowrap; }
.ok .row-result { background: var(--ok-soft); color: var(--ok); } .bad .row-result { background: var(--bad-soft); color: var(--bad); }
.case-key { font-size: 0.78rem; color: var(--muted); }
@media (max-width: 40rem) { .case-row { grid-template-columns: 1fr; gap: 6px; } .row-result { justify-self: start; } }
.answers { display: grid; gap: 5px; }
.documented { font-size: 0.88rem; color: var(--muted); }
.evidence { display: grid; gap: 10px; min-width: 0; }
.snip { margin: 0; border: 1px solid var(--line); border-radius: 10px; overflow: hidden; min-width: 0; }
.snip figcaption { display: flex; flex-wrap: wrap; gap: 8px; align-items: baseline; padding: 6px 10px; background: var(--code-bg); border-bottom: 1px solid var(--line); }
.snip-note { font-size: 0.82rem; color: var(--muted); }
.snip-body { display: grid; grid-template-columns: auto 1fr; overflow-x: auto; background: var(--code-bg); }
.snip pre { margin: 0; padding: 10px 12px; font-size: 0.8rem; line-height: 1.5; }
.snip pre code { background: none; padding: 0; font-size: inherit; }
.snip pre.code { position: relative; }
.snip pre.code code { position: relative; }
.hl-layer { position: absolute; top: 10px; left: 0; right: 0; pointer-events: none; }
.hl-layer span { display: block; height: 1.5em; }
.hl-layer span.on { background: var(--hl); }
.hl-n { color: var(--ink); font-weight: 700; }
.case-input .snip-body { grid-template-columns: 1fr; }
.case-input figcaption { align-items: center; }
.input-label { font: 600 0.8rem var(--mono); }
.case-input .copy { margin-left: auto; }
.gutter { color: var(--muted); text-align: right; user-select: none; border-right: 1px solid var(--line); opacity: 0.8; }
.snip-more { font-size: 0.78rem; color: var(--muted); padding: 4px 12px 8px; background: var(--code-bg); }
.hljs-keyword, .hljs-meta { color: var(--syn-kw); } .hljs-string, .hljs-regexp { color: var(--syn-str); }
.hljs-comment { color: var(--syn-com); font-style: italic; } .hljs-number, .hljs-literal { color: var(--syn-num); }
.hljs-title, .hljs-title.function_ { color: var(--syn-fn); } .hljs-type, .hljs-built_in, .hljs-title.class_ { color: var(--syn-type); }

.st-headed-there { background: var(--ok-soft); color: var(--ok); } .st-partial { background: var(--warn-soft); color: var(--warn); } .st-not-started { background: var(--bad-soft); color: var(--bad); }
.xlist, .rmlist, .focus { list-style: none; padding: 0; display: grid; gap: 6px; }
.xlist li { display: grid; grid-template-columns: 1.4rem 1fr; gap: 8px; align-items: baseline; }
.k-glyph { font-weight: 700; text-align: center; } .k-has .k-glyph { color: var(--ok); } .k-missing .k-glyph { color: var(--bad); }
.rmlist li { display: grid; grid-template-columns: 5.4rem 1fr; gap: 10px; align-items: baseline; }
.rmlist .pill { text-align: center; }
.rm-done { background: var(--ok-soft); color: var(--ok); } .rm-partial { background: var(--warn-soft); color: var(--warn); } .rm-planned { background: var(--accent-soft); color: var(--accent); }
.src { font-family: var(--mono); }

.notes { display: grid; grid-template-columns: 8.5rem 1fr; gap: 6px 14px; margin: 0; }
.notes dt { font-weight: 600; } .notes dd { margin: 0; max-width: 72ch; }
@media (max-width: 36rem) { .notes { grid-template-columns: 1fr; } .notes dd { margin-bottom: 6px; } }
.focus li { display: grid; grid-template-columns: 5.4rem 1fr; gap: 10px; align-items: baseline; }
.weight { font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }
.w-major { color: var(--accent); font-weight: 700; }

.cadence { margin: 0; display: grid; gap: 6px; }
.cadence svg { width: 100%; height: auto; max-width: 100%; }
.grid { stroke: var(--line); stroke-width: 1; } .baseline { stroke: var(--muted); stroke-width: 1; }
.axis { fill: var(--muted); font: 10px var(--mono); }
.bar-new { fill: var(--muted); opacity: 0.5; } .bar-reworked { fill: var(--accent); } .bar-restructured { fill: var(--star); }
.cadence figcaption { font-size: 0.86rem; display: grid; gap: 4px; }
.legend { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; color: var(--muted); font-size: 0.8rem; }
.key { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-left: 6px; }
.key-new { background: var(--muted); opacity: 0.5; margin-left: 0; } .key-reworked { background: var(--accent); } .key-restructured { background: var(--star); }

.flow { margin: 0; display: grid; gap: 6px; }
.flow-scroll { overflow-x: auto; }
.flow svg { width: 100%; min-width: 720px; height: auto; display: block; }
.fl-box { fill: var(--surface); stroke: var(--line); } .fl-box.added { fill: var(--accent-soft); stroke: var(--accent); }
.fl-title { fill: var(--ink); font: 600 12.5px var(--body); } .fl-title.added { fill: var(--accent); }
.fl-sub { fill: var(--muted); font: 10.5px var(--mono); }
.fl-life { stroke: var(--line); stroke-width: 1.2; stroke-dasharray: 3 4; }
.fl-msg { stroke: var(--ink); stroke-width: 1.3; fill: none; } .fl-msg.added { stroke: var(--accent); } .fl-msg.ret { stroke-dasharray: 5 4; }
.fl-label { fill: var(--ink); font: 12px var(--body); } .fl-label.added { fill: var(--accent); }
.fl-note { fill: var(--code-bg); stroke: var(--line); } .fl-note.added { fill: var(--accent-soft); stroke: var(--accent); }
.fl-loop { fill: none; stroke: var(--muted); stroke-dasharray: 2 3; }
.fl-loop-tab { fill: var(--code-bg); stroke: var(--muted); }
.fl-loop-label { fill: var(--muted); font: 600 11px var(--body); }
.mk-core { fill: var(--ink); } .mk-added { fill: var(--accent); }
.key-core { background: var(--ink); margin-left: 0; } .key-added { background: var(--accent); }
.flow figcaption { font-size: 0.86rem; display: grid; gap: 4px; }

.timeline summary { cursor: pointer; font-weight: 600; padding: 6px 0; font-size: 0.9rem; }
.table-wrap { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; font-size: 0.86rem; }
td, th { text-align: left; padding: 5px 8px; border-bottom: 1px solid var(--line); vertical-align: top; }
th { font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); font-weight: 600; }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; }
.tz { color: var(--muted); font-size: 0.76rem; }
.flag { font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 1px 6px; border-radius: 999px; margin-left: 4px; white-space: nowrap; background: var(--code-bg); color: var(--muted); }
.f-reworked { background: var(--accent-soft); color: var(--accent); } .f-restructured { background: var(--star-soft); color: var(--star); }

.toc { display: flex; flex-wrap: wrap; gap: 6px 14px; font-size: 0.86rem; }
.toc a { text-decoration: none; color: var(--muted); } .toc a:hover { color: var(--accent); }
footer { font-size: 0.8rem; color: var(--muted); border-top: 1px solid var(--line); padding-top: 12px; }
`;

const SCRIPT = `
document.querySelectorAll("button.copy").forEach((btn) => {
  btn.addEventListener("click", () => {
    const el = document.getElementById(btn.dataset.copy);
    const text = el.textContent;
    const done = () => { btn.textContent = "Copied"; setTimeout(() => (btn.textContent = "Copy"), 1500); };
    const select = () => { const r = document.createRange(); r.selectNodeContents(el); const s = getSelection(); s.removeAllRanges(); s.addRange(r); btn.textContent = "Selected — press ⌘C"; };
    try { navigator.clipboard.writeText(text).then(done, select); } catch { select(); }
  });
});
if (window.hljs) document.querySelectorAll("pre.code code").forEach((el) => window.hljs.highlightElement(el));
`;

const html = `<title>${esc(candidate.displayName)} Policy Engine Review</title>
<meta name="description" content="Reviewer brief for ${esc(candidate.displayName)}'s Policy Engine interview submission">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..100,500..800&family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap">
<style>${STYLE}</style>
<main class="page">
${renderMast()}
${renderVerdict()}
<nav class="toc" aria-label="Sections"><a href="#gate">Gate &amp; concerns</a>${review.flow ? '<a href="#flow">Request flow</a>' : ""}<a href="#signals">Signals</a><a href="#question">The question</a><a href="#externalization">Your thread</a><a href="#roadmap">Roadmap</a><a href="#how">How they worked</a></nav>
${renderGate()}
${renderFlow()}
${renderSignals()}
${renderChallenge()}
${renderExternalization()}
${renderRoadmap()}
${renderHowTheyWorked()}
<footer>Generated by the review-policy-engine skill from commit ${esc(candidate.headShort)} (${esc(candidate.ref)}) on ${esc(facts.collectedAt.slice(0, 16).replace("T", " "))} UTC. Tests ran in a clean snapshot of that commit; the candidate's own checks ran before any review files were added.</footer>
</main>
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<script>${SCRIPT}</script>
`;

const outFile = path.join(outDir, "review.html");
fs.writeFileSync(outFile, html);
console.log(`headline    ${headline.mark} ${headline.label}${review.verdict.override ? ` (override; computed ${HEADLINES[computed].label})` : ""} · signals ${Math.round(signalRatio * 100)}% · stars ${starCount} · red flags ${redFlags.length}`);
console.log(`html        ${outFile}`);
