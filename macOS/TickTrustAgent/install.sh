#!/bin/bash
# TickTrust macOS Agent — install script
# Run as admin (sudo) on the MacBook.
# Usage: sudo ./install.sh <device_id>

set -euo pipefail

DEVICE_ID="${1:?Usage: sudo $0 <device_id>}"
SUPABASE_URL="https://xdwvhezjgmcptyncoipa.supabase.co"
# Replace with the actual Supabase anon key from your project settings
SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY_HERE"

INSTALL_DIR="/Library/TickTrust"
LOG_DIR="/Library/Logs/TickTrust"
CONFIG_DIR="/Library/Application Support/TickTrust"
LAUNCH_AGENT_DIR="/Library/LaunchAgents"
PLIST="com.ticktrust.agent.plist"

echo "==> Building TickTrustAgent..."
cd "$(dirname "$0")"
swift build -c release
BINARY=".build/release/TickTrustAgent"

echo "==> Installing binary..."
mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$CONFIG_DIR"
cp "$BINARY" "$INSTALL_DIR/TickTrustAgent"
chmod 755 "$INSTALL_DIR/TickTrustAgent"
# Only root can modify the binary
chown root:wheel "$INSTALL_DIR/TickTrustAgent"

echo "==> Writing config..."
cat > "$CONFIG_DIR/config.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>supabase_url</key>
    <string>${SUPABASE_URL}</string>
    <key>supabase_anon_key</key>
    <string>${SUPABASE_ANON_KEY}</string>
    <key>device_id</key>
    <string>${DEVICE_ID}</string>
    <key>offline_mode</key>
    <string>strict</string>
    <key>offline_grace_minutes</key>
    <integer>30</integer>
</dict>
</plist>
EOF
chmod 640 "$CONFIG_DIR/config.plist"
chown root:wheel "$CONFIG_DIR/config.plist"

echo "==> Installing LaunchAgent..."
cp "LaunchAgent/$PLIST" "$LAUNCH_AGENT_DIR/$PLIST"
chown root:wheel "$LAUNCH_AGENT_DIR/$PLIST"
chmod 644 "$LAUNCH_AGENT_DIR/$PLIST"

echo "==> Loading agent..."
launchctl unload "$LAUNCH_AGENT_DIR/$PLIST" 2>/dev/null || true
launchctl load -w "$LAUNCH_AGENT_DIR/$PLIST"

echo ""
echo "✓ TickTrust agent installed for device: $DEVICE_ID"
echo "  Logs: $LOG_DIR/agent.log"
echo "  To uninstall: sudo launchctl unload $LAUNCH_AGENT_DIR/$PLIST && sudo rm -rf $INSTALL_DIR"
