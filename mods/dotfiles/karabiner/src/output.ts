import { 
  KarabinerConfig, 
  ModificationParameters, 
  Rule, 
  RuleBuilder, 
  complexModifications 
} from "karabiner.ts"

export const writeContext = {
  karabinerConfigDir() {
    return require('node:path').join(
      require('node:os').homedir(),
      '.config/home-manager/mods/dotfiles',
    )
  },
  karabinerConfigFile() {
    return require('node:path').join(
      this.karabinerConfigDir(),
      'karabiner.json',
    )
  },
  readKarabinerConfig() {
    return require(this.karabinerConfigFile())
  },
  writeKarabinerConfig(json: any) {
    return require('node:fs/promises').writeFile(
      this.karabinerConfigFile(),
      json,
    )
  },
  exit(code = 0): never {
    process.exit(code)
  },
}

