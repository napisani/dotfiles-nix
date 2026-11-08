const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { test } = require('node:test');

test('Claude loads user instructions despite a missing RTK import', {
  skip: !process.env.CLAUDE_TEST_BINARY && 'Set CLAUDE_TEST_BINARY to the pinned Claude executable',
  timeout: 45000,
}, async t => {
  const home = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'claude-memory-')));
  t.after(() => fs.rmSync(home, { recursive: true, force: true }));
  fs.mkdirSync(path.join(home, '.claude'));
  fs.writeFileSync(path.join(home, '.claude/CLAUDE.md'), 'Fixture memory marker\n@RTK.md\n');
  const requests = [];
  const server = http.createServer(async (req, res) => {
    let text = '';
    for await (const chunk of req) text += chunk;
    const body = text ? JSON.parse(text) : {};
    if (req.url.includes('count_tokens')) {
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify({ input_tokens: 1 }));
      return;
    }
    if (!req.url.startsWith('/v1/messages')) {
      res.writeHead(404).end();
      return;
    }
    requests.push(body);
    const message = { id: 'msg_fixture', type: 'message', role: 'assistant', model: body.model,
      content: [{ type: 'text', text: 'fixture response' }], stop_reason: 'end_turn', stop_sequence: null,
      usage: { input_tokens: 1, output_tokens: 2 } };
    if (!body.stream) {
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify(message));
      return;
    }
    res.setHeader('content-type', 'text/event-stream');
    for (const event of [
      { type: 'message_start', message: { ...message, content: [], stop_reason: null } },
      { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
      { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'fixture response' } },
      { type: 'content_block_stop', index: 0 },
      { type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: null }, usage: { output_tokens: 2 } },
      { type: 'message_stop' },
    ]) res.write(`event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`);
    res.end();
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  const child = spawn(process.env.CLAUDE_TEST_BINARY, ['-p', 'Reply with fixture response',
    '--model', 'claude-sonnet-4-6', '--no-session-persistence', '--max-turns', '1'], {
    cwd: home,
    env: {
      HOME: home, PATH: process.env.PATH,
      ANTHROPIC_API_KEY: 'fixture-not-a-secret',
      ANTHROPIC_BASE_URL: `http://127.0.0.1:${server.address().port}`,
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1', DISABLE_AUTOUPDATER: '1',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  t.after(() => child.kill());
  const timer = setTimeout(() => child.kill('SIGKILL'), 35000);
  t.after(() => clearTimeout(timer));
  let stdout = '', stderr = '';
  child.stdout.on('data', data => { stdout += data; });
  child.stderr.on('data', data => { stderr += data; });
  const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); });
  assert.equal(code, 0, stdout + stderr);
  assert.match(stdout, /fixture response/);
  assert.ok(requests.some(request => JSON.stringify(request).includes('Fixture memory marker')));
  assert.equal(fs.existsSync(path.join(home, '.claude/RTK.md')), false);
});
