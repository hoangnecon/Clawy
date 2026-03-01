@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo 🛑 Uninstalling OpenClaw Antigravity Bridge (Windows)
echo ======================================================

echo [1/4] Stopping Python Interception Proxy...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8046') do (
    taskkill /F /PID %%a >nul 2>&1
)

echo [2/4] Removing Custom Models from OpenClaw Registry...
set "TEMP_SCRIPT=%TEMP%\oc_uninstall.py"

echo import json, os > "%TEMP_SCRIPT%"
echo def update_json(path, modifier_func^): >> "%TEMP_SCRIPT%"
echo     p = os.path.expanduser(path^) >> "%TEMP_SCRIPT%"
echo     if not os.path.exists(p^): return >> "%TEMP_SCRIPT%"
echo     with open(p, 'r', encoding='utf-8'^) as f: d = json.load(f^) >> "%TEMP_SCRIPT%"
echo     modifier_func(d^) >> "%TEMP_SCRIPT%"
echo     with open(p, 'w', encoding='utf-8'^) as f: json.dump(d, f, indent=2^) >> "%TEMP_SCRIPT%"
echo. >> "%TEMP_SCRIPT%"
echo def mod_main(d^): >> "%TEMP_SCRIPT%"
echo     providers = d.get('models', {}^).get('providers', {}^) >> "%TEMP_SCRIPT%"
echo     providers.pop('antigravity', None^) >> "%TEMP_SCRIPT%"
echo     d.get('agents', {}^).get('defaults', {}^).pop('compaction', None^) >> "%TEMP_SCRIPT%"
echo     models = d.get('agents', {}^).get('defaults', {}^).get('models', {}^) >> "%TEMP_SCRIPT%"
echo     models.pop('antigravity/gemini-3-flash', None^) >> "%TEMP_SCRIPT%"
echo     models.pop('antigravity/gemini-3.1-pro-high', None^) >> "%TEMP_SCRIPT%"
echo     models.pop('antigravity/gemini-3.1-pro-low', None^) >> "%TEMP_SCRIPT%"
echo     models.pop('antigravity/claude-opus-4-6-thinking', None^) >> "%TEMP_SCRIPT%"
echo     models.pop('antigravity/claude-sonnet-4-6', None^) >> "%TEMP_SCRIPT%"
echo. >> "%TEMP_SCRIPT%"
echo update_json('~/.openclaw/openclaw.json', mod_main^) >> "%TEMP_SCRIPT%"
echo. >> "%TEMP_SCRIPT%"
echo def mod_ui(d^): >> "%TEMP_SCRIPT%"
echo     d.get('providers', {}^).pop('antigravity', None^) >> "%TEMP_SCRIPT%"
echo. >> "%TEMP_SCRIPT%"
echo update_json('~/.openclaw/agents/main/agent/models.json', mod_ui^) >> "%TEMP_SCRIPT%"

python "%TEMP_SCRIPT%"
del "%TEMP_SCRIPT%"

echo [3/4] Resetting Default Primary Model...
call openclaw config reset agents.defaults.model.primary

echo [4/4] Restarting Gateway...
call openclaw gateway restart

echo ======================================================
echo ✅ Uninstallation Complete.
echo OpenClaw is restored to its original state.
echo ======================================================
pause
