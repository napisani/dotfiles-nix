import "../polyfill.ts";
import { map, rule, writeToProfile } from "karabiner.ts";
import { modifierSwapRules } from "./modifierSwap.ts";
import { layerRules } from "./layers.ts";
import { capsRules } from "./hyper.ts";
import { systemLeaderRules } from "./system-leader.ts";
import { join } from "@std/path";
import { windowLeaderRules } from "./window-leader.ts";

const karabinerJsonPath = join(
  Deno.env.get("HOME") || "",
  ".config/home-manager/mods/dotfiles/karabiner.json",
);

writeToProfile({
  name: "default",
  dryRun: false,
  karabinerJsonPath,
}, [
  ...capsRules,
  ...modifierSwapRules,
  ...layerRules,
  ...systemLeaderRules,
  ...windowLeaderRules,

  rule("escape -> grave_accent_and_tilde").manipulators([
    map("escape").to("grave_accent_and_tilde")
      .description("escape -> grave_accent_and_tilde"),
  ]),
]);
