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
    # Reset compaction back to safeguard and delete explicit model overrides
    jq '.agents.defaults.compaction = {"mode": "safeguard"} | del(.agents.defaults.models["antigravity/gemini-3.1-pro", "openai/gemini-3.1-pro"])' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json
    
    # Remove the antigravity and openai custom providers
    if [ -f ~/.openclaw/agents/main/agent/models.json ]; then
        jq 'del(.providers.antigravity) | del(.providers.openai)' ~/.openclaw/agents/main/agent/models.json > ~/.openclaw/agents/main/agent/models.json.tmp && mv ~/.openclaw/agents/main/agent/models.json.tmp ~/.openclaw/agents/main/agent/models.json
        echo "✅ Removed custom provider configurations from agent models.json."
    fi
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
