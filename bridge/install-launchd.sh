#!/bin/sh
#
# install-launchd.sh
#
# Installs odysseus-bridge as a launchd LaunchAgent so it runs invisibly in
# the background on this Mac: starts at login, restarts itself if it
# crashes (KeepAlive), and needs no Terminal window open. This is the
# resilience fix for "the bridge dies when I close my Terminal tab."
#
# Usage:
#   cd bridge
#   ./install-launchd.sh
#
# Safe to re-run — it unloads any existing copy first, so re-running after
# moving the repo or updating server.js just re-registers it with the
# current paths.

set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This installs a launchd agent, which only exists on macOS." >&2
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SERVER_JS="$SCRIPT_DIR/server.js"
if [ ! -f "$SERVER_JS" ]; then
    echo "Couldn't find server.js next to this script (looked in $SCRIPT_DIR)." >&2
    exit 1
fi

NODE_PATH=$(command -v node || true)
if [ -z "$NODE_PATH" ]; then
    echo "node isn't on your PATH. Install Node.js first, then re-run this script." >&2
    exit 1
fi

LABEL="com.odysseus.bridge"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
LOG_PATH="/tmp/odysseus-bridge.log"

mkdir -p "$PLIST_DIR"

# Unload any previously-installed copy so re-running this script always
# leaves exactly one, current-paths agent behind instead of erroring on a
# duplicate load.
if launchctl list "$LABEL" >/dev/null 2>&1; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_PATH</string>
    <string>$SERVER_JS</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOG_PATH</string>
  <key>StandardErrorPath</key><string>$LOG_PATH</string>
</dict>
</plist>
EOF

launchctl load "$PLIST_PATH"

echo "Installed and started $LABEL."
echo "  Runs at login, restarts itself if it crashes, no Terminal needed."
echo "  Plist:  $PLIST_PATH"
echo "  Logs:   $LOG_PATH"
echo
echo "Verify it's up:"
echo "  curl http://localhost:8787/"
echo
echo "To stop and remove it later:"
echo "  ./uninstall-launchd.sh"
