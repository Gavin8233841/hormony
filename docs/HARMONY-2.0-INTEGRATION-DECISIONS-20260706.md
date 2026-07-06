# 鸿蒙2.0 主线整合决策

日期：2026-07-06

## 1. 当前基线

- 主项目路径：`C:\Users\guo82\Desktop\Hormony`
- 当前分支：`main`
- 本轮补验开始基线：`a3ddd5e feat: 补验鸿蒙2.0 Chat 发送状态`
- 当前主线以 `HEAD`、源码、构建配置和可执行验证为准。旧交接文档只作为线索，不覆盖当前源码结论。
- 工作区存在保留改动与本地资产：`.trae/progress.json`、`.tmp/`、`assets/`、展示站、zip、本地提示词和 HTML 提案等不得纳入主线提交。

## 2. 已确认的主线方向

1. 真实可用性优先于视觉资源。
2. 学习闭环优先于动效、图标和素材接入。
3. 采纳旧分支成果时只按单个提交或手工移植复核，不整枝合并。
4. Web API、Agent、模型、安全、HarmonyOS 仓储与页面改动必须补齐对应验证后进入主线。
5. 没有真机证据的能力统一标记为真机未验证。

## 3. 当前可推进项

### 3.1 Chat 发送按钮状态

状态：源码确认、静态诊断通过、构建通过、线上通过、模拟器通过连接可用态与历史回答渲染。

主线工作区 `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` 已有窄范围改动：

- 空输入时提示“输入问题后发送按钮会亮起”。
- 回答中提示“学伴正在回答，完成后可继续追问”。
- 云端连接中显示加载状态。
- 云端未连接时右侧按钮可触发重试，提示“云端未连接，点击右侧按钮重试”。

采纳决策：已进入主线。当前补验确认线上 Chat SSE 正常、端侧 fallback 网关可让 Chat 进入可输入态并显示历史真实回答。模拟器工具注入输入框文本后未触发新的 `POST /api/chat`，因此“端侧新输入问题 -> 发送 -> SSE 返回 -> 保存历史”仍不标记为完整模拟器通过。

### 3.2 1.13 数据与学习洞察

状态：旧分支有构建和 Web 验证记录，主线未逐提交复核。

采纳顺序：

1. 题库全局唯一与 Topic 覆盖测试。
2. 标签洞察持久聚合。
3. 错题/记录页练习入口。
4. 按真实 Topic 更新星图掌握度。

采纳要求：每批只触碰明确文件，先读当前调用方和测试，再运行 Web 检查、关系校验和 HarmonyOS 构建。

### 3.3 1.12 AI 可用性成果

状态：旧分支已推送，未提交脚本和 Plan 布局暂缓。

采纳范围：只复核已提交的 Web AI/API 可靠性和端侧云端地址复用成果。未提交 `scripts/harmonyos-app-smoke.ps1` 与 Plan 半成品不进入主线。

### 3.4 Chat Markdown 与测验复盘

状态：主线已有多轮 Chat Markdown 增强提交，旧分支仍可作为补充线索。

采纳要求：只接收能改善真实阅读体验、且不新增 OHPM 依赖、不引入 ArkWeb 的最小改动。表格、代码、引用、列表和链接显示必须通过 HAP 构建；端侧新问答链路需要单独补模拟器证据。

## 4. 暂缓项

- 未提交 smoke 脚本。
- 未构建页面半成品。
- 图标、Fluent、SVG 和大体积视觉资产接入。
- OHPM/Lottie/音效/字体等未完成 API 12 与真机验证的能力。
- `.trae/progress.json`、`.tmp/`、`assets/`、展示站、zip、本地证据和本地提示词。

## 5. 下一步执行顺序

1. 补验并提交主线 `Chat.ets` 发送按钮状态。
2. 逐提交复核 1.13 的题库、标签、真实 Topic 掌握度相关改动。
3. 复核 1.12 已提交的 Plan/AI Quiz 可用性成果，排除未提交脚本半成品。
4. 再处理文档型资源蓝图和后续验收矩阵。

## 6. 本轮证据等级

- 源码确认：根规范、交接文档、模型发布策略、资源收口文档、Trae 边界文档、DEVLOG 尾部记录已读取。
- 源码确认：`Chat.ets` 当前未提交 diff 已读取，范围仅为发送按钮状态与提示。
- 构建通过：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` exit 0，`BUILD SUCCESSFUL in 15 s 646 ms`。
- 模拟器通过：`Pura 90 Pro Max` 竖屏，窗口 `bundleName:com.c4ai.hormony`。UI 树证据显示 Chat 页不可用态包含“云端未连接，点击右侧按钮重试”；点击右侧圆形按钮后进入“正在连接云端学伴”并显示 `LoadingProgress`。
- 静态诊断通过：DevEco MCP `check_ets_files` 对 `Chat.ets` 返回 `no diagnostics`。
- 线上通过：`GET https://hormony-ruddy.vercel.app/api/health` 返回 HTTP 200、`status=ready`、模型名 `doubao-seed-2-1-pro-260628`；`POST /api/chat` 返回 HTTP 200，SSE 包含 `delta=1`、`done=1`、`citation=3`、`trace=3`、`thinking=4`，正文长度 1246 且包含 Java 代码内容。
- 模拟器通过：启动 `scripts/simulator-api-gateway.mjs` 后，端侧经 `http://10.0.2.2:3001` fallback 获取 Health 200，Chat 页进入 `输入你的问题...` 可输入态，并显示“输入问题后发送按钮会亮起”。UI 树显示历史真实回答包含“数组”“链表”“随机访问”“参考资料 (3)”。
- 未验证：模拟器工具 `uitest inputText` 与 `hdc shell uitest uiInput text` 能让输入框显示文本，但点击真实发送按钮后网关日志未出现新的 `POST /api/chat`，未证明新输入问题触发端侧发送。
- 真机未验证：Chat、Plan、Quiz、Lottie、OCR、TTS、distributedKVStore。
