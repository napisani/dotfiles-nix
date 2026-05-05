---
title: Axion PR Opener Shared Skill Design
date: 2026-05-04
status: draft
---

# Axion PR Opener Shared Skill Design

## Summary

Create a single shared skill, `axion-pr-opener`, that replaces the current OpenCode-only PR opener subagent and its two command wrappers. The skill should work across all configured agents, open GitHub pull requests tied to Jira tickets in the `AGP` project, and handle both flows: using an existing assigned ticket or creating a new one when no suitable assigned ticket exists.

## Goals

- Replace the OpenCode-specific PR workflow with a reusable shared skill.
- Preserve the current Axion Ray PR template and PR title conventions.
- Switch Jira operations from Jira MCP usage to the installed `acli-jira` skill.
- Support both existing-ticket and new-ticket flows inside one skill.
- Install the skill for all agents through the existing shared-skills sync in `mods/agents.nix`.

## Non-Goals

- Preserve OpenCode subagent or slash-command compatibility.
- Introduce new Jira defaults beyond the current workflow requirements.
- Automatically assign reviewers, labels, or milestones.
- Change community skill installation behavior in `mods/agents.nix`.

## Placement

The new skill will live at:

`mods/dotfiles/agents/shared-skills/axion-pr-opener/SKILL.md`

This location is already synchronized to the shared skill store and then made available to all configured agents by `mods/agents.nix`. No new installation wiring is required.

## Triggering

The skill description should be written to trigger on requests such as:

- opening a PR
- creating a PR tied to Jira
- creating a new Jira ticket and PR together
- finding an assigned ticket for the current branch and opening a PR
- following the Axion Ray PR workflow

The description should mention the conditions under which the skill applies, not the step-by-step workflow. It should explicitly mention `AGP`, existing versus new ticket selection, and the Axion Ray PR process so the skill triggers for broad natural-language requests.

## Workflow

### Decision Phase

The skill starts by deciding which ticket flow applies:

1. If the user explicitly asks for a new ticket, create a new `AGP` ticket.
2. If the user provides a concrete `AGP-<number>` ticket, use that ticket.
3. Otherwise, inspect repository context and look for a relevant existing `AGP` ticket assigned to the current user.
4. If multiple plausible assigned tickets are found, ask the user to choose from a short list before proceeding.
5. If no suitable assigned ticket exists, create a new `AGP` ticket.

### Shared PR Preparation Phase

After ticket resolution, both branches follow the same PR-opening workflow:

1. Inspect branch status and change context with `git` and `gh`.
2. Summarize the branch in a concise PR title and body.
3. Create the PR title in the format `AGP-<TICKET_NUMBER> - <SHORT_DESCRIPTION>`.
4. Fill the standard PR template with the Jira URL and branch-specific summary.
5. Create the PR with `gh`.
6. Return a short team-share summary plus the PR URL.

## Tooling Rules

The skill should instruct agents to:

- use `git` for working tree, branch, and diff context
- use `gh` for GitHub pull request operations
- use the `acli-jira` skill for Jira operations
- not use Jira MCP for this workflow

Because the skill is intended to be cross-agent, it should avoid OpenCode-specific command concepts and describe the workflow in agent-neutral terms.

## Jira Rules

The skill should enforce these Jira-specific invariants:

- project key is always `AGP`
- only consider tickets assigned to the current user when searching for existing tickets
- prefer tickets in the current active sprint when choosing an existing ticket

When creating a new Jira ticket, default to:

- issue type: `Task`
- priority: `Medium`
- story points: `3`
- assignee: current user
- sprint: current active sprint
- status: `In Review`

The ticket summary and description should be derived from staged changes, branch diff, and recent commits whenever possible, and should stay concise.

## PR Rules

The skill should preserve the existing PR template inline so every agent produces the same output contract:

```md
**Change description:**
<INSERT_CONTENT>
**Jira link:**
<INSERT_CONTENT>
**Steps to QA:**

**Loom Recording + Screenshots**:

**PR Creator Checklist:**

_As a PR Creator, you should review [this guide](https://axionray.atlassian.net/wiki/spaces/epd/pages/2311389190/Pull+Request+Standards) and use the check boxes below to confirm your PR is ready to go:_

- [ ] I have written a PR description and title that clearly explains the changes.
- [ ] I have provided the steps required to QA this change in a PR env
- [ ] I have linked to a Loom video that showcases the change, and how I tested it
- [ ] I have updated the necessary .md files for the feature that I have altered or I have included documentation for my new feature in the form of a .md file.
- [ ] _(Optional)_ I have included automated tests
- [ ] _(Optional)_ I have run the [Robust Suite E2E GH Action](https://github.com/Axion-Ray/axion-multisite/actions/workflows/run-e2e-tests.yaml) to ensure check for regressions.

**PR Reviewer Checklist:**

_As a PR reviewer, you should review [this guide](https://axionray.atlassian.net/wiki/spaces/epd/pages/2311389190/Pull+Request+Standards) and use the check boxes below to confirm the step you took when reviewing this PR:_

- [ ] I have performed the _Steps to QA_ in this PR in a local/PR environment.
- [ ] I have confirmed this work is ready to be seen by users, or is behind a feature flag.
- [ ] I have confirmed that any migrations are backwards compatible or can be rolled back.
- [ ] I confirm the PR details have been filled in satisfactorily.
- [ ] I confirm the documentation updates are clearly written and helpful.
```

Additional PR invariants:

- always include the full Jira URL in the PR body
- never assign reviewers, labels, or milestones automatically
- the change description should summarize purpose and impact, not enumerate file-by-file edits

## Asking Versus Inferring

The skill should infer as much as safely possible from repository state, but ask the user when:

- multiple assigned tickets plausibly match the branch
- the ticket or PR summary would otherwise be speculative
- required QA steps cannot be inferred safely

This keeps the workflow efficient without allowing the agent to invent project context.

## Migration Plan

Implementation should:

1. Add the new shared skill directory and `SKILL.md`.
2. Remove the OpenCode-only `axion-pr-opener` subagent file.
3. Remove the OpenCode-only `axion-pr-new-ticket` and `axion-pr-existing-ticket` command files.
4. Leave `mods/agents.nix` functionally unchanged unless a comment update is useful for discoverability.

This keeps the migration minimal by moving the behavior into the shared-skills path already supported by the repository.

## Verification

Verification should cover:

- the skill directory exists in `mods/dotfiles/agents/shared-skills`
- the skill naming and description follow repository skill conventions
- the workflow references `acli-jira`, `git`, and `gh` correctly
- the OpenCode-only files being replaced are removed
- `mods/agents.nix` still syncs shared skills to all agents without additional changes

## Risks

- The existing OpenCode workflow relied on command-specific entry points; the new skill must describe the decision phase clearly enough that agents choose the right branch without those wrappers.
- Jira field names such as story points or sprint assignment may vary by environment; the skill should rely on `acli-jira` guidance instead of embedding unsupported command syntax.
- Generic “open a PR” requests may not always imply Jira ticket creation; the skill description needs to be broad enough to trigger, while the body still asks when intent is ambiguous.

## Recommendation

Implement the shared skill as a single `axion-pr-opener` skill with an early decision point for existing versus new ticket flows, keep the PR template inline, and remove the OpenCode-only wrappers it replaces.
