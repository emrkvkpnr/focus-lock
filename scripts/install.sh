#!/bin/bash
# Builds FocusLock and installs the app plus the two root services.
# Run as your normal user; the script asks for the admin password once.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(id -u)" -eq 0 ]; then
    echo "Bitte ohne sudo starten. Das Skript fragt selbst nach dem Passwort." >&2
    exit 1
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/FocusLock.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/FocusLock" "$APP/Contents/MacOS/FocusLock"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.focuslock.app</string>
    <key>CFBundleName</key><string>FocusLock</string>
    <key>CFBundleExecutable</key><string>FocusLock</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
"$BIN/focuslockd" --print-plist com.focuslock.daemon > "$STAGE/com.focuslock.daemon.plist"
"$BIN/focuslockd" --print-plist com.focuslock.guard > "$STAGE/com.focuslock.guard.plist"

echo "Installation braucht Administratorrechte."
sudo bash -s "$STAGE" "$BIN" <<'ROOT'
set -euo pipefail
STAGE="$1"; BIN="$2"
for label in com.focuslock.guard com.focuslock.daemon; do
    launchctl bootout "system/$label" 2>/dev/null || true
done
install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools
install -o root -g wheel -m 755 "$BIN/focuslockd" /Library/PrivilegedHelperTools/com.focuslock.daemon
rm -rf /Applications/FocusLock.app
cp -R "$STAGE/FocusLock.app" /Applications/FocusLock.app
chown -R root:wheel /Applications/FocusLock.app
for label in com.focuslock.daemon com.focuslock.guard; do
    install -o root -g wheel -m 644 "$STAGE/$label.plist" "/Library/LaunchDaemons/$label.plist"
    launchctl enable "system/$label"
    launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
done
ROOT

open /Applications/FocusLock.app
echo "Fertig. FocusLock liegt in der Menüleiste."
