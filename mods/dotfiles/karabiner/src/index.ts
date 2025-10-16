import {
    map,
    rule,
    writeToProfile,
} from 'karabiner.ts'
import { writeContext } from './output'
import { modifierSwapRules } from './modifierSwap'
import { layerRules } from './layers'
import { capsRules } from './hyper.ts'
import { tabRules } from './system-leader.ts';

writeToProfile({
  name: 'default', 
  dryRun: false, 
  karabinerJsonPath: writeContext.karabinerConfigFile(),
}, [
  ...capsRules,
  ...modifierSwapRules,
  ...layerRules,
  ...tabRules,

  rule('escape -> grave_accent_and_tilde').manipulators([
    map("escape").to("grave_accent_and_tilde")
    .description("escape -> grave_accent_and_tilde"), 
  ]),

])


