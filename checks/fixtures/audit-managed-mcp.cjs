const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const root = fs.mkdtempSync(path.join(os.tmpdir(),'mcp-audit-'));
try {
  const declarations = path.join(root,'declared.json');
  fs.writeFileSync(declarations, JSON.stringify({claude:{mcpServers:{keep:{command:'desired'}}}}));
  const config = path.join(root,'.claude.json');
  fs.writeFileSync(config, JSON.stringify({oauthToken:'NEVER-PRINT-THIS', mcpServers:{keep:{command:'edited'},manual:{token:'ALSO-PRIVATE'}}}));
  const before = fs.readFileSync(config,'utf8'), mtime = fs.statSync(config).mtimeMs;
  const run = () => spawnSync(process.env.TEST_PYTHON,[process.argv[2],declarations,'--home',root],{encoding:'utf8'});
  const result = run(); assert.equal(result.status,1,result.stderr);
  const report = JSON.parse(result.stdout)[0];
  assert.deepEqual(report.undeclared,['manual']); assert.deepEqual(report.changed,['keep']);
  assert.ok(!result.stdout.includes('NEVER-PRINT-THIS')); assert.ok(!result.stdout.includes('ALSO-PRIVATE'));
  assert.equal(fs.readFileSync(config,'utf8'),before); assert.equal(fs.statSync(config).mtimeMs,mtime);
  fs.writeFileSync(config,'malformed PRIVATE-CONTENT');
  const bad = run(); assert.equal(bad.status,2); assert.equal(JSON.parse(bad.stdout)[0].status,'unreadable');
  assert.ok(!bad.stdout.includes('PRIVATE-CONTENT')); assert.equal(fs.readFileSync(config,'utf8'),'malformed PRIVATE-CONTENT');
} finally {fs.rmSync(root,{recursive:true,force:true});}
console.log('MCP audit: read-only, reports names, never prints values');
