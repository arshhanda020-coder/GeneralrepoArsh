#!/usr/bin/env node
//
// odysseus-bridge/server.js
//
// The companion service DevAgentBridgeView (Odysseus/Views/Agents/DevAgentBridgeView.swift)
// was built to point at. Runs on your Mac, wraps the real `claude` (Claude Code)
// and `codex` CLIs in their headless/print modes, and exposes them over HTTP so
// the Odysseus app — on the same Mac or on your phone over the LAN — can send
// them real prompts against a real working directory and get real output back.
//
// This is local code execution over HTTP. There is no user system beyond a
// single shared bearer token, so:
//   - Only run it on networks you trust (home Wi-Fi, not a coffee shop).
//   - Don't request `fullAuto` (--dangerously-skip-permissions) unless you
//     mean it — it lets the agent run tools without asking.
//   - The token lives in ~/.odysseus-bridge/token, mode 600. Anyone with it
//     and network access to this port can run code as you in whatever `cwd`
//     they name.
//
// No npm dependencies — everything here is Node built-ins on purpose, so
// `node server.js` just works.
//
// Usage:
//   node server.js              # port 8787
//   PORT=9000 node server.js    # custom port
//
// See README.md in this directory for the launchd autostart plist.

'use strict';

const http = require('http');
const os = require('os');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawn } = require('child_process');

const PORT = Number(process.env.PORT || process.argv[2] || 8787);
const CONFIG_DIR = path.join(os.homedir(), '.odysseus-bridge');
const TOKEN_PATH = path.join(CONFIG_DIR, 'token');
const MAX_BODY_BYTES = 200 * 1024; // 200KB — plenty for a prompt, not for uploading a codebase
const RUN_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes

// ---------------------------------------------------------------------------
// Token: generated once, reused across restarts so you don't re-paste it into
// the app every time you relaunch the server.
// ---------------------------------------------------------------------------

function loadOrCreateToken() {
    fs.mkdirSync(CONFIG_DIR, { recursive: true, mode: 0o700 });
    if (fs.existsSync(TOKEN_PATH)) {
        return fs.readFileSync(TOKEN_PATH, 'utf8').trim();
    }
    const token = crypto.randomBytes(24).toString('hex');
    fs.writeFileSync(TOKEN_PATH, token, { mode: 0o600 });
    return token;
}

const TOKEN = loadOrCreateToken();

// ---------------------------------------------------------------------------
// CLI availability — checked fresh on every /health call (cheap) so
// installing `codex` after the server is already running just works without
// a restart.
// ---------------------------------------------------------------------------

function checkCLI(command) {
    return new Promise((resolve) => {
        const child = spawn(command, ['--version'], { stdio: ['ignore', 'pipe', 'pipe'] });
        let out = '';
        child.stdout.on('data', (d) => { out += d; });
        child.on('error', () => resolve({ available: false }));
        child.on('close', (code) => {
            resolve(code === 0 ? { available: true, version: out.trim() } : { available: false });
        });
    });
}

// ---------------------------------------------------------------------------
// Running an agent. `spawn` with an argument array — never a shell string —
// so the prompt can contain anything (quotes, `;`, backticks) without it
// being interpreted as a second command.
// ---------------------------------------------------------------------------

function runClaudeCode({ prompt, cwd, fullAuto }) {
    const args = ['-p', prompt, '--output-format', 'json', '--add-dir', cwd];
    if (fullAuto) {
        args.push('--dangerously-skip-permissions');
    } else {
        args.push('--permission-mode', 'plan');
    }
    return runProcess('claude', args, cwd).then(({ stdout, stderr, code }) => {
        if (code !== 0 && !stdout.trim()) {
            return { ok: false, error: stderr.trim() || `claude exited with code ${code}` };
        }
        try {
            const parsed = JSON.parse(stdout);
            return {
                ok: !parsed.is_error,
                output: parsed.result ?? '',
                sessionId: parsed.session_id,
                costUSD: parsed.total_cost_usd,
                error: parsed.is_error ? (parsed.result || 'Claude Code reported an error.') : undefined,
            };
        } catch {
            // --output-format json failed to parse — fall back to raw text
            // rather than hiding whatever Claude Code actually printed.
            return { ok: code === 0, output: stdout.trim(), error: code === 0 ? undefined : stderr.trim() };
        }
    });
}

// Codex CLI isn't installed on the machine this was built on, so this path
// is unverified against a real install. It avoids assuming a specific output
// format — it just runs `codex exec` and returns whatever comes back on
// stdout — so a flag mismatch degrades to "here's the raw output" rather
// than a crash. Adjust the args below once you've installed Codex and can
// see its actual headless-mode flags (`codex exec --help`).
function runCodex({ prompt, cwd, fullAuto }) {
    const args = ['exec', prompt];
    if (fullAuto) args.push('--full-auto');
    return runProcess('codex', args, cwd).then(({ stdout, stderr, code }) => {
        if (code !== 0 && !stdout.trim()) {
            return { ok: false, error: stderr.trim() || `codex exited with code ${code}` };
        }
        return { ok: code === 0, output: stdout.trim(), error: code === 0 ? undefined : stderr.trim() };
    });
}

// ---------------------------------------------------------------------------
// Git status for a project's repoPath — lets the app show branch/dirty/
// ahead-behind without shelling out to a full agent run just to check state.
// ---------------------------------------------------------------------------

function gitStatus(cwd) {
    return runProcess('git', ['-C', cwd, 'status', '--porcelain=v2', '--branch'], cwd).then(({ stdout, code }) => {
        if (code !== 0) return { isRepo: false };
        let branch = null;
        let ahead = 0;
        let behind = 0;
        let dirty = 0;
        for (const line of stdout.split('\n')) {
            if (line.startsWith('# branch.head ')) {
                branch = line.slice('# branch.head '.length).trim();
            } else if (line.startsWith('# branch.ab ')) {
                const match = line.match(/\+(\d+) -(\d+)/);
                if (match) { ahead = Number(match[1]); behind = Number(match[2]); }
            } else if (line && !line.startsWith('#')) {
                dirty += 1;
            }
        }
        return { isRepo: true, branch, ahead, behind, dirty };
    });
}

function runProcess(command, args, cwd) {
    return new Promise((resolve, reject) => {
        const child = spawn(command, args, { cwd, timeout: RUN_TIMEOUT_MS });
        let stdout = '';
        let stderr = '';
        child.stdout.on('data', (d) => { stdout += d; });
        child.stderr.on('data', (d) => { stderr += d; });
        child.on('error', (err) => {
            if (err.code === 'ENOENT') {
                resolve({ stdout: '', stderr: `"${command}" isn't installed (or not on PATH) on this Mac.`, code: 127 });
            } else {
                reject(err);
            }
        });
        child.on('close', (code) => resolve({ stdout, stderr, code }));
    });
}

const RUNNERS = { claudeCode: runClaudeCode, codex: runCodex };

// ---------------------------------------------------------------------------
// HTTP layer
// ---------------------------------------------------------------------------

function send(res, status, body) {
    const json = JSON.stringify(body);
    res.writeHead(status, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    });
    res.end(json);
}

function isAuthed(req) {
    const header = req.headers['authorization'] || '';
    const provided = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (provided.length !== TOKEN.length) return false;
    // Constant-time compare — this is the only line standing between the
    // token and a timing attack, so it's worth doing properly.
    return crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(TOKEN));
}

function readBody(req) {
    return new Promise((resolve, reject) => {
        let size = 0;
        const chunks = [];
        req.on('data', (chunk) => {
            size += chunk.length;
            if (size > MAX_BODY_BYTES) {
                reject(Object.assign(new Error('Body too large'), { statusCode: 413 }));
                req.destroy();
                return;
            }
            chunks.push(chunk);
        });
        req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
        req.on('error', reject);
    });
}

const server = http.createServer(async (req, res) => {
    if (req.method === 'OPTIONS') { send(res, 204, {}); return; }

    if (req.method === 'GET' && req.url === '/') {
        send(res, 200, { service: 'odysseus-bridge', version: 1 });
        return;
    }

    if (req.method === 'GET' && req.url === '/health') {
        if (!isAuthed(req)) { send(res, 401, { ok: false, error: 'Bad or missing token.' }); return; }
        const [claudeCode, codex] = await Promise.all([checkCLI('claude'), checkCLI('codex')]);
        send(res, 200, { ok: true, agents: { claudeCode, codex } });
        return;
    }

    if (req.method === 'POST' && req.url === '/run') {
        if (!isAuthed(req)) { send(res, 401, { ok: false, error: 'Bad or missing token.' }); return; }
        let body;
        try {
            body = JSON.parse(await readBody(req));
        } catch (err) {
            send(res, err.statusCode === 413 ? 413 : 400, { ok: false, error: err.statusCode === 413 ? 'Prompt too large.' : 'Malformed JSON body.' });
            return;
        }

        const { agent, prompt, cwd, fullAuto } = body;
        const runner = RUNNERS[agent];
        if (!runner) { send(res, 400, { ok: false, error: `agent must be one of: ${Object.keys(RUNNERS).join(', ')}` }); return; }
        if (typeof prompt !== 'string' || !prompt.trim()) { send(res, 400, { ok: false, error: 'prompt is required.' }); return; }

        const resolvedCwd = typeof cwd === 'string' && cwd.trim() ? cwd.trim() : os.homedir();
        if (!fs.existsSync(resolvedCwd) || !fs.statSync(resolvedCwd).isDirectory()) {
            send(res, 400, { ok: false, error: `cwd "${resolvedCwd}" doesn't exist on this Mac.` });
            return;
        }

        try {
            const result = await runner({ prompt: prompt.trim(), cwd: resolvedCwd, fullAuto: !!fullAuto });
            send(res, 200, result);
        } catch (err) {
            send(res, 500, { ok: false, error: err.message });
        }
        return;
    }

    if (req.method === 'GET' && req.url.startsWith('/git-status')) {
        if (!isAuthed(req)) { send(res, 401, { ok: false, error: 'Bad or missing token.' }); return; }
        const { searchParams } = new URL(req.url, `http://${req.headers.host}`);
        const cwd = (searchParams.get('cwd') || '').trim();
        if (!cwd) { send(res, 400, { ok: false, error: 'cwd query param is required.' }); return; }
        if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) {
            send(res, 400, { ok: false, error: `cwd "${cwd}" doesn't exist on this Mac.` });
            return;
        }
        try {
            const status = await gitStatus(cwd);
            send(res, 200, { ok: true, ...status });
        } catch (err) {
            send(res, 500, { ok: false, error: err.message });
        }
        return;
    }

    send(res, 404, { ok: false, error: 'Not found.' });
});

server.listen(PORT, () => {
    const lanIP = Object.values(os.networkInterfaces())
        .flat()
        .find((i) => i && i.family === 'IPv4' && !i.internal)?.address;

    console.log(`odysseus-bridge listening on port ${PORT}`);
    console.log(`  Token (from ${TOKEN_PATH}): ${TOKEN}`);
    console.log(`  On this Mac:  http://localhost:${PORT}`);
    if (lanIP) console.log(`  From your phone (same Wi-Fi): http://${lanIP}:${PORT}`);
    else console.log('  Could not detect a LAN IP — check Wi-Fi is connected if you need phone access.');
});
