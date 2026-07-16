# WS03 课程内容与主动学习结果

更新时间：2026-07-17

## 目标

把现有 33 个 Topic、147 个知识切片、165 道精选题和 33 个 Lesson experience 组织成可继续、可互动、可获得确定反馈并能进入下一步的 HarmonyOS 原生学习路径。首条验收路径固定为 `cs101 / 数组与线性表`。

## 批次一：Lesson 数据闭环契约

### 行为

- `LearningActivity` 新增必填 `focusTag`，由同 Topic `quizzes.json` 的首标签生成，不维护第二份映射。
- Lesson 的“同标签测验”精确传递 `activity.focusTag`；`数组与线性表` 传递 `线性表操作`，Quiz 不再收到活动标题 `输出预测`。
- 为 6 个计算机网络自由回答活动补入规格中已有的最终状态作为标准答案。
- 过滤 HTTP 请求/响应示例中的空白步骤，保留非空代码行原始缩进。
- 旧 7 个 Lesson experience 的模糊迁移来源替换为对应教材来源与知识切片 ID；不执行任意用户代码。
- Topic 关系校验扩展为 Course -> Topic -> Lesson -> 互动 -> 聚焦测验/本地 Practice 数据契约，并新增 11 项零依赖单测。

### 文件

- `apps/harmonyos/entry/src/main/ets/model/DataModels.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `docs/ACTIVE-LEARNING-SPEC-CS103.md`
- `docs/LEARNING-ACTIVITY-V2.md`
- `scripts/generate-learning-activities.mjs`
- `scripts/validate-topic-relations.py`
- `scripts/test_validate_topic_relations.py`

### 证据

- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；生成 33 个 experience、59 个活动。
- **静态诊断通过**：`python -m unittest scripts/test_validate_topic_relations.py`，退出码 0；11 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 32 s 438 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：本批尚未安装到模拟器，未证明课程点击路径和页面视觉表现。
- **未验证**：手机与平板布局、真机、线上聚焦测验请求。

## 批次二：课程入口与主题路径收敛

### 行为

- 课程列表每门课程只保留一个主动作，按本地进度显示“进入课程”或“继续课程”；移除脱离 Topic 上下文的课程级出题入口。
- 课程主题预览最多显示 3 个标签，剩余数量以 `+N` 表示，避免标签挤占课程扫描空间。
- 课程详情移除重复的三步说明卡和每个 Topic 下并列的学习、练习、测验按钮；每个 Topic 收敛为一整行原生按钮，直接进入对应 Lesson。
- 课程详情从本地学习事件计算已完成 Topic 数，标出首个未完成 Topic，并用“开始 / 继续 / 复习 / 预览”表达真实状态。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Course.ets`
- `apps/harmonyos/entry/src/main/ets/pages/CourseDetail.ets`

### 证据

- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 27 s 777 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- 从仓库根目录调用 `apps\harmonyos\hvigorw.bat assembleHap --no-daemon` 时，Hvigor 在错误目录查找配置并以退出码 124、`00304004` 结束；切换到 `apps/harmonyos` 后验证通过。
- 切换目录后的第一次工具调用因 5 秒调用超时以退出码 124 结束；随后使用足够超时时间完整重跑并构建通过。
- **未验证**：本批尚无模拟器 UI 树或点击证据；手机与平板布局、真机均未验证。
