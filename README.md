# UESTC 答辩委员会 · AI 论文答辩模拟系统

> 基于开源项目 [Offer Master](https://github.com/heatnan/offerMaster) 改造的 **AI 论文答辩模拟工具**。三位 AI 评委（研究方法、领域内容、批判性）依次用语音向你提问，你语音作答，AI 即时评分并生成答辩评价报告。

**用途**：科技论文写作课程期末答辩预演。学生在自己的电脑上部署，上传论文/PPT，AI 评委基于内容提问，模拟真实答辩场景。

---

## 🚀 国内用户 · 快速开始（推荐，无需 Docker）

> ⚠️ 由于国内网络环境限制，Docker Hub 镜像拉取经常失败。**强烈推荐国内用户使用本地部署方式**，无需安装 Docker，只需 Python + Node.js。

### 环境要求

| 项目 | 最低要求 | 说明 |
|------|---------|------|
| 操作系统 | Windows 10+ / macOS 12+ / Linux | 均支持 |
| **Python** | **3.11+** | [华为云镜像下载](https://mirrors.huaweicloud.com/python/)（Windows） |
| **Node.js** | **20 LTS** | [npmmirror 镜像下载](https://npmmirror.com/mirrors/node/) |
| **ffmpeg** | 任意版本 | 语音识别需要（缺失不影响启动，仅影响语音功能） |
| 内存 | **8 GB** 以上 | 16 GB 更佳（Whisper 模型加载需要） |
| 硬盘 | **5 GB** 空闲空间 | Whisper 模型首次自动下载约 1.5 GB |
| 网络 | 能访问 `api.deepseek.com` | 用于调用大模型 API |

### 三步启动

#### 第一步：获取 DeepSeek API Key

1. 打开 [DeepSeek 开放平台](https://platform.deepseek.com)
2. 注册账号（支持手机号）
3. 进入「API Keys」页面，点击「创建 API Key」
4. 复制 Key（格式：`sk-xxxxxxxxxxxxxxxx`）
5. **新用户赠送 ¥10 额度，足够练习数十次**

#### 第二步：下载项目

```bash
git clone https://github.com/camille162/uestc-defense-committee.git
cd uestc-defense-committee
```

> 如果 GitHub 打不开，可以在项目页面点击「Code」→「Download ZIP」下载压缩包解压。

#### 第三步：一键启动

- **Windows**：双击 `setup.bat`
- **macOS / Linux**：终端执行 `./setup.sh`

首次运行会自动检查环境、安装依赖、启动服务。浏览器会自动打开 **http://localhost:3000**。

> 首次启动时脚本会检测到你还没填 API Key，自动创建 `.env` 文件并用记事本打开。填入 Key、保存后，重新双击 `setup.bat` 即可。

---

## 🌍 海外用户 · Docker 部署

### 环境要求

| 项目 | 最低要求 | 说明 |
|------|---------|------|
| 操作系统 | Windows 10+ / macOS 12+ / Linux | 均支持 |
| 内存 | **8 GB** 以上 | 16 GB 更佳 |
| 硬盘 | **10 GB** 空闲空间 | Docker 镜像 + Whisper 模型约 3-4 GB |
| 软件 | **Docker Desktop** | 必须安装 |

### 第一步：安装 Docker Desktop

- [Docker Desktop 下载页](https://www.docker.com/products/docker-desktop/)
- Windows 安装时勾选「Use WSL 2 instead of Hyper-V」
- 安装完成后确保任务栏 Docker 图标为绿色

验证：

```bash
docker --version
```

### 第二步：获取 DeepSeek API Key

同上。

### 第三步：下载并启动

```bash
git clone https://github.com/camille162/uestc-defense-committee.git
cd uestc-defense-committee
cp .env.example .env
```

编辑 `.env` 文件，填入 API Key，然后：

```bash
docker compose up -d --build
```

浏览器访问 **http://localhost:3000**。

---

---

## 使用流程

### 1. 准备文件

将你的论文或答辩 PPT 导出为 PDF（推荐），或者直接使用 PPTX/DOCX/TXT 格式。

> **提示**：如果 PPT 中有大量图表、截图，建议另外准备一份纯文字版的论文摘要 PDF，方便 AI 提取完整内容。

### 2. 开始答辩

1. 填写**论文题目**
2. 填写**论文方向简述**（一句话或一段摘要即可）
3. 上传**论文/PPT 文件**
4. 选择**评委人数**：
   - 1 位（研究方法评委）
   - 2 位（研究方法 + 领域内容）
   - 3 位（研究方法 + 领域内容 + 批判性）← **推荐**
5. 点击「开始答辩」

### 3. 语音作答

- AI 评委会先用语音向你提问（浏览器播放）
- 听到问题后，点击页面按钮或等待自动开始录音
- **按住说话**（push-to-talk）或**直接说**（系统自动检测静音并提交）
- 说完后可以手动点击「立即提交」，或等系统自动检测并提交
- 你的回答会被转写成文字显示在页面上，可以手动修改订正
- AI 评委可能追问，也可能推进到下一题

### 4. 查看报告

所有评委提问结束后，系统自动生成答辩评价报告，包含：

- 综合评价和答辩结论
- 每位评委的得分和评语
- 每题得分和详细点评
- 优势 (Top 3) / 待改进 (Top 3) / 学习建议
- 可下载 PDF 版本

---

## ⚠️ 能力边界（请先阅读）

**本系统能做什么：**

- ✅ 提取 PDF/PPTX/DOCX/TXT 中的**文字内容**，据此生成答辩提问
- ✅ 三位不同风格的 AI 评委轮流语音提问
- ✅ 学生语音作答（push-to-talk 模式）
- ✅ AI 根据回答内容智能追问
- ✅ 多维度打分并生成文字评语
- ✅ 答辩结束后输出 Markdown + PDF 评价报告

**本系统不能做什么：**

- ❌ 理解 PPT 中的图片、图表、曲线、公式、SmartArt、流程图（只提取文字）
- ❌ 处理扫描版 PDF（需要 OCR，本系统不含 OCR 能力）
- ❌ 支持多人并发（每人本地运行一个实例，天然隔离）
- ❌ 支持教师管理后台（无用户系统、无学号绑定）
- ❌ 完整理解超长论文（当前仅使用论文前约 6000 字符生成问题）

**建议**：如果你希望 AI 提问覆盖论文的全部章节，可将论文按章节拆分为多个文件分批上传，或者准备一份包含全文核心内容的摘要版 PDF。

---

## 成本说明

| 项目 | 费用 | 承担方 |
|------|------|-------|
| DeepSeek API | 单次答辩约 ¥0.20-0.50 | **学生自理**（新用户赠送 ¥10 额度） |
| 语音识别 (Whisper) | 免费，本地运行 | — |
| 语音合成 (Edge TTS) | 免费，微软提供 | — |
| Docker Desktop | 免费（个人使用） | — |

**成本分摊建议**：

每位学生注册自己的 DeepSeek 账号，首次赠送的 ¥10 额度足够完整练习 20-40 次。如果额度用完，DeepSeek 最低充值金额为 ¥1，按次计费，无需月租。一场答辩（3 位评委 × 5-8 题/人，约 30-60 分钟）的 LLM 调用量约 15,000-30,000 tokens，按当前 DeepSeek 价格折算约 ¥0.20-0.50。

---

## 常见问题

### Q: 启动后 localhost:3000 打不开？

- 等待几秒让服务完全启动
- 检查是否有杀毒软件/防火墙拦截
- 本地部署：查看 `backend/` 目录下的终端窗口是否报错
- Docker 部署：运行 `docker compose logs backend` 查看后端日志

### Q: 上传 PPT 后生成的问题不相关？

- 确认 PPT 的文本框中有足够文字（纯图片 PPT 无法提取内容）
- 建议将 PPT 导出为 PDF 再上传
- 如果论文很长，AI 只看到前 6000 字符，可能导致漏掉后文内容

### Q: 语音识别不准确？

- 默认使用本地 Whisper Medium 模型，中文口语识别有约 10-20% 错误率
- 可以在提交前手动修改转写文字
- 如果追求更高准确率，可以切换到火山引擎流式 ASR（见 `.env.example` 中的说明）

### Q: 答辩过程中浏览器崩溃了？

- 重新打开 http://localhost:3000，进入之前的答辩 ID
- 已提交的回答和评分会保留
- 也可以重新开始一场新的答辩

### Q: DeepSeek API Key 失效？

- 检查 `.env` 文件中的 Key 是否正确
- 登录 [platform.deepseek.com](https://platform.deepseek.com) 查看 Key 状态和余额
- 修改 `.env` 后需要重启服务（本地：关闭窗口重开；Docker：`docker compose up -d --build backend`）

### Q: 可以切换其他大模型吗？

可以。`.env` 文件中修改：

```ini
# 例如切换到阿里云通义千问
OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
OPENAI_API_KEY=你的通义千问APIKey
LLM_MODEL=qwen-plus
```

任何兼容 OpenAI 协议的大模型 API 都可以接入。

### Q: 数据库数据在哪？

- **本地部署 (SQLite)**：`backend/data/committee.db`
- **Docker 部署 (SQLite)**：Docker Volume `sqlite_data` 中
- **Docker 部署 (MySQL)**：Docker Volume `mysql_data` 中

### Q: 如何彻底清除数据重新开始？

- 本地部署：删除 `backend/data/committee.db`
- Docker + SQLite：`docker compose down -v`（会清除所有数据）
- Docker + MySQL：`docker compose down -v`

### Q: 不想用本地部署了，怎么切回 Docker？

```bash
# 编辑 .env，将 DB_ENGINE 改回 mysql
# 然后
docker compose up -d --build
```

---

## 技术架构

| 模块 | 选型 |
|------|------|
| 前端 | Next.js 14 + TypeScript + Tailwind |
| 后端 | FastAPI + SQLAlchemy |
| 数据库 | MySQL 8（海外 Docker） / SQLite（国内本地部署） |
| LLM | OpenAI 兼容协议（默认 DeepSeek） |
| STT | faster-whisper（本地） / 火山引擎 ASR（可选） |
| TTS | edge-tts（免费） / 豆包 TTS（可选） |
| 部署 | Docker Compose / 本地 Python + Node.js |

**关于多智能体**：原项目虽然安装了 `langgraph`，但实际流程由 FastAPI 按轮次驱动——第一轮调用评委 A 的 Prompt 出题，第二轮调用评委 B 的 Prompt，以此类推。三位评委不会同时对话，而是依次提问。这对于答辩模拟场景已经足够，但不是严格意义上的"多智能体委员会协同讨论"。

---

## 项目来源

本项目基于 [heatnan/offerMaster](https://github.com/heatnan/offerMaster)（MIT 协议）进行二次开发。原项目是一个 AI 模拟面试系统，我们将面试场景适配为论文答辩场景。

**主要改动**：

| 模块 | 原版（Offer Master） | 改造后（本系统） |
|------|---------------------|-----------------|
| 评委角色 | 一面 Peer / 二面 High Peer / 三面 Manager | 研究方法评委 / 领域内容评委 / 批判性评委 |
| 出题逻辑 | 基于简历+JD 生成技术面试题 | 基于论文/PPT 内容生成答辩问题 |
| 评分维度 | 技术准确性 / 表达 / 深度 | 内容掌握度 / 逻辑严密性 / 应对能力 / 学术表达 |
| 开场 | 自我介绍 | 论文概述 |
| 文件上传 | PDF / DOCX / TXT | PDF / PPTX / DOCX / TXT |
| 报告 | 面评报告（推荐 offer 等） | 答辩评价报告（推荐通过 / 有条件通过等） |

---

## 关于隐私

- 你的论文/PPT 文件、语音录音、回答文字等**全部数据仅存储在你的电脑上**（本地文件或 Docker Volume 中）
- 仅大模型 API 调用时会将论文摘要和回答文本发送至 DeepSeek 服务器（用于生成问题和评分）
- 语音数据**不离开你的电脑**（除非你手动切换为火山引擎 ASR，此时音频会发送至火山引擎服务器做转写）
- 如需彻底清除数据：
  - 本地部署：删除 `backend/data/` 目录
  - Docker 部署：`docker compose down -v`

---

## 鸣谢

本系统基于 [Offer Master](https://github.com/heatnan/offerMaster)（MIT License）改造，感谢原作者 heatnan 的优秀工作。

改造内容：将面试场景适配为论文答辩场景，包括修改全部 Prompt、添加 PPTX 解析支持、调整评分维度、修改前端文案等。

---

## License

MIT
