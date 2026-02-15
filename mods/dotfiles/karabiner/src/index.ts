import "../polyfill.ts";
import { map, rule, writeToProfile } from "karabiner.ts";
import { modifierSwapRules } from "./modifier-swap.ts";
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
  ...tabWindowManagerRules,

  rule("escape -> grave_accent_and_tilde").manipulators([
    map("escape").to("grave_accent_and_tilde")
      .description("escape -> grave_accent_and_tilde"),
  ]),
]);

// create symlink to karabiner.json in ~/.config/karabiner/karabiner.json
const karabinerConfigPath = join(
  Deno.env.get("HOME") || "",
  ".config/karabiner/karabiner.json",
);

try {
  await Deno.remove(karabinerConfigPath);
} catch {
  // ignore
}
await Deno.symlink(karabinerJsonPath, karabinerConfigPath);
console.log(
  `Created symlink from ${karabinerConfigPath} to ${karabinerJsonPath}`,
);
