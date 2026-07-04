# 鸿学伴端侧前端资源全网深猎 2（2026-07-04）

本文件只做资源审计、证据建账和采用顺序收口。未下载外部素材，未安装 OHPM 依赖，未修改 `apps/harmonyos` 源码。

证据等级沿用仓库规范：**源码确认**、**线上通过**、**未验证**。OHPM 与 GitHub API 的 **线上通过** 只证明公开元数据可读取；不证明 API 12 构建、模拟器渲染或真机播放通过。

## 一、当前仓库基线

| 项目 | 精确信息 | 证据 |
|---|---|---|
| 当前分支 | `codex/harmony-frontend-deep-hunt-2-20260704` | 源码确认 |
| 目标 SDK | `apps/harmonyos/build-profile.json5` 中 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)` | 源码确认 |
| 端侧依赖 | `apps/harmonyos/oh-package.json5` 与 `apps/harmonyos/entry/oh-package.json5` 的 `dependencies` 均为空对象 | 源码确认 |
| 设计令牌 | `apps/harmonyos/entry/src/main/ets/common/Constants.ets` 已收口文字、品牌、功能、背景、星图、阴影、按钮禁用态、动画时长和圆角 | 源码确认 |
| 公共 Builder | `apps/harmonyos/entry/src/main/ets/common/Builders.ets` 已有 `TitleBar`、`GradientHeader`、`EmptyState`、`LoadingState`、`StagedProgress`、`AnswerOption`、`ReviewDetailRow` | 源码确认 |
| Chat 阅读底座 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` 已有 `markdownBlocks()`、`readableMarkdown()`、`MarkdownContent()`、代码块行号、横向滚动、表格整理、引用块、任务项、`解释这段` 入口 | 源码确认 |
| Quiz 等待与复盘底座 | `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets` 已有 `generationSteps`、`scoringSteps`、题量选择、标签聚焦、结果错因标签、`问学伴复盘`、`练这个标签` | 源码确认 |
| Lesson 互动底座 | `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets` 已有 `LessonExperience`、`LearningActivity`、`MasteryBrief()`、`IntroExperience()`、`PracticeExperience()`、`CodeBlock()`、`CodeRunPanel()` | 源码确认 |
| LearningMap 底座 | `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets` 已有 `MapNode`、`MapEdge`、`Line` 先修边、节点状态、推荐节点和详情卡 | 源码确认 |
| 标签洞察底座 | `Profile.ets` 与 `ActivityRecords.ets` 已读取 `LocalLearningRepository.getTagInsights()` 并用 `Progress` 展示准确率 | 源码确认 |
| 端侧学习资源 | `knowledge-chunks.json` 147 条、`lesson-experiences.json` 33 条、`quizzes.json` 165 条、`topic-relations.json` 33 条、`external-resources.json` 36 条 | 源码确认 |
| 服务卡片漂移点 | `widget/pages/LearningPlanCard.ets` 仍直接写 `#176BFF`、`#111827`、`#F4F7FC` 等色值 | 源码确认 |

## 二、结论摘要

| 方向 | 结论 | 决策 | 证据 |
|---|---|---|---|
| ArkUI 原生能力 | `Progress`、`LoadingProgress`、`SymbolGlyph`、`Line`、`Scroll`、`Stack`、`animateTo`、`promptAction`、`CustomDialog` 足够支撑 2-3 周视觉升级 | 采用 | 源码确认；官方文档链接见下文 |
| Chat Markdown | 继续增强现有白名单渲染器；不在主线替换为第三方 Markdown 包 | 采用 | 源码确认 |
| AI 等待反馈 | 基于 `StagedProgress` 做 Quiz、Plan、Chat 统一阶段反馈；优先补失败恢复、重试、保留输入 | 采用 | 源码确认 |
| 星图高级化 | 继续使用 `Line` 和节点卡；先做一跳邻域、箭头/线型、外环编码、详情解释 | 采用 | 源码确认 |
| `@luvi/lv-markdown-in` | OHPM latest `3.4.5`，MIT，`compatibleSdkVersion: 12`，体积 `1398898`，依赖公式与代码高亮包 | 暂缓，独立 proof | 线上通过；未验证 |
| `@ohos/lottie-turbo` | OHPM latest `1.0.12`，Apache-2.0，`compatibleSdkVersion: 12`，体积 `2068580`，含 `liblottie-turbo.so` | 暂缓，独立 proof | 线上通过；未验证 |
| `@ohos/mpchart` | OHPM latest `3.0.28`，Apache License 2.0，`compatibleSdkVersion: 12`，体积 `356509` | 暂缓 | 线上通过；未验证 |
| `@visactor/harmony-vchart` | OHPM latest `1.13.5`，MIT，`compatibleSdkVersion: 10`，体积 `1050392` | 暂缓 | 线上通过；未验证 |
| `@lidary/markdown` | OHPM latest `3.0.5`，MIT，`compatibleSdkVersion: 15` | 拒绝主线 | 线上通过；当前项目 API 12 |
| `FluidMarkdown` | GitHub 未归档，Apache-2.0；README 方向高于 API 12 主线要求 | 拒绝主线 | 线上通过；未验证 |
| 图标资源 | 默认系统 `SymbolGlyph`；Tabler、Phosphor、Lucide、Iconoir 只作单 SVG 补缺或设计参考 | 暂缓入 HAP | 线上通过；未验证 |
| 插画资源 | Open Peeps 可做 1 张空态 proof；unDraw、ManyPixels 只作构图参考 | 暂缓入 HAP | 线上通过；未验证 |
| 音效资源 | Mixkit 可做 1 个短音效 proof；Pixabay、Freesound 需逐条授权建账 | 暂缓入 HAP | 线上通过；未验证 |
| 字体资源 | 当前使用系统字体；Noto Sans CJK 仅在缺字时做子集化 proof | 暂缓 | 线上通过；未验证 |
| Web 生态库 | canvas-confetti、SpinKit CSS、Zustand、Comlink、BlurHash、web-vitals 不进入 HAP | 拒绝 | 源码确认 |

## 三、ArkUI 原生资源

| 资源 | 来源 | 当前落点 | API 12 落地性 | 风险 | 决策 |
|---|---|---|---|---|---|
| `Progress` | [Huawei Progress](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-progress) | `Builders.ets`、`Quiz.ets`、`Lesson.ets`、`LearningMap.ets`、`Profile.ets`、`ActivityRecords.ets` | 已在当前源码使用 | 单线性进度视觉单薄 | 采用，配合阶段文案与标签说明 |
| `LoadingProgress` | [Huawei LoadingProgress](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-loadingprogress) | `LoadingState()`、`StagedProgress()`、Chat 回答生成过程 | 已在当前源码使用 | 只转圈会像普通加载页 | 采用，必须绑定具体阶段 |
| `SymbolGlyph` | [HarmonyOS Symbol](https://developer.huawei.com/consumer/en/design/harmonyos-symbol/)、[SymbolGlyph](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-symbolglyph) | 多页面按钮、空态、学伴头像、结果图标 | 已在当前源码使用 | 新 symbol 名必须从 SDK 或源码核验 | 采用，作为默认图标体系 |
| `Line` / `Stack` | [ArkUI Canvas](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-canvas)、[CanvasRenderingContext2D](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-canvasrenderingcontext2d) | `LearningMap.ets` 使用 `Line` 绘制先修边 | 已在当前源码使用 | 手机小屏边线与标签重叠 | 采用，先做一跳邻域和线型 |
| ArkUI 动画 | [ArkUI Animation](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkui-ts-animation) | 当前仅有页面转场和少量状态反馈 | 未新增运行证据 | 过量动效会干扰学习 | 采用小范围：按钮反馈、节点点亮、答对轻反馈 |
| `promptAction` | [promptAction](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-promptaction) | 当前页面多用内嵌 banner | 未新增运行证据 | Toast 频繁会打断学习 | 采用，限错误恢复和短成功反馈 |
| `CustomDialog` | [CustomDialog](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-methods-custom-dialog-box) | 当前未作为统一组件 | 未验证 | 弹窗泛滥会破坏学习流 | 后置，只用于确认、权限、危险操作 |
| `StyledString` | [StyledString](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-universal-styled-string) | Chat 目前用 `Text` 分块白名单渲染 | 未验证 | 与现有 Markdown 解析边界需要拆清 | P1 研究，先不替换 |
| `RichEditor` | [RichEditor](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-richeditor) | 当前无笔记编辑器 | 未验证 | 目标偏离“阅读、练习、复盘” | 后置，不进 2-3 周主线 |

## 四、OHPM 与开源组件审计

元数据读取时间：2026-07-04。来源为 OHPM 公开包元数据端点或 GitHub API。

| 资源 | 来源 | latest / 许可 | 维护状态 | API 12 与包体 | 依赖/风险 | 决策 |
|---|---|---|---|---|---|---|
| `@luvi/lv-markdown-in` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40luvi%2Flv-markdown-in)、[Gitee](https://gitee.com/luvi/lv-markdown-in) | `3.4.5` / MIT | modified `2026-07-03T17:15:28.342Z` | `compatibleSdkVersion: 12`，size `1398898` | 依赖 `@luvi/html2md`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid`；流式更新、代码块、表格、包体未验证 | 暂缓，独立 proof |
| `@ohos/lottie-turbo` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie-turbo)、[GitCode](https://gitcode.com/openharmony-sig/lottie_turbo) | `1.0.12` / Apache-2.0 | modified `2026-05-20T09:41:43.229Z` | `compatibleSdkVersion: 12`，size `2068580` | 原生库 `liblottie-turbo.so`；HAP 增量、ABI、生命周期、真机帧率未验证 | 暂缓，独立 proof |
| `@ohos/lottie` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie)、[GitCode](https://gitcode.com/openharmony-tpc/lottieArkTS.git) | `2.0.31` / MIT | modified `2026-05-21T15:30:58.039Z` | latest 元数据未给 `compatibleSdkVersion`，size `204695` | API 12 结论不足；旧方案不得直接套入主线 | 暂缓 |
| `@ohos/mpchart` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40ohos%2Fmpchart)、[GitCode](https://gitcode.com/openharmony-tpc/ohos_mpchart) | `3.0.28` / Apache License 2.0 | modified `2026-04-27T10:09:51.523Z` | `compatibleSdkVersion: 12`，size `356509` | Profile/ActivityRecords 首批可用原生 `Progress` 和列表完成；图表库扩大依赖面 | P2 暂缓 |
| `@visactor/harmony-vchart` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40visactor%2Fharmony-vchart)、[VChart](https://www.visactor.io/vchart) | `1.13.5` / MIT | modified `2025-02-18T14:16:10.958Z` | `compatibleSdkVersion: 10`，size `1050392` | OHPM latest 未给 repository；当前标签洞察不需要复杂图表 | 暂缓 |
| `@abner/toast` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40abner%2Ftoast)、[GitHub](https://github.com/AbnerMing888/HarmonyOSToast) | `1.0.1` / Apache-2.0 | modified `2025-09-08T09:24:11.698Z` | `compatibleSdkVersion: 12` | 原生 `promptAction` 已覆盖；不新增重复 Toast 库 | 拒绝 |
| `@lyb/loading-dialog` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40lyb%2Floading-dialog)、[Gitee](https://gitee.com/lyb5834/loading-dialog.git) | `2.1.7` / MIT | modified `2025-03-31T17:02:09.157Z` | `compatibleSdkVersion: 12`，size `35841` | `StagedProgress` 已覆盖长任务；不新增重复 Loading Dialog | 拒绝 |
| `@yunkss/eftool` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40yunkss%2Feftool)、[Gitee](https://gitee.com/yunkss/ef-tool.git) | `2.0.3` / Apache-2.0 | modified `2024-11-11T09:43:04.252Z` | `compatibleSdkVersion: 12` | 聚合网络、加密、JSON、UI、RCP 等能力，超过视觉升级边界 | 拒绝 |
| `@lidary/markdown` | [OHPM](https://ohpm.openharmony.cn/ohpm/%40lidary%2Fmarkdown)、[GitHub](https://github.com/electronicminer/Harmony-Markdown-Editor) | `3.0.5` / MIT | modified `2026-01-19T10:39:19.825Z`；GitHub pushed `2026-06-22T01:34:03Z` | `compatibleSdkVersion: 15`，size `146578` | 当前项目固定 API 12 | 拒绝主线 |
| `FluidMarkdown` | [GitHub](https://github.com/antgroup/FluidMarkdown) | Apache-2.0 | GitHub 未归档，pushed `2026-01-30T10:31:35Z` | 与当前 API 12 主线边界不一致 | 直接替换 Chat 阅读器风险高 | 拒绝主线 |

## 五、官方样例与参考实现

| 资源 | 来源 | 维护状态 | 用途 | 决策 |
|---|---|---|---|---|
| OpenHarmony app samples | [GitHub openharmony/app_samples](https://github.com/openharmony/app_samples) | 未归档，pushed `2026-06-26T12:32:43Z`，GitHub license `NOASSERTION` | 查 ArkUI 页面组织、组件示例、系统能力调用 | 参考，不复制源码 |
| OpenHarmony applications samples | [GitHub openharmony/applications_app_samples](https://github.com/openharmony/applications_app_samples) | 未归档，pushed `2026-07-02T01:06:31Z`，GitHub license `NOASSERTION` | 查应用级样例与资源组织 | 参考，不复制源码 |
| Huawei Codelabs | [GitHub huaweicodelabs/harmonyos-codelabs](https://github.com/huaweicodelabs/harmonyos-codelabs) | 未归档，pushed `2022-03-22T12:26:07Z` | 查历史教程思路 | 后置参考，以当前官方文档和本仓库源码为准 |

## 六、图标、插画、动效、音效、字体

| 资源 | 来源与许可 | 维护状态 | 进入 HAP 前要求 | 决策 |
|---|---|---|---|---|
| HarmonyOS 系统 Symbol | [HarmonyOS Symbol](https://developer.huawei.com/consumer/en/design/harmonyos-symbol/)、[SymbolGlyph](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-symbolglyph) | 平台能力 | 从 SDK 或源码核验 `symbolName`，保存页面用途和截图 | 采用 |
| HarmonyOS Design Resources | [Design Resources](https://developer.huawei.com/consumer/en/design/resource/) | 官方资源入口 | 下载包内许可、体积、可再分发边界需逐项审计 | 暂缓 |
| Tabler Icons | [GitHub](https://github.com/tabler/tabler-icons)、[LICENSE](https://raw.githubusercontent.com/tabler/tabler-icons/main/LICENSE) | 未归档，pushed `2026-06-28T11:36:43Z`，MIT | 单 SVG 建账、保留 MIT notice、记录 SHA-256、ArkUI 渲染截图 | 暂缓入 HAP |
| Phosphor Icons | [GitHub](https://github.com/phosphor-icons/core)、[LICENSE](https://raw.githubusercontent.com/phosphor-icons/core/main/LICENSE) | 未归档，pushed `2026-01-06T21:28:48Z`，MIT | 单 SVG 建账、保留 MIT notice、统一描边/填充风格 | 暂缓入 HAP |
| Lucide | [GitHub](https://github.com/lucide-icons/lucide)、[LICENSE](https://raw.githubusercontent.com/lucide-icons/lucide/main/LICENSE) | 未归档，pushed `2026-07-03T18:04:48Z`，license 文件为 ISC，并列出 Feather 派生图标 MIT notice | 单 SVG 建账，保留 ISC 与对应 MIT notice | 暂缓入 HAP |
| Iconoir | [GitHub](https://github.com/iconoir-icons/iconoir) | 未归档，pushed `2026-06-18T09:13:05Z`，MIT | 单 SVG 建账、视觉复核 | 暂缓入 HAP |
| Open Peeps | [官网](https://www.openpeeps.com/)、[CC0](https://creativecommons.org/publicdomain/zero/1.0/) | 公开素材站 | 只选 1 张空态 proof；记录具体素材页、作者、格式、体积、哈希 | 暂缓入 HAP |
| unDraw | [官网](https://undraw.co/)、[License](https://undraw.co/license) | 公开素材站 | 自定义许可需保存快照；只作构图参考 | 暂缓入 HAP |
| ManyPixels | [Gallery](https://www.manypixels.co/gallery) | 公开素材站 | 自定义许可和再分发边界需逐条审计 | 暂缓入 HAP |
| LottieFiles | [License](https://lottiefiles.com/page/license)、[Attribution help](https://help.lottiefiles.com/hc/en-us/articles/900002475966-how-do-i-give-attribution-for-a-lottie-animation-i-ve-used) | 用户上传素材平台 | 每条动画记录作者、URL、许可、JSON 图层、外部资产、时长、哈希、播放证据 | 暂缓，单动画 proof |
| Rive | [Runtimes](https://rive.app/runtimes)、[runtime LICENSE](https://github.com/rive-app/rive-runtime/blob/main/LICENSE)、[Terms](https://rive.app/docs/legal/terms-of-service) | runtime 未归档，pushed `2026-07-03T18:06:25Z`，MIT | API 12 原生运行链、编辑器隐私、社区文件授权未验证 | 暂缓 |
| Mixkit 音效 | [Sound Effects](https://mixkit.co/free-sound-effects/)、[License](https://mixkit.co/license/) | 公开音效站 | 仅 300-800ms 短音效 proof；记录关闭入口和真机播放证据 | 暂缓 |
| Pixabay | [License Summary](https://pixabay.com/service/license-summary/) | 用户上传素材平台 | 肖像、商标、第三方权利逐条排查 | 暂缓 |
| Freesound | [FAQ](https://freesound.org/help/faq/)、[CC licenses](https://creativecommons.org/cc-licenses/) | 用户上传素材平台 | CC0 可 proof；CC BY 需署名；NC 拒绝 | 暂缓 |
| Noto Sans CJK | [GitHub](https://github.com/notofonts/noto-cjk)、[OFL](https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE) | 未归档，pushed `2025-12-16T05:18:51Z`，OFL 1.1 | 只在缺字时子集化；记录体积和许可文本 | 暂缓 |

## 七、直接拒绝清单

| 资源 | 拒绝原因 | 替代方案 |
|---|---|---|
| canvas-confetti | 浏览器 Canvas/DOM 生态，不进入 HarmonyOS HAP；不得用 ArkWeb 承载庆祝动效 | ArkUI 原生轻动效；Lottie proof 通过后单动画引入 |
| SpinKit CSS / skeleton.css | CSS 动画依赖 Web 渲染管线 | `LoadingProgress`、`Progress`、ArkUI `animateTo` + 渐变骨架 |
| Zustand / Comlink / BlurHash / web-vitals | React/Web Worker/浏览器性能 API，不适合端侧 ArkTS 主线 | `AppStorage`、ArkData、TaskPool/Worker、`hiTraceMetric` |
| Toast/Dialog 聚合库 | 原生 `promptAction`、`CustomDialog` 足够，重复依赖增加维护面 | 原生能力 |
| 聚合工具包 | 能力范围过大，含网络、加密、UI 等与本任务无关能力 | 复用现有 `HttpClient`、ArkUI 原生组件 |

## 八、素材进入仓库前的建账字段

| 字段 | 要求 |
|---|---|
| `assetId` | 项目内唯一 ID |
| `sourceName` | 平台或仓库名称 |
| `sourceUrl` | 具体素材页，不是平台首页 |
| `downloadUrl` | 实际下载 URL |
| `authorOrUploader` | 页面公开作者 |
| `licenseName` | 精确许可证名称 |
| `licenseUrl` | 具体许可证 URL |
| `licenseSnapshotDate` | `YYYY-MM-DD` |
| `fileName` | 进入仓库的精确文件名 |
| `sha256` | 文件 SHA-256 |
| `bytes` | 文件字节数 |
| `format` | SVG、PNG、JSON、MP3、WAV、OTF、TTF 等 |
| `intendedUse` | 页面、触发场景、替代方案 |
| `targetPath` | 计划放置路径 |
| `attributionText` | 许可证要求的署名文本 |
| `commercialUseCheck` | 商业/竞赛使用审查结论 |
| `privacyRightsCheck` | 肖像、商标、第三方权利审查结论 |
| `hapSizeDeltaBytes` | 增加包体字节数 |
| `api12BuildEvidence` | API 12 构建证据 |
| `simulatorEvidence` | 模拟器运行证据 |
| `realDeviceEvidence` | 真机证据；没有证据时写未验证 |

## 九、Top 15 可采纳方案

1. Chat Markdown 继续原生增强：保留表格整理、代码块行号、横向滚动，补链接点击与引用展开一致性。
2. Chat 代码学习入口从单个 `解释这段` 扩到“预测输出”“定位错因”，只预填问题，不自动发送。
3. Quiz AI 出题等待态补齐失败恢复：保留课程、主题、标签、难度、题量，不让用户重选。
4. Quiz 结果页把错因标签和 `练这个标签` 放在分数卡之前，优先给下一步。
5. Plan 生成页复用 `StagedProgress`，阶段为“读取画像、拆目标、排日程、校验可执行”。
6. LearningMap 做一跳邻域：选中节点后高亮前置和后继，非邻域降透明。
7. LearningMap 边线加入箭头和线型图例，说明锁定、推荐、已完成关系。
8. LearningMap 节点外环编码最近练习证据：未练、已练、稳定、到期复习。
9. Lesson 保持“先尝试再讲解”，把 33 条 `lesson-experiences.json` 的现实案例和代码预测做成首屏信号。
10. Lesson 互动完成后显示“问学伴讲解”“同标签测验”“回到星图”三出口。
11. Profile 标签洞察改三档：待巩固、熟练、稳定；显示题量、错题数、最近练习。
12. ActivityRecords 加周目标进度和标签筛选，不做公开榜单。
13. Achievements 只由本地真实事件触发，先用 ArkUI 原生轻反馈。
14. EmptyState 使用系统 Symbol + 一句下一步，不先上大插画；Open Peeps 只做单张 proof。
15. 服务卡片 `LearningPlanCard.ets` 后续收口到设计令牌，避免主 App 与卡片视觉漂移。

## 十、未验证项

- 未安装任何 OHPM 依赖。
- 未执行 HarmonyOS 构建、DevEco 诊断、模拟器截图或真机验证。
- 未下载任何 SVG、PNG、Lottie JSON、Rive、音效或字体。
- `@luvi/lv-markdown-in`、`@ohos/lottie-turbo`、`@ohos/mpchart` 的 API 12 构建、包体增量、运行性能、生命周期均为未验证。
- 图标 SVG 渲染、Open Peeps 空态图、Lottie 动画、音效播放、字体注册均为未验证。
- 华为官方文档链接在命令行 `HEAD` 请求下返回 403；本文件只将其作为官方入口链接，不把它记为 HTTP 200 证据。
