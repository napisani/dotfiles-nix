---
name: loancrate-review-filters-interview
description: Review a candidate's Filters interview submission (Loancrate Senior Software Engineer, full-stack borrower-filters exercise). Runs their checks in a clean snapshot, probes their filtering API against the spec, clicks through the running app for screenshots and QA, analyzes it with three parallel agents, and publishes a skimmable reviewer brief — verdict, starred signals, and one challenge question backed by code snippets — as a private Artifact. Use when asked to review a filters interview repo or candidate.
---

# Review Filters Interview

Produces a brief the reviewer can absorb in minutes before a 15-minute Q&A. Consistency
comes from scripts and fixed references; judgment comes from three scoped agents; the page
comes from a fixed template.

**Arguments:** the candidate's **git URL** (start at step 0: clone, open, review) or their
existing clone directory (default: current directory; start at step 1). Optional
`--name "First Last"` to skip the name lookup; optional `--ref <commit>` to review an
earlier commit (e.g. the last one before the deadline).

**Paths** (substitute absolute paths in commands and prompts)

- `SKILL` = this skill's base directory
- `ROOT` = the interviews folder: `golden/` (a clone of `loancrate/filters-interview`, the
  starter) beside one clone per candidate. The scripts find it from `--root`,
  `$FILTERS_INTERVIEWS`, or the current directory (or its parent) when it holds `golden/`.
- `OUT` = `<candidate dir>/../_reviews/<candidate-folder>/` — facts, the probe adapter,
  screenshots, agent outputs, `review.json`, `review.html`, `snapshot/` (the reviewed
  commit, with its own install), `logs/`

**First run on a machine:** if a script exits 5 (no interviews folder or `golden/`), follow
`SKILL/AGENTS.md` to set it up, then resume where you stopped.

**References** (read only what your step needs)

- `references/rubric.md` — the spec, wireframes, Notion criteria and score examples
- `references/reviewer-lens.md` — what the reviewer values, verdict rules, signal and red-flag ids
- `references/challenge-playbook.md` — challenge angles with primer answers
- `references/adapter.md` — how to write the probe adapter
- `references/schemas.md` — JSON shapes for agent outputs and `review.json`
- `references/agents/{architecture,product,history}.md` — agent instructions

## 0. Intake (when given a git URL)

```bash
node SKILL/scripts/intake.mjs <git-url> [--name "First Last"] >"$SCRATCH/intake.log" 2>&1
```

It reads the candidate's name from a calendar event "<Name> // … Filters …" near now (when
a calendar script is installed; see `AGENTS.md`), falling back to their GitHub profile
name. It clones into `ROOT/<first-last>` (or pulls if that clone exists), opens the folder
in the editor, and prints JSON.

- Exit 3: no name found. Ask the user for it and re-run with `--name`.
- Exit 4: the folder exists with a different remote. Report it and stop.
- Exit 5: this machine isn't set up. Follow `SKILL/AGENTS.md`, then re-run.
- `nameMismatch: true`: the calendar and GitHub names share no word. Ask the user to
  confirm who this is before going further.

Tell the user in one line that the clone is open, then continue with its `dir`.

## 1. Collect (deterministic, ~10 s cached, 1–2 min on first install)

```bash
node SKILL/scripts/collect.mjs <candidateDir> [--ref <commit>] >"$SCRATCH/collect.log" 2>&1
```

Check the exit code, then read the log (a short summary). Exit 2 means collection broke
(usually the dependency install): report the message and stop. Exit 5 means no `golden/`
was found: follow `SKILL/AGENTS.md`.

It snapshots the commit, installs dependencies inside the snapshot, runs their own
typecheck/lint/build/test, and gathers git history, inventory, docs, dependency changes,
the borrower data their server loads, their ports and start commands, and detections into
`OUT/facts.json`.

A failing candidate check: read its log tail in facts (`checks[].tail`). An environment
cause (missing binary, package-manager refusal, network) is not the candidate's fault; say
so in the synthesis instead of flagging it.

## 2. Probe the API (the gate, ~3 min)

Write `OUT/probe/adapter.mjs` per `references/adapter.md`: read their client's request
code and the server route, then map the spec's filters onto their request and their
response back to ids. Verify it with one-off requests, then run the suite:

```bash
node SKILL/scripts/probe.mjs OUT --filters '[]'      # total must equal the dataset size
node SKILL/scripts/probe.mjs OUT                     # the suite; adds `probe` to facts.json
```

The probe starts their server from the snapshot on a free port (their port numbers are
rewritten in the snapshot only, and restored afterwards), sends string, number, date and
AND cases chosen to catch the usual bugs, and compares each result with a reference
implementation of the spec over their own data. It also records unspecified behavior
(case, trimming, empty and invalid values) without judging it.

- `PASS`: continue.
- `BUG` (a case returned wrong rows): confirm it's real before it costs the candidate
  anything. Re-send that case with `--filters`, check what their UI sends for the same
  filter, and read their filter code. An adapter mistake: fix the adapter and re-run. A
  real bug: it becomes a `core-bug` red flag in step 4.
- `FAIL` (a step returns nothing right, or filtering is client-side): confirm the same way;
  the adapter is the usual suspect.
- `SUSPECT` (the unfiltered request doesn't return their data): fix the adapter or its
  `dataset` / `start` / `ports` overrides. If it can't be fixed, continue and override the
  verdict in step 4 with the reason.

## 3. Analyze (three agents in parallel, ~3–8 min)

Launch all three in **one message**, `run_in_background: true`, `subagent_type:
general-purpose`:

| Agent | Model | Prompt |
|---|---|---|
| architecture | (omit — inherits) | `Read SKILL/references/agents/architecture.md and follow it exactly.` + `FACTS=`, `SNAPSHOT=`, `SKILL=`, `OUT=OUT/agent-architecture.json` |
| product | (omit — inherits) | `Read SKILL/references/agents/product.md …` + `FACTS=`, `SNAPSHOT=`, `SKILL=`, `OUT=OUT` (its JSON goes to `OUT/agent-product.json`), `SESSION=review-<candidate-folder>` |
| history | `sonnet` | `Read SKILL/references/agents/history.md …` + `FACTS=`, `CANDIDATE_DIR=`, `SKILL=`, `OUT=OUT/agent-history.json` |

Use absolute paths in the prompts. Without a tool for launching agents, do the three in
turn yourself (product last, since it runs the app), writing the same three files. While
they run, read `reviewer-lens.md` and `challenge-playbook.md` for synthesis. Don't redo the agents' work. When the product agent
finishes, confirm `node SKILL/scripts/app.mjs status OUT` reports nothing running; if it
does, run `app.mjs stop OUT`.

## 4. Synthesize `OUT/review.json`

Read the three agent files and the `probe` and `checks` keys of `facts.json`. Merge per
`references/schemas.md`. The reviewer is time-boxed and runs the app alongside the brief,
so everything obeys the lens's brevity rules (the renderer enforces the limits).

- **signals** — all 19 ids exactly once (architecture 9, product 6, history 4). Change an
  agent's call only when the evidence contradicts it. Keep **at most 3 stars**, for the
  strongest above-and-beyond work; a starred line says why it's impressive.
- **red flags from timing and structure** — `mvp.minute` past ~75, or under ~40 minutes of
  work after it, is `slow-mvp`; a
  one-component frontend or one-file backend is `messy-organization`. Both lower the
  headline to 🤔, which matches how interviewers scored such submissions.
- **concerns** — apply the lens strictly, including the prototype lens: JSON data, no DB,
  no auth, no tests are never concerns. Keep red flags only from its list. A confirmed
  probe failure is a `core-bug` red flag naming the case (render refuses a `BUG` gate
  without one). Unspecified-behavior choices (case, trimming) are not bugs. Empty is fine.
- **challenge** — pool every agent's `challengeCandidates`, drop `prototypeShortcut` ones,
  and score each with the lens formula. Take the top one, using the lens's tie-breaks.
  Then make it graspable in 30 seconds, per the lens's "Writing it: show, don't narrate":
  - **Run the input.** For each row that is a request (design rows that name places a
    change lands aren't), run it with
    `node SKILL/scripts/probe.mjs OUT --filters '<json>'` and put what came back in
    `result` (replace any "(traced)" from an agent). For a UI row, use the product agent's
    notes. A wrong example is worse than none.
  - Read each ref in the snapshot (Read with offset/limit), cut it to ≤ 20 lines around
    the point, and set `hl` on the exact lines.
  - Reread the title and ask as if cold: plain words, no coined labels, no preamble.
  Record the scored pool in `challengePool`, which is not rendered.
- **verdict.summary** — ≤ 2 short sentences: what kind of candidate this is and the
  standout. Don't restate the score. Set `verdict.override` only when the computed
  headline is wrong, with a concrete reason (red flags already produce 🤔).
- **scale, flow** from architecture; **screens, features, roadmap** from product;
  **mvp, aiUsage, agentGuidance, iteration, focusAreas** from history.

## 5. Render

```bash
node SKILL/scripts/render.mjs OUT
```

It validates `review.json` (exit 1 lists every problem: fix and re-run), embeds the
screenshots, and computes the headline: 👎 if a step doesn't work or filtering is
client-side, 🤔 on any red flag (including a confirmed bug), else 👍 with rockets on top:
🚀 at ≥ 60% of weighted signal points, 🚀🚀 at ≥ 75%, 🚀🚀🚀 at ≥ 90%.

## 6. Publish

Publish `OUT/review.html` with the Artifact tool: `icon: "clipboard"`, description
`Reviewer brief for <Name>'s Filters interview submission`. It is private by default. To
refresh a candidate reviewed in an earlier session, find its URL with `action: "list"` and
pass it as `url` so the link stays the same.

## 7. Reply

The link, then one line: headline and suggested score, plus the challenge title. Add
anything only if the user must act on it (a harness or environment problem).

## Guardrails

- Never edit the candidate's code or their clone. Everything runs in `OUT/snapshot`; the
  only edits there are `app.mjs`'s port rewrites, which `stop` restores.
- Leave nothing running: every `app.mjs start` (yours or an agent's) ends with
  `app.mjs stop OUT`, and every browser session with `playwright-cli -s=<session> close`.
- Don't re-run installs outside `collect.mjs`.
- Refs are line ranges at the reviewed commit. The renderer reads snippets from
  `OUT/snapshot`, so a wrong range shows the wrong code. Verify challenge refs.
