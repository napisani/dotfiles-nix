---
name: loancrate-review-policy-engine-interview
description: Review a candidate's Policy Engine interview submission (Loancrate Senior Platform/Security Engineer). Runs the starter and hidden tests in a clean snapshot, analyzes the solution with three parallel agents, and publishes a skimmable reviewer brief — verdict, starred signals, and one challenge question backed by code snippets — as a private Artifact. Use when asked to review a policy-engine interview repo or candidate.
---

# Review Policy Engine Interview

Produces a brief the reviewer can absorb in minutes before a 15-minute Q&A. Consistency
comes from scripts and fixed references; judgment comes from three scoped agents; the page
comes from a fixed template.

**Arguments:** the candidate's **git URL** (start at step 0: clone, open, review) or
their existing clone directory (default: current directory; start at step 1). Optional
`--name "First Last"` to skip the calendar lookup; optional `--ref <commit>` to review an
earlier commit (e.g. the last one before the deadline).

**Paths** (substitute absolute paths in commands and prompts)

- `SKILL` = this skill's base directory
- `ROOT` = the interviews folder: `golden/` (a clone of `loancrate/policy-engine-interview`,
  with the hidden tests) beside one clone per candidate. The scripts find it from
  `--root`, `$POLICY_ENGINE_INTERVIEWS`, or the current directory (or its parent) when it
  holds `golden/`.
- `OUT` = `<candidate dir>/../_reviews/<candidate-folder>/` — facts, agent outputs,
  `review.json`, `review.html`, `snapshot/` (the reviewed commit), `logs/`

**First run on a machine:** if a script exits 5 (no interviews folder or `golden/`), follow
`SKILL/AGENTS.md` to set it up, then resume where you stopped.

**References** (read only what your step needs)

- `references/rubric.md` — the interview rubric and hidden-test table (embedded from Notion)
- `references/reviewer-lens.md` — what the reviewer values, verdict rules, signal and red-flag ids
- `references/challenge-playbook.md` — challenge angles with primer answers
- `references/schemas.md` — JSON shapes for agent outputs and `review.json`
- `references/agents/{engine,production,history}.md` — agent instructions

## 0. Intake (when given a git URL)

```bash
node SKILL/scripts/intake.mjs <git-url> [--name "First Last"] >"$SCRATCH/intake.log" 2>&1
```

It reads the candidate's name from the calendar event "<Name> // Policy Engine Kickoff /
Review" nearest now (when a calendar script is installed; see `AGENTS.md`), falling back to
their GitHub profile name. It then clones into `ROOT/<first-last>` (or pulls if that clone
exists) and opens the folder in the editor so the reviewer can start browsing. It prints
JSON.

- Exit 3: no name found. Ask the user for it and re-run with `--name`.
- Exit 4: the folder exists with a different remote. Report it and stop.
- Exit 5: this machine isn't set up. Follow `SKILL/AGENTS.md`, then re-run.
- `nameMismatch: true`: the calendar and GitHub names share no word. Ask the user to
  confirm who this is before going further.

Tell the user in one line that the clone is open, then continue with its `dir`.

## 1. Collect (deterministic, seconds)

```bash
node SKILL/scripts/collect.mjs <candidateDir> [--ref <commit>] >"$SCRATCH/collect.log" 2>&1
```

Check the exit code, then read the log (a six-line summary). Exit 2 means collection broke:
report the message and stop. Exit 5 means no `golden/` was found: follow `SKILL/AGENTS.md`.

What it does: snapshots the commit, installs deps if missing or stale, runs the candidate's
own typecheck/lint/build/test on the pristine snapshot, generates adapter shims so the
golden starter and hidden tests import the candidate's app and fixtures wherever they
live, runs those tests, diffs rules and fixtures against the starter, and gathers git
history, inventory, docs and detections into `OUT/facts.json`.

- **`⚠ harness suspect`** means the shims could not load the candidate's modules. That is
  a harness problem, not a candidate failure. Read `OUT/logs/gate.log`, fix only the
  import wiring in `OUT/snapshot/<reviewDir>/app.shim.ts` or `fixtures.shim.ts` (never the
  tests), and re-run with `--gate-only`. If it can't be fixed, stop and tell the user.
- **A failing candidate check:** read its log tail in facts (`checks[].tail`). An
  environment cause (missing binary, package-manager refusal) is not the candidate's
  fault. Say so in the synthesis instead of flagging it.

## 2. Analyze (three agents in parallel, ~1–4 min)

Launch all three in **one message**, `run_in_background: true`, `subagent_type:
general-purpose`:

| Agent | Model | Prompt |
|---|---|---|
| engine | (omit — inherits) | `Read SKILL/references/agents/engine.md and follow it exactly.` + `FACTS=`, `SNAPSHOT=`, `SKILL=`, `OUT=OUT/agent-engine.json` |
| production | `sonnet` | `Read SKILL/references/agents/production.md …` + `FACTS=`, `SNAPSHOT=`, `SKILL=`, `OUT=OUT/agent-production.json` |
| history | `sonnet` | `Read SKILL/references/agents/history.md …` + `FACTS=`, `CANDIDATE_DIR=`, `SKILL=`, `OUT=OUT/agent-history.json` |

Use absolute paths in the prompts. While they run, read `reviewer-lens.md` and
`challenge-playbook.md` for synthesis. Don't redo the agents' work.

## 3. Synthesize `OUT/review.json`

Read the three agent files and `facts.gate` / `facts.checks`. Merge per
`references/schemas.md`. The reviewer is time-boxed and browses the repo alongside the
brief, so everything obeys the lens's brevity rules (the renderer enforces the limits).

- **signals** — all 16 ids exactly once (engine 5, production 10, history 1). Change an
  agent's call only when the evidence contradicts it. Keep **at most 3 stars**, for the
  strongest above-and-beyond work; a starred line says why it's impressive.
- **concerns** — apply the lens strictly, including the prototype lens: expected shortcuts
  (in-memory stores, missing auth or persistence or limits) are never concerns. Keep red
  flags only from its list. Drop slips fixed within minutes. Empty is fine.
- **challenge** — pool every agent's `challengeCandidates`, drop `prototypeShortcut`
  ones, and score each with the lens formula (impact + challenge + signal fit). Take the
  top one, using the lens's tie-breaks. Then make it graspable in 30 seconds, per the
  lens's "Writing it: show, don't narrate":
  - **Run the input.** Write `example.input` to a file in the scratchpad, then a scratch
    `.mts` script that imports their engine and rules from `OUT/snapshot`, reads that
    file, and evaluates it once per row (shipped rules, then each variant), using the
    candidate's own `node_modules/.bin/tsx` (no installs). Each `result` is what that run
    printed. Embed the same file's text as `input.code`. Trace the code only when it
    can't run. A wrong example is worse than none.
  - Read each ref in the snapshot (Read with offset/limit), cut it to ≤ 20 lines around
    the point, and set `hl` on the exact lines.
  - Reread the title and ask as if cold: plain words, no coined labels, no preamble.
  Record the scored pool in `challengePool`, which is not rendered.
- **verdict.summary** — ≤ 2 short sentences: what kind of candidate this is and the
  standout. Don't restate the score. Set `verdict.override` only with a concrete reason.
- **externalization** from engine; **roadmap, agentGuidance** from production;
  **aiUsage, iteration, focusAreas** from history.

## 4. Render

```bash
node SKILL/scripts/render.mjs <OUT>
```

It validates `review.json` (exit 1 lists every problem: fix and re-run) and computes the
headline: 👎 if the gate failed, 🤔 on any red flag, else 👍 with rockets on top: 🚀 at
≥ 60% signals, 🚀🚀 at ≥ 75%, 🚀🚀🚀 at ≥ 90%.

## 5. Publish

Publish `OUT/review.html` with the Artifact tool: `icon: "clipboard"`, description
`Reviewer brief for <Name>'s Policy Engine interview submission`. It is private by
default. To refresh a candidate reviewed in an earlier session, find its URL with
`action: "list"` and pass it as `url` so the link stays the same.

## 6. Reply

The link, then one line: headline and suggested score, plus the challenge title. Add
anything only if the user must act on it (a harness or environment problem).

## Guardrails

- Never edit the candidate's code. The only files written into their clone are the review
  harness at `<testDir>/__review__/`, left for live re-runs (the page shows the command).
- Don't re-run tests or installs outside `collect.mjs`.
- Refs are line ranges at the reviewed commit. The renderer reads snippets from
  `OUT/snapshot`, so a wrong range shows the wrong code. Verify challenge refs.
