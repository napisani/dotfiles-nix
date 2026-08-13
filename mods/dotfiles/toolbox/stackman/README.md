# Stackman

Stackman is a **branch-first** tool for managing stacked Git branches. It tracks parent-child relationships between branches and keeps them in sync with a single `stackman sync` command.

## Features

- **Stacked branches**: Track multiple feature branches that depend on each other
- **One-command sync**: `stackman sync` rebases your entire stack onto the latest parent
- **Automatic conflict resolution**: Use AI models (Claude, GPT-4, etc.) to resolve conflicts unattended
- **Non-destructive**: Never creates, deletes, or renames branches—only tracks relationships
- **Works anywhere**: Works from any worktree; same database for all worktrees of a repo

## Installation

```bash
# Via home-manager (if using this dotfiles setup)
# See mods/agents/skills.nix
```

## Quick Start

```bash
# Track a feature branch onto main
stackman track feature --parent main

# Track another branch onto the first
stackman track feature-2 --parent feature

# List the stack
stackman list

# Sync the entire stack
stackman sync

# Mark a branch as done (lift children to its parent)
stackman done feature

# Stop tracking a branch
stackman forget feature
```

## Conflict Resolution

When `stackman sync` encounters a rebase conflict, it can resolve it automatically using an AI model.

### Simplest Setup: Claude

```bash
export STACKMAN_RESOLVER="claude -p @prompt"
stackman sync feature
```

That's it. The `@prompt` token is automatically expanded to stackman's battle-tested conflict resolution prompt with your branch context (names, conflicted files, etc.) already filled in.

### What is `@prompt`?

Stackman provides a **default conflict resolution prompt** that:
- Inlines conflict resolution methodology (understand intent, merge intentionally, validate syntax)
- Includes safety guardrails (defaults to aborting when uncertain)
- Templates all context (branch name, parent, conflicted files, etc.)
- Provides clear exit criteria (success vs. failure)

Use `@prompt` to inject this prompt into any resolver command:

```bash
# Claude
--resolver "claude -p @prompt"

# OpenAI
--resolver "gpt-4 --prompt @prompt"

# Custom script
--resolver "~/.local/bin/my-resolver @prompt"
```

### View the Prompt

```bash
# See the prompt with your context filled in
stackman show-resolver-prompt

# See the template structure
stackman show-resolver-prompt --template
```

### Extend for Your Codebase

Add project-specific conflict resolution guidelines:

```bash
PROMPT="$(stackman show-resolver-prompt)"
PROMPT="${PROMPT}

## Our Code Standards
- Always preserve TypeScript types
- React hooks first, no class components
- If unsure, check recent commits"

stackman sync --resolver "claude -p \"$PROMPT\""
```

### Other AI Models

**OpenAI:**
```bash
stackman sync --resolver "curl -s https://api.openai.com/v1/chat/completions \
  -H 'Authorization: Bearer \$OPENAI_API_KEY' \
  -H 'Content-Type: application/json' \
  -d '{\"model\": \"gpt-4\", \"messages\": [{\"role\": \"user\", \"content\": \"@prompt\"}]}' | \
  jq -r '.choices[0].message.content'"
```

**Custom resolver script:**
```bash
chmod +x ~/.local/bin/my-resolver
stackman sync --resolver "~/.local/bin/my-resolver"
```

See [resolver-examples.md](docs/resolver-examples.md) for ready-to-use scripts.

## How It Works

### Tracking Branches

Stackman stores parent/fork-point metadata in a SQLite database (`~/.local/share/stackman/stackman.db`). It never modifies Git directly—only reads branch names and commit SHAs.

```bash
stackman track feature --parent main
# Records: feature has parent main, fork-point at main's current tip
```

### Syncing

When you run `stackman sync`, stackman:

1. **Resolves the stack** — finds all branches that depend on the current branch
2. **Rebases in order** — rebases each branch onto the latest tip of its parent
3. **Handles conflicts** — if a conflict occurs, either prompts you interactively or invokes your resolver
4. **Pushes** — force-pushes with lease (safe if no one else pushed)

### Fork Points

The **fork-point** is the commit where your branch diverged from its parent. Stackman records this when you track a branch:

```bash
stackman track feature --parent main
# fork-point = main's tip at that moment
```

When syncing, stackman rebases your commits (everything after the fork-point) onto the parent's latest tip.

## Interactive Conflict Resolution

If you don't configure a resolver, `stackman sync` will prompt you interactively:

```
[stackman] Resolve conflicts, run `git rebase --continue` or `git rebase --abort`, then press Enter to resume.
```

You can then manually resolve, run `git rebase --continue`, and press Enter.

## Commands

### Core Commands

- **`stackman track BRANCH --parent PARENT`** — Track a new branch
- **`stackman chain ANCHOR BRANCH...`** — Track an existing linear stack
- **`stackman sync [BRANCH]`** — Sync the stack containing BRANCH (default: current)
- **`stackman done BRANCH`** — Mark branch as done, reparent its children
- **`stackman forget BRANCH`** — Stop tracking a branch

### Inspection

- **`stackman list`** — Show tracked branches as a tree
- **`stackman status [BRANCH]`** — Show tracking status for a branch
- **`stackman discover PR_NUMBER`** — Auto-discover a stack from GitHub PRs

### Utilities

- **`stackman show-resolver-prompt`** — Display the default conflict resolution prompt
- **`stackman show-resolver-prompt --template`** — Show the prompt template with placeholders

## Options

### Sync Options

- **`--dry-run`** — Show what would happen without modifying the repo
- **`--verbose`** — Print the exact git rebase commands
- **`--squash`** — Squash 2+ commits after fork-point into one before rebasing
- **`--allow-dirty`** — Skip the preflight dirty-worktree check
- **`--resolver CMD`** — Use CMD for non-interactive conflict resolution (overrides `STACKMAN_RESOLVER`)
- **`--no-wait`** — Force non-interactive mode (don't wait for TTY input)

### Global Options

- **`--db-path PATH`** — Use a different database (default: `~/.local/share/stackman/stackman.db`)
- **`--repo PATH`** — Work with a specific repository (default: current directory)
- **`--version`** — Show version

## Environment Variables

### Conflict Resolution

- **`STACKMAN_RESOLVER`** — Default resolver command (can be overridden with `--resolver`)

### Resolver Context (set by stackman)

When your resolver is invoked, these variables are available:

- `STACKMAN_BRANCH` — Branch being rebased
- `STACKMAN_PARENT` — Parent branch name
- `STACKMAN_PARENT_TIP` — SHA of parent's tip
- `STACKMAN_FORK_POINT` — SHA where branch forked from parent
- `STACKMAN_CONFLICTED_FILES` — Newline-separated list of conflicted files
- `STACKMAN_OPERATION` — Always `"rebase"`
- `STACKMAN_REPO_URL` — Origin URL (if configured)
- `STACKMAN_PARENT_PR_NUMBER` — GitHub PR number (if available)
- `STACKMAN_PR_NUMBER` — GitHub PR number (if available)

## Examples

### Basic Stack

```bash
# Create a stack: main -> feature -> feature-2
stackman track feature --parent main
stackman track feature-2 --parent feature

# List the stack
stackman list
# Output:
# main
#  └─ feature
#      └─ feature-2

# Sync everything
stackman sync
```

### With Conflict Resolution

```bash
# Set Claude as your resolver
export STACKMAN_RESOLVER="claude -p @prompt"

# Sync; conflicts are resolved automatically
stackman sync feature

# Or use a different resolver for one sync
stackman sync feature --resolver "gpt-4-turbo --prompt @prompt"
```

### Dry Run Before Committing

```bash
# See what stackman would do
stackman sync --dry-run

# If it looks good, actually do it
stackman sync
```

### Mark a Branch as Done

```bash
stackman list
# main
#  └─ feature
#      └─ feature-2

stackman done feature
# Reparents feature-2 onto main

stackman list
# main
#  ├─ feature-2
#  └─ feature (still tracked, but orphaned)
```

## Documentation

- **[Conflict Resolution Guide](docs/conflict-resolution-guide.md)** — Detailed guide to setting up automatic conflict resolution
- **[Resolver Examples](docs/resolver-examples.md)** — Ready-to-use scripts for Claude, OpenAI, and custom resolvers
- **[Design](docs/design.md)** — Architectural overview

## FAQ

**Q: Does stackman delete or rename branches?**  
A: No. Stackman only tracks relationships in its database. Git branches are never modified.

**Q: What if I push a branch manually between syncs?**  
A: Stackman's fork-point doesn't change. The next sync will rebase onto the parent's current tip and use `--force-with-lease` to push safely.

**Q: Can I use stackman with multiple worktrees?**  
A: Yes. All worktrees of a repo share the same database, so you can sync from any worktree.

**Q: What if my resolver fails?**  
A: The rebase is aborted and `stackman sync` exits with a non-zero code. You can then manually resolve and retry.

**Q: How do I stop using stackman?**  
A: Just run `stackman forget --all` to drop all tracking. Your Git branches are unaffected.

## Contributing

See [AGENTS.md](./AGENTS.md) for development guidelines.

## License

See the monorepo's LICENSE file.
