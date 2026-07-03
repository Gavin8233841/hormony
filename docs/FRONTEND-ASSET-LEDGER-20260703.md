# 鸿学伴端侧前端资产与依赖受控账本（2026-07-03）

本账本记录本轮深猎中提到的第三方资产、依赖和参考资源。当前状态：未下载资产，未安装 OHPM 依赖，未复制任何文件到 HAP 资源目录。

进入 HAP 前必须补齐：具体素材 URL、许可证 URL、作者/来源、下载日期、SHA-256、文件大小、用途、替代方案、HAP 内路径、API 12 构建证据、模拟器或真机证据。

## 1. OHPM / 依赖账本

| 名称 | URL | 许可证 | 用途 | 版本 | 体积 | 已下载/安装 | 可进入 HAP | 验证状态 |
|---|---|---|---|---|---|---|---|---|
| `@luvi/lv-markdown-in` | https://ohpm.openharmony.cn/ohpm/%40luvi%2Flv-markdown-in | MIT | Markdown 渲染 proof | `3.4.5` | 未安装，未测 | 否 | 否，需单包 proof | 未验证 |
| `@luvi/html2md` | https://ohpm.openharmony.cn/ohpm/%40luvi%2Fhtml2md | MIT | `lv-markdown-in` 依赖链 | `1.0.3` | 未安装，未测 | 否 | 否 | 未验证 |
| `@cangjie-tpc/formula_hybrid` | https://ohpm.openharmony.cn/ohpm/%40cangjie-tpc%2Fformula_hybrid | MIT | 公式渲染依赖链 | `1.3.0` | 未安装，未测 | 否 | 否 | 未验证 |
| `@cangjie-tpc/prism_hybrid` | https://ohpm.openharmony.cn/ohpm/%40cangjie-tpc%2Fprism_hybrid | Apache-2.0 | 代码高亮依赖链 | `1.2.6` | 未安装，未测 | 否 | 否 | 未验证 |
| `@ohos/lottie-turbo` | https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie-turbo | Apache-2.0 | Lottie 动效 proof | `1.0.12` | 未安装，未测 | 否 | 否，需真机 | 未验证 |
| `@ohos/lottie` | https://ohpm.openharmony.cn/ohpm/%40ohos%2Flottie | MIT | Lottie 动效 proof | `2.0.31` | 未安装，未测 | 否 | 否，需 API 12 构建 | 未验证 |
| `@ohos/mpchart` | https://ohpm.openharmony.cn/ohpm/%40ohos%2Fmpchart | Apache License 2.0 | 标签趋势图 proof | `3.0.28` | 未安装，未测 | 否 | 否，需单包 proof | 未验证 |

## 2. 图标账本

| 名称 | URL | 许可证 | 用途 | 体积 | 已下载 | 可进入 HAP | 验证状态 |
|---|---|---|---|---|---|---|---|
| HarmonyOS `SymbolGlyph` | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph | 平台能力 | 默认功能图标 | 无新增体积 | 不适用 | 是，优先 | 源码确认 |
| Tabler Icons 单 SVG | https://github.com/tabler/tabler-icons | MIT | 系统 Symbol 缺口 | 未下载 | 否 | 单图建账后可评估 | 未验证 |
| Phosphor Icons 单 SVG | https://github.com/phosphor-icons/core | MIT | 系统 Symbol 缺口 | 未下载 | 否 | 单图建账后可评估 | 未验证 |
| Lucide 单 SVG | https://lucide.dev/license | ISC；Feather 派生图标另保留 MIT 来源 | 系统 Symbol 缺口 | 未下载 | 否 | 单图建账后可评估 | 未验证 |
| Iconoir 单 SVG | https://github.com/iconoir-icons/iconoir | MIT | 系统 Symbol 缺口 | 未下载 | 否 | 单图建账后可评估 | 未验证 |

规则：同一功能组不混用多套第三方图标；整包图标库不进入 HAP。

## 3. 插画 / 动效账本

| 名称 | URL | 许可证 | 用途 | 体积 | 已下载 | 可进入 HAP | 验证状态 |
|---|---|---|---|---|---|---|---|
| Open Peeps 单图 | https://www.openpeeps.com/ | CC0 | 空态插画 | 未下载 | 否 | 单图建账、视觉复核后可评估 | 未验证 |
| unDraw 单图 | https://undraw.co/license | 自定义许可 | 空态构图参考 | 未下载 | 否 | 谨慎；仅单图核验后评估 | 未验证 |
| ManyPixels 单图 | https://www.manypixels.co/gallery | 需人工复核；`/license` 路径本机返回 404 | 空态构图参考 | 未下载 | 否 | 谨慎；不能成为 App 核心价值 | 未验证 |
| LottieFiles 单动画 | https://lottiefiles.com/page/license | 需人工复核；许可证页本机返回 403 | 成就/全对动效 | 未下载 | 否 | 需单动画建账、Lottie 包真机通过 | 未验证 |
| Rive `.riv` | https://rive.app/runtimes | runtime MIT；社区资产另行授权 | 状态机动效参考 | 未下载 | 否 | 当前不进入 HAP | 未验证 |

规则：含外链图片、音频、表达式复杂且未验证的 Lottie JSON 不进入 HAP。

## 4. 音效 / 字体账本

| 名称 | URL | 许可证 | 用途 | 体积 | 已下载 | 可进入 HAP | 验证状态 |
|---|---|---|---|---|---|---|---|
| Mixkit 单音效 | https://mixkit.co/license/ | Mixkit Free License | 完成/成就轻提示 | 未下载 | 否 | 单条建账、可关闭、真机播放后评估 | 未验证 |
| Freesound `CC0` / `CC BY` 单音效 | https://freesound.org/help/faq/#licenses | 单条声音决定 | 完成/成就轻提示 | 未下载 | 否 | 只接受 CC0 或可满足署名的 CC BY | 未验证 |
| Pixabay 单音效 | https://pixabay.com/service/license-summary/ | 需人工复核；license summary 本机返回 403 | 低频提示音参考 | 未下载 | 否 | 谨慎；需权利和 Content ID 风险记录 | 未验证 |
| Noto CJK 子集字体 | https://notofonts.github.io/noto-docs/website/use/ | SIL OFL | 中文字体兜底 | 未下载 | 否 | 当前不进入 HAP，系统字体优先 | 未验证 |

规则：`CC BY-NC`、`CC BY-NC-SA`、`ND`、个人使用限定音效拒绝。

## 5. 代码展示参考

| 名称 | URL | 许可证 | 用途 | 已下载/安装 | 可进入 HAP | 验证状态 |
|---|---|---|---|---|---|---|
| PrismJS | https://github.com/PrismJS/prism | MIT | token 和配色参考 | 否 | 否 | 未验证 |
| Shiki | https://github.com/shikijs/shiki | MIT | 主题配色参考 | 否 | 否 | 未验证 |
| highlight.js | https://github.com/highlightjs/highlight.js | BSD-3-Clause | 语言分类参考 | 否 | 否 | 未验证 |

规则：Web/Node 运行库不进入 HAP。当前代码块继续 ArkUI 自绘。

## 6. 拒绝清单

| 类型 | 拒绝原因 |
|---|---|
| SpinKit CSS、canvas-confetti、Zustand、Comlink、BlurHash、web-vitals | Web/CSS/React 生态，不能直接在 ArkTS/HAP 中使用 |
| ArkWeb 承载庆祝动画或 Markdown 主体验 | 违反原生页面边界，增加 WebView 层级和安全复杂度 |
| `FluidMarkdown`、`Harmony-Markdown-Editor` 直接引入 | README/API 徽章标注 HarmonyOS API 15，高于当前 API 12 |
| 整包图标、插画、音效、字体 | 体积、风格和再分发风险不可控 |
| `CC BY-NC`、`CC BY-NC-SA`、`ND`、个人使用限定素材 | 不满足商业分发或修改边界 |
| 无单项许可证页的社区 Lottie/Rive | 无法证明可再分发进入 HAP |
| 真人肖像、品牌 Logo、第三方角色/IP | 平台下载许可不等于肖像权、商标权和 IP 权利已解决 |

## 7. 建账模板

新增任何素材前补齐以下字段：

| 字段 | 要求 |
|---|---|
| 素材名称 | 精确文件名 |
| 原始 URL | 具体素材页面，不是平台首页 |
| 许可证 URL | 具体许可证页面 |
| 作者/来源 | 页面公开记录 |
| 下载日期 | `YYYY-MM-DD` |
| SHA-256 | 下载后计算 |
| 文件大小 | 字节或 KB |
| 用途 | 具体页面和触发场景 |
| 替代方案 | 为什么系统 Symbol/ArkUI 原生能力不足 |
| HAP 路径 | 计划放入的精确 rawfile 路径 |
| 验证 | 构建、模拟器、真机或未验证 |
