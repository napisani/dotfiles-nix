# `ai-usage` design

## Goal

Provide an interactive-shell function, `ai-usage`, that renders one terminal report combining the usage information available to the locally authenticated Codex and Claude Code CLIs.

## Scope

The function lives in `mods/dotfiles/.bashrc.d/0110_alias_and_func.bashrc`. It uses each CLI's supported local reporting interface; it does not call web backends directly, inspect credential stores, or persist credentials or report data.

## Behavior

- Query Codex and Claude Code independently, using the existing CLI login for each.
- Print one labeled section per provider, retaining native usage-window and reset details when supplied.
- If a CLI is not installed, not logged in, or cannot provide a report, print a concise provider-specific diagnostic and continue to the other provider.
- Return success when at least one provider report is obtained; return nonzero only when neither report is available.
- Do not print or store tokens, cookies, or other credentials.

## Implementation shape

`ai-usage()` will coordinate two small provider-specific command invocations, capture their output, and render the combined report. Provider discovery and parsing stay isolated so a failure or output change from one CLI cannot prevent the other section from displaying. The implementation will prefer documented/native CLI facilities over HTTP calls or browser automation.

## Verification

- Source the Bash fragment in a clean Bash process and verify `ai-usage` is defined.
- Run the function with both CLIs available and confirm labeled combined output.
- Exercise an unavailable CLI path (for example by temporarily constraining `PATH`) and confirm the remaining provider still reports and the function exits successfully.
- Confirm neither-provider-available exits nonzero.
