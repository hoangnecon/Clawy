#!/usr/bin/env bash

set -e

PROXY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_LOG="$PROXY_DIR/proxy.log"

echo "======================================================"
echo "🚀 OpenClaw Antigravity Bridge Setup"
echo "======================================================"

echo "[1/4] Starting the Python Interception Proxy..."
# Kill existing proxy if running on 8046
lsof -ti:8046 | xargs kill -9 2>/dev/null || true

nohup python3 "$PROXY_DIR/proxy.py" > "$PROXY_LOG" 2>&1 &
sleep 2

if ! curl -s http://localhost:8046/v1/models > /dev/null; then
    echo "❌ Error: Failed to start the proxy on port 8046."
    echo "Check the log file at $PROXY_LOG for details."
    exit 1
fi
echo "✅ Proxy running successfully on port 8046."

echo "[2/4] Onboarding Custom OpenAI Provider in OpenClaw..."
# We use the 'antigravity' provider ID
openclaw onboard --auth-choice custom-api-key \
    --custom-api-key antigravity \
    --custom-base-url http://localhost:8046/v1 \
    --custom-provider-id antigravity \
    --custom-model-id gemini-3.1-pro \
    --non-interactive \
    --accept-risk \
    --skip-channels \
    --skip-daemon \
    --skip-health \
    --skip-skills \
    --skip-ui

echo "[3/4] Optimizing Context Compaction for Deep Context..."
# Modify OpenClaw config to maximize context usage and disable aggressive pruning
jq '.agents.defaults.compaction = {"mode": "default", "maxHistoryShare": 0.9, "reserveTokens": 4096, "keepRecentTokens": 64000}' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json

# Hard-patch the models config to 128000 context because OpenClaw auto-discovery fails on unrecognized config providers
jq '(.models.providers.antigravity.models[] | select(.id=="gemini-3.1-pro")).contextWindow = 128000 | (.models.providers.antigravity.models[] | select(.id=="gemini-3.1-pro")).maxTokens = 8192' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json

echo "[4/4] Setting Default Primary Model and Restarting Gateway..."
openclaw config set agents.defaults.model.primary antigravity/gemini-3.1-pro
openclaw gateway restart

echo "======================================================"
echo "🎉 Setup Complete!"
echo "Your OpenClaw instance is now paired with Antigravity Manager."
echo "Context Limit: 128,000 tokens"
echo "Proxy logs are located at: $PROXY_LOG"
echo "You can test it by messaging your Telegram bot."
echo "======================================================"
