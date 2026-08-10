# odysseus-bridge

The companion service Odysseus's **Claude Code** / **Codex** sections
(`DevAgentBridgeView`) connect to. There's no public mobile API for either
tool — this is a small HTTP server you run on your Mac that wraps the real
`claude` and `codex` CLIs, so prompts sent from the app run through the
actual agent against a real working directory and come back with real
output.

No npm install needed — `server.js` only uses Node built-ins.

## Run it

```sh
cd bridge
node server.js
```

You'll see something like:

```
odysseus-bridge listening on port 8787
  Token (from /Users/you/.odysseus-bridge/token): 9068f1cb...
  On this Mac:  http://localhost:8787
  From your phone (same Wi-Fi): http://192.168.1.105:8787
```

In the app, open **Claude Code** or **Codex** under Subagents, and fill in:
- **Bridge URL** — the `http://192.168.x.x:8787` line above (use `localhost`
  if you're running Odysseus on the same Mac).
- **Token** — copied from the server's startup output. It's saved once and
  reused; re-running `node server.js` prints the same token (it's persisted
  to `~/.odysseus-bridge/token`) so you only paste it once.
- **Working directory** — the project you want the agent to work in.

Tap **SAVE & CONNECT**. A green dot means the bridge is reachable and the
CLI is installed; amber means the bridge is up but that CLI isn't found on
this Mac.

To keep it running in the background instead of a terminal tab, see
[Autostart with launchd](#autostart-with-launchd) below.

## What it actually does

- `GET /` — unauthenticated reachability ping.
- `GET /health` — (token required) reports whether `claude`/`codex` are
  installed and their versions.
- `POST /run` — (token required) runs `claude -p "<prompt>" --output-format
  json --add-dir <cwd>` (or the `codex` equivalent) with `cwd` as the
  process's working directory, **blocks until it finishes**, and returns the
  result as JSON. Kept for backwards compatibility.
- `POST /tasks` — (token required) same run, but fire-and-forget: returns
  `{ id, status: "working", ... }` immediately (HTTP 202) while the CLI keeps
  running in the background.
- `GET /tasks` — (token required) the task list — `?agent=claudeCode` or
  `?agent=codex` to filter — newest first, each with `status: "working" |
  "completed" | "error"`. This is what the app polls to build its dashboard
  (the "Working / Completed" feed under Subagents → Claude Code/Codex),
  mirroring `claude`'s own background-task view in a terminal.
- `GET /tasks/:id` — (token required) a single task's current state.
- `GET /git-status?cwd=<path>` — (token required) runs `git status
  --porcelain=v2 --branch` against `cwd` and returns `{ isRepo, branch,
  ahead, behind, dirty }`. Used by a Project's linked repo to show live
  branch/dirty state without spending an agent run just to check it.

Task history persists to `~/.odysseus-bridge/tasks.json` (mode 600, capped
at the 200 most recent) so it survives a server restart.

The prompt is passed as an argument to `spawn`, never through a shell
string, so it can't be used to inject a second command.

## Permission modes

- **Off (default)** — runs with `--permission-mode plan`: Claude Code can
  read and plan but won't edit files or run commands.
- **Full auto** — runs with `--dangerously-skip-permissions`: the agent can
  edit files and run shell commands without asking. Only use this against
  directories/projects you're fine with an agent modifying unsupervised.

## Codex

`codex` wasn't installed on the machine this was built on, so `runCodex` in
`server.js` is untested against a real install — it calls `codex exec
<prompt>` and returns whatever comes back on stdout rather than assuming a
specific JSON shape. Once you've installed the Codex CLI, run `codex exec
--help` and adjust the args in `runCodex()` if its actual flags differ.

## Security

This is local code execution reachable over HTTP with a single shared
token — there's no per-request user, expiry, or rate limiting.

- Only run it on networks you trust (home Wi-Fi, not a coffee shop).
- The token lives at `~/.odysseus-bridge/token`, mode `600`. Delete that
  file and restart the server to rotate it.
- Don't leave **Full auto** on for a working directory you wouldn't want an
  unsupervised agent modifying.

## Autostart with launchd

To have it start automatically at login instead of running `node
server.js` by hand:

```sh
cat > ~/Library/LaunchAgents/com.odysseus.bridge.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.odysseus.bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>REPLACE_WITH_ABSOLUTE_PATH/bridge/server.js</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/odysseus-bridge.log</string>
  <key>StandardErrorPath</key><string>/tmp/odysseus-bridge.log</string>
</dict>
</plist>
EOF
# Edit the plist above to replace REPLACE_WITH_ABSOLUTE_PATH, and confirm
# node's path with `which node` (it may not be /usr/local/bin/node on your Mac).
launchctl load ~/Library/LaunchAgents/com.odysseus.bridge.plist
```

Check it's running: `curl http://localhost:8787/` — logs land in
`/tmp/odysseus-bridge.log`.
