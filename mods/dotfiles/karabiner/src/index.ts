import {
    map,
    writeToProfile,
    rule
} from 'karabiner.ts'
import { writeContext } from './output'
import { modifierSwapRules } from './modifierSwap'
// import { backslashRules } from './backslash'
import { layerRules } from './layers'
import { homeRowRules } from './home-row'
import { capsRules } from './caps-lock'
import { tabRules } from './tab';

writeToProfile({
  name: 'default', 
  dryRun: false, 
  karabinerJsonPath: writeContext.karabinerConfigFile(),
}, [
  ...capsRules,
  ...modifierSwapRules,
  // ...backslashRules,
  ...layerRules,
 ...homeRowRules,
  ...tabRules,

  rule('escape -> grave_accent_and_tilde').manipulators([
    map("escape").to("grave_accent_and_tilde")
    .description("escape -> grave_accent_and_tilde"), 
  ]),

])


