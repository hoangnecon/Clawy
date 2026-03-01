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

(
echo import json, os
echo def update_json(path, modifier_func^):
echo     p = os.path.expanduser(path^)
echo     if not os.path.exists(p^): return
echo     with open(p, 'r', encoding='utf-8'^) as f: d = json.load(f^)
echo     modifier_func(d^)
echo     with open(p, 'w', encoding='utf-8'^) as f: json.dump(d, f, indent=2^)
echo.
echo def mod_main(d^):
echo     providers = d.get('models', {}^).get('providers', {}^)
echo     providers.pop('antigravity', None^)
echo     d.get('agents', {}^).get('defaults', {}^).pop('compaction', None^)
echo     models = d.get('agents', {}^).get('defaults', {}^).get('models', {}^)
echo     models.pop('antigravity/gemini-3-flash', None^)
echo     models.pop('antigravity/gemini-3.1-pro-high', None^)
echo     models.pop('antigravity/gemini-3.1-pro-low', None^)
echo     models.pop('antigravity/claude-opus-4-6-thinking', None^)
echo     models.pop('antigravity/claude-sonnet-4-6', None^)
echo.
echo update_json('~/.openclaw/openclaw.json', mod_main^)
echo.
echo def mod_ui(d^):
echo     d.get('providers', {}^).pop('antigravity', None^)
echo.
echo update_json('~/.openclaw/agents/main/agent/models.json', mod_ui^)
) > "%TEMP_SCRIPT%"

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
