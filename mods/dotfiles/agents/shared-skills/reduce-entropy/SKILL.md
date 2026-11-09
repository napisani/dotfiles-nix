---
name: reduce-entropy
description: Find the smallest requirement concessions that buy the largest code and complexity reductions in a target area or the current changeset, with before/after code.
disable-model-invocation: true
---

# Reduce entropy

Code accumulates *entropy*: every option, layer, branch and special case makes the next one easier to justify. This review finds where entropy can be removed, and it goes past cleanup. Assume the code was built to requirements that are negotiable, and find the smallest functional *concessions* that buy the largest reductions in code, concepts or architecture.

Judge every finding by its *end state*: how much code and how many concepts remain afterward, not how much work the change takes. A 50-line rewrite that deletes 200 lines is a finding; a refactor that reorganizes code without shrinking it is not.

The review is read-only. Produce the report and stop; the user picks which concessions to accept.

## 1. Resolve the scope

- If the user named a target (path, directory, module, symbol, feature), analyze that.
- Otherwise analyze the current changeset: uncommitted changes plus the branch's commits since its merge base with the default branch. Follow the change into surrounding code wherever it builds on complexity that already exists there.
- If neither yields code, ask the user for a target.

## 2. Map complexity to requirements

Read the scope in full, plus its callers and tests. For every source of complexity, name the requirement it serves: each abstraction or layer, config option or flag, branch and special case, error or retry path, piece of state or cache, dependency, generic parameter, and near-duplicate variant.

Check whether each requirement is *load-bearing* instead of assuming it: search for callers of an option, check whether a flag is ever set, look for tests of the edge case, read commit messages and docs for the reason it exists. A requirement with no evidence of use costs nothing to drop.

Done when every non-trivial construct in scope has a named requirement, or is marked as serving none.

## 3. Find concessions

Work through the map:

- **Complexity serving no requirement**: dead code, unused generality, indirection with one implementation, duplicated logic, handling for impossible states. These are zero-concession findings.
- **Live requirements**: ask what the code becomes if the requirement is narrowed, weakened or dropped. Support one format instead of three, fail instead of retry, recompute instead of cache, hard-code the option nobody varies, replace a custom type with plain data, let an existing dependency do the work, merge two paths that differ only in rare cases. Keep the concessions whose payoff is disproportionate to what is given up.
- **Architecture**: look for a whole layer, module, process, persistence mechanism or dependency that exists for one requirement. These are the findings routine cleanup misses, and usually the largest.

Treat these defenses of existing code with skepticism, since each tends to preserve entropy:

- "It already exists": churn is not the measure; the end state is.
- "It's more flexible": flexibility for which concrete caller?
- "It separates concerns": every extra file, type and interface is code too.
- "It's easier to understand": distinguish *simple* (one concept, nothing complected) from *familiar*. Fewer things usually beat more well-organized things.

Two kinds of complexity resist removal. A framework's conventions are a requirement too; a finding that fights the framework usually costs more than it saves. And some things are far cheaper to keep than to retrofit: data that cannot be recovered later (timestamps, audit history), public API contracts, security fundamentals, migrations. A concession that gives one of these up is large however little code it saves.

Done when every requirement in the map has been tested for a concession. Keep only findings whose end state is smaller.

## 4. Size each finding

*Concession size* is what is given up and who notices:

| Size | Who notices |
|---|---|
| None | Nobody; behavior is identical. |
| Internal | Maintainers and internal callers: an API shape, an unused option, extensibility. Users do not. |
| Edge | Users, in rare cases: an uncommon input rejected, a less specific error, a slower uncommon path. |
| Feature | Users, routinely: a capability narrowed or removed, a guarantee weakened. |

A concession that is hard to reverse moves up one size. *Payoff* is the end-state reduction: net lines removed and concepts removed (types, files, options, layers, dependencies). Count lines from the code and mark estimates as estimates.

## 5. Report

Order findings by concession size, smallest first; within a size, largest payoff first. Use this template:

~~~markdown
# Reduce entropy: <scope>

| # | Finding | Concession | Payoff |
|---|---|---|---|
| 1 | <short title> | None | −40 lines, −1 type |

## 1. <Finding title>

**Concession (<size>):** what is given up and who would notice, or "None".
**Simplification:** what the code becomes, in one or two sentences.
**Payoff:** net lines and concepts removed.

Before (`path/to/file.ts:12-40`):
```ts
<current code, trimmed to the part that changes>
```

After:
```ts
<proposed code>
```
~~~

Keep explanations brief; the code examples carry the argument. Take each before excerpt from the real code with its file and line range, and elide unchanged parts with a comment. Write each after example as real code in the same language and idiom. For a finding that spans files, show the central seam before and after and list the files that disappear.

End with one line naming the finding with the best payoff for its concession. If the scope is already minimal for what it does, say so in place of a padded list.
