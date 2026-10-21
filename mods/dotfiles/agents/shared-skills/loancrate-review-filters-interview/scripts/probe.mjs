#!/usr/bin/env node
/**
 * Black-box functional probe of the candidate's filtering API — the review's gate.
 *
 *   node probe.mjs <outDir>                         run the fixed suite, write facts.probe
 *   node probe.mjs <outDir> --filters '<json>'      send one request, print what came back
 *
 * <outDir>/probe/adapter.mjs translates the spec's filters into the candidate's request
 * shape and their response back into borrower ids (references/adapter.md). Expected
 * results come from a reference implementation of the spec run over the borrower data
 * their server loads, so the suite also holds when a candidate regenerated the data.
 *
 * Cases are derived from the data deterministically and chosen to catch the usual bugs:
 * "is" implemented as "includes", inclusive bounds, dates compared as "M/D/YYYY" strings,
 * and UTC/local off-by-one (the server runs with a negative UTC offset; see app.mjs).
 *
 * Exit 0 = the suite ran (failures are facts); 3 = no adapter; 2 = the probe itself broke.
 */
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { startApp, stopApp, appStatus } from "./app.mjs";

const STRING_FIELDS = ["firstName", "lastName", "maritalStatus", "emailAddress", "homePhone", "cellPhone", "currentAddress", "employer", "title", "subjectPropertyAddress"];
const NUMBER_FIELDS = ["creditScore", "w2Income"];
const DATE_FIELDS = ["dateOfBirth", "startDate"];
const TYPE_OF = Object.fromEntries([...STRING_FIELDS.map((f) => [f, "string"]), ...NUMBER_FIELDS.map((f) => [f, "number"]), ...DATE_FIELDS.map((f) => [f, "date"])]);
const REQUEST_TIMEOUT_MS = 15_000;

const [outArg, ...rest] = process.argv.slice(2);
if (!outArg) {
  console.error("usage: probe.mjs <outDir> [--filters '<json>']");
  process.exit(2);
}
const outDir = path.resolve(outArg);
const factsPath = path.join(outDir, "facts.json");
const adapterPath = path.join(outDir, "probe", "adapter.mjs");
const single = rest[0] === "--filters" ? rest[1] : undefined;

// ─── Reference semantics ─────────────────────────────────────────────────────

/** Calendar day as a sortable integer (YYYYMMDD) from "M/D/YYYY" or "YYYY-MM-DD". */
function dayNumber(value) {
  const s = String(value).trim();
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (m) return Number(m[1]) * 10000 + Number(m[2]) * 100 + Number(m[3]);
  m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (m) return Number(m[3]) * 10000 + Number(m[1]) * 100 + Number(m[2]);
  return NaN;
}

const isoOf = (value) => {
  const n = dayNumber(value);
  return `${Math.floor(n / 10000)}-${String(Math.floor(n / 100) % 100).padStart(2, "0")}-${String(n % 100).padStart(2, "0")}`;
};

/** One filter against one borrower; `fold` lowercases both sides of string comparisons. */
function matches(borrower, { field, op, value }, fold) {
  const type = TYPE_OF[field];
  const actual = borrower[field];
  if (type === "string") {
    const a = fold ? String(actual).toLowerCase() : String(actual);
    const v = fold ? String(value).toLowerCase() : String(value);
    return op === "is" ? a === v : op === "includes" ? a.includes(v) : false;
  }
  const a = type === "date" ? dayNumber(actual) : Number(actual);
  const v = type === "date" ? dayNumber(value) : Number(value);
  return op === "lt" ? a < v : op === "is" ? a === v : op === "gt" ? a > v : false;
}

function expectedIds(data, filters, fold) {
  return data.filter((b) => filters.every((f) => matches(b, f, fold))).map((b) => b.id);
}

// ─── Case derivation (deterministic from the data) ───────────────────────────

function mostCommon(values) {
  const counts = new Map();
  for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
  let best;
  for (const [v, n] of counts) if (!best || n > best[1]) best = [v, n];
  return best ?? [undefined, 0];
}

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

function buildCases(data) {
  const cases = [];
  const add = (step, id, title, filters) => cases.push({ step, id, title, filters });
  const col = (field) => data.map((b) => b[field]);

  const [firstName] = mostCommon(col("firstName"));
  add("string", "string-is", `firstName is "${firstName}"`, [{ field: "firstName", op: "is", value: firstName }]);

  // A value that is a proper substring of another value of the same field ("married" ⊂ "unmarried").
  let exact;
  for (const field of ["maritalStatus", ...STRING_FIELDS]) {
    const values = [...new Set(col(field))];
    const v = values.find((x) => values.some((y) => y !== x && y.includes(x)));
    if (v) {
      exact = { field, value: v };
      break;
    }
  }
  if (exact) add("string", "string-is-not-includes", `${exact.field} is "${exact.value}" (not its superstrings)`, [{ field: exact.field, op: "is", value: exact.value }]);

  // A three-letter fragment from inside a last name that more than one borrower shares.
  let fragment;
  for (const name of col("lastName")) {
    for (let i = 1; i + 3 <= name.length && !fragment; i++) {
      const f = name.slice(i, i + 3);
      if (/^[a-z]{3}$/.test(f) && data.filter((b) => b.lastName.includes(f)).length >= 2) fragment = f;
    }
    if (fragment) break;
  }
  if (fragment) add("string", "string-includes", `lastName includes "${fragment}"`, [{ field: "lastName", op: "includes", value: fragment }]);

  const words = col("title").flatMap((t) => String(t).split(/\s+/)).filter((w) => w.length >= 6);
  const [word] = mostCommon(words);
  if (word) add("string", "string-includes-word", `title includes "${word}"`, [{ field: "title", op: "includes", value: word }]);

  const score = median(col("creditScore"));
  add("number", "number-lt", `creditScore is less than ${score}`, [{ field: "creditScore", op: "lt", value: score }]);
  add("number", "number-is", `creditScore is ${score}`, [{ field: "creditScore", op: "is", value: score }]);
  add("number", "number-gt", `creditScore is greater than ${score}`, [{ field: "creditScore", op: "gt", value: score }]);
  const income = Math.round(median(col("w2Income")) / 1000) * 1000;
  add("number", "number-gt-income", `w2Income is greater than ${income}`, [{ field: "w2Income", op: "gt", value: income }]);

  // The birth date where comparing "M/D/YYYY" as strings disagrees with the calendar most.
  const dobs = [...new Set(col("dateOfBirth"))];
  let pivot = dobs[0];
  let worst = -1;
  for (const d of dobs) {
    const disagreements = dobs.filter((x) => (x < d) !== (dayNumber(x) < dayNumber(d))).length;
    if (disagreements > worst) {
      worst = disagreements;
      pivot = d;
    }
  }
  add("date", "date-lt", `dateOfBirth is less than ${isoOf(pivot)}`, [{ field: "dateOfBirth", op: "lt", value: isoOf(pivot) }]);
  add("date", "date-is", `dateOfBirth is ${isoOf(pivot)}`, [{ field: "dateOfBirth", op: "is", value: isoOf(pivot) }]);
  add("date", "date-gt", `dateOfBirth is greater than ${isoOf(pivot)}`, [{ field: "dateOfBirth", op: "gt", value: isoOf(pivot) }]);
  const starts = [...col("startDate")].sort((a, b) => dayNumber(a) - dayNumber(b));
  const startPivot = starts[Math.floor(starts.length / 2)];
  add("date", "date-is-start", `startDate is ${isoOf(startPivot)}`, [{ field: "startDate", op: "is", value: isoOf(startPivot) }]);
  add("date", "date-gt-start", `startDate is greater than ${isoOf(startPivot)}`, [{ field: "startDate", op: "gt", value: isoOf(startPivot) }]);

  const shared = data.find((b) => b.firstName === firstName);
  add("and", "and-names", `firstName is "${firstName}" AND lastName is "${shared.lastName}"`, [
    { field: "firstName", op: "is", value: firstName },
    { field: "lastName", op: "is", value: shared.lastName },
  ]);
  const [status] = mostCommon(col("maritalStatus"));
  add("and", "and-mixed-types", `creditScore > ${score} AND maritalStatus is "${status}" AND dateOfBirth < ${isoOf(pivot)}`, [
    { field: "creditScore", op: "gt", value: score },
    { field: "maritalStatus", op: "is", value: status },
    { field: "dateOfBirth", op: "lt", value: isoOf(pivot) },
  ]);
  add("and", "no-match", `firstName is "Zzyzx" → nothing`, [{ field: "firstName", op: "is", value: "Zzyzx" }]);

  // Unspecified by the spec: recorded as behavior, never pass/fail.
  const behavior = [
    { id: "case-is", title: `firstName is "${firstName.toLowerCase()}" (lowercase)`, filters: [{ field: "firstName", op: "is", value: firstName.toLowerCase() }] },
    { id: "case-includes", title: `lastName includes "${(fragment ?? "son").toUpperCase()}" (uppercase)`, filters: [{ field: "lastName", op: "includes", value: (fragment ?? "son").toUpperCase() }] },
    { id: "whitespace", title: `firstName is " ${firstName} " (padded)`, filters: [{ field: "firstName", op: "is", value: ` ${firstName} ` }] },
    { id: "empty-value", title: `firstName is "" (empty value)`, filters: [{ field: "firstName", op: "is", value: "" }] },
    { id: "invalid-number", title: `creditScore is less than "abc"`, filters: [{ field: "creditScore", op: "lt", value: "abc" }] },
    { id: "invalid-date", title: `dateOfBirth is greater than "not-a-date"`, filters: [{ field: "dateOfBirth", op: "gt", value: "not-a-date" }] },
    { id: "unknown-field", title: `ssn is "123" (unknown field)`, filters: [{ field: "ssn", op: "is", value: "123" }] },
    { id: "wrong-operator", title: `creditScore includes "7" (string operator on a number)`, filters: [{ field: "creditScore", op: "includes", value: "7" }] },
  ];
  return { cases, behavior };
}

// ─── Transport ───────────────────────────────────────────────────────────────

async function send(adapter, baseUrl, filters) {
  const spec = await adapter.request({ filters: filters.map((f) => ({ ...f, type: TYPE_OF[f.field] ?? "string" })) });
  const url = new URL(spec.path ?? "/", baseUrl);
  for (const [k, v] of Object.entries(spec.query ?? {})) {
    for (const item of Array.isArray(v) ? v : [v]) url.searchParams.append(k, typeof item === "string" ? item : JSON.stringify(item));
  }
  const init = { method: spec.method ?? "GET", headers: { accept: "application/json", ...spec.headers }, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) };
  if (spec.body !== undefined) {
    init.body = typeof spec.body === "string" ? spec.body : JSON.stringify(spec.body);
    init.headers["content-type"] ??= "application/json";
  }
  const res = await fetch(url, init);
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {}
  const request = `${init.method} ${url.pathname}${url.search}${init.body ? ` ${init.body}` : ""}`;
  if (!res.ok) return { status: res.status, request, error: text.slice(0, 300) };
  const parsed = await adapter.parse(json ?? text, { status: res.status, headers: Object.fromEntries(res.headers) });
  return { status: res.status, request, ids: parsed.ids, total: parsed.total ?? parsed.ids.length };
}

/** Pass when the returned ids equal the expected set (case-sensitive or folded), allowing a page of a larger total. */
function judge(result, expectCs, expectCi) {
  if (result.error !== undefined || !result.ids) return { pass: false, why: `HTTP ${result.status ?? "error"}: ${result.error ?? "no ids"}` };
  const got = new Set(result.ids);
  const fits = (expected) => {
    const set = new Set(expected);
    const subset = [...got].every((id) => set.has(id));
    return subset && (got.size === set.size || (result.total === set.size && got.size < set.size));
  };
  if (fits(expectCs)) return { pass: true, mode: "exact" };
  if (fits(expectCi)) return { pass: true, mode: "folded" };
  const expected = new Set(expectCs);
  const extra = [...got].filter((id) => !expected.has(id)).length;
  const missing = [...expected].filter((id) => !got.has(id)).length;
  return { pass: false, why: `returned ${result.total} (${extra} unexpected, ${missing} missing) — expected ${expectCs.length}` };
}

function describeBehavior(id, result, data, baseline) {
  if (result.error !== undefined) return `HTTP ${result.status}${result.status >= 400 && result.status < 500 ? " (rejected)" : ""}`;
  const n = result.total;
  const all = data.length;
  if (id === "case-is" || id === "case-includes") return n === 0 ? `${n} rows — case-sensitive` : n === baseline[id] ? `${n} rows — case-insensitive` : `${n} rows`;
  if (id === "whitespace") return n === 0 ? `${n} rows — not trimmed` : n === baseline.whitespace ? `${n} rows — trimmed` : `${n} rows`;
  return n === all ? `${n} rows — ignored (everything returned)` : n === 0 ? `0 rows — matched nothing` : `${n} rows`;
}

// ─── Main ────────────────────────────────────────────────────────────────────

function loadData(facts, adapter) {
  const candidates = [adapter.dataset && path.join(facts.paths.snapshotDir, adapter.dataset), facts.dataset?.file && path.join(facts.paths.snapshotDir, facts.dataset.file), path.join(facts.paths.goldenDir, "packages/server/borrowers.json")].filter(Boolean);
  for (const file of candidates) {
    if (!fs.existsSync(file)) continue;
    const raw = JSON.parse(fs.readFileSync(file, "utf8"));
    const list = Array.isArray(raw) ? raw : raw.borrowers;
    if (Array.isArray(list)) return { data: list, file: path.relative(facts.paths.snapshotDir, file) };
  }
  throw new Error("no borrower data found; set `dataset` in the adapter");
}

async function main() {
  const facts = JSON.parse(fs.readFileSync(factsPath, "utf8"));
  if (!fs.existsSync(adapterPath)) {
    console.error(`probe: no adapter at ${adapterPath}; write one per references/adapter.md`);
    process.exit(3);
  }
  const adapter = await import(`${pathToFileURL(adapterPath).href}?t=${Date.now()}`);
  const { data, file: dataFile } = loadData(facts, adapter);

  if (adapter.serverFiltering === false) {
    facts.probe = { ranAt: new Date().toISOString(), serverFiltering: false, gate: { status: "fail", reasons: ["filtering does not happen on the server (adapter.serverFiltering = false)"] }, cases: [], behavior: [], steps: {} };
    fs.writeFileSync(factsPath, JSON.stringify(facts, null, 2));
    console.log("gate        FAIL  filtering is not done on the server");
    return;
  }

  const wasRunning = appStatus(outDir).running;
  const app = await startApp(outDir, { serverOnly: true });
  const baseUrl = app.server.baseUrl ?? `http://127.0.0.1:${app.server.port}`;
  try {
    if (single) {
      const filters = JSON.parse(single);
      const result = await send(adapter, baseUrl, filters).catch((err) => ({ error: String(err.message ?? err) }));
      const byId = new Map(data.map((b) => [b.id, b]));
      const fields = [...new Set(filters.map((f) => f.field))];
      const rows = (result.ids ?? []).slice(0, 10).map((id) => {
        const b = byId.get(id);
        return b ? `${b.firstName} ${b.lastName}${fields.length ? ` (${fields.map((f) => `${f}=${b[f]}`).join(", ")})` : ""}` : id;
      });
      const knownFields = filters.every((f) => TYPE_OF[f.field]);
      console.log(JSON.stringify({ request: result.request, status: result.status, total: result.total, error: result.error, rows, expectedBySpec: knownFields ? { exactCase: expectedIds(data, filters, false).length, anyCase: expectedIds(data, filters, true).length } : undefined }, null, 2));
      return;
    }

    const { cases, behavior } = buildCases(data);
    const unfiltered = await send(adapter, baseUrl, []).catch((err) => ({ error: String(err.message ?? err) }));
    const allIds = data.map((b) => b.id);
    const unfilteredJudged = judge(unfiltered, allIds, allIds);

    const results = [];
    for (const c of cases) {
      const expectCs = expectedIds(data, c.filters, false);
      const expectCi = expectedIds(data, c.filters, true);
      const result = await send(adapter, baseUrl, c.filters).catch((err) => ({ error: String(err.message ?? err) }));
      const verdict = judge(result, expectCs, expectCi);
      results.push({ ...c, expected: expectCs.length, got: result.total ?? null, status: result.status ?? null, request: result.request, ...verdict });
    }

    const baseline = {
      "case-is": expectedIds(data, behavior[0].filters, true).length,
      "case-includes": expectedIds(data, behavior[1].filters, true).length,
      whitespace: expectedIds(data, [{ ...behavior[2].filters[0], value: behavior[2].filters[0].value.trim() }], false).length,
    };
    const behaviorResults = [];
    for (const b of behavior) {
      const result = await send(adapter, baseUrl, b.filters).catch((err) => ({ error: String(err.message ?? err), status: null }));
      behaviorResults.push({ id: b.id, title: b.title, status: result.status, got: result.total ?? null, request: result.request, observed: describeBehavior(b.id, result, data, baseline) });
    }

    const steps = {};
    for (const step of ["string", "number", "date", "and"]) {
      const inStep = results.filter((r) => r.step === step);
      steps[step] = { passed: inStep.filter((r) => r.pass).length, total: inStep.length };
    }
    const reasons = [];
    let status = "pass";
    if (!unfilteredJudged.pass) {
      status = "suspect";
      reasons.push(`unfiltered request did not return the ${data.length} borrowers in ${dataFile}: ${unfilteredJudged.why}`);
    } else {
      const missing = Object.entries(steps).filter(([, s]) => s.total && s.passed === 0).map(([k]) => k);
      const buggy = results.filter((r) => !r.pass);
      if (missing.length) {
        status = "fail";
        reasons.push(`not working at all: ${missing.join(", ")}`);
      } else if (buggy.length) {
        status = "bug";
      }
      for (const r of buggy) reasons.push(`${r.title}: ${r.why}`);
    }

    facts.probe = {
      ranAt: new Date().toISOString(),
      serverFiltering: true,
      serverTz: app.tz,
      dataset: { file: dataFile, count: data.length },
      unfiltered: { status: unfiltered.status ?? null, got: unfiltered.total ?? null, request: unfiltered.request, ...unfilteredJudged },
      steps,
      cases: results,
      behavior: behaviorResults,
      caseMode: results.some((r) => r.mode === "folded") ? "folded" : "exact",
      gate: { status, reasons },
    };
    fs.writeFileSync(factsPath, JSON.stringify(facts, null, 2));

    console.log(`gate        ${status.toUpperCase()}  ${Object.entries(steps).map(([k, s]) => `${k} ${s.passed}/${s.total}`).join("  ")}`);
    for (const r of results.filter((x) => !x.pass)) console.log(`  ✕ ${r.title} — ${r.why}`);
    if (status === "suspect") console.log(`  ⚠ ${reasons[0]}`);
    for (const b of behaviorResults) console.log(`behavior    ${b.title.padEnd(58)} ${b.observed}`);
    console.log(`request     ${unfiltered.request ?? "(none)"}`);
  } finally {
    if (!wasRunning) await stopApp(outDir);
  }
}

main().catch((err) => {
  console.error(`probe: ${err.stack ?? err}`);
  process.exit(2);
});
