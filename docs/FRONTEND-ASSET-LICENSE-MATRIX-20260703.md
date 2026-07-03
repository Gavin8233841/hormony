# 前端资源许可证与风险矩阵（2026-07-03）

本矩阵只记录本轮已经打开或通过只读命令核验的来源。没有具体文件、具体 URL、许可证页和运行证据的资源，不进入 HAP。

## 1. 采用门槛

| 门槛 | 必须满足的证据 |
|---|---|
| 许可证 | 具体资源页或仓库 `LICENSE` 可访问；写明商用、修改、分发、署名、再分发限制 |
| API 12 | OHPM 包必须 `ohpm info` 可取到元数据，单独安装后 `apps/harmonyos` 增量构建通过 |
| 运行 | UI 资源至少模拟器通过；触感、音效、Lottie 帧率和生命周期必须真机通过 |
| 离线 | 所有产品内资产必须随 HAP 或 rawfile 离线可用；禁止运行期拉远程素材 |
| 隐私 | 素材渲染不能上传学习画像、题目、聊天内容、设备标识 |
| 仓库边界 | 不提交整包资产、压缩包、`.tmp`、screenshots、本地 HAP、来源不明素材 |

## 2. 开源与平台资源

| 资源 | 许可证 | 证据链接 | 本轮状态 | 可用范围 | 保留要求 | 风险 |
|---|---|---|---|---|---|---|
| HarmonyOS ArkUI 组件 | 平台能力 | [Huawei Design](https://developer.huawei.com/consumer/cn/design/)、OpenHarmony docs raw 链接见资源图谱 | 官方确认 | 端侧 UI 第一选择 | 不复制其他平台资产 | 需按 API 12 文档写法实现 |
| HarmonyOS 系统 Symbol | 平台预置资源 | [SymbolGlyph docs](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-symbolGlyph.md) | 官方确认 | 功能图标默认来源 | 只用 `$r('sys.symbol.xxx')` | 具体 symbol 名必须从源码/SDK核验 |
| `@luvi/lv-markdown-in` | MIT | [LICENSE](https://gitee.com/luvi/lv-markdown-in/raw/master/LICENSE) | 源码确认；OHPM 未验证 | Markdown 渲染增强方向 | 保留 MIT 版权文本 | 图片、HTML、远程链接和 SSE 增量需专项限制 |
| `@ohos/lottie` | MIT | [LICENSE](https://gitee.com/openharmony-tpc/lottieArkTS/raw/master/LICENSE) | 源码确认；OHPM 未验证 | 本地 Lottie JSON 渲染方向 | 保留 MIT 版权文本 | 解析器包体、帧率、销毁释放需真机证据 |
| `@ohos/lottie-turbo` 方向 | Apache-2.0 | [LottieC LICENSE](https://gitee.com/ywp7913/lottie-c/raw/master/LICENSE) | 源码确认；README 为空；OHPM 未验证 | 暂不进主线 | 保留 Apache-2.0 notice | native 依赖、ABI、崩溃边界不明 |
| `@ohos/mpchart` | Apache-2.0 | [ohos_mpchart LICENSE](https://gitee.com/openharmony-tpc/ohos_mpchart/raw/master/LICENSE) | 源码确认；OHPM 未验证 | 后续复杂图表 | 保留 Apache-2.0 notice | 当前功能可用原生实现，依赖收益不足 |

## 3. 图标库

| 资源 | 许可证 | 证据链接 | 采用限制 | 风险等级 |
|---|---|---|---|---|
| Tabler Icons | MIT | [LICENSE](https://raw.githubusercontent.com/tabler/tabler-icons/main/LICENSE) | 仅在系统 Symbol 缺失时单图引入 | 中 |
| Phosphor Icons | MIT | [LICENSE](https://raw.githubusercontent.com/phosphor-icons/core/main/LICENSE) | 不与 Tabler 并行建立第二套主图标语言 | 中 |
| Lucide Icons | ISC | [LICENSE](https://raw.githubusercontent.com/lucide-icons/lucide/main/LICENSE) | 仅作备用来源 | 中 |
| Iconoir | MIT | [LICENSE](https://raw.githubusercontent.com/iconoir-icons/iconoir/main/LICENSE) | 需逐图审美复核 | 中 |
| Heroicons | MIT | [LICENSE](https://raw.githubusercontent.com/tailwindlabs/heroicons/master/LICENSE) | Web/Tailwind 生态，不作为端侧主体系 | 中 |
| Remix Icon | Remix Icon License v1.0 | [License](https://raw.githubusercontent.com/Remix-Design/RemixIcon/master/License) | 自定义许可证，当前不采用 | 高 |

## 4. 插画与空态素材

| 资源 | 许可证结论 | 证据链接 | 可用场景 | 风险等级 | 操作规则 |
|---|---|---|---|---|---|
| Open Peeps | 官网声明 CC0 | [官网](https://www.openpeeps.com/)、[CC0](https://creativecommons.org/publicdomain/zero/1.0/) | 空错题、空成就、空资料 | 低 | 只取 1-3 张，记录具体文件和哈希 |
| unDraw | 自定义免费许可，允许商业使用，但禁止资产包再分发、复刻服务、AI/ML 训练等 | [License](https://undraw.co/license) | 空态/错误态 | 中 | 不使用品牌 logo 图，不批量收录 |
| ManyPixels Free Illustrations | Gallery 页面说明可免费用于个人与商业项目 | [Gallery](https://www.manypixels.co/gallery) | 空态 | 中 | 需要具体素材页和条款复核 |
| LottieFiles | 本轮许可证页 403 | [License](https://lottiefiles.com/page/license) | 暂无 | 高 | 不下载、不采用 |

## 5. 音效与触感

| 资源 | 许可证结论 | 证据链接 | 可用场景 | 风险等级 | 操作规则 |
|---|---|---|---|---|---|
| `@ohos.vibrator` | 平台能力；需权限 `ohos.permission.VIBRATE` | [vibrator docs](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/reference/apis-sensor-service-kit/js-apis-vibrator.md) | 答对、错误、全对、解锁短触感 | 中 | 真机验证前不得标记通过 |
| Kenney Interface Sounds | 页面标注 Creative Commons CC0 | [Kenney](https://kenney.nl/assets/interface-sounds) | 极短 UI 音效 | 低 | 先只取 1-3 个短音，验证静音模式、音量和包体 |
| Freesound | 按具体声音的 Creative Commons 许可证处理 | [FAQ](https://freesound.org/help/faq/#licenses-0) | 暂不作为主来源 | 高 | 逐文件记录作者、许可证、署名要求 |
| Mixkit Sound Effects | 不同 item type 使用不同许可证，Sound Effects 有 commercial licence | [License](https://mixkit.co/license/) | 暂不作为主来源 | 中 | 逐 item 复核 |
| Pixabay | 本轮许可证页 403 | [License summary](https://pixabay.com/service/license-summary/) | 不采用 | 高 | 无许可证证据不进仓库 |

## 6. 不采用清单

| 来源 | 原因 |
|---|---|
| Apple SF Symbols | Apple 平台符号库，只可研究动效和语义，不作为 HarmonyOS 资产来源 |
| Material 图标/组件资源 | 可研究反馈模式，不复制资产或视觉语言 |
| Web CSS 动画、React 组件、浏览器 Canvas 库 | 与独立 HAP 不兼容，已在既有收口文档中拒绝 |
| 任意远程素材 CDN | 离线性、隐私和稳定性不满足端侧交付 |
| 整包插画、整包图标、整包音效 | 仓库边界和许可证复核成本不可控 |

## 7. 进入 HAP 前的记录模板

```text
资源名称：
原始 URL：
许可证 URL：
许可证名称：
下载日期：
文件路径：
文件哈希：
目标页面：
为什么 ArkUI / SymbolGlyph 原生能力不足：
API 12 构建命令与退出码：
模拟器证据：
真机证据：
隐私与离线说明：
```
