import {
    map,
    writeToProfile,
    rule
} from 'karabiner.ts'
import { writeContext } from './output'
import { modifierSwapRules } from './modifierSwap'
import { mehRules } from './meh'
import { layerRules } from './layers'
import { homeRowRules } from './home-row'
import { capsRules } from './caps-lock'

writeToProfile({
  name: 'default', 
  dryRun: false, 
  karabinerJsonPath: writeContext.karabinerConfigFile(),
}, [
  ...capsRules,
  ...modifierSwapRules,
  ...mehRules,
  ...layerRules,
 ...homeRowRules,

  rule('escape -> grave_accent_and_tilde').manipulators([
    map("escape").to("grave_accent_and_tilde")
    .description("escape -> grave_accent_and_tilde"), 
  ]),

])


