@echo off
setlocal enabledelayedexpansion
title UESTC Defense Committee - Setup
cd /d "%~dp0"

echo.
echo   ==========================================
echo   UESTC Defense Committee - Setup
echo   No Docker required
echo   ==========================================
echo.

:: ---- Python ----
echo   [1/7] Checking Python...
set "PYTHON_CMD="

where python >nul 2>&1
if not errorlevel 1 set "PYTHON_CMD=python"

where python3 >nul 2>&1
if not errorlevel 1 set "PYTHON_CMD=python3"

if not defined PYTHON_CMD goto :NO_PYTHON

for /f "tokens=2" %%v in ('%PYTHON_CMD% --version 2^>^&1') do echo         Found Python %%v
goto :CHECK_NODE

:NO_PYTHON
echo.
echo   [ERROR] Python 3.11+ not found.
echo   Download: https://mirrors.huaweicloud.com/python/
echo   IMPORTANT: check "Add Python to PATH" during install.
pause
exit /b 1

:: ---- Node.js ----
:CHECK_NODE
echo   [2/7] Checking Node.js...
where node >nul 2>&1
if errorlevel 1 goto :NO_NODE

for /f "delims=v" %%v in ('node --version 2^>^&1') do echo         Found Node.js v%%v
goto :CHECK_FFMPEG

:NO_NODE
echo.
echo   [ERROR] Node.js 20+ not found.
echo   Download: https://npmmirror.com/mirrors/node/
pause
exit /b 1

:: ---- ffmpeg ----
:CHECK_FFMPEG
echo   [3/7] Checking ffmpeg...
where ffmpeg >nul 2>&1
if not errorlevel 1 (
    echo         Found ffmpeg
    goto :CHECK_ENV
)

echo         ffmpeg not found, trying winget...
where winget >nul 2>&1
if not errorlevel 1 (
    winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements >nul 2>&1
    if not errorlevel 1 (
        echo         ffmpeg installed - please re-run setup.bat
        pause
        exit /b 0
    )
)

echo.
echo   [WARNING] ffmpeg auto-install failed.
echo   Voice recognition will NOT work without ffmpeg.
echo   Manual install: https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip
echo.
pause

:: ---- .env ----
:CHECK_ENV
echo   [4/7] Checking .env config...
if exist ".env" goto :CHECK_APIKEY

copy .env.example .env >nul
echo.
echo   +---------------------------------------+
echo   ^| .env file created.                     ^|
echo   ^| 1. Fill in your DeepSeek API Key in   ^|
echo   ^|    the opened Notepad window           ^|
echo   ^| 2. Save and close Notepad              ^|
echo   ^| 3. Double-click setup.bat again        ^|
echo   +---------------------------------------+
start notepad .env
pause
exit /b 0

:CHECK_APIKEY
findstr /C:"YOUR_DEEPSEEK_API_KEY_HERE" .env >nul 2>&1
if errorlevel 1 goto :INSTALL_PYTHON

echo.
echo   +---------------------------------------+
echo   ^| API Key not filled in yet.             ^|
echo   ^| Edit OPENAI_API_KEY in the opened      ^|
echo   ^| Notepad window, save, then re-run      ^|
echo   ^| setup.bat.                             ^|
echo   +---------------------------------------+
start notepad .env
pause
exit /b 0

:: ---- Python deps ----
:INSTALL_PYTHON
echo   [5/7] Installing Python dependencies (Aliyun mirror)...
cd backend
if not exist "venv" %PYTHON_CMD% -m venv venv
call venv\Scripts\activate.bat
pip install -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -r requirements.txt
if errorlevel 1 goto :PIP_FAIL
echo         Done
goto :INSTALL_NODE

:PIP_FAIL
echo   [ERROR] pip install failed - check your network.
pause
exit /b 1

:: ---- Node deps ----
:INSTALL_NODE
echo   [6/7] Installing frontend dependencies (npmmirror)...
cd ..\frontend
call npm config set registry https://registry.npmmirror.com >nul 2>&1
call npm install
if errorlevel 1 goto :NPM_FAIL
echo         Done
goto :LAUNCH

:NPM_FAIL
echo   [ERROR] npm install failed - check your network.
pause
exit /b 1

:: ---- Launch ----
:LAUNCH
echo   [7/7] Starting services...
cd ..\backend
if not exist "data" mkdir data

:: Kill any process holding port 8000 or 3000 from a previous run
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8000 " 2^>nul') do taskkill /F /PID %%a >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3000 " 2^>nul') do taskkill /F /PID %%a >nul 2>&1

start "UESTC-Backend" cmd /k "cd /d %cd% && venv\Scripts\activate.bat && set DB_ENGINE=sqlite && echo Backend http://127.0.0.1:8000 && uvicorn app.main:app --host 127.0.0.1 --port 8000"

cd ..\frontend
start "UESTC-Frontend" cmd /k "cd /d %cd% && set NEXT_PUBLIC_API_BASE=http://127.0.0.1:8000 && echo Frontend http://localhost:3000 && npx next dev -p 3000"

timeout /t 5 /nobreak >nul
start http://localhost:3000

echo.
echo   ==========================================
echo   Setup complete.
echo   Browser: http://localhost:3000
echo   First launch downloads Whisper ~1.5GB.
echo   Close the two terminal windows to stop.
echo   ==========================================
pause
