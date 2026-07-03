# 鸿学伴端侧前端资源图谱（2026-07-03）

本文件面向 HarmonyOS 端侧产品化，不引入依赖、不下载素材、不修改 HAP 资源目录。证据等级沿用仓库规范：**官方确认**、**源码确认**、**构建通过**、**模拟器通过**、**真机通过**、**未验证**。

## 0. 本轮核验基线

### 本地仓库

| 项 | 结论 | 证据等级 |
|---|---|---|
| 当前分支 | `codex/harmony-1.16-frontend-resource-atlas-20260703` | 源码确认 |
| HarmonyOS 目标版本 | `apps/harmonyos/build-profile.json5` 中 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)` | 源码确认 |
| 端侧依赖 | `apps/harmonyos/oh-package.json5` 与 `apps/harmonyos/entry/oh-package.json5` 的 `dependencies` 为空 | 源码确认 |
| 当前端侧页面资源底座 | `Builders.ets` 已有 `StagedProgress`、`SymbolGlyph`、`Progress`、`LoadingProgress`；`Chat.ets` 已有 `MarkdownContent`；`LearningMap.ets` 已有 `MapCanvas`；`Profile.ets` 已有 `TagInsightRow` | 源码确认 |
| 用户点名的 20260702 三份深猎文档 | `docs/FRONTEND-ASSET-HUNT-DEEP-20260702.md`、`docs/FRONTEND-ASSET-ADOPTION-SPEC-20260702.md`、`docs/FRONTEND-PRODUCTIZATION-ROADMAP-20260702.md` 不存在 | 源码确认 |
| 本轮运行设备 | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe list targets` 返回 `127.0.0.1:5555` | 源码确认 |

### 只读命令结果

| 命令 | 退出码 | 结论 |
|---|---:|---|
| `git status --short` | 0 | 开始时无输出，工作树干净 |
| `git log -5 --oneline` | 0 | 最新为 `4e0d9d1 feat: 增强端侧学伴 Markdown 渲染` |
| `ohpm -v` | 0 | `26.0.0.410` |
| `ohpm info @luvi/lv-markdown-in` | 1 | OHPM registry 返回 502，包信息未取到 |
| `ohpm info @ohos/lottie` | 1 | OHPM registry 返回 502，包信息未取到 |
| `ohpm info @ohos/lottie-turbo` | 1 | OHPM registry 返回 502，包信息未取到 |
| `ohpm info @ohos/mpchart` | 1 | OHPM registry 返回 502，包信息未取到 |

> 说明：OHPM 502 只能证明本轮 registry 查询不可用，不能证明包不存在，也不能证明包可用于生产。

## 1. P0 原生资源：先用系统能力把学习体验做厚

| 能力 | 证据链接 | 许可证/授权 | API 12 适配证据 | 离线与隐私 | 包体/性能风险 | 鸿学伴落点 | 结论 |
|---|---|---|---|---|---|---|---|
| HarmonyOS Design 与 ArkUI 组件语言 | [HarmonyOS Design](https://developer.huawei.com/consumer/cn/design/) | 平台规范，不复制第三方素材 | 页面可访问；端侧已使用 ArkUI 原生组件 | 离线无影响；无隐私输入 | 无新增包体 | 全局页面节奏、状态层级、按钮密度 | **官方确认**，P0 |
| `SymbolGlyph` 系统 Symbol | [OpenHarmony SymbolGlyph 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-symbolGlyph.md) | 系统预置符号资源；不得混入 Apple/Material 资产 | 文档标注组件 API 11 起支持，ArkTS 卡片/原子化服务 API 12 起支持；仅支持 `$r('sys.symbol.xxx')` 系统预置 symbol | 离线可用；无隐私输入 | 图标由系统渲染，包体为 0 | 全局功能图标、空态图标、标签语义 | **官方确认 + 源码确认**，P0 |
| `Progress` | [OpenHarmony Progress 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-progress.md) | 平台组件 | API 7 起支持；`ProgressType` API 8 起；线性、环形、胶囊等类型可用 | 离线可用；无隐私输入 | 无新增包体；复杂环形过多时注意重绘 | 计划、课程、答题、成就、标签洞察 | **官方确认 + 源码确认**，P0 |
| `LoadingProgress` | [OpenHarmony LoadingProgress 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-loadingprogress.md) | 平台组件 | API 8 起支持；`enableLoading` API 10；`contentModifier` API 12 | 离线可用；无隐私输入 | 无新增包体；需设置合理宽高 | AI 出题、计划生成、Chat SSE 等待 | **官方确认 + 源码确认**，P0 |
| `Text` + `Span`/`SymbolSpan` | [OpenHarmony Text 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-text.md) | 平台组件 | API 7 起支持；支持 `Span`、`ImageSpan`、`SymbolSpan`、`ContainerSpan` 子组件 | 离线可用；文本来自本地或真实模型输出时按现有安全链路处理 | 无新增包体；长文本需滚动与折行保护 | Chat Markdown、Lesson 正文、引用卡 | **官方确认**，P0 |
| `RichEditor` | [OpenHarmony RichEditor 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-richeditor.md) | 平台组件 | API 10 起支持；StyledString 初始化 API 12 | 离线可用；若用于用户输入需复用现有长度与安全校验 | 交互复杂，不能替代 Markdown 渲染器直接上主线 | 手写推演、代码学习输入、未来富文本笔记 | **官方确认**，P1 |
| `Canvas` | [OpenHarmony Canvas 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-components-canvas-canvas.md) | 平台组件 | API 8 起支持；API 12 支持 `DrawingRenderingContext` 与 ImageAIOptions；最大面积约束需遵守 | 离线可用；禁用不必要图片 AI 分析 | 需要控制尺寸、不可见状态绘制、重绘频率 | 学习星图、概念玩具、复习热力图 | **官方确认 + 源码确认**，P0 |
| `Path2D` | [OpenHarmony Path2D 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-components-canvas-path2d.md) | 平台组件 | API 8 起支持；API 12 支持单位模式；可用 SVG path 字符串构造 | 离线可用；无隐私输入 | 不支持重置路径，复杂图需新建对象并缓存 | LearningMap 方向箭头、树/图结构图 | **官方确认**，P0 |
| `keyframeAnimateTo` | [OpenHarmony keyframeAnimateTo 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-keyframeAnimateTo.md) | 平台组件 | API 11 起支持；原子化服务 API 12；需通过 `UIContext` 调用 | 离线可用；无隐私输入 | 动画过多会干扰学习任务；只用于短正反馈 | 全对、解锁、连续学习、完成任务 | **官方确认**，P0 |
| `Grid` | [OpenHarmony Grid 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-container-grid.md) | 平台组件 | API 7 起支持；文档建议动态生成时优先 `LazyForEach` 或 `Repeat` 优化性能 | 离线可用；无隐私输入 | 大量格子需虚拟化或分页 | ActivityRecords 热力图、成就墙 | **官方确认**，P1 |
| `TextArea` | [OpenHarmony TextArea 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-textarea.md) | 平台组件 | API 7 起支持；API 11 支持宽度自适应相关能力 | 用户输入需长度、敏感内容和本地持久化边界 | 无新增包体；键盘遮挡需 UI 验收 | Lesson 先预测再揭示、代码推演板 | **官方确认 + 源码确认**，P0 |
| `@ohos.vibrator` 触感反馈 | [OpenHarmony vibrator 文档源码](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-sensor-service-kit/js-apis-vibrator.md) | 平台 Kit | 首批接口 API 8；`startVibration` API 9；需 `ohos.permission.VIBRATE`；文档推荐预置短振用于交互反馈 | 不上传数据；需权限声明和设备能力检查 | 需要真机验证，模拟器不能证明真实触感 | 答对、全对、解锁、错误提醒 | **官方确认**，但本项目未接入，**未验证** |

## 2. OHPM 与开源库方向

| 包/库 | 来源与证据 | 许可证 | 维护状态证据 | API 12 适配证据 | 离线与隐私 | 包体/性能风险 | 鸿学伴落点 | 结论 |
|---|---|---|---|---|---|---|---|---|
| `@luvi/lv-markdown-in` | [Gitee README](https://gitee.com/luvi/lv-markdown-in)、[LICENSE](https://gitee.com/luvi/lv-markdown-in/raw/master/LICENSE)；README 写明 `ohpm install @luvi/lv-markdown-in` | MIT | Gitee API：stars 72；`pushed_at=2026-07-03 11:19:17`；latest release `markdown-singed-v3.4.4` 创建于 2026-06-25 | OHPM `info` 本轮 502；未安装；未构建；未运行 | 本地 Markdown 可离线；若启用图片/HTML/链接需限制远程资源和脚本语义 | 渲染能力强，但会引入依赖和 API 面；需长正文、代码块、表格、SSE 增量验证 | `Chat.ets`、`Lesson.ets` | **源码确认**；生产采用为**未验证** |
| `@ohos/lottie` / lottieArkTS | [Gitee README](https://gitee.com/openharmony-tpc/lottieArkTS)、[LICENSE](https://gitee.com/openharmony-tpc/lottieArkTS/raw/master/LICENSE)；README 写明 `ohpm install @ohos/lottie` | MIT | Gitee API：stars 109；latest release `2.0.17-rc.1` 创建于 2025-02-22；仓库 updated 2026-06-26 | OHPM `info` 本轮 502；未安装；未构建；未运行 | rawfile JSON 可离线；不应加载远程动画 | Lottie JSON 解析与 Canvas 渲染会增加启动/内存风险；需生命周期销毁 | 成就解锁、答题全对 | **源码确认**；生产采用为**未验证** |
| `@ohos/lottie-turbo` 方向 | [LottieC Gitee](https://gitee.com/ywp7913/lottie-c)、[LICENSE](https://gitee.com/ywp7913/lottie-c/raw/master/LICENSE) | Apache-2.0 | Gitee API：stars 0；`pushed_at=2025-06-19 17:07:29`；仓库 updated 2026-04-01 | OHPM `info` 本轮 502；README 为空；未构建；未运行 | 离线取决于本地 JSON；需确认 native 动态库边界 | 原生依赖、ABI、包体和崩溃风险高于纯 ArkUI | 暂不进入主线 | **源码确认**；生产采用为**未验证** |
| `@ohos/mpchart` | [ohos_mpchart Gitee README](https://gitee.com/openharmony-tpc/ohos_mpchart/raw/master/README.md)、[LICENSE](https://gitee.com/openharmony-tpc/ohos_mpchart/raw/master/LICENSE)；README 写明 `ohpm install @ohos/mpchart` | Apache-2.0 | Gitee API：stars 148、forks 100；latest release `3.0.21` 创建于 2025-02-20；updated 2026-01-15 | OHPM `info` 本轮 502；未安装；未构建；未运行 | 本地数据可离线；图表不应上传画像数据 | 图表能力重，学习画像当前用 `Progress`/`Grid`/`Canvas` 足够 | Profile、ActivityRecords 后续大图表 | **源码确认**；P2，生产采用为**未验证** |

## 3. 图标资源

项目默认仍应使用 `SymbolGlyph`。第三方图标只在系统 Symbol 无法表达“代码、脑图、知识网络、终端、练习类型”时逐个引入，并保留许可证文本。

| 图标源 | 许可证证据 | 维护状态证据 | 适配方式 | 风险 | 结论 |
|---|---|---|---|---|---|
| Tabler Icons | [GitHub LICENSE](https://raw.githubusercontent.com/tabler/tabler-icons/main/LICENSE)，MIT | GitHub API 本轮成功读取：stars 21059，pushed 2026-06-28 | 单个 SVG 进入 `rawfile/icons/`，ArkUI `Image` 读取；颜色需统一 | 与系统 Symbol 混用会降低一致性 | **源码确认**，P1 少量补缺 |
| Phosphor Icons | [GitHub LICENSE](https://raw.githubusercontent.com/phosphor-icons/core/main/LICENSE)，MIT | GitHub API 本轮成功读取：stars 340，pushed 2026-01-06 | 同上 | 与 Tabler 风格不可混用 | **源码确认**，P2 |
| Lucide Icons | [GitHub LICENSE](https://raw.githubusercontent.com/lucide-icons/lucide/main/LICENSE)，ISC | GitHub REST 后续触发匿名限流，未完成维护状态核验 | 同上 | 第三套线性图标不应进入主视觉 | **源码确认**，P2 |
| Iconoir | [GitHub LICENSE](https://raw.githubusercontent.com/iconoir-icons/iconoir/main/LICENSE)，MIT | GitHub REST 后续触发匿名限流，未完成维护状态核验 | 同上 | 风格更强，需单图审美复核 | **源码确认**，P2 |
| Heroicons | [GitHub LICENSE](https://raw.githubusercontent.com/tailwindlabs/heroicons/master/LICENSE)，MIT | GitHub REST 后续触发匿名限流，未完成维护状态核验 | 同上 | Web/Tailwind 生态语义，不作为主图标体系 | **源码确认**，P2 |
| Remix Icon | [GitHub License](https://raw.githubusercontent.com/Remix-Design/RemixIcon/master/License)，Remix Icon License v1.0 | GitHub REST 后续触发匿名限流，未完成维护状态核验 | 同上 | 自定义许可证，需逐条法律复核 | **源码确认**，暂不采用 |

## 4. 插画、动效、音效资源

| 资源 | 来源与许可证 | 离线与隐私 | 包体/性能风险 | 适合页面 | 结论 |
|---|---|---|---|---|---|
| Open Peeps | [官网](https://www.openpeeps.com/) 声明 CC0；[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 本地 SVG/PNG 离线；无隐私输入 | 单张可控；整包不得入仓库 | 空错题、空成就、空资料 | **官方确认**，P1 单张使用 |
| unDraw | [License](https://undraw.co/license) 允许个人/商业免费使用，但禁止资产包再分发、复刻服务、AI/ML 训练等 | 单张离线；不得批量爬取或打包 | 单张可控；品牌 logo 图不用 | 空态、错误态 | **官方确认**，P2 单张谨慎使用 |
| ManyPixels Free Illustrations | [Gallery](https://www.manypixels.co/gallery) 页面描述 free for personal and commercial projects | 单张离线；需记录具体素材页 | 自定义站点条款需逐图复核 | 空态 | **官方确认**，P2 |
| LottieFiles | [License 页面](https://lottiefiles.com/page/license) 本轮 `Invoke-WebRequest` 返回 403 | 无法完成本轮许可证读取 | 动画渲染还需 Lottie 包验证 | 暂不进入产品资源 | **未验证** |
| 项目自绘 Lottie JSON | 已在 `docs/FRONTEND-RESOURCE-ADOPTION.md` 记录 3 个 JSON 结构 | rawfile 离线；无隐私输入 | 需 Lottie 渲染链、生命周期和真机帧率验证 | 成就、全对、任务完成 | **源码确认**，渲染为**未验证** |
| Kenney Interface Sounds | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) 标注 Creative Commons CC0 | 本地音频离线；无隐私输入 | 音频文件会增加包体；需格式、音量、静音模式、无障碍验证 | 答对、完成、错误短提示 | **官方确认**，P2 |
| Freesound | [FAQ license](https://freesound.org/help/faq/#licenses-0) 说明按具体声音的 Creative Commons 许可证处理 | 单文件离线；需记录作者和许可 | 逐音效许可复杂，署名/相同方式共享风险高 | 暂不作为主来源 | **官方确认**，逐文件前均为**未验证** |
| Mixkit Sound Effects | [Mixkit License](https://mixkit.co/license/) 标注不同 item type 使用不同许可证，并有 Sound Effects commercial licence | 单文件离线；需记录具体 item 页 | 自定义许可证，需法律复核 | 暂不作为主来源 | **官方确认**，逐文件前均为**未验证** |
| Pixabay 音效 | [License summary](https://pixabay.com/service/license-summary/) 本轮 403 | 无法完成本轮许可证读取 | 无法进入 HAP | 不采用 | **未验证** |

## 5. 可落地资源图谱结论

### 立即可用（不加依赖）

1. `SymbolGlyph` 统一图标语言：补足空态、失败态、状态标签、导航按钮的语义。
2. `Progress` + `LoadingProgress` + `StagedProgress`：所有 AI 长任务使用阶段、骨架、保留输入、失败恢复，不使用只会旋转的等待态。
3. `Canvas` + `Path2D`：LearningMap 增加方向、局部邻域、节点大小编码；Lesson 做栈/队列/树/TCP/调度概念玩具。
4. `keyframeAnimateTo`：先做 600-1200ms 的成功、全对、解锁、连续学习正反馈。
5. `Text`/`TextArea`：Chat 与 Lesson 继续增强 Markdown/代码块/预测输入，不先引入未构建的 Markdown 包。
6. `Grid`：ActivityRecords 用近 4-8 周热力图表达连续学习，替代静态流水账。

### 需要单独验证后再进 HAP

1. `@luvi/lv-markdown-in`：只有在 OHPM 信息、API 12 构建、Chat SSE 增量、长正文滚动、代码块、表格、图片禁用策略全部通过后，才替换或包裹现有手写渲染。
2. `@ohos/lottie`：只有在 OHPM 信息、构建、模拟器渲染、真机帧率、页面销毁释放全部通过后，才接入项目自绘 Lottie JSON。
3. `@ohos/mpchart`：当前没有必要进入主线；画像图表先用原生 `Progress`、`Grid`、`Canvas`。
4. 第三方 SVG/插画/音效：逐个文件记录 URL、许可证 URL、下载日期、用途、哈希；不得整包提交。

## 6. 本轮未验证项

- 未安装任何 OHPM 包。
- 未执行 HAP 构建、模拟器安装、UI 树、截图或真机验收；本轮为文档研究。
- 未下载第三方 SVG、插画、Lottie、音频资产。
- LottieFiles 与 Pixabay 许可证页面本轮未能读取。
- OHPM registry 对四个包继续返回 502，所有 OHPM 生产适配结论均保持**未验证**。
