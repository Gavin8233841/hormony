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

## 批次六：Lesson 互动断点恢复

### 行为

- Lesson 进入时读取现有本机学习事件，只接纳同课程、同 Topic 且 `taskId` 属于当前 experience 的 `lesson_activity`。
- 去重恢复已完成互动 ID，并自动定位首个未完成互动；全部已有记录时定位最后一项，允许直接完成 Topic 后进入 Practice。
- 互动事件读取失败不阻断知识内容和 Lesson 进度读取，页面显示精确的断点读取失败信息。
- 仅修改 Lesson 页面消费逻辑，未修改 WS02 独占仓储。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`

### 证据

- **源码确认**：互动恢复同时校验 `type/courseId/topic/taskId`，不把其他课程或旧 experience 事件混入当前 Lesson。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 个 experience 的活动 ID、答案与路径契约通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 27 s 566 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：尚无模拟器证据证明“完成部分互动后退出 → 重进 Lesson 自动定位下一互动”。
- **未验证**：真机未验证。

## 批次七：课程资料检索到精确 Topic

### 行为

- 删除把任意检索词写入 `selectedQuizTopic` 的入口；资料结果只有在 `topic` 与当前课程 Topic 清单逐字一致时才显示“进入主题”，并写入 `selectedContentTopic` 后进入 Lesson。
- 云端结果必须带当前课程的精确 `courseId`，同时过滤空正文、空来源和其他课程结果，最多展示 5 条；无有效云端结果时继续使用真实本地课程切片，不构造静态假回复。
- 没有精确 Topic 的资料不提供 Lesson 或 Quiz 导航，但仍可把来源与原资料关键句带入学伴追问，形成可执行的解释、举例和主动回忆路径。
- 每条结果按来源、相关度、精确 Topic、关键句、全文展开和下一步动作组织；有 Topic 时以 Lesson 为主动作、学伴为次动作，无 Topic 时只保留学伴解释；空结果不再显示成功勾选。
- 建议词改为可换行布局；底部安全区从搜索栏下方移动到骨架、结果列表和空态的实际底部，避免顶部无意义留白并保护末项操作。
- 新增 4 项页面契约测试，约束搜索词防污染、精确 Topic 守卫、无 Topic 追问和云端结果过滤。测试由并行子 agent 在独立文件内实现，主代理逐项复核并独立重跑后采用。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Knowledge.ets`
- `scripts/test_knowledge_navigation_contract.py`

### 证据

- **源码确认**：Knowledge 不再写入 `selectedQuizTopic`，Lesson 入口只写经过当前课程 Topic 清单验证的 `selectedContentTopic`；无 Topic 分支只进入 Chat。
- **静态诊断通过**：`python -m unittest scripts/test_knowledge_navigation_contract.py scripts/test_validate_topic_relations.py`，退出码 0；15 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 22 s 525 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：`C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe list targets` 退出码 0，输出 `[Empty]`；当前无可用模拟器或设备。
- **未验证**：检索结果展开、Lesson/Chat 跳转、手机和平板布局、真机和线上检索业务字段均未验证。

## 批次八：真实 Lesson 断点续学契约

### 行为

- 新增 4 项 Course/CourseDetail 页面契约测试，固定 `LessonProgress.completedChunkIds/updatedAt/completedAt` 到续学状态和 CTA 的语义，防止聚合 `course.progress` 为 0 时再次退化成“未开始”。
- 约束续学纯函数忽略外课程、未知 Topic 和空断点，最近未完成 Topic 按真实 `updatedAt` 选择，已完成 Topic 从 `completedAt` 合并。
- 约束课程列表调用无筛选的 `getLessonProgress()` 为各课程生成“继续课程 / 上次学到”，课程详情调用 `getLessonProgress(this.courseId)` 生成最近 Topic 和“继续”状态。
- 测试不写数据库、不构造产品种子状态，也未修改 WS02 独占的 `LocalLearningRepository.ets`。

### 文件

- `scripts/test_course_resume_contract.py`

### 证据

- **静态诊断通过**：`python -m unittest scripts/test_course_resume_contract.py scripts/test_knowledge_navigation_contract.py scripts/test_validate_topic_relations.py`，退出码 0；19 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **构建通过**：本批未改应用源码；同一应用源码已在批次七由增量 HAP 构建通过，`BUILD SUCCESSFUL in 22 s 525 ms`。

### 未验证

- **未验证**：当前 `hdc list targets` 仍为 `[Empty]`，尚无“完成部分切片后退出 → 课程显示继续 → 返回最近 Topic”的模拟器、手机、平板或真机证据。

## 批次九：Lesson 首个未完成互动定位

### 行为

- Lesson 进入时先清空上一 Topic 的知识切片完成态、互动索引、已练 ID、答案、反馈和演算临时状态，再读取当前 Topic 的真实 `LessonProgress` 与学习事件，避免异步恢复期间串入旧页面状态。
- 事件恢复继续只接纳 `lesson_activity`、同课程、同 Topic 且 `taskId` 属于当前 experience 的记录；去重后定位首个未完成互动，并在索引切换后清空上一互动的选择、文本和反馈。
- 最后一段知识切片仍有未完成互动时，底部唯一主动作从不可执行的“完成互动练习后继续”改为精确的“继续互动 N/M”。点击后使用互动卡 `onAreaChange` 的实际位置滚动到当前互动，位置尚未就绪时按当前视口向下翻页，不写死设备坐标。
- 全部互动完成后主动作才恢复为“完成主题并练习”；同标签测验仍保留 `c9572d2` 的当前课程精确 Topic 守卫。
- 新增 5 项 Lesson 恢复页面契约测试；其中 4 项由并行子 agent 在独立文件实现，主代理复核后补入临时状态清零和 CTA 定位契约。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`
- `scripts/test_lesson_activity_resume_contract.py`

### 证据

- **源码确认**：HarmonyOS API 12 SDK 声明包含 `CommonAttribute.onAreaChange` 与 `Scroller.scrollTo/scrollPage`；实现使用实际布局位置，不依赖固定屏幕坐标。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_validate_topic_relations -v`，退出码 0；24 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 39 s 99 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：`C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe list targets` 退出码 0，输出 `[Empty]`；当前无可用模拟器或设备。
- **未验证**：底部 CTA 到互动卡的实际滚动位置、手机和平板布局、真机恢复流程均未验证。

## 批次十：Knowledge 检索证据解释

### 行为

- Knowledge 不再把固定首句统一标为“关键句”；新增确定性证据选择器，依次查找完整检索词、空格分隔的有效检索词项、当前课程精确 Topic，均未命中时才明确降级为“课程资料摘要”。
- 命中句按句号、分号、问号、叹号和换行拆分，选择第一条大小写归一化命中；长句围绕实际命中位置截取上下文，不使用随机片段。
- 结果卡以“检索词命中 / Topic 关联 / 课程资料摘要”标注依据；“问学伴”复用同一个 `KnowledgeEvidence` 的标签和片段，避免卡片与追问携带不同证据。
- 当前结果使用提交检索时保存的 `resultQuery`。用户只编辑输入框、尚未重新检索时，不会改写旧结果的依据和学伴追问上下文。
- 未修改 Web API、RAG 评分、知识切片或依赖；结果仍限定当前课程，并继续保留精确 Topic 的 Lesson 守卫。
- 并行子 agent 将既有 Knowledge 页面契约从 4 项扩展为 6 项，主代理补入 `resultQuery` 快照契约并独立重跑。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Knowledge.ets`
- `scripts/test_knowledge_navigation_contract.py`

### 证据

- **源码确认**：结果卡与 Chat 均调用 `evidenceFor(item)`；证据选择顺序和三种标签由页面契约固定，且无随机分支。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_validate_topic_relations -v`，退出码 0；26 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 26 s 96 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无可用模拟器或设备，证据标签、长句截取与输入框修改后的实际页面表现未验证。
- **未验证**：线上 Knowledge 响应及业务字段未验证；本批未修改 Web API。

## 批次十一：课程主动学习闭环契约

### 行为

- 新增 5 项页面契约，按方法边界固定 CourseDetail 写入课程与精确 Topic 后进入 Lesson、Lesson 读取同一上下文、互动进入同 Topic/同标签 Quiz、互动原题与作答进入 Chat、完成主题进入同 Topic 本地 Practice 的完整路径。
- Quiz 契约继续固定 `c9572d2` 引入的精确 Topic 防污染守卫，并验证 `selectedQuizFocusTag` 被消费后清空且真实写入 `QuizRequest.focusTag`，避免“同标签测验”退化成只显示标签。
- 新增 5 项自评证据边界契约：Lesson 的 `lesson_self_assessment` 不携带 `accuracy/totalQuestions/correctCount`，客观 `lesson_interactive` 继续携带完整计分字段，互动参与成就与 `quiz_mastered` 客观掌握分离。
- WS02 独占的 `getTagInsights` 当前仍以 `totalQuestions ?? 1`、`correctCount ?? 0` 消费全部 `lesson_activity`；目标 reducer 契约以 `expected failure` 保留，等待 WS02 只接纳来源明确且字段完整的客观互动。本批未修改 `LocalLearningRepository.ets`。
- 自评边界测试由并行子 agent 在独立文件实现；主代理逐项复核，修正为可持续执行的跨工作流预期失败，并补齐课程闭环测试。

### 文件

- `scripts/test_course_learning_path_contract.py`
- `scripts/test_lesson_self_assessment_boundary.py`

### 证据

- **源码确认**：`CourseDetail.openTopic`、`Lesson.openFocusedQuizForActivity/askTutorForActivity/openPractice`、Quiz/Chat/Practice 消费方由同一组精确 AppStorage 键和路由目标连接；`Quiz.generateQuiz` 将非空 `focusTag` 写入请求。
- **静态诊断通过**：`python -m unittest scripts.test_course_learning_path_contract scripts.test_lesson_self_assessment_boundary -v`，退出码 0；10 项运行，9 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_course_learning_path_contract scripts.test_lesson_self_assessment_boundary scripts.test_validate_topic_relations -v`，退出码 0；36 项运行，35 项通过，1 项预期失败。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与同 Topic 标签门禁全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 4 s 396 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：WS02 尚未修改 `getTagInsights`，自评事件仍会被该标签洞察 reducer 误作 1 道错题；目标契约明确保留为预期失败。
- **未验证**：无模拟器、手机、平板或真机证据证明 Course → Topic → Lesson → 互动 → Quiz/Chat/Practice 的实际点击与返回流程。

## 批次十二：Lesson 标签与来源随题追问

### 行为

- 主动练习在题干前直接显示受控 `focusTag`，让学员在作答前知道本练验证的概念，随后“同标签测验”继续使用同一字段；采用单行信息层级，没有新增嵌套卡片或装饰动效。
- “问学伴讲解”把 Topic、专项标签、个人回答、参考答案与反馈区展示的同一 `source` 一并写入 `pendingChatQuestion`，避免跨页后丢失资料依据或标签目标。
- 新增长文本摘录和总长守卫：题干、自由回答、参考答案与来源分别限长，最终问题不超过 1800 字，低于 `/api/chat` 源码确认的 2000 字请求上限。
- 保留精确 Topic 和同标签 Quiz 路由语义；未修改 Web API、共享仓储或原始学习内容。
- 按仓库 `impeccable` 产品 UI 规范复核信息层级：复用现有色彩令牌、系统字体和稳定单行布局，不新增依赖。

### 文件

- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`
- `scripts/test_course_learning_path_contract.py`

### 证据

- **源码确认**：33 个 experience 共 59 个活动，`source` 空值为 0；Lesson 反馈区和学伴问题共用 `activity.source`，活动标签显示与 Quiz 路由共用 `activity.focusTag`。
- **源码确认**：`apps/web/src/app/api/chat/route.ts` 明确拒绝长度大于 2000 的 `message`；Lesson 端最终守卫为 1800。
- **静态诊断通过**：`python -m unittest scripts.test_course_learning_path_contract -v`，退出码 0；6 项通过。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_course_learning_path_contract scripts.test_lesson_self_assessment_boundary scripts.test_validate_topic_relations -v`，退出码 0；37 项运行，36 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与同 Topic 标签门禁全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；ArkTS 重新编译，`BUILD SUCCESSFUL in 20 s 238 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：`hdc list targets` 输出 `[Empty]`；“本练聚焦”在手机和平板的实际单行渲染、超长回答跳转 Chat、返回 Lesson 与完整点击路径均无模拟器或真机证据。
- **未验证**：学伴线上响应及引用业务字段；本批未调用线上 Chat，也未修改 Web API。

## 批次十三：Dijkstra 有向边事实修正

### 行为

- 修正“最短路径算法”主动练习 1：题面声明 `A→C`，旧答案却从 C 反向松弛 A 并构造不存在的 `S→B→C→A`。现按有向边方向得到 A=7、C=5，并明确 C 无出边、A→C 的候选距离 8 不会更新 C。
- 只修改唯一源规格 `ACTIVE-LEARNING-SPEC-CS101.md`，随后运行既有 `generate-learning-activities.mjs` 生成端侧产物；JSON 仅改变该活动的 `answer/feedback`，其他 58 个活动未变化。
- 内容校验器新增有向带权图路径门禁：从题干提取声明边，答案和反馈中使用箭头表示的每段路径都必须由已声明的同向边组成；不会执行题目代码或用户输入。
- 新增正反两项单测，分别证明反向使用 `C→A` 被拒绝、由 `S→B` 和 `B→C` 组成的路径被接受。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS101.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/validate-topic-relations.py`
- `scripts/test_validate_topic_relations.py`

### 证据

- **源码确认**：题面只声明 `S→A`、`S→B`、`B→A`、`B→C`、`A→C`；知识切片 `cs101_k27` 明确 Dijkstra 每轮用当前顶点更新其邻接顶点，旧路径中的 `C→A` 不存在。
- **源码确认**：在重新生成前运行 `python scripts/validate-topic-relations.py`，退出码 1，唯一新增错误为 `directed path "S→B→C→A" uses undeclared edge "C→A"`，证明门禁先复现旧事实错误；该次命令不是通过证据。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；生成 33/33 Topic、59 个活动，52 个规格活动类型分布保持不变。
- **静态诊断通过**：`python -m unittest scripts.test_validate_topic_relations -v`，退出码 0；13 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与有向路径门禁全部通过，`ALL CHECKS PASSED`。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_course_learning_path_contract scripts.test_lesson_self_assessment_boundary scripts.test_validate_topic_relations -v`，退出码 0；39 项运行，38 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；内容资源与 ArkTS 重新编译，`BUILD SUCCESSFUL in 19 s 171 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器或真机证据检查修正后的答案、反馈换行和滚动显示。
- **未验证**：本批没有逐题外部资料核验其他 58 个活动；门禁只证明显式有向路径使用题面声明边，不等同全量事实审校。

## 批次十四：红黑树根节点不变量补全

### 行为

- 修正 `cs101-AVL树与红黑树-2` 的叔父为红插入修复顺序：原序列在祖父为根时会以红根结束，现增加循环结束后把根重新着色为黑色的最终步骤。
- 正确顺序由 `C → B → E → A → D` 补全为 `C → B → E → A → D → F`；反馈明确区分本轮叔父为红的变色传播和整个修复循环结束后的根节点收尾。
- 只修改唯一源规格 `ACTIVE-LEARNING-SPEC-CS101.md`，随后由既有生成器同步端侧 JSON；未修改知识切片、共享仓储或页面。
- 新增真实内容契约，按精确活动 ID 读取生成产物，并与 `cs101_k20` 的“根为黑”性质及源规格最终步骤交叉校验。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS101.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：知识切片 `cs101_k20` 明确要求根为黑；旧顺序先把祖父设为红再向上检查，却没有 CLRS 插入修复循环结束时强制根为黑的步骤。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；生成 33/33 Topic、59 个活动，52 个规格活动类型分布保持不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts scripts.test_validate_topic_relations -v`，退出码 0；15 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过，`ALL CHECKS PASSED`。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_course_learning_path_contract scripts.test_lesson_self_assessment_boundary scripts.test_validate_topic_relations scripts.test_lesson_content_facts -v`，退出码 0；41 项运行，40 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 19 s 259 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：`hdc list targets` 输出 `[Empty]`；增加第六个排序步骤后的手机/平板布局、拖动排序与反馈滚动没有模拟器或真机证据。

## 批次十五：日志崩溃恢复顺序修正

### 行为

- 修正 `cs102-文件系统-2` 将正常 checkpoint、日志回收与后续崩溃重放串成错误单一路径的问题；旧顺序在日志已回收后才执行“重放未 checkpoint 事务”，前后条件矛盾。
- 题设现明确为元数据日志已 commit、尚未 checkpoint 时崩溃，唯一顺序为 `B → D → E → C → A → F`：先预写并提交，随后发生崩溃并识别已提交事务，再重放到实际位置，最后标记 checkpoint 并允许回收。
- 由唯一源规格生成端侧 JSON；新增真实产物契约，与知识切片 `cs102_k28` 的 WAL 先日志后实际位置语义交叉校验。
- 并行子 agent 完成 CS102 全 16 个活动的可执行审计；主代理逐项复核后只采用本活动，其余修订继续隔离，未并入本提交。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：`cs102_k28` 明确元数据修改先写日志再应用到实际位置，并在崩溃后重放日志；修订后的每一步均满足该依赖。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；生成 33/33 Topic、59 个活动，类型分布保持不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts -v`，退出码 0；3 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_course_learning_path_contract scripts.test_lesson_self_assessment_boundary scripts.test_validate_topic_relations scripts.test_lesson_content_facts -v`，退出码 0；42 项运行，41 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 19 s 477 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前设备列表仍为空；六步排序的拖动、提交反馈和长文本滚动没有模拟器、手机、平板或真机证据。

## 批次十六：UDP 与 IP 封装术语修正

### 行为

- 修正 `cs103-OSI与TCP/IP模型-2` 把添加 UDP 首部后的 PDU 统称为 Segment 的问题；现明确推演 `Message → UDP Datagram → IP Datagram → Frame → Bits`。
- 删除“DNS 使用 UDP 而非 TCP”的错误绝对化表述；题面只证明本次查询使用 UDP，反馈补充 RFC 7766 对通用 DNS 实现同时支持 UDP 与 TCP 的要求。
- 来源增加 RFC 7766，生成产物与唯一源规格同步；契约同时固定 UDP/IP 两层术语、禁止旧错误句回归并校验 RFC 引用。
- 修订来自并行 CS103 全活动事实审计，主代理复核 RFC 768、RFC 7766 原文后独立采用本活动；同文件 TCP Reno 差异未并入本提交。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS103.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：RFC 768 使用 User Datagram 术语；RFC 7766 明确写明通用 DNS 实现 `MUST support both UDP and TCP transport`；本题操作序列明确添加 UDP 首部后再添加 IP 首部。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts -v`，退出码 0；4 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_course_learning_path_contract scripts.test_lesson_self_assessment_boundary scripts.test_validate_topic_relations scripts.test_lesson_content_facts -v`，退出码 0；43 项运行，42 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 4 s 47 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前没有模拟器或真机；修订后的英文协议术语换行、长答案滚动及手机/平板显示未验证。

## 批次十七：TCP Reno 快恢复状态机修正

### 行为

- 修正同 Topic 逐步示例和两项活动把第 3 个重复 ACK 到达时的 `cwnd` 直接设为 `ssthresh` 的错误；RFC 5681 要求先临时膨胀为 `ssthresh+3 MSS`，确认重传数据的新 ACK 到达时再收缩到 `ssthresh`。
- 状态推演补全中间态：`FlightSize=18 MSS` 时得到 `ssthresh=9 MSS`、快恢复入口 `cwnd=12 MSS`，新 ACK 后回落为 9 MSS，再经一个拥塞避免 RTT 得到最终 10 MSS。
- 同步修正 Web 与 HarmonyOS 的 `cs103_k22/k23`，来源改为 RFC 5681；规格知识摘要、逐步示例、自由推演和步骤排序不再互相矛盾。
- 新增跨端逐字一致性与真实活动契约，固定入口膨胀、额外重复 ACK、退出收缩及最终答案。

### 文件

- `apps/web/src/lib/data/cs103-knowledge.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`
- `docs/ACTIVE-LEARNING-SPEC-CS103.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：RFC 5681 第 3.2 节步骤 3 要求重传后将 `cwnd` 设为 `ssthresh plus 3*SMSS`，步骤 6 要求确认新数据的 ACK 到达时将 `cwnd` 设回 `ssthresh`。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts -v`，退出码 0；5 项通过，且 `cs103_k22/k23` 的 Web 与端侧字段逐字一致。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；44 项运行，43 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`cd apps/web; pnpm lint`、`pnpm typecheck`，退出码均为 0；无 lint 或 TypeScript 错误。
- **静态诊断通过**：`cd apps/web; pnpm test`，退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：`cd apps/web; pnpm build`，退出码 0；Next.js 生产构建成功并生成 10/10 静态页面。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 31 s 135 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器或真机；逐步示例、中间窗口状态、两项活动反馈的手机/平板实际显示与滚动未验证。
- **未验证**：本批未调用线上 API，不构成线上内容检索或学伴回答证据。

## 批次十八：Dijkstra 精确可执行事实契约

### 行为

- 移除 `validate-topic-relations.py` 的通用自然语言箭头正则；该规则会把“不存在路径 C→A”等否定说明当成事实路径，也只能识别一种权重排版，不适合作为全部课程内容门禁。
- 将 Dijkstra 事实校验收敛到精确活动 `cs101-最短路径算法-1`：从真实题面解析 5 条有向带权边和源点，使用优先队列执行 Dijkstra，再比对每轮定型距离、松弛的有向边与权重、全部出边覆盖和最终距离字典。
- 新增旧错误答案 fixture：从 C 松弛 A 会明确得到 `relaxes undeclared directed edge C→A`，同时检出 A 以 6 错误定型及最终距离不匹配；当前生成活动作为正确 fixture 返回空错误集并固定 A=7、C=5。
- 本批不修改或重新生成 `lesson-experiences.json`，不会覆盖并行保留的 CS102 内容差异。

### 文件

- `scripts/validate-topic-relations.py`
- `scripts/test_validate_topic_relations.py`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：活动题面声明 `S→A=10`、`S→B=3`、`B→A=4`、`B→C=2`、`A→C=1`；真实最短距离为 S=0、B=3、C=5、A=7。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts scripts.test_validate_topic_relations -v`，退出码 0；18 项通过，包含错误 fixture 红灯断言和当前活动绿灯断言。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与结构关系契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；44 项运行，43 项通过，1 项跨 WS02 reducer 契约为预期失败。

### 失败与未验证

- 首次目标测试退出码 1，5 项因新增函数插入位置使 `find_activity` 缺少返回值而报错；修正返回位置后同一命令退出码 0，18 项全部通过。
- **未验证**：本批只改校验与测试，没有改产品代码或资源，未重复执行 HAP、模拟器或真机验证；最近一次 HAP 构建证据属于前一 TCP Reno 批次。

## 批次十九：满缓冲区信号量死锁推演修正

### 行为

- 修正 `cs102-同步与互斥-1` 对消费者执行顺序的错误描述：消费者先执行 `P(full)` 并成功，随后才阻塞在已被生产者持有的 `mutex`，无法消费并释放 `empty`。
- 来源补入实际使用的 `cs102_k34`，使占有并等待的解释与引用闭合；保留 `cs102_k42` 对生产者/消费者正确 P 操作顺序的依据。
- 新增可执行信号量状态契约，从 `mutex=1, empty=0, full=2` 真实推进生产者与消费者的四次 wait，证明双方阻塞链及文案一致性。

### 证据

- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts -v`，退出码 0；8 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；45 项运行，44 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 4 s 462 ms`。

### 未验证

- **未验证**：当前无模拟器或真机；修订后的答案、反馈和来源长文本显示未验证。

## 批次二十：匿名管道 read 与 EOF 三阶段语义修正

### 行为

- 修正 `cs102-进程间通信-1` 把“父进程未关闭写端”误述为当前 `read` 一直阻塞的问题：管道中已有数据时本次读取立即返回；数据耗尽且仍有写端时后续读取等待；所有写端关闭后读取返回 `0`（EOF）。
- 补齐示例调用 `printf` 所需的 `#include <stdio.h>`，并把末句的阻塞条件限定为“缓冲区读空且仍有写端”，避免与 EOF 条件互相矛盾。
- 子 agent 交付管道契约初稿；主代理复核后将预期三阶段收口为固定常量，避免调用方通过传入错误预期绕过门禁。
- 契约从生成活动 `$[23].activities[0]` 唯一提取 `char msg[]`，用真实 `os.pipe`/非阻塞 `os.read` 依次观测 `data`、`would_block`、`eof`；错误状态 fixture 三项均红灯，当前活动与真实观测绿灯。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：POSIX.1-2024 `read()` 明确规定空管道仍有写端且未启用 `O_NONBLOCK` 时阻塞、启用时返回 `EAGAIN`，无任何写端时返回 `0`；已有数据的读取不由写端是否仍打开决定。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；33/33 Topic、59 个活动，类型分布不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts -v`，退出码 0；10 项通过。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_consistency_cs102 -v`，退出码 0；CS102 的 16 个活动共 5 项一致性门禁通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；47 项运行，46 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 16 s 348 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器、手机、平板或真机；修订后的代码块、反馈长文本换行和滚动未验证。

## 批次二十一：分段地址严格限长与同标签题一致性

### 行为

- 修正分段地址合法边界：段限长表示段长度时，合法段内偏移必须满足 `0 <= d < L`，`d == L` 已越界；活动反馈不再使用会漏掉等值边界的“超过段限长”。
- 同步修正同 Topic 逐步示例：`P × 4096 + D = 8202` 时，仅当段限长严格大于 `8202` 才合法，旧 `段限长 >= 8202` 会允许首个越界地址。
- 修正同标签题 `cs102_q52` 的解析，并由 Web 题库唯一源生成端侧 `quizzes.json`；Course→Lesson→同标签练习对边界条件使用同一表述。
- 子 agent 实现真实活动解析与边界执行：解析三条段表、逻辑段号/偏移，计算 `base + offset = 5100`；`offset == limit`、旧“超过段限长”和旧 `>= 8202` fixture 均红灯，当前活动、逐步示例、知识切片引用与题库解析绿灯。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `apps/web/src/lib/data/quizzes.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：生成活动 `$[18].workedExampleSteps[3]` 使用 `段限长 > 8202`，`$[18].activities[1].feedback` 明确 `d >= L` 越界；`cs102_q52` 端侧解析与 Web 唯一源逐字一致。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs`，退出码 0；165 道选择题与 Web 源一致。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；33/33 Topic、59 个活动，类型分布不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts scripts.test_lesson_content_consistency_cs102 -v`，退出码 0；17 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；49 项运行，48 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`cd apps/web; pnpm lint`、`pnpm typecheck`，退出码均为 0。
- **静态诊断通过**：`cd apps/web; pnpm test`，退出码 0；13 个测试文件、167 项通过。
- **构建通过**：`cd apps/web; pnpm build`，退出码 0；Next.js 生产构建成功并生成 10/10 静态页面。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 35 s 794 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- 子 agent 在旧生成内容上首次执行目标测试精准红灯，定位到逐步示例仍使用 `>= 8202`；生成后转绿。主代理随后一度把题库句式改成重复主语，目标测试退出码 1；收敛到契约精确句式并重新生成后，12 项内容事实测试全部通过。
- **未验证**：当前无模拟器、手机、平板或真机；逐步示例、活动反馈与题库解析在实际设备上的换行、滚动和同标签跳转未验证。

## 批次二十二：Socket 并发事件的可执行依赖顺序

### 行为

- 修正 `cs102-进程间通信-2` 把服务端 `accept()` 调用与客户端 `connect()` 发起强行排成错误顺序的问题；选项 A 现在明确表示“连接到达后 `accept()` 返回”，不再表示可能更早发生并阻塞的调用动作。
- 题面要求按必然先后依赖排序，答案收敛为 `B → C → E → G → A → F → D`：服务端创建/绑定/监听后，客户端发起连接，连接到达后 `accept` 返回新套接字，随后通信并关闭。
- 反馈保留并发事实：服务端可以先调用 `accept` 并阻塞，但 `accept` 返回必然晚于连接到达；学习者操作的是可判定事件依赖，而不是伪造的全局调用时间线。
- 子 agent 实现步骤契约：从 `answerIndexes` 还原 A-G，校验选项与索引完整无重复、答案逐字一致，并执行依赖边 `B→C→E→G→A→F→D`；旧顺序 fixture 仅因违反 `G→A` 精确红灯。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：POSIX.1-2024 `accept()` 从待处理连接队列取出首个连接并创建新套接字；`connect()` 发起连接。因此 `accept` 调用可以先阻塞，但本题定义的 `accept 返回` 必须在客户端发起并使连接到达之后。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；33/33 Topic、59 个活动，类型分布不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts scripts.test_lesson_content_consistency_cs102 -v`，退出码 0；19 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；51 项运行，50 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 18 s 607 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器、手机、平板或真机；七步排序的拖动、提交反馈和长文本滚动未验证。

## 批次二十三：Socket 监听队列因果补正

### 行为

- 修正 `cs102-进程间通信-2` 的并发事件排序缺口：旧 G 是“客户端调用 `connect()`”，但该调用可以在服务器 `listen()` 前开始，不能与连接成功到达监听套接字混为同一事件。
- 题面现限定“服务器端可观察事件”；G 是连接到达已监听套接字并进入待 `accept` 队列，A 是 `accept()` 从该队列取出连接并返回新套接字。因此 `E → G → A` 分别对应建立监听队列、连接进入待处理队列、从队列取出连接，均为可证明依赖。
- 答案继续使用 `B → C → E → G → A → F → D`；反馈明确说明 `connect()` 调用起始时刻不参与排序，避免把并发调用时间包装成唯一教学答案。
- 可执行契约精确锁定题面范围、A/G 事件、POSIX 来源、完整排列与逐边依赖；固定输入把 G 恢复为旧 `connect()` 调用描述时仅触发对应错误，把 G/A 颠倒时仅触发 pending queue 依赖错误。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：POSIX.1-2024 `listen()` 规定将连接型 socket 标记为接受连接并限制 listen queue；`connect()` 规定尝试建立连接，阻塞、非阻塞或信号中断路径允许连接异步完成；`accept()` 规定从 pending connection queue 取出首个连接并创建新 socket。三份官方页面本轮读取均返回 HTTP 200，且已核对上述业务正文。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts scripts.test_lesson_content_consistency_cs102 -v`，退出码 0；22 项通过。首次执行因未跟踪总审计脚本仍锁定旧 Socket 文案失败 2 项，更新该审计契约后同一命令转绿；该未跟踪脚本不纳入本提交。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；54 项运行，53 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 16 s 122 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器、手机、平板或真机；七步排序的拖动、提交反馈、长文本滚动和手机/平板布局未验证。

## 批次二十四：MLFQ 周期提升时点唯一化

### 行为

- 修正 `cs102-CPU调度算法-2` 的非唯一排序条件：priority boost 是系统周期事件，旧题面未说明本轮触发时点，步骤 D 可以在进程降到 Q2 前后多个位置出现。
- 题面现明确假设本轮提升发生在该进程已进入 Q2 并执行之后，因此 `B → C → E → A → D` 成为与题设一致的唯一依赖链；反馈与 `cs102_k09` 的防饥饿语义保持不变。
- 子 agent 新增可执行步骤契约：精确锁定五个选项，从 `answerIndexes` 还原 A-E 并逐字生成答案，执行 `B→C→E→A→D`，同时校验 `cs102_k09` 来源与切片元数据。
- 旧题面 fixture 仅因缺少提升时点红灯；把 D 提前到 A 之前的 fixture 仅因违反 `A→D` 红灯，避免用静态字符串假装证明顺序正确。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_facts.py`

### 证据

- **源码确认**：`cs102_k09` 只规定定期提升所有进程以防饥饿，并未规定提升必然发生在某次 Q2 执行之后；当前题面的显式假设提供了本题所需时点。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；33/33 Topic、59 个活动，类型分布不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_facts scripts.test_lesson_content_consistency_cs102 -v`，退出码 0；22 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；54 项运行，53 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 16 s 122 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器、手机、平板或真机；五步排序交互与题面长文本在实际设备上的显示未验证。

## 批次二十五：UDP 乱序推演与 QUIC 恢复语义校正

### 行为

- 修正 `cs103-UDP协议-2` 的自相矛盾推演：旧操作先让 D1 正常到达，再让 D3 到达，却把 `[D1,D3]` 称为乱序。当前流程明确 D1 在网络中延迟、D2 丢失、D3 先到、D1 后到，端侧操作轨迹、最终状态和答案统一为 `[D3,D1]`。
- 删除“标准 QUIC 通过前向纠错恢复”的错误表述。活动反馈与 `cs103_k26` 现依据 RFC 9000/9002 描述多路复用、确认与丢失检测、将丢失信息按需放入新帧发送及拥塞控制，并明确不把 FEC 定义为核心恢复机制。
- Web `cs103_k26` 与 HarmonyOS `knowledge-chunks.json` 同步为逐字一致内容，来源更新为“计算机网络：自顶向下方法；RFC 9000/9002”，避免 Lesson 正文修正后离线检索仍返回旧事实。
- 子 agent 修正 CS103 规格并建立当前绿灯/旧文案红灯契约；主代理复核官方标准后补充 Web/端侧切片结构化比对和生成活动契约，直接检查端侧 `$[28].activities[1]` 的操作序列、答案、反馈与来源。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS103.md`
- `apps/web/src/lib/data/cs103-knowledge.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_consistency_cs103.py`

### 证据

- **源码确认**：RFC 9000 第 2 节规定通过交织多条流的 STREAM frame 实现多路复用；第 13.3 节规定丢失包不整包重传，而是按需在新帧中再次发送所载信息；RFC 9002 第 3 节定义确认、判丢和新包发送，第 7 节定义拥塞控制。官方 HTML 与文本本轮读取均返回 HTTP 200，且 RFC 9000/9002 文本中的 `FEC` 词项计数均为 0。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；33/33 Topic、59 个活动，类型分布不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_consistency_cs103 -v`，退出码 0；10 项通过，包含当前规格/生成产物/双端切片绿灯与旧 `[D1,D3]`、FEC 文案固定输入红灯。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；64 项运行，63 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`cd apps/web; pnpm lint; pnpm typecheck; pnpm test` 均退出码 0；13 个测试文件、167 项通过。
- **构建通过**：`cd apps/web; pnpm build`，退出码 0；Next.js 生产构建成功。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 18 s 595 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器、手机、平板或真机；UDP 推演输入、反馈滚动和手机/平板布局未验证。

## 批次二十六：CS102 题面自洽与并发模型边界

### 行为

- `cs102-内存管理基础-1` 的操作只有三次分配，题面从“分配/释放请求序列”改为“分配请求序列”；固定输入恢复旧题面时会同时报告缺少真实释放操作和题面类型不符。
- `cs102-I/O系统与磁盘调度-2` 不再宣称中断驱动 I/O 必然每传输一个字节中断一次，改为依据 `cs102_k31` 比较需 CPU 逐字节搬运的程序控制 I/O 与 DMA 块传输；契约绑定直接传输和完成中断两个事实。
- `cs102-死锁-2` 明确题设是“每类资源仅有一个实例”的 wait-for graph，且每条边表示一个进程必须等待另一进程释放资源，因此有环即死锁、环是充要条件；反馈同时说明多实例模型需用 Available/Allocation/Request 检测，不能把一般资源分配图的任意环直接判为死锁。
- `cs102-同步与互斥-2` 明确排序的是状态修改线程持有同一互斥锁、在 signal/broadcast 后释放锁的一条正确轨迹。反馈依据 POSIX 说明 wait 原子释放并阻塞、返回前重新持锁，以及 signal 可不持锁但要求可预测调度时应持锁，避免把题设轨迹误写成唯一合法 API 顺序。
- 子 agent 依据 OS Concepts 官方第 8 章材料和 POSIX.1-2024 实现 wait-for 模型分支、条件变量状态执行与四类错误固定输入；主代理逐段复核并新增 16 个 CS102 活动的类型、答案、引用闭包，以及 FF/DMA 红绿契约。

### 文件

- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `scripts/test_lesson_content_consistency_cs102.py`
- `scripts/test_cs102_concurrency_lesson_facts.py`

### 证据

- **源码确认**：`cs102_k31` 明确 DMA 在设备与内存间直接传输、CPU 无需逐字节参与，并在传输完成后通过中断通知 CPU。
- **源码确认**：Operating System Concepts 10e 官方第 8 章幻灯片第 11、33 页分别区分一般资源分配图的多实例“可能死锁”和每类资源单实例 wait-for graph 的“有环即死锁”。
- **源码确认**：POSIX.1-2024 `pthread_cond_wait()` 规定调用方持锁、原子释放并阻塞，返回前重新获取同一锁；`pthread_cond_signal()/broadcast()` 可在未持关联锁时调用，但要求可预测调度时调用方应持锁。官方页面本轮读取均返回 HTTP 200，且已核对上述正文。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；33/33 Topic、59 个活动，类型分布不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_consistency_cs102 scripts.test_cs102_concurrency_lesson_facts -v`，退出码 0；12 项通过。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；76 项运行，75 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 17 s 267 ms`，仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：当前无模拟器、手机、平板或真机；代码填空、七步排序、反馈滚动和手机/平板布局未验证。

## 批次二十七：TLS 1.3 模式边界与证书信任锚

### 行为

- `cs103_k32` 与 TLS 排序活动不再把 0-RTT 写成握手已经完成；明确它只在双方共享 PSK 时作为 early data 加入首个 flight，其余消息继续完成 1-RTT PSK 握手，且没有跨连接防重放保证。
- `cs103_k33` 与证书路径推演改为服务器发送终端和中间 CA 证书、客户端独立配置根 CA 信任锚；信任锚可从服务器链省略，其自签名不作为认证路径的一部分验证。
- `cs103_k34/k35` 列出 TLS 1.3 的 `(EC)DHE`、PSK-only、PSK 与 `(EC)DHE` 三类模式，区分“移除 RSA 密钥传输”和“RSA 仍可用于签名”，并删除“所有 TLS 1.3 模式强制前向安全”的错误概括。
- 现实案例把前向安全结论限定在 ECDHE 等临时密钥交换，明确 PSK-only 和 0-RTT 不能直接套用；规格中的四条知识摘要同步修正。
- 子 agent 完成两项活动和初始固定输入，主代理复核 RFC 原文后补齐 Web/raw 四切片逐字一致、四类旧语义拒绝、规格摘要与生成活动字段契约。

### 文件与生成边界

- 唯一活动源：`docs/ACTIVE-LEARNING-SPEC-CS103.md`。
- 生成器：`scripts/generate-learning-activities.mjs`；生成产物：`apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`。
- 生成 JSON 仅变化 9 个叶路径：`$[29].caseBody`、`$[29].workedExampleSteps[2]`、`$[29].activities[0].feedback`、`$[29].activities[0].source`、`$[29].activities[1].prompt`、`content`、`answer`、`feedback`、`source`。
- 知识切片同步文件：`apps/web/src/lib/data/cs103-knowledge.ts` 与 `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`；`scripts/test_lesson_content_consistency_cs103.py` 对 `cs103_k32` 至 `cs103_k35` 的正文和来源逐字比对。

### 证据

- **源码确认**：RFC 8446 第 2 节列出 `(EC)DHE`、PSK-only、PSK with `(EC)DHE` 三类密钥交换；第 2.3 节说明 0-RTT early data 加入 1-RTT 握手首个 flight，且不具前向安全和跨连接防重放保证；第 4.4.2 节允许独立分发的信任锚从服务器证书链省略；第 4.2.3 节说明自签名证书或信任锚签名不参与认证路径验证。官方文本读取返回 HTTP 200，正文长度 337736 字符，并核对上述原文。
- **静态诊断通过**：`node scripts/generate-learning-activities.mjs`，退出码 0；33/33 Topic、59 个活动，类型分布不变。
- **静态诊断通过**：`python -m unittest scripts.test_lesson_content_consistency_cs103 -v`，退出码 0；18 项通过，包含生成前旧产物红灯、当前规格/产物/双端切片绿灯及四类旧 TLS 固定输入红灯。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 闭环契约全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；84 项运行，83 项通过，1 项跨 WS02 reducer 契约为预期失败；Socket 的 `connect()` 调用起始时间拒绝 fixture 同时通过。
- **静态诊断通过**：`cd apps/web; pnpm lint; pnpm typecheck; pnpm test` 均退出码 0；13 个测试文件、167 项通过。
- **构建通过**：`cd apps/web; pnpm build`，退出码 0；Next.js 生产构建成功，静态页面生成 10/10。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 22 s 250 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- 生成前目标测试按预期在旧 TLS 活动产物上失败 1 项；生成后新增断言把“不能表述为”误写成“不表示为”，修正精确字面量后 18 项通过。
- 首次 WS03 回归命令包含仓库不存在的 `scripts.test_lesson_content_consistency_cs101`，退出码 1；通过 `rg --files` 读取实际测试文件后重跑正确的 10 个模块，退出码 0。
- **未验证**：当前无模拟器、手机、平板或真机；两项 TLS 活动、长反馈滚动及手机/平板布局未验证。本批未调用线上 API，不构成线上检索或学伴回答证据。

## 批次二十八：Reno ACK 调度与 OSPF 泛洪并发边界

### 行为

- 两个 Reno 活动不再把“每 RTT 精确翻倍/增加 1 MSS”写成 RFC 的无条件时钟语义。题面固定逐段 ACK、无延迟 ACK，并把拥塞避免按轮聚合为增加 1 MSS 的教学离散规则；答案数值保持 `cwnd=10 MSS, ssthresh=9 MSS`，快恢复继续使用 `FlightSize/2`、`ssthresh+3` 和新 ACK 后回落。
- `cs103_k20/k21` 改为 ACK 驱动增长：慢启动每个确认新数据的 ACK 至多增加 1 SMSS；拥塞避免近似执行 `cwnd += SMSS*SMSS/cwnd`。同标签题 `cs103_q35-q37` 同步区分典型指数形态、延迟 ACK、快恢复临时膨胀和 AIMD 概念模型。
- OSPF 排序活动不再把泛洪放在完整同步之后。新顺序为 `B→A→C→D→E`：2-Way、ExStart、Exchange/开始参与泛洪、请求列表补齐至 Full、按题设等待 Full 后运行 SPF。
- `cs103_k42` 明确 Exchange 状态即可参与泛洪和发送 LSR；请求列表未清空时进入 Loading 继续请求，接收 LSU 直至 Full。SPF 使用区域 LSDB，题面固定拓扑并显式等待 Full 只是为了形成唯一演练顺序，不包装成协议必然时序。
- 子 agent 核验 RFC 并交付 7 项初始测试；主代理复核后扩展为 10 项，覆盖规格、生成活动、Web/raw 切片、同标签题、delayed-ACK 可执行输入及 OSPF 错序 fixture。

### 文件与生成边界

- 活动唯一源：`docs/ACTIVE-LEARNING-SPEC-CS103.md`；经 `scripts/generate-learning-activities.mjs` 更新 `lesson-experiences.json` 的 `$[27]` Reno 示例/两项活动和 `$[31].activities[1]` OSPF 排序活动，共 23 个叶字段。
- 题库唯一源：`apps/web/src/lib/data/quizzes.ts`；经 `scripts/generate-quizzes-json.mjs` 更新端侧 `quizzes.json` 的 `$[122]`（`cs103_q35`）、`$[123].explanation`（`cs103_q36`）和 `$[124]`（`cs103_q37`），共 9 个叶字段；首标签仍为 `拥塞控制`。
- 知识同步：`apps/web/src/lib/data/cs103-knowledge.ts` 与端侧 `knowledge-chunks.json` 的 `cs103_k20`、`cs103_k21`、`cs103_k42` 正文/来源逐字一致。
- 契约：`scripts/test_cs103_non_tls_lesson_facts.py`、`scripts/test_lesson_content_consistency_cs103.py`。

### 证据

- **源码确认**：RFC 5681 第 3.1 节规定慢启动对每个累计确认新数据的 ACK 至多增加 1 SMSS，并给出拥塞避免公式；第 4.2 节允许延迟 ACK 至少每两个满尺寸段确认一次。官方文本 HTTP 200，正文长度 44339 字符。
- **源码确认**：RFC 2328 第 7.2 节明确邻接从 Database Exchange 开始即用于 flooding；第 10.1 节明确 Exchange 或更高状态可发送全部 OSPF 报文并可发送 LSR；请求列表清空后进入 Full。官方文本 HTTP 200，正文长度 524985 字符。
- **静态诊断通过**：修正前 `python -m unittest scripts.test_cs103_non_tls_lesson_facts -v` 退出码 1，7 项中两个 Reno 子项和一个 OSPF 项精准红灯；5 项独立红绿 fixture 已由子 agent 单独运行通过。
- **静态诊断通过**：两个生成器均退出码 0；33/33 Topic、59 个活动与 165 道选择题保持完整，题库源/产物逐字段一致。
- **静态诊断通过**：目标测试退出码 0；28 项通过。新测试中的 delayed-ACK 固定输入真实推进 `cwnd: 1→2→3`，拒绝无条件得到 4；OSPF 错误 fixture 拒绝 `B→A→D→C→E`。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，退出码 0；33 Topic、147 切片、165 题、33 experience 与 Lesson 同标签闭环全部通过。
- **静态诊断通过**：WS03 完整回归退出码 0；94 项运行，93 项通过，1 项跨 WS02 reducer 契约为预期失败；`lesson_self_assessment` 仍不计入客观掌握度。
- **静态诊断通过**：`cd apps/web; pnpm lint; pnpm typecheck; pnpm test` 均退出码 0；13 个测试文件、167 项通过。
- **构建通过**：`cd apps/web; pnpm build`，退出码 0；Next.js 生产构建成功，静态页面生成 10/10。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0；`BUILD SUCCESSFUL in 26 s 122 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- 新知识测试最初把否定说明中的“等待数据库完整同步后才泛洪”当禁用子串，产生 1 项误报；已改为只拒绝明确的 Full 后才泛洪断言，错误顺序由结构化选项和答案执行验证。
- 目标交叉回归曾因旧测试要求连续出现 `RFC 5681第3.2节` 而失败 1 项；来源合法扩展为第 3.1/3.2/4.2 节后，将契约收紧为精确章节片段并同步真实旧状态 fixture，重跑 28 项通过。
- **未验证**：当前无模拟器、手机、平板或真机；长题面、五步排序拖动、同标签题跳转和反馈滚动的实际布局未验证。本批未调用线上 API。

## 批次二十九：HTTP 持久连接与跨流队头阻塞边界

### 行为

- `cs103_k28` 区分 HTTP 语义与承载：HTTP/1.1、HTTP/2 通常运行在 TCP 之上，HTTP/3 运行在 QUIC 之上，不再用“HTTP 运行在 TCP 之上”覆盖所有版本。
- `cs103_k29` 按 RFC 9110 区分安全与幂等。安全只表示客户端没有请求、也不期望目标资源状态改变，不排除日志或计费等附带副作用；幂等比较多个相同请求与单个请求的预期效果，不要求响应内容完全相同。
- `cs103_k31` 与 `cs103_q40` 明确 HTTP/1.1 默认使用持久连接，无需发送 `Connection: keep-alive`，关闭时使用 `Connection: close`。`cs103_q09` 明确 DELETE 幂等但不安全；Web 简答题 `cs103_q11` 不再称 HTTP/2 消除所有队头阻塞。
- HTTP Topic 从既有单活动迁移数据进入主动学习规格：第一个活动保留 Accept/Content-Type 辨析，第二个活动固定三个等长连续 TCP 字节范围，真实执行“序号 2 丢失、另一流的序号 3 先到只能缓存、序号 2 重传后按序交付 2 和 3”。反馈区分 HTTP/1.1 应用层队头阻塞和 HTTP/2 仍存在的 TCP 队头阻塞。
- 子 agent 独立交付 `scripts/test_cs103_http_facts.py` 初稿，包含连续交付执行器和“仅丢失帧所属 stream 阻塞”的错误 fixture；主代理逐段复核后补齐 Web/raw 一致性、`cs103_q11` 旧文案反例与 RFC 来源约束。

### 文件与生成边界

- 活动唯一源：`docs/ACTIVE-LEARNING-SPEC-CS103.md`；`scripts/generate-learning-activities.mjs` 将规格覆盖从 26 Topic/52 活动提升为 27 Topic/54 活动，并按既有 Topic 键原位生成，避免 JSON 全量重排。
- `lesson-experiences.json` 仅原位更新 `$[6]`（`cs103/HTTP协议`）：活动数由 1 增为 2，总活动数由 59 增加到 60；其他 32 个 Topic 顺序与内容保持不变。
- 知识唯一源：三门课程的 `apps/web/src/lib/data/cs*-knowledge.ts`。新增 `scripts/generate-knowledge-json.mjs` 校验字段、courseId、147 条总数和全局唯一 id，再生成端侧 JSON。本批产物只变化 `$[127]`（`cs103_k28`）、`$[128]`（`cs103_k29`）、`$[130]`（`cs103_k31`）的 `text/source`。
- 题库唯一源：`apps/web/src/lib/data/quizzes.ts`；现有生成器更新端侧 `$[130].explanation`（`cs103_q09`）、`$[132].explanation`（`cs103_q40`）及由修正文案重新计算的 `$[132].tags[1]`（`协议机制`）。`cs103_q11` 是 Web 简答题，不进入只包含选择题的端侧 JSON。

### 证据

- **源码确认**：RFC 9110 第 9.2.1 节明确安全方法只要求客户端不请求状态改变，并列举访问日志和广告计费等允许的附带副作用；第 9.2.2 节以多个相同请求与单个请求的预期效果定义幂等。
- **源码确认**：RFC 9112 第 9.3 节明确 HTTP/1.1 默认使用持久连接；`close` connection option 表示当前响应后关闭。RFC 9113 第 1 节明确 HTTP/2 处理 HTTP/1.1 的 application-layer head-of-line blocking，但不处理 TCP head-of-line blocking。三份 RFC 官方文本本轮读取均返回 HTTP 200，并核对上述正文。
- **静态诊断通过**：修正前 `python scripts/test_cs103_http_facts.py` 退出码 1，7 项中 7 项失败，分别命中缺少第二活动、三条知识语义、两道选择题解释和生成活动；修正后退出码 0，9 项通过。固定错误输入明确拒绝“序号 3 可跨缺口交付”和“只有丢失帧所属 stream 阻塞”。
- **静态诊断通过**：`node scripts/generate-knowledge-json.mjs`、`node scripts/generate-quizzes-json.mjs`、`node scripts/generate-learning-activities.mjs` 均退出码 0；Web/端侧 147 条知识切片完全一致，165 道端侧选择题完全一致，33/33 Topic 共 60 个活动。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题、33 experience 的 schema、唯一性、引用、DAG、连通性、层级、Topic 和 Lesson 闭环全部通过。
- **静态诊断通过**：`python -m unittest discover -s scripts -p "test_*.py"` 退出码 0；103 项运行，102 项通过，1 项跨 WS02 `getTagInsights` reducer 契约为预期失败。`lesson_self_assessment` 页面事件没有 `accuracy/totalQuestions/correctCount`，未被包装成客观掌握度。
- **静态诊断通过**：`cd apps/web; pnpm lint; pnpm typecheck; pnpm test` 均退出码 0；13 个测试文件、167 项通过。
- **构建通过**：`cd apps/web; pnpm build` 退出码 0；Next.js 生产构建成功，静态页面生成 10/10。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` 最终退出码 0；ArkTS 与资源重新编译，`BUILD SUCCESSFUL in 29 s 836 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- 端侧 `cs103_q40` 第二标签从“状态推演”变为“协议机制”。追溯 `buildQuestionTags/abilityTag` 后确认旧解释因含“阻塞”被归入状态推演；修正后的持久连接解释按现有唯一源规则确定性归入协议机制，不是手工改写产物。
- **未验证**：当前环境 `hdc` 不存在，未安装或启动 HAP；HTTP 自由回答、跨流状态推演、长反馈滚动和手机/平板布局均未验证。本批未调用线上 API，不构成线上检索或学伴回答证据。

## 批次三十：DNS SOA.MINIMUM 与否定缓存 TTL 语义

### 行为

- `cs103-DNS系统-2` 的区域文件新增 `$TTL 3600`，为未显式给出 TTL 的资源记录提供默认值；SOA 最后一项 `86400` 明确标为否定缓存参数 `MINIMUM`，不再称为普通默认 TTL。
- 活动反馈补齐 RFC 2308 规则：权威服务器为否定响应携带的 SOA 记录选择 TTL 时，取 SOA 记录自身 TTL 与 SOA.MINIMUM 的较小值。A/AAAA、MX、NS 和 CNAME 的原题答案保持不变。
- `cs103_k39` 同步区分主文件 `$TTL`、SOA.MINIMUM 与否定缓存，Web 源和端侧离线切片逐字一致；来源从教材扩展到 RFC 1035 第 3.3.13 节及 RFC 2308 第 4/5 节。
- 子 agent 新增 `scripts/test_cs103_dns_lesson_facts.py`，用区域文件解析器分别执行正确/旧式 fixture，并计算 `default_rr_ttl=3600`、`soa_minimum=86400`、`negative_cache_ttl=3600`。主代理复核后把“禁止所有默认 TTL 字样”收紧为只禁止 MINIMUM 承担普通默认 TTL 的旧断言。

### 文件与生成边界

- 活动唯一源：`docs/ACTIVE-LEARNING-SPEC-CS103.md`；现有生成器只更新 `lesson-experiences.json` 的 `$[30].activities[1].content`、`feedback` 和 `source`。
- 知识唯一源：`apps/web/src/lib/data/cs103-knowledge.ts`；知识生成器只更新端侧 `knowledge-chunks.json` 的 `$[138]`（`cs103_k39`）`text/source`。
- 契约：`scripts/test_cs103_dns_lesson_facts.py`；没有修改题库、页面、仓储、Web API 或 WS06 发布脚本。

### 证据

- **源码确认**：RFC 2308 第 4 节明确废止 SOA.MINIMUM 作为区域最小 TTL，并要求未显式给出 TTL 的记录使用不同机制，随后为 RFC 1035 master file 定义 `$TTL <TTL>` 指令；第 5 节明确否定响应中 SOA 记录的 TTL 取 SOA.MINIMUM 与 SOA 自身 TTL 的较小值。官方文本本轮读取返回 HTTP 200，并核对上述正文。
- **静态诊断通过**：`node scripts/generate-knowledge-json.mjs`、`node scripts/generate-learning-activities.mjs` 均退出码 0；147 条 Web/端侧知识切片一致，33/33 Topic 共 60 个活动。
- **静态诊断通过**：`python scripts/test_cs103_dns_lesson_facts.py` 最终退出码 0；3 项通过，覆盖正确/错误区域文件、规格/产物逐字段一致及 Web/raw `cs103_k39` 来源语义。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的关系、层级与 Lesson 闭环全部通过。
- **静态诊断通过**：以 `git ls-files` 取得当前已跟踪测试模块并加入 DNS 新契约，退出码 0；106 项运行，105 项通过，1 项跨 WS02 reducer 契约为预期失败。CS101/TLS 两个后续批次的未跟踪红灯测试没有计入通过数。
- **静态诊断通过**：Web lint/typecheck 与 13 文件/167 测试均退出码 0。
- **构建通过**：Web 生产构建退出码 0，静态页面生成 10/10；HarmonyOS 增量 `assembleHap` 退出码 0，`BUILD SUCCESSFUL in 26 s 163 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- 旧内容目标测试退出码 1：规格/产物缺少 `$TTL`，`cs103_k39` 缺少 MINIMUM/否定缓存语义。首次修正后契约仍因正确的“`$TTL` 提供默认 TTL”和否定说明含“默认 TTL”而误报；改为按语义主体拒绝旧断言后 3 项通过。
- **未验证**：当前无模拟器、手机、平板或真机；区域文件代码块、反馈滚动和布局未验证。本批未调用线上 API。

## 批次三十一：LCS 与编辑距离前缀索引一致性

### 行为

- `cs101_k38` 明确 `dp[i][j]` 的两个维度表示长度为 `i/j` 的前缀，而 C++ 字符串使用零基下标，因此当前前缀末尾必须比较 `X[i-1]` 与 `Y[j-1]`；不再把前缀长度直接写成字符下标 `X[i]/Y[j]`。
- 动态规划活动 1 的规格反馈同步修正引用公式。原 C++ 循环已经正确使用 `X[i-1] == Y[j-1]`，填空答案和 LCS 数值不变。
- 同标签题 `cs101_q48` 的编辑距离解释使用相同索引契约，并补全相等分支与删除、插入、替换三项转移公式。
- 子 agent 交付 `scripts/test_cs101_algorithm_lesson_facts.py`：单字符 `X=Y="A"` 使用正确比较得到 LCS 1，旧 `X[i]/Y[j]` 在第一个非空状态立即越界；另独立执行两组 Lomuto 分区和稳定 merge 输入，确认排序活动没有同类事实缺口。

### 文件与生成边界

- 规格源：`docs/ACTIVE-LEARNING-SPEC-CS101.md`；知识唯一源：`apps/web/src/lib/data/cs101-knowledge.ts`；题库唯一源：`apps/web/src/lib/data/quizzes.ts`。
- `scripts/generate-knowledge-json.mjs` 只更新端侧 `knowledge-chunks.json` 的 `$[37].text`（`cs101_k38`）；`scripts/generate-quizzes-json.mjs` 只更新 `quizzes.json` 的 `$[38].explanation`（`cs101_q48`），两份生成器均完成源/产物一致性校验。
- 按主线程保护要求，本批未运行学习活动生成器，未修改或暂存 `lesson-experiences.json`，也未修改 `DEVLOG.md`。因此受保护产物 `$[12].activities[0].feedback` 仍含旧引用公式，未被本批写成一致性通过；主线程采用规格提交后需在其受控工作树生成该单一产物字段。

### 证据

- **源码确认**：规格中的 C++ 实现从 `i=1/j=1` 开始并使用 `X[i-1] == Y[j-1]`；状态 `dp[i][j]` 表示两个长度为 `i/j` 的前缀，因此单字符状态 `dp[1][1]` 只能读取下标 0。
- **静态诊断通过**：修正前 `python scripts/test_cs101_algorithm_lesson_facts.py` 退出码 1，规格、Web/raw `cs101_k38` 和 `cs101_q48` 共 5 个内容表面子项精准红灯；最终退出码 0，3 项测试通过，包含正确/错误索引执行 fixture 与 Web/raw 逐字一致。
- **静态诊断通过**：`node scripts/generate-knowledge-json.mjs` 与 `node scripts/generate-quizzes-json.mjs` 均退出码 0；147 条知识切片和 165 道端侧选择题分别与 Web 唯一源完全一致。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；Topic/切片/题库/experience 引用、DAG、层级和 Lesson 路由闭环通过。该命令不证明受保护 Lesson 反馈已同步。
- **静态诊断通过**：以当前已跟踪测试模块加入 CS101 新契约，退出码 0；109 项运行，108 项通过，1 项跨 WS02 reducer 契约为预期失败。TLS 后续批次的未跟踪红灯测试未计入通过数。
- **静态诊断通过**：Web lint/typecheck 与 13 文件/167 测试均退出码 0。
- **构建通过**：Web 生产构建退出码 0，静态页面生成 10/10；HarmonyOS API 12 增量 `assembleHap` 退出码 0，`BUILD SUCCESSFUL in 29 s 842 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- 首次源修正后目标测试仍因 `cs101_q48` 只写“比较 X[i-1] 与 Y[j-1]”而没有精确相等条件退出码 1；改为 `X[i-1]=Y[j-1]` 后重生成题库，3 项通过。
- **未验证**：受保护的 `lesson-experiences.json` 未生成，`$[12].activities[0].feedback` 仍待主线程受控同步；无模拟器、手机、平板或真机，代码填空与长反馈显示未验证。本批未调用线上 API。

## 批次三十二：TLS 测验认证与密钥协商边界

### 行为

- `cs103_q12` 不再把 ECDHE 称为“非对称加密”。解释明确 TLS 1.3 使用 `(EC)DHE` 密钥协商或 PSK 建立共享密钥材料，再派生 AEAD 保护应用流量的对称密钥；证书签名用于认证，不承担应用数据加密。
- `cs103_q13` 将题面限定为使用证书认证的 HTTPS，并补齐证书路径终止于客户端本地独立配置的信任锚、CertificateVerify 证明服务器持有终端证书私钥的两个步骤。
- `cs103_q43` 区分完整握手 1-RTT 与 PSK 恢复握手首个 flight 中的 0-RTT early data，明确 PSK-only 可省略 Certificate/CertificateVerify，删除“TLS 1.3 所有连接都必须使用数字证书”的绝对断言。
- `cs103_q44` 直接询问信任锚为何受信任，正确项改为客户端操作系统或应用本地独立配置；反馈明确自签名只是信任锚信息的可选承载形式，不自动产生信任，服务器可省略客户端已持有的锚。
- `cs103_q45` 把前向安全性限定在临时 `(EC)DHE` 并销毁临时私钥的模式，明确 PSK-only 和 0-RTT early data 没有这项保证。Web-only 简答题 `cs103_q14` 同步区分证书公钥验证 CertificateVerify 与 KeyShare 完成密钥协商。
- 子 agent 新增 `scripts/test_cs103_tls_quiz_facts.py`，逐字段比对 Web/raw 五道选择题，并以六份旧文案 fixture 验证门禁能够拒绝旧语义。

### 文件与生成边界

- 题库唯一源：`apps/web/src/lib/data/quizzes.ts`；`scripts/generate-quizzes-json.mjs` 生成端侧 `quizzes.json` 并完成 165 道选择题全字段一致性校验。
- 端侧精确变化：`$[135].explanation`（`cs103_q12`）；`$[136].question/explanation`（`cs103_q13`）；`$[137].explanation/tags[1]`（`cs103_q43`）；`$[138].question/options/explanation`（`cs103_q44`）；`$[139].explanation/tags[1]`（`cs103_q45`）。`cs103_q14` 是 Web 简答题，不进入只含选择题的端侧 JSON。
- q43 第二标签由旧解释中的“删除”误触为“结构操作”，修正后按题干“相比”确定为“概念辨析”；q45 在明确 TLS/PSK 模式后由“概念理解”确定为“协议机制”。两项均由现有 `buildQuestionTags/abilityTag` 从唯一源重新计算，不是手工修改生成产物。
- 按主线程保护要求，本批未修改或生成 `lesson-experiences.json`，未修改 `DEVLOG.md`；没有触碰页面、仓储、Web API 或 WS06 发布脚本。

### 证据

- **源码确认**：RFC 8446 第 2 节列出 `(EC)DHE`、PSK-only、PSK with `(EC)DHE` 三种模式；第 4.2.8 节定义 KeyShare 承载 DH/ECDH 密钥协商参数；第 4.4.2 节规定使用证书认证时发送 Certificate，而 PSK 模式可省略；第 4.4.3 节规定 CertificateVerify 显式证明证书私钥持有并保护此前握手完整性。
- **源码确认**：RFC 5280 第 6.1.1 节把 trust anchor information 作为路径验证输入，明确它因可信带外流程交付而受信任；自签名证书只是一种可选输入形式。RFC 官方文本本轮读取均返回 HTTP 200，并核对上述正文。
- **静态诊断通过**：修正前 `python scripts/test_cs103_tls_quiz_facts.py` 退出码 1，生产语义契约的 q12/q13/q43/q44/q45/q14 六个子项全部红灯；Web/raw 同步子测试和六份旧 fixture 拒绝子测试已通过。修正后退出码 0，3 项测试全部通过。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs` 退出码 0；165 道端侧选择题与 Web 唯一源逐字段一致。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的引用、DAG、层级与 Lesson 路由闭环通过。
- **静态诊断通过**：以当前已跟踪测试模块加入 TLS 新契约，退出码 0；112 项运行，111 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：Web lint/typecheck 与 13 文件/167 测试均退出码 0。
- **构建通过**：Web 生产构建退出码 0，静态页面生成 10/10；HarmonyOS API 12 增量 `assembleHap` 退出码 0，`BUILD SUCCESSFUL in 24 s 568 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- **未验证**：当前无模拟器、手机、平板或真机；五道选择题解释换行、选项可读性和简答题 Web 显示未验证。本批未调用线上 API。

## 批次三十三：数字签名方案与验证算法边界

### 行为

- `cs103_k46` 不再把数字签名概括成“非对称加密的逆运用”。内容以明确签名方案为单位，说明 RSA-PSS/ECDSA 使用私钥生成签名，验证方以公钥、消息、签名和约定参数运行验证算法并得到有效或无效结果。
- RSA-PSS 的教学解释落实到 RFC 8017：签名端执行 EMSA-PSS 编码和 RSA 签名原语；验证端执行 RSA 验证原语并检查 EMSA-PSS 一致性。内容明确拒绝“私钥加密摘要、公钥解密签名恢复摘要”这一不能覆盖 ECDSA 或 RSA-PSS 的通用模型。
- `cs103_q52` 的正确项改为“验证消息完整性与签名者身份，并可作为不可否认性证据”。解释同时限定：不可否认性需要私钥控制、身份绑定和审计条件，签名本身不加密消息内容。
- CS103 Topic 10 的五步排序保持 `B → D → E → A → C`，但改为选择签名方案、以原消息调用签名、从协议上下文取得算法参数、检查本地算法策略、以原消息调用验证算法的可执行因果链。题面先声明接收方已通过有效证书路径或可信配置取得并绑定签名者身份的公钥，避免把任意自建密钥的数学验签包装成身份认证。
- 新增 `scripts/test_cs103_signature_facts.py`，用正确 fixture 和三份旧模型 fixture 验证语义门禁，执行五步状态模型并精确拒绝“摘要冒充 RFC 8017 接口输入”和“未绑定公钥即认证身份”两个反例，同时逐字段比对 Web/端侧知识、题库以及主动学习规格。

### 文件与生成边界

- 规格源：`docs/ACTIVE-LEARNING-SPEC-CS103.md`；知识唯一源：`apps/web/src/lib/data/cs103-knowledge.ts`；题库唯一源：`apps/web/src/lib/data/quizzes.ts`。
- `scripts/generate-knowledge-json.mjs` 只更新端侧 `knowledge-chunks.json` 的 `$[145].text` 与 `$[145].source`（`cs103_k46`）。
- `scripts/generate-quizzes-json.mjs` 只更新端侧 `quizzes.json` 的 `$[154].question`、`$[154].options[1]` 与 `$[154].explanation`（`cs103_q52`）；答案、难度和三个标签均不变。新题面明确公钥已可信获得并绑定签名者身份。
- 按主线程保护要求，本批未运行学习活动生成器，`git diff --exit-code -- apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json` 退出码 0。主线程采用规格后需在其受控工作树同步以下精确字段，其他字段不变：
  - `$[32].caseBody`：`对称加密像用同一把钥匙锁箱子和开箱子——快但钥匙怎么安全给对方是难题（密钥分发问题）。非对称加密像你有一把公开的锁（公钥），任何人都能锁上但只有你有钥匙（私钥）能打开。数字签名不是把开锁过程倒放：签名方按公开的签名方案让私钥参与生成签章，验证方把原文、签章、已可信绑定签名者身份的公钥和算法参数交给验证算法，得到有效或无效结果。实际通信中可用密钥交换或密钥封装建立对称密钥，再用对称算法保护大量数据；签名用于认证和完整性，不等同于加密内容。`
  - `$[32].activities[0].prompt`：`接收方已通过有效证书路径或可信配置取得公钥，并确认该公钥与声称的签名者身份绑定。以下是数字签名的生成与验证过程，请将打乱的步骤排列为正确的执行顺序`
  - `$[32].activities[0].options[0]`：`接收方检查算法标识和参数符合本地策略，并选择对应验证算法`
  - `$[32].activities[0].options[1]`：`发送方选择明确的签名方案（如RSA-PSS或ECDSA）及约定参数`
  - `$[32].activities[0].options[2]`：`接收方以已可信绑定签名者身份的公钥、原消息、签名和约定参数调用验证算法，得到有效或无效结果`
  - `$[32].activities[0].options[3]`：`发送方以私钥、原消息和约定参数调用签名算法；方案内部完成哈希与编码，输出数字签名`
  - `$[32].activities[0].options[4]`：`接收方取得原消息和数字签名，并从协议上下文取得约定的算法标识和参数`
  - `$[32].activities[0].feedback`：取规格中 Topic 10 主动练习 1 的完整新反馈，从“发送方先选择明确的签名方案和约定参数（B）”开始，到“才可进一步作为不可否认性证据”结束。
  - `$[32].activities[0].source`：`NIST FIPS 186-5；RFC 8017第8.1.1节、第8.1.2节；知识切片 cs103_k46`

### 证据

- **源码确认**：NIST FIPS 186-5 官方页面说明该标准定义一组生成数字签名的算法，签名用于检测未授权修改、认证签名者，并可作为不可否认性证据；页面本轮读取 HTTP 200，业务正文与出版物元数据均已核对。
- **源码确认**：RFC 8017 官方文本本轮读取 HTTP 200。第 8.1.1 节的 `RSASSA-PSS-SIGN` 先执行 `EMSA-PSS-ENCODE`，再执行 `RSASP1`；第 8.1.2 节的 `RSASSA-PSS-VERIFY` 执行 `RSAVP1` 和 `EMSA-PSS-VERIFY`，最终只输出 `valid signature` 或 `invalid signature`。
- **源码确认**：修正前 `python -m unittest scripts.test_cs103_signature_facts -v` 退出码 1；3 个测试方法中正确/旧 fixture 方法已通过，真实规格与双端内容方法红灯，unittest 共记录 9 个失败断言。修正源但尚未生成端侧 JSON 时同一命令仍退出码 1，只剩规格精确措辞与 raw 同步两项失败，证明门禁没有绕过生成链。
- **静态诊断通过**：`node scripts/generate-knowledge-json.mjs` 与 `node scripts/generate-quizzes-json.mjs` 均退出码 0；147 条知识切片和 165 道选择题分别与 Web 唯一源完全一致。
- **静态诊断通过**：最终 `python -m unittest scripts.test_cs103_signature_facts -v` 退出码 0；4 项通过，包含正确模型绿灯、三份旧模型固定输入红灯断言、预哈希/未绑定公钥两个状态反例，以及规格和 Web/raw 同步。
- **静态诊断通过**：以 `git ls-files scripts` 取得全部已跟踪测试模块并加入新签名契约，退出码 0；116 项运行，115 项通过，1 项跨 WS02 reducer 契约为预期失败。三个后续子 agent 的未跟踪红灯测试没有计入通过数。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的 schema、引用、DAG、层级与 Lesson 路由闭环通过。该命令不证明受保护 Lesson 活动文案已同步。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 生产构建成功并生成 10/10 静态页面。
- **构建通过**：HarmonyOS API 12 增量 `assembleHap --no-daemon` 退出码 0，最终树 `BUILD SUCCESSFUL in 38 s 170 ms`；仍提示未配置 `signingConfigs`。

### 失败与未验证

- 首次生成题库时，解释中的“签名计算”触发现有标签器的“数值计算”规则；改为等义且更准确的“签名运算”后重新生成，`cs103_q52` 的第二标签保持“机制解释”。未修改共享标签器。
- 两阶段子 agent 审查先后发现摘要被误作 RFC 8017 外部输入、身份认证缺少可信公钥绑定前提、旧正确 fixture 自相矛盾，以及活动状态模型未消费真实 A-E 的四类问题；全部修正并重新复审。最终契约分别锁定知识与题库表面，结构化解析真实 prompt/选项/答案，并用摘要输入、未绑定攻击者公钥、重复验签和验签早于策略检查四类固定反例防止误绿。
- **未验证**：受保护的 `lesson-experiences.json` 尚未同步上述 9 个叶字段；当前端侧 Lesson 仍显示旧签名活动文案，不能记为产品路径通过。
- **未验证**：当前无模拟器、手机、平板或真机；长知识切片、五步排序和题库解释的实际显示未验证。本批未调用线上 API。

## 批次三十四：分页与段页式物理碎片边界

### 行为

- `cs102_q35` 不再以“哪种存储管理方式”提问并把段页式列为错误干扰项；题面限定为分页存储管理中的物理内存碎片，四个选项直接比较碎片结论，唯一正确项 B 为“可能产生内部碎片，但不产生外部碎片”。
- 解释补齐因果：逻辑页可映射到任意空闲且彼此不连续的固定大小物理页框，因此不要求连续大块、没有物理外部碎片；最后一页未填满时，页框内未使用字节构成内部碎片。
- 删除“段页式结合两者，可能同时存在内部和外部碎片”的错误断言。既有 `cs102_k21`、`cs102_q50` 与主动学习规格都明确每段继续分页并保留分页消除物理外部碎片的性质，本批不改写这些已正确内容。
- 采用子 agent 交付的 `scripts/test_cs102_memory_lesson_facts.py`：同一固定输入给出两个互不连续的 4 KiB 空闲区；连续 6 KiB 段无法装入，而分页后的两个页可映射到 frame 2/9，成功分配并产生 2 KiB 内部碎片、0 外部碎片。

### 文件与生成边界

- 题库唯一源：`apps/web/src/lib/data/quizzes.ts`；`scripts/generate-quizzes-json.mjs` 生成端侧 `quizzes.json` 并完成 165 道选择题全字段一致性校验。
- 端侧精确变化仅为 `$[74].question`、`$[74].options[0]`、`$[74].options[1]`、`$[74].options[2]`、`$[74].options[3]` 与 `$[74].explanation`（`cs102_q35`）；`answer=B`、`difficulty=medium` 和标签 `内存分配/系统机制/应用推理` 均不变。
- 本批不修改 CS102 主动学习规格、知识切片或 `lesson-experiences.json`。q35 是题库概念题，不是 Lesson 活动生成源，因此没有待同步 Lesson JSON 路径；`git diff --exit-code -- apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json` 退出码 0。

### 证据

- **源码确认**：本轮直接读取 Operating System Concepts 10th edition 官方 `ch9.pptx`，HTTP 200，响应长度 4,932,040 字节；全过程只在内存解压 slide XML，未写入工作区。slide 23 明确物理地址空间可以不连续、分页避免外部碎片但仍有内部碎片；slide 28 给出末页内部碎片计算；slide 59-60 明确 IA-32 支持 segmentation with paging，分段单元输出线性地址后由分页单元映射到物理内存。
- **源码确认**：修正前 `python -m unittest scripts.test_cs102_memory_lesson_facts -v` 退出码 1；4 项中 3 项通过，生产 q35 契约唯一红灯并报告 6 个精确语义缺口。正确/旧 fixture、离散页框执行模型与既有支撑内容在红灯阶段均已通过。
- **源码确认**：只修 Web 唯一源、尚未生成端侧题库时，同一目标测试仍退出码 1，唯一失败是 Web/raw q35 字段不一致，证明测试没有绕过生成链。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs` 退出码 0；165 道端侧选择题与 Web 唯一源完全一致。
- **静态诊断通过**：最终 `python -m unittest scripts.test_cs102_memory_lesson_facts -v` 退出码 0；4 项通过，覆盖正确/错误文案、连续段与离散页框分配模型、Web/raw 同步及 `cs102_k21/q50/spec` 支撑边界。
- **静态诊断通过**：以 `git ls-files scripts` 取得全部已跟踪测试模块并加入本批新契约，退出码 0；120 项运行，119 项通过，1 项跨 WS02 reducer 契约为预期失败。文件系统与 AVL 的两个未跟踪后续红灯测试没有计入通过数。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的 schema、引用、DAG、层级与 Lesson 路由闭环通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 生产构建成功并生成 10/10 静态页面。
- **构建通过**：HarmonyOS API 12 增量 `assembleHap --no-daemon` 退出码 0，`BUILD SUCCESSFUL in 54 s 447 ms`；仍提示未配置 `signingConfigs`。

### 失败与未验证

- 初次新解释中的“剩余空间”触发通用标签器的复杂度规则，随后题面“以下说法正确”又触发概念辨析规则；改成“页框内未使用的字节”并直接询问碎片特征后重新生成，最终三个派生标签与 HEAD 完全相同。未修改共享标签器。
- **未验证**：当前无模拟器、手机、平板或真机；新题面、四个选项和长解释的实际布局未验证。本批未调用线上 API。

## 批次三十五：AVL 双旋基本操作计数边界

### 行为

- `cs101_q41` 明确把一次左旋或右旋定义为 1 次基本旋转，不再把“一次双旋修复”与“一次基本旋转”混为同一计数单位。
- 正确答案由 A 改为 B：LL/RR 型需要一次基本旋转，LR/RL 型依次执行两个方向的两次基本旋转，因此一次 AVL 插入恢复平衡最多执行两次基本旋转。
- 新增可执行 AVL 插入模型，覆盖六个三键排列：无需旋转的两种排列计 0，LL/RR 各计 1，LR/RL 各计 2。契约同时拒绝旧答案 A、“双旋只算一次基本旋转”和否定句包含关键词误绿。

### 文件与生成边界

- 题库唯一源为 `apps/web/src/lib/data/quizzes.ts`；`scripts/generate-quizzes-json.mjs` 生成 HarmonyOS `quizzes.json` 并校验 165 道选择题逐字段一致。
- 端侧精确变化仅为 `$[24].question`、`$[24].answer`、`$[24].explanation`（`id=cs101_q41`）。四个选项、`difficulty=medium` 和标签 `平衡树机制/复杂度分析/应用推理` 均不变。
- 本批未修改主动学习规格、知识切片或受保护的 `lesson-experiences.json`，也未修改 `DEVLOG.md`。AVL Lesson 既有活动已经真实执行“对 60 右旋，再对 50 左旋”，无需生成 Lesson 产物。

### 证据

- **源码确认**：Virginia Tech OpenDSA《The AVL Tree》官方 source `AVL.rst.txt` 本轮读取 HTTP 200；第 125-130 行明确 Cases 1/4 使用 single rotation、Cases 2/3 使用 double rotation，第 162-170 行定义 left-right 及对称 right-left double rotation，第 180-184 行再次说明 Case 2 requires a double rotation。
- **源码确认**：修正前目标契约退出码 1，生产 q41 缺少基本旋转计数单位、答案仍为 A，四个事实约束红灯；只改 Web 源且尚未生成端侧 JSON 时，4 项中 3 项通过，唯一失败是 Web/raw q41 不一致。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs` 退出码 0，165 道端侧选择题与 Web 唯一源完全一致。
- **静态诊断通过**：最终 `python -m unittest scripts.test_cs101_complexity_lesson_facts -v` 退出码 0，4 项通过；包含六个三键排列、旧文案、错误答案和否定句误绿固定输入。
- **静态诊断通过**：17 个已跟踪脚本测试模块加本批新契约，退出码 0；124 项运行，123 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的 schema、引用、DAG、层级与 Lesson 路由闭环通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 生产构建成功并生成 10/10 静态页面；HarmonyOS API 12 增量 `assembleHap --no-daemon` 退出码 0，ArkTS 与资源重新编译，`BUILD SUCCESSFUL in 25 s 500 ms`，仍提示未配置 `signingConfigs`。
- **模拟器通过**：SDK `hdc.exe` 位于 `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`；目标 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`。当前 unsigned HAP 安装返回 `install bundle successfully`，`EntryAbility` 启动返回 `start ability successfully`。竖屏 UI 根 bounds 为 `[0,137][1256,2760]`。
- **模拟器通过**：所有点击均由实时 UI 树 bounds 计算中心。已走通 `pages/Index` 课程 Tab -> 数据结构 `pages/CourseDetail` -> `AVL树与红黑树` -> `pages/Lesson`，知识切片从 1/4 推进到 4/4，并打开主动练习 1/2。退出 Lesson 后课程页真实显示“上次学到 · AVL树与红黑树”，详情显示“继续 · AVL树与红黑树”，证明未完成 Topic 的最近学习语义能由真实断点恢复，不依赖种子进度。

### 失败与未验证

- 第一项活动已显示 AVL 插入 55 的固定状态推演；向上滚动后 UI 树出现“开始逐步推演”和“提交并对照答案”。本轮没有输入、提交或自评，不能记为互动完成，`lesson_self_assessment` 也未被当作客观掌握度。
- **未验证**：未进入同标签 Quiz，因此新 `cs101_q41` 的端侧实际题面、选择与反馈显示未验证；Course -> Topic -> Lesson -> 互动 -> 同标签练习的完整运行闭环本批未通过。运行态随后被切换到其他 Tab，且一次内联 PowerShell UI 辅助命令因 `throw` 后缺少空格产生错误，未将该失败计为产品通过。
- DevEco 会话 `ses_08ba7c7b2ffeHBxmS1eMIZSuiB` 未设置 `DEVECO_HOME`，`check_ets_files/build_project` 均返回 `DEVECO_HOME environment variable is not configured`；校准后的 `ses_08ba6a8b9ffeEMtXoMllguKjxO` 显式设置 `DEVECO_HOME`、Alibaba 模型和授权参数，但约 70 秒无输出后被终止。两次均不构成 DevEco check/start 通过；本批静态、构建和 UI 证据分别来自 Web/Hvigor/HDC。
- **未验证**：手机、平板、真机和线上 API 未验证。本批未创建或提交截图、HAP、日志及本地 IDE 文件。

## 批次三十六：POSIX 文件身份与链接实现边界

### 行为

- `cs102_k26` 不再用“每个文件有唯一 inode 号”忽略设备边界，也不再把 ext 风格多级块索引写成通用 Unix/Linux inode 定义。内容明确 POSIX 文件身份由 `st_dev` 与 `st_ino` 共同确定，同一文件的硬链接共享身份与链接计数。
- 知识切片补齐 `link()` 增加链接计数、`unlink()` 删除目录项并减少计数，以及最后链接删除且没有打开引用后才释放文件空间的生命周期。
- Web-only 简答题 `cs102_q15` 区分硬链接、目录硬链接例外和符号链接：目录 `link()` 通常失败，但进程有适当权限且实现支持时可成功；`symlink()` 保存未经路径校验的字符串，创建时目标可不存在，也可跨文件系统；删除符号链接不影响目标。
- 跨文件系统硬链接按 POSIX.1-2024 Issue 8 精确限定：可移植程序不得依赖；源文件与目标目录位于不同文件系统且实现不支持跨文件系统硬链接时返回 `EXDEV`。删除了“POSIX 无条件禁止跨文件系统硬链接”的过强断言。

### 文件与生成边界

- 知识唯一源为 `apps/web/src/lib/data/cs102-knowledge.ts`；`scripts/generate-knowledge-json.mjs` 只同步端侧 `knowledge-chunks.json` 的 `$[77].text` 与 `$[77].source`（`id=cs102_k26`），147 条切片完成逐字段一致性校验。
- `cs102_q15` 只修改 `apps/web/src/lib/data/quizzes.ts` 的 `answer/explanation`；该题 `type=short`，题库生成器复核输出 165 道选择题且端侧索引为 `-1`，因此 `quizzes.json` 无对应对象、产物零差异。
- `scripts/test_cs102_posix_link_facts.py` 独立承载 9 项 POSIX 执行与反例契约，不导入仍含其他事实红灯的混合研究文件。
- 本批不修改主动学习规格、`lesson-experiences.json`、页面、仓储或 `DEVLOG.md`。POSIX 链接事实不产生待同步 Lesson JSON 路径。

### 证据

- **源码确认**：POSIX.1-2024 `<sys/stat.h>`、`link()`、`symlink()`、`unlink()` 官方页面本轮均返回 HTTP 200，响应长度分别为 26,577、18,557、14,142、20,383 字节。正文明确文件身份由 `st_dev+st_ino` 组合唯一确定、硬链接共享身份；`link()` 的目录权限/实现例外和条件式 `EXDEV`；`symlink()` 只保存不校验的字符串；`unlink()` 递减链接计数且删除符号链接不影响目标。
- **源码确认**：旧生产内容上 POSIX 目标类 7 项中 6 项通过，唯一生产契约红灯并列出文件身份、同一身份、来源、跨文件系统、目录例外、路径字符串和 unlink 因果共 8 个缺口。
- **源码确认**：只修 Web 源且尚未生成知识 JSON 时，目标类唯一失败为 `cs102_k26` Web/raw 不一致；生成后初版 7/7 通过。主代理随后按 Issue 8 原文发现“无条件不能跨文件系统”过强，契约扩展为实现支持/不支持双输入并让初版文案重新红灯，避免错误绿灯固化。
- **静态诊断通过**：最终 `python -m unittest scripts.test_cs102_posix_link_facts -v` 退出码 0，9 项通过；覆盖相同 `st_ino` 不同 `st_dev`、条件式 `EXDEV`、目录权限与实现支持四状态、悬空/跨文件系统符号链接、unlink 因果，以及多组否定句固定反例。
- **静态诊断通过**：`node scripts/generate-knowledge-json.mjs` 退出码 0，147 条 Web/端侧知识切片完全一致；`node scripts/generate-quizzes-json.mjs` 退出码 0，165 道选择题一致且不包含 Web-only q15；Python 编译退出码 0。
- **静态诊断通过**：暂存后以 `git ls-files` 取得 19 个已跟踪脚本测试模块，退出码 0；133 项运行，132 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的 schema、引用、DAG、层级与 Lesson 路由闭环通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 生产构建成功并生成 10/10 静态页面；HarmonyOS API 12 增量 `assembleHap --no-daemon` 退出码 0，`BUILD SUCCESSFUL in 34 s 163 ms`，仍提示未配置 `signingConfigs`。
- **模拟器通过**：`127.0.0.1:5555 / TCP / Connected / localhost / hdc` 安装最新 unsigned HAP 返回 `install bundle successfully`，启动 `EntryAbility` 返回 `start ability successfully`；UI 树为 `pages/Index`，root bounds `[0,0][1256,2760]`，品牌与今日/课程/学伴/我的四个 Tab 可见。

### 失败与未验证

- 第一次 HDC 安装辅助命令在 PowerShell 解析阶段因压缩后的 `foreach` 缺少空格失败，没有执行设备操作；修正语法后安装、启动与 UI 树读取全部通过。
- **未验证**：本批没有在模拟器走到文件系统 Lesson 的 `cs102_k26` 长文本，也没有在 Web 实际打开简答题 `cs102_q15`；手机、平板、真机和线上 API 未验证。
- 未跟踪后续研究文件 `scripts/test_cs102_filesystem_lesson_facts.py` 中另两个 ext4/k28 与受保护 Lesson 活动契约仍为独立红灯；本批不暂存该文件，也未把跨主题失败写成通过。
- DevEco Agent 未重复调用：`alibaba-cn/qwen3-coder-plus` 当前返回 `403 AllocationQuota.FreeTierOnly`，`deveco/glm-5` 返回 `401 Token refresh failed`，需用户交互执行 `deveco providers login -p deveco` 后才能补专属工具证据；本批使用 Python/Web/Hvigor/HDC 完成分层验证。
- 本批未创建或提交截图、HAP、日志、密钥及本地 IDE 文件。

## 批次三十七：ext4 数据日志模式与崩溃保证边界

### 行为

- `cs102_k28` 不再把 ext4 三种数据模式只列名称，也不再把 XFS、ZFS、Btrfs 混成同一类“日志模式”。内容限定为 ext4/JBD2，并说明日志保护的是写入日志的更新原子性与文件系统元数据一致性。
- `data=journal` 将文件数据和元数据先写入日志；默认 `data=ordered` 只记录元数据，并在提交相关元数据前把文件数据先强制写入主文件系统；`data=writeback` 不保留这项顺序，文件数据可在元数据提交后写入，崩溃后可能暴露旧数据。
- 内容明确 journal commit 不等于所有模式下应用数据已经持久化。Btrfs 按官方 Introduction 定位为写时复制文件系统，并明确不属于 ext4 的三种日志模式。
- 新增独立状态机：同一崩溃事件序列分别执行 journal/ordered/writeback，验证元数据重放与文件数据新/旧状态；无有效 commit 的事务不重放。固定反例拒绝合并三种模式、通用“commit 即数据持久化”和把 Btrfs/ZFS 归入 ext4 模式。

### 文件与生成边界

- 知识唯一源为 `apps/web/src/lib/data/cs102-knowledge.ts`；`scripts/generate-knowledge-json.mjs` 只同步端侧 `knowledge-chunks.json` 的 `$[79].text` 与 `$[79].source`（`id=cs102_k28`），147 条切片完成逐字段一致性校验。
- `scripts/test_cs102_ext4_knowledge_facts.py` 只读取 Web/raw k28，不读取主动学习规格或 `lesson-experiences.json`。两份既有测试同步升级为锁定 k28 的三份官方来源和三种数据模式，不放宽文件系统活动的排序、崩溃、重放、checkpoint 与回收断言。
- 本批未修改 `ACTIVE-LEARNING-SPEC-CS102.md`、受保护的 `lesson-experiences.json`、页面、仓储或 `DEVLOG.md`。

### 受保护 Lesson 待同步字段

- 当前 `$[19].activities[1]`（`id=cs102-文件系统-2`）仍是旧的泛化日志活动。本分支未修改该对象；主线程受控同步时建议只改以下三个叶字段，其他字段不变：
  - `$[19].activities[1].prompt`：`ext4/JBD2 采用简化的元数据预写日志流程。假设一次写操作的日志已提交、尚未 checkpoint 时系统崩溃，请将从请求到重启恢复并回收日志的步骤排列为正确顺序`
  - `$[19].activities[1].feedback`：`本题只推演 ext4/JBD2 已提交元数据日志事务的恢复顺序（知识切片 cs102_k28）：文件系统先将元数据修改记录写入日志并提交（D → E）；在 commit 后、checkpoint 前崩溃（C）时，重启只重放带有效 commit 记录的事务到实际位置（A），完成后才 checkpoint 并回收日志（F），未提交事务不重放。这里的 journal commit 只证明该事务已完整写入日志，不等于所有模式下应用文件数据已经持久化：data=journal、默认 data=ordered 与 data=writeback 的文件数据写入顺序不同。`
  - `$[19].activities[1].source`：`Linux kernel ext4 Journal (JBD2)；Linux kernel ext4 administration guide；知识切片 cs102_k28`
- 规格 `Topic 4 / 知识切片引用 / cs102_k28` 以及主动练习 2 的题目、反馈、来源也需与上述值同步后再生成受保护产物；本批不宣称 Lesson 已完成同步。

### 证据

- **源码确认**：Linux kernel `ext4 Journal (JBD2)`、`ext4 administration guide` 与 Btrfs 官方 `Introduction` 本轮均返回 HTTP 200，响应长度分别为 46,523、41,026、16,446 字节。正文明确默认 ordered 的 metadata-only 日志边界、journal/writeback 差异、ordered 的数据先于元数据提交、writeback 的数据可晚于元数据，以及 Btrfs 的 copy-on-write 定义。
- **源码确认**：旧 k28 上独立目标 7 项中 6 项通过，唯一生产契约红灯并报告三种模式、commit/应用数据、Btrfs/ZFS 分类和三份来源共 10 个缺口；Web/raw 在红灯阶段逐字一致。
- **源码确认**：只修 Web 源、尚未生成端侧 JSON 时，目标 7 项中唯一失败变为 Web/raw k28 不一致，证明测试没有绕过生成链。
- **静态诊断通过**：`node scripts/generate-knowledge-json.mjs` 退出码 0，147 条 Web/端侧知识切片完全一致；最终 `python -m unittest scripts.test_cs102_ext4_knowledge_facts -v` 退出码 0，7 项通过。
- **静态诊断通过**：首次完整 Python 回归退出码 1，140 项中精准暴露 2 个旧契约：k28 来源被硬编码为“操作系统概念”、旧泛化 WAL 句子被硬编码。升级为精确官方来源与三模式事实后，同一回归退出码 0；140 项运行，139 项通过，1 项跨 WS02 reducer 契约为预期失败。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的 schema、引用、DAG、层级与 Lesson 路由闭环通过。该命令不证明上述受保护活动文案已同步。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 生产构建成功并生成 10/10 静态页面；HarmonyOS API 12 增量 `assembleHap --no-daemon` 退出码 0，`BUILD SUCCESSFUL in 22 s 814 ms`，仍提示未配置 `signingConfigs`。
- **模拟器通过**：`127.0.0.1:5555 / TCP / Connected / localhost / hdc` 安装最新 unsigned HAP 和启动 `EntryAbility` 均成功；UI 树为 `pages/Index`，root bounds `[0,0][1256,2760]`。

### 失败与未验证

- **未验证**：本批没有在模拟器打开 k28 长文本；受保护 Lesson 三字段和规格仍待主线程同步，不能把文件系统互动记为事实一致性通过。
- **未验证**：手机、平板、真机、线上 API 与 DevEco Agent 专属工具未验证；模型状态沿用批次三十六记录，不重复消耗受阻模型。
- 未跟踪混合研究文件 `scripts/test_cs102_filesystem_lesson_facts.py` 仍保留且不暂存。本批未创建或提交截图、HAP、日志、密钥及本地 IDE 文件。

## 批次三十八：System V 与 POSIX 消息队列接收语义边界

### 行为

- `cs102_q54` 不再把 System V 的消息类型选择规则泛化成所有消息队列。题面明确限定 System V 消息队列，并以管道不保留消息边界的字节流语义作为比较前提。
- 正确选项 B 明确 System V 消息队列保留消息边界并可按消息类型选择接收；不再用没有边界定义的“消息有格式”描述核心能力，也不再暗示通信速度必然更快。
- 解释按 POSIX.1-2024 展开 `msgrcv()` 的三种 `msgtyp` 规则：0 取队首、正值取该类型首条、负值取类型不大于绝对值的最低类型首条。
- 解释同时区分 POSIX 消息队列：`mq_receive()` 先选最高优先级，再取该优先级中最早入队的消息，不提供 System V 的 `msgtyp` 类型筛选；删除“消息队列是内核维护的链表”这一非标准实现断言。
- 新增可执行选择模型，用同一组消息证明 System V 类型筛选与 POSIX 优先级筛选会得到不同结果；另覆盖 `msgtyp=0`、负 `msgtyp`、同优先级 FIFO、正确 fixture 与旧泛化 fixture。

### 文件与生成边界

- 题库唯一源为 `apps/web/src/lib/data/quizzes.ts`；`scripts/generate-quizzes-json.mjs` 生成 HarmonyOS `quizzes.json` 并校验 165 道选择题逐字段一致。
- 端侧精确变化仅为 `$[106].question`、`$[106].options[0]`、`$[106].options[1]` 与 `$[106].explanation`（`id=cs102_q54`）。`answer=B`、`difficulty=medium` 和标签 `IPC机制/结构操作/应用推理` 均不变。
- `scripts/test_cs102_message_queue_quiz_facts.py` 是本批独立契约；其他未跟踪 CS101 二次探测、CS102 文件系统与管道研究文件均保留但不纳入本批。
- 本批不修改主动学习规格、受保护的 `lesson-experiences.json`、页面、仓储或 `DEVLOG.md`。q54 是独立题库事实，不产生待同步 Lesson JSON 路径；Lesson 文件零差异检查退出码 0。

### 证据

- **源码确认**：POSIX.1-2024 `msgsnd()`、`msgrcv()`、`mq_send()`、`mq_receive()` 与 Base Definitions 3.206 官方页面本轮均读取 HTTP 200。正文分别确认正整数 `mtype`、`msgtyp` 三分支、高优先级在前且同优先级新消息在后、最高优先级中最早消息，以及只定义消息队列对象和可观察移除顺序而不规定链表实现。
- **源码确认**：Linux man-pages `pipe(7)` 官方页面读取 HTTP 200，响应长度 21,854 字节；正文明确管道是没有消息边界概念的字节流。独立子 agent 的只读核验结论由主代理按上述官方正文复核，未直接采用未经复核的文案。
- **源码确认**：修正前 `python scripts/test_cs102_message_queue_quiz_facts.py` 退出码 1；6 项中 5 项通过，唯一生产契约红灯并报告 System V 范围、`msgtyp`、POSIX 优先级/FIFO 和链表实现四类缺口。
- **源码确认**：只修 Web 唯一源、尚未生成端侧 JSON 时，目标测试仍退出码 1；6 项中 5 项通过，唯一失败变为 Web/raw q54 不一致，证明契约没有绕过生成链。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs` 退出码 0，165 道端侧选择题与 Web 唯一源完全一致；最终 `python -m unittest scripts.test_cs102_message_queue_quiz_facts -v` 与 Python 编译均退出码 0，6 项通过。
- **静态诊断通过**：以 `git ls-files scripts` 取得全部已跟踪测试模块并显式加入本批契约，退出码 0；146 项运行，145 项通过，1 项跨 WS02 reducer 契约为预期失败。其他三个未跟踪研究文件未计入通过数。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的 schema、引用、DAG、层级与 Lesson 路由闭环通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 生产构建成功并生成 10/10 静态页面；HarmonyOS API 12 增量 `assembleHap --no-daemon` 退出码 0，资源与 ArkTS 编译成功，`BUILD SUCCESSFUL in 32 s 97 ms`，仍提示未配置 `signingConfigs`。

### 失败与未验证

- **未验证**：本批没有争抢可能被其他 worktree 覆盖的模拟器运行态，未在端侧实际打开 `cs102_q54`；手机、平板、真机和线上 API 未验证。沿用此前安装启动证据仅证明既有 HAP 可运行，不证明本批新题面已渲染。
- DevEco Agent 未重复调用：任何 `openai/*` 均被禁止，`alibaba-cn/qwen3-coder-plus` 已确认 `403 AllocationQuota.FreeTierOnly`，`deveco/glm-5` 已确认 `401 Token refresh failed`；本批使用 Python、Web 与直接 Hvigor 完成静态和构建验证。
- 本批未创建或提交截图、HAP、日志、密钥及本地 IDE 文件。

## 批次三十九：匿名管道描述符传递与容量边界

### 行为

- `cs102_q53` 不再把普通管道只概括为“半双工”，而按 POSIX/Linux 精确表述为单向字节流。正确选项 B 明确常见流程是在 `fork` 后由亲缘进程共享端点描述符。
- 解释删除“普通管道只能用于具有共同祖先的进程”这一绝对限制。`fork()` 继承是常见交接方式，但任何持有对应文件描述符的进程都可使用端点；Linux 的 UNIX 域套接字可用 `SCM_RIGHTS` 把打开文件描述的引用传给无亲缘关系进程。
- 解释删除“固定大小缓冲区”断言。Linux 管道容量有限但可通过 `F_GETPIPE_SZ` 查询，并在权限与系统资源约束内用 `F_SETPIPE_SZ` 请求调整；内核可能向上取整，函数返回实际容量。
- 新增描述符注册表执行模型，分别覆盖 `fork()` 继承与 `SCM_RIGHTS` 传递；容量模型覆盖请求值小于页大小时取整、返回容量不小于请求值、非特权请求超过上限，以及缩容低于已缓冲字节时精确 `errno.EBUSY`。
- 契约同时拒绝旧绝对亲缘/固定容量 fixture，以及“包含 SCM_RIGHTS 与无亲缘关键词但声称不能传递”的否定句误绿。

### 文件与生成边界

- 题库唯一源为 `apps/web/src/lib/data/quizzes.ts`；`scripts/generate-quizzes-json.mjs` 生成 HarmonyOS `quizzes.json` 并校验 165 道选择题逐字段一致。
- 端侧精确变化仅为 `$[105].question`、`$[105].options[0]`、`$[105].options[1]`、`$[105].options[2]`、`$[105].options[3]` 与 `$[105].explanation`（`id=cs102_q53`）。`answer=B`、`difficulty=easy` 和标签 `IPC机制/状态推演/基础识别` 均不变。
- `scripts/test_cs102_pipe_quiz_facts.py` 是本批独立契约；CS101 二次探测与 CS102 文件系统两个未跟踪研究文件均保留但不纳入本批。
- 本批不修改主动学习规格、受保护的 `lesson-experiences.json`、页面、仓储或 `DEVLOG.md`。现有管道 Lesson 活动独立推演 EOF/描述符关闭，q53 修订不产生待同步 Lesson JSON 路径；Lesson 文件零差异检查退出码 0。

### 证据

- **源码确认**：POSIX.1-2024 `pipe()` 官方页面读取 HTTP 200，响应长度 12,554 字节；正文只规定读端、写端文件描述符及对应打开文件描述，没有进程亲缘前置条件。
- **源码确认**：Linux man-pages `unix(7)`、`pipe(7)` 与 `F_GETPIPE_SZ(2const)` 官方页面均读取 HTTP 200，响应长度分别为 47,008、21,854、10,370 字节。正文明确 `SCM_RIGHTS` 传递的是打开文件描述的引用、管道是没有消息边界的单向字节流，以及容量查询、调整、页大小取整、实际容量返回、资源上限与 `EBUSY` 边界。
- **源码确认**：修正前 `python -m unittest scripts.test_cs102_pipe_quiz_facts -v` 退出码 1；6 项中 5 项通过，唯一生产契约红灯并报告绝对亲缘限制、描述符传递、固定容量和容量控制四类缺口。
- **源码确认**：修正 Web 源并扩展为 7 项契约、尚未生成端侧 JSON 时，6 项通过，唯一失败变为 Web/raw q53 不一致，证明契约没有绕过生成链。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs` 退出码 0，165 道端侧选择题与 Web 唯一源完全一致；最终 `python -m unittest scripts.test_cs102_pipe_quiz_facts -v` 与 Python 编译均退出码 0，7 项通过。
- **静态诊断通过**：以 `git ls-files scripts` 取得全部已跟踪测试模块并显式加入本批契约，退出码 0；153 项运行，152 项通过，1 项跨 WS02 reducer 契约为预期失败。其他两个未跟踪研究文件未计入通过数。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 切片、165 题和 33 experience 的 schema、引用、DAG、层级与 Lesson 路由闭环通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；13 个测试文件、167 项测试通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 生产构建成功并生成 10/10 静态页面；HarmonyOS API 12 增量 `assembleHap --no-daemon` 退出码 0，资源与 ArkTS 编译成功，`BUILD SUCCESSFUL in 34 s 838 ms`，仍提示未配置 `signingConfigs`。
- **源码确认**：HDC 只读设备列表为 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`。

### 失败与未验证

- 子 agent 复核指出初版研究契约不应强制“半双工”，且原容量模型错误承诺返回请求值；主代理按 POSIX/Linux 原文改为单向字节流，并补页大小取整、实际容量与 `EBUSY` 固定输入后才纳入本批。
- **未验证**：为避免覆盖其他 worktree 的模拟器应用状态，本批没有安装或启动新 HAP，也未在端侧实际打开 `cs102_q53`；手机、平板、真机和线上 API 未验证。此前安装启动证据不证明本批新题面已渲染。
- DevEco Agent 未重复调用：任何 `openai/*` 均被禁止，`alibaba-cn/qwen3-coder-plus` 已确认 `403 AllocationQuota.FreeTierOnly`，`deveco/glm-5` 已确认 `401 Token refresh failed`；本批使用 Python、Web、直接 Hvigor 与 HDC 只读设备检查完成分层验证。
- 本批未创建或提交截图、HAP、日志、密钥及本地 IDE 文件。
