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
set "PYVER="

:: Strategy: prefer 'py -3.11' (Windows launcher, immune to PATH order),
:: then 'python3', then 'python'. Always verify version >= 3.11.

:: 1) py -3.11
py -3.11 --version >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_CMD=py -3.11"
    for /f "tokens=2 delims= " %%v in ('py -3.11 --version 2^>^&1') do set "PYVER=%%v"
    goto :CHECK_PYVER
)

:: 2) python3
where python3 >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2 delims= " %%v in ('python3 --version 2^>^&1') do set "PYVER=%%v"
    if not "%PYVER%"=="" (
        set "PYTHON_CMD=python3"
        goto :CHECK_PYVER
    )
)

:: 3) python
where python >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set "PYVER=%%v"
    if not "%PYVER%"=="" (
        set "PYTHON_CMD=python"
        goto :CHECK_PYVER
    )
)

:: Nothing found
goto :NO_PYTHON

:CHECK_PYVER
:: Parse major.minor from version string (e.g. "3.11.9")
for /f "tokens=1,2 delims=." %%a in ("%PYVER%") do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
)

if "%PY_MAJOR%" NEQ "3" goto :BAD_PYTHON_VER
if %PY_MINOR% LSS 11 goto :BAD_PYTHON_VER

echo         Found Python %PYVER% ^(via %PYTHON_CMD%^)
goto :CHECK_NODE

:NO_PYTHON
echo.
echo   [ERROR] Python not found.
echo   Install Python 3.11+: https://mirrors.huaweicloud.com/python/
echo   IMPORTANT: check "Add Python to PATH" during install.
pause
exit /b 1

:BAD_PYTHON_VER
echo.
echo   [ERROR] Python %PYVER% is too old (need 3.11+).
echo.
echo   You have Python 3.11+ installed? Try this in PowerShell:
echo     py -3.11 -m venv venv
echo     .\venv\Scripts\Activate.ps1
echo     pip install -i https://mirrors.aliyun.com/pypi/simple/ -r requirements.txt
echo     set DB_ENGINE=sqlite
echo     uvicorn app.main:app --host 127.0.0.1 --port 8000
echo.
echo   Then in another terminal:
echo     cd frontend
echo     set NEXT_PUBLIC_API_BASE=http://127.0.0.1:8000
echo     npm install
echo     npx next dev -p 3000
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
