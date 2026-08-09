# PromptBuilder Skill Picker And Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add shared AI skill discovery for PromptBuilder slash completions and a `<leader>as` Snacks picker.

**Architecture:** `user.snacks.ai_skills` owns skill discovery, parsing, caching, and picker behavior. The blink source delegates to that shared module for its completion items. Wiremux registers `<leader>as` as a PromptBuilder staging action.

**Tech Stack:** Neovim Lua, `blink.cmp`, local dotfiles skill directories.

---

### Task 1: Shared Skill Module

**Files:**
- Create: `mods/dotfiles/nvim/lua/user/snacks/ai_skills.lua`
- Modify: `mods/dotfiles/nvim/lua/user/completion/sources/skills.lua`

**Steps:**

1. Move skill root discovery, `SKILL.md` parsing, sorting, and caching into `user.snacks.ai_skills`.
2. Expose `list(opts)`, `default_skill_dirs()`, `is_prompt_builder(bufnr)`, `skill_invocation(skill)`, and `pick_to_prompt_builder(opts)`.
3. Refactor `user.completion.sources.skills` to call `ai_skills.list()` and `ai_skills.is_prompt_builder()`.
4. Keep accepted completion text as `/skill-name`.

### Task 2: Picker Keymap

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/plugins/ai/wiremux.lua`
- Modify: `mods/dotfiles/nvim/BEHAVIOR.md`

**Steps:**

1. Add normal-mode `<leader>as` under `Wiremux + PromptBuilder`.
2. Have it call `require("user.snacks.ai_skills").pick_to_prompt_builder()`.
3. Document that `<leader>as` picks a skill and appends `/skill-name` to PromptBuilder.

### Task 3: Verification

**Commands:**

```bash
nvim --headless -c "lua local skills=require('user.snacks.ai_skills'); assert(#skills.default_skill_dirs()==2); assert(#skills.list({cache_ttl_ms=0}) > 0)" -c "qa"
```

```bash
nvim --headless -c "lua local s=require('user.completion.sources.skills').new({}); local b=vim.api.nvim_create_buf(false,true); vim.api.nvim_set_current_buf(b); vim.api.nvim_buf_set_lines(b,0,-1,false,{'/con'}); vim.api.nvim_win_set_cursor(0,{1,4}); vim.api.nvim_buf_set_var(b,'prompt_builder',true); s:get_completions({bufnr=b,cursor={1,4},line='/con'}, function(r) assert(#r.items > 0, 'expected skills') end)" -c "qa"
```

```bash
nvim --headless -c "checkhealth" -c "qa"
```
