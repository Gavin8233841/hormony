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
