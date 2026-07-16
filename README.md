# UESTC 答辩委员会 · AI 论文答辩模拟系统

> 基于开源项目 [Offer Master](https://github.com/heatnan/offerMaster) 改造的 **AI 论文答辩模拟工具**。三位 AI 评委（研究方法、领域内容、批判性）依次用语音向你提问，你语音作答，AI 即时评分并生成答辩评价报告。

**用途**：科技论文写作课程期末答辩预演。学生在自己的电脑上部署，上传论文/PPT，AI 评委基于内容提问，模拟真实答辩场景。

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

## 环境要求

| 项目 | 最低要求 | 说明 |
|------|---------|------|
| 操作系统 | Windows 10+ / macOS 12+ / Linux | 均支持 |
| 内存 | **8 GB** 以上 | 16 GB 更佳（Whisper 模型加载需要） |
| 硬盘 | **10 GB** 空闲空间 | Docker 镜像 + Whisper 模型约 3-4 GB |
| 网络 | 能访问 `api.deepseek.com` | 用于调用大模型 API |
| 软件 | **Docker Desktop** | 必须安装 |

> **注意**：本系统在你的电脑上本地运行，语音数据不上传任何云端服务（除非你选择使用火山引擎 ASR）。麦克风采集的语音仅在本地 Whisper 引擎中转写。

---

## 第一步：安装 Docker Desktop

### Windows 用户

1. 访问 [Docker Desktop 下载页](https://www.docker.com/products/docker-desktop/)
2. 下载 Windows 版本安装程序
3. 安装时**勾选 "Use WSL 2 instead of Hyper-V"**（推荐）
4. 如果提示需要 WSL 2，先运行以下命令安装（PowerShell 管理员模式）：

   ```powershell
   wsl --install
   ```

5. 安装完成后重启电脑
6. 启动 Docker Desktop，等待右下角鲸鱼图标变绿（显示 "Engine running"）

### macOS 用户

1. 访问 [Docker Desktop 下载页](https://www.docker.com/products/docker-desktop/)
2. 选择 Apple Silicon 或 Intel 版本
3. 安装并启动

### 验证安装

打开终端（PowerShell 或 Terminal），输入：

```bash
docker --version
```

如果显示版本号（如 `Docker version 27.x.x`），说明安装成功。

---

## 第二步：获取 DeepSeek API Key

AI 评委生成问题、评分、追问都需要调用大模型，使用的是 DeepSeek 的 API（OpenAI 兼容协议）。**每人需要用自己的 API Key**，费用自理。

1. 打开 [DeepSeek 开放平台](https://platform.deepseek.com)
2. 注册账号（支持手机号注册）
3. 进入「API Keys」页面，点击「创建 API Key」
4. 复制生成的 Key（格式类似 `sk-xxxxxxxxxxxxxxxx`）
5. **首次注册赠送 ¥10 额度，足够练习数十次**

> **为什么每人用自己的 Key？**
> 每次答辩的 LLM 成本约 ¥0.2-0.5（取决于答辩时长），60 个学生每人练习 2 次 = ~¥24-60 总额。如果共用老师的 Key，一是限额容易用完，二是费用归属不清。每人用自己免费赠送的 ¥10 额度完全够用，无需额外充值。

---

## 第三步：下载并启动系统

### 3.1 下载项目

```bash
# 方式一：Git 克隆（推荐）
git clone https://github.com/camille162/uestc-defense-committee.git
cd uestc-defense-committee

# 方式二：下载 ZIP
# 在 GitHub 项目页面点击 "Code" → "Download ZIP" → 解压到本地文件夹
```

### 3.2 配置 API Key

```bash
# 复制配置文件模板
cp .env.example .env
```

用**记事本**打开 `.env` 文件，找到这一行：

```ini
OPENAI_API_KEY=在此填入你的DeepSeek_API_Key
```

把它改成：

```ini
OPENAI_API_KEY=sk-你的真实APIKey
```

> ⚠️ **不要给 API Key 加引号**，直接写 `sk-xxxxxxxx` 就行。

### 3.3 一键启动

```bash
docker compose up -d --build
```

首次启动会自动下载 Docker 镜像、安装依赖、下载 Whisper 语音识别模型（约 1.5 GB）。

**等待时间**：视网络速度，首次约 5-15 分钟。后续启动约 30 秒。

当看到类似以下输出时，说明启动成功：

```
[+] Running 4/4
 ✔ Network ... Created
 ✔ Container ... Started
 ✔ Container backend ... Started
 ✔ Container frontend ... Started
```

### 3.4 打开系统

浏览器访问：**http://localhost:3000**

看到"开始一场模拟答辩"页面，说明一切就绪。

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
- **按住说话**（push-to-talk）或**直接说**（系统会自动检测静音并提交）
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

### Q: Docker 启动后 localhost:3000 打不开？

- 确认 Docker Desktop 正在运行（任务栏鲸鱼图标为绿色）
- 等待 1-2 分钟让服务完全启动
- 在终端运行 `docker compose logs backend` 查看后端日志

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
- 修改 `.env` 后需要重启：`docker compose up -d --build backend`

### Q: 磁盘空间不足？

- 运行 `docker system prune -a` 清理未使用的镜像和容器（慎用，会删除所有 Docker 数据）
- Whisper 模型约 1.5GB 存在 Docker Volume 中

### Q: 可以切换其他大模型吗？

可以。`.env` 文件中修改：

```ini
# 例如切换到阿里云通义千问
OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
OPENAI_API_KEY=你的通义千问APIKey
LLM_MODEL=qwen-plus
```

任何兼容 OpenAI 协议的大模型 API 都可以接入。

---

## 技术架构

| 模块 | 选型 |
|------|------|
| 前端 | Next.js 14 + TypeScript + Tailwind |
| 后端 | FastAPI + SQLAlchemy |
| 数据库 | MySQL 8 |
| LLM | OpenAI 兼容协议（默认 DeepSeek） |
| STT | faster-whisper（本地） / 火山引擎 ASR（可选） |
| TTS | edge-tts（免费） / 豆包 TTS（可选） |
| 部署 | Docker Compose |

**关于多智能体**：原项目虽然安装了 `langgraph`，但实际流程由 FastAPI 按轮次驱动——第一轮调用评委 A 的 Prompt 出题，第二轮调用评委 B 的 Prompt，以此类推。三位评委不会同时对话，而是依次提问。这对于答辩模拟场景已经足够，但不是严格意义上的"多智能体委员会协同讨论"。

---

## 关于隐私

- 你的论文/PPT 文件、语音录音、回答文字等**全部数据仅存储在你的电脑上**（Docker Volume 中）
- 仅大模型 API 调用时会将论文摘要和回答文本发送至 DeepSeek 服务器（用于生成问题和评分）
- 语音数据**不离开你的电脑**（除非你手动切换为火山引擎 ASR，此时音频会发送至火山引擎服务器做转写）
- 关闭 Docker 后所有数据仍保留在本地 Volume 中
- 如需彻底清除数据，运行：

  ```bash
  docker compose down -v
  ```

---

## 鸣谢

本系统基于 [Offer Master](https://github.com/heatnan/offerMaster)（MIT License）改造，感谢原作者 heatnan 的优秀工作。

改造内容：将面试场景适配为论文答辩场景，包括修改全部 Prompt、添加 PPTX 解析支持、调整评分维度、修改前端文案等。

---

## License

MIT
