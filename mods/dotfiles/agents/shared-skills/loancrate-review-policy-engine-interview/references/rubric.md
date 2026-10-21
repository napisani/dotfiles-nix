# Policy Engine Interview — Rubric (embedded)

Source: Notion "🛡️ Platform/Security Policy Engine Interview" (Recruiting → Senior
Platform/Security Engineer Interviews). Embedded here so the review never has to fetch it.
Refresh by hand if the page changes.

## Format

- 2-hour timed, AI-encouraged coding exercise for Senior Platform / Senior Security Engineer.
- Candidates build a generic rule evaluation engine that checks AWS resource configurations
  against compliance rules. Types and rules are provided as data; the engine is the
  deliverable. Candidates are told to finish the core, then show how they would make the
  solution more production-ready.
- Key signal: **engine generality** — a recursive evaluator that dispatches on condition
  type, not special-casing per resource type.
- After submission: ~15–30 min interviewer review, then ~15 min Q&A on Zoom (which starts
  with the candidate's walkthrough).

## Steps

1. **Field conditions** — dot-notation path resolution + comparison operators
   (`equals`, `notEquals`, `in`, `notIn`, `exists`, `notExists`, `contains`, `matchesPattern`).
   Wire `POST /evaluate`.
2. **Array conditions** — resolve an array, apply a nested condition per element with
   `some` / `every` / `none`.
3. **Logical conditions** — `and` / `or` / `not` composition (hardest step).
4. **Batch (stretch)** — `POST /evaluate/batch` with per-resource results + summary.

## Code review checklist (from the page)

- **Engine architecture:** one recursive `evaluateCondition(context, condition)` dispatching
  on `condition.type`, or hardcoded per resource type?
- **Path resolution:** dot-splitting, nested traversal, graceful null intermediates.
- **Commit history:** progression; refactor between steps vs bolt-on.
  (Reviewer preference overrides this — see reviewer-lens.md: step-by-step commits do NOT matter.)
- **AI usage patterns:** style shifts between commits; accepted wholesale vs iterated.

## Evaluation rubric

| Signal | Strong hire | Hire | No hire |
|---|---|---|---|
| Completion | Steps 1–3 complete, Step 4 started or done | Steps 1–2 complete, Step 3 partial | Did not complete Step 2 |
| Engine design | Generic recursive evaluator from the start; clean dispatch on condition type; context-passing for array elements | Recursive evaluator, rough edges; minor refactoring between steps | Hardcoded per-resource or per-rule; major rewrite between steps |
| Undisclosed tests | Most or all pass; explored fixtures proactively | Some pass; caught obvious edge cases | All fail; only optimized for provided tests |
| AI usage | Directed AI effectively; iterated on output | Used AI but reviewed/adapted results | Pasted prompt into AI and shipped output without testing |
| TypeScript | Discriminated union with type narrowing; clean types | Working TS; some assertions but reasonable | Fights the type system; excessive `any` |
| Q&A depth | Concrete, specific answers from real experience; identifies trade-offs | Reasonable answers with some depth | Surface-level or vague |

## Hiring-system score (what the interviewer submits)

1 = strong no · 2 = no · 3 = yes · 4 = strong yes. The page's headline maps onto this —
see reviewer-lens.md "Verdict".

## Undisclosed tests (12) — what each probes

| Edge case | Step | What it tests |
|---|---|---|
| S3 bucket with `logging: null` | 1 | Path resolution through null — `exists` on `logging.targetBucket` returns false, no throw |
| Nested path `publicAccessBlock.blockPublicAcls` | 1 | Deep path resolution |
| Compliant bucket → 0 violations | 1 | No false positives on dot paths |
| Non-compliant bucket → exactly 2 (S3-001, S3-002) | 1 | No false positives from broken path resolution |
| SG with `::/0` only in `ipv6CidrBlocks` | 2 | Both branches of the `or` evaluated |
| SG with `ingressRules: []` | 2 | `none`/`every` vacuously true on empty array |
| SG all-traffic (0–65535, protocol `-1`) | 2 | Caught by SG-002, not SG-003/SG-004 |
| IAM `Action: "s3:*"` (string) | 3 | `contains` on `string \| string[]` — substring vs membership |
| IAM wildcard allow WITH MFA `Condition` | 3 | `not` implemented correctly — IAM-003 passes |
| IAM deny-only policy → 0 | 3 | No false positives |
| Batch with several same-type resources | 4 | Rules applied per resource, not per type |
| Batch with unknown resource type (`aws:rds:Instance`) | 4 | 0 violations, no error |

In practice every candidate so far has passed all 12 — the hidden tests are a gate, not a
differentiator.

## Q&A prompts from the page

General: how did it go; what would you change with more time; "10,000 resources × 500
rules — what changes?"

Platform lean-in: custom rules without deploys; CI/CD integration (`terraform plan`
output, blocking on critical, PR comments); shared service (API/rule versioning,
multi-tenancy); rule versioning when a rule change flips compliant resources; observability.

Security lean-in: SOC 2 rules we're missing; false positives (exceptions, risk acceptance,
annotations); drift detection; risk of pre-deploy-only checks; prioritizing rules for a
startup's SOC 2.
