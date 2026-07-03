# 鸿学伴端侧前端资源采用规格（2026-07-02）

本规格把资源猎采结论转成可交给 Codex 主线实施的模块规格。默认目标仍是 HarmonyOS API 12、ArkTS 静态类型、ArkUI 原生优先、端侧本地数据为持久状态源。

## 通用规则

1. 不新增依赖即可完成的体验优先用 ArkUI 原生实现。
2. 每次只引入一个第三方依赖；必须先补许可证、版本、维护状态、包体、API 12 构建、模拟器或真机证据。
3. 任何 SVG、PNG、Lottie、音效、字体进入 HAP 前必须建账：具体 URL、作者、许可证 URL、下载日期、文件哈希、用途、体积。
4. UI 文案不暴露 Agent/RAG/Retrieval 等技术词；学生看到的是“回答生成过程”“复习建议”“下一步”。
5. 所有正反馈由真实本地事件触发；不得用静态演示数据制造完成、掌握或成就。

## 规格 1：Chat Markdown + 代码块 V2

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` |
| 现有基础 | `markdownBlocks(content)`、`MarkdownContent(content, failed)`、`MessageBubble()`、`AgentWorkbench()` |
| 数据输入 | 模型 SSE 拼接后的 `DisplayMessage.content`、`citations`、`agentTrace` |
| 资源依据 | GitHub Markdown/GFM、GitHub PR Review、Codecademy 代码学习布局、ArkUI `Scroll`/`Text`/`Row`/`Column` |
| 不引入项 | `FluidMarkdown`、`@luvi/lv-markdown-in`、`RichText` 直接渲染模型 HTML、ArkWeb |

### 结构要求

- `MarkdownBlock` 至少能表达：`type`、`text`、`language`、`lines`、`listLevel`、`quoteLevel`、`tableColumns`、`tableRows`。
- 代码块：
  - 顶部语言条，没有语言时显示“代码片段”。
  - 左侧行号列固定宽度。
  - 代码正文横向滚动，长行不撑破气泡。
  - 下方动作：“解释这段”，预填片段上下文，不自动发送。
- 引用块：左边线 + 浅色背景 + 正文，不显示原始 `>`。
- 表格：表头和行分开渲染；小屏允许横向滚动；不显示 `| --- |`。
- 列表：有序/无序都保留层级缩进；嵌套深度必须设上限。
- 行内样式：先处理粗体、行内代码、链接文本白名单；链接不自动外跳。

### 验收

- 长代码、表格、引用、列表、失败消息各一条截图。
- Chat SSE 增量期间不闪烁、不跳到底部之外。
- 大文本行数、代码行数、表格列数超过边界时降级为安全文本或折叠。
- 证据等级落地后至少达到构建通过；模拟器截图后才可写模拟器通过。

## 规格 2：长任务生成进度与恢复

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/common/Builders.ets`、`apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`、`apps/harmonyos/entry/src/main/ets/pages/Plan.ets` |
| 现有基础 | `StagedProgress(title, subtitle, activeIndex, steps)`、`Quiz.GenerationProgress()`、`Quiz.ScoringProgress()`、`Plan.runLocalProgress()` |
| 资源依据 | HarmonyOS `Progress`、`LoadingProgress`；成熟产品的阶段反馈和失败恢复 |
| 不引入项 | SpinKit CSS、Web 动画库、Lottie 作为普通加载 |

### 结构要求

- 阶段卡显示：主标题、当前阶段、已完成步骤、下一步说明。
- 失败态显示：错误码或业务状态、保留输入、重试、返回编辑。
- 成功态显示：完成摘要和下一动作，不只停留在“已完成”。
- `Quiz` 出题和评分使用同一视觉语言；`Plan` 生成计划复用同一阶段组件。

### 验收

- 断网、4xx、5xx、取消请求路径不清空用户输入。
- 进度条不会超过实际阶段可解释范围；未知时使用活动指示，已知流程使用阶段条。
- 不把请求取消显示为业务错误。

## 规格 3：标签化洞察与掌握等级

| 项目 | 内容 |
|---|---|
| 目标文件 | `LearningMetadataModels.ets`、`LocalLearningRepository.ets`、`Profile.ets`、`ActivityRecords.ets`、`Quiz.ets`、`Practice.ets`、`MistakeBook.ets` |
| 现有基础 | `LearningTagInsight`、`TagInsightRow()`、`ReviewDetailRow()`、错题 `ReviewItem.tags` |
| 资源依据 | Khan Academy Mastery levels / Mastery Challenges |
| 不引入项 | `@ohos/mpchart`、第三方图表库 |

### 等级规则

首批不改 schema，可从现有字段推导：

| 等级 | 推导建议 | 展示 |
|---|---|---|
| 未开始 | 本地无该标签答题记录 | 灰色状态 + “先完成 2 题建立基线” |
| 尝试 | `totalQuestions > 0` 且样本不足或正确率低 | 样本数、错题数、再练入口 |
| 熟悉 | 正确率达到中段且仍有错题 | 正确率、最近难度、复习建议 |
| 熟练 | 正确率高、样本数足够、错题少 | 下一步挑战题或复盘 |
| 掌握 | 正确率高且最近练习稳定 | 保持复习时间，不继续堆题 |

### UI 要求

- 标签行必须同时显示等级文本、进度条、样本数、错题数、最近练习时间或下一步。
- 颜色不能作为唯一信息，必须有文字说明。
- `Quiz` / `Practice` 结果页对低分标签显示下一步动作，直达已有页面。
- `MistakeBook` 默认按最弱标签或到期复习分组。

### 验收

- 空数据、单题、多题、全对、全错五种本地数据状态截图。
- 所有数据来自 `QuizResult.details.tags`、`ReviewItem.tags` 或 `TopicMastery`，不使用静态标签。

## 规格 4：学习星图关系视觉语言

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets` |
| 现有基础 | `MapNode`、`MapEdge`、`MapCanvas()`、四状态图例、详情卡、横向滚动 |
| 资源依据 | Obsidian Graph、Obsidian Canvas、Khan Mastery、Duolingo Path、ArkUI `Line`/`Path`/`Progress` |
| 不引入项 | D3、WebView 图谱、第三方图谱库、粒子背景素材 |

### 视觉编码

| 维度 | 编码 |
|---|---|
| 颜色 | 掌握状态：可开始、已学习、学习中、已掌握 |
| 大小或外环 | 练习次数、错题量或掌握强度，二选一先落地 |
| 方向 | 箭头从先修指向后继 |
| 透明度 | 选中节点的一跳邻域高亮，非邻域降透明 |
| 线型 | 已解锁路径强，锁定路径弱；线型含义写入图例 |
| 详情卡 | 当前主题、前置主题、后继主题、推荐原因、下一动作 |

### 验收

- 选中任一节点后，截图中必须能区分前置、后继、当前推荐、锁定原因。
- 图例解释颜色、大小/外环、箭头、线型。
- 标签不重叠；横向滚动不截断详情卡。
- 数据来自 `TopicRelation.prerequisiteIds`、`TopicMastery`、`LessonProgress`。

## 规格 5：Lesson 概念玩具与固定示例推演

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets` |
| 现有基础 | `MasteryBrief()`、`MasterySignal()`、`CodeBlock()`、活动题、标准答案 |
| 资源依据 | Brilliant 视觉互动、Duolingo Math 可操作工具、Mimo/Codecademy 短练习 |
| 不引入项 | 任意用户代码执行、Web IDE、远程判题 |

### 首批主题建议

- 数据结构：栈入栈出、队列、二叉树遍历。
- 操作系统：进程调度时间线、死锁资源分配图。
- 计算机网络：TCP 三次握手、重传计时。

### UI 要求

- 每张概念卡只有一个主操作：选择、排序、拖动或揭示。
- 提交后显示：你的推演、标准答案、差异点、下一题。
- 代码学习文案使用“推演”“对照”“预测输出”，不使用会暗示执行任意代码的文案。

### 验收

- 每门课程至少一个概念玩具截图。
- 小屏文字不溢出；长代码区可滚动；输出区始终可见。

## 规格 6：正反馈动画与声音边界

| 项目 | 内容 |
|---|---|
| 目标文件 | `Achievements.ets`、`Quiz.ets`、`Practice.ets`、`HomeContent.ets`、`Plan.ets` |
| 首选资源 | ArkUI 原生 `animateTo` / `keyframeAnimateTo`、`Progress`、`SymbolGlyph` |
| 后续资源 | LottieFiles 单动画、`@ohos/lottie-turbo` 或 `@ohos/lottie` 单包验证、Mixkit/Pixabay/Freesound 单音效 |
| 不引入项 | canvas-confetti、ArkWeb 庆祝动画、未验真 Lottie 包、未逐条授权音效 |

### 触发规则

- 全对、成就解锁、连续学习、当天任务完成可以触发轻量反馈。
- 错题复盘、低分结果不得播放庆祝动效；应强调下一步。
- 音效必须可关闭，默认先不进入 P0。

### 验收

- 动效不遮挡解析和下一步按钮。
- `@ohos/lottie-turbo` registry 元数据已确认 latest `1.0.12`、Apache-2.0、`compatibleSdkVersion: 12`，但依赖 `liblottie-turbo.so`；真机未验证前，Lottie/OCR/TTS/音效都保持未验证。

## 规格 7：图标和按钮语义规范

| 项目 | 内容 |
|---|---|
| 目标文件 | `Constants.ets`、`Builders.ets`、所有页面按钮 |
| 默认资源 | HarmonyOS `SymbolGlyph` |
| 补充资源 | Tabler / Phosphor / Lucide / Iconoir 单 SVG，仅补系统符号缺口 |

### 按钮状态

| 状态 | 用途 | 要求 |
|---|---|---|
| 主动作 | 发送、提交、开始练习、生成计划 | 品牌色、动词明确、可加载 |
| 次动作 | 展开、查看详情、跳转资料 | 低强调，不抢主动作 |
| 成功动作 | 已完成、已掌握、提交成功 | 成功色 + 文本说明 |
| 风险动作 | 清空输入、放弃、删除单条记录 | 必须明确范围；本阶段尽量不新增删除动作 |
| 禁用 | 输入不足、请求中、无数据 | 不只降低透明度，要保留原因 |

### 图标规则

- 系统 `SymbolGlyph` 覆盖的功能不得引入第三方 SVG。
- 第三方 SVG 只允许单图，且必须记录许可证和文件哈希。
- 不同图标库不得混用在同一功能组。

## 规格 8：素材建账模板

任何素材进入 HAP 前，在文档中补一行：

| 字段 | 要求 |
|---|---|
| 素材名称 | 精确文件名 |
| 原始 URL | 具体素材页面，不是平台首页 |
| 许可证 URL | 具体许可证页面 |
| 作者/来源 | 页面公开记录 |
| 下载日期 | YYYY-MM-DD |
| 文件哈希 | SHA-256 |
| 文件大小 | 字节或 KB |
| 用途 | 具体页面和触发场景 |
| 替代方案 | 为什么系统 Symbol/ArkUI 原生能力不足 |
| 验证 | 构建、模拟器、真机、未验证 |

未完成建账的素材只能停留在 `.tmp/` 或文档参考，不得复制进 `apps/harmonyos/entry/src/main/resources/`。
