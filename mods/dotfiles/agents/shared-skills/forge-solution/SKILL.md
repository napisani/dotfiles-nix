---
name: forge-solution
description: A guided design session that ends in an implementation-ready typed tech spec, plus a reviewer-ready RFC whenever the user asks for one. Highest-leverage questions first, then exhaustive frontier rounds, every option shown with its trade-offs, pros and cons, and visuals. Runs in the terminal, or on the anvil browser page when the anvil extension is loaded. Writes only ephemeral drafts to .scratch/.
disable-model-invocation: true
---

# Forge Solution

Turn an idea into an implementation-ready **tech spec** through a design session with two strands:

1. **Interview**: highest-leverage questions first, then exhaustive grilling. Gentle on-ramp, rigorous close. Every question follows [How to ask](#how-to-ask).
2. **Ephemeral drafts**: the tech spec, and the RFC when requested, are written to `.scratch/`, never committed. They exist to hand the design on — to an implementing agent or to reviewers — then die.

This skill is **design-only** and **project-agnostic**. Do not implement, scaffold, or write production code at any point. The throwaway drafts are the *only* things this skill writes to the repo; publishing them anywhere is the user's move. The session ends when the drafts are approved.

## Deliverables

- **tech spec**, always: a typed call-stack handoff an implementing agent can execute. Format: [references/spec-format.md](references/spec-format.md).
- **RFC**, on request: a design doc reviewers can judge in one sitting — key decisions, alternatives, sketches, rollout. Format: [references/rfc-format.md](references/rfc-format.md).

Never ask up front whether to write an RFC. The user can request or withdraw one at any point — in chat, with the anvil page's RFC toggle (arriving as an `Anvil RFC` message), or at spec review. When it is requested in chat on anvil, record it with `anvil_rfc` so the page shows it. A request mid-session adds the RFC's extra branches to the design tree (see [Phase 2](#phase-2--grill-frontier-rounds)); they join the next round.

## Choose the surface

Questions reach the user on one **surface** for the whole session:

- **terminal**: the structured ask-question tool (e.g. `ask_user_question`, Claude Code's `AskUserQuestion`).
- **anvil**: a live browser page, reached through the `anvil_ask` and `anvil_reply` tools.

Pick it before the first question:

1. If the user named one ("terminal", "tui", "anvil", "browser"), use it.
2. Otherwise, if `anvil_ask` is available, the surface choice is the session's first question: ask it on the terminal, anvil recommended.
3. Otherwise use the terminal.

If the chosen surface's tools are missing, say so and stop rather than asking in prose. Draft review in Phase 3 always happens on the terminal.

## How to ask

Every design question goes through the session's surface. Never ask a design question in plain text. Each question carries the same content on either surface; [Deliver it](#deliver-it) says how each surface carries it.

1. **A clear, pointed question.** One decision, phrased so each option is a direct answer. No preamble, no bundled sub-questions. The header is a short tag for the decision.
2. **Trade-offs on every option.** State what the answer buys and what it costs, across the dimensions this particular decision actually trades between — pick from simplicity, correctness, accuracy, reliability, robustness, durability, redundancy, performance, operability, reversibility, blast radius, testability, and anything else that applies. Name only the dimensions where the options differ; a dimension that is equal everywhere is noise. Be concrete ("one more table, but retries become idempotent") rather than adjectival ("more robust"). Keep every option to the same dimensions so they compare line for line.
3. **Pros and cons on every option.** Alongside the trade-offs, a bulleted **Pros** list and a bulleted **Cons** list: one short, concrete point per bullet, judged against the other options in this question. Every option gets at least one of each. They make the trade-offs scannable; the trade-off dimensions, scores, and visuals all stay.
4. **Visuals on every option.** Every option shows what choosing it means — in its `preview` on the terminal, in its lens visuals on anvil. Use the `show-me` skill's vocabulary, pick the views that make the difference obvious, and give every option the same views:
   - a `diff` against the current code when the change is to something that already exists. Read the files first; a diff names only files that exist or are marked new.
   - a sequence diagram when it is about interactions, call order, or where a failure surfaces;
   - an ER diagram plus example data and an example query when it changes a data model, storage, or a cache;
   - interface or type definitions in code when it is about a contract;
   - a call tree or ASCII flow when it is about control flow, ownership, or where a seam goes;
   - a file tree when it is about module boundaries;
   - a data table when it is about the shape of data or a side-by-side comparison.
5. **Spec impact.** Say what the option does to the spec, and to the RFC when one is requested: sections it adds or changes, decisions it unlocks, and any new subsystem or platform obligation.

Lead with the recommended option and make its trade-offs say why it wins here. Don't pad with options you would never pick.

### Deliver it

**Terminal.** Ask through the structured tool.

- Put trade-offs and spec impact in the option `description`, the recommended option first with `(Recommended)` at the end of its label.
- Give every option a `preview` holding the single most decisive view, rendered as plain text, followed by its **Pros** and **Cons** bullet lists, so options sit side by side. Previews render only on single-select questions, so prefer single-select; if a question must be multi-select, put one shared view in the question body and each option's pros and cons in its `description`.
- Check each call before sending: every option of every design question has a `preview` with pros and cons, and the call fits the tool's limits (header length, options per question, questions per call). One limit violation rejects the whole call.

**anvil.** Post each round with one `anvil_ask` call carrying all of its questions. The tool's parameter descriptions define the fields.

- Give each question stable id `D1`, `D2`, … in the order decisions are first asked.
- Choose 2–4 lenses from the views above and fill every lens for every option, or use kind `na` with the reason.
- Turn the trade-off dimensions into `dimensions`, and score every option 1–5 against the others with a one-line reason.
- Put the bullets in `pros` and `cons`, one string per bullet.
- Put spec impact in `impact` and `specDelta`.
- Flag the recommendation with `recommended: true`, keeping the label to the option's name.
- The turn ends after `anvil_ask`. Answers and defers come back together as one `Anvil round N complete` message once every question in the round is settled; that message is the round's answer. Follow-ups and revisits arrive as they happen.
- An `Anvil revisit` reopens a decision: re-ask it with `anvil_ask` under the same id and name the later decisions it puts back up for review.
- Decisions are recorded on the page. If the user decides in chat, ask them to submit it on the page so the ledger stays complete.

### Follow-ups

The user can question any question before answering it. On the terminal the tool appends a free-text "Type something." row to every question; never author that option yourself (the tool rejects reserved labels). On anvil they arrive as `Anvil follow-up` messages. Either way the question needs no dedicated follow-up option.

- **Triggers.** A free-text answer or message that reads as a question or a request for clarification, not as a decision. If it is ambiguous, treat it as a follow-up — a wrongly recorded decision costs more than one extra turn.
- **Answer it.** Briefly, with a fresh visual when that is what clarifies. If it needs a codebase fact, look it up (sub-agent if large) rather than guessing. On the terminal reply in plain text; on anvil reply with `anvil_reply`, revising the option there if the answer changes it.
- **Re-ask it.** On the terminal, ask the same question again through the tool, revising the options, trade-offs, or visuals if the clarification changed them, and repeat until it gets a real answer. On anvil the question stays open on the page.
- **A follow-up that exposes a missing decision** goes back into the design tree as a new question, rather than being resolved inside the answer.
- **In a batched round**, answers already given to the other questions stand; only the questioned one is re-asked, alongside any new frontier it unlocked. A follow-up never counts as the round's answer.

## Phase 1 — Frame (highest-leverage questions first)

Understand the problem before interrogating the design.

- **Explore first, ask second.** Read the relevant code, docs, and recent commits before asking anything. Never ask the user for a fact you can look up — their time is for *decisions*, not facts.
- **Scope check before detail.** If the request spans multiple independent subsystems, say so immediately and help decompose into sub-projects (what are the pieces, how do they relate, what order). Then forge the first sub-project; each gets its own session. Don't spend questions refining details of something that needs decomposition first.
- **One question at a time**, and only the questions that most change the design: purpose, constraints, success criteria. Ask each per [How to ask](#how-to-ask) with a recommendation. Zoom out when an answer implies a broader concern than the question asked — surfacing that is the point of this phase.
- **Propose 2–3 materially different approaches** once the problem is understood. Materially different means they differ in interface shape, seam placement, ownership, call stack, or module boundaries — not just names. Ask this as one question: one option per approach, its visuals showing its call stack or seam placement. Lead with your recommendation and why. YAGNI ruthlessly.

When the user picks a direction, the shape is settled — switch to Phase 2. Don't linger here polishing; the grill will catch what framing missed.

## Phase 2 — Grill (frontier rounds)

Now close every gap. Map the chosen design as a **design tree**: every decision branches into the decisions that hang off it. Work it in **rounds**.

The **frontier** is every decision whose prerequisites are settled — askable *now* without guessing at unheard answers. Ask the whole frontier as one round and wait for answers before the next.

- **Ask the round on the session's surface.** On the terminal, batch frontier questions up to the tool's per-call limit (e.g. 4) and split a larger frontier across consecutive calls in the same round. On anvil, post the whole frontier in one `anvil_ask` call.
- A question that depends on another question still open this round belongs to a *later* round.
- **Facts are your job, decisions are the user's.** When a frontier question needs a fact from the codebase or environment, dispatch a sub-agent to find it instead of asking. Don't block the round on it — only downstream questions wait; ask the rest of the frontier now.
- Aim the tree at what the spec will need (the outline in [references/spec-format.md](references/spec-format.md)). The frontier is empty only when you could fill every section without inventing: domain types and state model, interfaces and APIs, expected failure types, seams and adapters, call stacks from entrypoint to side effect, failure/retry/cancellation/idempotency behavior where reachable, files to touch, and what "done" means (the test plan).
- **When an RFC is requested**, also aim at what it needs beyond the spec (the template in [references/rfc-format.md](references/rfc-format.md)): measurable goals and non-goals when scope needs pinning, what would reopen each rejected approach, and — for project designs — rollout, observability, and phase order. A request after the frontier emptied reopens it for those branches only.

Done means empty frontier: every branch visited, nothing silently assumed.

## Phase 3 — Write the drafts

Read each draft's format reference before writing it.

- **tech spec**, always: follow [references/spec-format.md](references/spec-format.md). The essence: TypeScript pseudocode defines contracts, APIs, and data flow; prose explains why; alternatives considered get a short section recording what was compared during framing; include the RGR TDD test plan (vertical red-green-refactor slices per behavior — that section is what makes the spec directly executable by an agent). Write it to `.scratch/specs/YYYY-MM-DD-<topic>.md` in the repo root.
- **RFC**, when requested: follow [references/rfc-format.md](references/rfc-format.md), which says how the session's decisions map onto its sections. It describes the same design as the spec at sketch depth, so the two never disagree. Write it to `.scratch/rfcs/YYYY-MM-DD-<topic>.md` in the repo root.

Then, for each draft:

- The draft must stay out of git. Check with `git check-ignore -q .scratch`; if not ignored, append `.scratch/` to `.git/info/exclude` (local-only, never committed) rather than editing the repo's `.gitignore`.
- Self-review before handing it over: scan for placeholders/TBDs (an RFC's page-header blanks excepted), internal contradictions, requirements interpretable two ways, and scope too big for one implementation pass. For an RFC, also check every section against its budget. Fix inline.
- Ask the user to review the drafts through the terminal's structured tool. When no RFC was requested, offer "Approve and also write an RFC" beside plain approval; choosing it runs any RFC-only grilling still open, then writes and reviews the RFC. Revise until approved.

## Terminal state

The approved drafts **are** the deliverable. Do not implement, do not invoke an implementation skill, do not publish the RFC, and do not ask "want me to implement this now?" — the user decides separately when and how to build or circulate them. Close by stating each draft's path so any future session can be pointed at it.
