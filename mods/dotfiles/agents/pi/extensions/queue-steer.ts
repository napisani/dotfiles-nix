/**
 * /st and /q: steer the running agent or queue a follow-up using Pi's native
 * steering and follow-up queues.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  function register(name: string, deliverAs: "steer" | "followUp", description: string) {
    pi.registerCommand(name, {
      description,
      handler: async (args, ctx) => {
        const message = args.trim();
        if (!message) {
          ctx.ui.notify(`Usage: /${name} <message>`, "warning");
          return;
        }
        // deliverAs only applies while streaming; when idle Pi starts a turn immediately.
        pi.sendUserMessage(message, { deliverAs });
      },
    });
  }

  register("st", "steer", "Steer the current run at the next turn boundary");
  register("q", "followUp", "Queue a follow-up message for after the current run");
}
