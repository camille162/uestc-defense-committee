#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "  =========================================="
echo "  UESTC Defense Committee - Setup"
echo "  No Docker required"
echo "  =========================================="
echo ""

# ============================================================
# 1. Python
# ============================================================
echo "  [1/7] Checking Python..."

PYTHON_CMD=""
for cmd in python3 python; do
    if command -v "$cmd" &> /dev/null; then
        VER=$("$cmd" --version 2>&1 | awk '{print $2}')
        MAJOR=$(echo "$VER" | cut -d. -f1)
        MINOR=$(echo "$VER" | cut -d. -f2)
        if [ "$MAJOR" -ge 3 ] 2>/dev/null && [ "$MINOR" -ge 11 ] 2>/dev/null; then
            PYTHON_CMD="$cmd"
            echo "        Found Python $VER"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo ""
    echo "  [ERROR] Python 3.11+ not found."
    echo ""
    echo "  Install options:"
    echo "    macOS:        brew install python@3.11"
    echo "    Ubuntu/Debian: sudo apt install python3.11 python3.11-venv"
    echo "    Fedora:       sudo dnf install python3.11"
    echo "    Arch:         sudo pacman -S python"
    echo "    Other:        https://mirrors.huaweicloud.com/python/"
    echo ""
    exit 1
fi

# ============================================================
# 2. Node.js
# ============================================================
echo "  [2/7] Checking Node.js..."

if ! command -v node &> /dev/null; then
    echo ""
    echo "  [ERROR] Node.js 20+ not found."
    echo ""
    echo "  Install options:"
    echo "    macOS:  brew install node@20"
    echo "    Ubuntu: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt install -y nodejs"
    echo "    Other:  https://npmmirror.com/mirrors/node/"
    echo ""
    exit 1
fi
echo "        Found Node.js $(node --version)"

# ============================================================
# 3. ffmpeg
# ============================================================
echo "  [3/7] Checking ffmpeg..."

if ! command -v ffmpeg &> /dev/null; then
    echo "        ffmpeg not found, trying auto-install..."

    INSTALLED=false

    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
        echo "        Installing via Homebrew..."
        brew install ffmpeg && INSTALLED=true
    elif command -v apt &> /dev/null; then
        echo "        Installing via apt..."
        sudo apt update -qq && sudo apt install -y -qq ffmpeg && INSTALLED=true
    elif command -v dnf &> /dev/null; then
        echo "        Installing via dnf..."
        sudo dnf install -y ffmpeg-free && INSTALLED=true
    elif command -v pacman &> /dev/null; then
        echo "        Installing via pacman..."
        sudo pacman -S --noconfirm ffmpeg && INSTALLED=true
    fi

    if $INSTALLED; then
        echo "        ffmpeg installed successfully"
    else
        echo ""
        echo "  [WARNING] Could not auto-install ffmpeg."
        echo "  Voice recognition will NOT work without it."
        echo "  Install manually: https://ffmpeg.org/download.html"
        echo ""
        read -rp "  Press Enter to continue (voice recognition disabled)... "
    fi
else
    echo "        Found ffmpeg"
fi

# ============================================================
# 4. .env config
# ============================================================
echo "  [4/7] Checking .env config..."

if [ ! -f ".env" ]; then
    cp .env.example .env

    echo ""
    echo "  +---------------------------------------+"
    echo "  | .env file created.                     |"
    echo "  |                                       |"
    echo "  | 1. Edit .env and fill in your          |"
    echo "  |    DeepSeek API Key:                   |"
    echo "  |    OPENAI_API_KEY=sk-xxxxxxxx          |"
    echo "  | 2. Save the file                       |"
    echo "  | 3. Run ./setup.sh again                |"
    echo "  +---------------------------------------+"
    echo ""

    exit 0
fi

if grep -q "YOUR_DEEPSEEK_API_KEY_HERE" .env 2>/dev/null; then
    echo ""
    echo "  +---------------------------------------+"
    echo "  | API Key not filled in yet.             |"
    echo "  |                                       |"
    echo "  | Edit .env, set OPENAI_API_KEY to your  |"
    echo "  | DeepSeek API Key, save, then re-run:   |"
    echo "  |   ./setup.sh                           |"
    echo "  +---------------------------------------+"
    echo ""

    exit 0
fi

echo "        Config OK"

# ============================================================
# 5. Python deps
# ============================================================
echo "  [5/7] Installing Python dependencies (Aliyun mirror)..."

cd "$SCRIPT_DIR/backend"

if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
fi

source venv/bin/activate

pip install -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -r requirements.txt
echo "        Done"

# ============================================================
# 6. Node deps
# ============================================================
echo "  [6/7] Installing frontend dependencies (npmmirror)..."

cd "$SCRIPT_DIR/frontend"

npm config set registry https://registry.npmmirror.com 2>/dev/null || true
npm install
echo "        Done"

# ============================================================
# 7. Launch
# ============================================================
echo "  [7/7] Starting services..."
echo ""

# Kill any existing instances on the same ports
lsof -ti:8000 2>/dev/null | xargs kill -9 2>/dev/null || true
lsof -ti:3000 2>/dev/null | xargs kill -9 2>/dev/null || true

mkdir -p "$SCRIPT_DIR/backend/data"

# Backend
echo "  Starting backend on port 8000..."
cd "$SCRIPT_DIR/backend"
DB_ENGINE=sqlite nohup venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 > ../backend.log 2>&1 &

# Frontend
echo "  Starting frontend on port 3000..."
cd "$SCRIPT_DIR/frontend"
NEXT_PUBLIC_API_BASE=http://localhost:8000 nohup npx next dev -p 3000 > ../frontend.log 2>&1 &

sleep 4

# Open browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    open http://localhost:3000 2>/dev/null || true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open http://localhost:3000 2>/dev/null || true
fi

echo ""
echo "  =========================================="
echo "  Setup complete!"
echo ""
echo "  Browser opened: http://localhost:3000"
echo "  If page doesn't load, wait 1-2 minutes"
echo "  (first launch downloads Whisper model)."
echo ""
echo "  To stop:"
echo "    pkill -f 'uvicorn app.main'"
echo "    pkill -f 'next dev'"
echo "  To restart:"
echo "    ./setup.sh"
echo "  Logs: backend.log, frontend.log"
echo "  =========================================="
echo ""
