# 鸿学伴端侧前端资源深度猎采地图（2026-07-02）

本文件面向 HarmonyOS API 12 端侧产品化落地。目标不是换色，而是把可复用资源、成熟产品机制和当前代码底座对应起来，给后续 Codex 主线实现提供可核验的资源地图。

本轮没有下载外部资产，没有写入 `.tmp/`，没有修改 `apps/harmonyos` 生产代码，没有修改依赖文件。第三方资源进入 HAP 前必须逐项补充具体素材 URL、许可证 URL、下载日期、文件哈希、包体大小、API 12 构建与运行证据。

## 当前源码底座

| 项目 | 当前精确信息 | 证据等级 |
|---|---|---|
| Worktree | `C:\Users\guo82\.codex\worktrees\ca18\Hormony` 是独立 worktree；桌面主工作区另在 `C:\Users\guo82\Desktop\Hormony` | 源码确认 |
| 目标 SDK | `apps/harmonyos/build-profile.json5` 中 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)` | 源码确认 |
| OHPM 依赖 | `apps/harmonyos/oh-package.json5`、`apps/harmonyos/entry/oh-package.json5` 当前依赖为空 | 源码确认 |
| Chat Markdown | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` 已有 `markdownBlocks()` 与 `MarkdownContent()`，支持标题、列表、代码块、表格文本化、分隔线 | 源码确认 |
| Lesson 代码学习 | `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets` 已有 `CodeBlock()`、固定活动推演、进度条和标准答案展示 | 源码确认 |
| 长任务反馈 | `apps/harmonyos/entry/src/main/ets/common/Builders.ets` 已有 `StagedProgress()`；`Quiz.ets`、`Plan.ets` 已使用阶段反馈 | 源码确认 |
| 标签洞察 | `LearningTagInsight`、`LocalLearningRepository.getTagInsights()`、`Profile.ets`、`ActivityRecords.ets` 已有标签正确率、错题数、难度分布、下一步建议 | 源码确认 |
| 学习星图 | `LearningMap.ets` 已有 `MapNode`、`MapEdge`、先修边、推荐节点、四状态图例、节点光晕和横向滚动图 | 源码确认 |
| 系统图标 | `Builders.ets`、`HomeContent.ets`、`Plan.ets`、`Profile.ets` 等已大量使用 HarmonyOS `SymbolGlyph` | 源码确认 |

## 核验方法

- 本地只读命令：`git status --short`、`git log -5 --oneline`、`rg --files`、`rg`、`ohpm info`、GitHub API、Gitee 页面访问、官方文档 GET。
- 公开来源：HarmonyOS 官方文档、GitHub/Gitee 仓库和许可证页、产品官方文档/博客、设计资源官网和许可证页。
- 证据等级使用：**源码确认**、**官方确认**、**未验证**。没有 API 12 构建、模拟器截图或真机证据的资源，不能写成可直接进入 HAP。

## 总体决策

1. **P0 继续用 ArkUI 原生能力**：`Progress`、`LoadingProgress`、`SymbolGlyph`、`Line`、`Path`、`Path2D`、`animateTo`、`keyframeAnimateTo`、`StyledString` 是当前最稳的落地方向。
2. **Markdown 先增强现有手写渲染**：`FluidMarkdown` 源码能力强但 README 写明 HarmonyOS 最低 API 15；`@luvi/lv-markdown-in` 的 OHPM registry JSON 与 Gitee 源码/许可可核验，但本仓库尚未安装、构建或运行验证。当前 API 12 主线先不引入 Markdown 包。
3. **Lottie 和图表包暂不进入依赖**：`@ohos/lottie-turbo`、`@ohos/lottie`、`@ohos/mpchart` 的 OHPM registry JSON 可核验到版本和许可，但本轮没有执行安装、HAP 构建、模拟器或真机验证，因此不能直接写入依赖。
4. **图标只补系统 Symbol 缺口**：Tabler、Phosphor、Lucide、Iconoir 许可证清楚，但不得整包引入，也不得和系统 Symbol 混成多套图标语言。
5. **插画、音效、动效必须逐条建账**：Open Peeps 可作为少量空态素材方向；unDraw、ManyPixels、Rive 社区资源只作参考；LottieFiles、Pixabay、Freesound、Mixkit 只有在具体素材逐条核验后才可进入。

## 资源总表

| 资源 | URL | 类型 | License/授权状态 | 维护状态 | API 12 / ArkUI 适配判断 | 引入方式 | 包体/风险 | 可解决的鸿学伴问题 | 证据等级 |
|---|---|---|---|---|---|---|---|---|---|
| HarmonyOS Progress | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-progress | 原生进度组件 | 平台能力 | 官方文档可访问 | 当前已在 `Course.ets`、`Lesson.ets`、`Quiz.ets`、`Practice.ets`、`Profile.ets` 使用 | 继续复用，统一颜色和阶段语义 | 无新增包体；需避免只用进度条代替解释 | AI 出题、评分、计划生成、掌握度展示 | 官方确认 + 源码确认 |
| HarmonyOS LoadingProgress | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-loadingprogress | 原生加载组件 | 平台能力 | 官方文档可访问 | 当前已在 `Builders.ets`、`Chat.ets`、`Plan.ets` 使用 | 继续复用，配合阶段文案和失败恢复 | 无新增包体；单独旋转加载信息量不足 | Chat 连接、Quiz/Plan 长任务反馈 | 官方确认 + 源码确认 |
| HarmonyOS SymbolGlyph | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-symbolglyph | 系统符号 | 平台能力 | 官方文档可访问 | 当前多页面使用，适合按钮和状态 icon 统一 | 默认图标体系；仅在系统符号缺失时补单 SVG | 无新增包体；符号名必须从源码/SDK核验 | 按钮/icon 语义、状态提示、导航 | 官方确认 + 源码确认 |
| ArkUI animation / keyframeAnimateTo | https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkui-animation | 原生动画 | 平台能力 | 官方文档可访问 | API 12 下优先用于轻量正反馈 | `animateTo`、`keyframeAnimateTo` 做 600-1200ms 局部动效 | 无新增包体；需截图证明不遮挡正文 | 全对、提交成功、每日任务收束、成就解锁 | 官方确认；具体落地未验证 |
| CanvasRenderingContext2D | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-canvasrenderingcontext2d | 原生绘图 | 平台能力 | 官方文档可访问 | 适合 Lesson 概念图和 LearningMap 细节增强 | 仅在 `Line`/`Stack` 不够时使用 Canvas | 需实测性能和触控区域 | 栈/队列/树/TCP/调度图、星图箭头 | 官方确认；具体落地未验证 |
| Path2D / Path / Line | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-components-canvas-path2d | 原生路径与线 | 平台能力 | 官方文档可访问 | `LearningMap.ets` 已使用 `Line` 画先修边 | 用 `Line` 保持边，用 `Path` 或小三角补方向箭头 | 坐标缩放和横向滚动需截图验收 | 星图方向、局部邻域、先修路径说明 | 官方确认 + 源码确认 |
| RichEditor | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-richeditor | 原生富文本编辑 | 平台能力 | 官方文档可访问 | 当前不需要通用编辑器；可作为 Lesson 手写/文本推演后续方向 | P2 研究，不进入 P0 | 编辑器能力会扩大范围；需避免变成 Markdown 编辑器 | 手写推演、可编辑学习笔记 | 官方确认；未验证 |
| StyledString | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-universal-styled-string | 原生样式文本 | 平台能力 | 官方文档可访问 | 可作为手写 Markdown 行内样式升级方向 | P1 局部替换段落/代码行样式 | 需处理链接、代码、表格边界 | Chat 行内代码、粗体、引用、重点提示 | 官方确认；未验证 |
| RichText | https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-richtext | HTML 富文本组件 | 平台能力 | 官方文档可访问 | 不建议直接渲染模型 HTML；需白名单 | 仅作为受控 HTML 片段研究 | 直接渲染模型输出有安全和样式风险 | 不进入 P0；仅保留文档参考 | 官方确认；未验证 |
| `@luvi/lv-markdown-in` | https://ohpm.openharmony.cn/#/cn/detail/@luvi%2Flv-markdown-in；https://gitee.com/luvi/lv-markdown-in；https://gitee.com/luvi/lv-markdown-in/blob/master/LICENSE | OHPM Markdown 包方向 | OHPM latest `3.4.4` 为 MIT；Gitee LICENSE 页可访问 | OHPM modified `2026-06-25T15:14:58.66Z`；repository 为 Gitee | registry latest 声明 `compatibleSdkVersion` 为 `12`；本仓库 API 12 构建、包体、流式更新均未验证 | 只能在独立 proof 分支单包安装验证 | 依赖 `@luvi/html2md`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid`；依赖链许可和包体未核验 | Chat Markdown、代码块、表格、引用、列表、公式、Mermaid 方向 | 官方确认 + 源码确认；本仓库构建未验证 |
| FluidMarkdown | https://github.com/antgroup/FluidMarkdown；https://github.com/antgroup/FluidMarkdown/blob/main/LICENSE | 跨端流式 Markdown 源码 | Apache-2.0 | GitHub API：未归档，2026-01-30 pushed，2026-06-27 updated | README 写明 HarmonyOS 最低 API 15，高于当前 API 12 | 当前不引入；作为未来 API 升级参考 | 引入会违背 API 12 目标；依赖复杂 | 流式 AI Markdown、代码块、表格、公式参考 | 源码确认；当前 API 12 未验证 |
| Harmony Markdown Editor | https://github.com/electronicminer/Harmony-Markdown-Editor；https://github.com/electronicminer/Harmony-Markdown-Editor/blob/main/LICENSE | ArkUI Markdown 编辑器源码参考 | MIT | GitHub API：未归档，2026-06-22 pushed，2026-06-26 updated | README 标注 API 15 (5.0.3)，高于当前 API 12 | 只参考原生组件拆分、TaskPool 解析、代码块布局 | 不能复制云同步/AI 配置/编辑器架构 | Chat/Lesson Markdown 结构参考 | 源码确认；当前 API 12 未验证 |
| `@ohos/lottie-turbo` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Flottie-turbo；https://gitcode.com/openharmony-sig/lottie_turbo | OHPM 动效包方向 | OHPM latest `1.0.12` 为 Apache-2.0 | OHPM modified `2026-05-20T09:41:43.229Z`；GitCode 页面显示 Apache-2.0 与 ArkTS | registry latest 声明 `compatibleSdkVersion` 为 `12`；本仓库构建和真机渲染未验证 | 暂不写依赖；后续单包验证 | 依赖 `liblottie-turbo.so`；Native ABI、HAP 体积、生命周期和真机帧率未知 | 成就、全对、成功反馈动效 | 官方确认 + 源码确认；本仓库构建未验证 |
| `@ohos/lottie` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Flottie；https://gitcode.com/openharmony-tpc/lottieArkTS | OHPM 动效包方向 | OHPM latest `2.0.31` 为 MIT | OHPM modified `2026-05-21T15:30:58.039Z`；GitCode 页面显示 MIT | registry latest 未提供 `compatibleSdkVersion` 字段；本仓库 API 12 构建和真机渲染未验证 | 暂不写依赖；后续单包验证 | 动画 JSON 资产需单独授权；渲染兼容、内存释放、帧率未知 | 少量 Lottie 成就动画 | 官方确认 + 源码确认；本仓库构建未验证 |
| `@ohos/mpchart` | https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fmpchart；https://gitcode.com/openharmony-tpc/ohos_mpchart | OHPM 图表包方向 | OHPM latest `3.0.28` 为 Apache License 2.0 | OHPM modified `2026-04-27T10:09:51.523Z` | registry latest 声明 `compatibleSdkVersion` 为 `12`；当前 Profile/Records 仍可先用原生 `Progress`、`Line`、`Grid` 完成 | 不进入 P0；后续单包验证 | 大图表库会增加包体；GitCode 页面需进一步核对 tag 与 OHPM 版本 | 标签洞察、趋势图 | 官方确认；本仓库构建未验证 |
| Tabler Icons | https://github.com/tabler/tabler-icons；https://github.com/tabler/tabler-icons/blob/main/LICENSE | SVG 图标 | MIT | GitHub API：未归档，2026-06-28 pushed，2026-07-02 updated | ArkUI 可通过 rawfile SVG + `Image` 方向验证；当前未运行 | 仅取单个图标，保留 LICENSE 记录 | 整包不进 HAP；避免和系统 Symbol 混用 | 数据库、路线、终端、标签等 Symbol 缺口 | 官方确认；ArkUI 渲染未验证 |
| Phosphor Icons | https://github.com/phosphor-icons/core；https://github.com/phosphor-icons/core/blob/main/LICENSE | SVG 图标 | MIT | GitHub API：未归档，2026-01-06 pushed，2026-07-02 updated | 同 Tabler，仅作少量补充 | 单 SVG 引入 | 不与 Tabler/Lucide 并行形成三套风格 | 学位帽、脑图、代码语义 | 官方确认；ArkUI 渲染未验证 |
| Lucide | https://github.com/lucide-icons/lucide；https://github.com/lucide-icons/lucide/blob/main/LICENSE | SVG 图标 | ISC；部分 Feather 派生图标 MIT | GitHub API：未归档，2026-07-02 pushed | 同 Tabler；需记录具体图标许可证来源 | 单 SVG 引入 | 许可证双层记录成本 | 按钮/icon 语义备选 | 官方确认；ArkUI 渲染未验证 |
| Iconoir | https://github.com/iconoir-icons/iconoir；https://github.com/iconoir-icons/iconoir/blob/main/LICENSE | SVG 图标 | MIT | GitHub API：未归档，2026-06-18 pushed，2026-07-01 updated | 可补脑图、网络、终端等语义 | 单 SVG 引入 | 风格更强，必须视觉复核 | LearningMap、Lesson 资料类型、洞察图标 | 官方确认；ArkUI 渲染未验证 |
| Open Peeps | https://www.openpeeps.com/；https://creativecommons.org/publicdomain/zero/1.0/ | 插画 | 官网声明 CC0 方向；CC0 页面可访问 | 静态图库页面可访问 | 只取少量单张 SVG/PNG；需逐条记录来源 | 放 `.tmp/` 视觉比对，通过后再评估 rawfile | 手绘风可能与工具调性不合；整包不进 HAP | 空态、成就页轻插画 | 官方确认；ArkUI 渲染未验证 |
| unDraw | https://undraw.co/license | 插画 | 自定义许可；可商用但禁止打包再分发、AI/ML、复刻服务等 | 许可页面可访问 | 不进入 HAP，仅参考构图 | 不下载生产素材 | 自定义许可限制较多 | 空态构图参考 | 官方确认；采用未验证 |
| ManyPixels | https://www.manypixels.co/gallery | 插画 | 自定义许可方向；图库页可访问 | 页面可访问 | 不进入 HAP，仅参考构图 | 不下载生产素材 | 自定义许可和整包分发风险 | 空态、数据洞察插画参考 | 官方确认；采用未验证 |
| LottieFiles | https://lottiefiles.com/page/license | Lottie 动效 | 子代理核验为 Lottie Simple License 方向；主线程 HTTP 访问返回 403 | 平台活跃 | 必须逐条记录动画作者、页面、许可；还需 Lottie 渲染链通过 | 先放 `.tmp/`，不进 HAP | JSON 外链图片、表达式、真机帧率未知 | 全对、成就、提交成功 | 官方确认（子代理）；HarmonyOS 渲染未验证 |
| Rive runtime / community | https://github.com/rive-app/rive-runtime；https://rive.app/docs/legal/terms-of-service | 交互动效运行时和社区动效 | runtime MIT；社区内容需按平台条款逐项署名 | GitHub API：未归档，2026-07-01 pushed | 没有 API 12 原生集成证据 | 不进入 HAP；只参考状态机动效节奏 | `.riv` 运行链、署名、包体不可控 | 正反馈状态机和交互节奏参考 | 官方确认；API 12 未验证 |
| Noto Sans CJK / SC | https://github.com/notofonts/noto-cjk；https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE | 字体 | SIL OFL 1.1 | 子代理核验：仓库维护到 2025-12-16 | 默认用系统字体；仅在确需字体子集时评估 | 不整包引入 | 中文字体体积大；保留名规则需遵守 | 中文阅读一致性、代码备用字体 | 官方确认；API 12 字体加载未验证 |
| HarmonyOS 设计资源 | https://developer.huawei.com/consumer/cn/design/resource-V1/ | 字体/图标/设计资源 | 下载包内许可本轮未读 | 官方资源页可访问 | 端侧优先系统字体和 `SymbolGlyph` | 不把设计资源包直接塞进 HAP | 字体包体积大；下载包许可未核验 | 系统一致性参考 | 官方确认；采用未验证 |
| Pixabay | https://pixabay.com/service/license-summary/ | 图片/音效平台 | 平台许可摘要允许免费使用与修改，仍有独立转售、商标/人物限制 | 平台活跃 | 只允许逐条素材核验后使用 | 记录具体素材 URL、作者、许可证 | 第三方权利和音频体积风险 | 轻提示音、少量背景素材方向 | 官方确认；单素材未验证 |
| Freesound | https://freesound.org/help/faq/#licenses | 音效平台 | 每个声音可能是 CC0 / CC BY / CC BY-NC 等 | 平台维护 | 只用 CC0 或可署名 CC BY；禁用 BY-NC | 逐条记录作者、URL、许可证；默认不进 HAP | WAV/FLAC 体积、署名和转码风险 | 答对、完成、提示音方向 | 官方确认；单素材未验证 |
| Mixkit Sound Effects | https://mixkit.co/free-sound-effects/；https://mixkit.co/license/ | 音效平台 | Sound Effects Free License 方向 | Envato 维护 | 只取 1-2 个极短音效时再评估 | 逐条记录来源；先不上生产 | 音效可能打扰学习；需可关闭 | 成就/完成轻提示 | 官方确认；单素材未验证 |
| Duolingo 学习机制 | https://blog.duolingo.com/how-duolingo-streak-builds-habit/；https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo/；https://blog.duolingo.com/duolingo-launches-math-app/ | 成熟产品模式 | 只学习机制，不复制品牌资产 | 官方博客可访问 | 用真实学习事件驱动连续学习和短任务反馈 | 不引入素材 | 不复制吉祥物、音效、榜单表皮 | Home、Achievements、Lesson 正反馈 | 官方确认；落地未验证 |
| Brilliant 互动课模式 | https://brilliant.org/；https://brilliant.org/courses/ | 成熟产品模式 | 只学习结构，不复制课程/插画 | 官网可访问 | 用 ArkUI 小图和逐步问题表达概念 | 不引入素材 | 复杂互动需拆小步 | Lesson 概念玩具卡 | 官方确认；落地未验证 |
| Codecademy / Mimo 编程学习模式 | https://www.codecademy.com/；https://mimo.org/ | 成熟产品模式 | 不复制编辑器 UI，不执行任意用户代码 | 官网可访问 | 固定示例“推演感”：题意、代码、输出、解释 | 不引入 Web 沙盒 | 用户误解为真实执行的风险 | Lesson、Practice、Chat 代码学习 | 官方确认；落地未验证 |
| Khan Academy Mastery | https://support.khanacademy.org/hc/en-us/articles/5548760867853--How-do-Khan-Academy-s-Mastery-levels-work；https://support.khanacademy.org/hc/en-us/articles/360037127892-What-are-Mastery-Challenges-in-course-mastery | 掌握等级与复习机制 | 只学习层级和复习逻辑 | 官方帮助页可访问 | 从 `TagInsight` 与 `TopicMastery` 推导等级，不伪造历史 | 不引入素材 | 必须用真实本地数据 | Profile、ActivityRecords、MistakeBook、Quiz | 官方确认；落地未验证 |
| Obsidian Graph / Canvas | https://help.obsidian.md/plugins/graph；https://help.obsidian.md/plugins/canvas | 知识图模式 | 只学习节点/边/局部图/筛选 | 官方帮助页可访问 | 用现有 `LearningMap.ets` 的 `Line`、节点和详情卡强化关系 | 不引入图谱库 | 小屏节点拥挤 | LearningMap 星图语义升级 | 官方确认 + 源码确认；落地未验证 |

## OHPM 只读核验记录

本机 `ohpm --version` 为 `26.0.0.410`。在 `apps/harmonyos` 下执行 `ohpm info` 时，CLI 对未编码 registry 路径返回 502；随后主线程直接读取官方 registry 编码路径 `https://ohpm.openharmony.cn/ohpm/<encoded-package>` 成功取得元数据。两类证据都记录如下：

| 命令 | 退出码 | 结果 |
|---|---:|---|
| `ohpm info @luvi/lv-markdown-in` | 1 | `GET https://ohpm.openharmony.cn/ohpm/@luvi/lv-markdown-in 502( Bad Gateway )`，并报告 `Fetch Pkg Info Failed` |
| `ohpm info @ohos/lottie-turbo` | 1 | `GET https://ohpm.openharmony.cn/ohpm/@ohos/lottie-turbo 502( Bad Gateway )`，并报告 `Fetch Pkg Info Failed` |
| `ohpm info @ohos/lottie` | 1 | `GET https://ohpm.openharmony.cn/ohpm/@ohos/lottie 502( Bad Gateway )`，并报告 `Fetch Pkg Info Failed` |
| `ohpm info @ohos/mpchart` | 1 | `GET https://ohpm.openharmony.cn/ohpm/@ohos/mpchart 502( Bad Gateway )`，并报告 `Fetch Pkg Info Failed` |

| Registry URL | 结果 |
|---|---|
| `https://ohpm.openharmony.cn/ohpm/@luvi%2Flv-markdown-in` | latest `3.4.4`，MIT，modified `2026-06-25T15:14:58.66Z`，`compatibleSdkVersion: 12`，依赖 `@luvi/html2md`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid` |
| `https://ohpm.openharmony.cn/ohpm/@ohos%2Flottie-turbo` | latest `1.0.12`，Apache-2.0，modified `2026-05-20T09:41:43.229Z`，`compatibleSdkVersion: 12`，依赖 `liblottie-turbo.so` |
| `https://ohpm.openharmony.cn/ohpm/@ohos%2Flottie` | latest `2.0.31`，MIT，modified `2026-05-21T15:30:58.039Z`，latest 元数据未提供 `compatibleSdkVersion` 字段 |
| `https://ohpm.openharmony.cn/ohpm/@ohos%2Fmpchart` | latest `3.0.28`，Apache License 2.0，modified `2026-04-27T10:09:51.523Z`，`compatibleSdkVersion: 12` |

结论：元数据与许可证可作为**官方确认**，但本轮仍不得把以上 OHPM 包写入依赖；没有本仓库安装、增量构建、模拟器截图和真机证据前，不能标记为 API 12 运行通过。

## 不进入 HAP 的内容

- 整套图标包、整套插画包、整套音效包。
- 未记录具体素材 URL、作者、许可证和哈希的 SVG/PNG/Lottie/音效。
- WebView/ArkWeb 承载庆祝动画、Markdown 主阅读体验或图谱库。
- `FluidMarkdown` 在当前 API 12 目标下的直接引入。
- `@ohos/lottie-turbo`、`@ohos/lottie`、`@ohos/mpchart` 在本仓库安装、API 12 构建和运行证据齐全前的直接引入。
- 任意用户代码执行、在线判题沙盒或 Web IDE。
