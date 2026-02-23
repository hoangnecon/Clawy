#!/usr/bin/env bash

set -e

PROXY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_LOG="$PROXY_DIR/proxy.log"

echo "======================================================"
echo "🧹 Uninstalling OpenClaw Antigravity Bridge"
echo "======================================================"

echo "[1/3] Stopping the Python Interception Proxy..."
if lsof -ti:8046 > /dev/null; then
    lsof -ti:8046 | xargs kill -9
    echo "✅ Proxy on port 8046 stopped."
else
    echo "⚠️ Proxy on port 8046 is not running."
fi

echo "[2/3] Reverting OpenClaw Config to Defaults..."
if [ -f ~/.openclaw/openclaw.json ]; then
    # Reset compaction back to safeguard
    jq '.agents.defaults.compaction = {"mode": "safeguard"}' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json
    
    # Remove the antigravity custom provider
    jq 'del(.models.providers.antigravity) | del(.models.providers.openai)' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json

    echo "✅ Removed custom providers and reset compaction."
else
    echo "⚠️ ~/.openclaw/openclaw.json not found. Skipping config modification."
fi

echo "[3/3] Restarting OpenClaw Gateway..."
openclaw gateway restart

echo "======================================================"
echo "✅ Uninstallation Complete!"
echo "Your OpenClaw instance has been reverted back to original settings."
echo "You can safely delete this repository."
echo "======================================================"
