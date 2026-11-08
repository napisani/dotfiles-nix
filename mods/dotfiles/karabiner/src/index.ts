import "../polyfill.ts";
import { map, rule, writeToProfile } from "karabiner.ts";
import { modifierSwapRules } from "./modifier-swap.ts";
import { layerRules } from "./layers.ts";
import { capsRules } from "./cap-modifier.ts";
import { fromFileUrl, join } from "@std/path";
import { tabWindowManagerRules } from "./window-layer.ts";
import { windowManagerLookSource } from "./window-action-catalog.ts";

const dotfilesSource = fromFileUrl(new URL("../../", import.meta.url));
const karabinerJsonPath = join(dotfilesSource, "karabiner.json");
const lookSourceDir = join(dotfilesSource, "look-sources");
const lookSourcePath = join(lookSourceDir, "window-management.toml");
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

await Deno.mkdir(lookSourceDir, { recursive: true });
await Deno.writeTextFile(lookSourcePath, windowManagerLookSource());
console.log(`Wrote Look window-management source to ${lookSourcePath}`);
