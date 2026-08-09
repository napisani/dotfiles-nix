# PromptBuilder Parent Path File Ref Design

## Goal

Add `<leader>afp` as a PromptBuilder staging action that opens the same parent-directory file picker as `<leader>fp`, then appends an `@` file reference for the selected file to PromptBuilder.

## Scope

`<leader>afp` is normal-mode only under the existing `af` file-reference group. It should not open the selected file in an edit buffer. Directories should continue navigating inside the picker, matching `<leader>fp`.

## Approach

Reuse `user.snacks.find_files.find_path_files()` so the picker starts from the current buffer file's directory and preserves the same directory-recursion behavior as `<leader>fp`.

Add a small reusable helper in `user.snacks.ai_context_files` that converts a Snacks picker selection into PromptBuilder reference items. The existing `add_file_to_chat()` picker adapter and the new parent-path picker both call that helper, so reference formatting stays shared.

## Behavior

When the user presses `<leader>afp`, the parent path picker opens. Selecting a file appends an `@relative/path` reference to PromptBuilder and opens/focuses the PromptBuilder split through the existing append flow.
