#!/bin/bash
# Removes FocusLock. Only works while no session is running: during a session the
# two services put each other back.
set -euo pipefail

STATUS="/Library/Application Support/FocusLock/status.json"
if [ -f "$STATUS" ] && grep -q '"active":true' "$STATUS"; then
    echo "Es läuft eine Sperre. Deinstallieren geht erst danach." >&2
    exit 1
fi

sudo bash -s <<'ROOT'
set -euo pipefail
for label in com.focuslock.guard com.focuslock.daemon; do
    launchctl bootout "system/$label" 2>/dev/null || true
    rm -f "/Library/LaunchDaemons/$label.plist"
done
rm -f /Library/PrivilegedHelperTools/com.focuslock.daemon
rm -rf /Applications/FocusLock.app "/Library/Application Support/FocusLock"
ROOT
echo "FocusLock wurde entfernt. Prüfe /etc/hosts, falls dort noch ein FocusLock-Block steht."
