# CONTEXT.md Format

`CONTEXT.md` is a glossary and nothing else — no implementation details, no spec content, no scratch notes.

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under `_Avoid_`.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Only include terms specific to this project's context.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively.
- **Group terms under subheadings** when natural clusters emerge; a flat list is fine otherwise.

## Single vs multi-context repos

- If a `CONTEXT-MAP.md` exists at the repo root, the repo has multiple contexts — read it to find where each `CONTEXT.md` lives, and infer which context the current topic belongs to (ask if unclear).
- If only a root `CONTEXT.md` exists, single context.
- If neither exists, create a root `CONTEXT.md` lazily when the first term is resolved.
