#!/bin/sh
#
# uninstall-launchd.sh
#
# Stops and removes the odysseus-bridge launchd agent installed by
# install-launchd.sh. Back to running `node server.js` by hand afterward.

set -eu

LABEL="com.odysseus.bridge"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ ! -f "$PLIST_PATH" ]; then
    echo "No LaunchAgent found at $PLIST_PATH — nothing to remove."
    exit 0
fi

launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"

echo "Removed $LABEL. The bridge is no longer running in the background."
