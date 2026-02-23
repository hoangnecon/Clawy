# OpenClaw 🦞 🤝 Antigravity Manager 🚀

**The Ultimate Guide to Unlocking Unlimited, 128k+ Context Gemini in OpenClaw (Bypassing Developer Rate Limits & the 4096 Token Bug)**

---

## 🛑 The Problem

If you are using **OpenClaw** (or any CLI coding assistant) with Google's free developer Gemini API keys, you've likely hit a wall:
> `Error: Rate limit exceeded (15 requests per minute, 1 million tokens per day).`

If you try to upgrade your API tier or use a paid Gemini Advanced subscription, you'll realize that the official *Gemini Web UI* subscription **does not apply** to your developer API keys. 

### Enter Antigravity Manager
To bridge this gap, developers use **Antigravity Manager**—a local desktop proxy that hooks into your active, paid browser session (e.g., Gemini Advanced) and exposes it as a standard, unlimited OpenAI-compatible API running on `http://localhost:8045/v1`. 

### The OpenClaw 4096-Token Crash 💥
When you attempt to connect OpenClaw to this proxy, it crashes immediately on boot:
> `Agent failed before reply: Model context window too small (4096 tokens). Minimum is 16000.`

**Why?** OpenClaw strictly checks the model's capabilities via the `/v1/models` endpoint. Because the Antigravity Manager proxy does not return a `context_window` metadata field in its JSON payload, OpenClaw's internal discovery engine panics and falls back to a hardcoded legacy default of **4096 tokens**. 

## 🌟 The Solution: The Interception Bridge

Instead of manually recompiling OpenClaw's obfuscated JavaScript source code to change the fallback value, this repository provides a seamless **Python Interception Proxy**.

This lightweight bridge sits between OpenClaw and the Antigravity Manager. It intercepts the `/v1/models` API response, injects `"context_window": 128000` (and `"max_tokens": 8192`) on the fly, and feeds it to OpenClaw. OpenClaw happily boots, thinking it's talking to an official, massive-context OpenAI model.

---

## 🛠️ Step-by-Step Setup Guide

### Phase 1: Prep Antigravity Manager
1. Install **Antigravity Manager** on your machine.
2. Sign in to your paid Google Gemini account within the manager's browser.
3. Ensure the local proxy server is running. By default, it exposes the API at:
   `http://localhost:8045/v1`

### Phase 2: Install the Bridge

1. Clone this repository:
   ```bash
   git clone https://github.com/YOUR_GITHUB_NAME/openclaw-antigravity-bridge.git
   cd openclaw-antigravity-bridge
   ```

2. Make the installer executable:
   ```bash
   chmod +x install.sh
   ```

3. Run the automated installer:
   ```bash
   ./install.sh
   ```

### 🧠 What is `install.sh` actually doing under the hood?

If you prefer to know exactly what is happening to your system, here is the breakdown of the magic:

1. **Starts the Bridge (`proxy.py`)**: It spins up a Python background process listening on port `8046`. This script forwards all traffic to Antigravity (`8045`) but intercepts the `/models` endpoint to manually inject the 128,000 token limit.
2. **Onboards the Custom Provider**: It runs `openclaw onboard` using the `--custom-provider-id openai` flag. By masquerading as Native OpenAI (rather than a generic custom API), OpenClaw inherits robust routing logic while pointing at `http://localhost:8046/v1`. The script specifically configures `gemini-3.1-pro` as the target model.
3. **Disables Aggressive Context Pruning**: By default, OpenClaw features a "safeguard" mode that aggressively compacts (summarizes and deletes) your chat history to avoid token limits. Because you now have a massive 128k+ token window via Gemini, the script edits `~/.openclaw/openclaw.json` to disable "safeguard" and allow 90% history utilization, letting you retain deep context for massive projects.
4. **Restarts the Daemon**: Applies the new Primary Model and restarts the `openclaw gateway`.

---

## 🧪 Testing Your Setup

Once the script finishes, your CLI should reflect that the gateway is stable. Look for:
`✅ Proxy running successfully on port 8046.`

Send a massive block of code to your OpenClaw Telegram bot or CLI interface. It should process the request via the Antigravity proxy without ever triggering the 4096 context crash or prematurely summarizing your history.

## 🧰 Management & Uninstallation

**To view the bridge logs:**
```bash
tail -f proxy.log
```

**To stop the bridge:**
```bash
lsof -ti:8046 | xargs kill -9
```

**To uninstall:**
Simply stop the proxy, edit your `~/.openclaw/openclaw.json` to point back to your default provider, and delete this folder. No permanent system files are modified outside of the standard OpenClaw json configs.
