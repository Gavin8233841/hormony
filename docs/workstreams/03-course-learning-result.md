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

## 批次三：Lesson 概念推演与可信反馈

### 行为

- 把一次性平铺的概念流程改成固定高度步骤行：只揭示当前及已完成步骤，单一主动作逐步对照下一环，最后可重新推演。
- 代码活动明确标注为课程固定示例和只读状态演算；只展示给定步骤，不执行输入内容，也不连接代码沙盒。
- 互动反馈拆为“你的回答 / 参考答案 / 对照重点”，客观题保留确定判定，自由回答只允许选择“关键点有遗漏 / 关键点已覆盖”。
- 自由回答以 `lesson_self_assessment` 标记本次自我对照，且不写入客观题数量、正确数和正确率；仓储 reducer 的排除规则留待 WS02 在其独占文件中集成。客观互动记录补入精确 `focusTag`，与后续同标签测验一致。
- 同标签测验只接受当前课程的精确 Topic；非法或空 Topic 显示错误并停止导航，不再回退为“综合”。
- 保存提示只陈述本次互动结果，不再把单次自评描述为掌握证明。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`

### 证据

- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；Lesson、聚焦标签和本地 Practice 契约全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，最终退出码 0；`BUILD SUCCESSFUL in 24 s 41 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：概念步骤切换、自由回答自评、客观互动反馈及同标签测验尚无模拟器 UI 树和点击证据。
- **未验证**：WS02 尚未集成 `lesson_self_assessment` 的 reducer 排除规则，当前不能把标签洞察隔离标记为通过。
- **未验证**：手机与平板视觉布局、真机均未验证。

## 批次四：真实 Lesson 断点续学

### 行为

- 新增无 I/O 的 `CourseResumeState` 纯函数，只从 `LessonProgress.completedChunkIds`、`completedAt` 和 `updatedAt` 推导已开始、已完成及最近未完成 Topic；外课程、未知 Topic 与空断点被忽略。
- 课程列表在聚合进度仍为 0、但已有真实 Lesson 断点时显示“继续课程”，并显示“上次学到 · Topic”。
- 课程详情把 `completedAt` 与既有完成事件合并，优先把最近更新的未完成 Topic 作为下一步；所有已开始但未完成的 Topic 显示“继续”。
- 未读取或写入种子进度，未修改 WS02 独占的仓储实现。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/CourseResumeState.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Course.ets`
- `apps/harmonyos/entry/src/main/ets/pages/CourseDetail.ets`

### 证据

- **源码确认**：续学推导为纯函数，输入仅为当前课程 ID、真实 Topic 列表与 `LessonProgress[]`。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic 与完整 Lesson 路径契约通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 26 s 651 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：尚无模拟器证据证明“完成一个知识切片后退出 → 课程显示继续 → 返回最近 Topic”的运行路径。
- **未验证**：手机与平板布局、真机均未验证。

## 批次五：知识星图方向与局部行动

### 行为

- `MapEdge` 增加精确 `fromId/toId` 和三点箭头几何，边从前置节点指向后继节点；选中节点的入边与出边使用不同强调色。
- 选中 Topic 后只高亮当前、直接前置和直接后继，淡化无关节点与边，并给一跳节点标出“前置 / 后继”。
- 删除星点和大面积装饰圆，只保留层级、关系边和学习状态等有信息含义的视觉元素。
- 详情移除并列的“学习主题 / 主题练习”按钮，改为一个由真实解锁、Lesson 完成和客观练习状态决定的下一步动作。
- 锁定节点会沿已校验 DAG 回溯到实际可进入的最早未完成前置；已掌握节点优先进入可解锁后继，没有后继时回到本 Topic 复习。
- 逐段复核 `dad2d67`、`7693a6d`、`2857f6c` 的边 ID、箭头与一跳聚焦实现，只手工吸收适配当前动态画布与解锁语义的部分，未整体移植、未增加依赖或资源。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets`

### 证据

- **源码确认**：Topic 关系边包含源/目标 ID、箭头坐标、一跳聚焦与 DAG 前置回溯；装饰星点和圆形光斑已移除。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic 唯一、引用完整、DAG、连通性、层级与内容一致性全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 31 s 818 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：`C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe list targets` 退出码 0，但输出 `[Empty]`；无可用模拟器或设备。
- **未验证**：箭头实际渲染、横向滚动、节点局部聚焦、手机与平板布局、真机均未验证。
