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
