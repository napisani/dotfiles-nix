---
name: axion-pr-workflow
description: Create Axion pull requests that are linked to AGP Jira tickets. Use this whenever the user asks to open an Axion PR, create a PR with a new Jira ticket, create a PR for an existing ticket, choose an AGP ticket for staged changes, or format an Axion PR description.
---

# Axion PR Workflow

Use this skill to create a GitHub pull request for the current repository and link it to an Axion Jira ticket in project `AGP`.

This skill replaces the older OpenCode-only `axion-pr-opener`, `axion-pr-new-ticket`, and `axion-pr-existing-ticket` workflows.

## Tools

- Use `git` for repository inspection and branch state.
- Use `gh` for GitHub pull request creation and updates.
- Use the `axion-jira` skill for Jira operations. It selects `axionray.atlassian.net`, then delegates command syntax to `acli-jira`.
- Do not use Jira MCP tools for this workflow, even if they are available.

Before any Jira read or write, apply the `axion-jira` skill's site-selection rule:

```sh
acli jira auth switch --site axionray.atlassian.net
```

Then apply the `acli-jira` skill's conventions:

- Use `--json` for Jira read commands.
- Use `--yes` for Jira mutation commands that support it.
- Prefer JQL searches for ticket discovery.
- Use `@me` / `currentUser()` for the authenticated user.

## Core rules

- Jira tickets for this workflow are always in project `AGP`.
- Only consider Jira tickets assigned to the current user unless the user explicitly gives a ticket key.
- Every PR must include a full Jira URL in the `Jira link` section.
- PR titles must use this format: `AGP-<ticket-number> - <short description>`.
- Do not assign reviewers, labels, or milestones.
- If you are unsure which existing ticket matches the branch or staged changes, ask the user to choose from a short list before creating the PR.
- If required Jira fields cannot be set with `acli jira`, report the exact blocker instead of silently skipping them.

## Initial inspection

Start by inspecting the local repository:

```sh
git status --short
git diff --staged --stat
git diff --staged
git branch --show-current
```

Use staged changes as the primary source for the PR summary. If there are no staged changes, inspect branch context and ask whether to proceed from unstaged or branch changes.

## Existing ticket workflow

Use this path when the user asks for a PR for an existing ticket, gives an `AGP-...` key, or asks you to find the matching ticket.

1. If the user gives a ticket key, view it:

   ```sh
   acli jira workitem view AGP-123 --json
   ```

2. If the user does not give a key, search for relevant tickets assigned to the current user:

   ```sh
   acli jira workitem search \
     --jql "project = AGP AND assignee = currentUser() AND sprint in openSprints() AND statusCategory != Done ORDER BY updated DESC" \
     --fields "key,summary,status,assignee,priority" \
     --limit 20 \
     --json
   ```

3. Compare ticket summaries to the branch name and staged changes. If more than one ticket is plausible, ask the user to select a ticket before proceeding.
4. Build the Jira URL from the returned URL if available. If the CLI output only gives a key, use `https://axionray.atlassian.net/browse/<KEY>`.
5. Create the PR using the template below.

## New ticket workflow

Use this path when the user asks to create a new ticket for the PR.

1. Infer a concise ticket summary and description from staged changes.
2. Create an `AGP` task assigned to the current user:

   ```sh
   acli jira workitem create \
     --project "AGP" \
     --type "Task" \
     --summary "<summary>" \
     --description "<one or two sentence description>" \
     --assignee "@me" \
     --json
   ```

3. Set or verify these ticket details:

   - Priority: `Medium`
   - Story Points: `3`
   - Sprint: current active sprint
   - Status: `In Review`

   Use `acli jira workitem edit`, `acli jira workitem transition`, board/sprint discovery commands, and `--from-json` / `additionalAttributes` when custom Jira fields are required. If you need board or field IDs, discover them with `acli jira board search`, `acli jira board list-sprints`, and generated JSON templates.

4. Confirm the final ticket key and URL, then create the PR using the template below.

## PR creation

Use `gh` to create the PR. Prefer a body file so the template is preserved exactly:

```sh
gh pr create --title "<AGP-key> - <short description>" --body-file /tmp/axion-pr-body.md
```

If the branch is not pushed, push it with an upstream before creating the PR:

```sh
git push -u origin HEAD
```

If `gh pr create` reports that a PR already exists for the branch, view it with `gh pr view --json url,title,body` and ask before updating title or body.

## PR body template

Fill only the `Change description` and `Jira link` sections unless the user provides QA steps or screenshots.

```markdown
**Change description:**
<concise summary of the purpose, impact, and noteworthy implementation details>
**Jira link:**
<full Jira URL>
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

## Final response

After creating the PR, provide a concise shareable message followed by the PR link:

```text
This PR <one sentence describing the key change and purpose>.
PR:
<PR_LINK>
```

Also mention the linked Jira ticket key.
