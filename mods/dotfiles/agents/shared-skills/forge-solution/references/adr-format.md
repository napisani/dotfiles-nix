# ADR Format

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, etc. Create the directory lazily — only when the first ADR is needed. Scan for the highest existing number and increment.

## Template

```md
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

An ADR can be a single paragraph. The value is in recording *that* a decision was made and *why* — not in filling out sections. Optional additions, only when they add genuine value: `Status` frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`), **Considered Options** (when rejected alternatives are worth remembering), **Consequences** (when non-obvious downstream effects need calling out).

## When to offer an ADR

All three must be true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why on earth did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any is missing, skip it: easy-to-reverse decisions just get reversed, unsurprising ones prompt no questions, and no-alternative decisions record nothing beyond "we did the obvious thing."

## What qualifies

- **Architectural shape.** "The write model is event-sourced, the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target — the ones that would take a quarter to swap out, not every library.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; others reference it by ID only." Explicit no-s are as valuable as yes-s.
- **Deliberate deviations from the obvious path.** Anything where a reasonable reader would assume the opposite — these stop the next engineer from "fixing" something deliberate.
- **Constraints not visible in the code.** Compliance requirements, partner API latency contracts.
- **Rejected alternatives when the rejection is non-obvious.** Otherwise someone suggests it again in six months.
