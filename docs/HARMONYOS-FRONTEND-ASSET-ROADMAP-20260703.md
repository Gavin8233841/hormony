# 鸿学伴 HarmonyOS 前端资源落地路线（2026-07-03）

本路线把深猎资源转成 HarmonyOS 端侧可执行批次。默认边界：API 12 不升级，ArkUI 原生优先，不引入未经验证的依赖，不提交外部大资产，不修改 Web Agent、API、安全和端侧持久层核心结构。

## 一、执行原则

1. P0 只使用现有源码与 ArkUI 原生能力。
2. 第三方依赖只在独立 proof 分支一次验证一个包，主线不直接写入 `oh-package.json5`。
3. 所有素材先建账，再进入 `.tmp/` 视觉比对；没有构建和运行证据前不进 `resources/`。
4. 所有正反馈由真实端侧学习事件触发，不使用演示静态数据。
5. 需要修改核心端侧公共层、页面架构或依赖时，由 Codex 主线程执行；Trae 做独立页面内 UI 与只读审计。

## 二、P0：2-3 周内主线可落地

| 批次 | 目标 | 文件边界 | 实现方式 | 负责人边界 | 验收 |
|---|---|---|---|---|---|
| P0-1 | Chat Markdown 与代码块 V2 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` | 扩展现有 `MarkdownBlock` 和 `MarkdownContent()`：语言条、行号、横向滚动、引用块、表格横滚、行内代码、安全折叠 | Codex 主线程。该文件含 SSE、历史、本地存储和模型输出渲染，不交给并行代理直接改 | HAP 构建；长代码、表格、引用、失败消息截图 |
| P0-2 | 长任务阶段反馈统一 | `apps/harmonyos/entry/src/main/ets/common/Builders.ets`、`Quiz.ets`、`Plan.ets`、`Chat.ets` | 把 `StagedProgress` 扩成支持成功、失败、重试、保留输入的组件 | Codex 主线程改 `Builders.ets`；Trae 可只读列出页面文案 | 断网、4xx、5xx、取消路径不清空输入 |
| P0-3 | Quiz 出题等待与复盘下一步 | `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`、`Practice.ets` | 出题阶段文案学习化；结果页按低分标签给“复盘错题、学主题、再练、追问” | Codex 主线程。涉及答题与本地画像写入 | 构建通过；本地题、AI 题、低分、高分流程截图 |
| P0-4 | 标签掌握三档 | `Profile.ets`、`ActivityRecords.ets` | 使用 `TagInsight.totalQuestions`、`accuracy`、`wrongQuestions`、`lastPracticedAt` 推导待巩固、熟练、稳定 | Trae 可在页面内实现展示；Codex 复核数据规则，不改 schema | 空数据、少数据、全对、全错、多标签截图 |
| P0-5 | 学习星图一跳关系 | `LearningMap.ets` | 增加前置、后继、当前推荐高亮；箭头方向；线型图例；锁定原因 | Codex 主线程。页面涉及 DAG 语义和路由 | 三门课程截图，无标签重叠，横向滚动正常 |
| P0-6 | Lesson 互动卡强化 | `Lesson.ets` | 复用 `LessonExperience`、`LearningActivity`、`CodeRunPanel()`，把“入口-状态-出口”表达更强 | Codex 主线程设规则；Trae 可补充 `lesson-experiences.json` 数据但不得改页面架构 | 每门课程至少一个互动样例截图 |
| P0-7 | 按钮与图标语义统一 | `Constants.ets`、`Builders.ets`、各页面按钮 | 主动作、次动作、成功、风险、禁用状态统一；默认 `SymbolGlyph` | Codex 主线程改公共 Builder；Trae 可审计页面内不一致项 | 同类动作颜色和文案一致 |

## 三、P1：独立 proof 后采纳

| 方向 | proof 范围 | 文件边界 | 采纳条件 | 回退方案 |
|---|---|---|---|---|
| `@luvi/lv-markdown-in` | 单包安装、构建、Chat 长文本、表格、代码块、流式更新测试 | 独立 proof 分支，只改 `apps/harmonyos/entry/oh-package.json5` 与 proof 页面 | API 12 构建通过、模拟器截图、包体记录、依赖许可审计 | 保持 `Chat.ets` 原生 Markdown |
| `@ohos/lottie-turbo` | 单包安装、一个纯矢量 Lottie、播放/暂停/销毁 | 独立 proof 分支，不进主线资源目录 | API 12 构建、模拟器运行、真机生命周期证据、HAP 体积记录 | ArkUI `animateTo` / `keyframeAnimateTo` |
| 单个 Open Peeps 空态图 | 只选 1 张空态插画，建账并放 `.tmp/` 比对 | proof 后由 Codex 决定是否进 `resources/rawfile/` | 来源 URL、CC0、SHA-256、体积、渲染截图齐全 | 继续用 `SymbolGlyph` 空态 |
| 单个 Mixkit 音效 | 只选 1 个 300-800ms 成就音效 | proof 分支，不进主线 | 许可证、体积、可关闭入口、真机播放证据 | 无音效，仅视觉反馈 |

## 四、P2：后置研究

| 方向 | 后置原因 | 前置条件 |
|---|---|---|
| `@ohos/mpchart` 趋势图 | 首批标签洞察可用原生进度和列表完成 | 标签数据稳定，单包 proof 构建与截图通过 |
| `RichEditor` 学习笔记 | 当前产品重点是学习、练习、复盘 | Lesson、Practice、MistakeBook 闭环稳定 |
| 完整五档 mastery | 每 Topic 题量和复习记录要稳定 | 题库覆盖、复习包、错题回访稳定 |
| Rive 状态机动效 | API 12 原生运行链和社区素材授权未验证 | 官方运行链、授权、包体、真机证据齐全 |
| 音效体系 | 音效需要可关闭、低频、真实设备体验 | P1 单音效 proof 通过 |

## 五、Trae 可做范围

Trae 适合做独立、可复核、低冲突任务：

| 任务 | 文件范围 | 输出要求 |
|---|---|---|
| 页面内只读审计 | `apps/harmonyos/entry/src/main/ets/pages/*.ets` | 列出按钮、空态、加载态、图标语义不一致项，不改核心 |
| 标签洞察 UI 草案 | `Profile.ets`、`ActivityRecords.ets` | 仅页面内展示，不能改 `LocalLearningRepository.ets` 或 schema |
| Lesson 数据扩充 | `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json` | 每条记录字段完整，来源清楚，不改页面架构 |
| 资源许可证审计 | docs 独立报告 | URL、许可证、作者、体积、风险、证据等级 |
| 视觉验收脚本数据整理 | `screenshots/` 证据目录和独立报告 | 不提交截图，记录设备、分辨率、页面、结论 |

## 六、必须 Codex 主线程做范围

| 任务 | 原因 |
|---|---|
| 修改 `apps/harmonyos/entry/src/main/ets/common/Builders.ets` | 公共 Builder 会影响多页面 |
| 修改 `Constants.ets` 设计令牌 | 全局视觉和状态语义 |
| 修改 `Chat.ets` SSE 渲染、Markdown、历史存储 | 涉及模型输出、安全展示和本地历史 |
| 修改 `Quiz.ets` / `Practice.ets` 答题与复盘闭环 | 涉及评分、本地画像、错题写入 |
| 修改 `LearningMap.ets` DAG 语义 | 涉及先修关系、推荐、锁定逻辑 |
| 修改 `LocalLearningRepository.ets`、`DataModels.ets` | 端侧持久层与 schema |
| 写入 `oh-package.json5` 依赖 | 依赖、包体、许可证和 API 12 构建责任 |
| 复制素材到 `resources/` | 版权、包体、构建和运行责任 |

## 七、文件级路线

| 文件 | 当前基础 | 下一步 |
|---|---|---|
| `common/Constants.ets` | 已收口色彩、半径、动画时长 | 增加语义色分组文档，不盲目扩色 |
| `common/Builders.ets` | 已有 `StagedProgress`、`AnswerOption`、`ReviewDetailRow` | 增加统一按钮、状态提示、阶段失败恢复 Builder |
| `pages/Chat.ets` | 已有 Markdown 本地解析、阶段进度、回答生成过程 | 代码块 V2、引用块、表格横滚、行内代码、代码学习入口 |
| `pages/Quiz.ets` | 已有出题、评分、结果复盘、`StagedProgress` | 等待态学习化、低分标签下一步动作、结果页正反馈 |
| `pages/Practice.ets` | 已有本地练习和复盘 | 10 分钟复习包、错题/未练/回访透明排序 |
| `pages/LearningMap.ets` | 已有节点、边、状态、推荐、详情卡 | 一跳邻域、箭头、线型图例、外环编码 |
| `pages/Lesson.ets` | 已有互动练习、代码推演器、现实案例 | 组件边界收紧、每门强样例、反馈文案统一 |
| `pages/Profile.ets` | 已有标签洞察和学习图谱入口 | 三档掌握标签、样本数、错题数、下一步 |
| `pages/ActivityRecords.ets` | 已有事件和标签洞察 | 周目标、标签筛选、到期复习入口 |
| `pages/Achievements.ets` | 已有成就进度 | 原生轻动效，真实事件触发 |
| `pages/Knowledge.ets` | 已有知识检索 | 一跳知识关联、引用材料、下一练习 |
| `widget/pages/LearningPlanCard.ets` | 已读取 ArkData 当天计划，但仍存在直接色值 | 后续由 Codex 收口到端侧设计令牌或资源色值 |

## 八、验证路线

| 层级 | 命令或证据 | 本轮状态 |
|---|---|---|
| 静态检查 | `cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` | 本轮未执行，未改源码 |
| 模拟器视觉 | DevEco MCP UI 树和截图 | 本轮未执行 |
| 真机 | 设备型号、方向、分辨率、截图或日志 | 未验证 |
| 第三方依赖 | 单包安装、构建、包体、许可证、运行截图 | 未验证 |
| 素材 | URL、许可证、SHA-256、体积、构建、渲染 | 未验证 |

当前 rawfile 基线：`knowledge-chunks.json` 147 条，`lesson-experiences.json` 33 条，`quizzes.json` 165 条，`topic-relations.json` 33 条，`external-resources.json` 36 条。以上数量为源码确认，不代表内容质量或视觉运行通过。

## 九、禁止事项

- 不把 canvas-confetti、SpinKit CSS、Zustand、Comlink、BlurHash、web-vitals 等 Web 资源复制进 HAP。
- 不用 ArkWeb 承载 Markdown 主体验、庆祝动效或图谱。
- 不执行任意用户代码，不把“推演器”写成远程运行。
- 不整包引入图标、插画、音效或字体。
- 不把 registry 元数据写成构建通过或真机通过。
- 不升级 `compatibleSdkVersion` / `targetSdkVersion`。

## 十、下一次可执行工单

1. Codex 主线程：`Chat.ets` 代码块 V2 与表格横滚。
2. Codex 主线程：`LearningMap.ets` 一跳关系、箭头和图例。
3. Trae 页面任务：`Profile.ets` 与 `ActivityRecords.ets` 三档标签 UI 草案。
4. Codex 主线程：`Quiz.ets` 等待态和结果下一步动作。
5. Trae 数据任务：每门课补 1 个高质量 `lesson-experiences.json` 互动样例。
6. Codex proof：`@luvi/lv-markdown-in` 单包验证，不合格立即回退原生 Markdown。
7. Codex 小修：`LearningPlanCard.ets` 色值收口，避免服务卡片与主 App 设计令牌漂移。
