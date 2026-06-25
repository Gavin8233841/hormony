# 鸿蒙 AI 学习/校园助理 Agent

> 2026 中国高校计算机大赛-人工智能创意赛（C4-AI）· 鸿蒙高校创新赛 · Agent 创新方向参赛作品
>
> 项目路径：`C:\Users\guo82\Desktop\Hormony`

---

## 竞赛信息摘要（供 AI 协作工具快速理解上下文）

| 项目 | 内容 |
|------|------|
| 赛事全称 | 2026 中国高校计算机大赛-人工智能创意赛（C4-AI） |
| 赛道 | 鸿蒙高校创新赛 |
| 作品方向 | Agent 创新 |
| 主办 | 全国高等学校计算机教育研究会 |
| 承办 | 华为公司 + 浙江大学 |
| 官方页面 | https://developer.huawei.com/consumer/cn/activity/incentive/C4 |
| 总入口 | https://developer.huaweicloud.com/c4ai.html |
| 官方邮箱 | AiContest@huawei.com |

### 关键规则

- **FAQ 第 13 条：Agent 创新方向不限制模型 API 的使用**，可自由选择市场可用 AI 工具及模型 API
- 面向中国内地及港澳台地区高校在校生（专科/本科/硕士/博士），不限专业
- 每队不超过 3 人，可跨学校跨专业，须有一名指导老师（队长所属高校正式教师）
- 开放式命题，鼓励基于 HarmonyOS 技术创新开发
- 截止前可多次更新作品（至多 10 次），晋级后只能基于原作品迭代
- 大赛不提供硬件设备，可使用模拟器/云测试
- 提交入口：官方页面 → 华为 OAuth → 黄大年茶思屋平台
- 官方附件已下载至项目根目录（2 个 PDF），需登录后核对最新规则

### 官方附件（已下载）

- `2026"中国高校计算机大赛―人工智能创意赛"鸿蒙高校创新赛竞赛规程.pdf`
- `2026"中国高校计算机大赛―人工智能创意赛"鸿蒙赛道报名手册.pdf`

> 仍需登录茶思屋平台下载：作品说明文档（第三个附件）

---

## 作品概念

一个运行在 HarmonyOS 上的校园学习智能体应用，支持学生围绕课程资料、学习计划、作业任务、考试复习、校园事务进行多智能体协作。

### 核心功能模块

- 课程资料问答（RAG 知识库检索）
- 学习计划生成与任务拆解
- 作业思路辅导
- 测验题生成与错题分析
- 个性化学习画像
- 内容安全审核与反幻觉机制

### 多 Agent 架构

```
用户输入 → Orchestrator（编排器）
  ├── Profile Agent（用户画像）
  ├── Retrieval Agent（RAG 检索）
  ├── Planner Agent（学习计划）
  ├── Tutor Agent（课程问答）
  ├── Quiz Agent（测验出题）
  ├── Evaluator Agent（错题分析）
  └── Safety Agent（安全审核 + 反幻觉）
→ 结构化输出 + 资料引用
```

---

## 技术架构

### 总体设计

```
┌─────────────────────────────────────────────────────┐
│                   HarmonyOS 客户端                    │
│  (DevEco Studio / ArkTS / Stage 模型)                │
│  Dashboard │ Chat │ Course │ Plan │ Knowledge │ Profile│
│        HTTP / SSE / WebSocket  ↓↓↓                    │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                 AI / Web 后端 (Next.js)               │
│  API Routes → Orchestrator → Agents → 模型 API       │
│  RAG 检索（本地简化） + SQLite/JSON 存储              │
└─────────────────────────────────────────────────────┘
```

### 设计原则

1. **AI 能力服务端化**：复杂逻辑放后端，鸿蒙端只负责交互与系统体验
2. **可解释性**：所有 AI 输出附带资料引用与依据
3. **安全优先**：Safety Agent 对所有输出做内容安全审核
4. **渐进式 RAG**：初期本地 JSON/SQLite，后续接向量库
5. **鸿蒙原生体验**：服务卡片、通知、元服务、跨设备能力

### 技术栈

| 层级 | 技术 |
|------|------|
| AI / Web 后端 | Next.js 14 (App Router) + TypeScript + Tailwind CSS + Vercel AI SDK |
| 鸿蒙端 | DevEco Studio 26.0 + ArkTS + Stage 模型 + HarmonyOS SDK |
| 模型 API | OpenAI 兼容接口（方向不限模型） |
| 向量检索 | 初期本地简化，后续可接向量库 |
| 数据存储 | SQLite / JSON（初期零依赖） |

---

## 项目结构

```
Hormony/
├── README.md                         # 本文件
├── DEVLOG.md                         # 开发日志（追加写入，不得覆写）
├── .gitignore
├── 2026"…"鸿蒙高校创新赛竞赛规程.pdf   # 官方附件
├── 2026"…"鸿蒙赛道报名手册.pdf         # 官方附件
├── docs/
│   ├── notes/
│   │   ├── competition-summary.md    # 竞赛规则摘要
│   │   └── env-setup.md              # 环境配置记录
│   ├── architecture.md               # 技术架构
│   ├── api-spec.md                   # 接口规范
│   └── project-status.md             # 项目状态总览
├── apps/
│   ├── web/                          # Next.js AI Agent 后端 + Web 原型
│   │   ├── src/
│   │   │   ├── app/                  # 6 个 API 路由 + 6 个页面
│   │   │   │   ├── api/              # chat, profile, courses, plan, quiz, safety-review
│   │   │   │   ├── chat/             # 对话页
│   │   │   │   ├── courses/          # 课程页
│   │   │   │   ├── plan/             # 学习计划页
│   │   │   │   ├── knowledge/        # 知识库页
│   │   │   │   ├── profile/          # 个人画像页
│   │   │   │   ├── layout.tsx        # 全局布局（侧边栏导航）
│   │   │   │   ├── page.tsx          # 仪表盘首页
│   │   │   │   └── globals.css       # 全局样式
│   │   │   └── lib/
│   │   │       ├── agents/           # 7 Agent + 编排器
│   │   │       ├── rag/              # 简化版 RAG 检索
│   │   │       ├── store/            # 内存数据存储
│   │   │       ├── types.ts          # 共享类型
│   │   │       └── utils.ts          # 工具函数
│   │   ├── .env.example
│   │   └── package.json
│   └── harmonyos/                    # ArkTS 鸿蒙端
│       ├── AppScope/app.json5
│       ├── entry/src/main/
│       │   ├── ets/
│       │   │   ├── entryability/EntryAbility.ets
│       │   │   ├── pages/            # 6 个 ArkTS 页面
│       │   │   ├── common/           # HttpClient + Constants
│       │   │   └── model/            # 数据模型
│       │   ├── resources/            # 字符串/颜色/路由资源
│       │   └── module.json5
│       └── README.md
├── packages/                         # 共享代码（待用）
└── scripts/
    └── test-chat.mjs                 # 对话接口测试脚本
```

---

## 环境状态（2026-06-25 核查）

### 已就绪

| 工具 | 版本 | 路径 / 说明 |
|------|------|-------------|
| DevEco Studio | 26.0.0.461 (build 2600461) | `C:\Program Files\Huawei\DevEco Studio\` |
| HarmonyOS SDK | 随 DevEco Studio 内置 | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\` |
| HarmonyOS 模拟器镜像 | 6.1.1 (phone_x86) | `C:\Users\guo82\AppData\Local\Huawei\Sdk\system-image\HarmonyOS-6.1.1\` |
| ohpm | 26.0.0.410 | `C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat` |
| hvigor | 随 DevEco Studio | `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\` |
| hdc | 随 SDK | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe` |
| Node.js | v22.22.2 | 系统 PATH |
| npm | 10.9.7 | 系统 PATH |
| pnpm | 11.9.0 | 系统 PATH |
| Python | 3.13.12 | 系统 PATH |
| Git | 2.54.0.windows.1 | 系统 PATH |
| OpenJDK | 17.0.14 LTS | 系统 PATH |

### 待配置

| 项目 | 说明 |
|------|------|
| PATH 环境变量 | ohpm / hvigor / hdc 不在系统 PATH，需手动添加或通过 DevEco Studio 使用 |
| JAVA_HOME | 未设置，建议指向 JDK 17 安装目录 |
| HOS_SDK_HOME | 未设置，建议指向 SDK 目录 |
| 模型 API Key | 需在 `apps/web/.env.local` 中配置 |
| 官方第三附件 | 作品说明文档，需登录茶思屋下载 |

---

## DevEco MCP 连接配置

本项目通过 **DevEco Toolbox MCP** 实现AI工具与 DevEco Studio 的连接，支持在不打开 DevEco Studio 的情况下完成构建、部署、调试等操作。

### MCP 提供的工具

| 工具名 | 功能 |
|--------|------|
| `harmonyos_knowledge_search` | 查询鸿蒙云端知识库（API 23） |
| `check_ets_files` | ArkTS (.ets) 文件语法检查 |
| `check_cpp_files` | C++ 文件静态语法检查 |
| `build_project` | 项目构建 |
| `start_app` | 在模拟器/真机中启动应用 |
| `get_hilog_or_faultlog_recent` | 获取设备日志 |
| `get_app_ui_tree` | 获取当前页面 UI 树 |
| `project_sync` | 项目同步（初始化/依赖更新后） |
| `perform_ui_action` | 在已启动的 app 中执行点击/输入 |
| `verify_ui` | 基于自然语言测试用例的 UI 自动化验证 |

### MCP 配置 JSON

WorkBuddy 的 MCP 配置文件路径：`~/.workbuddy/mcp.json`

```json
{
  "mcpServers": {
    "deveco-mcp": {
      "command": "npx",
      "args": ["-y", "@deveco-codegenie/mcp@beta"],
      "env": {
        "DEVECO_PATH": "C:\\Program Files\\Huawei\\DevEco Studio",
        "PROJECT_PATH": "C:\\Users\\guo82\\Desktop\\Hormony\\apps\\harmonyos"
      }
    }
  }
}
```

> 注意：配置后需在 WorkBuddy 连接器管理页面点击 "Trust" 启用该 MCP 服务器。
> 若使用 Codex / Cursor / VSCode 等 IDE，将上述 JSON 中的 `mcpServers` 部分写入对应 IDE 的 MCP 配置文件。

### 官方替代方案

华为在 2026 HDC 大会上发布了官方 **DevEco CLI**（鸿蒙能力命令行工具），开源地址：https://gitcode.com/openharmony-sig/deveco-cli 。deveco-toolbox 项目后续仅做缺陷修复，建议关注官方 CLI 方案。

---

## 多 Agent 架构详解

### Agent 职责

| Agent | 职责 | 输入 | 输出 |
|-------|------|------|------|
| Orchestrator | 意图识别，决定调用哪些 Agent | 用户消息 + 上下文 | Agent 调用链 |
| Profile Agent | 用户画像构建与维护 | userId | 学习风格、薄弱点、偏好 |
| Retrieval Agent | RAG 知识库检索 | query + courseId | 相关文档片段 + 引用 |
| Planner Agent | 学习计划与任务拆解 | goal + duration | 可执行任务列表 |
| Tutor Agent | 课程问答与作业思路辅导 | 问题 + 资料 | 答案 + 引用 |
| Quiz Agent | 测验题生成 | 主题 + 难度 | 题目 + 答案 + 解析 |
| Evaluator Agent | 错题与薄弱点分析 | 答题记录 | 薄弱点报告 + 建议 |
| Safety Agent | 内容安全审核与反幻觉 | AI 输出内容 | 通过/拦截 + 风险等级 |

### 演示模式

无 API Key 时自动回退结构化模拟数据，确保项目可独立运行展示。

### 编排流程

```
用户输入
   ↓
Orchestrator ── 意图识别 ── 决定调用哪些 Agent
   ├── Profile Agent   ── 加载用户画像
   ├── Retrieval Agent ── RAG 检索相关资料
   │
   ↓ (按意图路由)
   Planner / Tutor / Quiz / Evaluator
   ↓
Safety Agent ── 审核 + 反幻觉
   ↓
结构化输出 + 引用
```

---

## API 接口

Base URL: `http://<host>:3000/api`

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/chat` | POST | 多 Agent 对话主入口（SSE 流式输出） |
| `/api/profile` | GET | 获取用户学习画像 |
| `/api/courses` | GET | 获取课程列表 |
| `/api/plan` | POST | 生成学习计划 |
| `/api/quiz` | POST | 生成测验题 |
| `/api/safety-review` | POST | 内容安全审核 |

详细接口规范见 `docs/api-spec.md`。

---

## 快速开始

### Web 后端

```bash
cd apps/web
pnpm install
cp .env.example .env.local   # 只复制非密钥配置；MODEL_API_KEY 通过当前进程环境变量注入
pnpm dev                     # http://localhost:3000
```

豆包 Ark 默认 Base URL 和模型名已写入 `apps/web/.env.example`。`MODEL_API_KEY` 不写入仓库、日志或 `.env.local`；未注入时 Web 后端自动使用演示模式。

### 鸿蒙端

使用 DevEco Studio 打开 `apps/harmonyos`，通过 SDK Manager 配置 HarmonyOS SDK，运行至模拟器或真机。

### 鸿蒙端测试

```bash
# 通过 MCP 或 DevEco Studio
# 1. check_ets_files ── 语法检查
# 2. build_project   ── 编译构建
# 3. start_app       ── 安装到模拟器/真机
# 4. verify_ui       ── UI 自动化验证
```

---

## AI 协作工具分工

| 工具 | 职责 |
|------|------|
| WorkBuddy | 环境配置、项目脚手架、AI Agent 后端、接口设计、文档、测试脚本、MCP 连接 |
| Codex | 代码审查、架构分析、鸿蒙端开发指引、技术方案优化、接手后续开发 |
| DevEco Studio | ArkTS 工程管理、模拟器/真机调试、打包提交 |

---

## 开发日志规范

项目根目录维护 `DEVLOG.md` 开发日志，遵循以下规则：

1. **追加写入**：只追加新记录，不得覆写已有内容
2. **必须包含**：模型名称、时间戳（UTC + 北京时间）、操作摘要
3. **格式**：
   ```
   ## [UTC时间] [北京时间] 模型: <模型名称>
   ### 操作
   - <操作摘要>
   ### 涉及文件
   - <文件路径列表>
   ### 备注
   - <补充说明>
   ```
4. **每次操作后更新**：包括代码修改、配置变更、环境调整等

---

## 许可证

待定（参赛阶段）

---

## 第三方依赖与 AI 工具声明

### AI Coding 工具

| 工具 | 用途 |
|------|------|
| WorkBuddy (Claude) | 项目脚手架、AI Agent 后端、文档、MCP 配置 |
| Codex | 代码审查、架构分析、鸿蒙端开发指引 |

### 主要依赖

| 依赖 | 版本 | 许可证 |
|------|------|--------|
| Next.js | 14.2.18 | MIT |
| React | 18.3.1 | MIT |
| Vercel AI SDK | 3.4.33 | Apache-2.0 |
| TypeScript | 5.6.3 | Apache-2.0 |
| Tailwind CSS | 3.4.15 | MIT |
| Zod | 3.23.8 | MIT |
| OpenAI SDK | 4.73.1 | Apache-2.0 |

> 最终提交文档需完整列出所有依赖及许可证。
