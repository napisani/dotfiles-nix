const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const {spawnSync} = require('node:child_process');
const test = require('node:test');
const TOML = require('@iarna/toml');
test('Codex projects MCP and hook flags together, preserving manual config', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(),'codex-config-'));
  t.after(() => fs.rmSync(dir,{recursive:true,force:true}));
  const hooks = path.join(dir,'hooks.json'), config = path.join(dir,'config.toml');
  const managedKey = `${hooks}:stop:0:0`, manualKey = `${hooks}:stop:0:1`;
  fs.writeFileSync(hooks, JSON.stringify({hooks:{Stop:[{hooks:[{command:'workmux set-window-status done'},{command:'manual'}]}]}}));
  const before = TOML.stringify({model:'keep', features:{hooks:false,other:true},mcp_servers:{old:{command:'old'}},hooks:{state:{[managedKey]:{enabled:false},[manualKey]:{enabled:false}}}});
  fs.writeFileSync(config,before);
  const run = mode => spawnSync(process.execPath,[path.join(__dirname,'apply-codex-config.js')],{
    encoding:'utf8',env:{...process.env,CONFIG_TOML_FILE:config,HOOKS_TARGET_FILE:hooks,MCP_SERVERS:'{"new":{"command":"new"}}',RECONCILE_MODE:mode},
  });
  assert.equal(run('status').status,1); assert.equal(fs.readFileSync(config,'utf8'),before);
  assert.equal(run('apply').status,0);
  const result = TOML.parse(fs.readFileSync(config,'utf8'));
  assert.deepEqual(Object.keys(result.mcp_servers),['new']);
  assert.equal(result.model,'keep'); assert.deepEqual(result.features,{hooks:true,other:true});
  assert.equal(result.hooks.state[managedKey].enabled,true);
  assert.equal(result.hooks.state[manualKey].enabled,false);
  assert.equal(run('status').status,0);
});
