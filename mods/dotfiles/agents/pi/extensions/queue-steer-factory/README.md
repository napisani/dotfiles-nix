# Command-driven Pi queue

Local fork of [pi-queue-steer-factory](https://github.com/monotykamary/pi-queue-steer-factory), based on the published npm release `pi-queue-steer-factory@0.17.5`. The TypeScript implementation and `LICENSE` originate there; this copy keeps its visible timeline, dispatch, persistence and control-row handling, but uses slash commands instead of taking over Pi's input shortcuts.

| Command | Action |
| --- | --- |
| `/st <message>` | Add an editable steer row for the current run (or the next run while idle). |
| `/q <message>` | Add an editable follow-up row. |
| `/st-edit` | Select a pending steer row to edit. |
| `/q-edit` | Select a pending follow-up row to edit. |
| `/queue-run` | Resume the plan (and any paused head row); while idle, send its first row. |
| `/pause` | Gracefully pause after in-flight tools finish (from upstream). |
| `/queue-drain` | Combine pending message rows into one submission (from upstream). |

The editor picker appears when a lane has several rows. The selected row uses Pi's composer: Enter saves, Escape cancels, and saving empty text removes a text-only row. An unrelated composer draft is restored after the edit. Rows cannot be changed once they have been dispatched to Pi. The timeline shows both lanes in delivery order, including rows paused after a restart or an error.

While Pi is working, `/st` delivers at the next safe turn boundary and `/q` after the run. While idle, both commands *park* their rows for editing; use `/queue-run` to begin dispatch. Unprefixed submissions, including native Enter/Option+Enter and ordinary Pi slash commands, pass through to Pi unchanged. Native Pi pending messages are not part of this extension's editable timeline.

## Loading

The dotfiles Pi adapter links this directory to `~/.pi/agent/extensions/queue-steer-factory`. Pi discovers `index.ts` in the linked directory. The npm package must not load alongside this copy: run `pi remove npm:pi-queue-steer-factory@0.17.5` **before** activating the new Home Manager generation, then restart Pi. Until that activation, the existing npm install remains the active extension; editing these files alone does not install the fork.

## Verification

The local `index.test.ts` exercises native-input pass-through, lane ordering, editing and dispatch with a small extension host. Run `sh check.sh` for type checking and tests against Pi's installed packages. A Pi TUI smoke test should also confirm the actual editor integration before relying on queued work.
