# 鸿学伴端侧前端资源全网深猎清单（2026-07-03）

本文件面向 HarmonyOS API 12 端侧交付，目标是把“端侧太素、缺少真实产品参考与资产体系”的问题转成可审计、可分期、可回退的资源方案。本轮只做调研、证据建账和路线收口，没有下载外部资产，没有安装 OHPM 依赖，没有修改 `apps/harmonyos` 源码。

证据等级沿用仓库规范：**源码确认**、**线上通过**、**未验证**。外部网页和 registry 的 **线上通过** 只证明公开 URL 可访问、HTTP 状态和公开字段可读取；不证明 HAP 构建、模拟器渲染或真机播放通过。

## 一、仓库基线

| 项目 | 精确信息 | 证据 |
|---|---|---|
| 当前分支 | `codex/harmony-frontend-deep-hunt-20260703` | 源码确认 |
| 目标 SDK | `apps/harmonyos/build-profile.json5` 中 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)` | 源码确认 |
| OHPM 依赖 | `apps/harmonyos/oh-package.json5` 与 `apps/harmonyos/entry/oh-package.json5` 的 `dependencies` 均为空对象 | 源码确认 |
| 端侧设计令牌 | `apps/harmonyos/entry/src/main/ets/common/Constants.ets` 收口颜色、半径、动画时长、星图色板 | 源码确认 |
| 公共 Builder | `apps/harmonyos/entry/src/main/ets/common/Builders.ets` 已有 `TitleBar`、`GradientHeader`、`EmptyState`、`LoadingState`、`StagedProgress`、`AnswerOption`、`ReviewDetailRow` | 源码确认 |
| Markdown 底座 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` 已有 `markdownBlocks()` 与 `MarkdownContent()`，覆盖标题、列表、代码块、分隔线、表格行折叠和基础段落 | 源码确认 |
| 学习星图底座 | `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets` 已有 `MapNode`、`MapEdge`、`Line` 边、节点光晕、四状态图例、推荐节点和详情卡 | 源码确认 |
| 标签洞察底座 | `TagInsight`、`TopicMastery`、`ReviewItem` 在 `DataModels.ets` 已存在，`LocalLearningRepository.getTagInsights()` 与 `getTopicMastery()` 已存在 | 源码确认 |
| 课程互动底座 | `LessonExperience` 与 `LearningActivity` 在 `DataModels.ets` 已存在，`Lesson.ets` 已有 `MasteryBrief()`、`IntroExperience()`、`PracticeExperience()`、`CodeBlock()`、`CodeRunPanel()` | 源码确认 |
| rawfile 资源 | `knowledge-chunks.json` 147 条、`lesson-experiences.json` 33 条、`quizzes.json` 165 条、`topic-relations.json` 33 条、`external-resources.json` 36 条；无 Lottie、第三方 SVG、音效、字体资源 | 源码确认 |
| 服务卡片视觉 | `apps/harmonyos/entry/src/main/ets/widget/pages/LearningPlanCard.ets` 仍直接写 `#176BFF`、`#111827`、`#F4F7FC` 等色值 | 源码确认 |

## 二、结论摘要

| 方向 | 本轮结论 | 采用级别 | 证据 |
|---|---|---|---|
| ArkUI 原生组件 | `Progress`、`LoadingProgress`、`SymbolGlyph`、`Line`、`Stack`、`animateTo`、`promptAction`、`CustomDialog` 是 2-3 周内最稳路线 | 采用 | 线上通过 + 源码确认 |
| 现有手写 Markdown | 先增强 `Chat.ets` 的现有白名单解析，不直接替换为第三方 Markdown 包；源码已支持标题、引用、任务项、列表、表格行折叠、分隔线和代码块 | 采用 | 源码确认 |
| `@luvi/lv-markdown-in` | OHPM latest `3.4.5`，license MIT，registry 声明 `compatibleSdkVersion: 12`；本仓库未安装、未构建、未运行 | 暂缓，独立 proof | 线上通过 + 未验证 |
| Lottie | `@ohos/lottie-turbo` registry 声明 API 12，适合做单包 proof；真机播放、生命周期、HAP 体积未验证 | 暂缓，独立 proof | 线上通过 + 未验证 |
| 图表 | `@ohos/mpchart` registry 声明 API 12；当前标签洞察先用 ArkUI 原生 `Progress`、`Grid`、`Line` | 暂缓 | 线上通过 + 未验证 |
| 图标 | 默认使用系统 `SymbolGlyph`；Tabler、Phosphor、Lucide、Iconoir 只作设计参考或单 SVG 补缺 | 暂缓入 HAP | 线上通过 + 未验证 |
| 插画 | Open Peeps 可作为少量空态插画方向；unDraw、ManyPixels 因自定义许可和再分发边界只作构图参考 | 暂缓入 HAP | 线上通过 + 未验证 |
| 音效 | Mixkit 可做少量短音效方向；Pixabay、Freesound 必须逐条留存许可证明和权利排查 | 暂缓入 HAP | 线上通过 + 未验证 |
| 字体 | 当前继续用系统字体；Noto Sans CJK 只在缺字时做子集化评估 | 暂缓 | 线上通过 + 未验证 |
| Web 库 | canvas-confetti、SpinKit CSS、Zustand、Comlink、BlurHash、web-vitals 不进入 HarmonyOS HAP | 拒绝 | 源码确认 |

## 三、ArkUI 原生资源

| 资源 | 来源 | 许可证 | 维护状态 | API 12 / ArkUI 落地性 | 风险 | 结论 | 证据 |
|---|---|---|---|---|---|---|---|
| `Progress` | [Huawei Progress](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-progress) | 平台能力 | 2026-07-03 HTTP 200 | `Course.ets`、`Lesson.ets`、`Quiz.ets`、`Practice.ets`、`Profile.ets` 已使用 | 单进度条信息量不足，需阶段文案 | 采用 | 线上通过 + 源码确认 |
| `LoadingProgress` | [Huawei LoadingProgress](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-loadingprogress) | 平台能力 | 2026-07-03 HTTP 200 | `Builders.ets` 和长任务页面已使用 | 只转圈会显得廉价 | 采用，必须绑定 `StagedProgress` | 线上通过 + 源码确认 |
| `SymbolGlyph` | [Huawei SymbolGlyph](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-symbolglyph) | 平台能力 | 2026-07-03 HTTP 200 | `Builders.ets`、`Lesson.ets`、`LearningMap.ets`、`Profile.ets` 等已使用 | 新符号名必须从 SDK 或源码核验 | 采用 | 线上通过 + 源码确认 |
| `Line` / `Stack` / Canvas 绘制 | [Huawei Canvas](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-canvas)、[CanvasRenderingContext2D](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-canvasrenderingcontext2d) | 平台能力 | 2026-07-03 HTTP 200 | `LearningMap.ets` 已用 `Line` 绘制先修边 | 小屏拥挤、触控区域需截图验收 | 采用 | 线上通过 + 源码确认 |
| ArkUI 动画 | [Huawei Animation](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkui-ts-animation) | 平台能力 | 2026-07-03 HTTP 200 | 适合节点点亮、按钮反馈、答对反馈、骨架 shimmer | 动效遮挡正文会损害学习体验 | 采用 | 线上通过；具体新动效未验证 |
| `promptAction` / 系统弹窗 | [promptAction](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-promptaction)、[CustomDialog](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-methods-custom-dialog-box) | 平台能力 | 2026-07-03 HTTP 200 | 可覆盖 Toast、Dialog、错误恢复和确认提示 | 频繁弹窗会打断学习流 | 采用 | 线上通过；具体新交互未验证 |
| `StyledString` | [Huawei StyledString](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-universal-styled-string) | 平台能力 | 2026-07-03 HTTP 200 | 可研究 Chat 行内代码、粗体、链接文本白名单 | 与现有手写 Markdown 需要拆分边界 | P1 研究 | 线上通过；未验证 |
| `RichEditor` | [Huawei RichEditor](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-basic-components-richeditor) | 平台能力 | 2026-07-03 HTTP 200 | 可作为学习笔记后续方向 | 当前目标是阅读和练习，不扩成编辑器 | P2 后置 | 线上通过；未验证 |

## 四、OHPM 与开源组件

| 资源 | 来源 | 许可证 | 维护状态 | API 12 / HarmonyOS 落地性 | 风险 | 结论 | 证据 |
|---|---|---|---|---|---|---|---|
| `@luvi/lv-markdown-in` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40luvi%2Flv-markdown-in)、[Gitee](https://gitee.com/luvi/lv-markdown-in) | MIT | latest `3.4.5`，modified `2026-07-03T17:15:28.342Z` | registry 声明 `compatibleSdkVersion: 12` | 依赖 `@luvi/html2md`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid`；包体、流式更新、长列表性能未验证 | P1 单包 proof | 线上通过 + 未验证 |
| `FluidMarkdown` | [GitHub](https://github.com/antgroup/FluidMarkdown)、[LICENSE](https://raw.githubusercontent.com/antgroup/FluidMarkdown/main/LICENSE) | Apache-2.0 | GitHub API：未归档，pushed `2026-01-30T10:31:35Z`，updated `2026-06-27T13:54:43Z` | README 标注 HarmonyOS 最低 API 15，高于当前 API 12 | 直接引入违反目标 SDK 边界 | 拒绝直接引入 | 线上通过 + 未验证 |
| Harmony Markdown Editor / `@lidary/markdown` | [GitHub](https://github.com/electronicminer/Harmony-Markdown-Editor)、[OHPM registry](https://ohpm.openharmony.cn/ohpm/%40lidary%2Fmarkdown) | MIT | GitHub API：未归档，pushed `2026-06-22T01:34:03Z` | OHPM 声明 `compatibleSdkVersion: 15` | 高于当前 API 12；编辑器架构超出 Chat 阅读需求 | 拒绝直接引入 | 线上通过 + 未验证 |
| `@ohos/lottie-turbo` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie-turbo)、[GitCode](https://gitcode.com/openharmony-sig/lottie_turbo) | Apache-2.0 | latest `1.0.12`，modified `2026-05-20T09:41:43.229Z` | registry 声明 `compatibleSdkVersion: 12` | 依赖 `liblottie-turbo.so`；HAP 体积、ABI、生命周期、真机帧率未验证 | P1 单包 proof | 线上通过 + 未验证 |
| `@ohos/lottie` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie)、[GitCode](https://gitcode.com/openharmony-tpc/lottieArkTS) | MIT | latest `2.0.31`，modified `2026-05-21T15:30:58.039Z` | latest 元数据未提供 `compatibleSdkVersion` 字段 | API 12 结论不足；Lottie JSON 仍需逐条审计 | 暂缓 | 线上通过 + 未验证 |
| `@ohos/mpchart` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40ohos%2Fmpchart)、[GitCode](https://gitcode.com/openharmony-tpc/ohos_mpchart) | Apache License 2.0 | latest `3.0.28`，modified `2026-04-27T10:09:51.523Z` | registry 声明 `compatibleSdkVersion: 12` | 标签洞察首批可用原生组件完成；图表库扩大依赖面 | P2 暂缓 | 线上通过 + 未验证 |
| `@visactor/harmony-vchart` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40visactor%2Fharmony-vchart) | MIT | latest `1.13.5`，modified `2025-02-18T14:16:10.958Z` | registry 声明 `compatibleSdkVersion: 10` | 元数据缺少本轮可核验 repository；维护时间早于 `@ohos/mpchart` | 暂缓 | 线上通过 + 未验证 |
| `@abner/toast` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40abner%2Ftoast)、[GitHub](https://github.com/AbnerMing888/HarmonyOSToast) | OHPM: Apache-2.0；GitHub API: `NOASSERTION` | latest `1.0.1`，modified `2025-09-08` | registry 声明 `compatibleSdkVersion: 12` | 原生 `promptAction` 已覆盖；GitHub 许可证识别不足 | 拒绝引入 | 线上通过 + 未验证 |
| `@lyb/loading-dialog` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40lyb%2Floading-dialog) | MIT | latest `2.1.7`，modified `2025-03-31T17:02:09.157Z` | registry 声明 `compatibleSdkVersion: 12` | `StagedProgress` 已覆盖长任务反馈；不新增重复弹窗库 | 拒绝引入 | 线上通过 + 未验证 |
| `@yunkss/eftool` | [OHPM registry](https://ohpm.openharmony.cn/ohpm/%40yunkss%2Feftool) | Apache-2.0 | latest `2.0.3`，modified `2024-11-11T09:43:04.252Z` | registry 声明 `compatibleSdkVersion: 12` | 聚合工具包包含网络、加密、UI、通知、位置、窗口等能力，超过本任务范围 | 拒绝引入 | 线上通过 + 未验证 |

## 五、图标、插画、动效、音效、字体

| 资源 | 来源与许可 | 进入 HAP 前要求 | 风险 | 结论 | 证据 |
|---|---|---|---|---|---|
| HarmonyOS 系统 Symbol | [HarmonyOS Symbol](https://developer.huawei.com/consumer/en/design/harmonyos-symbol/)、[SymbolGlyph API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph) | 记录 `symbolName`、页面、用途、截图证据 | 新符号名需 SDK 核验 | 采用 | 线上通过 + 源码确认 |
| HarmonyOS Design Resources | [Design Resources](https://developer.huawei.com/consumer/en/design/resource/) | 读取下载包内许可后再评估 | 资源包许可和包体未审计 | 暂缓 | 线上通过；未验证 |
| Tabler Icons | [GitHub](https://github.com/tabler/tabler-icons)、[MIT](https://raw.githubusercontent.com/tabler/tabler-icons/main/LICENSE) | 单 SVG 建账、保留 MIT notice、记录 SHA-256 | 整包引入会形成多套图标语言 | 暂缓入 HAP | 线上通过；ArkUI SVG 未验证 |
| Phosphor Icons | [GitHub](https://github.com/phosphor-icons/core)、[MIT](https://raw.githubusercontent.com/phosphor-icons/core/main/LICENSE) | 单 SVG 建账、保留 MIT notice | 多 weight 风格与系统 Symbol 不一致 | 暂缓入 HAP | 线上通过；ArkUI SVG 未验证 |
| Lucide | [GitHub](https://github.com/lucide-icons/lucide)、[ISC](https://raw.githubusercontent.com/lucide-icons/lucide/main/LICENSE) | 单 SVG 建账、保留 ISC notice | Feather 派生关系需保留许可文本 | 暂缓入 HAP | 线上通过；ArkUI SVG 未验证 |
| Iconoir | [GitHub](https://github.com/iconoir-icons/iconoir)、[MIT](https://raw.githubusercontent.com/iconoir-icons/iconoir/main/LICENSE) | 单 SVG 建账、保留 MIT notice | 图标风格较强，需视觉复核 | 暂缓入 HAP | 线上通过；ArkUI SVG 未验证 |
| Open Peeps | [官网](https://www.openpeeps.com/)、[CC0](https://creativecommons.org/publicdomain/zero/1.0/) | 记录具体素材、格式、体积、用途、哈希 | 人物风格强；空态控量使用 | 少量空态素材方向 | 线上通过；HAP 渲染未验证 |
| unDraw | [官网](https://undraw.co/)、[License](https://undraw.co/license) | 仅参考构图；如使用需保存许可快照 | 自定义许可禁止打包再分发等场景 | 暂缓入 HAP | 线上通过；HAP 集成未验证 |
| ManyPixels | [Gallery](https://www.manypixels.co/gallery) | 仅参考构图；如使用需保存许可快照 | 自定义许可与再分发边界 | 暂缓入 HAP | 线上通过；HAP 集成未验证 |
| LottieFiles | [License](https://lottiefiles.com/page/license)、[Attribution Help](https://help.lottiefiles.com/hc/en-us/articles/900002475966-how-do-i-give-attribution-for-a-lottie-animation-i-ve-used) | 逐条记录作者、URL、许可、JSON 图层、外部资产、时长、哈希 | 用户上传权利、外链图片、帧率、生命周期 | 暂缓，单动画 proof | 线上通过；播放未验证 |
| Rive | [Runtimes](https://rive.app/runtimes)、[runtime MIT](https://github.com/rive-app/rive-runtime/blob/main/LICENSE)、[Terms](https://rive.app/docs/legal/terms-of-service) | 运行时与社区文件逐条授权 | API 12 原生运行链未验证，云端编辑有隐私边界 | 暂缓 | 线上通过；API 12 未验证 |
| Mixkit 音效 | [Sound Effects](https://mixkit.co/free-sound-effects/)、[License](https://mixkit.co/license/) | 记录音效 URL、时长、格式、体积、触发场景 | 音效打扰学习；需可关闭 | 暂缓，少量短音效 proof | 线上通过；HAP 播放未验证 |
| Pixabay | [License Summary](https://pixabay.com/service/license-summary/) | 留存许可证明，排查肖像、商标、第三方权利 | 用户上传素材审计成本高 | 暂缓 | 线上通过；HAP 播放/渲染未验证 |
| Freesound | [FAQ](https://freesound.org/help/faq/)、[CC licenses](https://creativecommons.org/cc-licenses/) | 仅 CC0 直接纳入 proof；CC BY 需署名；NC 拒绝 | 质量、署名和体积差异大 | CC0 可 proof，NC 拒绝 | 线上通过；HAP 播放未验证 |
| Noto Sans CJK | [GitHub](https://github.com/notofonts/noto-cjk)、[OFL](https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE) | 子集化、保留 OFL 文本、记录体积 | CJK 字体包体大；当前系统字体已满足 | 暂缓内置 | 线上通过；字体注册未验证 |

## 六、素材建账模板

任何素材进入 HAP 前必须补齐以下字段，缺一项不得复制进 `apps/harmonyos/entry/src/main/resources/`。

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

## 七、Top 10 可采纳方案

1. `Chat.ets` 的 Markdown 继续原生增强：代码语言条、行号、横向滚动、引用块、表格横滚、行内代码。
2. `Builders.ets` 把 `StagedProgress` 扩成统一长任务组件，服务 Chat、Quiz、Plan、保存和评分。
3. `Quiz.ets` 出题等待态改成“选范围、生成题、校验答案、准备复盘”四段，失败保留题目条件。
4. `Profile.ets` 与 `ActivityRecords.ets` 用 `TagInsight` 推导三档掌握状态：待巩固、熟练、稳定。
5. `LearningMap.ets` 增加一跳邻域、箭头方向、锁定线型和外环编码，不引入图谱库。
6. `Lesson.ets` 将现有 `CodeRunPanel()` 与互动练习组件化，做每门课程 1 个更强的“先尝试再讲解”体验。
7. `Practice.ets` 和 `MistakeBook.ets` 做 10 分钟复习包：错题、未练、回访题透明排序。
8. `Achievements.ets` 只奖励真实本地事件，首批用 ArkUI 原生 `animateTo`，Lottie 只进独立 proof。
9. 图标体系默认 `SymbolGlyph`，第三方 SVG 只允许单图补缺并附 notice。
10. 空态素材先用 Open Peeps 做 1 张 proof，其他插画站只作为构图参考。

## 八、未验证项

- 未安装任何 OHPM 依赖。
- 未执行 HarmonyOS 构建、模拟器截图或真机验证。
- 未下载任何 SVG、PNG、Lottie JSON、音效、字体文件。
- `@luvi/lv-markdown-in`、`@ohos/lottie-turbo`、`@ohos/mpchart` 的构建、包体、运行性能仍为未验证。
- 图标 SVG 渲染、Open Peeps 空态图、Lottie 动画、音效播放、字体注册均为未验证。
- 服务卡片设计令牌收口未实施，本轮仅记录 `LearningPlanCard.ets` 存在硬编码色值。
