"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { actionPrompt, classifyPullRequest, updateStateAfterDispatch } = require("./loancrate-pr-tui-core.js");
const { LoancratePrTuiView, statusSignals } = require("./loancrate-pr-tui.js");

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
