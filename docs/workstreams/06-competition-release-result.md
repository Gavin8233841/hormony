# WS06 竞赛验收、内容质量与正式交付结果

更新时间：2026-07-17

## 工作边界

- 分支：`codex/ws06-competition-release`
- 官方依据：仓库根目录的竞赛规程 PDF 与报名手册 PDF。
- 产品数据单一来源：`apps/web/src/lib/data/quizzes.ts`；HarmonyOS `quizzes.json` 只由生成器同步。
- 禁止项：不修改 `DEVLOG.md` 既有记录，不提交 `.trae/`、构建产物、HAP、日志、截图、根目录资产、展示站、ZIP 或秘密。

## 批次 1：基于实时 UI 树 bounds 的 HarmonyOS 冒烟门禁

背景：原脚本会复用已抓取的 UI 树、对节点文本做宽松匹配，并在多设备或多个 HAP 并存时隐式选择目标，无法形成可重复的竞赛验收证据。

文件：

- `scripts/harmonyos-app-smoke.ps1`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 每次点击、页面断言和文本断言都重新执行 `uitest dumpLayout`，只匹配当前可见节点的精确文本，并从节点 `bounds` 计算点击中心。
- 对当前工具已见的三种 bounds 编码进行显式解析：`[x1,y1][x2,y2]`、`left/top/right/bottom`、`left/top/width/height`；反向、空尺寸和尾随内容均拒绝。
- 多设备连接时要求传入 `-DeviceTarget` 的精确值，所有 HDC 命令固定到该目标；安装产物固定为当前构建配置的 `entry-default-unsigned.hap`。
- UI 树 JSON、dump 路径、命令退出码、安装与启动结果都设置失败边界；截图只写入新的时间戳目录，已存在时拒绝覆盖。
- 新增 `-SelfTest` 离线入口，验证 bounds、UI 树、dump 路径和目标设备参数，不连接设备、不构建、不创建截图目录。

验证：

- **静态诊断通过**：PowerShell AST 解析，exit 0，`AST_PARSE=PASS`。
- **静态诊断通过**：PowerShell 7.6.3 执行 `./scripts/harmonyos-app-smoke.ps1 -SelfTest`，exit 0，9/9 通过。
- **静态诊断通过**：Windows PowerShell 5.1 执行同一 `-SelfTest`，exit 0，9/9 通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，`BUILD SUCCESSFUL in 8 s 559 ms`；仍有未配置 `signingConfigs` 的既有警告。
- **未验证**：`hdc list targets` 返回 `[Empty]`，因此没有运行安装、启动、页面点击和截图流程，不能标记为模拟器通过或真机通过。

## 批次 2：官方评分证据与正式材料口径

背景：正式材料需要直接映射官方 PDF，消除把项目内部严格要求写成官方要求、复用历史测试数字或夸大 AI 引用覆盖范围的风险。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 逐页列出初赛截止时间、三项必备内容、Demo 可选备注、PDF/MP4/ZIP 规格、上传次数和原创要求，并记录两份 PDF 的页数与 SHA-256。
- 建立创新性 50、完备度 20、前景评估 20、规范性 10、实际应用价值 20 的证据矩阵，不自行拆分官方未公开分值。
- 定稿一句话创新点、479 字项目介绍、两张真实图的取证规则、4 分 45 秒黄金演示镜头表和 20 页内作品说明结构。
- 补齐 PDF、MP4、源码 ZIP、NOTICE、原创声明、AI 使用说明和上传前真实性门禁。
- 明确“2 张图”是项目严格口径，不是 PDF 原文；明确拒绝复用“总题库 60 题”“78/78”“答案 100% 正确”“所有 AI 输出都有引用”等旧表述。
- 修正文档中证据等级数量，将源码确认、静态诊断通过、构建通过、模拟器通过、真机通过、线上通过、未验证准确写为七种。

验证：

- **源码确认**：使用 `pypdf` 读取两份官方 PDF 的关键页，exit 0；规程 11 页、报名手册 12 页。
- **源码确认**：`Get-FileHash -Algorithm SHA256`，exit 0；规程哈希 `E5093C61BED5A10C249E165095127AC1F03FD3CE5B8B993D3A8D6AE878BEC1A9`，报名手册哈希 `6034ACA8F908D76DEBD0EA1DC606C3F594DF8FE29310866F1E5EF91D170BD26E`。
- **静态诊断通过**：集成复核修正视频必交口径和通知能力边界后，文档门禁确认项目介绍为 479 个 Unicode 字符，评分项、截止时间、4 分 45 秒和 20 页上限均存在，exit 0。
- **未验证**：官方作品说明模板最新版、门户实时字段、单文件大小限制、真实队名和剩余更新次数仍须队长登录核对。
- **未验证**：最终 PDF、MP4、ZIP、截图、HAP 哈希和签署材料尚未生成；本文不把准备清单写成已交付。
