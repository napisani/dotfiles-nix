# Reviewer Lens

What the reviewer wants from the brief. Every agent and the synthesis step reads this.
When the rubric and this file disagree, this file wins.

## Context the reviewer works under

- ~15 min to get up to speed, partly by running the app and browsing the repo themselves;
  ~15 min of Q&A. The brief is a companion to that, not a replacement: high signal, very
  little reading.
- The reviewer may get only seconds with the challenge question before the call, so it
  shows the problem with one concrete case and points at the exact lines, rather than
  explaining it in prose.

## Brevity rules (hard)

- Signal evidence, concerns, feature notes, scale bullets, screenshot captions: **one line
  each**, aim for ≤ 90 characters (render rejects > 120). Say what is there, not how it
  works.
- Verdict summary: ≤ 2 short sentences.
- AI usage, agent guidance, iteration: one or two sentences each, no lists.
- No separate wins list — wins are stars on signals (below).
- One challenge question, not a menu.

## Prototype lens

This is a two-hour exercise. Judge the **broad strokes**: are the seams, boundaries and
extension points right, and does what they built work and look good? Not whether every
production detail is finished.

- Expected prototype shortcuts, never concerns and never the challenge question: data in
  a JSON file or memory, no database, no auth, no deploy story, no CI, no logging or
  security middleware (present, they earn the `ci-deploy` and `prod-hardening` bonuses), filtering with
  `Array.filter` over 100 rows. Candidates usually know and will say so.
- A shortcut matters only when it has **no seam** to replace it (e.g. filter logic tangled
  into the route handler so it could never become a SQL `WHERE` clause) — then the missing
  seam is the finding, not the shortcut.
- Tests are a bonus, not a basic: a 4-scorer "opted out of tests for time". Missing tests
  are never a concern.

## What matters

The doc tells candidates what we look for, in order: **throughput** (how much they got
done and working), **cleanliness** (DRY, readable, organized), and **going well beyond the
minimum** (features, design, server-side tech) — "a big part of what this test is."

Interviewer scores on past submissions turned on the same things, consistently:

- **Throughput.** A working MVP (all three steps) within about the first hour, then a lot
  delivered after it. Submissions where the MVP took most of the two hours scored a No even
  when the code was clean and tested.
- **Standout extras, not commodity ones.** Sorting, URL state, debounce, clear-all, result
  counts, pagination and a column picker are now expected of everyone using AI; they don't
  lift a score on their own. What did: AI inside the product (natural-language filters,
  explanations, scoring or decision engines), OR logic with a clear UI, domain features (credit or risk indicators, aggregates), saved views, OR groups, a theme
  the user can switch (dark/light toggle) or a brand theme, export, a modern typed stack
  (tRPC, TanStack) chosen with reasons. Dark styles that only follow the OS setting are
  commodity.
- **Code structure.** The frontend split into components, hooks and an API module (not one
  `App.tsx`); the backend split by responsibility (routes, validation, filtering, data),
  not collapsed into one file; styles organized (component styles or a styling system, not
  one sprawling `styles.css`).
- **Runtime validation with a schema library.** zod (or similar) at the API boundary,
  shared by client and server, was praised every time it appeared; hand-rolled imperative
  parsing was a critique every time, even when it worked.
- **Sensible libraries.** Reaching for established libraries where they fit (zod, TanStack
  Query/Table, shadcn/Radix) reads as judgment; hand-rolling everything reads as time spent
  on the wrong things.
- **Time on what matters.** Post-MVP time going mostly to fringe polish (icons, favicons,
  formatting minutiae) while the structure stayed monolithic counted against.
- **Small tells reviewers notice:** marital status as a dropdown of `MARITAL_STATUSES` (the
  starter exports it as a hint); clear date handling rather than regexes scattered through
  the code.

Tests, docs, agent guidance and tooling are good hygiene and count a little; they never
make up for slow throughput or commodity extras.

## What does NOT matter (never flag)

- Commit granularity, message style, bursts, squashed or rebased history.
- Regenerating or editing `borrowers.json`, changing ports, swapping libraries or package
  managers, restructuring the starter — all allowed ("edit any existing code").
- Style or naming nits, type-assertion counts, anything lint/typecheck would catch.
- Case-sensitivity, trimming, or empty-value handling choices — the spec is silent. They
  are product questions worth asking about, not bugs.
- Prototype shortcuts (see above), including missing tests.
- Running a few minutes past the two hours.

## Verdict

Gate (from `probe.mjs`): filtering happens on the server and every step works — string,
number and date filters each return exactly the borrowers the spec calls for, AND-ed.

- A step that doesn't work at all, or client-side filtering → **No**.
- Every step works but some case returns wrong rows (a real bug, confirmed) → the gate
  still passes, with a `core-bug` red flag → **Qualified**.

Passing the gate is a 👍. The signals only add on top of that, as levels of rocket: a
signal left at `no` is a missing bonus, not a mark against the candidate.

| Headline | When | Suggested score |
|---|---|---|
| 🚀🚀🚀 Triple rocket | Gate passes, signal score ≥ 90%, no red flags. | 4 |
| 🚀🚀 Double rocket | Gate passes, signal score ≥ 75%, no red flags. | 4 |
| 🚀 Rocket | Gate passes, signal score ≥ 60%, no red flags. | 3–4, the Q&A decides |
| 👍 Yes | Gate passes, no red flags. | 3 |
| 🤔 Qualified | Gate passes but at least one red flag. | 2–3, hinges on Q&A |
| 👎 No | A step doesn't work, or filtering isn't on the server. | 1–2 |

Signal score = Σ (yes = 1, partial = 0.5, no = 0) × weight / 25, where the six signals
marked ×2 below count double. The render script computes the
headline, including 🤔 for any red flag; synthesis overrides only when the computed
headline is wrong, with an explicit written reason.

## Signal checklist (ids are fixed — use exactly these)

| id | Label | ×2 | Yes when |
|---|---|---|---|
| `throughput` | Throughput | ×2 | All three steps working within ~60 min of the first commit, and substantial work after it. Partial = MVP by ~75 min, or early MVP with little after. No = MVP past ~75 min |
| `features-beyond` | Standout features | ×2 | At least one standout extra that works (see "What matters"), on top of the commodity ones. Partial = only commodity extras (sorting, URL state, debounce, pagination, column picker…) |
| `organized-for-growth` | Organized for growth | ×2 | Frontend split into components/hooks/api; backend split by responsibility; styles organized. Partial = one of the three is a monolith |
| `runtime-validation` | Validated at the boundary | ×2 | Filter requests validated with a declarative schema library (zod, ArkType, Valibot, TypeBox…), ideally the same schema shared with the client, with 4xx and a message on bad input. Partial = hand-rolled imperative validation that works. No = bad input crashes or silently matches nothing |
| `visual-design` | Looks great | ×2 | Clearly better than the wireframes: designed controls (not browser-default selects), readable labels (not raw `firstName` keys), consistent spacing and type, a designed table. Partial = tidy CSS on default controls or raw field keys |
| `natural-language-filters` | Natural-language filters | ×2 | Filters can be entered in plain language — "married borrowers over 40 with credit above 700" — through an LLM or an alternative (a parser, query syntax, fuzzy matching), and the result becomes the same structured filters the UI shows. Yes = works, output validated against the filter schema before it's applied, and the user sees and can edit the parsed filters. Partial = works but unvalidated or opaque, or demo-quality |
| `shared-model` | One source of truth | | Fields, their types and operators (and labels) are defined once, in `shared`, and both client and server derive from it. Partial = shared types but per-side copies of the field/operator lists |
| `extensible-filters` | Extension points | | A new field or operator lands in one place (a map/registry, or one exhaustive switch the compiler polices) on each side. Partial if per-type logic is copy-pasted |
| `type-safety` | Types carry weight | | Filters are a discriminated union by field type (or equivalent) so a number operator can't pair with a string field; typed API contract shared by both sides |
| `ux-details` | Reads between the lines | | Type-appropriate inputs (date picker, number input, marital-status select), operator resets on field change, remove/clear filters, empty/loading/error states, result count, readable labels and formatting |
| `server-depth` | Server-side depth | | Server work beyond one filter function: server-side sort/paging, a query layer or DB, caching, typed RPC (tRPC/GraphQL), request logging |
| `and-or-logic` | AND / OR logic | | Attempted OR alongside AND (OR groups, nested conditions) with a UI a user understands at first sight. Partial = attempted but confusing (unclear precedence, unlabeled grouping) or only a global "match all / any" switch. No = AND only — a missing bonus, never a mark against them |
| `scale-readiness` | Built for scale | | Scalability work the author actually introduced, from: debounced input, stale-response handling (abort, sequence check, query cache), server pagination, prefetching, caching (frontend query cache or backend), virtualization, precomputed indexes. Yes = work on both client and server; partial = one or two pieces. Evidence names what's there |
| `tests-beyond` | Test layers | | Unit tests of filter semantics are the floor (partial). Yes = unit tests plus at least one more layer: API/integration tests (e.g. supertest against the app), e2e (Playwright/Cypress), or database tests. Evidence lists the layers and rough counts. A bonus — never required |
| `tooling` | Quality tooling | | Local typecheck/lint/format/test scripts that pass, plus pre-commit hooks. Partial = some scripts |
| `ci-deploy` | CI/CD & deployment | | A CI pipeline that runs their checks (typecheck, lint, test, build) AND a deploy artifact: a Dockerfile/compose, platform config (Vercel, Fly, Render, Netlify, Railway, Procfile), or a production build where the server serves the built client. Partial = one of the two, or a written deploy plan with substance. A bonus — absence is never a concern |
| `prod-hardening` | Production hardening | | Productionization in the code, across several of: observability (structured/request logging, request ids, metrics); error handling (server error middleware, a client error boundary, user-facing error states); security (CORS allowlist, helmet, rate limiting, body-size limits); operations (env-driven config, health/readiness endpoint, graceful shutdown); PII care (borrower emails, phones and birth dates kept out of logs or masked). Yes = three or more areas; partial = one or two. Evidence names them. A bonus — absence is never a concern |
| `docs` | Docs for humans | | README covers how to run, the design, decisions/assumptions (case, dates), and next steps |
| `agent-guidance` | Agent guidance in repo | | CLAUDE.md / AGENTS.md / plans or specs written for agents |

### Stars ⭐ (these replace a wins list)

A `yes` signal gets `"star": true` when the candidate went clearly above and beyond on
that concern — polished, thoughtful, more than the basic "met" bar. **At most 3 stars.**
Most candidates now style their UI with AI help, so `visual-design` is starred only for
design that is distinctive (a theme or dark mode, a coherent design system, details that
delight — the "badass design" of the gold-standard 4), never for a clean table.
A starred signal's evidence line says why it's impressive, not just that it's met.
Zero stars is fine.

## Red flags (the only things that lower the headline)

`severity: "red-flag"` only for these; everything else is at most `"watch"`.

- `core-bug` — a confirmed probe failure: some string/number/date/AND case returns the
  wrong borrowers. Name the case.
- `spec-miss` — a requirement written in the spec visibly missing: the field dropdown
  offers fields that can't be filtered, operators don't follow the field's type, filters
  don't AND together, or a step's UI is absent. Only those: an empty-results state,
  removing filters, operator resets and wireframe copy are polish (`ux-details`), never
  `spec-miss`.
- `duplication` — notable copy-paste of logic: per-type filtering or rendering code
  repeated across components, or the filter semantics implemented twice (client and
  server). Field names or operator lists appearing in a few places is a `shared-model`
  partial, not this flag.
- `messy-organization` — hard to follow or extend: the whole frontend in one component
  (`App.tsx` holding state, fetching, filter rows and the table), the backend collapsed into
  one file mixing routing, parsing and filtering, dead code, contradictory patterns. (A long
  but cohesive file is not this.)
- `slow-mvp` — the three steps weren't all working until past ~75 minutes from the first
  commit, or less than ~40 minutes of work followed the MVP: little time was left for
  anything beyond the spec (`mvp.minute` from history).
- `nothing-beyond-core` — little or no meaningful work past the three steps.
- `unstyled-ui` — the UI is the starter's raw table plus browser-default controls; the doc
  asked them to make it look great.
- `broken-own-checks` — their own typecheck/lint/build/test fail at HEAD (after ruling out
  an environment cause).

## The one challenge question

Its purpose is to see how the candidate takes feedback: something that objectively could
be better, raised the way a friendly code reviewer would. Pick it; don't hand the reviewer
a menu.

Agents rate every candidate issue they find:

- `impact`: `high` (would change the design in production or at 1M borrowers, or a bug a
  user hits) · `medium` (real maintainability/extensibility cost) · `low` (worth
  improving, small cost)
- `challenge`: `design` (pushes back on a deliberate design choice they must defend) ·
  `gap` (a missing piece they'd likely concede) · `detail` (small fix)
- `signal`: the signal id it maps to, if any
- `prototypeShortcut`: true when it's an expected prototype shortcut → excluded

Score = impact (high 3 · medium 2 · low 1) + challenge (design 3 · gap 2 · detail 1)
+ 1 if it maps to a signal. Highest score wins. Ties go first to a challenge that is an
exception to something the candidate set out to do (a principle in their README, a pattern
they applied elsewhere), then to something the reviewer can **show live** in the running
app or with one request, then to architecture/extensibility over cosmetic UI. If nothing
is high impact, take the best medium; the point is to have one good question, not a
perfect one.

### Writing it: show, don't narrate

The reviewer may get 30 seconds with this section right before the call, and has to talk
about it live. They should be able to say "oh, I get it" from the title and the example
alone. Every field is short and concrete:

- **title** — the problem as you'd say it to a colleague who hasn't seen the code: what
  happens, in plain words. "Typing fast can leave the table showing an older search", not
  "Missing request sequencing". No coined labels.
- **intent** — one line on what they set out to do that this is an exception to (their
  principle, claim or pattern). It anchors the question in their own work.
- **example** — the concrete case, built so the reviewer can show it rather than describe
  it:
  - `given`: one line on the real-world situation ("a loan officer types 'Mart' quickly
    into lastName includes"), not a description of the request.
  - `input`: the whole thing the reviewer could paste or do: the exact request their API
    accepts (URL with query, or POST body), or for a design question the complete new
    field/operator definition in their format. ≤ 24 lines.
  - `rows`: 1–3 requests, edits or UI actions with what their app returns, marked as
    matching their intent or not. Contrast is the point: the way that works next to the
    way that doesn't. Every request outcome comes from running it (`probe.mjs --filters`).
- **cause** — one line: why it happens, in terms of their code.
- **ask** — one or two short questions the reviewer can read aloud, built on the example.
  No preamble, no "If this were a PR…", no restating the problem. When they documented the
  trade-off, ask them to defend or revisit it.
- **refs** — ideally two, ≤ 20 lines each, with `hl` on the exact lines that matter and a
  `note` saying what to look for there.
- **why** — ≤ 2 sentences on the user or production consequence; **goodAnswers** — 1–3
  one-liners.

Define any term from the candidate's code or docs (their feature names, "views", "groups")
in a few plain words the first time it appears.
