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

echo "[2/4] Injecting Custom Models into OpenClaw Registry..."

# Natively inject the Antigravity provider and all 5 requested models with 128k context limits
jq '
  .models.providers.antigravity = {
    "baseUrl": "http://localhost:8046/v1",
    "apiKey": "antigravity",
    "api": "openai-completions",
    "models": [
      {
        "id": "gemini-3-flash",
        "name": "gemini-3-flash (Antigravity)",
        "reasoning": false,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": 1048576,
        "maxTokens": 65536
      },
      {
        "id": "gemini-3.1-pro-high",
        "name": "gemini-3.1-pro-high (Antigravity)",
        "reasoning": false,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": 1048576,
        "maxTokens": 65536
      },
      {
        "id": "gemini-3.1-pro-low",
        "name": "gemini-3.1-pro-low (Antigravity)",
        "reasoning": false,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": 1048576,
        "maxTokens": 65536
      },
      {
        "id": "claude-opus-4-6-thinking",
        "name": "claude-opus-4-6-thinking (Antigravity)",
        "reasoning": true,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": 200000,
        "maxTokens": 32000
      },
      {
        "id": "claude-sonnet-4-6",
        "name": "claude-sonnet-4-6 (Antigravity)",
        "reasoning": false,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": 1000000,
        "maxTokens": 64000
      }
    ]
  }
' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json

echo "[3/5] Optimizing Context Compaction for Deep Context..."
# Modify OpenClaw config to maximize context usage and disable aggressive pruning
jq '.agents.defaults.compaction = {"mode": "default", "maxHistoryShare": 0.9, "reserveTokens": 4096, "keepRecentTokens": 64000}' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json

echo "[4/5] Registering Model Aliases for /model Switcher..."
# Inject alias entries into agents.defaults.models so the /model command can list all 5 models
jq '
  .agents.defaults.models["antigravity/gemini-3-flash"]           = {"alias": "my-flash"} |
  .agents.defaults.models["antigravity/gemini-3.1-pro-high"]      = {"alias": "my-pro-high"} |
  .agents.defaults.models["antigravity/gemini-3.1-pro-low"]       = {"alias": "my-pro-low"} |
  .agents.defaults.models["antigravity/claude-opus-4-6-thinking"] = {"alias": "my-opus"} |
  .agents.defaults.models["antigravity/claude-sonnet-4-6"]        = {"alias": "my-sonnet"}
' ~/.openclaw/openclaw.json > ~/.openclaw/openclaw.json.tmp && mv ~/.openclaw/openclaw.json.tmp ~/.openclaw/openclaw.json

echo "[5/6] Setting Default Primary Model..."
openclaw config set agents.defaults.model.primary antigravity/claude-opus-4-6-thinking

echo "[6/6] Syncing Local Agent Web UI Models and Restarting Gateway..."
mkdir -p ~/.openclaw/agents/main/agent
cat << 'EOF' > ~/.openclaw/agents/main/agent/models.json
{
  "providers": {
    "antigravity": {
      "baseUrl": "http://localhost:8046/v1",
      "apiKey": "antigravity",
      "api": "openai-completions",
      "models": [
        {
          "id": "gemini-3-flash",
          "name": "gemini-3-flash (Antigravity)",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 1048576,
          "maxTokens": 65536
        },
        {
          "id": "gemini-3.1-pro-high",
          "name": "gemini-3.1-pro-high (Antigravity)",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 1048576,
          "maxTokens": 65536
        },
        {
          "id": "gemini-3.1-pro-low",
          "name": "gemini-3.1-pro-low (Antigravity)",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 1048576,
          "maxTokens": 65536
        },
        {
          "id": "claude-opus-4-6-thinking",
          "name": "claude-opus-4-6-thinking (Antigravity)",
          "reasoning": true,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 200000,
          "maxTokens": 32000
        },
        {
          "id": "claude-sonnet-4-6",
          "name": "claude-sonnet-4-6 (Antigravity)",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 1000000,
          "maxTokens": 64000
        }
      ]
    }
  }
}
EOF

openclaw gateway restart

echo "======================================================"
echo "🎉 Setup Complete!"
echo "Your OpenClaw instance is now paired with Antigravity Manager."
echo "Context Limits: Gemini 1M | Claude Opus 200K | Claude Sonnet 1M"
echo "Proxy logs are located at: $PROXY_LOG"
echo "You can test it by messaging your Telegram bot."
echo "======================================================"
