# WS02 测验掌握度与错题复习结果

本文件记录 WS02 在独立分支 `codex/ws02-quiz-mastery` 上的产品改动与可复验证据。证据等级严格区分源码、静态诊断、构建和设备运行，不以构建结果代替模拟器、真机或线上验证。

## 批次 1：精确 Topic 防污染边界

### 背景

测验 API 此前允许缺少 `topic` 时回退为“综合”，HarmonyOS 多个入口也会把“综合”、搜索词或近似名称写入测验上下文。现有课程数据的唯一有效集合是题库、知识切片和 Topic 关系共同覆盖的 33 个精确 `courseId:Topic`，因此本批次先封闭入口，避免错误 Topic 污染后续掌握度、错题和复习统计。

### 文件

- `apps/web/src/lib/data/index.ts`
- `apps/web/src/app/api/quiz/route.ts`
- `apps/web/src/app/api/quiz/quiz-flow.test.ts`
- `apps/web/src/lib/data/data-integrity.test.ts`
- `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Course.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Practice.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Knowledge.ets`

### 行为变化

- Web 新增 `isCourseTopic(courseId, topic)`，以课程题库为精确 Topic 集合；`POST /api/quiz` 对缺失、空白、近似和跨课程 Topic 返回 HTTP 400 与 `INVALID_TOPIC`。
- HarmonyOS Quiz 从 `LearningContentRepository.getTopics(courseId)` 读取全部正式 Topic，仅接受集合中的入口值和用户选择。
- Course、Practice、Lesson、Knowledge 不再把“综合”、空值或知识搜索词写入 Quiz；无有效 Topic 时显示明确错误并阻止导航或保存。
- 契约测试固定 33 个精确 `courseId:Topic`，校验关系图、Web 题库、Web 选择题、HarmonyOS 题库和知识切片集合一致，并校验端侧题库 9 个字段及 12 个 Topic 入口。
- 展示题 `questions` 与本地评分 `grading` 的分离契约保持不变。

### 验证

- **静态诊断通过**：`python scripts/validate-topic-relations.py`，exit 0，33 个 Topic 的 schema、唯一性、引用、DAG、连通性、层级及跨数据一致性全部通过。
- **静态诊断通过**：`cd apps/web; pnpm lint`，exit 0，无警告或错误。
- **静态诊断通过**：`cd apps/web; pnpm typecheck`，exit 0。
- **静态诊断通过**：`cd apps/web; pnpm exec vitest run src/lib/data/data-integrity.test.ts src/app/api/quiz/quiz-flow.test.ts`，exit 0，2 个文件、22 项测试通过。
- **静态诊断通过**：`cd apps/web; pnpm test`，exit 0，13 个文件、169 项测试通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建完成。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，`BUILD SUCCESSFUL in 8 s 193 ms`；项目未配置 `signingConfigs`，构建跳过签名。

### 失败或未验证

- 模拟器、真机和线上流程未验证；本批次不声明设备运行通过。
- 幂等五类学习状态写回、终身统计、失败恢复、重启恢复、到期复习和再练将在后续批次实现并验证。

## 批次 2：ArkData 测验掌握度、错题到期复习与全量标签洞察

### 背景

旧实现把最近 20 次答题结果同时当作统计事实来源，并分别更新画像、错题、活动和 Topic 掌握度。结果明细截断后终身统计会丢失，多键写入中断也会留下部分状态；同一 AI 题包的固定 `quizId` 还会让第二次真实作答被误判为写回重试。本批次把可恢复的答题事实及派生状态收敛到 ArkData 单键 `quiz_learning_state`，保留展示题 `questions` 与本地评分 `grading` 分离，不改变云端题目内容源。

### 文件

- `apps/harmonyos/entry/src/main/ets/common/QuizLearningStateReducer.ets`
- `apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets`
- `apps/harmonyos/entry/src/main/ets/model/DataModels.ets`
- `apps/harmonyos/entry/src/main/ets/model/LearningMetadataModels.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Practice.ets`
- `apps/harmonyos/entry/src/main/ets/pages/MistakeBook.ets`
- `apps/web/src/lib/data/quiz-learning-state.test.ts`
- `apps/web/src/lib/data/mistake-review-flow.test.ts`

### 行为变化

- AI 题包 ID 写入 `sourceQuizId`，每次题组加载生成稳定的本次 `quizId/attemptId`；保存失败重试沿用同一尝试 ID 与提交时间，同一题包的两次真实作答分别累计。
- `quiz_learning_state` 使用静态 Promise 队列串行读写。答题先持久化 `pendingResults`，再幂等归并并完成第二次持久化；重启读取会恢复 pending，内部写入只调用未加锁 loader，课程进度也从当前状态快照和原始课程事件计算，不在队列内回调公开 getter。
- 数据库 schema 升至 8，测验状态 schema 升至 2；迁移以 `LearningContentRepository.getTopics(courseId)` 的 33 Topic 精确集合清洗旧结果、错题、掌握度、标签、活动和 milestone，补齐新字段、恢复有效 pending，并从真实 `quiz_mastered` 事件与现有掌握记录建立首次掌握 milestone。
- 最近结果只保留 20 条、测验活动明细只保留 500 条、已解决错题只保留 200 条；终身尝试数、题数、正确数、学习日期、Topic 掌握累计、首次掌握 milestone 和标签累计不随明细截断。
- 错题保留原题 A-D 选项、解析、标签、难度和精确 `reviewItemId`。复习按 1、3、7、14 天推进，未到期正确作答不会提前推进间隔；错题本显示到期优先队列，未到期按钮禁用。旧记录没有完整选项时明确降级为同 Topic 精选题，不伪装为原题。
- Practice 的复习题保留真实 `questionId`，复习项身份单独写入 `reviewItemId`，避免同一精选原题在一组内重复；提交后提供逐题复盘、问学伴入口和画像、错题、Topic 掌握度、活动次数、课程进度写回回执。
- 标签生产态以 `JSON.stringify([courseId, topic, tag])` 作为精确复合身份。Quiz 与 `lesson_activity` 都幂等聚合到持久状态；`getAllTagInsights()` 返回未截断全量洞察，供调用方按精确课程与 Topic 过滤，不再从最多 500 条活动明细重算。
- 成就与课程进度使用真实首次掌握 milestone；后续累计正确率下降不会撤销已经发生的首次掌握事件或使课程完成进度回退。

### 旧提交取舍

- **源码确认**：逐一复核 `5dfcbc3`、`ecefd25`、`14c9250`、`ddaaf12`、`3b815b9`、`a4e45c5`、`77b1ad1`、`2615966`、`258fce0` 及 `codex/harmony-1.13-knowledge-insights` 相关提交，没有整枝合并或直接 cherry-pick。
- 当前实现保留并加强了题目/评分分离、逐题复盘、错题恢复和标签洞察；拒绝提交前揭示 grading、“综合”兼容路径、固定“明天复习”文案及 `KEY_QUIZ_STATS`/`KEY_TAG_INSIGHTS`/`KEY_TOPIC_MASTERY` 分键顺序写入。
- 选择性采用旧迁移清洗思路，但改为按每个 `courseId` 的正式 Topic 集合精确过滤，覆盖历史结果、错题、掌握度、标签、活动与 milestone，不只排除单个文字值。

### 验证

- **静态诊断通过**：`python scripts/validate-topic-relations.py`，exit 0，33 个 Topic 的 schema、唯一性、引用、DAG、连通性、层级及题库/知识切片一致性全部通过。
- **静态诊断通过**：`cd apps/web; pnpm exec vitest run src/lib/data/quiz-learning-state.test.ts src/lib/data/mistake-review-flow.test.ts`，exit 0；队列、pending 恢复、重复题包多次作答、605 次终身统计、605 条课程互动、复合标签隔离、首次掌握、提前复习门控、原题恢复和旧记录降级契约通过。
- **静态诊断通过**：`cd apps/web; pnpm lint`，exit 0，无警告或错误。
- **静态诊断通过**：`cd apps/web; pnpm typecheck`，exit 0。
- **静态诊断通过**：`cd apps/web; pnpm test`，exit 0，15 个文件、188 项测试通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建完成。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，最终增量构建 `BUILD SUCCESSFUL in 30 s 379 ms`；项目未配置 `signingConfigs`，构建跳过签名。
- **源码确认**：`hdc list targets`，exit 0，输出 `[Empty]`，当前没有可用于设备验收的目标。

### 失败或未验证

- **未验证**：当前无模拟器或真机目标，未执行真实 ArkData 并发提交、进程中断后的 pending 恢复、应用重启后的错题/画像/Topic 掌握度/活动/课程进度逐项读取，也未完成到期时间跨日的设备流程。
- **未验证**：线上 AI 出题与提交链路本批次未重新调用；不沿用 HTTP 200 作为本批次业务成功证据。
- **未验证**：HAP 未签名，安装、真机和多设备行为未验证。

## 批次 3：结果页下一步与复合标签消费契约

### 背景

答题写回后虽然已有逐题复盘和状态回执，但 Quiz 结果页只有泛化的“再练一组”，Practice 结果页无论是否存在错题都进入 AI 测验，用户无法从结果页直接继续错题复习。本批次补齐真实下一步动作，并复核 WS04 消费标签洞察所需的精确隔离和全量读取边界。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Practice.ets`
- `apps/web/src/lib/data/quiz-learning-state.test.ts`

### 行为变化

- Quiz 有错题时显示“查看错题本”并进入真实 `pages/MistakeBook`；同时保留再练动作。正确率达到 80% 后，下一组按 `easy -> medium -> hard` 提升难度，挑战难度不再越界；不足 80% 时保持当前难度再练。
- Practice 有错题时下一步进入错题本，全对时才进入 AI 测验。Quiz 与 Practice 的两个新导航路径失败时均在当前页面显示明确错误，不把失败误报为成功。
- 页面动作契约从源码提取实际方法，约束错题本路由、失败提示、难度递进与 Practice 分支，不依赖静态假回复或运行时替身。
- **源码确认**：生产 reducer 使用 `JSON.stringify([courseId, topic, tag])` 作为标签洞察身份；605 条学习事件契约证明跨 Topic 同名标签分别累计且长期总数不受 500 条活动明细截断。
- **源码确认**：公开 `LocalLearningRepository.getAllTagInsights()` 克隆并排序 `state.tagInsights` 全量持久状态，不调用截断版活动读取、不做 `slice`，供 WS04 在按精确课程、Topic 过滤弱项前使用；现有 `getTagInsights(limit)` 仅作为展示摘要 API。

### 验证

- **静态诊断通过**：`python scripts/validate-topic-relations.py`，exit 0，33 个 Topic 的 schema、唯一性、引用、DAG、连通性、层级及题库/知识切片一致性全部通过。
- **静态诊断通过**：`cd apps/web; pnpm lint`，exit 0，无警告或错误。
- **静态诊断通过**：`cd apps/web; pnpm typecheck`，exit 0。
- **静态诊断通过**：`cd apps/web; pnpm test`，exit 0，15 个文件、192 项测试通过；其中结果页新增 4 项动作契约，全量洞察与复合标签隔离契约继续通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建完成。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，`BUILD SUCCESSFUL in 26 s 637 ms`；项目未配置 `signingConfigs`，构建跳过签名。
- **源码确认**：`hdc list targets`，exit 0，输出 `[Empty]`，当前没有可用于设备验收的目标。

### 失败或未验证

- **未验证**：无模拟器或真机目标，未执行结果页点击、错题本跳转、难度递进和应用重启后的设备流程。
- **未验证**：本批次未重新调用线上 Quiz，不声明线上题组生成或业务字段通过。
- **未验证**：HAP 未签名，安装、真机和多设备行为未验证。

## 批次 4：答题草稿恢复、冻结写回与读屏语义

### 背景与行为变化

- Quiz 与 Practice 将未提交答案、当前题号、精确课程、Topic、重点标签或错题入口、题组及独立 grading 保存到 ArkData；离页重进恢复同一 attempt，不跨上下文串草稿。
- AI 长等待离页会取消精确请求并隔离旧生命周期回调。首次提交冻结答案和 `submittedAt`；写回重试复用同一 attempt，同 ID 异载荷明确拒绝。
- 草稿创建、草稿保存和结果写回未确认使用不同错误层级，不再把内存答案误报为已落盘，也不把草稿保存失败误报为结果写回失败。
- AnswerOption 提供已选择、未选择和冻结状态；逐题解析提供展开状态；MistakeBook 的解析与重练操作具有精确名称和不小于 48 vp 的操作区。

### 对应提交

- `67cdcdf fix: 恢复测验草稿并冻结写回`
- `79bd393 fix: 补齐答题闭环读屏语义`
- `7132eb4 fix: 区分草稿保存与结果写回失败`

### 验证

- **静态诊断通过**：定向 Quiz/Practice/错题契约累计 `57/57` 通过。
- **静态诊断通过**：Web lint、typecheck、`422/422` 测试和生产构建均通过。
- **构建通过**：API 12 增量 HAP 构建完成，`BUILD SUCCESSFUL in 21 s 951 ms`；项目未配置 `signingConfigs`。
- **未验证**：当时 `hdc list targets` 输出 `[Empty]`，因此该批没有模拟器、真机或线上模型调用证据。

## 批次 5：放弃草稿互斥、事务创建与重入幂等

### 背景

草稿 Repository 已串行化操作，但页面在 `clear*Draft()` 等待期间仍能排入新保存，形成“旧保存 -> 清除 -> 新保存”，使已放弃草稿复活。Quiz 与 Practice 首次 create 还存在“已写入 -> 页面生命周期失效 -> 事后清理”窗口，其他重入页面可能在清理前读到本应取消的 attempt；Practice 在首次 create 等待中离页还会再排一次 create。

### 文件

- `apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Practice.ets`
- `apps/web/src/lib/data/quiz-learning-state.test.ts`

### 行为变化

- Quiz 与 Practice 新增 `discardingDraft` 互斥态。清除前先失效旧保存回调；等待期间冻结答案、翻题、保存、提交、页内返回和系统返回，按钮显示明确忙碌文案。
- `queueDraftSave()` 在互斥态拒绝后排保存；clear 前递增保存 epoch，使已完成的旧回调失效。页面重新显示时按精确上下文和 attemptId 向 Repository 复核所有权，旧页面不会继续保存已被其他页面结束的 attempt。
- Repository 将首次 create 与后续 save 分开：create 对精确上下文执行 CAS，不覆盖其他页面草稿；save 只更新同 attempt。相同 attempt 的同载荷 create 是幂等 no-op，异载荷明确冲突，迟到 create 不会把后续答案回退。
- API 12 的 `querySqlSync`、`executeSync`、`beginTransaction`、`commit` 与 `rollBack` 在同一 JS 调用栈完成“读取 -> CAS -> 写入 -> lifecycle guard -> 提交或回滚”。全部草稿访问仍经过同一 `answerDraftQueue`；后排 get/create 无法观察 create 与 rollback 之间的未提交状态，进程中断由 RDB 事务回滚，而不是依赖第二次补偿写。
- Quiz create guard 绑定精确 generation run、页面 lifecycle 与请求取消对象；Practice guard 绑定精确 load run、lifecycle 与 attemptId。Practice 只有 create 提交后才设置 `draftCreated`，首次 create 等待期间 `onPageHide` 不再排第二次 create。
- attemptId 使用 Repository 共享进程计数器生成并拒绝首尾空格；clear、create、save 均按规范化前的精确值校验，不进行模糊匹配。
- 动态 ArkData fixture 实际执行事务 begin/commit/rollback、guard 失效时后排读取、rollback 后后排 create、guard 抛错、clear 后 late save、同 attempt 迟到 create 及写失败恢复；页面契约固定互斥、生命周期 guard 和重进核验顺序。

### 验证

- **静态诊断通过**：`cd apps/web; pnpm exec vitest run src/lib/data/quiz-learning-state.test.ts`，exit 0，`56/56` 通过。
- **静态诊断通过**：`cd apps/web; pnpm lint`、`pnpm typecheck`，exit 0。
- **静态诊断通过**：`cd apps/web; pnpm test`，exit 0，28 个文件、`433/433` 测试通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建完成。
- **构建通过**：本机 API 12 SDK 类型声明确认同步查询、写入和事务接口均为 `@since 12`。`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` 完成 CompileArkTS 与 PackageHap，`BUILD SUCCESSFUL in 21 s 609 ms`；项目未配置 `signingConfigs`，构建跳过签名。
- **静态诊断通过**：`scripts/harmonyos-app-smoke.ps1 -SelfTest`，exit 0，UI 树 JSON、bounds 中心点、精确文本与设备目标参数 `9/9` 通过。
- **模拟器通过**：Pura 90 Pro Max，竖屏 1256x2760，目标 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`。本次 `entry-default-unsigned.hap` 返回 `install bundle successfully`，`com.c4ai.hormony/EntryAbility` 返回 `start ability successfully`。UI 树按 bounds 点击“课程” `[448,2421][526,2466]`、“继续课程” `[245,1156][428,1209]` 与二叉树主题“继续” `[1073,2361][1151,2406]`，页面依次为 `pages/Index`、`pages/CourseDetail`、`pages/Lesson`。
- **模拟器通过**：同批较早构建在同一模拟器从 `pages/MistakeBook` 进入 `pages/Practice`，选择 C 后“下一题”为 enabled，放弃草稿后恢复为 disabled；返回错题本并重进同一复习项后仍为 disabled，旧答案未恢复。最新事务收紧没有重新执行该输入流程，因此它不替代当前 HAP 的构建与契约证据。
- **模拟器通过**：smoke 已生成启动页与课程页截图，证据目录为 `screenshots/trae-smoke-20260718-152011/`；该本地目录不纳入提交。

### 失败或未验证

- **未验证**：DevEco Agent 当前不可用：`alibaba-cn/qwen3-coder-plus` 返回 `403 AllocationQuota.FreeTierOnly`，内置 `deveco/glm-5` 返回 `401 Token refresh failed`；按主线程指令停止重试且不回落 `openai/*`。此前对 Repository、Quiz、Practice 取得的 `check_ets_files: no diagnostics` 早于本次事务改动，不作为最新静态诊断；API 12 Hvigor 与 HDC 证据单独成立。
- **未验证**：全量 smoke 在已完成安装、启动、首页和课程页截图后，因当前首屏 UI 树没有精确文本“计算机网络”而 exit 1；该断点与草稿状态机无关，但其后步骤不能标记通过。
- **未验证**：本次设备流程不使用文本输入；`uitest uiInput inputText` 曾切到系统“学习助理”，重新 `aa start` 后应用正常，属于模拟器输入法干扰，不记录为产品失败。最新 HAP 的 Quiz 生成、取消、放弃、重进与提交设备流程未完成。
- **未验证**：未调用线上 Quiz 或模型，不声明线上题组生成或业务字段通过；项目未配置生产签名，真机与多设备未验证。

## 批次 6：长期结果幂等摘要与确定性错误分层

### 背景

`recentResults` 只保留最近 20 条，但 `appliedQuizIds` 长期保留。第 21 条之后，旧成功结果的同载荷重试无法再从 recent window 找到原文，旧实现会把“摘要已截断”误报成“载荷冲突”，页面又统一提示可以重试，形成不会自行恢复的错误循环。

### 行为变化

- `QuizLearningState` 从 schema 2 迁移到 schema 3，ArkData schema 从 12 迁移到 13；新增与 `appliedQuizIds` 同保留期、同顺序的 `appliedQuizProofs`。
- 新写回使用 API 12 `CryptoArchitectureKit` 的 `createMd('SHA256')`、`updateSync`、`digestSync` 和 UTF-8 `TextEncoder` 生成 verified proof。输入为带长度前缀的显式 canonical payload，覆盖原同载荷比较的全部结果字段、逐题字段、数组顺序与 optional 区分，不依赖对象属性顺序或分隔符猜测。
- recent window 内的 schema 2 结果在迁移时重新计算 verified proof；已经被截断、无法从现有 ArkData 重建原文的 ID 标记为 `legacy-unverifiable`，不冒充同载荷成功，也不冒充 payload conflict。
- 新结果 pending outbox 在归并前生成 proof，结果、画像、错题、标签、活动与 proof 在同一 `quiz_learning_state` 写回链路持久化。第 21 条之后的同载荷重试仍返回 `applied: false`，不会重复累计；异载荷仍由 SHA-256 proof 确定性拒绝。
- Repository 分别抛出 `QuizResultConflictError` 与 `QuizResultVerificationUnavailableError`。Quiz/Practice 对这两类确定性错误显示“放弃草稿后重新开始”，当前页面将提交按钮切换为“写回已阻止”并禁用；暂时性 ArkData/摘要生成失败仍保留原重试路径。
- 旧的 `sameQuizResult/sameStringArray` 已删除，避免两套同载荷定义漂移。

### 验证

- **静态诊断通过**：`cd apps/web; pnpm exec vitest run src/lib/data/quiz-learning-state.test.ts`，exit 0，`59/59` 通过。
- **静态诊断通过**：动态 ArkData fixture 连续写入 25 个结果，确认首条被 recent window 淘汰后同载荷重试仍幂等、异载荷仍冲突，统计保持 25 次；schema 2 的 25 个 ID 迁移后前 5 个为 legacy、后 20 个为 verified，legacy 重试 fail-closed 且不增加统计。
- **静态诊断通过**：canonical payload 字段覆盖、SHA-256 精确算法名、pending proof 顺序、schema 13 迁移、页面确定性错误先于暂时性错误及按钮阻止态均有源码契约；Web lint、typecheck、28 个文件 `436/436` 测试通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建完成。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` 完成 CompileArkTS 与 PackageHap，`BUILD SUCCESSFUL in 24 s 710 ms`；项目未配置 `signingConfigs`，构建跳过签名。
- **模拟器通过**：目标 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`。最新 `entry-default-unsigned.hap` 返回 `install bundle successfully`，`com.c4ai.hormony/EntryAbility` 返回 `start ability successfully`；UI 树为 `pages/Index`，根 bounds `[0,137][1256,2760]`，可见品牌文本“鸿学伴”。

### 未验证

- **未验证**：本批不构造或清除模拟器用户数据库，长期第 21 条重试与 schema 2 升级由可执行 ArkData fixture 和 API 12 HAP 构建验证，未在模拟器 UI 中人工制造 25 次历史答题。
- **未验证**：未调用线上 Quiz 或模型，不声明线上题组生成、线上提交或模型业务字段通过；DevEco Agent 的 Alibaba 403 与内置模型 401 状态未重试。
- **未验证**：项目未配置生产签名，真机与多设备未验证。

## 批次 7：旧测验迁移失败后的重入幂等

### 背景与行为变化

- schema 8/10 的旧测验迁移需要依次写入 `quiz_learning_state` 与清理后的 `study_events`。旧实现若第一键成功、第二键失败，`schema_version` 会保持旧值；下次初始化再次把同一旧画像、掌握度和答题统计追加到已经迁移的状态，造成终身统计翻倍。
- 历史聚合确实早于当前测验状态时，迁移在追加统计的同一次 `quiz_learning_state` 写入中同步保存 `legacy.updatedAt` 作为 `firstSubmittedAt` 时间边界。失败重入后，同一历史不再满足“早于当前状态”，既有的非追加合并分支保持现状，无需新增 schema 或独立迁移标记。
- 动态 ArkData fixture 在 `study_events` 写入点注入失败：首次中断后保持 6 次、42 题、30 题正确；同进程重新初始化后仍为 6 次、42 题、30 题正确，Topic 掌握累计保持 6 次、12 题、9 题正确，最终 schema 升至 13。修复前同一用例稳定复现为 10 次、82 题、59 题正确。

### 验证

- **静态诊断通过**：`cd apps/web; pnpm exec vitest run src/lib/data/quiz-learning-state.test.ts`，exit 0，`60/60` 通过；新增第二键写失败与迁移重入故障注入反例。
- **静态诊断通过**：`cd apps/web; pnpm lint`、`pnpm typecheck`，exit 0；`pnpm test` 为 28 个文件、`437/437` 通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建完成。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，CompileArkTS 与 PackageHap 完成，`BUILD SUCCESSFUL in 24 s 457 ms`；项目未配置 `signingConfigs`，构建跳过签名。
- **模拟器通过**：目标 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`。最新 `entry-default-unsigned.hap` 返回 `install bundle successfully`，`com.c4ai.hormony/EntryAbility` 返回 `start ability successfully`；UI 树为 `pages/Index`，根 bounds `[0,137][1256,2760]`。

### 未验证

- **未验证**：本批不修改或清除模拟器用户数据库，schema 8/10 第二键写失败后的统计不重复由可执行 ArkData 故障注入 fixture 验证，未在模拟器内破坏真实迁移过程。
- **未验证**：未调用线上 Quiz 或模型，不声明线上题组生成、线上提交或模型业务字段通过；按主线程约束未重试当前不可用的 DevEco Agent 模型。
- **未验证**：项目未配置生产签名，真机与多设备未验证。
