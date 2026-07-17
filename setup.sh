#!/usr/bin/env bash
set -e

# ╔══════════════════════════════════════════════╗
# ║  UESTC 答辩委员会 · 一键启动（无需 Docker）     ║
# ╚══════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   UESTC 答辩委员会 · 一键启动（无需 Docker）   ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# ============================================================
# 1. Check Python
# ============================================================
echo "  [1/7] 检查 Python..."

PYTHON_CMD=""
for cmd in python3 python; do
    if command -v "$cmd" &> /dev/null; then
        VER=$("$cmd" --version 2>&1 | awk '{print $2}')
        MAJOR=$(echo "$VER" | cut -d. -f1)
        MINOR=$(echo "$VER" | cut -d. -f2)
        if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 11 ] 2>/dev/null; then
            PYTHON_CMD="$cmd"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo -e "  ${RED}[错误] 未找到 Python 3.11+${NC}"
    echo "  macOS:  brew install python@3.11"
    echo "  Ubuntu: sudo apt install python3.11 python3.11-venv"
    exit 1
fi
echo "        已找到 Python $($PYTHON_CMD --version 2>&1 | awk '{print $2}')"

# ============================================================
# 2. Check Node.js
# ============================================================
echo "  [2/7] 检查 Node.js..."

if ! command -v node &> /dev/null; then
    echo -e "  ${RED}[错误] 未找到 Node.js${NC}"
    echo "  macOS:  brew install node@20"
    echo "  Ubuntu: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt install nodejs"
    echo "  国内镜像: https://npmmirror.com/mirrors/node/"
    exit 1
fi
echo "        已找到 Node.js $(node --version)"

# ============================================================
# 3. Check / auto-install ffmpeg
# ============================================================
echo "  [3/7] 检查 ffmpeg..."

if ! command -v ffmpeg &> /dev/null; then
    echo "        未找到 ffmpeg，尝试自动安装..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use brew
        if command -v brew &> /dev/null; then
            echo "        正在通过 Homebrew 安装 ffmpeg..."
            brew install ffmpeg
            echo -e "        ${GREEN}ffmpeg 安装成功${NC}"
        else
            echo -e "        ${YELLOW}[警告] 未找到 Homebrew，跳过 ffmpeg 安装${NC}"
            echo "        如需语音功能，请先安装 Homebrew: https://brew.sh"
            echo "        然后运行: brew install ffmpeg"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux: use apt
        if command -v apt &> /dev/null; then
            echo "        正在通过 apt 安装 ffmpeg..."
            sudo apt update -qq && sudo apt install -y -qq ffmpeg
            echo -e "        ${GREEN}ffmpeg 安装成功${NC}"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y ffmpeg
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm ffmpeg
        else
            echo -e "        ${YELLOW}[警告] 无法自动安装 ffmpeg，语音识别功能将不可用${NC}"
        fi
    fi
else
    echo "        已找到 ffmpeg"
fi

# ============================================================
# 4. Create .env if needed
# ============================================================
echo "  [4/7] 准备配置文件..."

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo ""
    echo "  ┌─────────────────────────────────────────────┐"
    echo "  │  .env 配置文件已创建                           │"
    echo "  │  请编辑填入 DeepSeek API Key 后重新运行:         │"
    echo "  │  nano .env   (或任意文本编辑器)                 │"
    echo "  │  改完后重新运行: ./setup.sh                    │"
    echo "  └─────────────────────────────────────────────┘"
    echo ""
    exit 0
fi

if grep -q "在此填入你的DeepSeek_API_Key" .env 2>/dev/null; then
    echo ""
    echo "  ┌─────────────────────────────────────────────┐"
    echo "  │  检测到 API Key 还没填！                       │"
    echo "  │  请编辑 .env 文件，修改 OPENAI_API_KEY 这一行   │"
    echo "  │  nano .env                                   │"
    echo "  │  改完后重新运行: ./setup.sh                    │"
    echo "  └─────────────────────────────────────────────┘"
    echo ""
    exit 0
fi

echo "        配置文件就绪"

# ============================================================
# 5. Install Python deps
# ============================================================
echo "  [5/7] 安装 Python 后端依赖（阿里云镜像，首次约 1-3 分钟）..."

cd "$SCRIPT_DIR/backend"

if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
fi

source venv/bin/activate

pip install -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -r requirements.txt
echo "        后端依赖安装完成"

# ============================================================
# 6. Install Node deps
# ============================================================
echo "  [6/7] 安装前端依赖（npmmirror 镜像，首次约 1-2 分钟）..."

cd "$SCRIPT_DIR/frontend"

npm config set registry https://registry.npmmirror.com 2>/dev/null || true
npm install
echo "        前端依赖安装完成"

# ============================================================
# 7. Launch
# ============================================================
echo "  [7/7] 启动服务..."
echo ""

# Create data dir for SQLite
mkdir -p "$SCRIPT_DIR/backend/data"

# Backend (background)
echo "  启动后端服务 (端口 8000)..."
cd "$SCRIPT_DIR/backend"
DB_ENGINE=sqlite nohup venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 > ../backend.log 2>&1 &
BACKEND_PID=$!

# Frontend
echo "  启动前端服务 (端口 3000)..."
cd "$SCRIPT_DIR/frontend"
NEXT_PUBLIC_API_BASE=http://localhost:8000 nohup npx next dev -p 3000 > ../frontend.log 2>&1 &
FRONTEND_PID=$!

# Wait
echo "  等待服务启动（首次下载 Whisper 模型约 1.5GB，需 3-5 分钟）..."
sleep 5

# Open browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    open http://localhost:3000
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open http://localhost:3000 &> /dev/null || true
fi

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║                                                  ║"
echo "  ║   浏览器已打开 → http://localhost:3000             ║"
echo "  ║                                                  ║"
echo "  ║   如果页面还没出来，等 1-2 分钟刷新即可             ║"
echo "  ║   （首次启动需要下载语音模型）                     ║"
echo "  ║                                                  ║"
echo "  ║   关闭方式:                                       ║"
echo "  ║     kill $BACKEND_PID $FRONTEND_PID              ║"
echo "  ║   下次启动: ./setup.sh（依赖已装好，秒开）          ║"
echo "  ║   后端日志: backend.log                           ║"
echo "  ║   前端日志: frontend.log                          ║"
echo "  ║                                                  ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
