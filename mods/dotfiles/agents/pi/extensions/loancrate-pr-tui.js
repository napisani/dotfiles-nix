"use strict";

const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { createRequire } = require("node:module");
const { actionPrompt, classifyPullRequest, updateStateAfterDispatch } = require("./loancrate-pr-tui-core.js");

let piTui;
function getPiTui() {
  if (piTui) return piTui;
  try {
    piTui = require("@earendil-works/pi-tui");
  } catch (_error) {
    // Local extensions are linked as individual files, so Node does not walk
    // through Pi's ~/.pi/agent/npm package root when resolving bare imports.
    // The package is declared directly in the Nix Pi package list; resolve it
    // from that package root explicitly instead of relying on NODE_PATH.
    const agentDir = process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");
    piTui = createRequire(path.join(agentDir, "npm", "package.json"))("@earendil-works/pi-tui");
  }
  return piTui;
}

const REPO = "loancrate/loancrate";
const STATE_FILE = path.join(os.homedir(), ".local", "state", "loancrate-pr-maintainer", "state.json");
// loancrate-pr-maintainer is a pinned skill, so Pi links it into its own
// skill directory rather than the shared ~/.agents/skills store.
const SKILL_DIR = path.join(os.homedir(), ".pi", "agent", "skills", "loancrate-pr-maintainer");
const FIND_PANE = path.join(SKILL_DIR, "scripts", "find-agent-pane.sh");
const SEND_PROMPT = path.join(SKILL_DIR, "scripts", "send-prompt.sh");
const GRAPHQL_QUERY = `
query($owner:String!,$repo:String!,$number:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      url number title headRefName baseRefName headRefOid
      isDraft mergeable mergeStateStatus reviewDecision
      reviewThreads(first:100){nodes{
        id isResolved isOutdated
        comments(first:50){nodes{databaseId author{login} createdAt body}}
      }}
      comments(first:100){nodes{databaseId author{login} createdAt body}}
      reviews(first:50){nodes{author{login} state submittedAt body}}
      commits(last:1){nodes{commit{
        statusCheckRollup{
          state
          contexts(first:100){nodes{
            __typename
            ... on CheckRun{name status conclusion detailsUrl isRequired(pullRequestNumber:$number)}
            ... on StatusContext{context state targetUrl isRequired(pullRequestNumber:$number)}
          }}
        }
      }}}
    }
  }
}`;

async function exec(pi, command, args, timeout = 30_000) {
  const result = await pi.exec(command, args, { timeout });
  if (result.code !== 0) {
    throw new Error((result.stderr || result.stdout || `${command} failed`).trim());
  }
  return result.stdout;
}

async function readState() {
  try {
    return JSON.parse(await fs.readFile(STATE_FILE, "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
    return { version: 1, prs: {} };
  }
}

async function writeState(state) {
  const directory = path.dirname(STATE_FILE);
  await fs.mkdir(directory, { recursive: true });
  const temporary = `${STATE_FILE}.${process.pid}.tmp`;
  await fs.writeFile(temporary, `${JSON.stringify(state, null, 2)}\n`, "utf8");
  await fs.rename(temporary, STATE_FILE);
}

function parseArgs(args) {
  const result = { send: false, pr: undefined };
  const tokens = args.trim().split(/\s+/).filter(Boolean);
  for (let i = 0; i < tokens.length; i += 1) {
    if (tokens[i] === "--send") result.send = true;
    if (tokens[i] === "--pr") result.pr = Number(tokens[++i]);
  }
  return result;
}

async function queryPullRequest(pi, number) {
  const response = JSON.parse(await exec(pi, "gh", [
    "api", "graphql", "-F", "owner=loancrate", "-F", "repo=loancrate", "-F", `number=${number}`,
    "-f", `query=${GRAPHQL_QUERY}`,
  ]));
  const pr = response.data?.repository?.pullRequest;
  if (!pr) throw new Error("GitHub returned no pull request data");
  if (pr.mergeable === "UNKNOWN" || pr.mergeStateStatus === "UNKNOWN") {
    await new Promise((resolve) => setTimeout(resolve, 3_000));
    const retry = JSON.parse(await exec(pi, "gh", [
      "api", "graphql", "-F", "owner=loancrate", "-F", "repo=loancrate", "-F", `number=${number}`,
      "-f", `query=${GRAPHQL_QUERY}`,
    ]));
    return retry.data?.repository?.pullRequest ?? pr;
  }
  return pr;
}

async function collectPullRequests(pi, options) {
  const viewer = (await exec(pi, "gh", ["api", "user", "--jq", ".login"])).trim();
  const list = JSON.parse(await exec(pi, "gh", [
    "pr", "list", "--repo", REPO, "--author", viewer, "--state", "open", "--limit", "100",
    "--json", "number,url,title,headRefName,baseRefName,isDraft,updatedAt",
  ]));
  const selected = options.pr === undefined ? list : list.filter((pr) => pr.number === options.pr);
  const state = await readState();
  const rows = await Promise.all(selected.map(async (summary) => {
    try {
      const pr = await queryPullRequest(pi, summary.number);
      return classifyPullRequest(pr, viewer, state);
    } catch (error) {
      return {
        ...summary,
        branch: summary.headRefName,
        base: summary.baseRefName,
        mergeable: "UNKNOWN",
        mergeStateStatus: "UNKNOWN",
        approved: false,
        ready: false,
        blocking: `Could not refresh: ${error.message}`,
        feedback: { ids: [], descriptions: [] },
        ci: { state: "PENDING", failed: [], failing: false },
        action: { kind: "manual", reason: `Could not refresh: ${error.message}` },
      };
    }
  }));
  let stateChanged = false;
  for (const row of rows) {
    const previous = state.prs?.[String(row.number)];
    if (row.ci.state === "SUCCESS" && previous?.ci_attempts > 0) {
      previous.ci_attempts = 0;
      stateChanged = true;
    }
  }
  // A preview must not mutate the durable dedupe file. In send mode, persist
  // the CI-attempt reset so a later red run gets a fresh pair of attempts.
  if (stateChanged && options.send) await writeState(state);
  return { viewer, state, rows };
}

async function findPane(pi, branch) {
  try {
    const output = await exec(pi, FIND_PANE, [branch], 10_000);
    const [status = "no-session", target = "", detail = ""] = output.trim().split("\t");
    return { status, target, detail };
  } catch (error) {
    return { status: "no-session", target: "", detail: error.message };
  }
}

async function addPaneStatus(pi, rows) {
  return Promise.all(rows.map(async (row) => ({ ...row, pane: await findPane(pi, row.branch) })));
}

function actionLabel(row) {
  switch (row.action.kind) {
    case "rebase": return "Rebase";
    case "ci": return "Fix CI";
    case "feedback": return `Address ${row.feedback.ids.length}`;
    case "manual": return "Needs you";
    default: return row.action.reason === "Ready to merge" ? "—" : "Wait";
  }
}

function actionColor(theme, row) {
  if (row.action.kind === "manual" || row.pane?.status === "no-agent" || row.pane?.status === "no-session") return "error";
  if (row.action.kind !== "none") return "warning";
  if (row.ready) return "success";
  return "muted";
}

function mergeLabel(row) {
  if (row.ready) return "ready";
  if (row.mergeable === "CONFLICTING" || row.mergeStateStatus === "DIRTY") return "conflicts";
  if (row.ci.failing) return "CI red";
  if (row.feedback.ids.length > 0) return "feedback";
  if (row.ci.state === "PENDING" || row.ci.state === "EXPECTED") return "CI running";
  if (row.draft) return "draft";
  return row.mergeStateStatus.toLowerCase();
}

function hasDispatchAction(row) {
  return Boolean(row && ["rebase", "ci", "feedback"].includes(row.action.kind));
}

function unavailableReason(row) {
  if (!row) return "no pull request selected";
  if (row.action.kind === "manual") return row.action.reason;
  if (!hasDispatchAction(row)) {
    if (row.ready) return "approved and mergeable; merging remains a manual decision";
    return row.action.reason;
  }
  switch (row.pane?.status) {
    case "busy": return "the agent pane is busy";
    case "no-session": return "no matching workmux session exists for this branch";
    case "no-agent": return row.pane.detail || "the target pane is not a live agent";
    case "ok": return undefined;
    default: return "the agent pane could not be verified";
  }
}

function isDispatchable(row) {
  return hasDispatchAction(row) && unavailableReason(row) === undefined;
}

const PR_VIEWS = [
  { id: "all", label: "All", matches: () => true },
  { id: "actionable", label: "Actionable", matches: isDispatchable },
  { id: "working", label: "Working", matches: (row) => hasDispatchAction(row) && row.pane?.status === "busy" },
  { id: "waiting", label: "Waiting", matches: (row) => row.action.kind === "none" && !row.ready },
  { id: "ready", label: "Ready", matches: (row) => row.ready },
  {
    id: "needs-you",
    label: "Needs You",
    matches: (row) => row.action.kind === "manual" || (hasDispatchAction(row) && ["no-session", "no-agent"].includes(row.pane?.status)),
  },
];

function stageIndicator(row, staged) {
  if (staged) return "[x]";
  if (isDispatchable(row)) return "[ ]";
  if (row.action.kind === "manual") return "[- manual]";
  if (!hasDispatchAction(row)) return row.ready ? "[- ready]" : "[- wait]";
  if (row.pane?.status === "busy") return "[- busy]";
  if (row.pane?.status === "no-session") return "[- no pane]";
  if (row.pane?.status === "no-agent") return "[- no agent]";
  return "[- unknown]";
}

function singleLine(value) {
  return String(value ?? "").replace(/[\r\n\t\u2028\u2029]+/g, " ");
}

function pad(text, width) {
  const { truncateToWidth, visibleWidth } = getPiTui();
  const fitted = truncateToWidth(singleLine(text), width, "");
  return `${fitted}${" ".repeat(Math.max(0, width - visibleWidth(fitted)))}`;
}

class LoancratePrTuiView {
  constructor(tui, theme, rows, options) {
    this.tui = tui;
    this.theme = theme;
    this.rows = rows;
    this.options = options;
    this.selected = 0;
    this.activeView = "all";
    this.staged = new Set();
    this.confirming = false;
    this.busy = false;
    this.notice = options.initialNotice || "Preview only — nothing will be sent until you confirm.";
  }

  setRows(rows, notice) {
    this.rows = rows;
    this.selected = Math.min(this.selected, Math.max(0, this.filteredRows().length - 1));
    this.busy = false;
    if (notice) this.notice = notice;
    this.tui.requestRender();
  }

  setBusy(busy, notice) {
    this.busy = busy;
    if (notice) this.notice = notice;
    this.tui.requestRender();
  }

  currentView() {
    return PR_VIEWS.find((view) => view.id === this.activeView) ?? PR_VIEWS[0];
  }

  filteredRows() {
    return this.rows.filter(this.currentView().matches);
  }

  current() { return this.filteredRows()[this.selected]; }

  setView(viewId) {
    if (!PR_VIEWS.some((view) => view.id === viewId)) return;
    this.activeView = viewId;
    this.selected = 0;
    this.notice = `Showing ${this.currentView().label.toLowerCase()} pull requests.`;
    this.tui.requestRender();
  }

  cycleView(direction) {
    const current = PR_VIEWS.findIndex((view) => view.id === this.activeView);
    const next = (current + direction + PR_VIEWS.length) % PR_VIEWS.length;
    this.setView(PR_VIEWS[next].id);
  }

  visibleRows() {
    // Custom components share the terminal with Pi's footer/status rows. If
    // the component renders past the viewport, differential redraws can scroll
    // old rows back into view instead of replacing them. Keep a stable,
    // viewport-sized slice and retain the selected row inside that slice.
    const terminalRows = this.tui.terminal?.rows || 40;
    const compact = terminalRows < 32;
    const reserved = compact ? 18 : 24;
    const maxRows = Math.max(1, terminalRows - reserved);
    const filtered = this.filteredRows();
    const start = Math.min(
      Math.max(0, this.selected - Math.floor(maxRows / 2)),
      Math.max(0, filtered.length - maxRows),
    );
    return {
      start,
      rows: filtered.slice(start, start + maxRows),
      compact,
    };
  }

  canStage(row) {
    return isDispatchable(row);
  }

  toggleStage() {
    const row = this.current();
    if (!this.canStage(row)) {
      this.notice = `Not staged — ${unavailableReason(row)}.`;
    } else if (this.staged.has(row.number)) {
      this.staged.delete(row.number);
      this.notice = `Removed #${row.number} from the dispatch queue.`;
    } else {
      this.staged.add(row.number);
      this.notice = `Staged #${row.number} — still nothing has been sent.`;
    }
    this.tui.requestRender();
  }

  stageAll() {
    for (const row of this.filteredRows()) if (this.canStage(row)) this.staged.add(row.number);
    this.notice = `${this.staged.size} safe action(s) staged — review before dispatch.`;
    this.tui.requestRender();
  }

  handleInput(data) {
    const { matchesKey } = getPiTui();
    if (this.confirming) {
      if (matchesKey(data, "escape") || data === "n") {
        this.confirming = false;
        this.notice = "Dispatch cancelled. Staged actions remain queued.";
        this.tui.requestRender();
      } else if (matchesKey(data, "enter") || data === "y") {
        this.confirming = false;
        this.options.onDispatch([...this.staged]);
      }
      return;
    }
    if (matchesKey(data, "escape") || data === "q") return this.options.onClose();
    if (matchesKey(data, "tab")) {
      this.cycleView(1);
      return;
    } else if (matchesKey(data, "shift+tab")) {
      this.cycleView(-1);
      return;
    } else if (/^[1-6]$/.test(data)) {
      this.setView(PR_VIEWS[Number(data) - 1].id);
      return;
    } else if (matchesKey(data, "up") || data === "k") {
      this.selected = Math.max(0, this.selected - 1);
    } else if (matchesKey(data, "down") || data === "j") {
      this.selected = Math.min(Math.max(0, this.filteredRows().length - 1), this.selected + 1);
    } else if (matchesKey(data, "space") || matchesKey(data, "enter")) {
      this.toggleStage();
      return;
    } else if (data === "a") {
      this.stageAll();
      return;
    } else if (data === "s") {
      if (this.staged.size === 0) this.notice = "Nothing staged. Select a dispatchable row and press Space.";
      else this.confirming = true;
    } else if (data === "r") {
      this.options.onRefresh();
      return;
    } else if (data === "o") {
      const row = this.current();
      if (row?.url) this.options.onOpen(row.url);
      return;
    }
    this.tui.requestRender();
  }

  line(text, width) {
    const { truncateToWidth } = getPiTui();
    return truncateToWidth(singleLine(text), width);
  }

  render(width) {
    const th = this.theme;
    const lines = [];
    const inner = Math.max(20, width - 2);
    const border = th.fg("border", "│");
    const top = th.fg("border", `╭${"─".repeat(inner)}╮`);
    const bottom = th.fg("border", `╰${"─".repeat(inner)}╯`);
    const row = (content, background) => {
      const body = pad(this.line(content, inner), inner);
      return border + (background ? th.bg("selectedBg", body) : body) + border;
    };
    lines.push("");
    lines.push(top);
    const filtered = this.filteredRows();
    const mode = this.confirming ? th.fg("warning", "CONFIRM DISPATCH") : th.fg("accent", "PREVIEW MODE");
    lines.push(row(` ${th.bold("Loancrate PR TUI")}  ${mode}  ${th.fg("dim", `${filtered.length}/${this.rows.length} shown`)}`));
    lines.push(row(` ${th.fg("muted", `${this.staged.size} staged · ${this.busy ? "refreshing…" : "GitHub + tmux connected"}`)}`));
    const views = PR_VIEWS.map((view, index) => {
      const count = this.rows.filter(view.matches).length;
      const label = `${index + 1}:${view.label} ${count}`;
      return view.id === this.activeView ? th.fg("accent", `[${label}]`) : th.fg("dim", label);
    }).join("  ");
    lines.push(row(` ${views}`));
    lines.push(row(""));

    if (this.confirming) {
      lines.push(row(` ${th.fg("warning", `Dispatch ${this.staged.size} staged prompt(s)?`)}`));
      lines.push(row(` ${th.fg("muted", "Press Enter or y to send. Escape or n cancels. Each pane is rechecked immediately before send.")}`));
      lines.push(row(""));
    }

    const tableWidth = width >= 100 ? Math.min(width - 2, 105) : inner;
    const visible = this.visibleRows();
    const range = visible.rows.length < filtered.length ? ` · showing ${visible.start + 1}-${visible.start + visible.rows.length}` : "";
    const header = `${pad("stage", 12)} ${pad("PR", 6)} ${pad("branch", 25)} ${pad("state", 13)} action${range}`;
    lines.push(row(` ${th.fg("dim", this.line(header, tableWidth - 1))}`));
    for (let offset = 0; offset < visible.rows.length; offset += 1) {
      const i = visible.start + offset;
      const pr = visible.rows[offset];
      const indicator = stageIndicator(pr, this.staged.has(pr.number));
      const checkbox = th.fg(this.staged.has(pr.number) ? "accent" : this.canStage(pr) ? "text" : "dim", indicator);
      const health = pr.ready ? th.fg("success", "✓") : pr.action.kind === "manual" ? th.fg("error", "!") : pr.action.kind !== "none" ? th.fg("warning", "●") : th.fg("dim", "·");
      const state = th.fg(actionColor(th, pr), mergeLabel(pr));
      const action = th.fg(actionColor(th, pr), actionLabel(pr));
      const content = `${pad(checkbox, 12)} ${health} ${pad(`#${pr.number}`, 6)} ${pad(pr.branch, 25)} ${pad(state, 13)} ${action}`;
      lines.push(row(` ${this.line(content, tableWidth - 1)}`, i === this.selected));
    }

    const selected = this.current();
    lines.push(row(""));
    if (selected) {
      lines.push(row(` ${th.fg("accent", `#${selected.number} · ${selected.title}`)}`));
      if (!visible.compact) lines.push(row(` ${th.fg("dim", `${selected.branch} → ${selected.base}`)}`));
      lines.push(row(` ${th.fg("muted", "Recommended:")} ${th.fg(actionColor(th, selected), actionLabel(selected))} ${th.fg("dim", `— ${selected.action.reason}`)}`));
      const unavailable = unavailableReason(selected);
      lines.push(row(unavailable
        ? ` ${th.fg("muted", "Dispatch:")} ${th.fg("warning", "Unavailable")} ${th.fg("dim", `— ${unavailable}`)}`
        : ` ${th.fg("muted", "Dispatch:")} ${th.fg("success", "Available")} ${th.fg("dim", "— press Space to stage")}`));
      if (!visible.compact) {
        lines.push(row(` ${th.fg("muted", "Merge:")} ${selected.mergeable} / ${selected.mergeStateStatus}   ${th.fg("muted", "Agent:")} ${selected.pane?.status || "not checked"}${selected.pane?.target ? ` · ${selected.pane.target}` : ""}`));
        if (selected.ci.failed.length > 0) lines.push(row(` ${th.fg("error", `Failing: ${selected.ci.failed.map((check) => check.name).join(", ")}`)}`));
        if (selected.feedback.descriptions.length > 0) lines.push(row(` ${th.fg("warning", `Feedback: ${selected.feedback.descriptions[0]}${selected.feedback.descriptions.length > 1 ? ` (+${selected.feedback.descriptions.length - 1} more)` : ""}`)}`));
        if (selected.blocking !== "—") lines.push(row(` ${th.fg("muted", `Blocking: ${selected.blocking}`)}`));
      }
    } else {
      lines.push(row(` ${th.fg("dim", "No open PRs authored by you.")}`));
    }
    lines.push(row(""));
    lines.push(row(` ${this.line(th.fg(this.confirming ? "warning" : "muted", this.notice), inner - 1)}`));
    lines.push(row(` ${th.fg("dim", "Tab/Shift+Tab view · 1-6 jump · ↑↓/jk select · Space stage · a stage view · s dispatch · r refresh · o open · q close")}`));
    lines.push(bottom);
    return lines;
  }

  invalidate() {}
}

async function dispatchStaged(pi, ctx, rows, selectedNumbers, setRows) {
  const state = await readState();
  let sent = 0;
  let skipped = 0;
  const dispatched = new Set();
  for (const row of rows.filter((candidate) => selectedNumbers.includes(candidate.number))) {
    const pane = await findPane(pi, row.branch);
    if (pane.status !== "ok") {
      skipped += 1;
      continue;
    }
    try {
      await exec(pi, SEND_PROMPT, [pane.target, actionPrompt(row)], 10_000);
      const nextState = updateStateAfterDispatch(state, row, pane.target);
      state.prs = nextState.prs;
      await writeState(state);
      dispatched.add(row.number);
      sent += 1;
    } catch (error) {
      skipped += 1;
      ctx.ui.notify(`#${row.number} was not dispatched: ${error.message}`, "error");
    }
  }
  setRows(rows.map((row) => dispatched.has(row.number) ? { ...row, action: { kind: "none", reason: "Prompt dispatched; refresh to collect new state" } } : row), `Dispatch complete: ${sent} sent${skipped ? ` · ${skipped} skipped` : ""}. Refresh to see updated signals.`);
}

function loancratePrTuiExtension(pi) {
  pi.registerCommand("loancrate-pr-tui", {
    description: "Open the Loancrate PR TUI operator console",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/loancrate-pr-tui requires interactive TUI mode", "error");
        return;
      }
      const options = parseArgs(args);
      ctx.ui.notify("Refreshing Loancrate PR TUI…", "info");
      let collected = await collectPullRequests(pi, options);
      let rows = await addPaneStatus(pi, collected.rows);
      let view;
      const refresh = async () => {
        if (view) view.setBusy(true, "Refreshing GitHub signals and checking agent panes…");
        try {
          collected = await collectPullRequests(pi, options);
          rows = await addPaneStatus(pi, collected.rows);
          view?.setRows(rows, "Preview refreshed — no prompts sent.");
        } catch (error) {
          view?.setBusy(false, `Refresh failed: ${error.message}`);
          ctx.ui.notify(`Loancrate PR TUI refresh failed: ${error.message}`, "error");
        }
      };
      await ctx.ui.custom((tui, theme, _keybindings, done) => {
        view = new LoancratePrTuiView(tui, theme, rows, {
          initialNotice: options.send ? "Send mode requested — review the staged actions before confirming." : undefined,
          onClose: () => done(),
          onRefresh: refresh,
          onOpen: (url) => pi.exec("open", [url]).catch(() => {}),
          onDispatch: async (selectedNumbers) => {
            view.setBusy(true, "Rechecking panes and dispatching…");
            await dispatchStaged(pi, ctx, rows, selectedNumbers, (nextRows, notice) => {
              rows = nextRows;
              view.setRows(nextRows, notice);
            });
          },
        });
        if (options.send) view.stageAll();
        return view;
      });
    },
  });

  pi.registerShortcut("ctrl+shift+r", {
    description: "Open Loancrate PR TUI console",
    handler: async (ctx) => {
      await pi.sendUserMessage("/loancrate-pr-tui", { expandPromptTemplates: true });
    },
  });
}

module.exports = loancratePrTuiExtension;
module.exports.LoancratePrTuiView = LoancratePrTuiView;
