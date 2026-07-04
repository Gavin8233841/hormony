# 鸿学伴端侧前端资源采用矩阵（2026-07-04）

本矩阵服务 HarmonyOS API 12 主线。除“源码确认”或“官方确认”外，所有未安装、未构建、未模拟器/真机运行的资源均标记为“未验证”。本文件不是依赖安装清单。

| 资源名 | 来源 URL | 用途 | 许可证 | 维护状态 | API 12 / HarmonyOS 适配性 | 接入成本 | 风险 | 建议优先级 | 验证命令或验证缺口 |
|---|---|---|---|---|---|---|---|---|---|
| ArkUI `Progress` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-progress-V5 | 课程进度、Quiz 题目进度、标签掌握度 | 平台能力 | 官方维护 | 项目已使用，源码确认 | 低 | 单独进度条信息量不足 | P0 | 已有源码；后续页面截图验收 |
| ArkUI `LoadingProgress` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-basic-components-loadingprogress-V5 | Chat/Plan/Quiz 长任务活动指示 | 平台能力 | 官方维护 | 项目已使用，源码确认 | 低 | 不区分阶段会像卡住 | P0 | 断网、超时、取消路径截图 |
| 项目 `StagedProgress` | `apps/harmonyos/entry/src/main/ets/common/Builders.ets` | 统一 AI 出题、计划生成、评分阶段反馈 | 项目代码 | 主线维护 | 已在 Quiz/Plan/Chat 使用 | 低 | 阶段过多会制造伪进度 | P0 | HAP 构建 + 三场景 UI 树 |
| HarmonyOS Symbol / `SymbolGlyph` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph | 功能图标、状态提示、导航 | 系统资源 | 官方维护 | 项目已大量使用 | 低 | 符号名不能猜写 | P0 | 每个新增符号名从 DevEco/源码核验 |
| HarmonyOS Design | https://developer.huawei.com/consumer/cn/design/ | 视觉规范、布局、动效节奏 | 官方设计资源 | 官方维护 | 设计层适配；下载包许可未验证 | 中 | 下载资源再分发许可需读包内说明 | P0 | 对照 `Constants.ets` 做只读审计 |
| ArkUI `animateTo` / `keyframeAnimateTo` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/arkui-animation-V5 | 成就、全对、任务完成轻反馈 | 平台能力 | 官方维护 | V5 文档可访问，本项目具体动效未验收 | 中 | 连续触发、页面离开、低端帧率 | P0 | HAP 构建、模拟器点击、截图/录屏 |
| ArkUI `Particle` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-particle-animation-V5 | 全对和成就解锁粒子 | 平台能力 | 官方维护 | V5 文档可访问，本项目未接入 | 中 | 粒子数量和生命周期影响帧率 | P1 | 模拟器 + 真机帧率未验证 |
| ArkUI `Canvas` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-canvasrenderingcontext2d | 雷达图、热力、概念玩具、星图增强 | 平台能力 | 官方维护 | V5 文档可访问 | 中 | 绘制坐标、横竖屏适配 | P0 | HAP 构建 + 多尺寸截图 |
| ArkUI `Path2D` / `Path` / `Line` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-components-canvas-path2d-V5 | LearningMap 箭头、路径、高亮边 | 平台能力 | 官方维护 | `LearningMap.ets` 已用 `Line` | 中 | 节点标签重叠、滚动区域裁切 | P0 | 模拟器选择任意节点截图 |
| ArkUI `Grid` | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-container-grid | 学习热力图、徽章墙、日期格 | 平台能力 | 官方维护 | 官方组件 | 低 | 小屏格子文字溢出 | P0 | 空/少/多数据截图 |
| ArkUI `List` | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-container-list | ActivityRecords 时间线、错题分组 | 平台能力 | 官方维护 | 项目已有列表类页面 | 低 | 长列表性能和分组黏性 | P0 | 长数据 UI 树与滚动验收 |
| ArkUI `DataPanel` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-datapanel-V5 | Profile 概览、标签占比 | 平台能力 | 官方维护 | V5 文档可访问，本项目未接入 | 低 | 颜色和分段可读性 | P1 | 构建 + 截图 |
| ArkUI `Gauge` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-gauge-V5 | Quiz 掌握仪表、专注度仪表 | 平台能力 | 官方维护 | V5 文档可访问，本项目未接入 | 低 | 角度/刻度含义过重 | P2 | 构建 + 截图 |
| ArkUI `StyledString` | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-universal-styled-string | Chat 行内代码、粗体、引用重点 | 平台能力 | 官方维护 | 官方能力，本项目未接入 | 中 | 需要自研解析边界 | P1 | ArkTS 诊断、长文本性能 |
| ArkUI `RichText` | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-richtext | 受控 HTML 片段展示 | 平台能力 | 官方维护 | 官方组件 | 中 | 不可直接渲染模型 HTML | P3 | 白名单清洗策略未验证 |
| ArkUI `RichEditor` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/ts-basic-components-richeditor-V5 | 未来学习笔记、可编辑推演 | 平台能力 | 官方维护 | V5 文档可访问，本项目未接入 | 高 | IME、粘贴、选择菜单复杂 | P3 | 不进 2-3 周主线 |
| `TaskPool` / Worker | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/concurrency-overview-V5 | 大段 Markdown 解析、星图布局 | 平台能力 | 官方维护 | V5 文档可访问 | 中 | Sendable 数据边界 | P2 | 独立性能实验未验证 |
| 现有纯 ArkUI Markdown | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` | Chat SSE 文本、列表、引用、代码块 | 项目代码 | 主线维护 | 已运行在主线 | 低 | Markdown 子集有限 | P0 | 增强后跑 HAP 构建与 Chat 截图 |
| `@luvi/lv-markdown-in` | https://ohpm.openharmony.cn/#/cn/detail/@luvi%2Flv-markdown-in；https://gitee.com/luvi/lv-markdown-in | 完整 Markdown、代码高亮、公式、流式 | MIT | latest `3.4.5`，modified `2026-07-03` | registry 写 `compatibleSdkVersion=12`，本项目未构建 | 中高 | 依赖链、包体、SSE 更新性能 | P1 实验 | `cd apps/harmonyos; ohpm install @luvi/lv-markdown-in`; `.\hvigorw.bat assembleHap --no-daemon`; Chat SSE 回归 |
| FluidMarkdown | https://github.com/antgroup/FluidMarkdown | AI 流式 Markdown 参考 | Apache-2.0 | 活跃项目 | README 写 HarmonyOS 最低 API 15 | 高 | 不符合当前 API 12 | 拒绝当前接入 | 仅 API 升级后评估 |
| Harmony Markdown Editor | https://github.com/electronicminer/Harmony-Markdown-Editor | Markdown 编辑/渲染源码参考 | MIT | 近期有提交 | README 为 API 15 | 中 | 不符合当前 API 12 | 参考 | 不接入依赖 |
| markdown4cj | https://gitcode.com/Cangjie-TPC/markdown4cj | 仓颉 Markdown 解析参考 | Apache-2.0 | 有仓库维护 | API 12 未验证，需仓颉/C++ 工具链 | 高 | 工具链复杂 | 暂缓 | 不进主线 |
| `@ohos/lottie-turbo` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Flottie-turbo；https://gitcode.com/openharmony-sig/lottie_turbo | Lottie 动效渲染 | Apache-2.0 | latest `1.0.12`，modified `2026-05-20` | registry 写 `compatibleSdkVersion=12`，本项目未构建 | 中 | Native `.so`、ABI、真机帧率 | P2 实验 | 单包安装、HAP 构建、真机/模拟器播放 |
| `@ohos/lottie` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Flottie；https://gitcode.com/openharmony-tpc/lottieArkTS | Lottie 动效渲染 | MIT | latest `2.0.31` | registry latest 未给 compatibleSdkVersion | 中 | API 12 兼容未证实 | P2 实验 | 单包安装和播放验证 |
| 项目自制 Lottie JSON | `assets/frontend-resources/animations/` | 成功、进度、奖杯动效 | 项目授权 | 静态资源 | JSON 格式旧文档已核验；播放未验证 | 中 | 渲染链未验证 | P2 | 依赖通过后逐个播放 |
| `@ohos/mpchart` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fmpchart；https://gitcode.com/openharmony-tpc/ohos_mpchart | 雷达图、折线、柱状图后备 | Apache License 2.0 | latest `3.0.28`，modified `2026-04-27` | registry 写 `compatibleSdkVersion=12`，未构建 | 中高 | 包体、复杂度、大数据卡顿问题 | P3 | 先用原生图，必要时单包验证 |
| `@pura/harmony-utils` | https://ohpm.openharmony.cn/#/cn/detail/@pura%2Fharmony-utils | 日期、JSON、工具集 | Apache-2.0 | latest `1.4.2`，modified `2026-07-01` | registry 写 `compatibleSdkVersion=12` | 中 | 当前无必须替代缺口 | 暂缓 | 不新增工具库债务 |
| `@pura/harmony-dialog` | https://ohpm.openharmony.cn/#/cn/detail/@pura%2Fharmony-dialog | 弹窗和加载弹窗 | Apache-2.0 | latest `1.1.8`，modified `2025-09-01` | registry 写 `compatibleSdkVersion=12` | 中 | 依赖 `@pura/spinkit`，会引入 UI 语言分叉 | 暂缓 | 优先原生弹层 |
| `@ohos/imageknife` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fimageknife | 图片加载缓存 | Apache License 2.0 | latest `3.2.9` | registry 写 `compatibleSdkVersion=18` | 高 | 不适配 API 12 | 拒绝当前接入 | 需 API 18 目标才评估 |
| `@ohos/pulltorefresh` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fpulltorefresh | 下拉刷新 | Apache License 2.0 | latest `3.0.1`，modified `2026-04-30` | registry 写 `compatibleSdkVersion=12` | 中 | 当前列表场景不够强 | 暂缓 | 先查原生 Refresh 能力 |
| `@ohmos/calendar` | https://ohpm.openharmony.cn/#/cn/detail/@ohmos%2Fcalendar；https://github.com/HarmonyOS-Next/mini-calendar | 学习日历 | Apache-2.0 | latest `2.1.4`，modified `2024-10-23` | registry 写 `compatibleSdkVersion=12` | 中 | 维护偏旧，依赖 dayjs | 暂缓 | 原生 Grid 热力图优先 |
| `@ohos/high_light_guide` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fhigh_light_guide | 新手引导高亮 | Apache License 2.0 | latest `1.0.5`，modified `2025-12-05` | registry 写 `compatibleSdkVersion=12` | 中 | 引导可能打扰学习主流程 | P3 | 先补空态与页面自解释 |
| Lucide 单 SVG | https://lucide.dev/icons/；https://lucide.dev/license | 系统 Symbol 缺口 | ISC | 活跃维护 | ArkUI 可加载 SVG 方向，未在本项目验证 | 低 | 混用图标语言 | P2 | 单图哈希、许可证、截图 |
| Tabler Icons 单 SVG | https://tabler.io/icons；https://github.com/tabler/tabler-icons/blob/master/LICENSE | 教育/技术图标参考 | MIT | 活跃维护 | ArkUI SVG 加载未在本项目验证 | 低 | 旧文档已拒绝整包使用 | 参考 / P2 单图 | 单图入账 |
| Phosphor Icons 单 SVG | https://phosphoricons.com/；https://github.com/phosphor-icons/core/blob/main/LICENSE | 学位帽、脑图等图标 | MIT | 活跃维护 | ArkUI SVG 加载未在本项目验证 | 低 | 画布和风格差异 | 参考 | 单图入账 |
| Remix Icon | https://remixicon.com/；https://github.com/Remix-Design/RemixIcon/blob/master/License | 图标参考 | 自定义许可 | 活跃 | ArkUI SVG 可行但未验证 | 中 | 自定义许可增加合规成本 | 暂缓 | 不作为低风险来源 |
| Open Peeps | https://www.openpeeps.com/；https://creativecommons.org/publicdomain/zero/1.0/ | 空态人物插画 | CC0 | 静态资源 | SVG/PNG 可入包，未验证 | 中 | 手绘风与工具调性需复核 | P2 | 逐图 URL、哈希、包体、截图 |
| Open Doodles | https://www.opendoodles.com/；https://creativecommons.org/publicdomain/zero/1.0/ | 轻空态插画 | CC0 | 静态资源 | SVG/PNG 可入包，未验证 | 中 | 风格偏活泼 | P3 | 逐图入账 |
| unDraw | https://undraw.co/illustrations；https://undraw.co/license | 空态构图参考 | 自定义许可，可商用但限制再分发和图库化 | 维护中 | 技术可行，合规成本较高 | 中 | 自定义许可 | 参考 | 不批量下载 |
| Kenney Interface Sounds | https://kenney.nl/assets/interface-sounds | 提交/完成轻音效 | CC0 | 静态资源 | `rawfile/audio` 可行，播放 API 未查 | 中 | 音效打扰学习，需要开关 | P2 | 查 Audio API、单音频体积、真机播放 |
| Kenney Game Icons / Pattern Pack | https://kenney.nl/assets/game-icons；https://kenney.nl/assets/pattern-pack | 徽章底板、纹理 | CC0 | 静态资源 | SVG/PNG 可行，未验证 | 中 | 游戏感过强 | P3 | 视觉复核 |
| LottieFiles 免费动画 | https://lottiefiles.com/page/license；https://lottiefiles.com/free-animations/commercial | 成就/成功动效素材 | Lottie Simple License | 平台活跃 | 需 Lottie 渲染链，未验证 | 高 | 单动画作者、表达式、外链图片、同许可分发要求 | P3 | 逐条动画页、JSON 审计、播放验证 |
| NASA Image Library 单图 | https://images.nasa.gov/；https://www.nasa.gov/nasa-brand-center/images-and-media/ | 星图/知识宇宙背景参考 | NASA 使用指南；不得暗示背书 | 平台维护 | 图片可入包，未验证 | 中 | 第三方权利、体积、品牌背书 | P3 | 逐图核验、压缩、署名说明 |
| ESA / Hubble 单图 | https://esahubble.org/images/；https://esahubble.org/copyright/ | 星云背景参考 | 多为 CC BY 4.0 | 平台维护 | 图片可入包，未验证 | 中 | 必须署名 | 暂缓 | 关于页许可证清单 |
| Freesound 单音效 | https://freesound.org/help/faq/#licenses | 反馈音效 | 单文件许可不同 | 平台维护 | 音频可入包，未验证 | 中 | NC 禁用，署名成本 | 暂缓 | 只接受 CC0 或明确 CC BY |
| Mixkit SFX | https://mixkit.co/free-sound-effects/；https://mixkit.co/license/ | 反馈音效 | 自定义许可 | 平台维护 | 音频可入包，未验证 | 中 | 禁止素材再分发，许可需全文记录 | 暂缓 | 逐音频入账 |
| Duolingo Streak | https://blog.duolingo.com/how-duolingo-streak-builds-habit/；https://www.duolingo.com/help/what-is-a-streak | 连续学习机制 | 只借鉴机制 | 官方维护 | 可用本地事件实现 | 中 | 避免空刷和焦虑 | P0 | 以真实学习事件触发 |
| Khan Academy Mastery | https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work；https://support.khanacademy.org/hc/en-us/articles/360037494231-What-are-Mastery-Challenges | 掌握等级、复习挑战 | 只借鉴机制 | 官方维护 | 当前已有标签掌握底座 | 中 | 不改变现有解锁契约 | P0 | 本地数据五状态截图 |
| Codecademy AI Assistant | https://help.codecademy.com/hc/en-us/articles/23400751016859-AI-Features-available-on-Codecademy | 上下文 AI 反馈 | 只借鉴机制 | 官方维护 | Chat/Lesson/Quiz 可映射 | 中 | 不执行任意用户代码 | P0 | 固定代码示例推演验收 |
| GitHub Skills / Markdown | https://skills.github.com/；https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks | 分步学习、代码块阅读 | 只借鉴机制 | 官方维护 | Chat/Lesson 已有底座 | 低 | 避免技术词过多 | P0 | 长代码、表格、引用截图 |
| LeetCode Study Plan | https://leetcode.com/studyplan/；https://leetcode.com/studyplan/leetcode-75/ | 主题题单、周期、完成徽章 | 只借鉴机制 | 官方维护 | Practice/Quiz 可映射 | 中 | AI 题质量需验证 | P1 | 题组完成与标签数据写回 |
| Coursera Deadlines | https://www.coursera.support/s/article/learner-000001570；https://blog.coursera.org/coursera-update-striking-a-balance-with-start/ | 截止日期、过期任务、节奏调整 | 只借鉴机制 | 官方维护 | Plan/复习队列可映射 | 中 | 不迁移端侧私有状态到云端 | P1 | 到期/过期/恢复输入截图 |
| Brilliant 互动课 | https://brilliant.org/；https://brilliant.org/courses/ | 概念可操作化、先预测再揭示 | 只借鉴机制 | 官方维护 | Lesson 可映射 | 中高 | 交互过大难验收 | P1 | 每门一个概念玩具截图 |
| Obsidian Graph / Canvas | https://help.obsidian.md/plugins/graph；https://help.obsidian.md/plugins/canvas | 节点/边、局部图、筛选 | 只借鉴机制 | 官方维护 | LearningMap 已有底座 | 中 | 小屏拥挤 | P0 | 一跳邻域和箭头截图 |
