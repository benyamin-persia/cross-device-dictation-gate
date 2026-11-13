#!/bin/bash
set -euo pipefail
LABEL="org.crossdevice.dictationgate"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
APP="$HOME/Applications/Cross-Device Dictation Gate.app"
SUPPORT="$HOME/Library/Application Support/CrossDeviceDictationGate"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if [[ -f "$AGENT" ]]; then rm "$AGENT"; fi
if [[ -d "$APP" ]]; then rm -rf "$APP"; fi
echo "Stopped and removed Cross-Device Dictation Gate."
echo "Deskflow, SonoBus, BlackHole, and the earlier G6Dictation helper were not modified."
if [[ "$*" == *--remove-data* ]]; then
  if [[ -d "$SUPPORT" ]]; then rm -rf "$SUPPORT"; fi
  echo "Also removed this package's logs, settings, and backups."
else
  echo "Configuration, logs, and backups preserved at: $SUPPORT"
fi
