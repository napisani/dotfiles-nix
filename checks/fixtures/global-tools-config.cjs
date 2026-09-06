// Real generation-bound config operations through the real CLI. Only the
// declared HOME literal is redirected; no native installers are selected.
const fs = require('node:fs'), path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const {home, commands} = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const root = fs.mkdtempSync(path.join(process.env.TMPDIR, 'config-operations-'));
const target = path.join(root, 'home'); fs.mkdirSync(target);
function snapshot(dir) {
  return fs.readdirSync(dir).flatMap(name => {
    const file = path.join(dir,name), stat = fs.lstatSync(file);
    return stat.isDirectory() ? snapshot(file) : [[file, fs.readFileSync(file,'utf8'), stat.mtimeMs, stat.mode]];
  });
}
const manifest = path.join(root,'manifest.json');
fs.writeFileSync(manifest, JSON.stringify({files:[], operations:commands.map(({name, command}) => {
  const script = path.join(root,name+'.sh');
  const redirected = command.split(home).join(target);
  assert.ok(!redirected.includes(home));
  fs.writeFileSync(script,`#!${process.env.TEST_BASH}\nset -eu\n${redirected}`,{mode:0o700});
  return {name,command:script};
})}));
const run = mode => spawnSync(process.execPath, [process.env.GLOBAL_TOOLS_CLI, manifest, mode], {
  encoding:'utf8', env:{...process.env,HOME:target},
});
const status = run('status');
assert.equal(status.status,1,status.stderr);
// Every independent file must be reported, not just the first drift per agent.
for (const file of ['.claude.json','.claude/settings.json','.codex/hooks.json','.codex/config.toml','.pi/agent/mcp.json','.pi/agent/settings.json','.pi/agent/models.json','.npmrc', ...(commands.some(({name}) => name === 'claude-loancrate') ? ['.claude/loancrate.json'] : [])]) {
  assert.ok(status.stdout.includes(path.join(target,file)), `missing status for ${file}: ${status.stdout}`);
}
assert.deepEqual(snapshot(target),[], 'status wrote user state');
const applied = run('apply'); assert.equal(applied.status,0,applied.stdout+applied.stderr);
const after = snapshot(target);
assert.equal(run('status').status,0);
assert.deepEqual(snapshot(target),after);
assert.equal(run('apply').status,0);
assert.deepEqual(snapshot(target),after,'repeat rewrote configuration');
// Bad MCP input cannot block independent settings/loancrate config repair.
const broken = path.join(target,'.claude.json'); fs.writeFileSync(broken,'not-json');
const settings = path.join(target,'.claude/settings.json'); fs.unlinkSync(settings);
const loancrate = path.join(target,'.claude/loancrate.json');
const hasLoancrate = fs.existsSync(loancrate); if (hasLoancrate) fs.unlinkSync(loancrate);
const failed = run('apply'); assert.equal(failed.status,1);
assert.equal(fs.readFileSync(broken,'utf8'),'not-json');
assert.ok(fs.existsSync(settings));
if (hasLoancrate) assert.ok(fs.existsSync(loancrate));
// Codex's hooks are independent of malformed TOML; TOML is never line-edited.
fs.writeFileSync(broken,'{}');
const toml = path.join(target,'.codex/config.toml'); fs.writeFileSync(toml,'not = = toml');
const hooks = path.join(target,'.codex/hooks.json'); fs.unlinkSync(hooks);
assert.equal(run('apply').status,1);
assert.ok(fs.existsSync(hooks));
assert.equal(fs.readFileSync(toml,'utf8'),'not = = toml');
console.log('real CLI: complete read-only status, independent repair, fail-closed files, idempotent apply');
