# Challenge Playbook

Standing angles for high-impact challenge questions, with primer knowledge so the
reviewer can hold the conversation. Tailor every angle to the candidate's actual code —
a challenge that doesn't cite their code doesn't ship. Only use an angle where their code
gives it teeth.

Selection (impact × challenge × signal fit) and the prototype lens are defined in
`reviewer-lens.md` — only one question reaches the page, written per the lens's "Writing it:
show, don't narrate": a plain-words title, what they set out to do, a whole realistic
input with outcomes side by side, a one-line cause, one or two questions to read aloud,
good answers, and ≤ 2 highlighted snippets.

The angles below give the primer knowledge. Their **Ask** lines are the opening
scenario, not text to paste: build the page's `example` and `ask` from the candidate's
actual code. A missing-data angle's input is a complete resource a real scanner could
send, run through two rules. A design angle's input is the complete new rule or request
that forces the change, and its rows are the places the change lands, each with what
happens if it's missed.

Angles 4 (scale) and 7 (integration) usually land on prototype shortcuts — use them only
when the finding is a missing seam, not the shortcut itself.

## 1. Adding a condition type (strategy/registry dispatch)

**Use when:** condition-type dispatch lives in a `switch` (or several) while operators
use a registry — or when adding a condition type touches many places (engine switch,
validator switch, helper switches, type union).

**Ask (scenario framing — avoids the "I was focused on bigger problems" deflection):**
"Say we externalize rules and a team wants a new condition type — `count` (at least N
elements match) or a field-to-field comparison. Walk me through every place you'd touch."
Then: "You made operators a registry — why not condition types?"

**Why it matters:** Condition types are the engine's extension point. If adding one means
editing several switches in different files, externalized or third-party rules can't add
behavior without an engine release, and missing a spot is a silent bug (or a compile
error only if the switches are exhaustive). A handler map keyed by `condition.type`
(`Record<Condition["type"], Handler>`) makes the set of types data the engine and the
validator share.

**Good answers:**
- A handler/strategy map where each handler owns evaluate + validate (+ blame/explain),
  typed so a missing handler is a compile error.
- Keeping the `switch` is defensible if it is the *single* place and exhaustiveness is
  enforced (`never` check) — the candidate should say so and name the trade-off
  (simplicity vs pluggability).
- Bonus: version the condition vocabulary so old engines reject rules they can't evaluate.

## 2. Externalizing rules (the reviewer's go-to thread)

**Use when:** always report readiness; ask when the code gives a concrete hook (rules as
TS modules, a validator, a `version` field, a roadmap item).

**Ask:** "Security wants to add or tweak rules without a deploy. What changes in your
design, and what's the first thing that breaks?"

**Why it matters:** Rules in code couple policy changes to engineering releases. Moving
them to data (files, DB, API) moves validation from the compiler to runtime — every rule
must be schema-checked on write, and bad rules must be rejected, not crash evaluation.

**Good answers:**
- Rules as JSON/YAML in a repo (policy-as-code, reviewed via PR) or a DB behind an admin
  API; a JSON Schema / zod schema derived from the TS types; validate on write and on load.
- Fail closed on invalid rules; keep last-known-good rule set on load failure.
- Guard untrusted inputs: regex (ReDoS — use RE2 or timeouts), path segments
  (`__proto__`, `constructor`), tree depth/size limits.
- Separate authoring from activation: draft → review → active.

## 3. Rule versioning and "the rule changed"

**Ask:** "A rule gets stricter and 200 resources that passed yesterday fail today. How does
your system tell an auditor what happened, and how do teams roll that out without a wall
of red?"

**Why it matters:** Evaluation results are only meaningful relative to the rule version
that produced them. Without versions, you can't explain history, reproduce a past
result, or stage a stricter rule.

**Good answers:**
- Immutable rule versions (id + version or content hash); results stamp the version.
- Rollout modes: audit/warn first, then enforce; grace periods; per-team opt-in.
- Diff old vs new outcomes (shadow evaluation) before enforcing.
- Exemptions with expiry for known exceptions.

## 4. Scale: 10,000 resources × 500 rules

**Use when:** the code does per-request work that won't scale (linear rule scans,
recompiling regexes, unbounded in-memory logs, synchronous giant batches).

**Why it matters:** 5M rule evaluations per sweep. Constant factors (regex compile, path
splitting, filtering all rules per resource) dominate; memory growth and event-loop
blocking take the service down.

**Good answers:**
- Index rules by resource type once; precompile conditions (paths pre-split, regexes
  compiled) into closures.
- Stream/chunk batches; worker threads or a job queue for large sweeps; return async
  job ids.
- Bound anything that grows per request (audit logs → durable store).
- Incremental evaluation: re-evaluate only resources whose config hash changed.

## 5. Missing-data semantics (fail open vs fail closed)

**Use when:** a missing field or missing array silently passes (e.g. `notEquals` on
`undefined`), or the candidate deliberately chose fail-closed.

**Why it matters:** In compliance, "we couldn't see it" must not read as "compliant". But
fail-closed everywhere floods teams with false positives on partial inventories.

**Good answers:** explicit per-rule/per-operator semantics; an `unknown`/`error` outcome
distinct from pass/fail; data-quality reporting separate from violations.

## 6. Engine API growth

**Use when:** each new cross-cutting feature (indexing, exemptions, modes, context)
added a new family of `evaluate*` functions or parameters instead of extending one entry
point.

**Ask:** "If we add one more concern — say per-tenant rule sets — how many new functions
does the engine grow?"

**Why it matters:** Combinatorial APIs (`evaluateWithXWithY`) mean every new concern
doubles the surface, and callers pick the wrong variant.

**Good answers:** one `Evaluator` built once with its dependencies (rule index, exemption
store, clock, tenant), or an options/context object plus a pipeline of post-processors
(waivers, modes) over one core `evaluate`.

## 7. Production integration (platform lean-in)

CI/CD on `terraform plan` JSON, blocking on critical, PR comments; drift detection by
scheduled evaluation of live inventory (AWS Config/CloudQuery) vs deploy-time checks;
shared service with API versioning and multi-tenancy. Use when the candidate built toward
any of these (CLI, verdict/exit codes, audit trails, modes).

## Anti-patterns (do not produce)

- Style or naming nits; "could use more tests" without a concrete gap; anything
  lint/typecheck would catch.
- Commit granularity.
- Challenges without a code reference.
- Critiques of trade-offs the candidate already documented, unless the documented
  reasoning is wrong — then quote their doc and ask them to defend it.
