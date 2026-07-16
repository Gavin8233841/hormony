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
