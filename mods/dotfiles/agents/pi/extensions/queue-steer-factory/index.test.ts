import { expect, test } from "bun:test";
import queueSteerExtension from "./index.ts";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { QueueSnapshot } from "./queue-persistence.ts";

function harness(idle = true) {
  const commands = new Map<string, (args: string, ctx: ExtensionContext) => Promise<void>>();
  const events = new Map<string, (event: any, ctx: ExtensionContext) => any>();
  const snapshots: QueueSnapshot[] = [];
  const sends: { message: unknown; options: unknown }[] = [];
  const notifications: string[] = [];
  const widgets: unknown[] = [];
  let draft = "original composer";
  let pick = 0;
  const pi = {
    registerCommand: (name: string, spec: { handler: (args: string, ctx: ExtensionContext) => Promise<void> }) => commands.set(name, spec.handler),
    on: (name: string, handler: (event: any, ctx: ExtensionContext) => any) => events.set(name, handler),
    events: { on: () => () => {}, emit: () => {} },
    appendEntry: (_type: string, data: QueueSnapshot) => snapshots.push(data),
    sendUserMessage: (message: unknown, options?: unknown) => sends.push({ message, options }),
    getCommands: () => [],
  } as unknown as ExtensionAPI;
  const ctx = {
    mode: "tui", isIdle: () => idle,
    ui: {
      notify: (message: string) => notifications.push(message),
      setWidget: (_name: string, widget: unknown) => widgets.push(widget),
      getEditorText: () => draft,
      setEditorText: (text: string) => { draft = text; },
      select: async (_title: string, choices: string[]) => choices[pick],
    },
  } as unknown as ExtensionContext;
  queueSteerExtension(pi);
  return {
    commands, events, snapshots, sends, notifications, widgets, ctx,
    setIdle: (value: boolean) => { idle = value; },
    setPick: (value: number) => { pick = value; },
    draft: () => draft,
    latest: () => snapshots.at(-1)!,
    run: (name: string, args = "") => commands.get(name)!(args, ctx),
  };
}

test("unprefixed interactive submissions remain Pi-owned even with a visible queue", async () => {
  const app = harness(false);
  await app.run("q", "pending");
  expect(app.events.get("input")!({ source: "interactive", text: "plain", streamingBehavior: "steer" }, app.ctx)).toEqual({ action: "continue" });
  expect(app.events.get("input")!({ source: "interactive", text: "plain", streamingBehavior: "followUp" }, app.ctx)).toEqual({ action: "continue" });
  expect(app.latest().rows.map((row) => row.text)).toEqual(["pending"]);
  expect(app.sends).toHaveLength(0);
});

test("commands add visible, persistent rows in both lanes and idle rows wait for /queue-run", async () => {
  const app = harness();
  await app.run("q", "first queued run");
  await app.run("st", "steer next run");
  expect(app.latest().rows.map(({ lane, text }) => [lane, text])).toEqual([
    ["steer", "steer next run"], ["followUp", "first queued run"],
  ]);
  expect(app.latest().paused).toBe(true);
  expect(app.widgets.at(-1)).toBeFunction();
  expect(app.sends).toHaveLength(0);
  await app.run("queue-run");
  expect(app.sends).toEqual([{ message: "steer next run", options: undefined }]);
  expect(app.latest().rows.map((row) => row.text)).toEqual(["first queued run"]);
});

test("lane-specific editor selects a row, saves it without sending, and restores composer", async () => {
  const app = harness();
  await app.run("st", "steer row");
  await app.run("q", "first follow-up");
  await app.run("q", "second follow-up");
  app.setPick(1);
  await app.run("q-edit");
  expect(app.draft()).toBe("second follow-up");
  expect(app.events.get("input")!({ source: "interactive", text: "edited follow-up", images: [] }, app.ctx)).toEqual({ action: "handled" });
  expect(app.draft()).toBe("original composer");
  expect(app.latest().rows.map((row) => row.text)).toEqual(["steer row", "first follow-up", "edited follow-up"]);
  expect(app.sends).toHaveLength(0);
  await app.run("st-edit");
  expect(app.draft()).toBe("steer row");
  app.events.get("input")!({ source: "interactive", text: "", images: [] }, app.ctx);
  expect(app.latest().rows.map((row) => row.lane)).toEqual(["followUp", "followUp"]);
});

test("a busy steer joins the current run and follow-ups wait behind it", async () => {
  const app = harness(false);
  await app.run("q", "after run");
  await app.run("st", "while working");
  expect(app.latest().rows.map((row) => row.text)).toEqual(["while working", "after run"]);
  await app.events.get("turn_end")!({ message: { role: "assistant", stopReason: "stop" } }, app.ctx);
  expect(app.sends).toEqual([{ message: "while working", options: { deliverAs: "steer" } }]);
  expect(app.latest().rows.map((row) => row.text)).toEqual(["after run"]);
});
