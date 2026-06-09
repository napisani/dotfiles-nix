import type { Plugin } from "@opencode-ai/plugin"

/**
 * OpenCode plugin that sets a tmux session-level user option (@opencode_state)
 * to "thinking" while the agent is busy and "complete" when idle.
 *
 * Legacy OpenCode-only status channel. The session picker now reads Workmux's
 * @workmux_status value instead.
 */
export const TmuxStatusPlugin: Plugin = async ({ $ }) => {
  const inTmux = !!process.env.TMUX

  async function setTmuxState(state: "thinking" | "complete") {
    if (!inTmux) return
    try {
      await $`tmux set-option @opencode_state ${state}`
    } catch {
      // tmux command failed — not fatal
    }
  }

  // Mark complete on startup so the picker shows a baseline state
  await setTmuxState("complete")

  return {
    event: async ({ event }) => {
      if (event.type === "session.status") {
        const status = event.properties.status.type
        if (status === "busy") {
          await setTmuxState("thinking")
        } else if (status === "idle") {
          await setTmuxState("complete")
        }
        // "retry" keeps the current state (still thinking)
      }
    },
  }
}
