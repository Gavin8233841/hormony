# LearningActivity v2 数据契约

更新时间：2026-07-02

## 目标

端侧课程继续保持离线、确定性和零第三方依赖。学习活动只支持代码阅读、步骤排序、状态推演和输出预测；不执行用户输入的任意代码。

## LessonExperience v2

每个 Topic 对应一个 `LessonExperience`：

- `schemaVersion`: 固定为 `2`
- `courseId`、`topic`: 必须与 `knowledge-chunks.json` 的精确值一致
- `visualTitle`、`visualSteps`: 首屏概念路径，步骤不超过 4 个
- `caseTitle`、`caseBody`: 现实案例
- `workedExampleTitle`、`workedExampleSteps`: 分步示例
- `activities`: 1 至 2 个主动学习活动

## LearningActivity v2

- `id`: Topic 内唯一标识
- `type`: `code_fill`、`step_order`、`state_trace`、`output_predict`
- `title`、`prompt`: 活动标题和用户任务
- `focusTag`: 同 Topic 精选题库中真实存在的首标签，最多 12 个 UTF-16 码元；Lesson 用它进入聚焦测验
- `content`、`language`: 代码、状态或场景材料及其显示标签
- `interactionMode`:
  - `single_choice`: 单选并立即反馈
  - `ordered_choice`: 依次点击步骤卡片形成顺序
  - `free_response`: 用户先写出答案，再对照标准答案自评
- `options`: 选择项；自由作答时为空数组
- `answerIndexes`: 单选或排序的正确索引；自由作答时为空数组
- `answer`: 非空、可读的标准答案；自由作答也必须能在提交后获得确定反馈
- `feedback`: 技术解释与纠错反馈
- `source`: 教材、标准或知识切片来源

## 生成与校验

运行：

```powershell
node scripts/generate-learning-activities.mjs
```

脚本从三份 `ACTIVE-LEARNING-SPEC-*.md` 转换 26 个 Topic，并迁移现有 7 个体验。`focusTag` 从同 Topic 的 `quizzes.json` 首标签生成，不另建标签映射。生成前后强制校验 33 个 Topic 全覆盖、52 个新增活动、练习类型枚举、标准答案、步骤排序答案完整性，以及 Topic 与端侧知识切片和题库标签的一致性。

Trae 验证报告中的类型分布统计不正确。三份规格正文的实际分布为：`code_fill 13`、`step_order 16`、`state_trace 17`、`output_predict 6`，合计 52。验证报告把 `state_trace` 多计了 1；cs101 规格附录还把该课程的 `code_fill` 多计 1、`output_predict` 少计 1。生成脚本以每个活动正文中的 `类型` 字段为准并自动统计。
