---
name: axion-jira
description: Use when Jira work involves Axion Ray, Axion tickets, axionray.atlassian.net, Jira keys from Axion projects, or PR work that should reference Axion Jira work items.
---

# Axion Jira

## Purpose

Use this skill for Axion Ray Jira work. Axion uses Atlassian Cloud at:

```text
axionray.atlassian.net
```

This skill adds Axion-specific site selection on top of the generic `acli-jira` skill. For command syntax, read and follow `~/.agents/skills/acli-jira/SKILL.md`; do not duplicate that reference from memory.

## Core Rule

Before reading or changing Axion Jira data with `acli jira`, make the active Jira profile the Axion site:

```sh
acli jira auth switch --site axionray.atlassian.net
```

If that reports the user is not authenticated, ask the user to authenticate or run:

```sh
acli jira auth login --site axionray.atlassian.net --web
```

Do not append a site flag to normal `acli jira workitem`, `project`, `board`, or `sprint` commands. The CLI uses the active Jira auth profile for those commands.

## Workflow

1. Use this skill when the user mentions Axion Jira, Axion Ray Jira, `axionray.atlassian.net`, or an Axion Jira key.
2. Switch the active Jira site to `axionray.atlassian.net`.
3. Use `acli-jira` for the actual Jira operation.
4. Prefer `--json` for reads and `--yes` for non-interactive mutations, following `acli-jira`.
5. When creating PRs for Axion work, look for Jira keys in the branch name, commit messages, PR title, or user prompt, and include relevant Jira links in the PR body.

## PR Links

Use this URL form when referencing Axion Jira work items:

```text
https://axionray.atlassian.net/browse/KEY-123
```

If no Jira key is obvious, do not invent one. Either omit the Jira link or ask the user for the ticket key if the PR workflow clearly requires it.

## Quick Checks

```sh
# Show current Jira auth state
acli jira auth status

# Switch to Axion Jira
acli jira auth switch --site axionray.atlassian.net

# Verify project access after switching
acli jira project list --recent --json
```

## Common Mistakes

- Passing `https://axionray.atlassian.net/` where `acli` expects a site name. Use `axionray.atlassian.net` for `--site`.
- Adding `--site` to ordinary Jira workitem commands. Use `auth switch` first, then run normal `acli jira ...` commands.
- Treating Axion Jira as a generic browser-only workflow. Use `acli` first unless the user explicitly asks for a web URL.
- Guessing ticket keys. Search Jira or ask the user when the key is not present in branch, commits, prompt, or PR metadata.
