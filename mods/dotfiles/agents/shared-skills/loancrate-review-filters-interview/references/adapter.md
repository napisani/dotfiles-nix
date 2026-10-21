# Writing the probe adapter

`probe.mjs` tests the candidate's API with filters written in the spec's vocabulary. The
adapter at `OUT/probe/adapter.mjs` translates those into the request their client sends,
and their response back into borrower ids. It is the only file you write for the probe;
never edit their code.

## Find their contract (2–3 files)

1. The client call: grep the client for `axios`, `fetch(`, `useQuery`, `trpc.` — note the
   method, path, how filters are encoded (query param JSON, repeated params, POST body,
   tRPC input), the operator names, and how date values are sent (a date input gives
   `YYYY-MM-DD`; some convert to `M/D/YYYY`).
2. The server route and its parser/validator: confirm what it accepts and the response
   shape (plain array, `{ data, total }`, `{ items, page }`, tRPC `{ result: { data } }`).
3. Paging: if the server paginates, request the largest page it allows and return `total`.

## Translate, don't pass through

The probe speaks one canonical vocabulary; the adapter's whole job is to turn it into
exactly what their client puts on the wire. Check each of these against their client code:

- **Operator names:** the probe's `op` is `is | includes | lt | gt`; map it to their key
  and values (`operator: "lessThan"`, `"is_less_than"`, `"<"`…).
- **Value types:** the probe gives numbers as numbers and dates as `YYYY-MM-DD`. If their
  client sends every value as a string, send `String(value)`; if it sends `M/D/YYYY`,
  convert.
- **No filters:** send what their client sends with an empty filter list — `[]`, an
  omitted param, or `[]` rather than `[[]]` for a model of OR groups (one group holding
  all filters is `[filters]`).
- **`total`:** only the number of rows matching the filters. A count header that is
  always the unfiltered size must not become `total`; leave `total` out unless paged.

## Shape

```js
// OUT/probe/adapter.mjs — one comment line naming where the contract lives.
// Optional: override what collect.mjs detected.
// export const ports = { server: 1337, client: 1234 };   // their hard-coded ports
// export const start = { server: "npm run dev:server", client: "npm run dev:client" };
// export const dataset = "packages/server/data/borrowers.json"; // what the server loads
// export const serverFiltering = false;   // only if filtering happens in the client

const OPS = { is: "is", includes: "includes", lt: "lessThan", gt: "greaterThan" };

/**
 * filters: [{ field, type: "string"|"number"|"date", op: "is"|"includes"|"lt"|"gt", value }]
 * value: string for strings, number for numbers, "YYYY-MM-DD" for dates. Some probe cases
 * deliberately send bad input (unknown field, "abc" as a number) — pass it through as-is.
 * Return { method, path, query?, body?, headers? }; query values that aren't strings are JSON-encoded.
 */
export function request({ filters }) {
  return {
    method: "GET",
    path: "/borrowers",
    query: { filters: JSON.stringify(filters.map((f) => ({ field: f.field, operator: OPS[f.op] ?? f.op, value: String(f.value) }))) },
  };
}

/** json: the parsed response body. Return { ids, total? } (total when paged). */
export function parse(json) {
  return { ids: json.map((b) => b.id) };
}
```

Common variations:

- **POST body:** `return { method: "POST", path: "/borrowers/search", body: { filters: [...] } }`.
- **Repeated params:** `query: { field: [...], op: [...], value: [...] }` (arrays repeat the key).
- **tRPC:** copy what the browser sends (read the client's link config, or
  `playwright-cli requests`). Direct `httpLink`: `path: "/trpc/borrowers.list", query:
  { input: JSON.stringify(input) }`, parse `json.result.data`. `httpBatchLink`:
  `query: { batch: "1", input: JSON.stringify({ 0: input }) }`, parse `json[0].result.data`.
  With superjson, input is wrapped as `{ json: input }` and data is under `.json`. Either
  way, `parse` still maps the rows to `{ ids: rows.map((b) => b.id) }`.
- **Paged:** add their page-size param at its maximum; `parse` returns `{ ids, total }`.
- **Dates:** convert `"1980-10-26"` to what their client sends (`"10/26/1980"`) if needed.
- **No `id` in rows:** map rows back to ids via a unique field only if you must; say so in
  the header comment.

## Verify

`node SKILL/scripts/probe.mjs OUT --filters '[]'` should print `total` equal to the dataset
size; then one filter per type, e.g.
`--filters '[{"field":"creditScore","op":"gt","value":800}]'`, whose `total` should match
`expectedBySpec` (`exactCase` or `anyCase`; the spec leaves case open). Then run the full suite: `node SKILL/scripts/probe.mjs OUT`.

A failing case is a fact about the candidate only once you've ruled out the adapter:
re-send it with `--filters`, compare with what their UI sends for the same filter (their
client code), and read their filter function. If the adapter was wrong, fix it and re-run.
