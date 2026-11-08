const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const agents = [
  { name: 'claude', args: ['--auto-patch'], stock: '.claude/RTK.md' },
  { name: 'pi', args: ['--agent', 'pi'], stock: '.pi/agent/extensions/rtk.ts' },
  { name: 'codex', args: ['--codex'], stock: '.codex/RTK.md' },
];
const targets = [
  '.claude/RTK.md', '.claude/CLAUDE.md', '.claude/settings.json',
  '.codex/RTK.md', '.codex/AGENTS.md', '.codex/hooks.json',
  '.pi/agent/extensions/rtk.ts', '.pi/agent/extensions/.rtk-agents',
  '.config/rtk', 'Library/Application Support/rtk', '.local/share/rtk',
];

function rejectLinks(home, relative) {
  let current = home;
  for (const part of relative.split('/')) {
    current = path.join(current, part);
    let stat;
    try { stat = fs.lstatSync(current); }
    catch (error) {
      if (error.code === 'ENOENT') return;
      throw error;
    }
    if (stat.isSymbolicLink()) {
      throw new Error(`RTK ownership handoff required: ${current} is a symlink; review and back it up before removing it`);
    }
  }
}

function setup(mise, home = fs.realpathSync(os.homedir())) {
  const globalPaths = {
    CLAUDE_CONFIG_DIR: path.join(home, '.claude'),
    CODEX_HOME: path.join(home, '.codex'),
    PI_CODING_AGENT_DIR: path.join(home, '.pi/agent'),
    XDG_CONFIG_HOME: path.join(home, '.config'),
    XDG_DATA_HOME: path.join(home, '.local/share'),
    XDG_STATE_HOME: path.join(home, '.local/state'),
    XDG_CACHE_HOME: path.join(home, '.cache'),
  };
  for (const [key, expected] of Object.entries(globalPaths)) {
    if (process.env[key] && path.resolve(process.env[key]) !== expected &&
      path.resolve(process.env[key]) !== path.join(os.homedir(), path.relative(home, expected))) {
      throw new Error(`rtk:setup supports standard global paths only; review ${key} first`);
    }
  }
  if (Object.keys(process.env).some(key => key.startsWith('RTK_') && process.env[key])) {
    throw new Error('Review RTK_* environment overrides before running rtk:setup');
  }
  for (const target of targets) rejectLinks(home, target);
  for (const relative of ['.claude/settings.json', '.codex/hooks.json']) {
    const file = path.join(home, relative);
    if (!fs.existsSync(file)) continue;
    const contents = fs.readFileSync(file, 'utf8');
    let parsed;
    try { parsed = JSON.parse(contents); }
    catch { throw new Error(`Invalid JSON at ${file}`); }
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error(`Expected a JSON object at ${file}`);
    }
    if (/\/nix\/store\/[^"\s]*\/rtk(?:\s|\\)/.test(contents)) {
      throw new Error(`Retire the old Nix RTK hook in ${file} before upstream initialization`);
    }
  }
  const rtk = execFileSync(mise, ['-C', home, 'which', 'rtk', '--tool', 'aqua:rtk-ai/rtk'], {
    encoding: 'utf8',
  }).trim();
  const env = { ...process.env, ...globalPaths, HOME: home, PATH: `${path.dirname(rtk)}:${process.env.PATH}` };
  const init = (agent, cwd, environment, extra = []) => execFileSync(rtk,
    ['init', '--global', ...agent.args, '--no-trust-filters', ...extra],
    { cwd, env: environment, input: '', encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });

  // Upstream overwrites RTK.md even with --no-patch. Compare, never deploy,
  // fresh upstream output before allowing it to write an existing profile.
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'rtk-preflight-'));
  try {
    const scratchEnv = {
      HOME: scratch, PATH: env.PATH,
      XDG_CONFIG_HOME: path.join(scratch, '.config'),
      XDG_DATA_HOME: path.join(scratch, '.local/share'),
      XDG_STATE_HOME: path.join(scratch, '.local/state'),
      XDG_CACHE_HOME: path.join(scratch, '.cache'),
    };
    for (const agent of agents) {
      init(agent, scratch, scratchEnv);
      const existing = path.join(home, agent.stock);
      if (fs.existsSync(existing) && !fs.readFileSync(existing).equals(fs.readFileSync(path.join(scratch, agent.stock)))) {
        throw new Error(`Refusing non-stock RTK file: ${existing}; back up and review it before retrying (including after an RTK upgrade)`);
      }
    }
    for (const agent of agents) init(agent, home, env, ['--dry-run']);
    for (const agent of agents) process.stdout.write(init(agent, home, env));
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

if (require.main === module) {
  process.umask(0o077);
  try { setup(process.argv[2] || process.env.MISE_BIN || 'mise'); }
  catch (error) {
    console.error(error.stderr?.toString() || error.message);
    process.exitCode = 1;
  }
}
module.exports = { setup };
