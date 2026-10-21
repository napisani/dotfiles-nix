# Setting Up loancrate-review-filters-interview

For agents: get this skill working on a new machine. Come here when a script exits 5, or
when asked to install the skill. Check each item, do only what is missing, and ask the user
before changing anything outside the interviews folder.

## 1. Install the skill

This folder belongs at `~/.claude/skills/loancrate-review-filters-interview`, which is
where Claude Code looks for personal skills. If it was unzipped somewhere else, move it
there. It takes effect in the next session.

## 2. Tools

- **Required:** `git`, `node` + `npm` (Node ≥ 22; `golden/.nvmrc` has the starter's
  version), and `lsof` (stopping dev servers).
- **Required for screenshots and UI QA:** `playwright-cli` with a browser installed
  (`playwright-cli install-browser chromium`). Without it the product agent judges the UI
  from code and the brief has no screenshots.
- **As needed:** `pnpm`, `yarn` or `bun` when a candidate switched package managers
  (`collect.mjs` installs with whatever lockfile they committed).
- **Optional:** `sips` (macOS) to downscale embedded screenshots; without it they are
  embedded as captured.
- **Optional:** `gh`, signed in, to read a candidate's name from their GitHub profile.
  Without it, intake asks for `--name`.
- **Optional:** an editor CLI for opening each clone. The default is `code` (VS Code). To
  use another, set `editor_command` in `~/.claude/agent-skills.json`.
- **Optional:** calendar name lookup reads `~/.claude/skills/weekly-report/scripts/cal-events.py`.
  Most machines won't have it, and that's fine: it falls back to GitHub, then `--name`.

## 3. The interviews folder

Ask the user where to keep interview clones (suggest `~/interviews/filters`). Create it,
then clone the starter repo into it as `golden`:

```bash
git clone https://github.com/loancrate/filters-interview.git <folder>/golden
```

The repo is private to the loancrate org. If the clone is refused, the user needs access.
Candidate clones and `_reviews/` will land beside `golden/`. Pull `golden/` now and then so
the starter comparison stays current.

## 4. Point the scripts at it

The scripts find the folder in one of two ways:

- Claude Code is launched from the interviews folder (or from a candidate clone inside it).
- `FILTERS_INTERVIEWS` is set to the folder. To set it for every session, add it to the
  `env` block of `~/.claude/settings.json`. That file is the user's global config, so ask
  before editing it.

## 5. Publishing

Step 6 publishes the brief as a claude.ai Artifact, so Claude Code must be signed in to a
claude.ai account that can publish Artifacts. Briefs are private to the reviewer until
they share them.

## 6. Check it

```bash
node ~/.claude/skills/loancrate-review-filters-interview/scripts/intake.mjs https://github.com/loancrate/filters-interview --name "Setup Check" --dry-run
```

Run it from the interviews folder, or with `FILTERS_INTERVIEWS` set. It should print
`"ok": true` with `dir` inside the interviews folder. It doesn't clone anything. Exit 5
means steps 3–4 aren't done yet.
