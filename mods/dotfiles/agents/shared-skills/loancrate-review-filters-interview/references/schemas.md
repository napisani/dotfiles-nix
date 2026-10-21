# JSON Shapes

All agent outputs and the final `review.json` use these shapes. `render.mjs` validates
`review.json` and fails loudly on violations. One-line fields are ≤ 120 characters (aim
for ≤ 90) — the render rejects longer ones.

## Shared pieces

```jsonc
// Ref — a code location at the reviewed commit, relative to the repo root.
// Line numbers must come from reading the file in the snapshot (Read tool line numbers).
{ "file": "packages/server/filters.ts", "start": 12, "end": 40, "note": "optional short label", "hl": [18] }
// `hl` (challenge snippets only): line numbers inside start..end to highlight.

// Signal — one checklist item; ids and meanings are fixed in reviewer-lens.md.
// `star` only on "yes" signals that went above and beyond (max 3 across all signals);
// a starred signal's evidence says why it's impressive.
{ "id": "shared-model", "status": "yes" | "partial" | "no", "evidence": "one line", "star": true?, "ref": Ref? }

// Concern — one line. `flag` is required for red flags and must be a red-flag id.
{ "text": "one line", "severity": "red-flag" | "watch", "flag": "duplication"?, "ref": Ref? }

// Challenge candidate — rated and written per reviewer-lens.md "The one challenge question".
{
  "title": "Typing fast can leave the table showing an older search",   // plain words, ≤ 90 chars
  "angle": "single-source" | "request-races" | "database-seam" | "dates" | "validation" | "semantics" | "and-only" | "ai" | "other",
  "impact": "high" | "medium" | "low",
  "challenge": "design" | "gap" | "detail",
  "signal": "scale-readiness",                // signal id it maps to, or null
  "prototypeShortcut": false,                 // true → excluded from selection
  "intent": "README: \"filters update as you type\" (README.md:40).",   // one line: what they set out to do
  "example": {
    "given": "A loan officer types \"Mart\" quickly into last name includes.",   // one line
    "input": {                                // the whole request or definition; ≤ 24 lines
      "label": "GET /borrowers",
      "lang": "http",                         // "json" (default; must parse) | "http" | "bash" | "typescript" | "text"
      "code": "GET /borrowers?filters=[{\"field\":\"lastName\",\"operator\":\"includes\",\"value\":\"M\"}]",
      "hl": [1]                               // optional 1-based lines to highlight
    },
    "rows": [                                 // 1–3; `ok` = matches what they intended
      { "label": "value \"M\" (sent first)", "code": "lastName includes \"M\"", "result": "41 borrowers", "ok": true },
      { "label": "value \"Mart\" (sent last)", "code": "lastName includes \"Mart\"", "result": "2 borrowers", "ok": true },
      { "label": "table after \"M\" lands last", "code": "no abort, no sequence check", "result": "shows the 41", "ok": false }
    ]
  },
  "cause": "`useEffect` fires a request per keystroke and sets state from whichever resolves last.",
  "ask": "If the \"M\" response arrives after \"Mart\", what does the table show?",
  "why": "≤ 2 sentences: the user or production consequence.",
  "goodAnswers": ["1–3 one-line directions"],
  "refs": [Ref, ...],                         // 1–3 (2 is ideal), each ≤ 20 lines, with `note` and `hl`
  "alreadyDocumented": "README.md Next steps" // optional
}
```

`example.rows[].code` is written for the brief, not copied from their repo: the smallest
filter, request or edit that shows the outcome, ≤ 3 lines. Every request `result` comes
from `probe.mjs --filters` (SKILL.md step 4); UI outcomes come from the product agent's
notes. For a design question the rows are the places a change lands, e.g.
`{ "label": "client/FilterRow.tsx", "code": "OPERATORS.string", "result": "UI never offers it", "ok": false }`.

## Agent outputs

`agent-architecture.json`
```jsonc
{
  "signals": [/* shared-model, extensible-filters, organized-for-growth, type-safety, runtime-validation, server-depth, scale-readiness, tests-beyond, prod-hardening */],
  "scale": {
    "status": "ready" | "partial" | "not-started",
    "bullets": [{ "kind": "has" | "missing", "text": "one line", "ref": Ref? }]   // 2–5: debounce, stale responses, server paging, query seam, indexes/caching
  },
  "flow": { /* optional request-flow diagram, below */ },
  "concerns": [...],
  "challengeCandidates": [/* 2–4, fully written, rated */]
}
```

`agent-product.json`
```jsonc
{
  "signals": [/* visual-design, ux-details, features-beyond, natural-language-filters, and-or-logic, docs */],
  "screens": [{ "file": "shots/01-initial.jpeg", "caption": "one line" }],     // 2–4, files under OUT
  "features": [{ "name": "URL-synced filters", "status": "works" | "partial" | "broken", "note": "one line", "ref": Ref? }],  // ≤ 10, built only; plans go in roadmap
  "specCheck": [{ "item": "Only filterable fields in the dropdown", "ok": true, "note": "one line" }],   // the spec items, as clicked
  "roadmap": { "source": "<file>#<heading>, e.g. docs/PLAN.md#Next" | null, "summary": "one sentence", "items": [{ "item": "…", "status": "done" | "partial" | "planned", "note": "…" }] },  // optional, ≤ 8 items
  "concerns": [...],
  "challengeCandidates": [/* 0–2: UI bugs or product-semantics angles found while clicking */]
}
```

`agent-history.json`
```jsonc
{
  "signals": [/* throughput, agent-guidance, tooling, ci-deploy */],
  "mvp": { "minute": 52, "sha": "c774fbb", "evidence": "one line: the commit where all three steps first worked, and why you believe it" },  // minute null if unknown
  "aiUsage": { "summary": "1–2 sentences" },
  "agentGuidance": { "summary": "one sentence with counts" },
  "iteration": { "summary": "one sentence, shown as the caption of the commit graph" },
  "focusAreas": [{ "area": "UI polish", "weight": "major" | "moderate" | "minor", "text": "one line" }],  // ≤ 4
  "concerns": [...]
}
```

## Final `review.json` (written by synthesis, read by render.mjs)

```jsonc
{
  "schema": 1,
  "verdict": {
    "summary": "≤ 2 short sentences: what kind of candidate this is and the standout.",
    "override": { "headline": "rocket3" | "rocket2" | "rocket1" | "yes" | "qualified" | "no", "reason": "why" }   // optional; rare
  },
  "signals": [/* all 19 ids exactly once; ≤ 3 stars; weights live in render.mjs */],
  "concerns": [/* only real ones after the prototype lens; a confirmed probe failure needs flag "core-bug" */],
  "challenge": { /* the ONE selected candidate, text tightened */ },
  "challengePool": [{ "title": "...", "impact": "...", "challenge": "...", "signal": "...", "prototypeShortcut": false, "score": 7 }],  // record only
  "screens": [/* from product agent, ≤ 4 */],
  "features": [/* from product agent, ≤ 10 */],
  "scale": { /* from architecture agent */ },
  "roadmap": { /* optional, from product agent */ },
  "aiUsage": { /* from history */ },
  "agentGuidance": { /* from history */ },
  "iteration": { /* from history */ },
  "focusAreas": [/* from history, ≤ 4 */],
  "mvp": { /* from history */ },
  "flow": { /* optional, from architecture */ }
}
```

## `flow` — request-flow sequence diagram (optional)

One filter change, from the user's edit to the rendered table, drawn as an SVG sequence
diagram. Participants are the solution's real components (2–8, left to right in call
order; label ≤ 16 chars, sub ≤ 19 chars, usually the file). Mark `added: true` on any
participant or step beyond the stock shape (filter row → fetch `/borrowers` → server
filters the array → table re-renders); those draw in the accent color.

```jsonc
{
  "caption": "One filter edit, top to bottom. …",
  "participants": [{ "id": "row", "label": "FilterRow", "sub": "FilterRow.tsx", "added": false }],
  "steps": [
    { "from": "row", "to": "hook", "text": "onChange(filter)" },                      // call
    { "from": "hook", "to": "hook", "text": "debounce 300 ms", "added": true },        // self-step
    { "from": "server", "to": "hook", "text": "Borrower[]", "return": true },          // dashed return
    { "kind": "note", "from": "hook", "to": "server", "text": "…", "added": true },    // spans from..to
    { "kind": "loop-start", "text": "for each filter" },
    { "kind": "loop-end" }
  ]
}
```
