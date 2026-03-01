@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo 🚀 OpenClaw Antigravity Bridge Setup (Windows)
echo ======================================================

echo [1/4] Starting the Python Interception Proxy...
:: Kill existing proxy on port 8046
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8046') do (
    taskkill /F /PID %%a >nul 2>&1
)

:: Start proxy in background
start /B pythonw proxy.py > proxy.log 2>&1
timeout /t 2 /nobreak >nul

:: Check if port 8046 is active
netstat -aon | findstr :8046 >nul
if errorlevel 1 (
    echo ❌ Error: Failed to start the proxy on port 8046.
    echo Check the log file at proxy.log
    pause
    exit /b 1
)
echo ✅ Proxy running successfully on port 8046.

echo [2/4] Injecting Custom Models into OpenClaw Registry...
set "TEMP_SCRIPT=%TEMP%\oc_inject.py"

(
echo import json, os
echo def update_json(path, modifier_func^):
echo     p = os.path.expanduser(path^)
echo     try:
echo         with open(p, 'r', encoding='utf-8'^) as f: d = json.load(f^)
echo     except: d = {}
echo     modifier_func(d^)
echo     os.makedirs(os.path.dirname(p^), exist_ok=True^)
echo     with open(p, 'w', encoding='utf-8'^) as f: json.dump(d, f, indent=2^)
echo.
echo def mod_main(d^):
echo     models = d.setdefault('models', {}^).setdefault('providers', {}^)
echo     models['antigravity'] = {
echo         'baseUrl': 'http://localhost:8046/v1',
echo         'apiKey': 'antigravity',
echo         'api': 'openai-completions',
echo         'models': [
echo             {'id': 'gemini-3-flash', 'name': 'gemini-3-flash (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1048576, 'maxTokens': 65536},
echo             {'id': 'gemini-3.1-pro-high', 'name': 'gemini-3.1-pro-high (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1048576, 'maxTokens': 65536},
echo             {'id': 'gemini-3.1-pro-low', 'name': 'gemini-3.1-pro-low (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1048576, 'maxTokens': 65536},
echo             {'id': 'claude-opus-4-6-thinking', 'name': 'claude-opus-4-6-thinking (Antigravity)', 'reasoning': True, 'input': ['text'], 'contextWindow': 200000, 'maxTokens': 32000},
echo             {'id': 'claude-sonnet-4-6', 'name': 'claude-sonnet-4-6 (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1000000, 'maxTokens': 64000}
echo         ]
echo     }
echo     d.setdefault('agents', {}^).setdefault('defaults', {}^)['compaction'] = {'mode': 'default', 'maxHistoryShare': 0.9, 'reserveTokens': 4096, 'keepRecentTokens': 64000}
echo     m = d.setdefault('agents', {}^).setdefault('defaults', {}^).setdefault('models', {}^)
echo     m['antigravity/gemini-3-flash'] = {'alias': 'my-flash'}
echo     m['antigravity/gemini-3.1-pro-high'] = {'alias': 'my-pro-high'}
echo     m['antigravity/gemini-3.1-pro-low'] = {'alias': 'my-pro-low'}
echo     m['antigravity/claude-opus-4-6-thinking'] = {'alias': 'my-opus'}
echo     m['antigravity/claude-sonnet-4-6'] = {'alias': 'my-sonnet'}
echo.
echo update_json('~/.openclaw/openclaw.json', mod_main^)
echo.
echo def mod_ui(d^):
echo     providers = d.setdefault('providers', {}^)
echo     providers['antigravity'] = {
echo         'baseUrl': 'http://localhost:8046/v1',
echo         'apiKey': 'antigravity',
echo         'api': 'openai-completions',
echo         'models': [
echo             {'id': 'gemini-3-flash', 'name': 'gemini-3-flash (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1048576, 'maxTokens': 65536},
echo             {'id': 'gemini-3.1-pro-high', 'name': 'gemini-3.1-pro-high (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1048576, 'maxTokens': 65536},
echo             {'id': 'gemini-3.1-pro-low', 'name': 'gemini-3.1-pro-low (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1048576, 'maxTokens': 65536},
echo             {'id': 'claude-opus-4-6-thinking', 'name': 'claude-opus-4-6-thinking (Antigravity)', 'reasoning': True, 'input': ['text'], 'contextWindow': 200000, 'maxTokens': 32000},
echo             {'id': 'claude-sonnet-4-6', 'name': 'claude-sonnet-4-6 (Antigravity)', 'reasoning': False, 'input': ['text'], 'contextWindow': 1000000, 'maxTokens': 64000}
echo         ]
echo     }
echo.
echo update_json('~/.openclaw/agents/main/agent/models.json', mod_ui^)
) > "%TEMP_SCRIPT%"

python "%TEMP_SCRIPT%"
del "%TEMP_SCRIPT%"

echo [3/4] Setting Default Primary Model...
call openclaw config set agents.defaults.model.primary antigravity/claude-opus-4-6-thinking

echo [4/4] Syncing Local Agent Web UI Models and Restarting Gateway...
call openclaw gateway restart

echo ======================================================
echo 🎉 Setup Complete!
echo Your OpenClaw instance is now paired with Antigravity Manager.
echo Context Limits: Gemini 1M ^| Claude Opus 200K ^| Claude Sonnet 1M
echo Proxy logs are located in proxy.log
echo You can test it by messaging your Telegram bot.
echo ======================================================
pause
