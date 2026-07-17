@echo off
setlocal enabledelayedexpansion

title UESTC Defense Committee Setup

cd /d "%~dp0"

echo.
echo   ==========================================
echo   UESTC Defense Committee - Setup
echo   No Docker required
echo   ==========================================
echo.

:: ============================================================
:: 1. Python
:: ============================================================
echo   [1/7] Checking Python...

set PYTHON_CMD=
where python >nul 2>&1
if %errorlevel% equ 0 set PYTHON_CMD=python
where python3 >nul 2>&1
if %errorlevel% equ 0 set PYTHON_CMD=python3

if "%PYTHON_CMD%"=="" (
    echo.
    echo   [ERROR] Python 3.11+ not found.
    echo.
    echo   Download: https://mirrors.huaweicloud.com/python/
    echo   IMPORTANT: Check "Add Python to PATH" during install.
    echo.
    pause
    exit /b 1
)

for /f "tokens=2 delims= " %%v in ('%PYTHON_CMD% --version 2^>^&1') do set PYVER=%%v
echo         Found Python %PYVER%

:: ============================================================
:: 2. Node.js
:: ============================================================
echo   [2/7] Checking Node.js...

where node >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   [ERROR] Node.js 20+ not found.
    echo.
    echo   Download: https://npmmirror.com/mirrors/node/
    echo.
    pause
    exit /b 1
)

for /f "tokens=1 delims=v" %%v in ('node --version 2^>^&1') do set NODEVER=%%v
echo         Found Node.js v%NODEVER%

:: ============================================================
:: 3. ffmpeg
:: ============================================================
echo   [3/7] Checking ffmpeg...

where ffmpeg >nul 2>&1
if %errorlevel% neq 0 (
    echo         ffmpeg not found, trying auto-install via winget...

    where winget >nul 2>&1
    if %errorlevel% equ 0 (
        winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements >nul 2>&1
        if %errorlevel% equ 0 (
            echo         ffmpeg installed. Please re-run setup.bat to pick up the new PATH.
            pause
            exit /b 0
        )
    )

    echo.
    echo   [WARNING] ffmpeg auto-install failed.
    echo   Voice recognition will NOT work without ffmpeg.
    echo   Manual install: https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip
    echo   Extract and add the bin folder to system PATH.
    echo.
    echo   Press any key to continue (voice recognition disabled)...
    pause >nul
) else (
    echo         Found ffmpeg
)

:: ============================================================
:: 4. .env
:: ============================================================
echo   [4/7] Checking .env config...

if not exist ".env" (
    copy .env.example .env >nul

    echo.
    echo   +---------------------------------------+
    echo   ^| .env file created.                     ^|
    echo   ^|                                       ^|
    echo   ^| 1. Fill in your DeepSeek API Key in   ^|
    echo   ^|    the opened Notepad window           ^|
    echo   ^| 2. Save and close Notepad              ^|
    echo   ^| 3. Double-click setup.bat again        ^|
    echo   +---------------------------------------+
    echo.

    start notepad .env
    pause
    exit /b 0
)

findstr /C:"YOUR_DEEPSEEK_API_KEY_HERE" .env >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   +---------------------------------------+
    echo   ^| API Key not filled in yet.             ^|
    echo   ^|                                       ^|
    echo   ^| Edit OPENAI_API_KEY in the opened      ^|
    echo   ^| Notepad window, save, then re-run      ^|
    echo   ^| setup.bat.                             ^|
    echo   +---------------------------------------+
    echo.

    start notepad .env
    pause
    exit /b 0
)

echo         Config OK

:: ============================================================
:: 5. Python deps
:: ============================================================
echo   [5/7] Installing Python dependencies (Aliyun mirror)...

cd backend

if not exist "venv" (
    %PYTHON_CMD% -m venv venv
)

call venv\Scripts\activate.bat

pip install -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -r requirements.txt
if %errorlevel% neq 0 (
    echo   [ERROR] pip install failed.
    pause
    exit /b 1
)
echo         Done

:: ============================================================
:: 6. Node deps
:: ============================================================
echo   [6/7] Installing frontend dependencies (npmmirror)...

cd ..\frontend

call npm config set registry https://registry.npmmirror.com >nul 2>&1
call npm install
if %errorlevel% neq 0 (
    echo   [ERROR] npm install failed.
    pause
    exit /b 1
)
echo         Done

:: ============================================================
:: 7. Launch
:: ============================================================
echo   [7/7] Starting services...
echo.

cd ..\backend
if not exist "data" mkdir data

start "UESTC-Backend" cmd /k "cd /d %cd% && venv\Scripts\activate.bat && set DB_ENGINE=sqlite && echo Backend starting on port 8000... && uvicorn app.main:app --host 0.0.0.0 --port 8000"

cd ..\frontend
start "UESTC-Frontend" cmd /k "cd /d %cd% && set NEXT_PUBLIC_API_BASE=http://localhost:8000 && echo Frontend starting on port 3000... && npx next dev -p 3000"

timeout /t 5 /nobreak >nul
start http://localhost:3000

echo.
echo   ==========================================
echo   Setup complete!
echo.
echo   Browser opened: http://localhost:3000
echo   If page does not load, wait 1-2 minutes
echo   (first launch downloads Whisper model).
echo.
echo   To stop: close the two terminal windows.
echo   To restart: double-click setup.bat again.
echo   ==========================================
echo.

pause
