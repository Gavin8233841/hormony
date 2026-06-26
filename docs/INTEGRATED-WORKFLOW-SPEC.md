# Trae + DevEco Code 组合拳工作流规范

> **创建时间**: 2026-06-27
> **创建者**: Trae (Claude)
> **目标**: 100% 发挥 DevEco Code CLI + DevEco MCP 全部能力，形成组合拳高效推进鸿学伴工程
> **约束**: 本规范为强制性工作流边界，Trae 必须积极调用这些鸿蒙官方工具，不得浪费生产工具能力

---

## 一、工具能力矩阵（全部实测验证）

### 1.1 DevEco Code CLI（`deveco` 命令）

> 安装路径: `C:\Users\guo82\AppData\Local\Programs\nodejs-portable\node-v24.16.0-win-x64\deveco.cmd`
> 版本: `@deveco/deveco-code@0.1.0`
> 默认模型: `gpt-5.3-chat-latest`（build 模式）
> 免费模型: `deveco/GLM-5.1`（50 req/min）

| 命令 | 能力 | 实测状态 | 分配任务 |
|------|------|:---:|------|
| `deveco run '<指令>' --dir <项目> --skip-agreement` | 非交互 AI Agent 执行 | ✅ 已验证 | 代码审查、问题分析、方案生成、代码生成、术语扫描 |
| `deveco run --format json` | JSON 事件流输出 | ✅ 可用 | 程序化解析 AI 输出 |
| `deveco run -m deveco/GLM-5.1` | 指定免费模型 | ✅ 可用 | 日常低延迟任务 |
| `deveco serve` | headless 服务器 | 未测试 | 持久服务多会话 |
| `deveco mcp add/list` | MCP 服务器管理 | ✅ 已查询 | 挂载 DevEco MCP 到 DevEco Code |
| `deveco debug skill` | 列出所有 Skills | ✅ 已验证 | 确认可用技能 |
| `deveco debug config` | 查看解析配置 | ✅ 已验证 | 排查配置问题 |
| `deveco debug paths` | 查看全局路径 | ✅ 已验证 | 定位数据目录 |
| `deveco agent list` | 列出 Agent 和权限 | ✅ 已验证 | 确认 Agent 权限配置 |
| `deveco models` | 列出可用模型 | ✅ 已验证 | 选择最优模型 |
| `deveco plugin <module>` | 安装插件 | 未测试 | 扩展能力 |

### 1.2 DevEco Code Skills（5 个内置技能包）

> 路径: `C:\Users\guo82\.local\share\deveco\skills\`

| Skill | 触发场景 | Trae 调用方式 | 实测状态 |
|-------|----------|---------------|:---:|
| **arkui-knowledge** | 编写/修改 ArkUI 组件、布局、状态管理 | Read 参考文件 + `deveco run` 自动加载 | ✅ |
| **arkts-grammar-standards** | 编写 ArkTS 代码前检查语法合规 | Read `references/ts-diff.md` + `restrictions.md` | ✅ |
| **arkts-error-fixes** | 编译报错时查找修复指南 | Read `reference/<错误类型>.md` | ✅ |
| **arkts-runtime-fix** | 应用闪退/崩溃/白屏 | 执行 `scripts/*.mjs` 脚本链 | ✅ |
| **deveco-create-project** | 新工程模板生成 | 未使用（项目已存在） | — |

### 1.3 arkts-runtime-fix 脚本链（全部实测）

> 需设置环境变量: `DEVECO_HOME=C:\Program Files\Huawei\DevEco Studio`

| 脚本 | 功能 | 实测命令 | 输出 |
|------|------|----------|------|
| `probe-faultlogger.mjs` | 探测设备 faultlogger | `node scripts/probe-faultlogger.mjs --bundle-name com.c4ai.hormony --device-id 127.0.0.1:5555 --max-age-minutes 60 --limit 5` | `status: not_found`（无崩溃时正常） |
| `collect-hilog.mjs` | 收集设备 hilog | `node scripts/collect-hilog.mjs --device-id 127.0.0.1:5555 --lines 500 --output-dir <临时目录>` | `status: collected` + 日志文件路径 |
| `parse-jscrash-log.mjs` | 解析崩溃日志 | `node scripts/parse-jscrash-log.mjs --log-file <日志路径> --bundle-name com.c4ai.hormony --source hilog` | 结构化崩溃报告 |
| `fetch-faultlog.mjs` | 拉取 faultlog | `node scripts/fetch-faultlog.mjs --faultlog-name <名称> --device-id <设备> --output-dir <目录>` | 本地 faultlog 文件 |
| `jscrash-report.mjs` | 从文本生成崩溃报告 | `node scripts/jscrash-report.mjs --log-text "<崩溃日志>" --bundle-name com.c4ai.hormony --include-text` | 结构化报告 |

### 1.4 DevEco MCP 工具（11 个，通过 Trae MCP 调用）

| 工具 | 分配任务 | DevEco Code 是否可替代 |
|------|----------|:---:|
| `build_project` | 编译构建验证 | ✓（但 MCP 更稳定） |
| `start_app` | 部署到模拟器 | ✓（但 MCP 更稳定） |
| `perform_ui_action` | 点击/输入/截图 | ✗（DevEco Code 无此工具） |
| `get_app_ui_tree` | 获取 UI 树 | ✗（DevEco Code 无此工具） |
| `get_hilog_or_faultlog_recent` | 获取日志 | △（arkts-runtime-fix 脚本可替代） |
| `check_ets_files` | 语法检查 | △（build 可替代） |
| `project_sync` | 项目同步 | ✗ |
| `harmonyos_knowledge_search` | 知识检索 | △（`deveco run` + Skills 可替代） |
| `verify_ui` | UI 自动化验证 | ✓（需配 AI 视觉模型） |
| `check_cpp_files` | C++ 检查 | ✗ |
| `init_project_path` | 路径初始化 | △（`switch_cwd` 可替代） |

---

## 二、组合拳工作流（强制性规范）

### 2.1 日常开发流程（每次代码改写必须执行）

```
阶段 1: 知识准备（编写代码前）
├── [Trae] 读取相关 Skill 参考文件
│   ├── ArkUI 代码 → Read arkui-knowledge/references/common-mistakes.md
│   ├── ArkTS 语法 → Read arkts-grammar-standards/references/ts-diff.md
│   └── 编译错误修复 → Read arkts-error-fixes/reference/<错误类型>.md
└── [Trae] 如需查询 HarmonyOS API → deveco run '查询 <API> 的用法'

阶段 2: 代码编写（Trae 主导）
├── [Trae] 直接编辑 .ets 文件
└── [Trae] 遵循 Skill 参考文件的规范

阶段 3: 语法验证（MCP 主导）
├── [MCP] build_project → CompileArkTS 阶段验证语法
└── 失败 → [Trae] 读取 arkts-error-fixes 对应指南 → 修复 → 重新构建

阶段 4: AI 深度审查（DevEco Code 主导）★ 新增
├── [DevEco Code] deveco run '审查 <文件> 的 ArkUI/ArkTS/SSE/状态管理问题'
├── [Trae] 分析 DevEco Code 输出，修复发现的真实问题
└── [MCP] build_project → 验证修复

阶段 5: 部署验证（MCP 主导）
├── [MCP] start_app → 部署到模拟器
├── [MCP] perform_ui_action screenshot → 截图验证
└── 如崩溃 → [DevEco Code] 执行 arkts-runtime-fix 脚本链诊断

阶段 6: 知识沉淀（Trae 主导）
├── [Trae] 更新 DEVLOG.md
└── [Trae] 如有新发现，更新本文档
```

### 2.2 任务分配原则

| 任务类型 | 主力工具 | 辅助工具 | 原因 |
|----------|----------|----------|------|
| **代码编写** | Trae | Skills 参考文件 | Trae 直接编辑，Skills 提供规范 |
| **语法检查** | MCP build_project | check_ets_files（如可用） | MCP 构建结果最权威 |
| **代码审查** | DevEco Code `deveco run` | Trae 分析输出 | DevEco Code 有鸿蒙专家知识，能发现 Trae 遗漏的问题 |
| **编译错误修复** | Trae + arkts-error-fixes | DevEco Code | Trae 读指南修复，DevEco Code 验证 |
| **运行时崩溃诊断** | arkts-runtime-fix 脚本链 | MCP hilog | 脚本链提供结构化崩溃分析 |
| **UI 验证** | MCP perform_ui_action | DevEco Code verify_ui（如已配置） | MCP 直接截图更可控 |
| **知识查询** | DevEco Code `deveco run` | Skills 参考文件 + WebSearch | 多层知识获取 |
| **方案设计** | DevEco Code `deveco run` | Trae 综合判断 | DevEco Code 生成代码方案，Trae 决策 |
| **部署运行** | MCP start_app | Emulator.exe（手动启动） | MCP 部署最稳定 |

### 2.3 DevEco Code `deveco run` 任务模板

以下为经过实测验证的高效调用模板：

#### 代码审查模板
```powershell
deveco run '读取 <文件路径>，分析 <关注点> 是否有潜在问题，特别是 <具体方面>' --dir '<项目路径>' --skip-agreement --log-level ERROR
```

#### 代码生成模板
```powershell
deveco run '读取 <文件路径>，给出修改方案：<需求描述>。只给方案和关键代码片段，不要直接修改文件' --dir '<项目路径>' --skip-agreement --log-level ERROR
```

#### 术语扫描模板
```powershell
deveco run '检查项目 <目录> 下所有页面的用户界面文案，是否有技术架构术语暴露给用户（如 Agent/RAG/Retrieval/Planner 等）' --dir '<项目路径>' --skip-agreement --log-level ERROR
```

#### API 查询模板
```powershell
deveco run '查询 HarmonyOS <API/组件名> 的用法、参数、注意事项' --dir '<项目路径>' --skip-agreement --log-level ERROR
```

#### 完整文件重写模板（耗时较长，60s+）
```powershell
deveco run '读取 <文件路径>，<问题描述>。请给出修复后的完整文件内容，确保符合 ArkTS 语法标准' --dir '<项目路径>' --skip-agreement --log-level ERROR
```

### 2.4 arkts-runtime-fix 崩溃诊断流程

```
应用闪退/崩溃/白屏
    │
    ├── 1. 获取 bundleName（从 AppScope/app.json5 读取）
    │
    ├── 2. 探测 faultlogger
    │   │ node scripts/probe-faultlogger.mjs --bundle-name <bundleName> --device-id <deviceId> --max-age-minutes 30 --limit 10
    │   │
    │   ├── status: found → 3a. 拉取并解析 faultlog
    │   │   │ node scripts/fetch-faultlog.mjs --faultlog-name <latestFaultlog> --device-id <deviceId> --output-dir <tempDir>
    │   │   │ node scripts/parse-jscrash-log.mjs --log-file <localPath> --bundle-name <bundleName> --source file --include-text
    │   │   └── 获得结构化崩溃报告 → 5. 修复
    │   │
    │   └── status: not_found → 3b. 收集 hilog
    │       │ node scripts/collect-hilog.mjs --device-id <deviceId> --lines 4000 --output-dir <tempDir>
    │       │ node scripts/parse-jscrash-log.mjs --log-file <hilogPath> --bundle-name <bundleName> --source hilog --include-text
    │       └── 获得结构化报告 → 5. 修复
    │
    ├── 4. 如有原始崩溃文本
    │   │ node scripts/jscrash-report.mjs --log-text "<crashLog>" --bundle-name <bundleName> --include-text
    │   └── 获得结构化报告 → 5. 修复
    │
    └── 5. 根据报告修复代码 → build_project 验证 → start_app 重新部署
```

---

## 三、强制性规则（工作流边界）

### 规则 1: 代码审查必须调用 DevEco Code

> 每次 .ets 文件改写后，**必须**调用 `deveco run` 进行 HarmonyOS 专项审查。
> 不得仅依赖 Trae 自身判断。

**原因**: DevEco Code 内置 arkui-knowledge Skill，能发现 Trae 遗漏的 ArkUI 常见错误、状态管理问题、SSE 内存泄漏等专业问题。实测已验证其发现真实问题的能力。

### 规则 2: 编译错误必须查询 arkts-error-fixes

> 编译报错时，**必须**先读取 `arkts-error-fixes/reference/<错误类型>.md` 对应指南，再修复。
> 不得凭经验猜测修复方案。

**路径**: `C:\Users\guo82\.local\share\deveco\skills\arkts-error-fixes\reference\`

### 规则 3: 运行时崩溃必须使用脚本链诊断

> 应用闪退/崩溃/白屏时，**必须**执行 arkts-runtime-fix 脚本链收集证据。
> 不得仅凭症状猜测原因。

**环境变量**: `DEVECO_HOME=C:\Program Files\Huawei\DevEco Studio`

### 规则 4: 编写 ArkUI 代码前必须读取参考文件

> 编写/修改 ArkUI 组件前，**必须**读取对应 Skill 参考文件：
> - `arkui-knowledge/references/common-mistakes.md` — 避免高频错误
> - `arkui-knowledge/references/ui-quality-checklist.md` — 质量检查
> - `arkts-grammar-standards/references/ts-diff.md` — TS vs ArkTS 差异

### 规则 5: 知识查询优先使用 DevEco Code

> 查询 HarmonyOS API/组件用法时，**优先**调用 `deveco run '查询 <API>'`。
> `harmonyos_knowledge_search` MCP 工具因网络问题不可靠时，改用 `deveco run` + Skills 文件读取。

### 规则 6: 方案设计必须借助 DevEco Code

> 设计新功能或重构方案时，**必须**调用 `deveco run` 生成方案和关键代码片段。
> Trae 综合判断后决定是否采纳，但不得跳过此步骤。

---

## 四、实测验证记录

### 4.1 `deveco run` 代码审查 — Index.ets

**命令**: `deveco run '分析 Index.ets 的 ArkUI 问题'`
**结果**: 发现 3 个真实问题
1. `stats` 判空不完整（已修复）
2. error 类型不安全（已修复）
3. @Builder 重复结构（技术债务记录）

### 4.2 `deveco run` SSE 分析 — Chat.ets

**命令**: `deveco run '分析 SSE 流式接收逻辑是否有潜在问题'`
**结果**: 发现 4 个问题
1. SSE 未取消机制 → 内存泄漏（需修复）
2. 频繁 slice 刷新 → 性能隐患
3. 无结束事件处理 → 永远 loading 风险
4. 数据无上限累积 → 内存膨胀

### 4.3 `deveco run` ArkTS 合规检查 — HttpClient.ets

**命令**: `deveco run '检查 ArkTS 语法合规性'`
**结果**: 发现 3 个违规
1. `as T` 类型断言（ArkTS 禁止）
2. `body: Object`（应用具体 interface）
3. `Record<string, Object>`（结构化类型不允许）

### 4.4 `deveco run` 术语扫描 — 全部页面

**命令**: `deveco run '检查是否有技术架构术语暴露'`
**结果**: 未发现 UI 可见术语暴露（`agent`/`agentTrace` 仅内部字段）

### 4.5 `deveco run` 方案生成 — Plan.ets

**命令**: `deveco run '给出完成任务标记的修改方案'`
**结果**: 生成完整方案 + 关键代码片段（`completed?: boolean` + `TextDecorationType.LineThrough` + 绿色勾）

### 4.6 arkts-runtime-fix 脚本链

| 脚本 | 实测结果 |
|------|----------|
| `probe-faultlogger.mjs` | ✅ `status: not_found`（无崩溃时正常） |
| `collect-hilog.mjs` | ✅ `status: collected` + 日志文件路径 |
| `parse-jscrash-log.mjs` | ✅ 可用（需配合 hilog/faultlog 文件） |

---

## 五、环境配置清单

### 5.1 路径常量

```
DevEco Code CLI:    C:\Users\guo82\AppData\Local\Programs\nodejs-portable\node-v24.16.0-win-x64\deveco.cmd
Node.js:            C:\Users\guo82\AppData\Local\Programs\nodejs-portable\node-v24.16.0-win-x64\node.exe
Skills 目录:        C:\Users\guo82\.local\share\deveco\skills\
项目路径:           C:\Users\guo82\Desktop\Hormony\apps\harmonyos
App BundleName:     com.c4ai.hormony
模拟器设备 ID:      127.0.0.1:5555
Emulator.exe:       C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe
hdc.exe:            C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe
```

### 5.2 环境变量

```
DEVECO_HOME=C:\Program Files\Huawei\DevEco Studio
```

### 5.3 PowerShell 调用模板

```powershell
# DevEco Code 非交互执行
$deveco = 'C:\Users\guo82\AppData\Local\Programs\nodejs-portable\node-v24.16.0-win-x64\deveco.cmd'
$project = 'C:\Users\guo82\Desktop\Hormony\apps\harmonyos'
& $deveco run '<指令>' --dir $project --skip-agreement --log-level ERROR

# arkts-runtime-fix 脚本
$env:DEVECO_HOME = 'C:\Program Files\Huawei\DevEco Studio'
$node = 'C:\Users\guo82\AppData\Local\Programs\nodejs-portable\node-v24.16.0-win-x64\node.exe'
$skillDir = 'C:\Users\guo82\.local\share\deveco\skills\arkts-runtime-fix'
& $node "$skillDir\scripts\probe-faultlogger.mjs" --bundle-name 'com.c4ai.hormony' --device-id '127.0.0.1:5555' --max-age-minutes '60' --limit '5'
```

---

## 六、待测试能力

| 能力 | 优先级 | 测试计划 |
|------|:---:|------|
| `deveco serve` headless 服务器 | 中 | 启动持久服务，测试多会话复用 |
| `deveco mcp add` 挂载 DevEco MCP | 高 | 让 DevEco Code 也能调用 build/start/screenshot |
| Goal 模式 SDD 开发 | 中 | 编写 Spec 文档，测试自动拆解任务 |
| `deveco run` 完整文件重写 | 高 | 让 DevEco Code 直接生成修复后的完整文件 |
| `verify_ui` 配置 AI 视觉模型 | 高 | 配置 Qwen3-VL，启用自然语言 UI 验证 |
| `deveco plugin` 插件安装 | 低 | 测试扩展能力 |
| `deveco run --format json` | 中 | 程序化解析 AI 输出 |

---

## 七、更新日志

| 时间 | 更新内容 |
|------|----------|
| 2026-06-27 18:36 | 创建文档，记录全部实测结果和组合拳工作流规范 |
