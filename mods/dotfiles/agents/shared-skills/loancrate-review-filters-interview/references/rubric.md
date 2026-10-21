# Filters Interview — Rubric (embedded)

Sources: Notion "🐼 Engineering Filters Interview" (Recruiting → Senior Software Engineer
Interviews) and the Google Doc "Loancrate Filters" sent to candidates. Embedded so the
review never has to fetch them. Refresh by hand if either changes.

## Format

- Full-stack exercise for Senior Software Engineers, run after the autocomplete (search)
  interview. Framing to the candidate: "previously we built search; the other way
  customers look up data in Loancrate is filters."
- ~15–30 min intro: spec and wireframes, download the starter, walk `server/index.ts`,
  `client/App.tsx`, `shared/index.ts`. Candidate creates a private GitHub repo and adds the
  interviewers as collaborators.
- 2 hours of working time; AI is explicitly encouraged.
- Then ~15 min code review (reviewer clones, **runs it locally and QAs it**, notes how far
  they got and design questions), then ~15 min Q&A on Zoom.

## What the Notion page says we evaluate

Full-stack skill, code organization, and how they handle a larger project:

- How DRY is the solution? Is it easy to read and understand?
- Are there bugs?
- Did they complete all 3 steps?
- Do they ask good product questions and read between the lines of the spec and mockups?

## What the candidate doc tells them

- "For UI work, make it look great. We don't expect you to be a designer but we do want it
  to look as best as you can."
- Third-party libraries and AI are welcome ("you almost certainly should use AI").
- "Above all else, we are looking for 1) throughput of task completion 2) the cleanliness
  of your code when finished and 3) going well beyond the minimum requirements below to
  add features, design, server side tech, etc to make this as awesome as possible. What
  should you add exactly? That's up to you. It's a big part of what this test is."
- Any existing code may be changed. TypeScript is the only requirement.

## The steps (the spec)

1. **String filters** on `firstName, lastName, maritalStatus, emailAddress, homePhone,
   cellPhone, currentAddress, employer, title, subjectPropertyAddress` with operators
   **Is** and **Includes**. Only filterable fields appear in the field dropdown. All
   filters are **AND**-ed. **Filtering happens on the server**; only filtered data returns.
2. **Number filters** on `creditScore, w2Income`: **Is less than**, **Is**, **Is greater than**.
3. **Date filters** on `dateOfBirth, startDate`: **Is less than**, **Is**, **Is greater than**.

Wireframes (3 pages): a "Borrowers" title; a "Filters" card with an **Add Filter** button
and the empty hint "Add a filter to narrow your results"; each filter row reads
`Where [Field ▾] [is ▾] [value]`, later rows start with `AND`; the borrower table below
with readable column headers (First Name, Last Name, Date of Birth…).

## Starter facts that matter for review

- npm workspaces: `packages/client` (React 19 + Vite, port 1234, proxy `/borrowers`),
  `packages/server` (Express 5 + tsx, port 1337, `GET /borrowers` returns all 100 with a
  `TODO: Implement support for filtering`), `packages/shared` (`Borrower`,
  `BORROWER_FIELD_NAMES`, `MARITAL_STATUSES`).
- `borrowers.json`: 100 faker borrowers. Dates are **`M/D/YYYY` strings** (`10/26/1980`),
  so comparing them as strings is wrong and `new Date()` on a date-picker value
  (`YYYY-MM-DD`, parsed as UTC) vs. the data (parsed as local) is off by a day west of
  UTC. `maritalStatus` values are `married | separated | unmarried` — "is married" must
  not match "unmarried".
- No tests, no lint, no field-type metadata: everything beyond the table is theirs.

## Q&A prompts from the page

- How'd it go? Any feedback on the interview?
- If you had more time, what would you change or do differently?
- **"Let's say we wanted to support 1M borrowers instead of 100 — what changes would you
  make?"** (debouncing? pagination?)
- What UI/UX improvements would you make?

## Score examples from the page (hiring-system scale)

1 = strong no · 2 = no · 3 = yes · 4 = strong yes.

- **2** — "Barely cleared the minimum bar on the coding portion, with notable duplication
  in his solution… didn't show the depth expected."
- **3** — "A lot of good additions… in terms of code quality and consistency. I would've
  scored higher if he was able to expand past the minimal requirements more but his design
  was objectively better than the mocks and added a few features. Good AI development
  workflows… considers customers of the potential product."
- **4** — "Fully integrated AI, including a loan decision engine, caching to save on $, AI
  cost estimation tool, custom search, badass design. This should be the gold standard for
  what a 4 looks like."
- **4** — "Went above and beyond… adding theming, a sidebar, optional case matching, and
  sorting with a clean design. Took feedback well and opted out of tests for time."
