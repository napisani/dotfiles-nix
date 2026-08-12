---
name: forge-solution
description: A guided design session that ends in an implementation-ready typed tech spec. Opens with brainstorm-style framing (a few high-leverage questions, one at a time), escalates to exhaustive grilling frontier rounds, and produces an ephemeral tech spec in .scratch/ as the handoff artifact. Project-agnostic — writes nothing to the repo but the throwaway spec, and leaves long-lived documentation to each project's own conventions.
disable-model-invocation: true
---

# Forge Solution

Turn an idea into an implementation-ready **tech spec** through a design session with two strands:

1. **Interview** — brainstorm-style framing first, then exhaustive grilling. Gentle on-ramp, rigorous close.
2. **Ephemeral spec** — the deliverable is a typed call-stack tech spec written to `.scratch/`, never committed. It exists to hand the design to an implementing agent, then die.

This skill is **design-only** and **project-agnostic**. Do not implement, scaffold, or write production code at any point. The throwaway spec is the *only* thing this skill writes to the repo — long-lived documentation is deliberately out of scope, since doc conventions differ across projects and belong to each project, not to this skill. The session ends when the spec is approved.

## Phase 1 — Frame (brainstorm cadence)

Understand the problem before interrogating the design.

- **Explore first, ask second.** Read the relevant code, docs, and recent commits before asking anything. Never ask the user for a fact you can look up — their time is for *decisions*, not facts.
- **Scope check before detail.** If the request spans multiple independent subsystems, say so immediately and help decompose into sub-projects (what are the pieces, how do they relate, what order). Then forge the first sub-project; each gets its own session. Don't spend questions refining details of something that needs decomposition first.
- **One question at a time**, and only the questions that most change the design: purpose, constraints, success criteria. Prefer multiple choice with a recommendation. Zoom out when an answer implies a broader concern than the question asked — surfacing that is the point of this phase.
- **Propose 2–3 materially different approaches** once the problem is understood. Materially different means they differ in interface shape, seam placement, ownership, call stack, or module boundaries — not just names. Lead with your recommendation and why. YAGNI ruthlessly.

When the user picks a direction, the shape is settled — switch to Phase 2. Don't linger here polishing; the grill will catch what framing missed.

## Phase 2 — Grill (frontier rounds)

Now close every gap. Map the chosen design as a **design tree**: every decision branches into the decisions that hang off it. Work it in **rounds**.

The **frontier** is every decision whose prerequisites are settled — askable *now* without guessing at unheard answers. Ask the whole frontier in one numbered round and wait for answers before the next:

```
❓ **Q1** - **<question title>**: <question body, may include multiple choices>

➡️ <your recommended answer>
```

- A question that depends on another question still open this round belongs to a *later* round.
- **Facts are your job, decisions are the user's.** When a frontier question needs a fact from the codebase or environment, dispatch a sub-agent to find it instead of asking. Don't block the round on it — only downstream questions wait; ask the rest of the frontier now.
- Aim the tree at what the spec will need (the outline in [references/spec-format.md](references/spec-format.md)). The frontier is empty only when you could fill every section without inventing: domain types and state model, interfaces and APIs, expected failure types, seams and adapters, call stacks from entrypoint to side effect, failure/retry/cancellation/idempotency behavior where reachable, files to touch, and what "done" means (the test plan).

Done means empty frontier: every branch visited, nothing silently assumed.

## Phase 3 — Write the spec

Produce the spec following [references/spec-format.md](references/spec-format.md) — read it before writing. The essence: TypeScript pseudocode defines contracts, APIs, and data flow; prose explains why; alternatives considered get a short section recording what was compared during framing; include the RGR TDD test plan (vertical red-green-refactor slices per behavior — that section is what makes the spec directly executable by an agent).

- Write it to `.scratch/specs/YYYY-MM-DD-<topic>.md` in the repo root.
- The spec must stay out of git. Check with `git check-ignore -q .scratch`; if not ignored, append `.scratch/` to `.git/info/exclude` (local-only, never committed) rather than editing the repo's `.gitignore`.
- Self-review before handing it over: scan for placeholders/TBDs, internal contradictions, requirements interpretable two ways, and scope too big for one implementation pass. Fix inline.
- Ask the user to review the spec file. Revise until approved.

## Terminal state

The approved spec **is** the deliverable. Do not implement, do not invoke an implementation skill, and do not ask "want me to implement this now?" — the user decides separately when and how to build (same session, fresh session, another agent). Close by stating the spec path so any future session can be pointed at it.
