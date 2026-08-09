# PromptBuilder Skill Picker And Completion Design

## Goal

Add skill insertion affordances for PromptBuilder:

- typing `/` inside PromptBuilder opens a `blink.cmp` menu of skills and accepting an item inserts `/skill-name`
- pressing `<leader>as` opens a Snacks picker over the same skill list and appends `/skill-name` to PromptBuilder

## Scope

The blink source is enabled only for PromptBuilder buffers, identified by `b:prompt_builder`. It must not affect normal markdown buffers or other completion contexts. The `<leader>as` picker is a normal-mode staging action under `Wiremux + PromptBuilder`.

Skill discovery is limited to:

- `~/.agents/skills`
- the current working repo's `.agents/skills`

Agent-specific directories such as `~/.codex/skills`, `~/.claude/skills`, and similar paths are intentionally excluded.

## Approach

Create `lua/user/snacks/ai_skills.lua` as the shared source of truth for AI skill discovery. It scans skill directories for `SKILL.md`, reads frontmatter `name` and `description` when present, and returns sorted `{ name, description, path }` entries. The repo-local skill root is resolved from the current working directory by walking upward to `.git` or `flake.nix`.

The blink source calls `user.snacks.ai_skills.list()` and uses `/` as its trigger character. Each item shows the skill name and optional description, but the accepted text is always the literal slash invocation, for example `/context7`.

The `<leader>as` mapping calls `user.snacks.ai_skills.pick_to_prompt_builder()`. The picker displays the same skill list, and confirming a skill appends `/skill-name` to PromptBuilder, opening/focusing it through the existing PromptBuilder append flow.

## Testing

Validate that the shared module loads and returns the expected roots, that the blink source returns items in a synthetic PromptBuilder-marked buffer and stays disabled outside PromptBuilder, that the Wiremux keymap registry includes `<leader>as`, and that the full Neovim config loads headlessly.
