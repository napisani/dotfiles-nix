# PromptBuilder Parent Path File Ref Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `<leader>afp` to stage a selected parent-directory file reference in PromptBuilder.

**Architecture:** Reuse `user.snacks.find_files.find_path_files()` for picker behavior and `user.snacks.ai_context_files` for converting selected files into PromptBuilder references.

**Tech Stack:** Neovim Lua, Snacks picker, PromptBuilder.

---

### Task 1: Shared Selection Helper

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/snacks/ai_context_files.lua`

**Steps:**

1. Add `append_file_selection_to_chat(selection)` that runs existing selection coercion and `to_reference_item()` conversion.
2. Change `add_file_to_chat()` to call the new helper from its custom confirm action.
3. Add `add_parent_path_file_to_chat()` that calls `user.snacks.find_files.find_path_files({ confirm = ... })`.

### Task 2: Keymap And Behavior Docs

**Files:**
- Modify: `mods/dotfiles/nvim/lua/user/plugins/ai/wiremux.lua`
- Modify: `mods/dotfiles/nvim/BEHAVIOR.md`

**Steps:**

1. Add normal-mode `<leader>afp` under the `af` group.
2. Wire it to `require("user.snacks.ai_context_files").add_parent_path_file_to_chat()`.
3. Document that `<leader>afp` uses the parent path picker and appends an `@` file reference to PromptBuilder.

### Task 3: Verification

**Commands:**

```bash
nvim --headless -c "lua local m=require('user.snacks.ai_context_files'); assert(type(m.append_file_selection_to_chat)=='function'); assert(type(m.add_parent_path_file_to_chat)=='function')" -c "qa"
```

```bash
nvim --headless -c "lua local maps=require('user.plugins.ai.wiremux').get_keymaps().normal; local found=false; for _, map in ipairs(maps) do if map[1] == '<leader>afp' then found = type(map[2]) == 'function' end end; assert(found, 'expected <leader>afp')" -c "qa"
```

```bash
nvim --headless -c "checkhealth" -c "qa"
```
