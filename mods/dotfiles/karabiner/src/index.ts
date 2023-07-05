import {
  map,
  rule,
} from 'karabiner.ts'
import { writeToProfileInDotfiles } from './output'
import { hyperRules } from './hyper'
import { modifierSwapRules } from './modifierSwap'
import { mehRules } from './meh'
import { layerRules } from './layers'

writeToProfileInDotfiles('default', [
  ...hyperRules,
  ...modifierSwapRules,
  ...mehRules,
  ...layerRules,
  rule('escape -> grave_accent_and_tilde').manipulators([
    map("escape").to("grave_accent_and_tilde")
    .description("escape -> grave_accent_and_tilde"), 
  ]),

])


