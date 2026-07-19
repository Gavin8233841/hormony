# WS08 成熟产品级首屏与课程体验结果

更新时间：2026-07-19
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

### 批次 F：学伴关键操作无障碍与自适应

- 推荐问题、云端重连、问题输入、发送/停止、本机会话重试、回答重试、引用展开、错误详情、回答生成过程和代码解释等关键操作统一保留至少 48 vp 触控区。
- 发送按钮按停止、发送、重连、连接中和不可用状态提供动态无障碍名称；输入、重连、历史恢复和代码解释提供对象化名称与用途说明。
- 引用、错误详情和回答生成过程可聚焦，展开/收起名称包含具体对象及引用数量，避免读屏只播报“展开”。
- 发送状态、生成过程和 Agent 说明移除单行或双行省略；欢迎区、消息列表、连接状态和输入栏限制最大内容宽度 760 vp，窄屏保持全宽，宽屏避免阅读行过长。
- 本批只修改 `Chat.ets` 展示与无障碍属性；未修改 SSE、请求身份、取消、历史持久化、路由、Repository 或 Plan 状态机。

### 批次 G：计划制定与任务执行层级

- 建议目标、目标输入、周期选择、生成/取消、失败重试、错误详情和规划依据统一保留至少 48 vp；周期、生成、重试、展开/收起均提供状态化对象名称。
- 规划依据和错误详情可聚焦；五个生成检查点将完成、进行中和未开始状态与说明组合为读屏文本，不再只依赖符号与颜色。
- 任务标题、课程/Topic 和规划理由移除固定行数省略，日期、时长和任务类型改为可换行元数据；任务信息组合为单个对象化名称，原“学习/练习/测验/复盘”和“完成/恢复”按钮保持独立焦点与既有写入守卫。
- 已有计划默认把大表单收束为“当前计划 + 调整目标与周期”，让真实任务成为首屏主体；调整入口展开完整编辑器，已有任务在新计划保存前保持不变，收起后回到任务列表。
- 已生成计划写入 ArkData 失败时，目标、周期、生成和调整入口会锁定，唯一恢复动作明确为“保存刚生成的计划”，避免屏幕输入与实际待保存产物错配；需要修改输入的安全/4xx 错误则进入“调整目标”，不盲目重复旧请求。
- 生成和本机恢复期间不再同时占用编辑卡；加载内容使用独立可滚动区域，使长目标和字体放大时取消、检查点及等待说明仍可到达。
- 表单、消息、加载、依据、任务列表和空态限制最大内容宽度 760 vp；窄屏仍使用可用全宽，宽屏避免长行和卡片无限拉伸。
- 本批只修改 `Plan.ets` 展示状态与 Builder；未修改计划读取代次、请求参数、HTTP、校验、取消、ArkData 保存、任务串行写入、服务卡片更新、Repository 或 `pageTransition()`。

### 批次 H：计划任务操作的大字号增长空间

- 计划任务的“学习/练习/测验”和“完成/恢复/保存中”不再固定为 `64 x 48 vp`，改为最小 `64 x 48 vp` 并保留内容内边距；普通字号下仍维持 48 vp 触控高度，字体或文案增长时允许按钮随内容增长。
- WS08 与 WS01 Chat/Plan 源契约同步禁止这两类任务操作回退到固定 `width(64)` / `height(48)`，同时继续约束任务写入串行锁、对象化无障碍名称和真实路由。
- 本批只修改 `Plan.ets` 的两类任务按钮及对应源契约；未修改任务状态机、ArkData、Repository、计划内容、路由、HTTP 或 Agent 调用。

## 四、文件

- `apps/harmonyos/entry/src/main/ets/common/Builders.ets`
- `apps/harmonyos/entry/src/main/ets/common/Constants.ets`
- `apps/harmonyos/entry/src/main/ets/common/ProactiveLearningService.ets`
- `apps/harmonyos/entry/src/main/ets/pages/HomeContent.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Course.ets`
- `apps/harmonyos/entry/src/main/ets/pages/CourseDetail.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Chat.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Plan.ets`
- `scripts/test-product-experience-contracts.mjs`
- `scripts/test-ws01-chat-plan-source-contract.mjs`
- `scripts/test-proactive-learning-service.mjs`
- `scripts/test-proactive-delivery-contracts.mjs`
- `scripts/test_course_resume_contract.py`
- `docs/workstreams/08-product-experience-result.md`

## 五、验证

### 源契约

```powershell
node --test scripts/test-product-experience-contracts.mjs scripts/test-proactive-learning-service.mjs scripts/test-proactive-delivery-contracts.mjs
```

- exit 0，58/58 通过。
- 覆盖首页真实状态门禁、课程直达与旧 payload 兼容、课程排序、三页 latest-wins、错误恢复、Lesson 显式提交/下一互动、后续动作路由失败、Chat/Plan 动态操作语义与 48 vp、Plan 编辑层级与完整任务文本、长文本、返回语义和实际颜色对比度。

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

批次 H 定向复核：

```powershell
node --test scripts/test-product-experience-contracts.mjs scripts/test-ws01-chat-plan-source-contract.mjs
```

- exit 0，27/27 通过。
- 新增约束两类计划任务操作只固定最小 `64 x 48 vp`，不固定最终宽高；既有任务写入串行、保存锁、Chat SSE、长文本和无障碍契约继续通过。

### API 12 HAP

Hvigor 帮助已确认当前版本支持 `--incremental`。最终命令：

```powershell
cd apps/harmonyos
.\hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --incremental --no-daemon
```

- 首批 exit 0，`BUILD SUCCESSFUL in 23 s 216 ms`；渐进提示批次 exit 0，`BUILD SUCCESSFUL in 25 s 664 ms`；后续动作失败恢复批次 exit 0，`BUILD SUCCESSFUL in 31 s 639 ms`；学伴无障碍与自适应批次 exit 0，首次 `BUILD SUCCESSFUL in 19 s 885 ms`，最终复核 `BUILD SUCCESSFUL in 6 s 863 ms`；计划层级批次首次 `BUILD SUCCESSFUL in 22 s 283 ms`，任务优先层级复核 `BUILD SUCCESSFUL in 20 s 718 ms`，失败恢复反例修正后最终 `BUILD SUCCESSFUL in 27 s 288 ms`。
- 批次 H exit 0，`BUILD SUCCESSFUL in 38 s 884 ms`；`CompileArkTS`、`PackageHap` 与 `PackingCheck` 通过。
- `CompileArkTS`、`PackageHap` 与 `PackingCheck` 通过，多项任务显示 `UP-TO-DATE`。
- 项目没有 `signingConfigs`，Hvigor 跳过签名；该结果只记为**构建通过**。
- 最终 HAP：`apps/harmonyos/entry/build/default/outputs/default/entry-default-unsigned.hap`；SHA-256 为 `6C6AEF66A93AD4BE4467E28291083961BD1B95625C055E9324FA5EB93FBE40DF`。
- 早期通用 `assembleHap --no-daemon` 构建虽 exit 0，但日志内部出现 `:entry:clean`；最终证据以上述显式增量构建为准。

### 设备

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets -v
```

- exit 0，输出 `127.0.0.1:5555 / TCP / Connected / localhost`。HAP 使用 `hdc install -r` 返回 `install bundle successfully`，`aa start -a EntryAbility -b com.c4ai.hormony` 返回 `start ability successfully`。
- **模拟器通过（限定流程）**：设备为 DevEco Emulator，竖屏 `1256 x 2760`、密度 3.5、旋转 0。安装后从 UI 树读取底栏“学伴” bounds `[730,2421][808,2466]`，以中心 `(769,2443)` 进入 `pages/Index` 的 Chat 标签。
- 安装后 Chat UI 树记录输入框 `[56,1829][990,1997]`、发送按钮 `[1032,1829][1200,1997]`，二者高度均为 168 px，即 48 vp；状态、输入栏、历史恢复提示和底部导航均在可视范围。截图人工复核未见文字、按钮和相邻区域重叠。
- Plan 最终 HAP 重装后，从根页 UI 树读取“查看完整计划” bounds `[435,2220][821,2256]`，以中心 `(628,2238)` 进入 `pages/Plan`。修复前任务 List bounds 为 `[0,2395][1256,2662]`，高度 267 px（约 76 vp）；已有计划默认收起编辑器后为 `[0,1670][1256,2662]`，高度 992 px（约 283 vp），可视高度约为原来的 3.7 倍。
- 收束态中“调整目标与周期” bounds 为 `[56,878][1200,1046]`；以中心 `(628,962)` 展开后，“收起编辑”、目标输入、三枚建议、三枚周期和生成按钮高度均为 168 px，即 48 vp。以“收起编辑”实时 bounds `[933,601][1200,769]` 中心 `(1066,685)` 返回任务优先视图成功。
- Plan 截图人工复核：收束态首项任务完整显示标题、课程/Topic、规划理由、日期、时长、类型和两枚操作，第二项露出并可继续滚动；展开态建议自动换行，输入、周期和生成控件无相互遮挡，任务操作需先用顶部“收起编辑”返回任务优先视图。
- 失败恢复反例修正后的最终 HAP 再次重装，`17-plan-final2-ui.json` 仍确认 `pages/Plan`、调整按钮 `[56,878][1200,1046]` 和任务 List `[0,1670][1256,2662]`；`17-plan-final2.jpeg` 人工复核任务优先层级无回退。
- 证据目录：`screenshots/ws08-chat-a11y-20260718T093940Z/`。Chat 主要证据为 `04-chat-postinstall-ui.json` 和 `04-chat-postinstall.jpeg`；Plan 主要证据为 `13-plan-final-ui.json`、`13-plan-final.jpeg`、`14-plan-editor-final-ui.json`、`14-plan-editor-final.jpeg`、`15-plan-final-collapsed-ui.json`、`17-plan-final2-ui.json` 和 `17-plan-final2.jpeg`。该目录按仓库规范不提交。
- `uitest dumpLayout` 不导出源码中的 `accessibilityText`；尝试 `-e accessibilityText` 和 `-e focusable` 均返回 `Invalid attribute name, currently supported names are 'uniqueId'.`，因此对象化语义只记为**源码确认/源契约通过**，屏幕朗读与设备焦点行为仍为**未验证**。
- 已按 DisplayManagerService 帮助执行 `-rotationlock,0` 与 `-motion,1`，等待后 DMS 仍显示旋转 0、`1256 x 2760`；横屏未取得有效证据，明确记为**未验证**。应用实际字体缩放效果、平板、减少动效和动态安全区同样未取得对应设备证据。
- 保存失败锁定与加载区滚动已达**源码确认/源契约通过/构建通过**；本批不伪造 ArkData 故障、不调用模型制造慢请求，因此这两条异常流程的模拟器交互仍为**未验证**。

批次 H 设备复核继续使用同一 API 12 模拟器与目标：

- 系统设置 UI 树先确认“字体大小”为“特大”、滑块值 `5.000000`；应用经 `aa force-stop com.c4ai.hormony` 和 `aa start -a EntryAbility -b com.c4ai.hormony` 真实重启后，完成 Chat 与 Plan 流程。系统设置本身已确认，但应用文本几何与标准字号基线一致，因此只证明**最大字体设置流程已执行**，不把应用实际字体缩放记为模拟器通过。
- 最终 HAP 以 `hdc install -r` 安装成功并重新启动。Plan 连续 UI 树稳定在 `pages/Plan`；“学习/完成/练习/完成”操作 bounds 分别为 `[927,1719][1151,1887]`、`[927,1908][1151,2076]`、`[927,2202][1151,2370]`、`[927,2391][1151,2559]`，均为 `224 x 168 px`，即密度 3.5 下的最小 `64 x 48 vp`。截图中任务标题、课程/Topic、理由、日期、时长、类型和两组操作无重叠。
- Chat 最终 UI 树确认输入框 `[56,1829][990,1997]`、发送按钮 `[1032,1829][1200,1997]`，均为 168 px（48 vp）高；长回答位于独立滚动区，输入、重试、恢复提示和底栏无重叠。
- DisplayManagerService 只读信息确认实际视口 `1256 x 2760`、`VirtualWidth: 358`、`VirtualHeight: 788`、`VirtualPixelRatio: 3.5`，因此本批取得**358 vp 窄宽模拟器证据**。同一输出仍为 `Rotation: 0`，帮助文本同时显示 `dms.hidumper.supportdebug false`；未修改调试开关或绕过限制，横屏继续记为**未验证**。
- 最终证据位于 `screenshots/ws08-max-font-20260718T180018Z/`：Plan 为 `27-final-plan-a-ui.json`、`28-final-plan-b-ui.json`、`28-final-plan.jpeg`；Chat 为 `31-final-chat-ui.json`、`31-final-chat.jpeg`；系统字体恢复为“标准”与滑块 `2.000000` 的证据为 `41-font-restored-verification-ui.json`。该目录按仓库规范不提交。

## 六、仍未验证与下一缺口

1. 仓库没有 API 12 系统“减少动效”信号的精确使用依据，本批未猜写接口；减少动效仍为**未验证**。
2. `Index` 已响应式订阅安全区，但公共二级页标题仍通过静态 getter 读取顶部安全区；旋转时的即时重排需有效横屏设备证据和统一 Builder 参数设计。
3. Chat 当前在线失败时保留真实重连，但 Chat/Plan 的屏幕朗读、硬件键盘焦点顺序和最大字体下的展开内容仍需对应设备能力验证。
4. 课程路径仍使用现有 `router`。迁移到 `Navigation` 影响全部子页和回流契约，不属于本批安全范围。
5. 本批未调用线上 API、模型、通知或服务卡片；不声明线上通过、真机通过、屏幕朗读通过或横屏通过。

## 七、审计说明

- 四条只读委派分别完成成熟学习产品/开源实现基准、窄屏/字体/动效契约审计、首页-课程-Lesson 产品流程审计和 Lesson 后续动作状态反例复核；委派代理未修改文件。
- Plan 批次另有两条只读委派：一条核对 WS03/04/06/07/09 refs、结果文档和页面归属，一条逐行审计 Plan 大字号、读屏、48 vp、截断和宽屏层级；均确认只改 Plan 展示层且必须保留 `be0bc17` 状态契约，委派代理未修改文件或操作设备。
- 独立 diff 审查尝试因本机没有 CodeRabbit CLI 和后续并发连接中断而未形成审查结论；未将其记为通过证据。
- Chat 批次恢复后未重复请求 DevEco Agent；已知 Alibaba `qwen3-coder-plus` 返回 403 `AllocationQuota.FreeTierOnly`，`deveco/glm-5` 返回 401 `Token refresh failed`，按任务要求停止重试并使用本地契约、Hvigor 与 HDC 完成验证。
- 交付结论以当前源码、58 项 WS08 Node 契约、16 项 Python 契约、13 项 Chat/Plan 契约、API 12 显式增量构建和限定竖屏模拟器证据为准。
