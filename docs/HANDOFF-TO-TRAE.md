# Trae 接力工作指引文档

> 本文档由 WorkBuddy (GLM-5.2) 于 2026-06-26 编写，用于向 Trae AI Agent 交接项目全貌与执行角色。
> Trae 接手后请先通读本文档，再阅读 `README.md`、`DEVLOG.md`、`docs/CODEX-HANDOFF.md`。
> **首要提醒**：本项目已配置好 DevEco MCP 连接，请先阅读第四节再开始操作，避免重复探索浪费 token。

---

## 一、项目背景与产品命名（必须精确理解）

### 产品名

**鸿学伴**（2026-06-25 用户从 4 个候选中选定）

- 用于 C4-AI 报名、PPT、演示视频、源码包统一命名
- 英文/拼音备选暂定 HongXueBan / HongMate，如报名表需英文名再定
- 后续文档抬头、README、PPT 封面均以「鸿学伴」为准（README 尚未同步更新产品名，待统一处理）

### 竞赛信息

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

### 关键规则（影响技术决策）

1. **FAQ 第 13 条：Agent 创新方向不限制模型 API 的使用**——可自由选择市场可用 AI 工具及模型 API（豆包/OpenAI 兼容接口等均可）。
2. 面向中国内地及港澳台地区高校在校生（专科/本科/硕士/博士），不限专业。
3. 每队不超过 3 人，可跨学校跨专业，须有一名指导老师（队长所属高校正式教师）。
4. 开放式命题，鼓励基于 HarmonyOS 技术创新开发。
5. 截止前可多次更新作品（至多 10 次），晋级后只能基于原作品迭代优化，不得换新作品。
6. 大赛不提供硬件设备，可使用模拟器/云测试/自有设备。
7. 提交入口：官方页面 → 华为 OAuth → 黄大年茶思屋平台。
8. 使用 AI Coding 工具需在文档中单独说明（工具名、模型 API、开源库、框架、许可证）。

### 关键时间节点（从本地 PDF 规程核对）

| 节点 | 截止时间 |
|------|----------|
| 初赛报名/提交作品 | 2026-07-26 24:00 |
| 复赛提交作品 | 2026-09-30 24:00 |
| 复赛演示视频 | 5 分钟以内 |

### 官方附件（已下载至项目根目录）

- `2026"中国高校计算机大赛―人工智能创意赛"鸿蒙高校创新赛竞赛规程.pdf`
- `2026"中国高校计算机大赛―人工智能创意赛"鸿蒙赛道报名手册.pdf`

> 仍需登录茶思屋平台下载第三个附件：作品说明文档模板。提交前必须核对最新截止时间、提交格式、附件要求。

---

## 二、用户明确指令（必须遵守）

1. **不要直接确定沿用现有初稿思路**——先搭建好需要的一切基础设施，再开始开发，之后再评估初稿成果以及是否复用。（当前阶段基础设施已搭好，初稿已部分复用）
2. **开发日志规范**：`DEVLOG.md` 为追加写入，严禁覆写已有内容；每条记录必须包含模型名称、时间戳（UTC + 北京时间）、操作摘要、涉及文件。
3. **文件操作安全规则**：禁止批量/递归/通配符删除；单文件删除需确认路径；不得覆写已有成果；不得修改工作区之外的文件；不确定时停止并询问用户。完整规则见用户自定义指令。
4. **标识符规则**：严禁猜测任何标识符（键名、变量名、路径、字段、JSON 路径），必须从文件读取精确表述。不确定时必须向用户询问。
5. **PowerShell 中文用 UTF-8 编码**。
6. **不得接触 MODEL_API_KEY**，不写入任何文件或日志。模型密钥只在启动 Web 服务时通过当前进程环境变量注入。

---

## 三、当前项目状态

### Git 状态（2026-06-26 核查）

- 仓库已初始化，分支 `main`
- 最新提交：`3f96850 feat: 封装模型服务端调用`
- 提交历史（6 次）：
  1. `690b07f` chore: initial commit - 项目脚手架
  2. `18add30` docs: 添加 Codex 接手指引文档 + DEVLOG + .gitignore
  3. `58efce7` feat: 补齐 HarmonyOS Hvigor 工程 + 修复 hvigorw 构建 + Web ESLint/类型检查
  4. `1c1562c` feat: 打通 HarmonyOS 编译闭环 — HAP 构建成功
  5. `436a6fa` feat: 知识库 API 闭环 + 模型配置边界
  6. `3f96850` feat: 封装模型服务端调用

### 工作区状态（重要）

当前工作区有 **9 个未提交改动**，是 WorkBuddy 最后两轮（端侧导航闭环 + 遗留修复）的产物，待 Codex 复核后提交：

| 文件 | 改动性质 |
|------|----------|
| `DEVLOG.md` | 追加记录 |
| `apps/harmonyos/entry/src/main/ets/common/HttpClient.ets` | escape() 废弃 API 替换为 TextDecoder |
| `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` | 加返回按钮 |
| `apps/harmonyos/entry/src/main/ets/pages/Course.ets` | 加返回按钮 |
| `apps/harmonyos/entry/src/main/ets/pages/Index.ets` | 启用路由跳转 + 补 Course/Profile 入口 |
| `apps/harmonyos/entry/src/main/ets/pages/Knowledge.ets` | 加返回按钮 + score 显示 |
| `apps/harmonyos/entry/src/main/ets/pages/Plan.ets` | 加返回按钮 |
| `apps/harmonyos/entry/src/main/ets/pages/Profile.ets` | 加返回按钮 |
| `apps/web/src/app/knowledge/page.tsx` | 加错误提示 |

> Trae 接手后建议先与 Codex 确认这批改动是否提交，再开始新工作。

### 已完成的工作清单

#### 基础设施（WorkBuddy + Codex 协作完成）
- ✅ DevEco Studio 26.0.0.461 + HarmonyOS SDK + 模拟器镜像 6.1.1 环境就绪
- ✅ HarmonyOS Hvigor 工程文件补齐（hvigorw tasks BUILD SUCCESSFUL）
- ✅ hvigorw.bat wrapper（内置 NODE_HOME/JAVA_HOME/DEVECO_SDK_HOME，无需系统级设置）
- ✅ DevEco MCP 连接配置（WorkBuddy + Codex 双侧可用）
- ✅ Web ESLint 非交互式配置 + 独立类型检查流程
- ✅ Git 仓库初始化 + .gitignore 完整配置

#### Web 后端（Next.js 14）
- ✅ 8 个 API 路由：`/api/chat`、`/api/courses`、`/api/knowledge/search`、`/api/model/status`、`/api/plan`、`/api/profile`、`/api/quiz`、`/api/safety-review`
- ✅ 7 个 Agent + 编排器（Profile/Retrieval/Planner/Tutor/Quiz/Evaluator/Safety）
- ✅ 模型服务端封装（豆包 Ark OpenAI 兼容，演示模式兜底）
- ✅ RAG 知识库检索（本地简化版）
- ✅ Web lint / typecheck / build 全部通过
- ✅ SSE 对话链路验证通过

#### HarmonyOS 端（ArkTS / Stage 模型）
- ✅ 6 个 ArkTS 页面（Index/Chat/Course/Plan/Knowledge/Profile）
- ✅ HttpClient + Constants + DataModels
- ✅ ArkTS 严格检查 0 Error（全部 10 个 .ets 文件）
- ✅ HAP 构建成功（`entry-default-unsigned.hap`，~263KB）
- ✅ 端侧导航闭环（Dashboard → 6 页面跳转 + 返回按钮）
- ✅ 知识库页接入后端 API（含降级路径）
- ✅ HttpClient 废弃 API 修复（TextDecoder 替代 escape）

### 待完成的工作（下一步任务）

1. **提交当前未提交改动**（待 Codex 复核确认）
2. **router → Navigation 组件迁移**（架构级重构，需 Codex 决策指引）——当前 `@ohos.router` 的 pushUrl/back 全部被标记 deprecated
3. **鸿蒙赛道亮点择一实现**：服务卡片 / 通知 / 元服务
4. **知识库上传接口** `POST /api/knowledge/upload`（暂未实现）
5. **Web 课程页/画像页接入真实 API**（当前用硬编码演示数据）
6. **Knowledge.ets 请求体传 courseId**（需课程选择器 UI）
7. **签名配置**（HAP 当前为 unsigned，真机安装需在 DevEco Studio 配置 signingConfigs）
8. **README 产品名同步**（改为「鸿学伴」）
9. **报名材料准备**（作品说明文档、技术方案、创意描述、PPT、演示视频）

---

## 四、DevEco MCP 连接方法（关键，避免重复探索）

### 这是什么

本项目通过 **DevEco Toolbox MCP** 实现 AI 工具与 DevEco Studio 的连接，类比 Xcode 通过 MCP 连接的方式。配置好后，AI 工具可以在不打开 DevEco Studio 图形界面的情况下完成 ArkTS 检查、项目构建、应用启动、UI 验证等操作。

### MCP 包信息（已验证可用）

- **MCP 包名**：`@deveco-codegenie/mcp@beta`
- **启动方式**：`npx -y @deveco-codegenie/mcp@beta`
- **开源项目**：https://github.com/open-deveco/deveco-toolbox

### 配置内容（标准 JSON 格式）

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

### 两个环境变量（必须设置）

| 环境变量 | 值 | 用途 |
|---------|-----|------|
| `DEVECO_PATH` | `C:\Program Files\Huawei\DevEco Studio` | DevEco Studio 安装路径 |
| `PROJECT_PATH` | `C:\Users\guo82\Desktop\Hormony\apps\harmonyos` | 鸿蒙工程目录 |

### 各 IDE 的配置文件位置（已验证）

| AI 工具 | 配置文件 | 注意事项 |
|---------|---------|---------|
| WorkBuddy | `~/.workbuddy/mcp.json` | 写入后需在连接器管理页面点击 "Trust" 启用 |
| Codex | `~/.codex/config.toml` | TOML 格式，command 需用完整 npx 路径；修改后需重启会话生效（非热加载） |
| Trae | （需 Trae 自身文档确认） | Trae 支持 MCP，请查阅 Trae 的 MCP 配置文档，将上述 JSON 中 `mcpServers` 部分按 Trae 要求添加 |

> **Trae 配置提示**：WorkBuddy 和 Codex 已分别用 JSON 和 TOML 两种格式成功配置。Trae 的具体配置文件路径和格式请查阅 Trae 官方文档，不要猜测。配置完成后必须验证工具是否真正暴露。

### Codex 配置参考（TOML 格式，已验证可用）

Codex 在 `~/.codex/config.toml` 中的配置如下，注意 command 用了完整路径（因为 Codex runtime 的 npx 不在 PATH 中）：

```toml
[mcp_servers."deveco-mcp"]
command = 'C:\Users\guo82\AppData\Local\OpenAI\Codex\runtimes\cua_node\1b23c930bdf84ed6\bin\npx.cmd'
args = ["-y", "@deveco-codegenie/mcp@beta"]
startup_timeout_sec = 120

[mcp_servers."deveco-mcp".env]
DEVECO_PATH = 'C:\Program Files\Huawei\DevEco Studio'
PROJECT_PATH = 'C:\Users\guo82\Desktop\Hormony\apps\harmonyos'
```

> 如果 Trae 的 npx 不在 PATH 中，也需要用完整路径。可用 `where npx`（Windows）或 `which npx`（Unix）查找。

### 可用工具（10 个，已验证全部可用）

| 工具名 | 功能 | 使用场景 |
|--------|------|----------|
| `harmonyos_knowledge_search` | 查询鸿蒙云端知识库（API 23） | 查 ArkTS/HarmonyOS API 用法，**不要猜测 API**，先查这里 |
| `check_ets_files` | ArkTS (.ets) 文件语法检查 | 每次 ArkTS 改动后必须执行 |
| `check_cpp_files` | C++ 文件静态语法检查 | 涉及 NDK 时用 |
| `build_project` | 项目构建 | 完成一轮改动后执行，生成 HAP |
| `start_app` | 在模拟器/真机中启动应用 | 需先配置签名或用模拟器 |
| `get_hilog_or_faultlog_recent` | 获取设备日志 | 调试运行时问题 |
| `get_app_ui_tree` | 获取当前页面 UI 树 | UI 自动化验证 |
| `project_sync` | 项目同步（初始化/依赖更新后） | ohpm install 后或新增依赖后 |
| `perform_ui_action` | 在已启动的 app 中执行点击/输入 | UI 自动化测试 |
| `verify_ui` | 基于自然语言测试用例的 UI 自动化验证 | 端到端验证 |

### 验证 MCP 是否可用的方法

配置完成后，调用 `harmonyos_knowledge_search`（关键词如 "Stage模型" 或 "module.json5"），如果能返回 HarmonyOS 官方文档内容，说明 MCP 链路畅通。

### ArkTS 严格模式关键规则（WorkBuddy 踩坑总结）

ArkTS 严格检查有 5 条关键规则，违反会报 Error：

1. **对象字面量必须对应已声明的 interface**——不能写内联对象类型 `{ text: string; source: string }`，必须先定义 interface
2. **不能用 `any`/`unknown`**——必须显式声明类型
3. **不能用索引签名 `[key: string]`**——接口里不能有索引签名
4. **函数/箭头函数参数和返回值需要显式类型**——回调函数也要加返回类型，如 `filter((x): boolean => ...)`
5. **静态方法在回调中用类名调用而非 this**——如 `HttpClient.decodeArrayBuffer` 而非 `this.decodeArrayBuffer`

> 改 ArkTS 代码时务必遵守，改完用 `check_ets_files` 验证。

### 官方替代方案

华为在 2026 HDC 发布了官方 **DevEco CLI**（https://gitcode.com/openharmony-sig/deveco-cli），npm 包 `@deveco/deveco-cli` v1.0.0。deveco-toolbox 项目后续仅做缺陷修复，建议关注官方 CLI 方案。

---

## 五、Trae 的角色定位

### 角色变更说明

由于额度问题，WorkBuddy（GLM-5.2）的执行角色暂时由 **Trae** 接手接力。协作分工调整如下：

| 角色 | AI 工具 | 职责 |
|------|---------|------|
| 架构师/指挥 | Codex (GPT-5) | 核心底层框架、相关约束、架构决策、代码审查、给出开发指引和分析 |
| 执行者 | **Trae（接替 WorkBuddy）** | 听取 Codex 指挥，精准执行大型大量任务，优先解决简单和不易出错的任务和配置相关问题 |
| （退出执行） | WorkBuddy (GLM-5.2) | 暂时退出执行角色，产物和进展已交接给 Trae |

### Trae 的工作原则

1. **听取 Codex 指挥**：Codex 负责核心底层框架和相关约束，Trae 负责执行，以节约 Codex 的 token 消耗。
2. **优先简单和不易出错的任务**：配置问题、页面补齐、样式统一、资源整理、文档同步、重复性 ArkTS 类型修复、构建回归等。
3. **不触碰核心模型文件**：不修改 `apps/web/src/lib/agents/model.ts`、`orchestrator.ts` 和模型相关 API（由 Codex 负责）。
4. **不接触 MODEL_API_KEY**：不写入任何文件或日志。
5. **每次 ArkTS 改动后执行 DevEco MCP `check_ets_files`**。
6. **完成一轮改动后执行 `build_project`**。
7. **所有改动追加写入 `DEVLOG.md`**（含模型名称 + 时间戳）。

### 与 Codex 的协作方式

- Codex 会通过 DEVLOG 和直接对话给出开发指引和约束
- Trae 执行后追加 DEVLOG 记录
- Codex 会审查 Trae 的工作成果
- 关键架构决策（如 router → Navigation 迁移）由 Codex 决定，Trae 不擅自做架构级重构

---

## 六、环境信息（已就绪，无需重新配置）

### 开发工具（2026-06-25 核查）

| 工具 | 版本 | 路径 |
|------|------|------|
| DevEco Studio | 26.0.0.461 (build 2600461) | `C:\Program Files\Huawei\DevEco Studio\` |
| HarmonyOS SDK | 随 DevEco 内置 | `sdk\default\openharmony\` (apiVersion 26) |
| 模拟器镜像 | HarmonyOS-6.1.1 (phone_x86) | `AppData\Local\Huawei\Sdk\system-image\HarmonyOS-6.1.1\` |
| ohpm | 26.0.0.410 | `DevEco Studio\tools\ohpm\bin\ohpm.bat` |
| hvigor | 6.26.1 | `DevEco Studio\tools\hvigor\` |
| hdc | 3.2.0e | `sdk\default\openharmony\toolchains\hdc.exe` |
| node.exe | DevEco 内置 | `DevEco Studio\tools\node\node.exe` |
| Node.js (WorkBuddy shell) | v22.22.2 | 系统 PATH |
| npm | 10.9.7 | 系统 PATH |
| pnpm | 11.9.0 | 系统 PATH |
| Python | 3.13.12 | 系统 PATH |
| Git | 2.54.0.windows.1 | 系统 PATH |
| OpenJDK | 17.0.14 LTS | 系统 PATH |

### 环境差异说明（重要）

不同 AI 工具的终端环境可能不同：

| 环境 | Node 版本 | npm | pnpm |
|------|-----------|-----|------|
| WorkBuddy shell | v22.22.2 | 10.9.7 | 11.9.0 |
| Codex 终端 | v24.14.0 (bundled) | 11.13.0 | 11.7.0 (bundled) |
| Trae 终端 | （需 Trae 自行确认） | — | — |

> ohpm / hvigor / hdc 不在系统 PATH，通过 DevEco Studio 或 hvigorw.bat wrapper 使用。

### Hvigor 工程构建（已修复，关键经验）

`apps/harmonyos/hvigorw.bat` 是 wrapper 脚本，内置以下环境变量（无需系统级设置）：

| 环境变量 | 值 | 用途 |
|---------|-----|------|
| NODE_HOME | `C:\Program Files\Huawei\DevEco Studio\tools\node` | Node.js 运行环境 |
| JAVA_HOME | `C:\Program Files\Huawei\DevEco Studio\jbr` | JDK 17（DevEco 内置 JBR） |
| DEVECO_SDK_HOME | `C:\Program Files\Huawei\DevEco Studio\sdk` | HarmonyOS SDK |

**根本原因（已解决）**：hvigorw.js 依赖 `__dirname`（脚本自身所在目录）定位 DevEco Studio 的 @ohos/hvigor 包路径。不能把 hvigorw.js 复制到项目目录，否则相对路径解析失败。所以 hvigorw.bat 改为 wrapper 调用 DevEco Studio 原始 hvigorw.bat。

**compatibleSdkVersion**: `"5.0.0(12)"`（DevEco Studio 26.0 官方模板值）

**验证命令**：`hvigorw.bat tasks --no-daemon` → `BUILD SUCCESSFUL`

### npm registry 配置（@ohos 包不在 npmjs.org）

已配置华为 registry（在 `~/.npmrc`）：
- `registry=https://repo.huaweicloud.com/repository/npm/`
- `@ohos:registry=https://repo.harmonyos.com/npm/`

---

## 七、技术架构概览

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
  结构化输出 + 资料引用
```

编排器：`apps/web/src/lib/agents/orchestrator.ts`
演示模式：无 API Key 时自动回退结构化模拟数据

### API 接口

Base URL: `http://<host>:3000/api`

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/chat` | POST | 多 Agent 对话主入口（SSE 流式输出） |
| `/api/profile` | GET | 获取用户学习画像 |
| `/api/courses` | GET | 获取课程列表 |
| `/api/plan` | POST | 生成学习计划 |
| `/api/quiz` | POST | 生成测验题 |
| `/api/safety-review` | POST | 内容安全审核 |
| `/api/knowledge/search` | POST | 知识库检索 |
| `/api/model/status` | GET | 模型状态检查 |

详细接口规范见 `docs/api-spec.md`。

---

## 八、关键文件索引

| 文件 | 用途 |
|------|------|
| `README.md` | 项目全貌，含竞赛信息/架构/环境/MCP/Agent 详解 |
| `DEVLOG.md` | 开发日志（追加写入，含全部历史记录） |
| `docs/CODEX-HANDOFF.md` | Codex 接手指引文档（WorkBuddy 早期编写） |
| `docs/HANDOFF-TO-TRAE.md` | 本文件，Trae 接力指引 |
| `docs/CODEX-ROLE-CHANGE.md` | Codex 角色改变说明 |
| `docs/notes/competition-summary.md` | 竞赛规则摘要 |
| `docs/architecture.md` | 技术架构设计 |
| `docs/api-spec.md` | API 接口规范 |
| `docs/notes/env-setup.md` | 环境配置记录 |
| `docs/project-status.md` | 项目状态总览 |
| `apps/web/` | Next.js AI Agent 后端 + Web 原型 |
| `apps/harmonyos/` | ArkTS 鸿蒙端工程 |
| `apps/harmonyos/hvigorw.bat` | Hvigor 构建 wrapper（关键，勿删） |
| `scripts/test-chat.mjs` | 对话接口测试脚本 |

### 鸿蒙端 ArkTS 文件清单

```
apps/harmonyos/entry/src/main/ets/
├── entryability/EntryAbility.ets   # 入口 Ability
├── pages/
│   ├── Index.ets                   # Dashboard 首页
│   ├── Chat.ets                    # 对话页（SSE 流式）
│   ├── Course.ets                  # 课程页
│   ├── Plan.ets                    # 学习计划页
│   ├── Knowledge.ets               # 知识库页
│   └── Profile.ets                 # 个人画像页
├── common/
│   ├── HttpClient.ets              # HTTP 客户端封装
│   └── Constants.ets               # 常量定义（API 路径等）
└── model/
    └── DataModels.ets              # 数据模型 interface
```

### Web 后端关键文件

```
apps/web/src/
├── app/
│   ├── api/                        # 8 个 API 路由
│   │   ├── chat/route.ts
│   │   ├── courses/route.ts
│   │   ├── knowledge/search/route.ts
│   │   ├── model/status/route.ts
│   │   ├── plan/route.ts
│   │   ├── profile/route.ts
│   │   ├── quiz/route.ts
│   │   └── safety-review/route.ts
│   ├── chat/                       # 对话页
│   ├── courses/                    # 课程页
│   ├── plan/                       # 学习计划页
│   ├── knowledge/                  # 知识库页
│   └── profile/                    # 个人画像页
└── lib/
    ├── agents/                     # 7 Agent + 编排器 + 模型封装
    │   ├── orchestrator.ts         # ⚠️ Trae 不修改
    │   ├── model.ts                # ⚠️ Trae 不修改
    │   ├── planner-agent.ts
    │   ├── quiz-agent.ts
    │   └── ...
    ├── rag/                        # RAG 检索
    ├── store/                      # 内存数据存储
    ├── types.ts                    # 共享类型
    └── utils.ts                    # 工具函数
```

---

## 九、WorkBuddy 操作经验总结（供 Trae 参考，避免踩坑）

### 1. ArkTS 改动后的验证流程

```
改 .ets 文件
  → DevEco MCP check_ets_files（检查该文件）
  → 修复所有 Error（Warning 可酌情保留）
  → DevEco MCP build_project（构建整个工程）
  → BUILD SUCCESSFUL 则通过
```

### 2. Web 端改动后的验证流程

```bash
cd apps/web
pnpm lint        # ESLint 检查
pnpm typecheck   # 类型检查（用 tsconfig.typecheck.json，不依赖 .next）
pnpm build       # 生产构建
```

> 注意：不要先清理 `.next` 再直接跑 `typecheck`，会因 `.next/types/**/*.ts` 缺失失败。先 `build` 再 `typecheck`，或用独立的 `tsconfig.typecheck.json`。

### 3. 测试对话接口

```bash
# 启动 Web 服务
cd apps/web && pnpm build && next start -p 3001

# 另开终端测试
node scripts/test-chat.mjs
```

### 4. Git 提交规范

- 提交信息用 `feat:` / `fix:` / `docs:` / `chore:` 前缀
- 提交前确认工作区状态（`git status`）
- 不要提交 `.env.local`、`node_modules`、`oh_modules`、`.hvigor`、`.next`（已在 .gitignore）

### 5. 常见坑

- **hvigorw.js 不能复制到项目目录**：会破坏 `__dirname` 相对路径解析，用 hvigorw.bat wrapper
- **@ohos 包不在 npmjs.org**：需配置华为 registry
- **ArkTS 对象字面量必须有 interface**：不能写内联类型
- **`@ohos.router` 已 deprecated**：华为推荐 Navigation 组件，但当前原型阶段 router 仍可用
- **curl 在 Windows Git Bash 下中文编码异常**：用 Node.js fetch 测试
- **store 使用 globalThis 单例**：Next.js dev 模式模块隔离修复

---

## 十、Trae 接手后的建议首步

1. **通读本文件** + `README.md` + `DEVLOG.md`（至少最近 3 条记录）
2. **配置 DevEco MCP**（见第四节），配置后调用 `harmonyos_knowledge_search` 验证
3. **与 Codex 确认**：当前 9 个未提交改动是否提交，以及下一步任务优先级
4. **开始执行 Codex 指派的任务**，每次改动后追加 DEVLOG 记录

### DEVLOG 记录格式（必须遵守）

```
## [UTC时间] [北京时间] 模型: Trae (模型名)

### 操作
<操作摘要>

### 涉及文件
- <文件路径列表>

### 备注
- <补充说明>

---
```

---

## 十一、AI 协作工具声明（最终提交需包含）

| 工具 | 模型 | 用途 |
|------|------|------|
| WorkBuddy | GLM-5.2 | 环境配置、项目脚手架、AI Agent 后端、接口、文档、MCP 配置（已退出执行角色） |
| Codex | GPT-5 | 代码审查、架构分析、核心底层框架、模型封装、开发指引 |
| Trae | （Trae 模型） | 接替 WorkBuddy 执行角色，ArkTS 页面补齐、样式统一、资源整理、文档同步、构建回归 |

> 最终提交文档需完整列出所有 AI 工具、模型 API、开源库、框架及许可证。

---

_本文档由 WorkBuddy (GLM-5.2) 于 2026-06-26 编写，用于 Trae 接力交接。如有疑问，优先查阅 DEVLOG.md 历史记录或询问 Codex。_
