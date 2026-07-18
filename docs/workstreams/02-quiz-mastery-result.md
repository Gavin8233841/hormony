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

## 2026-07-19 主线：旧测验累计迁移重入与再次降级

### 背景与行为变化

- WS07 `c03930e` 原修复通过覆盖 `firstSubmittedAt` 阻止第二键失败后的重复追加；主线复核确认聚合 `updatedAt` 不是首次答题事实，而且单一时间标记会漏掉再次降级后写入旧累计键的新答题，因此未原样采用。
- `QuizLearningState` 新增向前兼容的可选 `legacyHistorySnapshot`，记录旧来源的整体题数、正确数、各精确课程/Topic 累计高水位，以及旧版最多 20 条结果窗口的有序唯一 ID；不提升全局 schema 12 或 quiz state schema 2，旧 JSON 缺少整个快照时仍按首轮迁移处理。
- 首次迁移继续按已核验时间边界执行全量追加或较大快照采用；pending 的真实最早时间参与边界判断，但其数值在 aggregate 合并后单独回放，避免被 max 吞掉或被 append 双计。快照与合并统计在同一次 `quiz_learning_state` 写入；第一键失败时两者都不落盘，后续键失败时重入为零增量。
- 用户再次运行旧版时，以结果窗口相对上次有序 ID 的可证明完整新前缀作为新增答题唯一事实源。旧版停在 `quiz_results`、已写 `quiz_stats` 但未写 `topic_mastery`、或三键全部写完时，stats 与 Topic 均只补一次；原始 aggregate 只做单调性和窗口一致性校验，不再驱动二次统计。达到 20 条且无旧 ID 交集、顺序断裂、重复 ID、累计回退、增量超出新前缀或已合并 Topic 目标缺失时明确拒绝迁移。
- stats 或 Topic aggregate 结构/数值无效时不导入任何 aggregate 组件，也不写快照；任一未知课程/Topic 会使整组 aggregate 拒绝导入，existing 与无 unified state 两条路径不会把全局统计和过滤后的局部 Topic 混合。
- `firstSubmittedAt` 只从合法结果 `submittedAt`、Quiz 事件时间、Topic 实际练习时间和 pending 中取真实最早值；聚合更新时间只保留在审计快照中，不再冒充首次答题时间。Repository 清洗、Reducer 答题和 mastery 汇总均按解析后的时间戳比较，支持带时区偏移的合法 ISO 时间。
- 主线复核补足旧结果窗口的严格 marker 判定：只有 `quiz_stats.updatedAt` 和同一精确课程/Topic 的 `lastPracticedAt` 均与结果原始 `submittedAt` 完全匹配时，才将该结果视为已进入相应累计；marker 不在窗口则全部重放，marker 后仍出现更旧结果、物理写入顺序不明或同提交时间多重匹配均 fail-closed，避免把未证明的历史当作已累计。

### 文件

- `apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets`
- `apps/harmonyos/entry/src/main/ets/common/QuizLearningStateReducer.ets`
- `apps/harmonyos/entry/src/main/ets/model/LearningMetadataModels.ets`
- `apps/web/src/lib/data/quiz-learning-state.test.ts`
- `docs/workstreams/02-quiz-mastery-result.md`

### 验证

- **静态诊断通过**：`cd apps/web; pnpm exec vitest run src/lib/data/quiz-learning-state.test.ts`，exit 0，`78/78` 通过；覆盖第一键、第二键和 schema 版本键失败重入、旧版三个源键中断点、20 条无交集窗口、无效 aggregate、非法 Topic 两条迁移路径、损坏/回退快照、Topic 三类回退、pending、带时区首答时间及连续仅写 `quiz_results` 的完整回放/marker 边界拒绝。
- **静态诊断通过**：独立内存变异确认删除 delta、改回 max/replace、删除快照写入、静默吞掉全局/Topic 回退或移除旧结果首答时间合并都会使对应反例变红。
- **静态诊断通过**：`cd apps/web; pnpm lint`、`pnpm typecheck`，exit 0；`pnpm test` 为 36 个文件、`453/453` 通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 14.2.18 生产构建完成，10/10 静态页面和 26.8 kB middleware 进入产物。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon --incremental`，exit 0，API 12 CompileArkTS、PackageHap 与 PackingCheck 通过，`BUILD SUCCESSFUL in 49 s 34 ms`；项目未配置正式签名。
- **源码确认**：`hdc list targets -v`，exit 0，`127.0.0.1:5555 / TCP / Connected / localhost / hdc`。
- **模拟器通过**：在 `127.0.0.1:5555` 对本批 HAP 执行 `install -r`、`aa force-stop com.c4ai.hormony`、`aa start -a EntryAbility -b com.c4ai.hormony` 均 exit 0；`uitest dumpLayout` 返回 `pages/Index`，可见“鸿学伴”节点 bounds 为 `[56,328][372,451]`。

### 未验证

- **未验证**：本批使用可执行 ArkData 内存 fixture 注入三处写失败、旧版源键中断、损坏快照和累计回退，没有修改或清除模拟器真实用户数据库；安装启动和首页 UI 树通过不等于设备迁移故障流程通过。
- **未验证**：未调用线上 Quiz、Agent 或模型，不声明线上题组生成、提交或业务字段通过；已知不可用模型 Provider 未重试，也未回落 `openai/*`。
- **未验证**：正式签名、真机、多设备、横屏与平板未验证。

## 2026-07-22 主线：迟到答题不回退较新复习状态

### 背景与行为变化

- 首次 pending 写入失败后，另一页面可能先成功写入较新复习结果，旧页面随后沿用冻结的 `submittedAt` 重试。旧 reducer 会正确累计两次事实，却会把 Topic/标签最近时间以及错题题面、难度、间隔和下次复习时间回退到迟到结果。
- Topic 掌握与标签洞察继续累计所有已验证结果，但最近时间与最近难度只接受不早于当前快照的结果。错题收到早于当前 `updatedAt` 的结果时只增加尝试次数，不覆盖较新的题面、答案、解析、难度、解决状态、间隔和下次复习时间。
- 可执行 Repository fixture 覆盖“初始错题 -> 旧提交首次写失败 -> 较新正确复习成功 -> 旧提交重试”完整顺序，锁定累计不丢失且当前复习状态保持单调。

### 文件

- `apps/harmonyos/entry/src/main/ets/common/QuizLearningStateReducer.ets`
- `apps/web/src/lib/data/quiz-learning-state.test.ts`
- `docs/workstreams/02-quiz-mastery-result.md`

### 未验证

- **未验证**：本批不修改或清除设备真实用户数据库，跨页面乱序提交由动态 ArkData fixture 验证；模拟器双页面并发复现、正式签名、真机和多设备仍未验证。
- **未验证**：未调用线上 Quiz、Agent 或模型；已知不可用模型 Provider 未重试，也未回落 `openai/*`。
