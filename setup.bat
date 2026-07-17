@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

title UESTC 答辩委员会 - 一键启动

echo.
echo   ╔══════════════════════════════════════════════╗
echo   ║   UESTC 答辩委员会 · 一键启动（无需 Docker）   ║
echo   ╚══════════════════════════════════════════════╝
echo.

cd /d "%~dp0"

:: ============================================================
:: 1. 检查 Python
:: ============================================================
echo   [1/7] 检查 Python...

where python >nul 2>&1
if %errorlevel% neq 0 (
    where python3 >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo   [错误] 未找到 Python 3.11+
        echo.
        echo   请下载安装 Python（安装时勾选 "Add to PATH"）：
        echo   国内镜像: https://mirrors.huaweicloud.com/python/
        echo.
        echo   安装完成后重新运行本脚本。
        pause
        exit /b 1
    )
    set PYTHON_CMD=python3
) else (
    set PYTHON_CMD=python
)

for /f "tokens=2 delims= " %%v in ('!PYTHON_CMD! --version 2^>^&1') do set PYVER=%%v
echo        已找到 Python %PYVER%

:: ============================================================
:: 2. 检查 Node.js
:: ============================================================
echo   [2/7] 检查 Node.js...

where node >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   [错误] 未找到 Node.js 20+
    echo.
    echo   请下载安装 Node.js LTS：
    echo   国内镜像: https://npmmirror.com/mirrors/node/
    echo.
    echo   安装完成后重新运行本脚本。
    pause
    exit /b 1
)

for /f "tokens=1 delims=v" %%v in ('node --version 2^>^&1') do set NODEVER=%%v
echo        已找到 Node.js v%NODEVER%

:: ============================================================
:: 3. 检查/自动安装 ffmpeg
:: ============================================================
echo   [3/7] 检查 ffmpeg...

where ffmpeg >nul 2>&1
if %errorlevel% neq 0 (
    echo        未找到 ffmpeg，尝试自动安装...

    :: 方法1: winget (Win10/11 自带)
    where winget >nul 2>&1
    if %errorlevel% equ 0 (
        echo        正在通过 winget 安装 ffmpeg（约 80MB，请稍候）...
        winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements >nul 2>&1
        if %errorlevel% equ 0 (
            echo        ffmpeg 安装成功！请重新运行本脚本以使 PATH 生效。
            pause
            exit /b 0
        )
        echo        winget 安装失败（可能需要管理员权限），尝试备选方案...
    )

    :: 方法2: 下载便携版到项目目录
    echo        正在下载 ffmpeg 便携版...
    set FFMPEG_DIR=%cd%\ffmpeg
    if not exist "!FFMPEG_DIR!" mkdir "!FFMPEG_DIR!"

    :: 使用 GitHub 加速下载（选择较小的 essential 版本）
    set FFMPEG_URL=https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip
    set FFMPEG_ZIP=%TEMP%\ffmpeg_portable.zip

    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -TimeoutSec 300 } catch { exit 1 }}" >nul 2>&1

    if %errorlevel% equ 0 (
        echo        正在解压...
        powershell -Command "& {Expand-Archive -Path '%FFMPEG_ZIP%' -DestinationPath '%TEMP%\ffmpeg_extract' -Force}" >nul 2>&1
        :: ffmpeg 在 bin/ 子目录下，拷贝 exe 出来
        for /r "%TEMP%\ffmpeg_extract" %%f in (ffmpeg.exe) do copy /y "%%f" "!FFMPEG_DIR!\ffmpeg.exe" >nul 2>&1
        for /r "%TEMP%\ffmpeg_extract" %%f in (ffprobe.exe) do copy /y "%%f" "!FFMPEG_DIR!\ffprobe.exe" >nul 2>&1
        del "%FFMPEG_ZIP%" >nul 2>&1
        rmdir /s /q "%TEMP%\ffmpeg_extract" >nul 2>&1

        :: 临时加入 PATH
        set "PATH=!FFMPEG_DIR!;%PATH%"
        echo        ffmpeg 已安装到项目目录 !FFMPEG_DIR!
    ) else (
        del "%FFMPEG_ZIP%" >nul 2>&1
        echo.
        echo   [警告] ffmpeg 自动下载失败，语音识别功能将不可用。
        echo   如需语音功能，请手动下载安装：
        echo   https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip
        echo   解压后将 bin\ffmpeg.exe 所在目录加入系统 PATH。
        echo.
        echo   按任意键继续部署（仅影响语音识别）...
        pause >nul
    )
) else (
    echo        已找到 ffmpeg
)

:: ============================================================
:: 4. 创建 .env 配置文件
:: ============================================================
echo   [4/7] 准备配置文件...

if not exist ".env" (
    copy .env.example .env >nul
    echo.
    echo   ┌─────────────────────────────────────────────┐
    echo   │  .env 配置文件已创建，还需要你做一个操作：    │
    echo   │                                             │
    echo   │  把 DeepSeek API Key 填入 .env 文件           │
    echo   │  然后重新双击 setup.bat 即可启动              │
    echo   └─────────────────────────────────────────────┘
    echo.
    start notepad .env
    pause
    exit /b 0
)

findstr /C:"在此填入你的DeepSeek_API_Key" .env >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo   ┌─────────────────────────────────────────────┐
    echo   │  检测到 API Key 还没填！                      │
    echo   │  请在打开的记事本中修改 OPENAI_API_KEY 这一行  │
    echo   │  保存后关闭，重新双击 setup.bat               │
    echo   └─────────────────────────────────────────────┘
    echo.
    start notepad .env
    pause
    exit /b 0
)

echo        配置文件就绪

:: ============================================================
:: 5. 安装 Python 依赖
:: ============================================================
echo   [5/7] 安装 Python 后端依赖（阿里云镜像，首次约 1-3 分钟）...

cd backend

if not exist "venv" (
    !PYTHON_CMD! -m venv venv
    if %errorlevel% neq 0 (
        echo   [错误] 创建虚拟环境失败！请检查 Python 安装是否完整
        pause
        exit /b 1
    )
)

call venv\Scripts\activate.bat

pip install -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -r requirements.txt
if %errorlevel% neq 0 (
    echo   [错误] pip 安装失败，请检查网络连接后重试
    pause
    exit /b 1
)
echo        后端依赖安装完成

:: ============================================================
:: 6. 安装前端依赖
:: ============================================================
echo   [6/7] 安装前端依赖（npmmirror 镜像，首次约 1-2 分钟）...

cd ..\frontend

call npm config set registry https://registry.npmmirror.com >nul 2>&1
call npm install
if %errorlevel% neq 0 (
    echo   [错误] npm install 失败，请检查网络连接后重试
    pause
    exit /b 1
)
echo        前端依赖安装完成

:: ============================================================
:: 7. 启动服务
:: ============================================================
echo   [7/7] 启动服务...
echo.

cd ..\backend

:: 创建 SQLite 数据目录
if not exist "data" mkdir data

:: 启动后端
start "UESTC-答辩委员会·后端" cmd /c "cd /d %cd% && venv\Scripts\activate.bat && set DB_ENGINE=sqlite && echo 后端服务启动中(端口8000)... && uvicorn app.main:app --host 0.0.0.0 --port 8000"

cd ..\frontend

:: 启动前端
start "UESTC-答辩委员会·前端" cmd /c "cd /d %cd% && set NEXT_PUBLIC_API_BASE=http://localhost:8000 && echo 前端服务启动中(端口3000)... && npx next dev -p 3000"

:: 等待服务就绪
echo   等待服务启动（首次下载 Whisper 模型约 1.5GB，需 3-5 分钟）...
timeout /t 6 /nobreak >nul

:: 打开浏览器
start http://localhost:3000

echo.
echo   ╔══════════════════════════════════════════════════╗
echo   ║                                                  ║
echo   ║   浏览器已打开 → http://localhost:3000             ║
echo   ║                                                  ║
echo   ║   如果页面还没出来，等 1-2 分钟刷新即可             ║
echo   ║   （首次启动需要下载语音模型）                     ║
echo   ║                                                  ║
echo   ║   关闭方式：直接关掉两个命令行窗口                   ║
echo   ║   下次启动：双击 setup.bat（依赖已装好，秒开）       ║
echo   ║                                                  ║
echo   ╚══════════════════════════════════════════════════╝
echo.

pause
