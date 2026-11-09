const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const runtime = process.env.CONFIG_WRITER_RUNTIME || path.resolve(__dirname, '../../mods/dotfiles/mise/runtime');
const setup = path.join(runtime, 'mise/rtk-setup.cjs');
const native = process.env.RTK_TEST_BINARY;
function write(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}
function snapshot(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).sort().flatMap(name => {
    const file = path.join(dir, name);
    const stat = fs.lstatSync(file);
    return stat.isDirectory() ? snapshot(file) : [[file, stat.isSymbolicLink() ? fs.readlinkSync(file) : createHash('sha256').update(fs.readFileSync(file)).digest('hex')]];
  });
}
function fixture(t, binary) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'rtk-setup-test-')));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const home = path.join(root, 'home');
  fs.mkdirSync(home);
  const mise = path.join(root, 'mise');
  write(mise, '#!/bin/sh\n[ "$3 $4 $5 $6" = "which rtk --tool aqua:rtk-ai/rtk" ] || exit 9\nprintf "%s\\n" "$TEST_SELECTED_RTK"\n');
  fs.chmodSync(mise, 0o755);
  if (!binary) {
    binary = path.join(root, 'rtk');
    write(binary, `#!${process.execPath}\nconst fs=require('node:fs'),path=require('node:path');
if(process.argv.includes('--dry-run'))process.exit(0);
const target=process.argv.includes('--codex')?'.codex/RTK.md':process.argv.includes('pi')?'.pi/agent/extensions/rtk.ts':'.claude/RTK.md';
const file=path.join(process.env.HOME,target);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,'stock upstream content\\n');\n`);
    fs.chmodSync(binary, 0o755);
  }
  const env = {
    HOME: home, PATH: process.env.PATH,
    XDG_CONFIG_HOME: path.join(home, '.config'),
    XDG_DATA_HOME: path.join(home, '.local/share'),
    XDG_STATE_HOME: path.join(home, '.local/state'),
    XDG_CACHE_HOME: path.join(home, '.cache'),
    TEST_SELECTED_RTK: binary,
  };
  const run = (extra = {}) => spawnSync(process.execPath, [setup, mise], {
    cwd: home, env: { ...env, ...extra }, encoding: 'utf8', timeout: 30000,
  });
  return { home, env, run, file: name => path.join(home, name) };
}
function success(result) { assert.equal(result.status, 0, result.stdout + result.stderr); }

for (const [name, binary] of [['fixture', undefined], ['upstream', native]]) {
  const skip = name === 'upstream' && !binary ? 'Set RTK_TEST_BINARY to an isolated mise-selected RTK executable' : false;
  test(`${name}: repeat initialization preserves manual hooks, settings and filter trust`, { skip }, t => {
    const h = fixture(t, binary);
    write(h.file('.claude/settings.json'), JSON.stringify({ manual: 'keep', hooks: { PreToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: 'manual-hook' }] }] } }));
    write(h.file('.codex/hooks.json'), JSON.stringify({ manual: 'keep', hooks: { PreToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: 'manual-codex-hook' }] }] } }));
    write(h.file('.claude/CLAUDE.md'), 'Manual instructions\n@RTK.md\n');
    write(h.file('.codex/AGENTS.md'), `Manual instructions\n@${h.home}/.codex/RTK.md\n`);
    write(h.file('.codex/config.toml'), 'model = "manual-model"\n');
    const filter = process.platform === 'darwin' ? 'Library/Application Support/rtk/filters.toml' : '.config/rtk/filters.toml';
    const filterText = '[filters.manual]\nmatch_command = "^dangerous-test-command$"\nstrip_lines_matching = ["noise"]\n';
    write(h.file(filter), filterText);
    success(h.run());
    // Upstream logs invocations and discovers shared Pi/OMP ownership on rerun.
    const configuration = () => snapshot(h.home).filter(([file]) => !/\/(?:history\.db(?:-shm|-wal)?|\.rtk-agents)$/.test(file));
    const before = configuration();
    success(h.run());
    assert.deepEqual(configuration(), before);
    assert.equal(fs.readFileSync(h.file(filter), 'utf8'), filterText);
    assert.match(fs.readFileSync(h.file('.claude/settings.json'), 'utf8'), /manual-hook/);
    assert.match(fs.readFileSync(h.file('.codex/hooks.json'), 'utf8'), /manual-codex-hook/);
    assert.equal(fs.readFileSync(h.file('.codex/config.toml'), 'utf8'), 'model = "manual-model"\n');
    if (!binary) return;
    const claudeSource = h.file('declared-claude-hooks.json');
    const codexSource = h.file('declared-codex-hooks.json');
    const workmux = { Stop: [{ hooks: [{ type: 'command', command: 'workmux set-window-status done' }] }] };
    write(claudeSource, JSON.stringify(workmux));
    write(codexSource, JSON.stringify(workmux));
    const writers = `import json, sys
from pathlib import Path
sys.path.insert(0, ${JSON.stringify(runtime)})
from configure_apps import ConfigWriter, apply_claude_settings, apply_codex_hooks
writer = ConfigWriter()
read = lambda file: json.loads(Path(file).read_text())
apply_claude_settings(writer, Path(${JSON.stringify(h.file('.claude/settings.json'))}), read(${JSON.stringify(claudeSource)}), {})
apply_codex_hooks(writer, Path(${JSON.stringify(h.file('.codex/hooks.json'))}), read(${JSON.stringify(codexSource)}))`;
    for (let i = 0; i < 2; i++) {
      success(spawnSync('uv', ['run', '--locked', '--project', runtime, 'python', '-c', writers], {
        env: { ...h.env, UV_CACHE_DIR: process.env.UV_CACHE_DIR || path.join(os.homedir(), '.cache/uv') }, encoding: 'utf8',
      }));
    }
    for (const agent of ['claude', 'codex']) {
      const text = fs.readFileSync(h.file(agent === 'claude' ? '.claude/settings.json' : '.codex/hooks.json'), 'utf8');
      assert.match(text, /manual-/);
      assert.match(text, /workmux set-window-status/);
      assert.equal(text.split(`rtk hook ${agent}`).length - 1, 1, text);
      assert.doesNotMatch(text, /\/nix\/store/);
    }
    for (const [file] of snapshot(h.home).filter(([file]) => /trust/i.test(path.basename(file)))) {
      assert.doesNotMatch(fs.readFileSync(file, 'utf8'), /dangerous-test-command/);
    }
  });
  for (const file of ['.claude/RTK.md', '.codex/RTK.md', '.pi/agent/extensions/rtk.ts']) {
    test(`${name}: modified ${file} stops all initialization`, { skip }, t => {
      const h = fixture(t, binary);
      success(h.run());
      if (binary) {
        for (const target of ['.claude/settings.json', '.codex/hooks.json']) {
          assert.equal(fs.statSync(h.file(target)).mode & 0o777, 0o600);
        }
      }
      fs.appendFileSync(h.file(file), '\nmanual customization\n');
      const before = snapshot(h.home);
      const result = h.run();
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, /Refusing non-stock/);
      assert.deepEqual(snapshot(h.home), before);
    });
  }
}
test('native RTK and core instruction templates coexist across repeated applies', {
  skip: !(native && process.env.MISE_TEST_BINARY) && 'Set RTK_TEST_BINARY and MISE_TEST_BINARY',
}, t => {
  const toml = require('./toml.cjs');
  const h = fixture(t, native);
  const sources = path.resolve(__dirname, '../../mods/dotfiles');
  const core = toml.parse(fs.readFileSync(path.join(sources, 'mise/config.toml'), 'utf8'));
  const targets = ['~/.claude/CLAUDE.md', '~/.codex/AGENTS.md'];
  const declarations = Object.fromEntries(targets.map(target => [target, core.dotfiles[target]]));
  assert.ok(targets.every(target => declarations[target]));
  for (const file of ['claude-instructions.md.tera', 'codex-instructions.md.tera']) {
    write(h.file('.config/mise/dotfiles/mise/apps/' + file), fs.readFileSync(path.join(sources, 'mise/apps', file), 'utf8'));
  }
  write(h.file('.config/mise/dotfiles/agents/AGENTS.md'), 'Fixture instructions\n');
  write(h.file('.config/mise/config.toml'), toml.stringify({
    settings: { history: { enabled: false } }, dotfiles: declarations,
  }));
  const env = { ...h.env, MISE_YES: '1' };
  for (const [key, dir] of [['CONFIG', '.config/mise'], ['DATA', '.local/share/mise'],
    ['STATE', '.local/state/mise'], ['CACHE', '.cache/mise'], ['SYSTEM_CONFIG', 'system']]) {
    env['MISE_' + key + '_DIR'] = h.file(dir);
  }
  const apply = () => spawnSync(process.env.MISE_TEST_BINARY, ['-C', h.home, 'dot', 'apply'], { env, encoding: 'utf8' });
  const instructions = () => targets.map(target => fs.readFileSync(h.file(target.slice(2)), 'utf8'));
  success(apply());
  const before = instructions();
  success(h.run());
  assert.deepEqual(instructions(), before);
  success(apply());
  success(h.run());
  assert.deepEqual(instructions(), before);
});
for (const file of ['.claude/settings.json', '.codex/hooks.json']) {
  test(`malformed ${file} fails without writes or leaked contents`, t => {
    const h = fixture(t);
    write(h.file(file), '{private credential');
    const before = snapshot(h.home);
    const result = h.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Invalid JSON/);
    assert.doesNotMatch(result.stderr, /private credential/);
    assert.deepEqual(snapshot(h.home), before);
  });
}
for (const file of ['.claude/RTK.md', '.codex/RTK.md', '.pi/agent/extensions', '.claude/settings.json']) {
  test(`symlink ${file} requires deliberate handoff`, t => {
    const h = fixture(t);
    const external = h.file('unmanaged');
    write(external, 'do not overwrite');
    fs.mkdirSync(path.dirname(h.file(file)), { recursive: true });
    fs.symlinkSync(external, h.file(file));
    const before = snapshot(h.home);
    const result = h.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /ownership handoff required/);
    assert.deepEqual(snapshot(h.home), before);
  });
}
test('Nix-backed hook requires retirement before upstream initialization', t => {
  const h = fixture(t);
  write(h.file('.claude/settings.json'), JSON.stringify({ hooks: { PreToolUse: [{ hooks: [{ command: '/nix/store/old-rtk/bin/rtk hook claude' }] }] } }));
  const before = snapshot(h.home);
  assert.match(h.run().stderr, /Retire the old Nix RTK hook/);
  assert.deepEqual(snapshot(h.home), before);
});
