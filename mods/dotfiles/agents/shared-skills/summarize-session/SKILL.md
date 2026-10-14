---
name: summarize-session
description: Re-entry recap of the current task in 30 seconds, covering why it exists, what is done, where it stands, and what is next. For switching back into a worktree.
disable-model-invocation: true
---

# Summarize session

The user juggles many worktrees and is switching back into this one cold. Write a **re-entry brief** they can absorb in about 30 seconds, then stop. The recap exists to restore context cheaply, so it stays read-only and does not move the task forward.

## Gather

Session context is the primary source, above all for the *why*: the request that started the work, a linked ticket or PR, the reasons the user gave, decisions made along the way. Where a later message supersedes an earlier one, report the later.

Corroborate current status with a few cheap local reads: `git branch --show-current`, `git status --short`, `git log --oneline -10`, narrowed to this branch's own commits with `<base>..HEAD` when the base is known. Report a ticket or PR only as the session last knew it, and say so; external status was not checked.

Observe and report only. A recap writes no files, mutates no ticket or PR, and makes no commit, test run, build, or install.

## Format

Write the brief in chat. The default recap, however many tasks it covers, fits in about 150–250 words:

```markdown
## <Task name>
<worktree/branch> · <current status> · <ticket/PR, if any>

### Why
### Done
### Where we are
### Next
```

- **Why**: what prompted the work, who or what it helps, and what success looks like. Connect a ticket to the underlying problem when the session supports it. When motivation is not in the session, write "Motivation not recorded in this session" and offer only what the branch or commits show, labeled as inferred. A grander reason than the evidence supports misleads the next reader.
- **Done**: 3–5 outcome bullets, not tool calls. Include important decisions with their reasons, and verification when it changes how far to trust the result. When nothing is built yet, say that and list what exists instead (investigation, plan, decisions).
- **Where we are**: a short synthesis of what works, what is incomplete, and any blocker or decision still needed. Separate the stages that apply: implemented, tested, committed, pushed, activated. Leave out stages that do not matter to this task.
- **Next**: the next concrete action, then anything else needed to finish. For finished work write "Nothing remaining" plus follow-ups the user already named, and invent no new work.

Trim the header line to what is known. Prefer one sharp sentence to three hedged ones.

## Scope

Recap the task this worktree exists for. Skip conversation history that does not touch it: a side question or work on another repo is not part of the brief. When the worktree itself carries several separate tasks, give each a compact brief under the one word budget, the main task first, and never fuse them into one invented ticket. Split the budget, so three tasks get roughly 60–80 words each.

## Thin context

Compaction alone does not make context thin: treat any retained summary as session context. When the session and any summary hold no record of the motivation or progress, open with one line stating the evidence limit ("Session has no record of the original request; status is from git only"), then deliver a partial recap from what exists. Do not ask clarifying questions; the user wants orientation now, and an honest partial brief serves that better than a blocked one.
