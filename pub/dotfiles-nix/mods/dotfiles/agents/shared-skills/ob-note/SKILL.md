---
name: ob-note
description: Use when the user explicitly asks to store, create, organize, read from obsidian notes or obsidian vault. 
---

# Ob Note

Use this skill to safely read, create, update, and organize notes in Nick's Obsidian vault.

The vault is folder-organized. Preserve that organization instead of flattening notes.

## First Steps

1. Locate the vault.
2. Search for an existing note before creating a new one.
3. Choose the correct folder from the taxonomy below.
4. Make the smallest useful change.
5. Preserve existing frontmatter, wikilinks, headings, checkboxes, and completed tasks.

## Vault Location

Nick's Obsidian vault is always at:

```text
~/code/obsidian
```

Use this path for all searches, creates, edits, and moves unless the user explicitly provides a different vault path for a specific request.

Useful commands:

```sh
VAULT="$HOME/code/obsidian"
rg --files "$VAULT" -g '*.md'
```

Use `rg` for content search and `rg --files` for filename discovery.

## Folder Taxonomy

```text
Work/People/{Colleagues,Interviews,1-on-1s}/
Work/{Projects,Meetings,Documentation,Career,Incidents,Ideas}/
Home/{Todos,Projects,Notes,Learning}/
Development/{Learning,Active-Projects,Project-Ideas,Tools}/
Cars/{MR2,Volvo,General}/
Daily/
Archive/
Attachments/
```

Use `Development/Project-Ideas/` for future coding project ideas.

## Categorization Rules

### Work

- `Work/People/Colleagues/`: individual colleague and team member notes.
- `Work/People/Interviews/`: candidate interview notes.
- `Work/People/1-on-1s/`: manager, report, and recurring 1-on-1 notes.
- `Work/Projects/`: work projects, client work, Dagster, landscapes, metrics, and work coding projects.
- `Work/Meetings/`: sprints, retros, standups, planning, reviews, and team meetings.
- `Work/Documentation/`: standards, procedures, how-tos, runbooks, and technical docs.
- `Work/Career/`: reviews, career ladder, promotion, and performance notes.
- `Work/Incidents/`: outages, postmortems, investigations, and incident logs.
- `Work/Ideas/`: work improvement proposals and product/process ideas.

Critical rule: work coding projects go in `Work/Projects/`, not `Development/`.

### Home

- `Home/Todos/`: personal task lists, shopping, gifts, wishlists, and files with `todo`, `task`, `wishlist`, or `gift` in the name.
- `Home/Projects/`: personal non-coding projects, 3D printing, keyboards, and home improvement.
- `Home/Notes/`: general personal notes and saved articles.
- `Home/Learning/`: non-programming learning.

### Development

- `Development/Learning/`: programming languages, frameworks, and technical learning.
- `Development/Active-Projects/`: personal coding projects in progress.
- `Development/Project-Ideas/`: future coding project ideas, plugin concepts, experiments.
- `Development/Tools/`: CLI tools, editor configuration, dev tooling, and workflow notes.

### Cars

- `Cars/MR2/`: Toyota MR2-specific notes.
- `Cars/Volvo/`: Volvo-specific notes.
- `Cars/General/`: universal automotive knowledge.

### Common Folders

- `Daily/`: daily notes, logs, capture notes, and journal-style entries.
- `Archive/`: old notes that should be retained but not kept active.
- `Attachments/`: non-markdown files. Do not edit binary attachments.

## Note Creation

Before creating a note:

```sh
rg --files "$VAULT" -g '*.md' | rg -i '<topic words>'
rg -n '<topic words>' "$VAULT" -g '*.md'
```

If an existing note clearly matches, update it instead of creating a duplicate.

For new notes:

- Use a clear human title in Title Case unless the vault already uses a different naming style nearby.
- Store the note in the most specific folder from the taxonomy.
- Prefer normal markdown headings over heavy frontmatter.
- Add Obsidian wikilinks with `[[Note Title]]` when a related note already exists.
- Put related links near the bottom under `## Related` when they are not part of the main prose.

## Updating Notes

When the user asks to store a fact or add information:

1. Search for the target note by filename and content.
2. Append to the most relevant heading if one exists.
3. Create a heading only when it makes future scanning easier.
4. Preserve existing wording unless the user asks for cleanup.
5. Keep the change local to the requested topic.

When adding a dated item, prefer an ISO date prefix or a `YYYY-MM-DD` heading if nearby notes use dates.

## Todo Formatting

Todo-like notes should use markdown task checkboxes:

```markdown
- [ ] unfinished item
- [x] completed item
```

Todo-like files are detected by filenames containing `todo`, `task`, `wishlist`, or `gift`.

Rules:

- In todo-like files, convert short plain lines and simple bullets into `- [ ]`.
- In non-todo files, convert only explicit bullets that are clearly task items.
- Preserve `- [x]` and `- [X]`.
- Do not convert headings, long prose, tables, blockquotes, or code blocks.

Use the bundled formatter when doing mechanical cleanup. It reads markdown from stdin and writes formatted markdown to stdout:

```sh
python3 ~/.agents/skills/ob-note/scripts/format_note.py path/to/note.md < path/to/note.md
```

To apply formatting to a file, write stdout to a temporary file first, inspect the diff, then replace the note only if the change is correct.

## Markdown Cleanup

Use conservative cleanup:

- Add a space after heading markers: `#Heading` -> `# Heading`.
- Collapse excessive blank lines.
- Keep lists consistent.
- Fix common typos only outside code blocks.
- Never correct names, part numbers, company jargon, or code.

Common safe typo fixes:

- `types cript` -> `TypeScript`
- `kubernetes` -> `Kubernetes`
- `doesnt` -> `doesn't`
- `cant` -> `can't`
- `im` -> `I'm`

## Organization and Moves

When organizing existing notes:

1. Classify each file by content, not just filename.
2. Move to the most specific folder.
3. Preserve backlinks by keeping filenames stable unless the user asks to rename notes.
4. Avoid bulk moves over 10 files without summarizing the plan first.
5. Do not delete notes. Move obsolete notes to `Archive/` only when asked.

## Safety Rules

- Do not edit the vault until the target path is identified.
- Do not overwrite an existing note with unrelated content.
- Do not edit `Attachments/` except to move files when explicitly asked.
- Do not modify generated sync metadata, hidden plugin state, or `.obsidian/` unless asked.
- For ambiguous categorization, choose the least surprising folder and mention the assumption.
