# 项目交接文档 — Trae Work → Trae IDE

> **创建时间**: 2026-06-27 19:30 CST
> **创建者**: Trae (Claude) — Trae Work 会话
> **目的**: 将本线程的重要上下文传递给 Trae IDE，确保工程持续推进不出现重大差错或误会

---

## 一、项目概览

### 1.1 项目基本信息

| 项目 | 值 |
|------|-----|
| 项目名称 | 鸿学伴 (HongXueBan) — 学习助手 App |
| 竞赛 | 华为鸿蒙激励赛 (https://developer.huawei.com/consumer/cn/activity/incentive/C4) |
| 项目路径 | `C:\Users\guo82\Desktop\Hormony` |
| 双前端 | HarmonyOS ArkTS App（竞赛交付物）+ Next.js Web App（服务端/管理） |
| App BundleName | `com.c4ai.hormony` |
| 模拟器 | Pura 90 Pro Max，设备 ID `127.0.0.1:5555` |

### 1.2 团队分工

| 角色 | 模型/工具 | 职责 |
|------|-----------|------|
| **Codex** | GPT-5 | 架构师，做架构决策（如 router 迁移、API 设计） |
| **Trae** | Claude | 执行者，负责前端开发、UI 改版、文档、测试 |
| **DevEco Code** | gpt-5.3-chat-latest / GLM-5.1 | 鸿蒙专家 AI Agent，代码审查、方案生成、崩溃诊断 |

### 1.3 关键架构决策（Codex 决定，Trae 执行）

- **路由系统**: 当前使用 `@ohos.router`（已废弃），迁移到 Navigation 是 Codex 的架构决策，**当前阶段不执行迁移**
- **API 基础地址**: `http://10.0.2.2:3000`（模拟器访问宿主机 Web 服务）
- **用户 ID**: `demo`（演示阶段硬编码）
- **courseId**: `cs101`（Knowledge.ets 已修复，请求体包含此值）

---

## 二、当前工程状态

### 2.1 Git 提交历史（最近 5 条）

```
5a1da09 docs: Trae+DevEco Code组合拳工作流规范
ab52bef fix: P0代码修复 + DevEco Code平台集成测试
9320fa5 docs: 数据真实性核实 + DevEco Code平台研究 + 调试产物清理
d313493 feat: 第二批UI改版(Chat/Profile/Knowledge/Plan) + 构建验证 + 截图
2f0891b docs: 前端交互框架设计文档(685行)+竞品分析+开源调研
```

### 2.2 已完成的工作

#### UI 改版（两批，全部完成）

| 页面 | 状态 | 关键改动 |
|------|:---:|------|
| Index.ets | ✅ | 浅色主题、统计卡片、5 个功能入口（彩色左边框） |
| Course.ets | ✅ | 浅色主题、课程进度条、知识点标签 |
| Chat.ets | ✅ | 浅色主题、"正在思考..."替代"Agent 协作中"、折叠引用、SSE 保留 |
| Plan.ets | ✅ | 浅色主题、目标输入+生成计划、任务列表 |
| Knowledge.ets | ✅ | 浅色主题、修复 courseId、相关度百分比、空状态 |
| Profile.ets | ✅ | 浅色主题、加载状态、内联统计卡片、红/绿标签 |

#### P0 代码修复（已完成）

- `Chat.ets`: 移除死导入 `ChatMessage`
- `Knowledge.ets`: 空查询不再回退演示数据，改为空状态
- `Index.ets`: error 类型安全 `(e as Error).message ?? String(e)`

#### 文档体系（已建立）

| 文档 | 路径 | 用途 |
|------|------|------|
| 前端交互框架 | `docs/FRONTEND-INTERACTION-FRAMEWORK.md` | 设计系统、页面规范、竞品借鉴 |
| DevEco Code 能力参考 | `docs/DEVECO-CODE-CAPABILITIES.md` | 平台工具链完整参考 |
| 组合拳工作流规范 | `docs/INTEGRATED-WORKFLOW-SPEC.md` | **强制性**工作流边界 |
| 开发日志 | `DEVLOG.md` | 全部操作记录（1283+ 行） |

### 2.3 技术债务清单

| 优先级 | 问题 | 文件 | 状态 |
|:---:|------|------|------|
| **P1** | 10 处废弃 `router.pushUrl`/`back` | 全部页面 | Codex 架构决策，暂不迁移 |
| **P1** | 14 类硬编码颜色值未收口 Constants | 全部页面 | 记录待处理 |
| **P1** | Chat.ets SSE 未取消机制 → 内存泄漏 | Chat.ets | DevEco Code 发现，需修复 |
| **P1** | HttpClient.ets ArkTS 违规 (`as`/`Object`/`Record`) | HttpClient.ets | DevEco Code 发现，需修复 |
| **P2** | 4 页面 catch 块演示数据回退 | Course/Plan/Profile/Knowledge | 原型期可接受 |
| **P2** | verify_ui 未启用 | MCP 配置 | 需配 AI 视觉模型 |
| **P2** | check_ets_files 管道错误 | MCP 工具 | 需重启 DevEco Studio LSP |
| **P2** | harmonyos_knowledge_search 网络不通 | MCP 工具 | 阿里云 8.152.217.126 不通 |
| **P2** | 5 处 `console.error` 未改 hilog | Index.ets | 建议改 hilog |

---

## 三、工具链配置（关键！）

### 3.1 双工具栈架构

```
Trae (Claude)  ←→  DevEco MCP (@deveco-codegenie/mcp)  — 11 个 MCP 工具
                  ↕
Trae (Claude)  ←→  DevEco Code (@deveco/deveco-code v0.1.0)  — AI Agent
```

### 3.2 DevEco Code CLI

- **CLI 命令**: `deveco`（不是 `deveco-code`）
- **路径**: `C:\Users\guo82\AppData\Local\Programs\nodejs-portable\node-v24.16.0-win-x64\deveco.cmd`
- **默认模型**: `gpt-5.3-chat-latest`
- **免费模型**: `deveco/GLM-5.1`（50 req/min）
- **非交互执行**: `deveco run '<指令>' --dir <项目> --skip-agreement --log-level ERROR`

### 3.3 Skills 文件路径

```
C:\Users\guo82\.local\share\deveco\skills\
├── arkui-knowledge\references\      — ArkUI 常见错误、质量检查清单
├── arkts-grammar-standards\references\  — TS vs ArkTS 差异、语法限制
├── arkts-error-fixes\reference\     — 30+ 编译错误修复指南
├── arkts-runtime-fix\scripts\       — hilog/faultlog/jscrash 脚本链
└── deveco-create-project\           — 工程模板
```

### 3.4 环境变量

```
DEVECO_HOME=C:\Program Files\Huawei\DevEco Studio
```

### 3.5 模拟器启动流程

```powershell
# 1. 接受许可
& 'C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe' -license accept
# 2. 清理残留进程
Stop-Process -Name "emulator-crash-service" -Force -ErrorAction SilentlyContinue
# 3. 启动
& 'C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe' -start 'Pura 90 Pro Max' -noWindow
# 4. 等待 45 秒后验证
& 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list target
# 5. 检测到 127.0.0.1:5555 后，用 MCP start_app 部署
```

### 3.6 工作流规范

**详见 `docs/INTEGRATED-WORKFLOW-SPEC.md` — 这是强制性工作流边界文档**

6 条核心规则：
1. 代码改写后必须调用 `deveco run` 审查
2. 编译报错必须查 arkts-error-fixes 指南
3. 运行时崩溃必须用脚本链诊断
4. 编写 ArkUI 代码前必须读 Skill 参考文件
5. 知识查询优先用 `deveco run`
6. 方案设计必须借助 `deveco run`

---

## 四、设计系统（P0 官方核实）

### 4.1 色彩

| 色彩 | 色值 | 用途 | 来源 |
|------|------|------|------|
| 宇宙蓝(brand) | `#0a59f7` | 官方品牌色、主操作色 | [P0-官方] |
| ~~系统蓝~~ | ~~`#007DFF`~~ | ~~社区误传~~ | **[P0-已否定]** 仅 TextInput 光标色 |
| 成功绿 | `#4caf50` | 进度条、正确率 | 自定义 |
| 警告橙 | `#ff9800` | 学习天数 | 自定义 |
| 错误红 | `#e53935` | 薄弱知识点 | 自定义 |
| 背景灰 | `#f5f6f8` | 页面背景 | 自定义 |
| 卡片白 | `#ffffff` | 卡片背景 | 自定义 |
| 主文字 | `#1a1a1a` | 标题、正文 | 自定义 |
| 次文字 | `#929292` | 副标题 | 自定义 |

### 4.2 字体

- 字体族: HarmonyOS Sans（9 种字重）
- ArkUI `fontWeight` 默认值 500（Medium），取值 [100, 900] 间隔 100

### 4.3 动效

| 场景 | 时长 |
|------|------|
| 简单动画 | 100ms |
| 小范围运动 | 150ms |
| 局部运动 | 200ms |
| 复杂动画 | 300ms |
| 全屏运动 | 350ms |
| ~~页面转场上限~~ | ~~500ms~~ **[P0-已否定]** |

### 4.4 圆角

- 卡片/按钮/输入框: 12vp（自定义，非官方规范）
- 官方 Button 默认: NORMAL=20vp / SMALL=14vp

---

## 五、重要约定和禁忌

### 5.1 文件操作安全规则

- **禁止**批量/递归/通配符删除（`del /s`、`Remove-Item -Recurse`、`rm -rf` 等）
- 删除文件每次只能删一个明确指定的文件
- 不得删除目录，即使为空
- 不得覆盖用户已有未提交修改
- PowerShell 涉及中文使用 UTF-8 编码

### 5.2 代码约定

- **禁止**在 UI 文案中暴露技术架构术语（Agent/RAG/Retrieval/Planner 等）
- **禁止**使用 `#007DFF`（非官方品牌色）
- **禁止**使用 `as` 类型断言（ArkTS 禁止）
- **禁止**使用 `Object` 类型（应用具体 interface）
- **禁止**使用 `Record<string, Object>`（结构化类型不允许）
- **禁止**使用模板字面量 `` `${value}` ``（ArkTS 限制，应用字符串拼接）
- 路由 URI 用 `pages/X` 格式（无前导斜杠）
- `main_pages.json` 路由注册路径无前导斜杠

### 5.3 工作流约定

- 每次代码改写后必须 `deveco run` 审查（强制性）
- 每次构建必须 `BUILD SUCCESSFUL` 才算通过
- 每次节点进展必须更新 `DEVLOG.md`
- 重型任务必须有开发文档保存在工作目录

### 5.4 subagent 约定

- subagent 无数量上限、无搜索额度限制、无范围限制
- 搜索直到信息偏离需求无用为止
- 最大推理强度推进工程，不计成本

---

## 六、待完成工作

### 6.1 近期（高优先级）

1. **修复 Chat.ets SSE 内存泄漏** — DevEco Code 发现：SSE 未取消机制、页面退出后回调仍持有 this
2. **修复 HttpClient.ets ArkTS 违规** — `as T` 断言、`Object` 类型、`Record` 结构化类型
3. **颜色值收口到 Constants** — 14 类硬编码颜色统一管理
4. **配置 verify_ui** — 需配置 AI 视觉模型（Qwen3-VL，阿里云百炼）

### 6.2 中期

5. router 迁移到 Navigation（Codex 架构决策后执行）
6. 提取 Index.ets/Profile.ets 重复结构为 @Builder
7. 演示数据回退加 `__DEBUG__` 开关
8. console.error 改 hilog

### 6.3 测试

9. `deveco serve` headless 服务器测试
10. `deveco mcp add` 挂载 DevEco MCP 到 DevEco Code
11. Goal 模式 SDD 开发测试

---

## 七、项目文件结构

```
C:\Users\guo82\Desktop\Hormony\
├── docs/
│   ├── FRONTEND-INTERACTION-FRAMEWORK.md   — 前端交互框架（685行）
│   ├── DEVECO-CODE-CAPABILITIES.md         — DevEco Code 平台能力参考
│   └── INTEGRATED-WORKFLOW-SPEC.md         — 组合拳工作流规范（强制性）
├── DEVLOG.md                                — 开发日志（1283+ 行）
├── apps/
│   ├── harmonyos/                           — HarmonyOS ArkTS App
│   │   ├── AppScope/app.json5              — bundleName: com.c4ai.hormony
│   │   └── entry/src/main/ets/
│   │       ├── pages/
│   │       │   ├── Index.ets               — 首页（仪表盘+功能入口）
│   │       │   ├── Chat.ets                — AI 对话（SSE 流式）
│   │       │   ├── Course.ets              — 我的课程
│   │       │   ├── Plan.ets                — 学习计划
│   │       │   ├── Knowledge.ets           — 知识库搜索
│   │       │   └── Profile.ets             — 学习画像
│   │       ├── common/
│   │       │   ├── HttpClient.ets          — HTTP/SSE 客户端
│   │       │   └── Constants.ets           — 常量（BASE_URL, DEMO_USER_ID）
│   │       └── model/
│   │           └── DataModels.ets          — 数据接口定义
│   └── web/                                 — Next.js Web App
│       └── src/app/
│           ├── api/                         — API 路由
│           ├── courses/page.tsx             — 课程页（已接入 API）
│           ├── profile/page.tsx             — 画像页（已接入 API）
│           └── knowledge/page.tsx           — 知识库页
└── screenshots/harmonyos/                   — UI 截图
    ├── batch2-index.png
    ├── batch2-chat.png
    ├── batch2-plan.png
    ├── batch2-knowledge.png
    └── batch2-profile.png
```
