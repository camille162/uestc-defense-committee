# UESTC 答辩委员会 · AI 论文答辩模拟系统

> 基于开源项目 [Offer Master](https://github.com/heatnan/offerMaster)（MIT 协议）改造的 **AI 论文答辩模拟工具**。三位 AI 评委依次用语音向你提问，你语音作答，AI 即时评分并生成答辩评价报告。

**用途**：科技论文写作课程期末答辩预演。学生在自己电脑上部署，上传论文/PPT，AI 评委基于内容提问，模拟真实答辩场景。

---

## 🚀 国内用户 · 部署指南（无需 Docker，Windows / macOS / Linux 通用）

> 全程不需要 Docker、不需要配镜像源、不需要拉任何外网镜像。只需 Python + Node.js，脚本自动完成其余一切。

---

### 第 0 步：检查/安装 Python 和 Node.js（仅第一次需要，5-15 分钟）

**这是唯一需要你手动操作的步骤**——之后所有操作全自动。

#### 检查是否已安装

打开终端（Windows 按 `Win+R` 输入 `cmd` 回车；macOS 打开"终端"），分别输入：

```bash
python --version
node --version
```

如果两个命令都显示版本号（Python ≥ 3.11，Node ≥ v20），**跳过本节，直接看第 1 步**。

#### Windows 安装 Python

1. 打开 https://mirrors.huaweicloud.com/python/
2. 找到 **3.11.x** 最新版本，点击进入，下载 `python-3.11.x-amd64.exe`
3. 双击运行安装程序
4. ⚠️ **第一屏底部务必勾选 "Add Python to PATH"**（不勾会导致后续找不到 python 命令）
5. 点击「Install Now」，等待完成

#### Windows 安装 Node.js

1. 打开 https://npmmirror.com/mirrors/node/
2. 找到最新 **v20.x.x LTS** 版本，下载 `node-v20.x.x-x64.msi`
3. 双击运行，一路点「Next」，全部默认即可

#### macOS 安装

```bash
brew install python@3.11 node@20
```

#### Linux (Ubuntu/Debian) 安装

```bash
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs
```

---

### 第 1 步：获取 DeepSeek API Key（5 分钟，只需一次）

1. 打开 https://platform.deepseek.com
2. 用手机号注册账号
3. 登录后，左侧菜单点击「API Keys」
4. 点击「创建 API Key」，复制生成的 `sk-xxxxxxxxxxxxxxxx`
5. ⚠️ **把 Key 保存到一个你能找到的地方**（下一步要用）
6. 新用户赠送 ¥10，够练几十次

---

### 第 2 步：下载项目（1 分钟）

**方式 A（推荐）**：浏览器打开 https://github.com/camille162/uestc-defense-committee，点击绿色「Code」按钮 →「Download ZIP」→ 解压到桌面。

**方式 B**（如果装了 git）：
```bash
git clone https://github.com/camille162/uestc-defense-committee.git
```

解压后会看到一个名为 `uestc-defense-committee` 的文件夹，里面有 `setup.bat`、`setup.sh`、`README.md` 等文件。

---

### 第 3 步：首次运行 & 填写 API Key（1 分钟）

- **Windows**：双击 `setup.bat`
- **macOS / Linux**：终端进入项目目录，执行 `./setup.sh`

脚本会自动检测到你还**没填 API Key**，弹出一个窗口（Windows 是记事本，macOS 是文本编辑器）：

1. 找到 `OPENAI_API_KEY=YOUR_DEEPSEEK_API_KEY_HERE` 这一行
2. 把 `YOUR_DEEPSEEK_API_KEY_HERE` 替换成你第 1 步复制的 `sk-xxxxxxxxxxxxxxxx`
3. ⚠️ **不要加引号、不要加空格**，直接 `OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxx` 即可
4. 保存文件，关闭编辑器
5. 脚本自动退出

---

### 第 4 步：正式启动（首次 3-8 分钟，之后 10 秒）

**再次双击 `setup.bat`**（或执行 `./setup.sh`），脚本会自动：

```
[1/7] 检查 Python           → 已找到 Python 3.11.x
[2/7] 检查 Node.js           → 已找到 Node.js v20.x.x
[3/7] 检查 ffmpeg            → 已找到 / 自动安装
[4/7] 检查 .env 配置         → Config OK
[5/7] 安装 Python 依赖       → 阿里云镜像，1-2 分钟
[6/7] 安装前端依赖           → npmmirror 镜像，1-2 分钟
[7/7] 启动服务               → 后端 8000 + 前端 3000
```

浏览器自动打开 **http://localhost:3000**，看到"开始一场模拟答辩"页面即成功。

> ⚠️ **首次启动 Whisper 模型下载约 1.5 GB**，如果页面加载慢，等 1-2 分钟刷新即可。后续启动 10 秒内完成。

---

### 第 5 步：关闭 & 下次使用

- **关闭**：关掉弹出来的两个命令行窗口即可
- **下次再用**：双击 `setup.bat` → 10 秒启动 → 浏览器打开

---

### 常见问题（部署相关）

| 问题 | 解决 |
|------|------|
| 双击 `setup.bat` 闪退 | 在项目文件夹空白处按住 Shift+右键→「在此处打开 PowerShell」→ 输入 `.\setup.bat` 回车，看报错信息 |
| `python` 不是内部命令 | Python 安装时没勾"Add to PATH"→ 重新安装 Python 并勾选，或手动添加 PATH |
| `node` 不是内部命令 | 重新安装 Node.js |
| 端口 8000/3000 被占用 | 重启电脑，或手动关掉占用端口的程序 |
| 页面打开但一片空白 | 等 1 分钟刷新（Whisper 模型首次下载中） |
| Windows 用户名含中文 | 可能导致 venv 创建失败，试着手动创建一个英文路径的项目目录 |
| `OSError: cannot load library 'libgobject-2.0-0'` | Windows 缺 GTK 库，PDF 导出不可用（答辩、语音、打分不受影响）。如需 PDF 参考 https://doc.courtbouillon.org/weasyprint/stable/first_steps.html#windows |

---

## 🌍 海外用户 · Docker 部署

```bash
git clone https://github.com/camille162/uestc-defense-committee.git
cd uestc-defense-committee
cp .env.example .env
# 编辑 .env，填入 DeepSeek API Key
docker compose up -d --build
# 浏览器打开 http://localhost:3000
```

---

## 使用流程

### 1. 准备文件

将论文或答辩 PPT 导出为 PDF（推荐），或直接使用 PPTX/DOCX/TXT。

> 如果 PPT 中大量图表，建议另外准备一份纯文字版论文摘要 PDF。

### 2. 开始答辩

1. 填写论文题目
2. 填写论文方向简述（一句话或一段摘要）
3. 上传论文/PPT 文件
4. 选择评委人数：1 位 / 2 位 / **3 位（推荐）**
5. 点击「开始答辩」

### 3. 语音作答

- AI 评委会用语音提问（浏览器播放）
- 按下录音按钮说话，或系统自动检测
- 回答会被转写成文字，可以手动修改
- AI 评委可能追问，也可能推进到下一题

### 4. 查看报告

答辩结束后自动生成评价报告，包含：
- 综合评价和答辩结论
- 每位评委分项得分和评语
- 优势 Top 3 / 待改进 Top 3 / 学习建议
- 可下载 PDF 版本

---

## ⚠️ 能力边界

**能做什么：**
- ✅ 提取 PDF/PPTX/DOCX/TXT 中的文字内容，据此生成答辩提问
- ✅ 三位不同风格的 AI 评委轮流语音提问
- ✅ 语音作答（push-to-talk 模式）
- ✅ AI 根据回答内容智能追问
- ✅ 多维度打分并生成评语
- ✅ Markdown + PDF 评价报告

**不能做什么：**
- ❌ 理解图片、图表、公式、流程图（只提取文字）
- ❌ 处理扫描版 PDF（无 OCR）
- ❌ 多人并发、教师管理后台
- ❌ 完整理解超长论文（当前约前 6000 字符）

---

## 成本

| 项目 | 费用 | 谁出 |
|------|------|------|
| DeepSeek API | ~¥0.2-0.5/次 | 学生自理（新用户送 ¥10） |
| 语音识别 (Whisper) | 免费，本地运行 | — |
| 语音合成 (Edge TTS) | 免费，微软提供 | — |

---

## 技术架构

| 模块 | 选型 |
|------|------|
| 前端 | Next.js 14 + TypeScript + Tailwind |
| 后端 | FastAPI + SQLAlchemy |
| 数据库 | SQLite（国内） / MySQL 8（Docker） |
| LLM | OpenAI 兼容协议（默认 DeepSeek） |
| STT | faster-whisper（本地） |
| TTS | edge-tts（免费） |
| 部署 | setup.bat/sh 本地启动 / Docker Compose |

---

## 鸣谢 & License

基于 [heatnan/offerMaster](https://github.com/heatnan/offerMaster)（MIT）改造。主要改动：

| 模块 | 原版 → 本系统 |
|------|-------------|
| 评委角色 | HR/技术/Manager → 研究方法/领域内容/批判性 |
| 出题逻辑 | 基于简历+JD → 基于论文/PPT |
| 评分维度 | 技术/表达/深度 → 内容掌握/逻辑严密性/应对能力/学术表达 |
| 文件上传 | PDF/DOCX/TXT → PDF/PPTX/DOCX/TXT |
| 报告 | 面试评估 → 答辩评价报告 |

MIT License
