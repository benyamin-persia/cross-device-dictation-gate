#!/bin/bash
# Cross-Device Dictation Gate - macOS installer. No root required.
set -euo pipefail
usage() {
  echo 'Usage: ./install.sh --windows-ip 192.168.1.10 --mac-ip 192.168.1.20 [--port 43891] [--update] [--validate-only]'
}
WINDOWS_IP=""
MAC_IP=""
PORT=43891
UPDATE=0
VALIDATE=0
while (( $# > 0 )); do
  case "$1" in
    --windows-ip) WINDOWS_IP="$2"; shift 2 ;;
    --mac-ip) MAC_IP="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --update) UPDATE=1; shift ;;
    --validate-only) VALIDATE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option $1" >&2; usage; exit 2 ;;
  esac
done
command -v python3 >/dev/null || { echo "Install Xcode Command Line Tools: xcode-select --install"; exit 3; }
python3 -c 'import ipaddress,sys; a=ipaddress.IPv4Address(sys.argv[1]); b=ipaddress.IPv4Address(sys.argv[2]); assert a != b, "Same IP"' "$WINDOWS_IP" "$MAC_IP" || exit 2
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then echo "Invalid port" >&2; exit 2; fi
command -v swiftc >/dev/null || { echo "swiftc missing. Run xcode-select --install" >&2; exit 3; }
command -v codesign >/dev/null || { echo "codesign missing" >&2; exit 3; }
ROOT="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$ROOT/MacDictationGate.swift.in"
[[ -f "$TEMPLATE" ]] || { echo "Missing Swift template" >&2; exit 3; }
APP="$HOME/Applications/Cross-Device Dictation Gate.app"
SUPPORT="$HOME/Library/Application Support/CrossDeviceDictationGate"
AGENT="$HOME/Library/LaunchAgents/org.crossdevice.dictationgate.plist"
LABEL="org.crossdevice.dictationgate"
if (( !VALIDATE && !UPDATE )) && { [[ -e "$APP" ]] || [[ -e "$AGENT" ]]; }; then
  echo "Already installed; use --update to back up and replace this package." >&2; exit 4
fi
STAGE="$(mktemp -d /tmp/cross-device-gate.XXXXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
SOURCE_OUT="$STAGE/MacDictationGate.swift"
sed -e "s/__WINDOWS_IP__/$WINDOWS_IP/g" -e "s/__UDP_PORT__/$PORT/g" "$TEMPLATE" > "$SOURCE_OUT"
if grep -Eq '__[A-Z_]+__' "$SOURCE_OUT"; then echo "Unresolved template variable" >&2; exit 4; fi
swiftc -O "$SOURCE_OUT" -o "$STAGE/MacDictationGate"
if (( VALIDATE )); then echo "PASS: Swift code compiled. No installation performed."; exit 0; fi
mkdir -p "$HOME/Applications" "$SUPPORT" "$HOME/Library/LaunchAgents"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -e "$APP" ]]; then
  mkdir -p "$SUPPORT/backups"
  ditto "$APP" "$SUPPORT/backups/Cross-Device Dictation Gate-$STAMP.app"
fi
if [[ -e "$AGENT" ]]; then cp -p "$AGENT" "$AGENT.backup-$STAMP"; fi
# Only this package's LaunchAgent is touched; original G6Dictation remains unchanged.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
mkdir -p "$APP/Contents/MacOS"
cp "$STAGE/MacDictationGate" "$APP/Contents/MacOS/MacDictationGate"
cp "$SOURCE_OUT" "$SUPPORT/MacDictationGate.swift"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.crossdevice.dictationgate</string>
<key>CFBundleExecutable</key><string>MacDictationGate</string>
<key>CFBundleName</key><string>Cross-Device Dictation Gate</string>
<key>CFBundleDisplayName</key><string>Cross-Device Dictation Gate</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>NSInputMonitoringUsageDescription</key><string>Enable dictation for the currently controlled computer.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - --identifier "$LABEL" "$APP"
codesign --verify --deep --strict "$APP"
cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$APP/Contents/MacOS/MacDictationGate</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>60</integer>
<key>StandardOutPath</key><string>$SUPPORT/gate.log</string>
<key>StandardErrorPath</key><string>$SUPPORT/gate-error.log</string>
</dict></plist>
EOF
plutil -lint "$AGENT"
printf 'WindowsIP=%s\nMacIP=%s\nPort=%s\n' "$WINDOWS_IP" "$MAC_IP" "$PORT" > "$SUPPORT/connection.conf"
chmod 600 "$SUPPORT/connection.conf"
launchctl bootstrap "gui/$(id -u)" "$AGENT"
echo "INSTALLED: $APP"
echo "Mac startup: $AGENT"
echo "Approve Cross-Device Dictation Gate in System Settings > Privacy & Security > Accessibility"
echo "Approve Input Monitoring if prompted. Then run:"
echo "  launchctl kickstart -k gui/$(id -u)/$LABEL"
echo "Set the macOS Dictation shortcut to Option+H and choose your intended microphone."
echo "Disable any previous competing G6 helper before switching to this app."
