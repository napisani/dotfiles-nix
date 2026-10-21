# Reviewer Lens

What the reviewer wants from the brief. Every agent and the synthesis step reads this.
When the rubric page and this file disagree, this file wins.

## Context the reviewer works under

- 15–30 min to get up to speed, partly by browsing the repo themselves; 15 min of Q&A that
  opens with the candidate's walkthrough. The brief is a companion to browsing, not a
  replacement: high signal, very little reading.
- The reviewer is not deep on every topic and may get only seconds with the challenge
  question before the call, so it shows the problem with one concrete case and points at
  the exact lines, rather than explaining it in prose.

## Brevity rules (hard)

- Signal evidence, concerns, externalization bullets, roadmap notes: **one line each**,
  aim for ≤ 90 characters (render rejects > 120). Say what is there, not how it works.
- Verdict summary: ≤ 2 short sentences.
- AI usage, agent guidance, iteration: one or two sentences each, no lists.
- No separate wins list — wins are stars on signals (below).
- One challenge question, not a menu.

## Prototype lens

This is a two-hour exercise. Judge the **broad strokes**: are the seams, boundaries and
extension points right? Not whether every production detail is finished.

- Expected prototype shortcuts, never concerns and never the challenge question: in-memory
  stores or logs, static/hardcoded data, no auth, no persistence, single process, simple
  config, missing pagination or limits. Candidates usually know and will say so.
- A shortcut matters only when it has **no seam** to replace it (e.g. storage calls
  scattered everywhere instead of behind an interface) — then the missing seam is the
  finding, not the shortcut.
- Something absent that a production version would obviously need (deploy story,
  observability, CI) is a lowlight only if it is also **not mentioned in any plan**.

## What matters

Past the gate, the signal is **what they did beyond the core and how well**: organized
for growth; production readiness; a roadmap and execution against it; rule
externalization and versioning (the reviewer's go-to thread); domain depth; agent
guidance in the repo (rare, valued); reasonable AI-usage inferences; visible iteration;
senior concerns (extensibility, maintainability, understandability).

## What does NOT matter (never flag)

- Committing Steps 1–4 in one commit; commit granularity, message style, bursts.
- Editing provided fixtures/data to match new or stricter rules — that's a positive.
- Style or naming nits, type-assertion counts, anything lint/typecheck would catch.
- Passing the hidden tests. Everyone has so far; it's a gate, not a differentiator.
- Prototype shortcuts (see above).

## Verdict

Gate: all provided tests (7) AND all hidden tests (12) pass. Any failure is a **No**.

Passing the gate is a 👍. The signals only add on top of that, as levels of rocket: a
signal left at `no` is a missing bonus, not a mark against the candidate.

| Headline | When | Suggested score |
|---|---|---|
| 🚀🚀🚀 Triple rocket | Gate passes, signal score ≥ 90%, no red flags. | 4 |
| 🚀🚀 Double rocket | Gate passes, signal score ≥ 75%, no red flags. | 4 |
| 🚀 Rocket | Gate passes, signal score ≥ 60%, no red flags. | 3–4, the Q&A decides |
| 👍 Yes | Gate passes, no red flags. | 3 |
| 🤔 Qualified | Gate passes but at least one red flag. | 2–3, hinges on Q&A |
| 👎 No | Gate fails (a real failure, not a harness problem). | 1–2 |

Signal score = (yes = 1, partial = 0.5, no = 0) / 16. The render script computes the
headline; synthesis may override only with an explicit written reason.

## Signal checklist (ids are fixed — use exactly these)

| id | Label | Yes when |
|---|---|---|
| `generic-engine` | Generic recursive engine | One recursive evaluator dispatching on condition type; array elements passed as context; no per-resource/rule special cases |
| `extensible-dispatch` | Extension points | Condition types AND operators each extend in one place (registry/strategy map, or a single exhaustive switch the compiler polices). Partial if one is scattered |
| `organized-for-growth` | Organized for growth | Clear module boundaries (engine / rules / API / domain), rules grouped sensibly, no god files |
| `rules-as-data` | Rules externalizable | Rules are validated data with a schema/validator and a loading seam — or clearly headed there. Partial = validated in code, no loading seam |
| `rule-versioning` | Rule versioning | Rules carry versions and results/evidence record which version ran. Partial = field only, or only planned |
| `api-hardening` | API boundary hardening | Request validation, error handling, sensible status codes |
| `tests-beyond` | Own test investment | Meaningful tests beyond the provided ones |
| `ci-cd` | CI/CD | A pipeline that runs tests/typecheck/lint |
| `deployable` | Deployable | Dockerfile or equivalent, env-driven config, health endpoint, graceful shutdown (partial for some) |
| `observability` | Observability | Structured logging, metrics or tracing (console.log alone = no) |
| `domain-depth` | Domain depth | Security/compliance thinking beyond the brief |
| `roadmap` | Roadmap written | A written plan / next steps / deferred list in the repo |
| `roadmap-execution` | Executed on plan | Delivered meaningful slices of the plan; "no" if there is no plan |
| `agent-guidance` | Agent guidance in repo | CLAUDE.md / AGENTS.md / `.claude` rules / context docs / specs aimed at agents |
| `iteration-visible` | Visible iteration | History shows reworking their own earlier code, not only additions |
| `docs` | Docs for humans | README explains how to run, the design, and decisions |

### Stars ⭐ (these replace a wins list)

A `yes` signal gets `"star": true` when the candidate went clearly above and beyond on
that concern — polished, thoughtful, more than the basic "met" bar. **At most 3 stars.**
A starred signal's evidence line says why it's impressive, not just that it's met.
Zero stars is fine.

## Red flags (the only things that lower the headline)

`severity: "red-flag"` only for these; everything else is at most `"watch"`.

- `nothing-beyond-core` — little or no meaningful work past Steps 1–4.
- `messy-organization` — hard to follow or extend: god file mixing concerns, duplicated
  logic, dead code, contradictory patterns. (A long but cohesive file is not this.)
- `hardcoded-engine` — per-resource or per-rule special-casing in the engine.
- `missing-basics-unplanned` — an obvious production basic (input validation, own tests,
  error handling) is absent AND not mentioned in any plan. Missing CI is not one of
  these: it is worth flagging, but only ever as a `watch`.
- `broken-own-checks` — their own typecheck/lint/test/build fail at HEAD (after ruling out
  an environment/harness cause).

## The one challenge question

Its purpose is to see how the candidate takes feedback: something that objectively could
be better, raised the way a friendly code reviewer would. Pick it; don't hand the
reviewer a menu.

Agents rate every candidate issue they find:

- `impact`: `high` (would change the design in production or at 10× growth) · `medium`
  (real maintainability/extensibility cost) · `low` (worth improving, small cost)
- `challenge`: `design` (pushes back on a deliberate design choice they must defend) ·
  `gap` (a missing piece they'd likely concede) · `detail` (small fix)
- `signal`: the signal id it maps to, if any
- `prototypeShortcut`: true when it's an expected prototype shortcut → excluded

Score = impact (high 3 · medium 2 · low 1) + challenge (design 3 · gap 2 · detail 1)
+ 1 if it maps to a signal. Highest score wins. Ties go first to a challenge that is an
exception to something the candidate set out to do (a principle in their README, a
pattern they applied elsewhere), then to architecture/extensibility angles over
functional bugs. If nothing is high impact, take the best medium; the point is to have
one good question, not a perfect one.

### Writing it: show, don't narrate

The reviewer may get 30 seconds with this section right before the call, and has to talk
about it live. They should be able to say "oh, I get it" from the title and the example
alone. Every field is short and concrete:

- **title** — the problem as you'd say it to a colleague who hasn't seen the code: what
  happens, in plain words. "A missing field passes when the check is wrapped in `not`",
  not "Fail-closed doesn't survive negation". No coined labels, no "X doesn't survive Y".
- **intent** — one line on what they set out to do that this is an exception to (their
  principle, claim or pattern). It anchors the question in their own work.
- **example** — the concrete case, built so the reviewer can show it rather than
  describe it:
  - `given`: one line on the real-world situation that produces the input ("the scanner
    was denied `s3:GetEncryptionConfiguration`, so the record has no `encryption`"), not
    a description of the input.
  - `input`: the whole input, pasteable as-is: a complete resource their API accepts, with
    realistic names and the fields a real scanner sends (or, for a design question, the
    complete new rule or request in their format). Prefer an input that breaks a rule
    they shipped; when none does, use the smallest realistic rule change.
  - `rows`: 1–3 rules or calls run on that input, with what their engine returns,
    marked as matching their intent or not. Contrast is the point: the way that works
    next to the way that doesn't. Every outcome comes from running the input.
- **cause** — one line: why it happens, in terms of their code.
- **ask** — one or two short questions the reviewer can read aloud, built on the example
  ("With no `encryption` field, what does your engine return for that `not` rule?"). No
  preamble, no "If this were a PR…", no restating the problem. When they documented the
  trade-off, ask them to defend or revisit it.
- **refs** — ideally two, ≤ 20 lines each, with `hl` on the exact lines that matter and a
  `note` saying what to look for there ("`not` just flips the result").
- **why** — ≤ 2 sentences on the production consequence; **goodAnswers** — 1–3 one-liners.

Define any term from the candidate's code or docs (their feature names, "outcomes",
"tiers") in a few plain words the first time it appears, e.g. "the rule index (a lookup
of rules by resource type, built at startup)".
