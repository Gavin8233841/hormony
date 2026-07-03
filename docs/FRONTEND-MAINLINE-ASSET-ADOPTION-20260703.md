# 端侧前端资产主线接入说明（2026-07-03）

本文件给主线程使用，记录本轮已下载到 `.tmp/` 做初步验证的具体资产、验证结论和接入步骤。本轮没有修改端侧源码、依赖或资源目录；`.tmp/asset-mainline-validation-20260703/` 只作本地证据，不提交。

## 结论摘要

| 资产组 | 主线结论 | 原因 | 仍需主线程完成 |
|---|---|---|---|
| Fluent UI System Icons 精选 6 个 SVG | 确认可接入 | MIT 许可证；文件小；SVG 结构简单；无脚本、无外链、无位图；ArkUI `Image` 支持 SVG 相关属性 | 复制到 `rawfile/icons/` 后执行 HAP 构建、模拟器 UI 树和截图验收 |
| JetBrains Mono Regular TTF | 可做单独接入验证 | OFL 1.1；TTF 文件有效；SDK 声明 `UIContext.getFont().registerFont(...)` 可注册字体 | 复制单字重后验证 HAP 体积、代码块渲染、中文混排和模拟器截图；通过后再留主线 |
| IRA Design SVG 部件 | 暂不接入 | MIT 许可证成立，但下载到的是插画零件，不是完整空态图；语义不完整 | 不进入当前主线；需要完整空态图时重新挑选具体完整 SVG |

## 已验证的 Fluent 图标

来源仓库：[microsoft/fluentui-system-icons](https://github.com/microsoft/fluentui-system-icons)  
许可证文件：[LICENSE](https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/LICENSE)  
许可证验证：本机下载 `fluentui-system-icons-LICENSE`，首行为 `MIT License`，版权行为 `Copyright (c) 2020 Microsoft Corporation`。

本轮下载路径：`.tmp/asset-mainline-validation-20260703/icons/`

| 文件名 | 原始 URL | 字节 | SHA-256 | 用途 |
|---|---|---:|---|---|
| `fluent_code_24_regular.svg` | `https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Code/SVG/ic_fluent_code_24_regular.svg` | 1193 | `03090C9E30C66BD926AD19FB1E5CCD07BDD9C2815881CA5A83A8788F6FCE2F63` | 代码练习、代码块解释 |
| `fluent_branch_24_regular.svg` | `https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Branch/SVG/ic_fluent_branch_24_regular.svg` | 1077 | `A8955F892119E1D84812197B26384F417CB639DD150B4382743E81160B619AE9` | 学习路径、分支选择、先修关系 |
| `fluent_trophy_24_regular.svg` | `https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Trophy/SVG/ic_fluent_trophy_24_regular.svg` | 1474 | `3F0C241009916E1E8E2EA3B0DAA5AAAED0BBC37B47F4504BE31981DCFB21072C` | 成就、全对反馈 |
| `fluent_target_arrow_24_regular.svg` | `https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Target%20Arrow/SVG/ic_fluent_target_arrow_24_regular.svg` | 2070 | `0C9351AAD1745DA1F6500621EE0D1E20A812607D47F56796640D5F4FB1C11930` | 目标、掌握标准、计划任务 |
| `fluent_book_24_regular.svg` | `https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Book/SVG/ic_fluent_book_24_regular.svg` | 616 | `3FF995137B68BA3BD5811C30CBF5395FBBA457C57F57CC9864BF400ADC4624AC` | 课程内容、资料 |
| `fluent_brain_circuit_24_regular.svg` | `https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Brain%20Circuit/SVG/ic_fluent_brain_circuit_24_regular.svg` | 2696 | `1C3F81DBA526461F73EEE67BE8EB7D1C422766B26876CB67433ED92F39A5BF21` | 学伴、知识结构、智能提示 |

合计体积：9126 字节。

### SVG 安全与格式检查

每个文件均通过以下检查：

- XML 根节点为 `svg`。
- `width="24"`、`height="24"`、`viewBox="0 0 24 24"`。
- 无 `<script>`。
- 无 `<foreignObject>`。
- 无外部 `http/https href`。
- 无 `<image>` 位图引用。
- 只有 1 个 `<path>`。
- `fill` 值只出现 `#212121` 与 `none`。

ArkUI 适配依据来自本机 SDK：

- `ImageInterface` 接收 `PixelMap | ResourceStr | DrawableDescriptor`，可使用 rawfile 资源。
- `ImageAttribute.fillColor(value: ResourceColor)` 的 SDK 注释写明该属性只适用于 SVG images。

### 主线程接入步骤

1. 新建目录：

   ```text
   apps/harmonyos/entry/src/main/resources/rawfile/icons/
   ```

2. 仅复制上表 6 个 SVG 文件，不复制整个 Fluent 仓库。

3. 同步加入许可证文本：

   ```text
   apps/harmonyos/entry/src/main/resources/rawfile/licenses/fluentui-system-icons-LICENSE
   ```

4. 页面使用方式：

   ```ts
   Image($rawfile('icons/fluent_code_24_regular.svg'))
     .width(20)
     .height(20)
     .fillColor(Constants.COLOR_BRAND)
   ```

5. 推荐接入位置：

| 页面/组件 | 替换或新增位置 | 图标 |
|---|---|---|
| `Lesson.ets` 代码活动标题 | `CodeBlock` 标题栏或主动练习标题 | `fluent_code_24_regular.svg` |
| `LearningMap.ets` 主题详情 | 前置/后继或路径说明 | `fluent_branch_24_regular.svg` |
| `Achievements.ets` 成就概览 | 成就标题或下一目标 | `fluent_trophy_24_regular.svg` |
| `Lesson.ets` 掌握标准 | 目标卡片 | `fluent_target_arrow_24_regular.svg` |
| `CourseDetail.ets` / `Knowledge.ets` | 内容/资料入口 | `fluent_book_24_regular.svg` |
| `Chat.ets` 学伴头像或解释过程 | 学伴/知识结构入口 | `fluent_brain_circuit_24_regular.svg` |

6. 最低验收：

   ```powershell
   cd apps/harmonyos
   .\hvigorw.bat assembleHap --no-daemon
   ```

   然后在模拟器执行涉及页面的 UI 树和截图验收，确认：

   - SVG 显示非空。
   - `fillColor(Constants.COLOR_BRAND)` 生效。
   - 暗色/浅色背景下不糊、不被裁剪。
   - 图标没有替代系统 Symbol 的全局默认地位，只用于语义补缺。

## JetBrains Mono 单字重接入验证

来源：[JetBrains Mono](https://www.jetbrains.com/lp/mono/)  
字体文件：`https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-Regular.ttf`  
许可证：[OFL.txt](https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/OFL.txt)

本轮下载路径：`.tmp/asset-mainline-validation-20260703/fonts/JetBrainsMono-Regular.ttf`

| 文件名 | 字节 | SHA-256 | 文件签名 |
|---|---:|---|---|
| `JetBrainsMono-Regular.ttf` | 270224 | `E6FD0D7E91550B3ED2B735D4312474362C4716EDC4FC0577A0F61ED782D5AED1` | TTF `00 01 00 00` |

许可证验证：本机下载 `JetBrainsMono-OFL.txt`，文本包含 `This Font Software is licensed under the SIL Open Font License, Version 1.1.`。

SDK 接入依据：

- `@ohos.font.d.ts` 中 `FontOptions` 精确字段为 `familyName: string | Resource` 与 `familySrc: string | Resource`。
- `@ohos.arkui.UIContext.d.ts` 声明 `getFont(): Font` 与 `Font.registerFont(options: font.FontOptions): void`。
- `text.d.ts` 声明 `Text.fontFamily(value: string | Resource): TextAttribute`。

### 主线程接入步骤

1. 单独分支验证，不与 SVG 图标同批提交。

2. 新建目录并复制单字重：

   ```text
   apps/harmonyos/entry/src/main/resources/rawfile/fonts/JetBrainsMono-Regular.ttf
   apps/harmonyos/entry/src/main/resources/rawfile/licenses/JetBrainsMono-OFL.txt
   ```

3. 在合适的初始化位置注册字体。示例写法需由主线程在实际文件中按当前页面生命周期落位：

   ```ts
   this.getUIContext().getFont().registerFont({
     familyName: 'JetBrainsMono',
     familySrc: $rawfile('fonts/JetBrainsMono-Regular.ttf')
   });
   ```

4. 代码块使用：

   ```ts
   Text(codeText)
     .fontFamily('JetBrainsMono')
   ```

5. 最低验收：

   - HAP 增量构建通过。
   - Chat 代码块和 Lesson 代码块截图对比系统 `monospace`。
   - 验证中文说明与英文字体混排不出现异常间距。
   - 记录 HAP 体积变化；单字重原始文件为 270224 字节。

6. 不采用 Fira Code 作为默认代码教学字体。原因：连字会把 `!=`、`=>` 等符号合成为视觉符号，不利于初学者认识真实字符。

## IRA Design 本轮暂不接入

来源仓库：[ira-design/ira-illustrations](https://github.com/ira-design/ira-illustrations)  
许可证：[LICENSE.md](https://raw.githubusercontent.com/ira-design/ira-illustrations/master/LICENSE.md)，本机读取首行为 `MIT License`。

本轮下载了两个 SVG 部件用于检查：

| 文件名 | 字节 | SHA-256 | 检查结果 |
|---|---:|---|---|
| `ira-object.svg` | 587 | `2D90AAD0520A8500E406630285305403AEB3C16FF91D0BC5D043B705DD3B0BD2` | SVG 有效，无脚本、无外链，但只是插画对象部件 |
| `ira-hair.svg` | 554 | `14255DFB06CED73AD4D96AB495B04A24F2B587F59AD8C02374C8BC5BF516B809` | SVG 有效，无脚本、无外链，但只是人物头发部件 |

结论：不进入当前主线。许可证允许不等于产品可用；这两个文件无法直接表达“无错题”“暂无成就”“暂无资料”等空态语义。主线程若需要空态插画，应重新挑选完整 SVG，并重复许可证、文件结构、体积、语义和截图验收。

## 本轮未通过或未纳入主线的项目

| 项目 | 结论 |
|---|---|
| `Terminal` Fluent 图标 | 仓库路径 `assets/Terminal/SVG` 返回 404，本轮不接入 |
| `@luvi/lv-markdown-in`、`@ohos/lottie-turbo`、`@ohos/lottie`、`@ohos/mpchart` | `ohpm info` 继续返回 502，仍未验证 |
| Lottie / Rive | 未做 HarmonyOS 渲染验证，不进入主线 |
| Storyset / Lordicon / OpenMoji / Twemoji | 署名、非商用或共享义务不适合当前 HAP 主线 |

## 主线程推荐批次

1. 第一批只接 6 个 Fluent SVG 图标和许可证文本，改动小、体积低、风险最低。
2. 第二批单独验证 JetBrains Mono Regular，重点看代码块可读性和 HAP 体积。
3. 空态插画暂缓，等主线程确定具体空态页面和完整 SVG 后再做。
