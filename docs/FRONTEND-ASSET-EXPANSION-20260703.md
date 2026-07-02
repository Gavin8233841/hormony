# 鸿学伴端侧前端资源扩展审计（2026-07-03）

本文件是 `docs/FRONTEND-ASSET-HUNT-20260702.md` 的补充审计，继续只做资料、资源和许可证验证，不修改端侧源码、不写入依赖、不下载素材。本轮验证目标是扩大资源面，并把“可直接考虑”“仅作参考”“不进入 HAP”的边界写清楚。

## 本轮验证方法

1. 工作区检查：`git status --short` 无输出；`git log -5 --oneline` 当前 HEAD 为 `e652398 docs: 梳理端侧前端资源猎采地图`。
2. OHPM 只读验证：`ohpm info @luvi/lv-markdown-in`、`@ohos/lottie-turbo`、`@ohos/lottie`、`@ohos/mpchart` 均返回 `GET https://ohpm.openharmony.cn/ohpm/... 502( Bad Gateway )`，退出码 1。
3. 可访问性验证：对 20 个资源官网或许可证页执行 `Invoke-WebRequest`。Heroicons、Bootstrap Icons、Fluent Icons、DrawKit、Storyset、Lordicon、Shiki、Cytoscape、Carbon、Atlassian Design Tokens、CodeCombat 等返回 HTTP 200；`https://lottiefiles.com/page/license` 与 `https://leetcode.com/studyplan/` 在本机返回 403。
4. 许可证首行验证：对 GitHub raw LICENSE 或 GitHub license API 读取首行。MIT、OFL、BSD-3-Clause、Apache-2.0、CC BY、CC BY-SA 等只在成功读到许可证文本后记录。

证据等级：本文件只形成**源码确认**、**许可证文本确认**、**HTTP 可访问确认**或**未验证**。没有模拟器、真机、构建或线上证据。

## 新增资源结论总表

| 资源 | 精确来源 | 初步结论 | 进入 HAP 建议 | 证据 |
|---|---|---|---|---|
| Heroicons | [官网](https://heroicons.com/)；[LICENSE](https://raw.githubusercontent.com/tailwindlabs/heroicons/master/LICENSE) | MIT；线性图标简洁 | 系统 Symbol 缺失时可少量补充；不要与 Tabler/Bootstrap 并用 | HTTP 200；raw LICENSE 首行为 `MIT License` |
| Bootstrap Icons | [官网](https://icons.getbootstrap.com/)；[LICENSE](https://raw.githubusercontent.com/twbs/icons/main/LICENSE) | MIT；图标覆盖广，开发/状态类多 | 可作为备用图标源；与 Heroicons/Fluent 三选一 | HTTP 200；raw LICENSE 首行为 `The MIT License (MIT)`；GitHub API `spdx_id=MIT` |
| Fluent UI System Icons | [Fluent 2 Iconography](https://fluent2.microsoft.design/iconography)；[LICENSE](https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/LICENSE) | MIT；regular/filled 双风格，适合状态语义 | 可作为“学习/代码/反馈”补充图标源；需逐个图标视觉复核 | HTTP 200；raw LICENSE 首行为 `MIT License` |
| Remix Icon | [仓库许可证](https://raw.githubusercontent.com/Remix-Design/RemixIcon/master/License) | 许可证为 `Remix Icon License v1.0`，不是本轮常见 OSI 许可证 | 暂不进入 HAP；除非逐条审完该自定义许可证 | raw LICENSE 已打开；许可证类型需法务/主线程复核 |
| JetBrains Mono | [官网](https://www.jetbrains.com/lp/mono/)；[OFL](https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/OFL.txt) | SIL Open Font License 1.1；代码可读性强 | 只在系统 monospace 不满足代码块阅读时评估；先测 HAP 体积和字体加载 | HTTP 200；raw LICENSE 明确 OFL 1.1 |
| Fira Code | [LICENSE](https://raw.githubusercontent.com/tonsky/FiraCode/master/LICENSE) | SIL Open Font License 1.1；连字对教学代码不一定合适 | 不优先；代码教学里连字可能干扰初学者识别真实字符 | raw LICENSE 明确 OFL 1.1 |
| Cascadia Code | [LICENSE](https://raw.githubusercontent.com/microsoft/cascadia-code/main/LICENSE) | SIL Open Font License 1.1，含 Reserved Font Name | 可作为备用代码字体；需确认 HarmonyOS 字体嵌入和体积 | raw LICENSE 已打开 |
| IBM Plex Mono | [LICENSE](https://raw.githubusercontent.com/IBM/plex/master/LICENSE.txt) | SIL Open Font License 1.1，含 Reserved Font Name `Plex` | 可作为备用代码字体；视觉比 JetBrains Mono 更正式 | raw LICENSE 明确 OFL 1.1 |
| IRA Design illustrations | [LICENSE](https://raw.githubusercontent.com/ira-design/ira-illustrations/master/LICENSE.md) | MIT；可编辑矢量插画 | 可放入 `.tmp/` 做空态视觉比对；不批量引入 | raw LICENSE 首行为 `MIT License` |
| DrawKit | [License](https://www.drawkit.com/license) | 页面返回 HTTP 200；条款写明非独占、不可转让、免版税、全球许可，可商用/非商用；仍有禁止条款 | 可作为少量空态插画来源；必须记录具体素材 URL 和下载日期 | HTTP 200；页面文本抽取到 license/commercial/not allowed 相关条款 |
| Storyset | [FAQ](https://storyset.com/faqs) | 免费插画要求署名 Storyset；无署名需 Flaticon premium | 不进入 HAP 默认资产；可作为参考或在提交材料中按要求署名使用 | HTTP 200；FAQ 文本明确 attribution |
| Lordicon | [Licenses](https://lordicon.com/licenses) | 免费许可为非商用且要求署名；PRO 有请求数和时限条款 | 不进入 HAP；仅研究动效节奏 | HTTP 200；页面文本明确 free license non-commercial |
| OpenMoji | [FAQ](https://openmoji.org/faq/)；[LICENSE](https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/LICENSE.txt) | CC BY-SA 4.0；有署名和相同方式共享义务 | 不进入 HAP 主资源；系统 emoji 或系统 Symbol 优先 | HTTP 200；raw LICENSE 首行为 `Attribution-ShareAlike 4.0 International` |
| Twemoji graphics | [graphics license](https://raw.githubusercontent.com/twitter/twemoji/master/LICENSE-GRAPHICS)；[code license](https://raw.githubusercontent.com/twitter/twemoji/master/LICENSE) | 图形 CC BY 4.0；代码 MIT | 不进入 HAP 主资源；署名和品牌风格成本高 | raw LICENSE-GRAPHICS 首行为 `Attribution 4.0 International` |
| Lottie web / dotLottie web | [lottie-web LICENSE](https://raw.githubusercontent.com/airbnb/lottie-web/master/LICENSE.md)；[dotlottie-web API](https://api.github.com/repos/LottieFiles/dotlottie-web/license) | Web runtime MIT；不是 ArkUI 可直接用的端侧能力 | 仅作 Lottie 文件格式和动效生产参考；HAP 仍需 `@ohos/lottie-turbo` 或原生动画验证 | raw/API 许可证确认 MIT |
| Rive runtime | [LICENSE](https://raw.githubusercontent.com/rive-app/rive-runtime/main/LICENSE) | MIT；交互动效能力强 | HarmonyOS ArkUI 无已验证运行链，不进入 HAP | raw LICENSE 首行为 `MIT License` |
| Shiki | [官网](https://shiki.style/)；[LICENSE](https://raw.githubusercontent.com/shikijs/shiki/main/LICENSE) | MIT；高质量语法高亮 | 不直接进入 HAP；可参考主题 token 和语言标签结构 | HTTP 200；raw LICENSE MIT |
| highlight.js | [LICENSE](https://raw.githubusercontent.com/highlightjs/highlight.js/main/LICENSE) | BSD-3-Clause | 不直接进入 HAP；可参考语言分类与代码块 affordance | raw LICENSE BSD-3-Clause |
| PrismJS | [LICENSE](https://raw.githubusercontent.com/PrismJS/prism/master/LICENSE) | MIT | 不直接进入 HAP；仅作语法高亮模式参考 | raw LICENSE MIT |
| markdown-it | [LICENSE](https://raw.githubusercontent.com/markdown-it/markdown-it/master/LICENSE) | MIT | 不直接进入 HAP；可参考 Markdown block 类型 | raw LICENSE MIT 文本已读 |
| Mermaid | [LICENSE](https://raw.githubusercontent.com/mermaid-js/mermaid/develop/LICENSE) | MIT；适合结构图语法 | 不进入 HAP runtime；可把图结构离线转成 ArkUI `Canvas`/`Line` 设计 | raw LICENSE MIT |
| Cytoscape.js | [官网](https://js.cytoscape.org/)；[LICENSE](https://raw.githubusercontent.com/cytoscape/cytoscape.js/master/LICENSE) | MIT 类许可文本；图谱交互成熟 | 不进入 HAP；参考局部图、节点/边编码和交互 | HTTP 200；raw LICENSE 已读 |
| D3 | [LICENSE](https://raw.githubusercontent.com/d3/d3/main/LICENSE) | ISC 类许可文本 | 不进入 HAP；参考 scale、布局和数据编码思想 | raw LICENSE 已读 |
| IBM Carbon Design System | [官网](https://carbondesignsystem.com/)；[LICENSE](https://raw.githubusercontent.com/carbon-design-system/carbon/main/LICENSE) | Apache-2.0 | 仅作状态、数据表、标签和空态模式参考 | HTTP 200；raw LICENSE Apache-2.0 |
| Atlassian Design Tokens | [Tokens](https://atlassian.design/tokens/design-tokens) | 本轮未核到可复用代码许可证 | 只作 token 命名和状态色模式参考 | HTTP 200；许可证未验证 |
| CodeCombat | [官网](https://codecombat.com/) | 编程闯关产品参考 | 可参考关卡、目标、即时反馈，不使用资产 | HTTP 200 |
| LeetCode Study Plan | [Study Plan](https://leetcode.com/studyplan/) | 本机 HTTP 403 | 仅作用户熟知的题单/标签/进度模式参考；不写成可访问资产 | 本机 HTTP 403 |

## 推荐进入下一轮视觉比对的资源

### 1. 补充图标源：Fluent UI System Icons

理由：Heroicons、Bootstrap Icons、Fluent Icons 都可用，但本项目已有 HarmonyOS `SymbolGlyph` 作为主来源。若确实缺少“代码运行、终端、分支、脑图、靶心、奖杯、证据引用”等图标，Fluent 的 regular/filled 双态适合表达“未完成/已完成”状态。

落地方式：

- 从 Fluent UI System Icons 只挑 6-10 个 SVG，先放 `.tmp/frontend-asset-expansion-20260703/icons/` 视觉比对。
- 每个 SVG 记录原始 URL、许可证 URL、文件哈希、用途。
- 通过后复制到 `entry/src/main/resources/rawfile/icons/`，页面用 `Image($rawfile(...))`；颜色统一由 SVG stroke/fill 改成项目 token。

当前状态：许可证文本确认；未下载；未做 ArkUI 渲染；**未验证**。

### 2. 代码字体：JetBrains Mono

理由：`Chat.ets` 和 `Lesson.ets` 已出现代码块，代码阅读是核心体验。JetBrains Mono 的 OFL 1.1 许可证清楚；但 HarmonyOS 自带字体和 `fontFamily('monospace')` 已可工作，新增字体只在真实截图证明可读性显著提升时成立。

落地方式：

- 先用当前系统 monospace 做代码块 V2。
- 若仍需字体，下载 JetBrains Mono 单一 Regular 字重到 `.tmp/` 做 HAP 体积估算和 ArkUI 字体加载验证。
- 不引入连字字体作为默认代码教学字体，避免 `!=`、`=>` 等字符被合成为初学者看不见的符号。

当前状态：许可证文本确认；未下载；未做字体加载；**未验证**。

### 3. 空态插画：IRA Design 或 DrawKit 二选一

理由：`MistakeBook.ets`、`Achievements.ets`、`Knowledge.ets` 的空态可以从“纯文字/图标”提升到更温和的学习反馈。IRA Design 是 MIT；DrawKit 页面明确商业使用许可，但条款较长，适合少量精选。

落地方式：

- 优先 IRA Design，因为 MIT 边界清楚。
- 只挑 2-3 张：无错题、暂无成就、暂无资料。
- 插画必须支持品牌色替换，不使用带外部品牌、人物身份暗示或难以本地化的图。

当前状态：IRA 许可证文本确认；DrawKit HTTP 200 且条款抽取成功；未下载；未做视觉比对；**未验证**。

### 4. 代码块与 Markdown：Shiki / GitHub / Primer 作为模式来源

理由：`Chat.ets` 手写 Markdown 已解决原始标记泄漏，但离“可阅读开发者答案”还有距离。Shiki、highlight.js、PrismJS 都是 Web/JS 高亮方向，不应直接进 HAP；它们的价值是提供语言标签、主题 token、行级结构和高亮边界参考。

落地方式：

- ArkUI 端先实现无依赖代码块 V2：语言条、复制/追问按钮、横向/纵向滚动、行号、输出区。
- 高亮先做 3-5 个确定性 token：keyword、string、comment、number、operator；只覆盖教学示例，不承诺完整语言解析。
- `@luvi/lv-markdown-in` 包源恢复后再与手写方案对比。

当前状态：多个许可证文本确认；未引入依赖；**未验证**。

### 5. 学习星图参考：Cytoscape / D3 / Mermaid

理由：这些库不进入 HAP，但它们能帮助定义图谱语义。当前 `LearningMap.ets` 已有先修边和 Level；下一步应补方向、局部邻域、节点大小和边权，而不是继续加背景光效。

落地方式：

- D3 只参考 scale：颜色=掌握状态，大小=练习量或错题量，线宽=先修强度。
- Cytoscape 只参考交互：选中节点时高亮一跳邻居、淡化远端节点。
- Mermaid 只参考图结构表达：把先修关系从数据结构转为 ArkUI 绘制指令，不嵌 WebView。

当前状态：许可证文本/官网访问确认；未实现；**未验证**。

### 6. 竞品模式补充：CodeCombat / SoloLearn / Replit / LeetCode

本轮把这些作为“学习结构参考”，不作为素材来源：

- CodeCombat：关卡目标、即时反馈、失败可重试，适合 `Lesson.ets` 的固定示例“运行感”。
- SoloLearn：移动端短课、选择/填空/代码练习循环，适合本项目每个 Topic 的 3-5 分钟活动单元。
- Replit：指令、代码、输出、AI 帮助并排，适合鸿学伴的“题意 / 代码 / 输出 / 追问”四段结构。
- LeetCode：题单、标签、难度、通过状态和进度，适合 `Quiz.ets` 与 `Practice.ets` 的标签化复习；本机访问 `studyplan` 返回 403，不写成可访问来源。

## 本轮不推荐进入 HAP 的资源

| 资源 | 不推荐原因 | 替代方案 |
|---|---|---|
| Lordicon 免费图标 | 免费许可非商用且要求署名；PRO 有时限和请求数条款 | ArkUI 原生关键帧；必要时 LottieFiles 逐条复核 |
| Storyset 免费插画 | 免费使用要求署名；无署名需 premium | IRA Design / Open Peeps / DrawKit 少量精选 |
| OpenMoji | CC BY-SA 4.0 的署名与相同方式共享义务不适合 HAP 主资源 | 系统 emoji、系统 Symbol、MIT 图标 |
| Twemoji 图形 | CC BY 4.0 署名成本和品牌风格成本高 | 系统 emoji 或 SymbolGlyph |
| Remix Icon | 自定义 `Remix Icon License v1.0`，本轮未完成条款审查 | Heroicons / Bootstrap Icons / Fluent Icons |
| Rive runtime | MIT 但 HarmonyOS ArkUI 运行链未验证 | 原生 `animateTo` / `keyframeAnimateTo`；Lottie 真机验证后再议 |
| Shiki/highlight.js/PrismJS/markdown-it runtime | Web/JS 生态，不符合独立 HAP 零依赖优先边界 | 手写 ArkUI 渲染子集；包源恢复后验证 `@luvi/lv-markdown-in` |
| D3/Cytoscape/Mermaid runtime | Web 图形库，不进入 ArkUI 原生页面 | 抽取交互和数据编码思想，用 ArkUI `Canvas`/`Line` 实现 |

## 初步落地优先级

1. **P0：继续无资产实现**。先改 Chat 代码块 V2、LearningMap 方向/局部图、Profile 标签掌握等级，均不需要下载资源。
2. **P1：图标补缺试验**。Fluent UI System Icons、Heroicons、Bootstrap Icons 三选一，先 `.tmp/` 视觉比对 6-10 个图标。
3. **P1：代码字体试验**。JetBrains Mono 只试单字重，比较系统 monospace 与自带字体的可读性和 HAP 体积。
4. **P2：空态插画试验**。IRA Design 优先，DrawKit 次选；只做 2-3 张空态，不进入课程主内容。
5. **P2：动效资产暂停**。OHPM 仍 502，Lottie/Rive 不进入 HAP；成就和全对反馈先用 ArkUI 原生动画。

## 后续需要主线程复核的问题

1. 是否允许后续在 `.tmp/` 下载少量 SVG/字体文件做视觉比对。下载前应列出精确 URL 和目标文件名。
2. 图标补缺优先选 Fluent UI System Icons、Heroicons 还是 Bootstrap Icons。当前建议只选一套，避免应用内图标语言混杂。
3. 是否接受 JetBrains Mono 作为代码块字体试验。若接受，需要单独记录 HAP 体积变化和 ArkUI 字体加载方式。
4. Storyset、Lordicon、OpenMoji、Twemoji 不建议进主线；若提交材料需要使用，必须单独准备署名和许可证说明。
