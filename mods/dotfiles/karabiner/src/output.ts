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

export function writeToProfileInDotfiles(
  name: '--dry-run' | string,
  rules: Array<Rule | RuleBuilder>,
  parameters: ModificationParameters = {},
) {
  const config: KarabinerConfig =
    name === '--dry-run'
      ? { profiles: [{ name, complex_modifications: { rules: [] } }] }
      : writeContext.readKarabinerConfig()

  const profile = config?.profiles.find((v) => v.name === name)
  if (!profile)
    exitWithError(`⚠️ Profile ${name} not found in ${writeContext.karabinerConfigFile()}.\n
ℹ️ Please check the profile name in the Karabiner-Elements UI and 
    - Update the profile name at writeToProfile()
    - Create a new profile if needed
 `)

  try {
    profile.complex_modifications = complexModifications(rules, parameters)
  } catch (e) {
    exitWithError(e)
  }

  const json = JSON.stringify(config, null, 2)

  if (name === '--dry-run') {
    console.info(json)
    return
  }

  writeContext.writeKarabinerConfig(json).catch(exitWithError)

  console.log(`✓ Profile ${name} updated.`)
}

function exitWithError(err: any): never {
  if (err) {
    if (typeof err === 'string') {
      console.error(err)
    } else {
      console.error((err as Error).message || err)
    }
  }
  return writeContext.exit(1)
}
