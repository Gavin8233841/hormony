# 鸿学伴端侧前端资源猎采审计（2026-07-02）

本轮目标不是换色，而是为 HarmonyOS ArkUI 端侧学习体验建立可执行的资源地图。当前仓库基线为：`apps/harmonyos/oh-package.json5` 与 `apps/harmonyos/entry/oh-package.json5` 依赖为空；`Chat.ets` 已有手写 Markdown 分块；`Quiz.ets`、`Plan.ets` 已复用 `StagedProgress`；`LearningMap.ets` 已用 ArkUI `Stack`、`Line`、节点光晕和静态星点实现学习星图；`Profile.ets`、`ActivityRecords.ets` 已有标签洞察。以上为**源码确认**。

本轮未下载任何外部资源，未写入 `.tmp/`，未改依赖文件，未提交二进制资产。所有资源在进入 HAP 前仍需单独验收；没有模拟器或真机证据的项目统一标为**未验证**。

## 采用原则

1. P0 优先使用 ArkUI 原生组件、HarmonyOS 系统 Symbol、现有 `Constants.ets` 颜色和公共 Builder。
2. 第三方资源只作为补缺：系统 Symbol 覆盖不了的教育/代码语义图标、空态插画、成就动效、成熟 Markdown/代码块渲染。
3. 许可证必须逐项记录 URL、许可名称和限制；没有本轮可访问许可证页或包源 502 的资源不进入实现。
4. SVG、Lottie、图片若需要检查，只能放入 `.tmp/`；本轮未下载，后续也不得提交 `assets/`、压缩包或许可证不清楚素材。
5. 视觉资产服务学习行为：解释、练习、反馈、复盘、计划和仪式感；不为装饰单独引入依赖。

## P0：无需新增依赖的端侧资源

| 资源/模式 | 来源链接 | 许可/商用风险 | ArkUI 适配方式 | 适合页面 | 优先级 | 落地成本 | 验证状态 |
|---|---|---|---|---|---|---|---|
| HarmonyOS Design 与系统组件语言 | [HarmonyOS Design](https://developer.huawei.com/consumer/cn/design/)；[ArkUI 文档索引](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/atomic-services) | 平台设计规范与系统能力，不复制第三方资产；不得把 Apple/Material 资产搬入 HAP | 继续收口到 `Constants.ets`、`Builders.ets`；页面内只复用 token、`SymbolGlyph`、`Progress`、`LoadingProgress` | 全局 | P0 | 低 | 来源已打开；本项目为源码确认 |
| 原生进度反馈 | [ArkUI Progress](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-progress-V5) | 平台组件，无额外素材许可 | 保留 `StagedProgress`，扩展为“阶段 + 骨架 + 成功/失败后动作”；不要只显示旋转加载 | `Quiz.ets`、`Plan.ets`、`Chat.ets`、`Knowledge.ets` | P0 | 低 | 来源已打开；现有实现为源码确认 |
| 原生 Canvas/Path/Line 图形 | [CanvasRenderingContext2D](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-canvasrenderingcontext2d?ha_source=zxqy-IT&ha_sourceId=89000468)；[Path2D](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-components-canvas-path2d) | 平台组件，无额外素材许可 | 当前 `LearningMap.ets` 已用 `Stack`/`Line`；下一步可补方向箭头、局部焦点图、节点大小编码，不引入图谱库 | `LearningMap.ets`、`Lesson.ets` 概念结构图 | P0 | 中 | 来源已打开；现有星图为源码确认 |
| 原生关键帧/显式动画 | [ArkUI 动画](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkui-animation-V5)；[keyframeAnimateTo](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-keyframeanimateto) | 平台组件，无额外素材许可 | 用于全对、解锁、连续学习、代码答对的 600-1200ms 小仪式；先做 `animateTo`/`keyframeAnimateTo`，不先上 Lottie | `Achievements.ets`、`Quiz.ets`、`Practice.ets`、`Lesson.ets` | P0 | 中 | 来源已打开；未进行视觉验收，本轮未验证 |
| GitHub Markdown/代码块展示范式 | [GitHub 代码块](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks)；[基础 Markdown](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax) | 作为交互参考，不复制 GitHub UI 或品牌资产 | 手写渲染至少支持标题、列表、引用、代码块、表格清洗、语言标签、等宽块、横向滚动；包源恢复后再比较 `@luvi/lv-markdown-in` | `Chat.ets`、`Lesson.ets` | P0 | 中 | 来源已打开；当前手写实现为源码确认 |
| GitHub review 逐行反馈结构 | [GitHub PR review](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/reviewing-proposed-changes-in-a-pull-request) | 作为交互参考，不复制 GitHub UI 或品牌资产 | 代码学习反馈可做“行号/片段/建议/追问”四段结构，先用于固定示例，不执行任意代码 | `Lesson.ets`、`Chat.ets`、`Practice.ets` | P0 | 中 | 来源已打开；未实现，未验证 |

## P1：许可清楚但需要审美与运行复核的可嵌入素材

| 资源 | 来源链接 | 本轮许可核验 | 商用/合规风险 | ArkUI 适配方式 | 适合页面 | 优先级 | 落地成本 | 验证状态 |
|---|---|---|---|---|---|---|---|---|
| Tabler Icons | [Tabler Icons LICENSE](https://github.com/tabler/tabler-icons/blob/main/LICENSE) | MIT；嵌入 SVG 时保留许可证文本 | 与 HarmonyOS 系统 Symbol 混用会造成图标语言不统一；只用于系统 Symbol 缺失的教育/代码图标 | 单个 SVG 放 `rawfile/icons/` 后用 `Image($rawfile(...))`；颜色需改为 `Constants.COLOR_BRAND` 对齐 | Lesson 活动类型、代码练习、资料类型 | P1 | 低 | 许可来源已打开；未下载，未验证 |
| Phosphor Icons | [Phosphor LICENSE](https://github.com/phosphor-icons/core/blob/main/LICENSE) | MIT；嵌入 SVG 时保留许可证文本 | 同上；避免和 Tabler 同时进入主图标体系 | 仅作为 Tabler 覆盖不足时的单图标补充 | 同上 | P2 | 低 | 许可来源已打开；未下载，未验证 |
| Lucide Icons | [Lucide LICENSE](https://github.com/lucide-icons/lucide/blob/main/LICENSE) | ISC；部分图标源自 Feather，许可证页列明 MIT 派生部分 | 线性风格与 Tabler 接近，但不应再引入第三套 | 不建议与 Tabler 并行；仅记录为备用来源 | 同上 | P2 | 低 | 许可来源已打开；未下载，未验证 |
| Iconoir | [Iconoir LICENSE](https://github.com/iconoir-icons/iconoir/blob/main/LICENSE) | MIT；嵌入 SVG 时保留许可证文本 | 图标较多但风格更设计化；需逐图审美复核 | 只取极少数系统 Symbol 没有的“脑图/网络/终端”类图标 | LearningMap、Lesson、Knowledge | P2 | 低 | 许可来源已打开；未下载，未验证 |
| Open Peeps | [Open Peeps](https://www.openpeeps.com/)；[CC0](https://creativecommons.org/publicdomain/zero/1.0/) | 官网声明 CC0，可个人和商业使用 | 手绘人物风格与当前学习工具调性不一致时不得进入主线；不得替代真实内容 | 可用少量 SVG/PNG 做空态：无错题、无成就、无资料；先放 `.tmp/` 视觉比对 | `MistakeBook.ets`、`Achievements.ets`、`Knowledge.ets` | P1 | 中 | 许可来源已打开；未下载，未验证 |
| unDraw | [unDraw License](https://undraw.co/license) | 允许商业/个人项目免费使用，但禁止打包再分发、复刻服务、AI/ML 训练等 | 不是开源许可证；如果素材成为应用核心卖点或被批量收录，风险升高；包含品牌 logo 的图不使用 | 只用于少量空态插画；记录具体 SVG URL 和下载日期 | 空态、引导页、错误页 | P2 | 中 | 许可来源已打开；未下载，未验证 |
| ManyPixels Free Illustrations | [ManyPixels Gallery](https://www.manypixels.co/gallery) | 允许商业/个人使用，禁止复刻服务或打包再分发 | 不是 OSI 开源许可证；不可批量收录；需记录具体素材 URL | 与 unDraw 二选一，不混用；只用于空态 | 空态、轻量说明页 | P2 | 中 | 许可来源已打开；未下载，未验证 |
| LottieFiles 免费动画 | [Lottie Simple License](https://lottiefiles.com/page/license) | 允许下载、修改、发布、商业使用；要求同许可条款随文件展示/分发，禁止汇编复刻服务 | 每个动画仍需记录具体作者/页面；HarmonyOS 渲染链未通过；过度动画会喧宾夺主 | 仅在 `@ohos/lottie-turbo` 或原生 Lottie 真机通过后用于全对/成就；优先先做原生关键帧 | `Quiz.ets`、`Achievements.ets` | P2 | 中-高 | 许可来源已打开；未下载；渲染未验证 |

## P1：OHPM 方向，本轮包源未验证

2026-07-02 本机 `ohpm --version` 为 `26.0.0.410`。执行 `ohpm info @luvi/lv-markdown-in`、`ohpm info @ohos/lottie-turbo`、`ohpm info @ohos/lottie`、`ohpm info @ohos/mpchart` 均返回 `GET https://ohpm.openharmony.cn/ohpm/... 502( Bad Gateway )`，命令退出码均为 1。因此下表只记录后续复核路线，不记录本轮许可通过结论。

| 包/能力 | 本轮状态 | 使用条件 | 适合页面 | 优先级 | 落地成本 | 验证状态 |
|---|---|---|---|---|---|---|
| `@luvi/lv-markdown-in` | 包源 502，许可与版本本轮未核验 | 包源恢复后：`ohpm info` 记录版本/许可证；单独分支安装；API 12 构建；SSE 增量、长正文滚动、代码块、表格、公式分别验收 | `Chat.ets` | P1 | 中 | 未验证 |
| `@ohos/lottie-turbo` | 包源 502，许可与版本本轮未核验 | 包源恢复后单独验证 native 依赖、模拟器渲染、真机渲染、生命周期暂停/恢复；通过前不写依赖 | `Achievements.ets`、`Quiz.ets` | P1 | 中-高 | 未验证 |
| `@ohos/lottie` | 包源 502，许可与版本本轮未核验 | 仅作为 `lottie-turbo` 不可用时的备选；同样需要真机 | 同上 | P2 | 中-高 | 未验证 |
| `@ohos/mpchart` | 包源 502，许可与版本本轮未核验 | 当前先不用；Profile 的正确率、标签、连续学习用 ArkUI `Progress`、`Canvas` 或 `DataPanel/Gauge` 原生方案 | `Profile.ets` | P2 | 高 | 未验证 |

## 明确不采用或仅作参考

| 资源 | 原因 | 结论 |
|---|---|---|
| Apple SF Symbols | [Apple SF Symbols](https://developer.apple.com/sf-symbols/) 是 Apple 平台符号库，适合研究“语义搜索、分层渲染、符号动效”，但不作为 HarmonyOS HAP 素材来源 | 仅作图标语义与动效参考 |
| Material Design 组件资源 | [Material Progress](https://m3.material.io/components/progress-indicators/overview) 与 [Snackbar](https://m3.material.io/components/snackbar/overview) 页面需 JS，能作为产品模式参考；不复制 Material 资产 | 仅作反馈模式参考 |
| Web 状态库/CSS 动画/React 资源 | 与独立 HAP 无关，已被 `docs/FRONTEND-RESOURCE-ADOPTION.md` 否决 | 不进入 HAP |
| 许可证页不可访问的图标、插画、动效 | 无法记录精确许可与限制 | 不进入实现 |
| 任意代码运行 Web 沙盒 | 当前项目只做确定性代码阅读/预测/自评，不执行任意用户代码 | 不进入本阶段 |

## 页面级资源落地清单

### Lesson：从纯文字到“概念玩具 + 主动练习”

- 使用 ArkUI 原生：`Canvas`/`Line` 画栈、队列、树旋转、TCP 状态迁移等结构小图；`TextArea` 保留“先写推演，再对照答案”的低风险练习。
- 借鉴 Brilliant 与 Duolingo Math：每个概念至少一个可操作对象，不只给定义段落。Brilliant 强调视觉互动和分步问题；Duolingo Math 公开说明用可操作工具帮助理解钟表等概念。
- 可用素材：无需第三方；如空态需要人物插画，优先 Open Peeps 单张 CC0。
- 本轮验证：源码确认已有 `MasteryBrief`、`CodeBlock`、主动练习；新增图形玩具未实现，未验证。

### Chat：Markdown、代码块和引用

- 使用 GitHub Markdown 作为最低渲染目标：标题层级、列表、引用、代码块语言标签、表格清洗、等宽字体、空行节奏。
- 代码块不只“深色背景”：补语言条、长代码横向/纵向滚动、输出/解释分区、追问入口。
- `@luvi/lv-markdown-in` 只在包源恢复并完成 API 12 构建与流式验收后评估；当前继续收口手写渲染，不猜 API。
- 本轮验证：`Chat.ets` 手写分块为源码确认；第三方 Markdown 未验证。

### Quiz / Plan：长任务反馈

- 当前 `StagedProgress` 已覆盖生成题目、评分、计划生成阶段。下一步把“阶段”改成可恢复动作：失败后保留输入、提供重试；成功后显示下一步。
- 可用资源：ArkUI `Progress`、`LoadingProgress`、骨架块；不需要 SpinKit、CSS 动画或 Lottie。
- 本轮验证：现有 `Quiz.ets`、`Plan.ets` 为源码确认；增强未实现，未验证。

### LearningMap：星图升级为可读知识图

- 参考 Obsidian Graph：节点代表知识，线代表内部关系；节点大小、线方向、筛选、局部图、悬停/点击高亮都有明确含义。
- 当前 `LearningMap.ets` 已有真实先修边、节点状态、Level 行和选中标签。下一步不是加更多光晕，而是补：方向箭头、选中节点的一跳邻居、前置/后继分组、掌握度和错题数双编码。
- 可用资源：ArkUI `Line`/`Path`/`Canvas`，无需 D3 或 WebView。
- 本轮验证：现有星图为源码确认；增强未实现，未验证。

### Profile / ActivityRecords / MistakeBook：标签洞察

- 参考 Khan Academy Mastery：标签不要只显示正确率，应显示“未开始/尝试/熟悉/熟练/掌握”一类层级变化和复习条件。
- 当前 `TagInsight` 已按标签统计题数、正确率、错题数、最近时间。下一步可映射为掌握层级和下一次复习建议。
- 可用资源：原生 `Progress`、环形 `Progress`、小标签；不需要 `mpchart`。
- 本轮验证：现有标签洞察为源码确认；层级映射未实现，未验证。

### Achievements：学习闭环仪式感

- 优先原生关键帧：全对、连续学习、解锁成就使用小范围动画，不抢走复盘内容。
- Lottie 只用于成就解锁或全对反馈，必须先证明包源、构建、模拟器、真机都通过。
- 可用素材：LottieFiles 具体动画需逐条记录；本轮不下载。
- 本轮验证：现有成就页为源码确认；新仪式动画未实现，未验证。

## 后续复核步骤

1. 包源恢复后只读执行：`ohpm info @luvi/lv-markdown-in`、`ohpm info @ohos/lottie-turbo`，记录版本、许可证、依赖链、发布时间。
2. 若引入 OHPM 包，单独分支一次只引入一个包，执行 `apps/harmonyos` 增量构建、模拟器启动、目标页面 UI 树、截图和真机验收。
3. 若使用 SVG/插画/Lottie，先放 `.tmp/frontend-asset-hunt-YYYYMMDD/`，记录原始 URL、许可证 URL、下载日期、文件哈希、页面用途；通过复核前不得复制到资源目录。
4. 每个素材进入 HAP 前必须补 `docs/FRONTEND-RESOURCE-ADOPTION.md`，并给出“为什么系统 Symbol/ArkUI 原生能力不足以完成”的说明。
