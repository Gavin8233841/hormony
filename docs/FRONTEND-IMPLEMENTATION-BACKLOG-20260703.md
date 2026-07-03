# 端侧前端产品化实施 Backlog（2026-07-03）

本 backlog 只安排文档研究后的可落地任务，不代表已经实现。每项任务都必须保持小批次、精确文件边界、构建和 UI 证据。

## P0：不新增依赖，直接提升学习效率

| 优先级 | 任务 | 文件边界 | 负责建议 | 资源依据 | 验收 |
|---|---|---|---|---|---|
| P0 | Chat 文案去技术化：把“多 Agent 工作台”等学生不可见技术词改成“回答生成过程/解题过程” | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` | 主线程 | GitHub/Primer 可扫描状态模式 | HAP 构建；Chat 页面 UI 树无 Agent/RAG/Retrieval 文案 |
| P0 | 代码块 V2：语言条、行号、横向滚动、片段追问入口 | `Chat.ets` | 主线程 | GitHub code blocks / PR review | 长代码截图不撑破气泡；预填追问不自动发送 |
| P0 | Plan/Quiz 失败恢复统一：保留输入、保留本地状态、明确重试 | `Plan.ets`、`Quiz.ets`、必要时 `Builders.ets` | 主线程 | 长任务反馈模式，现有 `StagedProgress` | 断网/4xx/5xx 手动或模拟路径 UI 验收 |
| P0 | LearningMap 方向箭头和局部邻域高亮 | `LearningMap.ets` | 主线程 | Canvas/Path2D 官方能力，Obsidian Graph 模式 | 截图可区分前置和后继；标签不重叠 |
| P0 | 标签掌握等级：从 `TagInsight` 推导尝试/熟悉/熟练/掌握 | `LocalLearningRepository.ets`、`LearningMetadataModels.ets`、`Profile.ets`、`ActivityRecords.ets` | 主线程 | Khan mastery levels | 本地记录驱动等级；无记录空态清楚 |
| P0 | Quiz/Practice 结果页下一步动作：复盘错题、学主题、再练 3 题 | `Quiz.ets`、`Practice.ets` | 主线程 | Khan 复习挑战 | 按低分标签生成动作，按钮直达已有页面 |

## P1：原生视觉和交互增强

| 优先级 | 任务 | 文件边界 | 负责建议 | 资源依据 | 验收 |
|---|---|---|---|---|---|
| P1 | Lesson 概念玩具第一批：栈/队列/树遍历/TCP 握手/进程调度任选每门 1 个 | `Lesson.ets`、必要时独立 Builder 文件 | 主线程设计，Trae 可补内容数据 | Brilliant 视觉互动、ArkUI Canvas/Path2D | 模拟器截图显示可操作控件和结构图 |
| P1 | 固定示例运行感：输入、状态表、输出、解释 | `Lesson.ets`、课程 rawfile 数据 | Trae 可补数据，主线程接 UI | Codecademy/Mimo | 不执行任意用户代码；输出来自结构化答案 |
| P1 | ActivityRecords 近 4-8 周热力图 | `ActivityRecords.ets` | Trae 可先做页面内 UI，主线程复核 | ArkUI Grid/Canvas | 空态、少量、多量数据截图 |
| P1 | 原生短动画：全对、连续学习、解锁成就 | `Achievements.ets`、`Quiz.ets`、`Builders.ets` | 主线程 | `keyframeAnimateTo` | 600-1200ms，不遮挡复盘 |
| P1 | 空态图标语义统一：先用 `SymbolGlyph` 梳理无错题、无记录、无成就、加载失败 | 多个页面，但逐页小批 | Trae 可逐页做，主线程复核 | SymbolGlyph 官方能力 | UI 树和截图证明状态清楚 |

## P2：需第三方资源或真机证据

| 优先级 | 任务 | 文件边界 | 负责建议 | 前置条件 | 验收 |
|---|---|---|---|---|---|
| P2 | `@luvi/lv-markdown-in` 单独验证分支 | `apps/harmonyos/entry/oh-package.json5`、独立 demo 页面或最小 Chat 包装 | 主线程 | OHPM `info` 成功；许可证记录；一次只引入这一个依赖 | API 12 构建、长 Markdown、代码块、表格、SSE 增量、远程图片禁用 |
| P2 | `@ohos/lottie` 单独验证分支 | 依赖文件、`resources/rawfile/lottie/`、最小成就 demo | 主线程 | OHPM `info` 成功；项目自绘 JSON 复核 | 构建、模拟器播放、真机帧率、页面销毁释放 |
| P2 | 触感反馈验证 | `module.json5` 权限、`Achievements.ets`/`Quiz.ets` | 主线程 | 真机可用；`ohos.permission.VIBRATE` 评估 | 真机通过，记录设备和效果 |
| P2 | Kenney CC0 短音效验证 | `resources/rawfile/sounds/`、最小播放封装 | 主线程 | 具体音频 URL、CC0、哈希、包体评估 | 真机静音模式、音量、延迟、无障碍 |
| P2 | 单张 Open Peeps / unDraw 空态插画 | 单页 rawfile 资源和许可证文档 | Trae 可调研单图，主线程决定 | 具体素材 URL 和许可证记录 | 截图确认风格一致，不批量引入 |

## 适合 Trae 的边界

| 可交给 Trae | 不交给 Trae |
|---|---|
| 逐页空态文案和 Symbol 语义梳理 | 依赖引入、OHPM、构建配置 |
| 课程概念玩具的数据结构草案 | `LocalLearningRepository` schema/持久层改动 |
| ActivityRecords 热力图页面内 UI 初稿 | 核心 Repository、Ability、导航底层 |
| 单张素材许可证调查文档 | 把素材放入产品资源目录 |
| 公开竞品模式补充研究 | Agent、API、模型、安全、RAG |

## 每批最小验证

### 文档或调研

- `git diff --check`
- `git status --short`

### HarmonyOS 页面改动

- `cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`
- DevEco MCP 或 `hdc` 安装运行
- UI 树和截图，注明设备、方向、分辨率、证据路径

### Web 或 API 改动

- `cd apps/web; pnpm lint`
- `cd apps/web; pnpm typecheck`
- `cd apps/web; pnpm test`
- `cd apps/web; pnpm build`

## 本轮不做

- 不新增 OHPM 依赖。
- 不下载第三方素材包。
- 不把 Web/CSS/React 动画带入 HAP。
- 不执行任意用户代码。
- 不修改 `DEVLOG.md`，以保持与主线程边界清晰；如主线程要求合入，再由主线程统一追加记录。
