"use strict";

/** Pure signal interpretation for the /loancrate-pr-tui Pi extension. */

const BOT_LOGINS = new Set(["devin-ai-integration", "unblocked"]);

function isBot(login) {
  return !login || login.endsWith("[bot]") || BOT_LOGINS.has(login);
}

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

function latestReviews(reviews) {
  const byAuthor = new Map();
  for (const review of reviews ?? []) {
    const login = review?.author?.login;
    if (!login || !review.submittedAt) continue;
    const old = byAuthor.get(login);
    if (!old || old.submittedAt < review.submittedAt) byAuthor.set(login, review);
  }
  return [...byAuthor.values()];
}

function quotedReplyExists(comment, allComments, viewer) {
  const original = text(comment.body).replace(/\s+/g, " ");
  if (original.length < 12) return false;
  const phrase = original.slice(0, Math.min(original.length, 80)).toLowerCase();
  return (allComments ?? []).some((reply) =>
    reply?.author?.login === viewer &&
    reply.createdAt > comment.createdAt &&
    text(reply.body).toLowerCase().includes(phrase),
  );
}

function outstandingFeedback(pr, viewer) {
  const ids = [];
  const descriptions = [];
  const comments = [...(pr.comments?.nodes ?? [])].sort((a, b) => (a.createdAt ?? "").localeCompare(b.createdAt ?? ""));

  for (const thread of pr.reviewThreads?.nodes ?? []) {
    const threadComments = thread?.comments?.nodes ?? [];
    const last = threadComments.at(-1);
    const login = last?.author?.login;
    if (!thread?.isResolved && last && login !== viewer && !isBot(login)) {
      ids.push(`rt:${thread.id}`);
      descriptions.push(`${login}: ${text(last.body).slice(0, 120) || "unresolved review thread"}`);
    }
  }

  for (const comment of comments) {
    const login = comment?.author?.login;
    if (!comment?.databaseId || login === viewer || isBot(login)) continue;
    if (!quotedReplyExists(comment, comments, viewer)) {
      ids.push(`ic:${comment.databaseId}`);
      descriptions.push(`${login}: ${text(comment.body).slice(0, 120) || "unanswered PR comment"}`);
    }
  }

  for (const review of latestReviews(pr.reviews?.nodes)) {
    const login = review?.author?.login;
    const body = text(review?.body);
    const requestsChanges = review?.state === "CHANGES_REQUESTED";
    const humanComment = review?.state === "COMMENTED" && !isBot(login);
    if (!body || (!requestsChanges && !humanComment)) continue;
    if (requestsChanges || !isBot(login)) {
      ids.push(`rv:${login}:${review.submittedAt}`);
      descriptions.push(`${login}: ${body.slice(0, 120)}`);
    }
  }

  return { ids: [...new Set(ids)], descriptions };
}

function ciFailures(pr) {
  const rollup = pr.commits?.nodes?.at(-1)?.commit?.statusCheckRollup;
  const state = rollup?.state ?? "PENDING";
  const failed = [];
  for (const context of rollup?.contexts?.nodes ?? []) {
    const result = context.__typename === "CheckRun" ? context.conclusion : context.state;
    if (result !== "FAILURE" && result !== "ERROR") continue;
    failed.push({
      name: context.__typename === "CheckRun" ? context.name : context.context,
      required: Boolean(context.isRequired),
    });
  }
  const specific = failed.filter((check) => check.name !== "pull_request_shared");
  return {
    state,
    failed: specific.length > 0 ? specific.concat(failed.filter((check) => check.name === "pull_request_shared")) : failed,
    failing: state === "FAILURE" || state === "ERROR",
  };
}

function mergeSummary(pr, ci) {
  if (pr.isDraft || pr.mergeStateStatus === "DRAFT") return "Draft";
  if (pr.mergeable === "CONFLICTING" || pr.mergeStateStatus === "DIRTY") return "Conflicts with base";
  if (pr.mergeStateStatus === "BEHIND") return "Behind base branch";
  const required = ci.failed.filter((check) => check.required);
  if (required.length > 0) return `Failing required check: ${required[0].name}`;
  if (pr.mergeStateStatus === "BLOCKED") return "Awaiting required approval";
  if (ci.state === "PENDING" || ci.state === "EXPECTED") return "CI running";
  if (pr.mergeable === "UNKNOWN" || pr.mergeStateStatus === "UNKNOWN") return "GitHub still computing mergeability";
  return "—";
}

function initialAction(pr, feedback, ci) {
  if (pr.mergeable === "UNKNOWN" || pr.mergeStateStatus === "UNKNOWN") {
    return { kind: "none", reason: "Mergeability is still computing" };
  }
  if (pr.mergeable === "CONFLICTING" || pr.mergeStateStatus === "DIRTY") {
    return { kind: "rebase", reason: "Conflicts outrank all lower-priority work" };
  }
  if (ci.failing) {
    return { kind: "ci", reason: `CI is failing: ${ci.failed.map((check) => check.name).join(", ") || "unknown check"}` };
  }
  const changesRequested = latestReviews(pr.reviews?.nodes).some((review) => review.state === "CHANGES_REQUESTED");
  if (!pr.isDraft && (feedback.ids.length > 0 || changesRequested)) {
    return { kind: "feedback", reason: `${feedback.ids.length} unanswered feedback item(s)` };
  }
  if (pr.isDraft) return { kind: "none", reason: "Draft PR" };
  if (ci.state === "PENDING" || ci.state === "EXPECTED") return { kind: "none", reason: "CI running" };
  if (pr.reviewDecision === "APPROVED" && pr.mergeable === "MERGEABLE") return { kind: "none", reason: "Ready to merge" };
  return { kind: "none", reason: "No new action" };
}

function applyResendRules(action, pr, feedback, state) {
  const previous = state?.prs?.[String(pr.number)];
  if (action.kind === "none") return action;

  if (action.kind === "feedback") {
    const handled = new Set(previous?.handled_ids ?? []);
    const newIds = feedback.ids.filter((id) => !handled.has(id));
    if (newIds.length === 0) return { kind: "none", reason: "Feedback already dispatched; no new items", newIds: [] };
    return { ...action, newIds };
  }

  if (action.kind === "rebase") {
    if (previous?.last_action === "rebase" && previous.head_oid === pr.headRefOid) {
      return { kind: "manual", reason: "Rebase was already dispatched for this unchanged conflicting head" };
    }
    return action;
  }

  if (action.kind === "ci") {
    if (previous?.last_action === "ci" && previous.head_oid === pr.headRefOid) {
      return { kind: "none", reason: "CI action already dispatched for this unchanged head" };
    }
    if ((previous?.ci_attempts ?? 0) >= 2) {
      return { kind: "manual", reason: "Two CI repair attempts still left this PR red" };
    }
  }
  return action;
}

function classifyPullRequest(pr, viewer, state) {
  const feedback = outstandingFeedback(pr, viewer);
  const ci = ciFailures(pr);
  const action = applyResendRules(initialAction(pr, feedback, ci), pr, feedback, state);
  const blocking = mergeSummary(pr, ci);
  const ready = pr.reviewDecision === "APPROVED" && pr.mergeable === "MERGEABLE";
  return {
    number: pr.number,
    url: pr.url,
    title: pr.title,
    branch: pr.headRefName,
    base: pr.baseRefName,
    headOid: pr.headRefOid,
    draft: pr.isDraft,
    mergeable: pr.mergeable ?? "UNKNOWN",
    mergeStateStatus: pr.mergeStateStatus ?? "UNKNOWN",
    approved: pr.reviewDecision === "APPROVED",
    ready,
    blocking,
    feedback,
    ci,
    action,
  };
}

function actionPrompt(pr) {
  switch (pr.action.kind) {
    case "rebase":
      return "/rebase-from-parent\n\nThis branch has merge conflicts with its base. Rebase from the parent, resolve every conflict you can resolve confidently, and push the result automatically. If you hit a conflict you cannot resolve safely, or the push is rejected, abort and leave a clear note asking for my intervention rather than guessing.";
    case "ci": {
      const names = pr.ci.failed.map((check) => check.name).filter(Boolean).join(", ");
      return `CI is failing on this PR: ${names}. Review the CI failures and work out whether the failure was introduced by this branch. If this branch introduced it, fix it and push the fix. If the failure is upstream, run /rebase-from-parent, resolve any conflicts, and push. If you cannot tell which it is, or the fix is not one you can make safely, stop and ask for my intervention rather than guessing.`;
    }
    case "feedback":
      return `/address-pr-feedback ${pr.url}\n\nThere is new review feedback on this PR that has not been addressed yet.`;
    default:
      return "";
  }
}

function updateStateAfterDispatch(state, pr, target, now = new Date().toISOString()) {
  const next = structuredClone(state ?? { version: 1, prs: {} });
  next.version = 1;
  next.prs ??= {};
  const previous = next.prs[String(pr.number)] ?? { handled_ids: [], ci_attempts: 0 };
  const handled = new Set(previous.handled_ids ?? []);
  for (const id of pr.action.newIds ?? (pr.action.kind === "feedback" ? pr.feedback.ids : [])) handled.add(id);
  next.prs[String(pr.number)] = {
    ...previous,
    last_action: pr.action.kind,
    dispatched_at: now,
    head_oid: pr.headOid,
    target,
    handled_ids: [...handled],
    ci_attempts: pr.action.kind === "ci" ? (previous.ci_attempts ?? 0) + 1 : (pr.ci.state === "SUCCESS" ? 0 : (previous.ci_attempts ?? 0)),
  };
  return next;
}

// This file lives beside the extension because Pi resolves relative imports from
// the linked extension directory. It is also discovered as an extension itself;
// exporting a no-op factory keeps that discovery harmless while preserving named
// exports for loancrate-pr-tui.js and its tests.
function loancratePrTuiCoreExtension() {}
Object.assign(loancratePrTuiCoreExtension, {
  actionPrompt,
  classifyPullRequest,
  ciFailures,
  isBot,
  outstandingFeedback,
  updateStateAfterDispatch,
});
module.exports = loancratePrTuiCoreExtension;
