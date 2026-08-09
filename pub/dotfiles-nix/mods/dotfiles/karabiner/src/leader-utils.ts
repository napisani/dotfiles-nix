import { ToEvent, toSetVar } from "karabiner.ts";

export const systemLeader = "system_leader";

// Helper function to exit leader mode
export function exitLeader(): ToEvent[] {
  return [toSetVar(systemLeader, 0)];
}
