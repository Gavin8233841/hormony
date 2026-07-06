# 鸿学伴端侧竞品与行业标准差距审计（2026-07-04）

本文在 `FRONTEND-RESOURCE-DEEP-HUNT-20260704.md`、`FRONTEND-IMPLEMENTATION-ACCEPTANCE-20260704.md` 基础上继续推进：把当前 HarmonyOS 源码与成熟学习产品、移动交互标准和可访问性标准对齐，形成“还差什么”的审计清单。本文只新增文档，不修改 `apps/harmonyos` 代码。

## 0. 当前状态复核

| 检查项 | 当前结论 | 证据等级 |
|---|---|---|
| 安全区机制 | 当前源码已有 `SafeAreaInsets`、`EntryAbility.configureSafeArea()`、`getWindowAvoidArea()`，并在 `Index.ets`、`Builders.ets`、`CourseDetail.ets`、`Knowledge.ets`、`LearningMap.ets`、`Lesson.ets`、`Plan.ets`、`Quiz.ets`、`Profile.ets`、`Practice.ets` 等页面消费 top/bottom 避让区 | 源码确认 |
| 旧安全区审计 | `docs/HARMONYOS-LAYOUT-AUDIT-2.md` 中“整个应用未使用任何安全区域适配 API”已不符合当前源码 | 源码确认 |
| 学生端技术词 | `Plan.ets` 仍有 UI 标题 `Agent 工作链`；`Chat.ets` 内部保留 `Retrieval`、`Tutor` 等字段，但展示函数已映射为学生可读文案 | 源码确认 |
| 触控目标 | 多处按钮和输入框高度仍低于 48vp，例如 `Profile.ets` / `Quiz.ets` 标签动作 30vp、`Chat.ets` 输入 44vp、`Plan.ets` 任务按钮 30vp、`HomeContent.ets` QuickAsk 38vp | 源码确认 |
| 视觉洞察 | 标签掌握值、弱因和下一步已有文字表达；雷达、热力、趋势仍未落地 | 源码确认 |
| 学习星图 | 已有 `MapNode`、`MapEdge`、`Line` 和节点双尺寸；仍缺方向箭头、一跳邻域和完整图例 | 源码确认 |
| 真机/模拟器 | 本轮未运行 HAP 构建、模拟器或真机验收 | 未验证 |

## 1. 外部标准对齐

| 标准 / 产品 | 来源 URL | 可转化要求 | 鸿学伴当前差距 |
|---|---|---|---|
| HarmonyOS 安全区与窗口避让区 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-window | 使用窗口避让区处理状态栏、刘海、手势条 | 源码已具备机制；仍需模拟器/真机截图证明 |
| WCAG 2.2 Target Size | https://www.w3.org/TR/WCAG22/#target-size-minimum | 可点击目标至少具备足够触控面积，并有间距或等效目标 | 多处 30-44vp 动作低于移动端常用 48vp 目标，需要统一提升或扩大命中区 |
| Material Design Progress Indicators | https://m3.material.io/components/progress-indicators/overview | 可确定进度用确定型，未知等待用活动型，避免伪造完成 | `StagedProgress` 已形成底座；仍缺断网/失败/取消截图 |
| Apple HIG Feedback | https://developer.apple.com/design/human-interface-guidelines/feedback | 每个操作应及时反馈，反馈不能遮挡任务本身 | Quiz/Plan/Chat 有阶段反馈；全对/低分/空态反馈仍需区分 |
| NN/g Skeleton Screens | https://www.nngroup.com/articles/skeleton-screens/ | 骨架屏适合降低等待焦虑，但必须匹配实际布局 | Course/Profile 有骨架；Quiz/Chat/Plan 的长任务更适合阶段 + 局部骨架组合 |
| Khan Academy Mastery | https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work | 技能掌握分层，复习挑战更新掌握状态 | 鸿学伴已有 `masteryLevel`，但缺可视化升降级和复习挑战呈现 |
| Duolingo Streak | https://blog.duolingo.com/how-duolingo-streak-builds-habit/ | 连续学习应建立习惯，并给明确里程碑 | Profile 已有连续天数；Home/服务卡片仍可强化当天目标完成仪式 |
| GitHub Markdown | https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks | 代码块语言名、围栏、可读层级 | Chat 已有代码块 V2 基础；表格/行内样式仍需增强 |
| Codecademy AI 学习反馈 | https://help.codecademy.com/hc/en-us/articles/23400751016859-AI-Features-available-on-Codecademy | AI 反馈应贴合当前任务、代码或答案上下文 | Chat/Quiz/Lesson 已有追问入口；Lesson 仍缺每门图形化概念玩具 |
| Obsidian Graph | https://help.obsidian.md/plugins/graph | 节点/边必须表达关系、筛选和局部邻域 | LearningMap 已有 DAG 底座；关系语义仍弱 |

## 2. 竞品成熟度评分

评分只用于排序，满分 5 分。分值依据当前源码和文档证据，不代表模拟器或真机通过。

| 维度 | 成熟产品参照 | 当前得分 | 已具备 | 缺口 |
|---|---|---:|---|---|
| 输入极简 | 夸克学习、ChatGPT、Codecademy AI | 4 | Chat / QuickAsk 输入、云端就绪状态、失败重试 | Chat 输入区触控 44vp；长回复流式阅读未完整验收 |
| 输出结构化 | GitHub Docs、Codecademy、Khan | 3 | Markdown 子集、代码块语言条、行号、引用与阶段 | 表格、行内样式、长代码滚动截图不足 |
| 掌握诊断 | Khan Academy | 4 | `masteryPoints`、`masteryLevel`、弱因、下一步 | 雷达、热力、趋势和复习挑战 UI 未完成 |
| 关系学习 | Obsidian Graph、Duolingo Path | 3 | LearningMap DAG、节点状态、推荐理由 | 方向箭头、一跳邻域、图例语义不足 |
| 习惯激励 | Duolingo、百词斩 | 3 | 连续学习、本地事件、成就进度 | 当天完成仪式、里程碑反馈、到期复习突出不足 |
| 互动学习 | Brilliant、Codecademy | 3 | Lesson 固定代码推演、活动证据写回、同标签测验 | 每门图形化概念玩具未落地 |
| 失败恢复 | Coursera、Material / Apple | 4 | Chat/Quiz/Plan 多处保留输入和重试 | 需要系统性断网/4xx/5xx/取消截图 |
| 可访问性 | WCAG 2.2、移动端 48vp 目标 | 2 | 安全区已有机制，部分文本有截断 | 多处触控目标偏小，大字体/屏幕阅读器未验收 |
| 资产合规 | 开源许可实践 | 4 | 已建立素材建账模板，未下载未授权素材 | 还未做单素材哈希和 HAP 渲染验证 |
| HarmonyOS 原生感 | HarmonyOS Design / ArkUI | 4 | 系统 Symbol、ArkUI 原生进度、安全区、本地状态 | 视觉洞察和正反馈仍偏列表化 |

## 3. 当前最值得修的 12 个缺口

| 优先级 | 缺口 | 当前证据 | 行业/竞品依据 | 建议处理 |
|---:|---|---|---|---|
| 1 | Plan 页面仍显示 `Agent 工作链` | `Plan.ets` `AgentTraceCard()` | 学生端应使用用户语言 | 改为 `计划生成过程` 或 `安排依据`，内部字段不动 |
| 2 | 多处触控目标小于 48vp | `rg` 命中 30-44vp 按钮/输入框 | WCAG 2.2、移动端可触控习惯 | P0 动作按钮提升到 48vp；小标签动作至少扩大命中区域 |
| 3 | Chat 表格仍未成体系 | `Chat.ets` 现有 `tableText()` 压成文本 | GitHub Markdown | 表格分表头/行，横向滚动或折叠 |
| 4 | Chat 行内样式仍偏清洗 | `cleanInline()` 删除 `**`、反引号 | GitHub Docs / Primer | 用白名单行内样式或 `StyledString` |
| 5 | LearningMap 边没有方向箭头 | `MapCanvas()` 只有 `Line()` | Obsidian Graph / 技能树 | 增加箭头和图例 |
| 6 | LearningMap 缺一跳邻域 | 选中节点只缩放当前节点 | Obsidian Graph | 高亮当前、前置、后继，弱化其他 |
| 7 | Profile 标签洞察仍是列表 | `TagInsightRow()` | Khan Mastery / 数据看板 | 原生 Canvas 雷达或 Top 3 错因总览 |
| 8 | ActivityRecords 缺热力 | 当前按记录展示 | Duolingo / Flomo | 用 `Grid` 做近 4 周学习热力 |
| 9 | Lesson 缺概念玩具 | `CodeRunPanel()` 仅代码推演 | Brilliant / Codecademy | 三门各做一个概念玩具卡 |
| 10 | 全对/成就反馈缺层次 | 成就和 Quiz 主要是卡片/进度 | Duolingo streak | 原生 keyframe / Particle 小范围反馈 |
| 11 | 旧审计文档过期风险 | `HARMONYOS-LAYOUT-AUDIT-2.md` 的安全区结论已过期 | 交接可读性 | 新文档中标注，以免重复修已修问题 |
| 12 | 三方依赖实验缺独立验收 | 仅 registry 元数据 | 依赖治理 | 先开 proof 分支逐个包验证，不进主线 |

## 4. 可访问性与设备适配补充审计

| 项目 | 当前状态 | 需要的证据 |
|---|---|---|
| 安全区 | 已有 `SafeAreaInsets` 机制 | 竖屏、横屏、平板窗口截图；状态栏/手势条不遮挡 |
| 触控目标 | 多处 30-44vp | UI 树 bounds；主操作不小于 48vp 或命中区足够 |
| 大字体 | 大量固定 `fontSize()` | 系统大字体截图；按钮文字不溢出 |
| 文本截断 | 部分页面已有 `maxLines` / `textOverflow` | 动态长标题、长标签、长通知截图 |
| 颜色无障碍 | 颜色承载掌握、错误、推荐 | 所有颜色状态必须有文字说明 |
| 屏幕阅读 | 未见系统化标签审计 | 关键按钮、进度、错误态可被读懂 |
| 横屏/平板 | LearningMap/底栏/热力图需要布局验证 | 横屏和平板窗口截图 |

## 5. 更新后的 P0 施工建议

相对 `FRONTEND-IMPLEMENTATION-ACCEPTANCE-20260704.md`，本审计建议把“触控目标统一”提前到 P0，因为它直接影响可用性和成熟感。

1. **Plan 技术词收口**：把 `Agent 工作链` 改成学生可读文案。
2. **主动作触控目标统一**：输入框、发送、重试、提交、练这个标签、任务完成等关键动作达到 48vp 或等效命中区。
3. **Chat Markdown 表格/行内样式**：优先补表格和行内代码。
4. **LearningMap 箭头 + 一跳邻域**：让星图关系读得出来。
5. **Profile/ActivityRecords 原生洞察小图**：先热力和 Top 3 错因，雷达可后置。
6. **断网/失败/取消截图包**：证明长任务不是“看起来会恢复”。

## 6. 对旧文档的修正说明

`docs/HARMONYOS-LAYOUT-AUDIT-2.md` 是 2026-07-01 的只读审计，其中 P0-1/P0-2 写明“全局缺失安全区域适配”。当前源码已经出现：

- `apps/harmonyos/entry/src/main/ets/common/SafeArea.ets`
- `EntryAbility.configureSafeArea()`
- `Window#getWindowAvoidArea()` 对 system/cutout/gesture/navigation indicator 的读取
- 多页面 `SafeAreaInsets.topVp()` / `SafeAreaInsets.bottomVp()` 消费

因此后续主线程不应再按“完全没有安全区”施工，而应改为做真实设备/模拟器证据采集和局部遗漏补齐。

## 7. 未验证项

- 未运行 HAP 构建。
- 未运行 DevEco MCP 静态诊断。
- 未采集模拟器/真机截图。
- 未改任何 `.ets` 文件。
- 外部标准只用于审计映射，未证明当前 UI 达标。

## 8. DEVLOG 片段（未写入主 `DEVLOG.md`）

背景：持续推进端侧前端资源深猎，进一步把资源地图和实施验收包转成当前源码差距审计，避免沿用旧报告中过期的安全区结论。

文件：
- `docs/FRONTEND-COMPETITIVE-GAP-AUDIT-20260704.md`

行为变化：
- 新增竞品与行业标准差距审计。
- 明确当前源码已具备安全区机制，纠正旧布局审计中的过期判断。
- 按成熟学习产品、WCAG 触控目标、Material/Apple 反馈原则、Khan/Duolingo/GitHub/Codecademy/Obsidian 模式重新排序 P0 缺口。

验证：
- `git status --short`：开始时无输出。
- `git log -5 --oneline`：最新提交为 `150a360 docs: add frontend implementation acceptance package`。
- `rg` 核验当前源码中的安全区、触控目标、技术词、文本截断使用情况。

失败或未验证：
- 本批次未执行 HAP 构建。
- 未做模拟器/真机视觉验收。

