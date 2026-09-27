# 鸿学伴 API 26 导航升级接力（2026-09-27）

## 已完成

- `apps/harmonyos/build-profile.json5` 的最低与目标版本均为 `26.0.0`。根页只有 ArkUI 原生 `Tabs`；底栏使用 API 26 `barFloatingStyle` 与薄型 `ImmersiveMaterial`，没有并存旧导航。
- 四个入口的图标采用同一套 Phosphor 常规／双色 SVG；选中时切换图形、颜色、浅色底并在 180ms 内放大。图标与文字固定居中，首页课程卡圆形按钮中的斜箭头也已居中。资源许可证见 `entry/src/main/resources/rawfile/nav-icons/LICENSE`。
- 四个根页为悬浮底栏留出下缘空间；学伴输入区在底栏上方，键盘弹出时原生底栏自动隐藏。首页缩短主卡和签到区，课程快捷卡改为对称双卡；签到 28 日历史可折叠。
- `DEVECO_CLI_STUDIO_PATH=/Applications/DevEco-Studio.app devecocli build` 最后一次 exit 0；`CompileArkTS`、`PackageHap`、`PackingCheck` 通过。`devecocli run --skip-build --device 127.0.0.1:5555` 安装启动 exit 0。当前未签名 HAP：`apps/harmonyos/entry/build/default/outputs/default/entry-default-unsigned.hap`，SHA-256 `d06511381c902897046e6584dc99686707394343b839275ee3bd06aca42bacd1`。
- Pura X View 竖屏 1320×2232 本机证据：浅色首页 `.runtime/api26-arrow-centered.jpeg`、深色首页 `.runtime/api26-final-dark.jpeg`、学伴输入区 `.runtime/api26-chat-fixed.jpeg`、键盘 `.runtime/api26-keyboard.jpeg`；深色系统选项 UI 树 `.runtime/api26-settings-dark-layout.json`。首页“全部课程”实际跳到课程、再切到学伴已抽样。截图与树在忽略目录，不入 Git。

## 接力优先级

1. 复赛附件制作优先：以最终提交版重新绑定 HAP、生产部署、PDF、MP4、源码 ZIP 与 SHA。旧附件底稿里的 API 12 HAP 哈希是历史证据，不能用于新版素材。
2. 如继续 UI 验收，优先恢复 Pura X View 的 HDC 连接后抽查“我的”、签到 28 日展开/收起与长内容滚动。最后一次点击“我的”时 HDC 报 `Device not found or connected`，没有宣称这次点击通过；已有首页浅暗截图与键盘证据有效。
3. 真实设备、横屏/展开态、大字号、正式签名、门户上传仍未验证。`compatibleSdkVersion=26.0.0` 意味着旧系统不在安装范围内；这是已批准取舍。动画的 180ms 参数在源码中，截图不证明逐帧效果。

## 工作区边界

本批只处理 `AGENTS.md`、`apps/harmonyos/README.md`、`apps/harmonyos/build-profile.json5`、四个根页及首页、`rawfile/nav-icons/`、前端资源/设计记录、附件底稿、DEVLOG 和本接力文档。`scripts/harmonyos-app-smoke.ps1`、`scripts/test_validate_official_deliverables.py`、`docs/astra-review/`、`docs/workflows/`、`scripts/harmonyos-app-smoke.md` 是其他任务的未提交修改，不要包含进本批，也不要覆盖或清理。

相关设计依据与此前验证边界见 [复赛设计记录](SEMIFINAL-DESIGN-REFINEMENT-20260927.md)；附件内容基底见 [复赛附件底稿](SEMIFINAL-ATTACHMENT-START-20260927.md)。
