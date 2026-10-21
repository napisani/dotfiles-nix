# Challenge Playbook

Standing angles for high-impact challenge questions, with primer knowledge so the reviewer
can hold the conversation. Tailor every angle to the candidate's actual code — a challenge
that doesn't cite their code doesn't ship. Only use an angle where their code gives it
teeth.

Selection (impact × challenge × signal fit) and the prototype lens are defined in
`reviewer-lens.md` — only one question reaches the page, written per the lens's "Writing
it: show, don't narrate".

The **Ask** lines below are the opening scenario, not text to paste: build the page's
`example` and `ask` from the candidate's code. A behavior angle's input is the exact
request their API accepts, run through `probe.mjs --filters` for each row. A design
angle's input is the complete new field or operator that forces the change, and its rows
are the places the change lands, each with what happens if it's missed.

## 1. Adding a field type or operator (one source of truth)

**Use when:** field types, operator lists or labels exist in more than one place (client
dropdown config, server switch, validator, shared types), or `shared` is used for types
only while each side keeps its own lists.

**Ask:** "Product wants `maritalStatus` as a dropdown of its three values, and a new
`is not` operator for every type. Walk me through every file you'd touch."

**Why it matters:** Filters grow — Loancrate's real filters cover hundreds of loan fields.
If a field's type and operators live in several places, every addition is a multi-file
edit and a missed spot is a silent mismatch (the UI offers an operator the server
rejects, or the server accepts one the UI never sends).

**Good answers:**
- One field registry in `shared` (`field → { type, label, operators, input }`), with the
  client rendering from it and the server validating and dispatching from it.
- Per-type operator handlers in a map keyed by type, typed so a missing handler is a
  compile error.
- Bonus: generate the request schema (zod) from the same registry.

## 2. Request races and wasted requests (the 1M-borrowers question, client side)

**Use when:** every keystroke fires a request with no debounce, or responses aren't
sequenced (no `AbortController`, no "ignore stale" flag, no react-query/SWR key), so a slow
early response can overwrite a newer one.

**Ask:** "A loan officer types 'Mart' into last name includes. Four requests go out; the
'M' one comes back last. What does the table show?"

**Why it matters:** At 100 rows every response is instant and the bug hides; at 1M rows
responses take hundreds of milliseconds and arrive out of order, so the table can show
results for a filter the user no longer has.

**Good answers:** debounce typing (~250–300 ms); abort the previous request or drop
responses that aren't the latest; or use a query cache keyed by the filters
(react-query) that handles both; keep the previous rows visible while loading.

## 3. From array filter to a database (the 1M-borrowers question, server side)

**Use when:** filter logic is bound to in-memory evaluation in a way that couldn't become
a query: predicates built from closures over JS values, string matching done after
formatting, or filtering tangled into the route handler.

**Ask:** "Borrowers move to Postgres with a million rows. What happens to your filter
code — can your filter model turn into a `WHERE` clause?"

**Why it matters:** The model (field, operator, value) is the contract; the evaluator is
replaceable. If the model is clean, a SQL/ORM translator slots in beside the in-memory
one; if logic is tangled with request parsing or JS-only semantics, it's a rewrite.

**Good answers:** keep a pure filter model validated at the boundary; translate it per
backend (`ILIKE '%x%'` for includes, typed date columns rather than `M/D/YYYY` strings,
indexes on common fields); paginate (cursor or offset) and return a total; precompute or
cache counts; trigram/full-text index for includes.

## 4. Dates (a classic correctness trap)

**Use when:** dates are compared as strings, parsed with `new Date()` on mixed formats, or
compared with timestamps where a time component sneaks in — and especially when the probe
caught a date case.

**Ask:** "Filter date of birth is 10/26/1980. Which borrowers come back if the server runs
in New York? In Los Angeles?"

**Why it matters:** `new Date("1980-10-26")` is UTC midnight but `new Date("10/26/1980")`
is local midnight, so "is" misses and "less than" shifts by a day west of UTC; `"10/26/1980"
< "9/1/1961"` as strings. Mortgage data is full of dates (closing, rate lock, DOB).

**Good answers:** compare calendar days (`YYYYMMDD` integers or a date-only type); parse
the data's format explicitly; store ISO dates server-side; be explicit about time zones.

## 5. Validation at the boundary

**Use when:** the server trusts the filter payload — an unknown field, a string operator
on a number, `"abc"` as a number or an unparseable JSON param produces a 500, an empty
table, or silently ignores the filter (see `facts.probe.behavior`).

**Ask:** "Someone bookmarks a URL from last month, and we've since renamed a field. What
does your server do with `?filters=[{"field":"w2Income",…}]` now?"

**Why it matters:** URLs get shared, saved views outlive schema changes, and other clients
will call the API. A filter that silently matches nothing looks like "no borrowers", which
is worse than an error.

**Good answers:** a schema (zod) derived from the shared field registry; 400 with a
message naming the bad filter; the client surfaces it; versioning saved filters.

## 6. Product semantics the spec left open

**Use when:** a choice the spec didn't make looks accidental rather than decided: "is" is
case-sensitive so "matt" finds nothing; includes on phone numbers fails because of
formatting; an empty value returns everything (or nothing); "is" on a date ignores or
includes time.

**Ask:** "A loan officer searches cell phone includes '5551234' and the number is stored
as `(555) 123-4567`. Should that match? What does yours do?"

**Why it matters:** "Read between the lines" is an explicit criterion. Users judge filters
by whether they find the borrower they know is there.

**Good answers:** a stated default (case-insensitive, trimmed) with a reason; normalizing
phone numbers before matching; optional case-sensitive toggle; incomplete rows ignored
until valid, shown as such.

## 7. AND-only model vs. growth

**Use when:** the filter model is a flat list hard-wired to AND, and the candidate built
something that will need more (saved views, OR groups planned in a README, NL filters).

**Ask:** "Customers ask for 'credit score > 700 AND (married OR separated)'. What changes
in your model, URL format and UI?"

**Good answers:** a tree (`{ and: [...] } | { or: [...] } | condition`) that degrades to a
list; the evaluator recursing on it; versioned URL encoding.

## 8. AI features: cost, trust, and failure

**Use when:** they built natural-language filters or other AI into the product
(explanations, scoring) — the gold-standard 4 did.

**Ask:** "What happens when the model returns a filter for a field that doesn't exist — or
the API is down? What does each query cost?"

**Good answers:** validate model output against the same filter schema; show the parsed
filters for the user to confirm; fall back gracefully; cache by prompt; cost estimates.

## Anti-patterns (do not produce)

- Style or naming nits; "could use more tests"; anything lint/typecheck would catch.
- Commit granularity.
- Challenges without a code reference.
- Prototype shortcuts (JSON file, no DB, no auth) unless a seam is missing.
- Critiques of trade-offs the candidate already documented, unless the documented
  reasoning is wrong — then quote their doc and ask them to defend it.
