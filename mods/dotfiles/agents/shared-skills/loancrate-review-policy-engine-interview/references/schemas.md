# JSON Shapes

All agent outputs and the final `review.json` use these shapes. `render.mjs` validates
`review.json` and fails loudly on violations. One-line fields are ≤ 120 characters (aim
for ≤ 90) — the render rejects longer ones.

## Shared pieces

```jsonc
// Ref — a code location at the reviewed commit, relative to the repo root.
// Line numbers must come from reading the file in the snapshot (Read tool line numbers).
{ "file": "src/policy/engine.ts", "start": 59, "end": 110, "note": "optional short label", "hl": [72] }
// `hl` (challenge snippets only): line numbers inside start..end to highlight.

// Signal — one checklist item; ids and meanings are fixed in reviewer-lens.md.
// `star` only on "yes" signals that went above and beyond (max 3 across all signals);
// a starred signal's evidence says why it's impressive.
{ "id": "domain-depth", "status": "yes" | "partial" | "no", "evidence": "one line", "star": true?, "ref": Ref? }

// Concern — one line. `flag` is required for red flags and must be a red-flag id.
{ "text": "one line", "severity": "red-flag" | "watch", "flag": "messy-organization"?, "ref": Ref? }

// Challenge candidate — rated and written per reviewer-lens.md "The one challenge question".
// The reviewer may have 30 seconds with it: show the problem with a concrete case, don't narrate it.
{
  "title": "A missing field passes when the check is wrapped in `not`",  // the problem in plain words, ≤ 90 chars
  "angle": "condition-dispatch" | "externalization" | "versioning" | "scale" | "missing-data" | "api-growth" | "integration" | "other",
  "impact": "high" | "medium" | "low",
  "challenge": "design" | "gap" | "detail",
  "signal": "extensible-dispatch",            // signal id it maps to, or null
  "prototypeShortcut": false,                 // true → excluded from selection
  "intent": "A bucket with no `encryption` must not pass S3-001; that would \"fail open\" (README.md:100).",
                                              // one line: what they set out to do that this is an exception to
  "example": {                                // the concrete case: one whole input, outcomes side by side
    "given": "The scanner was denied `s3:GetEncryptionConfiguration`, so the record has no `encryption`.",
                                              // one line: the real-world situation that produces this input
    "input": {                                // the whole input, pasteable as-is; ≤ 24 lines
      "label": "POST /evaluate",              // where it goes
      "lang": "json",                         // default json; json must parse
      "code": "{\n  \"resourceType\": \"aws:s3:Bucket\",\n  …\n}",
      "hl": [9]                               // optional: 1-based lines to highlight (the value that matters)
    },
    "rows": [                                 // 1–3; `ok` = matches what they intended
      { "label": "S3-001 as shipped", "code": "notEquals(encryption, \"none\")", "result": "1 violation: S3-001", "ok": true },
      { "label": "S3-001 written with `not`", "code": "not(equals(encryption, \"none\"))", "result": "0 violations: compliant", "ok": false }
    ]
  },
  "cause": "`not` flips its child's `false`, and `false` means both \"no match\" and \"couldn't read it\".",
                                              // one line: the mechanism, in terms of their code
  "ask": "With no `encryption` field, what does your engine return for that `not` rule?",
                                              // 1–2 short questions to read aloud; no preamble
  "why": "≤ 2 sentences: the production or growth consequence.",
  "goodAnswers": ["1–3 one-line directions"],
  "refs": [Ref, ...],                          // 1–3 (2 is ideal), each ≤ 20 lines; `note` says what to
                                              // look for; `hl: [130]` highlights the exact lines
  "alreadyDocumented": "README.md Remaining rule gaps"   // optional
}
```

`example.input` is the whole thing the reviewer could paste in front of the candidate:
for a behavior gap, a complete resource their API accepts as-is, with realistic names and
every field a real scanner would send except the one the case is about; for a design
question, the complete new rule or request that forces the change, in their format. Keep
it ≤ 24 lines by dropping fields no rule reads, never by making it invalid.

`example.rows[].code` is written for the brief, not copied from their repo: the smallest
rule or call that shows the outcome on that input, ≤ 3 lines. Prefer shorthand that reads
at a glance (`not(equals(encryption, "none"))`) over the full rule JSON; the refs show the
real code. A `result` says what their engine returns for the whole input ("0 violations:
compliant"), and every one must come from running it (see SKILL.md step 3). For a design
question the rows are the places a change lands, e.g. `{ "label": "validate.ts", "code":
"case \"count\": …", "result": "compiles if forgotten; boot rejects every count rule",
"ok": false }`.

## Agent outputs

`agent-engine.json`
```jsonc
{
  "signals": [/* generic-engine, extensible-dispatch, organized-for-growth, rules-as-data, rule-versioning */],
  "externalization": {
    "status": "headed-there" | "partial" | "not-started",
    "bullets": [{ "kind": "has" | "missing", "text": "one line", "ref": Ref? }]   // 2–4
  },
  "concerns": [...],
  "challengeCandidates": [/* 2–4, fully written, rated */]
}
```

`agent-production.json`
```jsonc
{
  "signals": [/* api-hardening, tests-beyond, ci-cd, deployable, observability, domain-depth, roadmap, roadmap-execution, agent-guidance, docs */],
  "roadmap": {
    "source": "docs/ROADMAP.md" | "README.md#Extending" | null,
    "summary": "one sentence on the plan and how execution matched it",
    "items": [{ "item": "short name", "status": "done" | "partial" | "planned", "note": "one line" }]   // ≤ 8
  },
  "agentGuidance": { "summary": "one sentence with counts, e.g. 'Four scoped CONTEXT.md files (~100 lines); no CLAUDE.md or AGENTS.md.'" },
  "concerns": [...],
  "challengeCandidates": [/* 0–2 */]
}
```

`agent-history.json`
```jsonc
{
  "signals": [/* iteration-visible */],
  "aiUsage": { "summary": "1–2 sentences" },
  "iteration": { "summary": "one sentence, shown as the caption of the commit graph" },
  "focusAreas": [{ "area": "Compliance features", "weight": "major" | "moderate" | "minor", "text": "one line" }],  // ≤ 4
  "concerns": [...]
}
```

## Final `review.json` (written by synthesis, read by render.mjs)

```jsonc
{
  "schema": 2,
  "verdict": {
    "summary": "≤ 2 short sentences: what kind of candidate this is and the standout.",
    "override": { "headline": "rocket3" | "rocket2" | "rocket1" | "yes" | "qualified" | "no", "reason": "why" }   // optional; rare
  },
  "signals": [/* all 16 ids exactly once; ≤ 3 stars */],
  "concerns": [/* only real ones after the prototype lens; empty is fine */],
  "challenge": { /* the ONE selected candidate, text tightened */ },
  "challengePool": [{ "title": "...", "impact": "...", "challenge": "...", "signal": "...", "prototypeShortcut": false, "score": 7 }],  // record only; not rendered
  "externalization": { /* from engine agent */ },
  "roadmap": { /* from production agent */ },
  "agentGuidance": { /* from production agent */ },
  "aiUsage": { /* from history agent */ },
  "iteration": { /* from history agent */ },
  "focusAreas": [/* from history agent, ≤ 4 */],
  "flow": { /* optional request-flow sequence diagram, below */ }
}
```

## `flow` — request-flow sequence diagram (optional)

One `POST /evaluate` from client to response, drawn by `render.mjs` as an SVG sequence
diagram. Participants are the solution's real components (2–8, left to right in call
order; label ≤ 16 chars, sub ≤ 19 chars, usually the file). Mark `added: true` on any
participant or step the candidate built beyond the exercise's core (route → engine →
recursive condition evaluation → violations); those draw in the accent color, so the
reader sees at a glance where the solution departs from the stock shape. Step labels are
short (≤ ~40 chars) and in plain words.

```jsonc
{
  "caption": "One POST /evaluate, top to bottom. …",
  "participants": [{ "id": "router", "label": "Router", "sub": "routes/evaluate.ts", "added": false }],
  "steps": [
    { "kind": "note", "from": "router", "to": "exempt", "text": "At startup: …", "added": true },  // spans from..to
    { "from": "client", "to": "router", "text": "POST /evaluate { resource }" },                     // call
    { "from": "router", "to": "router", "text": "shape check: 400 if malformed", "added": true },  // self-step
    { "from": "index", "to": "engine", "text": "applicable rules", "return": true },               // dashed return
    { "kind": "loop-start", "text": "for each applicable rule" },
    { "kind": "loop-end" }
  ]
}
```
