// Project the whole managed portion of config.toml before writing once.
// Parsing first also prevents hook-enablement from editing malformed TOML.
const fs = require('node:fs');
const TOML = require('@iarna/toml');
const {readJsonObject} = require('../../scripts/lib/managed-hooks.js');
const {writeConfigFile} = require('../../scripts/lib/config-file.js');
const {isManaged} = require('./apply-codex-hooks.js');
const file = process.env.CONFIG_TOML_FILE;
const original = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
const doc = original.trim() ? TOML.parse(original) : {};
const declared = JSON.parse(process.env.MCP_SERVERS || '{}');
if (!declared || typeof declared !== 'object' || Array.isArray(declared)) throw new Error('invalid MCP_SERVERS');
doc.mcp_servers = declared;
doc.features = {...doc.features, hooks:true};
const hooksFile = process.env.HOOKS_TARGET_FILE;
const hooks = readJsonObject(hooksFile, {}).hooks || {};
for (const [event, groups] of Object.entries(hooks)) {
  if (!Array.isArray(groups)) throw new Error(`invalid Codex hook event ${event}`);
  const key = event.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
  groups.forEach((group, groupIndex) => (group.hooks || []).forEach((handler, index) => {
    if (isManaged(handler)) {
      const state = doc.hooks?.state?.[`${hooksFile}:${key}:${groupIndex}:${index}`];
      if (state?.enabled === false) state.enabled = true;
    }
  }));
}
writeConfigFile(file, TOML.stringify(doc));
