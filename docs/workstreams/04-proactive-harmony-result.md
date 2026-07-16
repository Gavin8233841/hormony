# WS04 主动服务与鸿蒙原生体验结果

更新时间：2026-07-17

## 目标与边界

本工作流围绕唯一闭环推进：真实学习事件 -> 到期错题或精确可执行的今日计划 -> next-best-action -> 首页、通知和服务卡片主动触达 -> 一键回到任务 -> 后续答题或完成事件继续更新本机状态。

基线为 `dd2fe16 docs: 新增鸿蒙2.0接力文档`，工作分支为 `codex/ws04-proactive-harmony`。本工作流没有修改 Web API、模型、安全边界、ArkData schema、第三方依赖或产品资产，也没有把 OCR、TTS、Lottie 或分布式能力写成已通过。

## 交付结果

### 统一主动行动

- `ProactiveLearningService.ets` 从 ArkData Repository 读取课程、学习事件、到期错题和今日计划。
- 固定优先级为：精确课程 Topic 下的到期错题、今日最早可执行任务、最近真实学习事件对应课程、制定计划。
- 每个行动统一携带 badge、标题、推荐依据、进度、CTA、课程、Topic、标签、任务类型和目标页面。
- 无学习事件且三门目录课程均为零进度时，明确进入“制定计划”，不再默认续学第一门课。
- 今日计划只接受存在的课程、归属该课程的精确 Topic 和 `lesson/practice/quiz/review` 动作；可跳过无效任务选择后续有效任务，全部无效时引导重新生成计划。

### 首页、通知与服务卡片

- `HomeContent.ets` 只消费统一行动，不再维护第二套排序；首屏说明推荐依据和当前进度。
- 首页通知入口区分创建中、创建成功和权限/发布失败，失败状态使用错误语义。
- `LearningReminder.ets` 使用 API 12 `WantAgent`，通知正文和点击参数来自同一行动。
- 通知授权请求完成后再次读取系统开关；仍未授权时不发布通知，并在首页保留明确错误和重试操作。API 12 不调用 API 13 才提供的应用内通知设置接口。
- `EntryAbility.ets` 在 `onCreate` 与 `onNewWant` 消费卡片/通知参数；合法外壳通过目录校验后重新解析当前 ArkData 行动，单调序号保证连续 Want 只执行最后一次，无关 Want 不清除已排队入口。
- `EntryAbility.ets` 对重算后的当前行动生成前台周期稳定键；相同来源和行动的重复 Want 只发布一次，进入后台后释放去重状态，后续真实触达仍可再次执行。
- `Index.ets` 通过 `@StorageLink + @Watch` 覆盖冷启动和热启动；嵌套页上的课程入口使用 API 12 `Router.back({ url: 'pages/Index' })` 返回根页，其他目标按当前路由栈执行 `pushUrl/replaceUrl`，只在导航确认成功后消费目标。
- `EntryAbility.ets` 先完成内容仓库与 ArkData 课程目录同步，再校验来源、128 字符长度上限、动作/页面映射、课程和精确 Topic；外部 `courseTitle` 被忽略，标题从本地目录推导，非法 Want 不写 `AppStorage`。
- `LearningFormUpdater.ets` 与 `LearningPlanCard.ets` 展示同一行动、依据、进度和 CTA，`FormLink` 传递精确目标页面及学习上下文。

### 记录、画像与成就反馈

- 学习事件按本地时区分组和显示，不再直接截取 UTC ISO 字符串。
- 近 4 周学习节奏、连续天数、活跃天数、事件数和分类筛选全部由本机真实事件计算。
- 每条计划、课程互动、课程完成、精选练习和 AI 测验记录按已有 AppStorage 契约回到真实页面；旧事件 Topic 不再属于当前课程时只回到课程详情。
- `Achievements.ets` 展示每项里程碑的真实来源、剩余量和本地解锁日期；最接近解锁的目标使用本地课程目录、未计数互动和未掌握 Topic 提供可增长的精确动作。

### WS02 标签洞察依赖

- 已读取 `codex/ws02-quiz-mastery` 工作树 HEAD `c9572d2` 上的未提交 `QuizLearningStateReducer.ets`、`LocalLearningRepository.ets` 差异与 `quiz-learning-state.test.ts`。
- 源码确认 reducer 的 `tagInsightKey(courseId, topic, tag)` 使用三元组分组，其测试包含“相同标签在不同精确 Topic 下分别累计”用例。
- 当前 WS04 基线 Repository 仍按 `tag` 跨课程/Topic 聚合，所以本批主动服务、记录页和成就页不读取标签洞察，也没有修改 `LocalLearningRepository.ets`。
- WS02 reducer 提交并集成后，再用独立补丁恢复薄弱标签主动推荐；若需新增完整集合 Repository API，必须单独提交以便在 WS02 之后精确重放。

## 旧提交复核

- `efadc6d`：已读取每日收束实现，未直接采用。“今日计划全部完成”不能证明到期复习和薄弱标签已经处理，直接显示“今日已收束”会与统一主动行动冲突。
- `da6a3a5`：采用真实事件节奏与分类筛选思路；实现改为本地时区分组，并把 `lesson_activity` 纳入课程筛选。
- `b301688`：采用“下一成就可执行”思路；实现改为使用当前 Repository 课程的精确 Topic，不使用固定文案 Topic。
- `5f69a8f`：已读取薄弱标签直达思路；因当前标签洞察仍跨课程/Topic 混合，本批不采用该直达实现。

## 文件

- `apps/harmonyos/entry/src/main/ets/common/ProactiveLearningService.ets`
- `apps/harmonyos/entry/src/main/ets/common/LearningFormUpdater.ets`
- `apps/harmonyos/entry/src/main/ets/common/LearningReminder.ets`
- `apps/harmonyos/entry/src/main/ets/entryability/EntryAbility.ets`
- `apps/harmonyos/entry/src/main/ets/pages/HomeContent.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Index.ets`
- `apps/harmonyos/entry/src/main/ets/pages/ActivityRecords.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Achievements.ets`
- `apps/harmonyos/entry/src/main/ets/widget/pages/LearningPlanCard.ets`
- `apps/harmonyos/entry/src/main/resources/base/element/string.json`
- `scripts/test-proactive-delivery-contracts.mjs`
- `scripts/test-proactive-learning-service.mjs`

## 验证证据

| 等级 | 命令或依据 | 结果 |
|---|---|---|
| **源码确认** | DevEco Studio API 12 SDK 类型声明 | 已确认 `NotificationRequest.wantAgent`、`wantAgent.getWantAgent()`、`UIAbility.onNewWant()`、`@Watch`、`FormLink` 的 `router/params` |
| **源码确认** | DevEco Studio API 12 `@ohos.notificationManager.d.ts` | `requestEnableNotification(context)` 要求 UI 加载后调用；用户拒绝后不能再次弹框。`openNotificationSettings` 从 API 13 提供，因此 API 12 采用系统设置提示与显式重试 |
| **源码确认** | WS02 未提交 reducer 与测试 | 三元组分组与跨 Topic 隔离用例存在；本批未修改、未提交或运行 WS02 测试 |
| **源码确认** | `node --test scripts/test-proactive-learning-service.mjs` | exit 0，21/21 通过；直接执行当前 `.ets` 服务并约束无关 Want、latest-wins、点击时重解析、根页回流、子页替换及失败保留重试 |
| **源码确认** | `node --test scripts/test-proactive-delivery-contracts.mjs` | exit 0，12/12 通过；直接执行当前服务、提醒、卡片更新器、Form Ability 与 EntryAbility，另对 ArkUI 绑定做精确静态契约检查 |
| **源码确认** | 两个主动学习脚本合并执行 | exit 0，33/33 通过；覆盖六项触达参数一致、授权后二次确认、点击时重算、latest-wins、前台周期幂等、根页回流及失败保留重试 |
| **构建通过** | `cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` | 最新 exit 0，`CompileArkTS` 与 HAP 打包完成，`BUILD SUCCESSFUL in 24 s 131 ms` |
| **未验证** | DevEco MCP 单文件 ArkTS 诊断 | 当前任务未提供 DevEco MCP，不能写为静态诊断通过 |
| **未验证** | `hdc list targets` | 使用 DevEco 安装目录中的 `hdc 3.2.0e` 执行，exit 0，返回 `[Empty]` |
| **未验证** | 通知授权、通知点击、服务卡片桌面渲染与点击 | 当前无模拟器或真机目标 |

构建仍提示仓库未配置 `signingConfigs`，所以只证明未签名 debug HAP 构建通过，不证明安装或提交包可用。

## 未验证与后续

- 首页、记录、成就、提醒和卡片已在源码中共享同一真实状态，但缺少设备上的“计划保存/答题事件 -> 首页和卡片刷新 -> 通知或卡片点击回流”证据。
- 按课程/Topic/标签隔离的主动标签推荐依赖 WS02 reducer 先完成提交和集成，当前明确未启用。
- 服务卡片 2x2 的桌面排版、安全区、字体截断和点击区域未取得模拟器或真机证据。
- 通知权限首次请求、用户拒绝后的错误态与重试、通知点击冷热启动 `onNewWant` 幂等均未取得设备证据。
- HAP 签名、安装、横屏、平板和真机均未验证。
- OCR、TTS、Lottie、distributedKVStore 未修改且仍为未验证。

第一批提交：`a3d2ad4 feat: 统一主动学习触达`。
第二批提交：`c6697ef fix: 修正主动学习状态与入口边界`。
第三批提交：`17057cc fix: 强化主动触达幂等与失败恢复`，主线集成时保留最新行动重算与成功后消费状态机。
