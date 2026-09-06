// Codex hooks.json has one writer. Its config.toml is a separate operation.
const {readJsonObject, writeJsonIfChanged, replaceManagedHooks} = require('../../scripts/lib/managed-hooks.js');
const isManaged = handler => typeof handler?.command === 'string' && handler.command.includes('workmux set-window-status');
if (require.main === module) {
  const source = readJsonObject(process.env.HOOKS_SOURCE_FILE);
  if (!source) throw new Error('missing declared Codex hooks');
  const target = readJsonObject(process.env.HOOKS_TARGET_FILE, {});
  target.hooks = replaceManagedHooks(target.hooks || {}, source, isManaged);
  writeJsonIfChanged(process.env.HOOKS_TARGET_FILE, target);
}
module.exports = {isManaged};
