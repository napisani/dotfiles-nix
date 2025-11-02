import "../polyfill.ts";
import { map, rule, writeToProfile } from "karabiner.ts";
import { modifierSwapRules } from "./modifierSwap.ts";
import { layerRules } from "./layers.ts";
import { capsRules } from "./cap-modifier.ts";
import { join } from "@std/path";
import { tabWindowManagerRules } from "./window-layer.ts";

const karabinerJsonPath = join(
  Deno.env.get("HOME") || "",
  ".config/home-manager/mods/dotfiles/karabiner.json",
);
console.log("Writing to Karabiner profile at:", karabinerJsonPath);

writeToProfile({
  name: "default",
  dryRun: false,
  karabinerJsonPath,
}, [
  ...capsRules,
  ...modifierSwapRules,
  ...layerRules,
  // ...systemLeaderRules,
  // ...windowLeaderRules,
  ...tabWindowManagerRules,

  rule("escape -> grave_accent_and_tilde").manipulators([
    map("escape").to("grave_accent_and_tilde")
      .description("escape -> grave_accent_and_tilde"),
  ]),
]);
