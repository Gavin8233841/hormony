# WS08 成熟产品级首屏与课程体验结果

更新时间：2026-07-18
恢复基线提交：`a3f6b59`（已包含批次 A-E）
工作分支：`codex/08-product-experience`

## 一、目标与边界

本工作流把 HarmonyOS 首页、课程列表、课程详情、Lesson 和学伴问答收束为可信的学习路径：应用先读取本机真实学习状态，再给出唯一下一步；进入课程后继续最近学习内容；阅读、互动、提交、反馈、后续练习和学伴追问保持连续。

执行边界：

- 复用 ArkUI、HarmonyOS System Symbol、现有设计令牌、ArkData Repository 和既有路由。
- 未修改课程事实源、`lesson-experiences.json`、题库、知识切片、schema、依赖、SDK 版本或模型配置。
- 未引入图片、Lottie、第三方 UI/动效库或 ArkWeb。
- 按任务要求未编辑 `DEVLOG.md`。

## 二、核验来源

以下资料于 2026-07-17 实际访问。官方文档用于系统能力与无障碍边界；产品文章和 Web/跨端开源实现只用于工作流参考，不作为 ArkUI API 依据。

### HarmonyOS 与可访问性

- HarmonyOS 无障碍开发指导：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-universal-attributes-accessibility>
- HarmonyOS 无障碍属性参考：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-accessibility>
- HarmonyOS ArkUI 动画：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-animation>
- HarmonyOS UX 体验建议：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/experience-suggestions-ux>
- WCAG 2.2 最低对比度：<https://www.w3.org/TR/WCAG22/#contrast-minimum>

**官方确认**：交互焦点顺序应与视觉顺序一致；动态状态需要可感知；`accessibilityText` 应简洁完整；普通组件可使用项目 API 12 已具备的无障碍属性。动效应用于状态、操作反馈和加载，不应用于无意义装饰。

### 成熟学习产品与固定开源实现

- Duolingo 学习路径：<https://blog.duolingo.com/new-duolingo-home-screen-design/>
- Duolingo 核心标签页重构：<https://blog.duolingo.com/core-tabs-redesign/>
- Duolingo 难题透明提示：<https://blog.duolingo.com/duolingo-difficult-exercises/>
- Khan Perseus README（固定提交 `eb7d6fd422213f981c9cf51c0bd06ae2714e5fbf`）：<https://github.com/Khan/perseus/blob/eb7d6fd422213f981c9cf51c0bd06ae2714e5fbf/README.md>
- Khan 渐进提示实现：<https://github.com/Khan/perseus/blob/eb7d6fd422213f981c9cf51c0bd06ae2714e5fbf/packages/perseus/src/hints-renderer.tsx>
- Khan 评分实现：<https://github.com/Khan/perseus/blob/eb7d6fd422213f981c9cf51c0bd06ae2714e5fbf/packages/perseus-score/src/score.ts>
- Moodle 课程卡（固定提交 `2c001177c81deaf1cdb9f36140ee191e35ec67ea`）：<https://github.com/moodlehq/moodleapp/blob/2c001177c81deaf1cdb9f36140ee191e35ec67ea/src/core/features/courses/components/course-list-item/core-courses-course-list-item.html>
- Moodle Lesson 播放器：<https://github.com/moodlehq/moodleapp/blob/2c001177c81deaf1cdb9f36140ee191e35ec67ea/src/addons/mod/lesson/pages/player/player.html>
- Moodle Lesson 离线状态：<https://github.com/moodlehq/moodleapp/blob/2c001177c81deaf1cdb9f36140ee191e35ec67ea/src/addons/mod/lesson/services/lesson-offline.ts>

**源码确认/产品参考**：课程卡应表达进度与未完成状态；首页应维持单一学习路径；题面、选择、提交、评分和提示应分阶段；离线断点不能被看似成功的默认状态替代。这些来源不是 ArkUI 实现，未复制其组件 API 或视觉资产。

## 三、落地批次

### 批次 A：可信首屏与真实直达

- 首页主动行动新增 loading、ready、error 和单调读取序号。真实状态确认前只显示稳定骨架，不再展示可点击的默认“数据结构”行动。
- 读取失败保留本机状态并提供原地重试；今日计划也区分 loading、empty 和 error。
- 课程型主动行动从通用课程 Tab 改为直达精确 `CourseDetail`；旧 `pages/Index + course` 通知/卡片 payload 继续通过校验，避免既有回流失效。
- 下一步卡移除挤压窄屏的 98 vp 装饰圆形，主操作改为稳定全宽按钮；铃铛移除常驻“未读”装饰点。

### 批次 B：课程层级、续学与恢复

- 课程列表使用真实 `LessonProgress.updatedAt` 将已开始且最近学习的课程前置；未开始课程保持目录顺序。
- 课程列表全量失败和续学位置降级均有可执行重试；并发读取使用 latest-wins，旧成功、失败和 finally 不覆盖新结果。
- 课程详情在进度快照确认前显示稳定骨架，不提前发布“开始/继续/预览”；读取失败显示独立恢复页。
- 课程详情增加唯一“继续上次主题/开始下一主题”主操作；品牌蓝只标识当前下一步，完成使用成功色，未来预览使用中性色。
- 学生可见词汇从“知识切片”收敛为“课程 -> 主题 -> 小节 -> 练习”。导航失败保留页面上下文和可见提示。

### 批次 C：Lesson 阅读与互动

- Lesson 进度和互动断点读取增加 latest-wins 与稳定骨架；失败不覆盖课程内容，并提供原地重试。
- 单选从“点击立即判分写入”改为“选择 -> 明确提交 -> 判分写入”，避免误触污染学习证据。
- 底部主操作解析首个未完成互动；完成第 1 项后会进入第 2 项，不再滚回已完成练习。
- 掌握标准由三列截断改为纵向扫描；长选项取消四行省略，现有 53 字符 HTTPS 选项可按内容增长。
- 错误答案统一使用错误语义色；可点击的返回、重试、推演、提交、追问和下一练习控件提升至至少 48 vp。
- 辅助文字、占位文字、未选导航和成功/警告/错误小字调整到可在实际浅色表面通过 WCAG AA 的颜色；源契约计算对比度，不只断言十六进制字符串。

### 批次 D：渐进分步提示

- Lesson 复用现有 `workedExampleSteps`，默认不展开答案步骤；学习者每次只揭示一步，全部展开后可收起。
- 活动切换、断点恢复和输入重置时同步收起提示，避免上一项练习的帮助状态污染下一项。
- 揭示按钮保持 48 vp 和动态无障碍名称；未修改 `lesson-experiences.json`、答案、评分或学习事件结构。

### 批次 E：真实后续动作失败恢复

- Lesson 的“同标签测验”和末节“完成主题并练习”不再在路由失败时静默；页面保留当前上下文并显示可见重试反馈。
- 主题练习失败文案明确本节进度已经保存，避免学习者因重复操作担心进度丢失；原操作保持为重试入口。
- 复用既有 `message` 区、`router` 和幂等课程进度写入，不修改路由目标、课程事实、学习事件或 Repository。

### 批次 F：提交态冻结、主动行动互斥与浅色表面对比度

- 自由回答提交时保存去除首尾空白后的不可变快照；输入框随即冻结，反馈与“向学伴追问”只读取该快照，提交后的输入变化不会改写学习证据。
- 单选和排序选项提交后禁用，并继续向读屏暴露“已选择/未选择、答案已提交”的精确状态，避免结果页误触改变视觉答案。
- 首页本地任务写回、系统提醒发布和服务卡片重试使用互斥入口；提醒行动绑定精确 `nextActionRunId`，发布等待期间或后续任务切换导致版本变化时，服务卡片不能重试同步旧行动，CTA 会切换为按当前行动重新创建提醒。
- 新增浅色表面专用品牌文字色 `COLOR_BRAND_TEXT`；品牌填充色保持不变，标签、百分比、辅助操作和状态文字在实际浅色背景上的对比度由源契约计算并达到 WCAG AA。

### 批次 G：学伴关键操作无障碍与自适应

- 推荐问题、云端重连、问题输入、发送/停止、本机会话重试、回答重试、引用展开、错误详情、回答生成过程和代码解释等关键操作统一保留至少 48 vp 触控区。
- 发送按钮按停止、发送、重连、连接中和不可用状态提供动态无障碍名称；输入、重连、历史恢复和代码解释提供对象化名称与用途说明。
- 引用、错误详情和回答生成过程可聚焦，展开/收起名称包含具体对象及引用数量，避免读屏只播报“展开”。
- 发送状态、生成过程和 Agent 说明移除单行或双行省略；欢迎区、消息列表、连接状态和输入栏限制最大内容宽度 760 vp，窄屏保持全宽，宽屏避免阅读行过长。
- 本批只修改 `Chat.ets` 展示与无障碍属性；未修改 SSE、请求身份、取消、历史持久化、路由、Repository 或 Plan 状态机。

## 四、文件

- `DESIGN.md`
- `apps/harmonyos/entry/src/main/ets/common/Builders.ets`
- `apps/harmonyos/entry/src/main/ets/common/Constants.ets`
- `apps/harmonyos/entry/src/main/ets/common/ProactiveLearningService.ets`
- `apps/harmonyos/entry/src/main/ets/pages/HomeContent.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Course.ets`
- `apps/harmonyos/entry/src/main/ets/pages/CourseDetail.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Chat.ets`
- `scripts/test-product-experience-contracts.mjs`
- `scripts/test-proactive-learning-service.mjs`
- `scripts/test-proactive-delivery-contracts.mjs`
- `scripts/test_course_resume_contract.py`
- `docs/workstreams/08-product-experience-result.md`

## 五、验证

### 源契约

```powershell
node --test scripts/test-product-experience-contracts.mjs scripts/test-proactive-learning-service.mjs scripts/test-proactive-delivery-contracts.mjs
```

- 主线融合批次 G 后复跑 exit 0，62/62 通过。
- 覆盖首页真实状态门禁、提醒/任务写回互斥、课程直达与旧 payload 兼容、课程排序、三页 latest-wins、错误恢复、Lesson 显式提交/下一互动、提交后输入与选项冻结、后续动作路由失败、Chat 动态操作语义与 48 vp、长文本、返回语义和实际颜色对比度。

```powershell
python -m unittest scripts.test_course_resume_contract scripts.test_lesson_activity_resume_contract
```

- exit 0，16/16 通过。
- 覆盖课程/Topic 精确隔离、断点续学、Lesson 互动证据恢复、写入失败重试和学伴/测验交接。

```powershell
node --test scripts/test-ws01-chat-plan-source-contract.mjs
```

- exit 0，13/13 通过。
- 覆盖 Chat 真实 SSE 提交、单调请求身份、取消、结构化失败、本机会话恢复、引用/代码/表格阅读，以及 Plan 串行写入和安全区；证明本批展示层修改未改变既有 Chat/Plan 状态契约。

### API 12 HAP

Hvigor 帮助已确认当前版本支持 `--incremental`。最终命令：

```powershell
cd apps/harmonyos
.\hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --incremental --no-daemon
```

- 主线批次 F 独立审查后的源码 exit 0，`BUILD SUCCESSFUL in 39 s 148 ms`；WS08 分支学伴无障碍批次首次 `BUILD SUCCESSFUL in 19 s 885 ms`，最终复核 `BUILD SUCCESSFUL in 6 s 863 ms`。
- `CompileArkTS`、`PackageHap` 与 `PackingCheck` 通过，多项任务显示 `UP-TO-DATE`。
- 项目没有 `signingConfigs`，Hvigor 跳过签名；该结果只记为**构建通过**。
- 最终 HAP：`apps/harmonyos/entry/build/default/outputs/default/entry-default-unsigned.hap`；SHA-256 为 `F31EF1965DCA92436288FD6DA1AB315600B6F4140B6EBD446ADA46AB0CA24DF3`。
- 早期通用 `assembleHap --no-daemon` 构建虽 exit 0，但日志内部出现 `:entry:clean`；最终证据以上述显式增量构建为准。

### 设备

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets -v
```

- 重启后首次查询输出 `[Empty]`；对交接文档中已确认的精确目标执行 `hdc tconn 127.0.0.1:5555` 后，复核为 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`。设备参数返回 `emulator`。
- `scripts/harmonyos-app-smoke.ps1 -DeviceTarget '127.0.0.1:5555'`：整体 exit 1；API 12 增量构建、HAP 安装、`EntryAbility` 启动、根页、首页“今日”、课程 Tab、可见的“操作系统/数据结构”状态均通过。脚本在未滚动视口直接查找第三门“计算机网络”时停止；这是真实门禁缺口，不记完整流程通过。
- 局部流程为**模拟器通过**：竖屏 HarmonyOS emulator，截图 1256 x 2760；证据位于本地未提交目录 `screenshots/trae-smoke-20260718-160913`。截图确认课程页无重叠，第三张课程卡仅露出顶部，和失败位置一致。
- Alibaba DevEco Code 会话 `ses_08bb0ef19ffeXBJ9AYKEfASkxw`：`arkui-knowledge`、`arkts-grammar-standards` 加载成功；独立审查修正前的六个本批 `.ets` 的 `check_ets_files` 均为 `no diagnostics`。`arkts_knowledge_search` 返回 `Unknown response format from knowledge service`，不记知识库通过。
- Alibaba DevEco Code 会话 `ses_08ba97913ffesXh7hsStWLfVXi`：`start_app` 完成同一 HAP 安装与 `com.c4ai.hormony/EntryAbility` 启动。`verify_ui` 因未配置多模态模型不可用；build agent 不暴露 `get_app_ui_tree`，因此屏幕朗读、最大字体、旋转、平板与动态安全区仍为**未验证**。
- 独立审查修正后的最终 DevEco 复检会话 `ses_08b962424ffeZxO9aSPgtKl4eU` 在工具调用前返回 `403 AllocationQuota.FreeTierOnly`；最终 Home/Lesson 单文件诊断为**未验证**，以随后 API 12 `CompileArkTS` 成功作为最终构建证据。
- WS08 分支另一次限定流程中，HAP 安装和 EntryAbility 启动成功；DevEco Emulator 为竖屏 `1256 x 2760`、密度 3.5、旋转 0，Chat 输入框和发送按钮设备高度均为 48 vp，截图人工复核未见重叠。
- 证据目录：`screenshots/ws08-chat-a11y-20260718T093940Z/`。主要证据为 `04-chat-postinstall-ui.json` 和 `04-chat-postinstall.jpeg`；该目录按仓库规范不提交。
- `uitest dumpLayout` 不导出源码中的 `accessibilityText`；尝试 `-e accessibilityText` 和 `-e focusable` 均返回 `Invalid attribute name, currently supported names are 'uniqueId'.`，因此对象化语义只记为**源码确认/源契约通过**，屏幕朗读与设备焦点行为仍为**未验证**。
- 已按 DisplayManagerService 帮助执行 `-rotationlock,0` 与 `-motion,1`，等待后 DMS 仍显示旋转 0、`1256 x 2760`；横屏未取得有效证据，明确记为**未验证**。最大字体、平板、减少动效和动态安全区同样未取得对应设备证据。
- 本次主线融合时 `hdc list targets -v` 输出 `[Empty] / hdc`；上述历史支线证据不代表当前主线重新安装或设备通过。

## 六、仍未验证与下一缺口

1. 仓库没有 API 12 系统“减少动效”信号的精确使用依据，本批未猜写接口；减少动效仍为**未验证**。
2. `Index` 已响应式订阅安全区，但公共二级页标题仍通过静态 getter 读取顶部安全区；旋转时的即时重排需有效横屏设备证据和统一 Builder 参数设计。
3. Chat 当前在线失败时保留真实重连，但屏幕朗读、硬件键盘焦点顺序和最大字体下的回答卡展开仍需对应设备能力验证。
4. 课程路径仍使用现有 `router`。迁移到 `Navigation` 影响全部子页和回流契约，不属于本批安全范围。
5. Lesson 底部“上一篇 / 继续互动”横向操作组的大字号折行仍需设备证据。
6. 本批未调用线上 API、模型、通知或服务卡片；不声明线上通过、真机通过、屏幕朗读通过或横屏通过。

## 七、审计说明

- 四条只读委派分别完成成熟学习产品/开源实现基准、窄屏/字体/动效契约审计、首页-课程-Lesson 产品流程审计和 Lesson 后续动作状态反例复核；委派代理未修改文件。
- 主线提交前多轮独立审查发现发布等待、卡片部分失败后切任务、任务写回尾部窗口中的旧提醒重试路径，以及两个条件颜色表达式绕过对比度契约、busy 禁用态与读屏文案不一致；均已修正并重新通过 58/58、16/16 与最终 API 12 HAP。
- 独立 diff 审查尝试因本机没有 CodeRabbit CLI 和后续并发连接中断而未形成审查结论；未将其记为通过证据。
- Chat 批次恢复后未重复请求 DevEco Agent；已知 Alibaba `qwen3-coder-plus` 返回 403 `AllocationQuota.FreeTierOnly`，`deveco/glm-5` 返回 401 `Token refresh failed`，按任务要求停止重试并使用本地契约、Hvigor 与 HDC 完成验证。
- 本次融合后的产品契约为 62/62；API 12 与设备结论须以整条 WS08 合并后的主线复跑为准，历史支线记录不提升当前主线证据等级。
