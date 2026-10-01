"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { actionPrompt, babysitStatus, classifyPullRequest, parseSessionFrontmatter, updateStateAfterDispatch } = require("./loancrate-pr-tui-core.js");
const { LoancratePrTuiView, babysitDetail, statusSignals } = require("./loancrate-pr-tui.js");

function pullRequest(overrides = {}) {
  return {
    number: 42,
    url: "https://github.com/loancrate/loancrate/pull/42",
    title: "Test PR",
    headRefName: "nick/test",
    baseRefName: "main",
    headRefOid: "abc",
    isDraft: false,
    mergeable: "MERGEABLE",
    mergeStateStatus: "CLEAN",
    reviewDecision: null,
    reviewThreads: { nodes: [] },
    comments: { nodes: [] },
    reviews: { nodes: [] },
    commits: {
      nodes: [{ commit: { statusCheckRollup: { state: "SUCCESS", contexts: { nodes: [] } } } }],
    },
    ...overrides,
  };
}

function failingChecks() {
  return {
    nodes: [{
      commit: {
        statusCheckRollup: {
          state: "FAILURE",
          contexts: {
            nodes: [{ __typename: "CheckRun", name: "tests", conclusion: "FAILURE", isRequired: true }],
          },
        },
      },
    }],
  };
}

test("conflicts take priority over failing CI and review feedback", () => {
  const pr = pullRequest({
    mergeable: "CONFLICTING",
    mergeStateStatus: "DIRTY",
    reviewThreads: {
      nodes: [{ id: "thread", isResolved: false, comments: { nodes: [{ author: { login: "alice" }, body: "Please fix", createdAt: "2026-01-01" }] } }],
    },
    commits: failingChecks(),
  });
  const classified = classifyPullRequest(pr, "nick", { version: 1, prs: {} });
  assert.equal(classified.action.kind, "merge");
  assert.match(actionPrompt(classified), /^\/merge-parent-into-branch/);
});

test("CI failures take priority over outstanding feedback", () => {
  const pr = pullRequest({
    reviewThreads: {
      nodes: [{ id: "thread", isResolved: false, comments: { nodes: [{ author: { login: "alice" }, body: "Please fix", createdAt: "2026-01-01" }] } }],
    },
    commits: failingChecks(),
  });
  assert.equal(classifyPullRequest(pr, "nick", { version: 1, prs: {} }).action.kind, "ci");
});

test("feedback only dispatches when at least one outstanding id is new", () => {
  const pr = pullRequest({
    reviewThreads: {
      nodes: [{ id: "thread", isResolved: false, comments: { nodes: [{ author: { login: "alice" }, body: "Please fix", createdAt: "2026-01-01" }] } }],
    },
  });
  const classified = classifyPullRequest(pr, "nick", { version: 1, prs: { 42: { handled_ids: ["rt:thread"] } } });
  assert.equal(classified.action.kind, "none");
  assert.match(classified.action.reason, /already dispatched/);
});

test("a repeated parent merge against the same head escalates to a human", () => {
  const pr = pullRequest({ mergeable: "CONFLICTING", mergeStateStatus: "DIRTY" });
  const classified = classifyPullRequest(pr, "nick", { version: 1, prs: { 42: { last_action: "merge", head_oid: "abc" } } });
  assert.equal(classified.action.kind, "manual");
});

test("the TUI caps visible rows to the terminal viewport", () => {
  const rows = Array.from({ length: 10 }, (_, i) => ({
    number: 20000 + i,
    title: `Title ${i}`,
    branch: `branch-${i}`,
    base: "main",
    mergeable: "MERGEABLE",
    mergeStateStatus: "CLEAN",
    ready: false,
    draft: false,
    action: { kind: "none", reason: "No new action" },
    feedback: { ids: [], descriptions: [] },
    ci: { state: "SUCCESS", failed: [], failing: false },
    pane: { status: "ok", target: "pane" },
  }));
  rows[0].branch = "nick/a-branch-name-that-is-much-longer-than-the-column";
  rows[0].action = { kind: "ci", reason: "CI is failing" };
  rows[0].feedback.descriptions = ["reviewer: first line\n<details>second line</details>"];
  rows[2].action = { kind: "ci", reason: "CI is failing" };
  rows[2].pane = { status: "busy", target: "pane" };
  rows[3].action = { kind: "merge", reason: "Conflicts" };
  rows[3].pane = { status: "no-session", target: "" };
  rows[4].action = { kind: "manual", reason: "Repeated repair failed" };
  rows[5].ready = true;

  const theme = {
    fg: (_color, value) => value,
    bg: (_color, value) => value,
    bold: (value) => value,
  };
  const view = new LoancratePrTuiView(
    { terminal: { rows: 40 }, requestRender() {} },
    theme,
    rows,
    { onClose() {}, onRefresh() {}, onOpen() {}, onDispatch() {} },
  );
  assert.equal(view.visibleRows().rows.length, 10);
  const rendered = view.render(120);
  assert.ok(rendered.every((line) => !line.includes("\n")), "each rendered item must be exactly one terminal line");
  const firstRow = rendered.find((line) => line.includes("#20000"));
  const secondRow = rendered.find((line) => line.includes("#20001"));
  const stripAnsi = (line) => line.replace(/\x1b\[[0-9;]*m/g, "");
  const heading = stripAnsi(rendered.find((line) => line.includes("STAGE")));
  assert.match(heading, /STAGE\s+PR\s+BRANCH\s+STATE\s+ACTION/);
  assert.match(stripAnsi(firstRow), /│ > \[ \]/, "the selected row uses the picker's reserved cursor column");
  assert.match(stripAnsi(secondRow), /│   \[-\]/, "unselected rows preserve cursor-column alignment");
  assert.match(stripAnsi(firstRow), /C✓ R\? clean/, "state cells use compact CI and review signals");
  assert.equal(stripAnsi(firstRow).indexOf("clean"), stripAnsi(secondRow).indexOf("clean"), "state columns must align");

  assert.match(stripAnsi(rendered.find((line) => line.includes("#20002"))), /\[-\].*Working/);
  assert.match(stripAnsi(rendered.find((line) => line.includes("#20003"))), /\[-\].*No pane/);
  assert.match(stripAnsi(rendered.find((line) => line.includes("#20004"))), /\[-\].*Needs you/);
  assert.match(stripAnsi(rendered.find((line) => line.includes("#20005"))), /\[-\].*ready/);

  view.toggleStage();
  const stagedRow = view.render(120).find((line) => line.includes("#20000"));
  assert.match(stripAnsi(stagedRow), /\[x\]/, "staged rows show a checked checkbox");

  view.setView("actionable");
  assert.deepEqual(view.filteredRows().map((row) => row.number), [20000]);
  view.setView("working");
  assert.deepEqual(view.filteredRows().map((row) => row.number), [20002]);
  view.setView("ready");
  assert.deepEqual(view.filteredRows().map((row) => row.number), [20005]);
  view.setView("needs-you");
  assert.deepEqual(view.filteredRows().map((row) => row.number), [20003, 20004]);

  const shortView = new LoancratePrTuiView(
    { terminal: { rows: 20 }, requestRender() {} },
    theme,
    rows,
    { onClose() {}, onRefresh() {}, onOpen() {}, onDispatch() {} },
  );
  assert.equal(shortView.visibleRows().rows.length, 2);
  const shortRendered = shortView.render(120);
  assert.ok(shortRendered.some((line) => line.includes("#20000")));
  assert.ok(shortRendered.some((line) => line.includes("#20001")));
});

test("status signals mirror the tmux picker's compact PR indicators", () => {
  assert.deepEqual(statusSignals({
    approved: false,
    draft: false,
    ci: { state: "FAILURE", failing: true },
    feedback: { ids: ["thread"] },
  }), [
    { label: "C✗", tone: "error" },
    { label: "R!", tone: "error" },
  ]);
  assert.deepEqual(statusSignals({
    approved: true,
    draft: false,
    ci: { state: "SUCCESS", failing: false },
    feedback: { ids: [] },
  }), [
    { label: "C✓", tone: "success" },
    { label: "R✓", tone: "success" },
  ]);
});

test("dispatch state unions feedback ids and increments CI attempts", () => {
  const pr = classifyPullRequest(pullRequest({ commits: failingChecks() }), "nick", { version: 1, prs: {} });
  const state = updateStateAfterDispatch(
    { version: 1, prs: { 42: { handled_ids: ["old"], ci_attempts: 1 } } },
    pr,
    "pane",
    "2026-01-02T00:00:00Z",
  );
  assert.equal(state.prs[42].ci_attempts, 2);
  assert.deepEqual(state.prs[42].handled_ids, ["old"]);
  assert.equal(state.prs[42].target, "pane");
});

const SESSION_FILE = [
  "---",
  "pr: 42",
  'branch: "nick/feature"',
  'mode: "drive"',
  'last_poll: "2026-09-30T14:26:04Z"',
  'next_poll: "2026-09-30T14:30:04Z"',
  'ci: "red"',
  'blocked_on: "human approval"',
  "unposted_replies: 2",
  "stop_requested: false",
  "ended: null",
  "---",
  "",
  "## 2026-09-30 14:02 · pass 1",
].join("\n");

const AT_1427 = Date.parse("2026-09-30T14:27:00Z");
// next_poll is 14:30:04, so the deadline is 14:40:04 and anything past it is stale.
const AT_STALE = Date.parse("2026-09-30T14:47:00Z");

test("session frontmatter parses without a YAML library", () => {
  const fm = parseSessionFrontmatter(SESSION_FILE);
  assert.equal(fm.pr, 42);
  assert.equal(fm.mode, "drive");
  assert.equal(fm.unposted_replies, 2);
  assert.equal(fm.stop_requested, false);
  assert.equal(fm.ended, null);
  assert.equal(fm.blocked_on, "human approval");
});

test("a file with no frontmatter is not a babysit run", () => {
  assert.equal(parseSessionFrontmatter("# just a heading\n"), null);
  assert.equal(babysitStatus(null).state, "none");
});

test("liveness comes from next_poll, not from ended being null", () => {
  const fm = parseSessionFrontmatter(SESSION_FILE);
  assert.equal(babysitStatus(fm, AT_1427).state, "active");
  // A crashed run cannot record `ended`, so a missed deadline outranks it.
  assert.equal(babysitStatus(fm, AT_STALE).state, "stale");
  assert.equal(babysitStatus({ ...fm, ended: "CI green" }, AT_1427).state, "finished");
  // Grace: still active a few minutes after next_poll, since polls are not punctual.
  assert.equal(babysitStatus(fm, Date.parse("2026-09-30T14:35:00Z")).state, "active");
});

test("an active babysit suppresses dispatch even when CI is failing", () => {
  const pr = pullRequest({ commits: failingChecks() });
  const active = babysitStatus(parseSessionFrontmatter(SESSION_FILE), AT_1427);
  const withoutBabysit = classifyPullRequest(pr, "nick", { version: 1, prs: {} });
  assert.equal(withoutBabysit.action.kind, "ci");

  const withBabysit = classifyPullRequest(pr, "nick", { version: 1, prs: {} }, active);
  assert.equal(withBabysit.action.kind, "none");
  assert.match(withBabysit.action.reason, /Babysat \(drive\), next check 2026-09-30T14:30:04Z/);
  assert.equal(withBabysit.babysit.state, "active");
});

test("a stale babysit leaves the PR dispatchable", () => {
  const pr = pullRequest({ commits: failingChecks() });
  const stale = babysitStatus(parseSessionFrontmatter(SESSION_FILE), AT_STALE);
  const row = classifyPullRequest(pr, "nick", { version: 1, prs: {} }, stale);
  assert.equal(row.action.kind, "ci");
  assert.equal(row.babysit.state, "stale");
});

test("the STATE column carries a babysit signal without a new column", () => {
  const base = classifyPullRequest(pullRequest(), "nick", { version: 1, prs: {} });
  assert.equal(statusSignals(base).some((s) => s.label.startsWith("B")), false);

  const active = babysitStatus(parseSessionFrontmatter(SESSION_FILE), AT_1427);
  const babysat = classifyPullRequest(pullRequest(), "nick", { version: 1, prs: {} }, active);
  assert.deepEqual(statusSignals(babysat).find((s) => s.label.startsWith("B")), { label: "B▶", tone: "accent" });

  const stale = babysitStatus(parseSessionFrontmatter(SESSION_FILE), AT_STALE);
  const dead = classifyPullRequest(pullRequest(), "nick", { version: 1, prs: {} }, stale);
  assert.deepEqual(statusSignals(dead).find((s) => s.label.startsWith("B")), { label: "B⚠", tone: "warning" });
});

test("the detail line reports next check and owed replies", () => {
  assert.equal(babysitDetail({ babysit: { state: "none" } }), null);
  assert.equal(babysitDetail({}), null);

  const active = babysitStatus(parseSessionFrontmatter(SESSION_FILE), AT_1427);
  assert.deepEqual(babysitDetail({ babysit: active }), {
    tone: "accent",
    text: "drive · next check 2026-09-30T14:30:04Z · 2 replies to post",
  });

  const stale = babysitStatus(parseSessionFrontmatter(SESSION_FILE), AT_STALE);
  assert.match(babysitDetail({ babysit: stale }).text, /^stale since 2026-09-30T14:26:04Z · run died without finishing/);

  const one = babysitStatus(parseSessionFrontmatter(SESSION_FILE.replace("unposted_replies: 2", "unposted_replies: 1")), AT_1427);
  assert.match(babysitDetail({ babysit: one }).text, /1 reply to post$/);
});

test("a backed-off run on a quiet PR is active, not stale", () => {
  // A PR sitting for days polls every 30 minutes. A fixed 12-minute window
  // would call this healthy run dead, which is the bug this guards.
  const quiet = parseSessionFrontmatter(SESSION_FILE
    .replace('last_poll: "2026-09-30T14:26:04Z"', 'last_poll: "2026-09-30T14:00:00Z"')
    .replace('next_poll: "2026-09-30T14:30:04Z"', 'next_poll: "2026-09-30T14:30:00Z"'));
  assert.equal(babysitStatus(quiet, Date.parse("2026-09-30T14:25:00Z")).state, "active");
  assert.equal(babysitStatus(quiet, Date.parse("2026-09-30T14:39:00Z")).state, "active");
  assert.equal(babysitStatus(quiet, Date.parse("2026-09-30T14:41:00Z")).state, "stale");
});

test("a run with no next_poll falls back to last_poll plus grace", () => {
  const fm = parseSessionFrontmatter(SESSION_FILE.replace('next_poll: "2026-09-30T14:30:04Z"', "next_poll: null"));
  assert.equal(babysitStatus(fm, Date.parse("2026-09-30T14:30:00Z")).state, "active");
  assert.equal(babysitStatus(fm, Date.parse("2026-09-30T14:40:00Z")).state, "stale");
});
