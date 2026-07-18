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

## 主线集成补修：写入一致性与下一动作真实性

### 行为

- Lesson 互动只在 `appendStudyEvent()` 成功后加入已练集合；写入中阻止重复提交，写入失败保留答案和反馈，并为客观互动显示“重试保存记录”，自由回答继续保留自评按钮重试。
- Repository 以 Promise 队列串行执行学习事件读改写，并按事件 ID 幂等；`lesson_self_assessment` 事件继续用于互动断点和成就，但在题数默认值之前从客观标签统计中排除。
- 星图按 `nextActionTarget()` 返回目标的 `lessonCompleted/mastery` 决定进入 Lesson 或 Practice；前置、后继文案与真实目标页面保持一致。
- Knowledge 为每次检索分配单调版本，成功、失败 fallback 和 loading 发布均只接受最新请求，旧响应不再覆盖新结果或证据查询快照。
- 课程目录在课程已加载但续学位置读取失败时展示非阻断提示和重试动作；重试开始时清除旧提示，成功后恢复正常列表。

### 文件

- `apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Course.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Knowledge.ets`
- `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets`
- `scripts/test_course_resume_contract.py`
- `scripts/test_knowledge_navigation_contract.py`
- `scripts/test_learning_map_navigation_contract.py`
- `scripts/test_lesson_activity_resume_contract.py`

### 证据

- **静态诊断通过**：`python -m unittest scripts.test_course_resume_contract scripts.test_knowledge_navigation_contract scripts.test_lesson_activity_resume_contract scripts.test_learning_map_navigation_contract scripts.test_validate_topic_relations -v`，退出码 0，33/33 通过。
- **静态诊断通过**：`node scripts/test-achievements-next-action.mjs`，退出码 0，4/4 通过。
- **静态诊断通过**：`node --test scripts/test-proactive-learning-service.mjs scripts/test-proactive-delivery-contracts.mjs`，退出码 0，33/33 通过。
- **静态诊断通过**：`.\scripts\harmonyos-app-smoke.ps1 -SelfTest`，退出码 0，9/9 通过；只证明 UI 树和 bounds 脚本门禁。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，退出码 0，`BUILD SUCCESSFUL in 26 s 207 ms`；仍提示未配置 `signingConfigs`。

### 未验证

- **未验证**：`hdc list targets` 返回 `[Empty]`；课程续学提示、互动保存失败重试、星图 CTA 和并发检索的模拟器/真机交互均未验证。
- **未验证**：真实 ArkData 故障注入与进程重启并发恢复未验证；当前证据为源码契约、脚本执行和 HAP 构建。
- **未验证**：HAP 未配置正式签名，安装与竞赛提交包可用性未验证。

## 主线集成：ext4 数据日志模式边界

### 行为

- `cs102_k28` 限定为 ext4/JBD2：`data=journal` 将文件数据和元数据先写入日志；默认 `data=ordered` 只记录元数据，并在提交相关元数据前把关联文件数据写入主文件系统；`data=writeback` 不保留该顺序，崩溃后可能暴露旧数据。
- 内容明确 journal commit 不能推出所有模式下应用数据已经持久化，不再把 XFS、ZFS、Btrfs 混写成 ext4 的三种数据模式；Btrfs 只按官方 Introduction 说明为 copy on write 文件系统。
- Web `cs102-knowledge.ts` 与端侧 `knowledge-chunks.json` 只同步 `cs102_k28` 的 `text/source`；新增独立 Python 契约逐字段比较两端，并用三模式事件模型、固定错误文本和来源断言防止事实回退。
- 本批不修改受保护的 `lesson-experiences.json`。其中 `cs102-文件系统-2` 仍是旧活动文案，不能据此宣称 Lesson 互动已经完成 ext4 三模式同步。

### 来源与文件

- Linux kernel ext4 Journal (JBD2)：`https://docs.kernel.org/filesystems/ext4/journal.html`；2026-07-18 访问，HTTP 200，46,523 bytes，SHA-256 `93a525427430e90363101fd3e763f6ff51efa240596ddba5e0403f2d949c9d64`。
- Linux kernel ext4 administration guide：`https://docs.kernel.org/admin-guide/ext4.html`；2026-07-18 访问，HTTP 200，41,026 bytes，SHA-256 `3885fe8c133d866972b87d103e02777b676551b5c5b523256eadc580a49ae0f5`。
- Btrfs documentation Introduction：`https://btrfs.readthedocs.io/en/latest/Introduction.html`；2026-07-18 访问，HTTP 200，16,446 bytes，SHA-256 `1459973f84df3b04e266970885db6a8a8219c704d5b7e799b3e6a67edc018fec`。
- `apps/web/src/lib/data/cs102-knowledge.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`
- `scripts/test_cs102_ext4_knowledge_facts.py`
- `docs/workstreams/03-course-learning-result.md`

### 证据与未验证

- **源码确认**：三份官方页面本轮均返回 HTTP 200；URL、字节数和响应 SHA-256 已固定在上方，正文分别明确 `data=journal`、默认 `data=ordered`、`data=writeback` 的数据顺序，以及 Btrfs 的 copy on write 定义。
- **静态诊断通过**：`python -m unittest scripts.test_cs102_ext4_knowledge_facts -v` 退出码 0，10/10 通过；覆盖三模式事件状态、未提交事务、通用持久化误称、矛盾 journal 子句、Btrfs/ZFS 分类、TypeScript 注释与未导出对象误绿、五字段双端一致性和精确 URL 固定。
- **静态诊断通过**：`python scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 知识切片、165 道题和 33 份学习体验的 schema、唯一性、引用、DAG、连通性、单根、层级与 Lesson 路由一致性全部通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；36 个测试文件、437/437 通过。
- **构建通过**：Web `pnpm build` 退出码 0，Next.js 14.2.18 生成 10/10 静态页面和 26.8 kB middleware；HarmonyOS API 12 增量 HAP 退出码 0，`CompileArkTS`、`PackageHap`、`PackingCheck` 通过，`BUILD SUCCESSFUL in 31 s 82 ms`，仍未配置签名。
- **未验证**：本批尚未在模拟器打开 k28 长文本；屏幕阅读器、手机/平板排版、真机和线上 API 未验证。
- **未验证**：主线没有 WS03 分支使用的 `generate-knowledge-json.mjs`，因此没有记录不存在的生成命令；本批以两个明确字段的受控同步和可执行逐字段一致性契约证明双端内容一致。

## 主线集成：System V 与 POSIX 消息队列接收语义

### 行为

- `cs102_q54` 题面限定为 System V 消息队列，不再把所有“消息队列”笼统描述为按类型接收，也不再把标准未规定的“内核链表”当成统一实现事实。
- 解释明确 System V `msgrcv()`：`msgtyp=0` 取队首，正值取该类型首条，负值取不大于绝对值的最低类型首条；同时区分 POSIX `mq_receive()` 的最高优先级优先、同优先级先进先出语义。
- 正确选项继续为 B，但改为可审计的“保留消息边界，并可按消息类型选择性接收”；Web 与端侧只同步 q54 的题面、四个选项和解释，答案、难度、标签及其他题目不变。
- 新契约执行 System V/POSIX 两套选择器、固定旧题反例、Web/raw 五个展示与评分字段一致性；TypeScript 提取只读取 `cs102Quizzes` 导出区间并先剥离注释，导出外或注释内同 ID 对象不能误绿。
- 主线复核发现 `cs102_k45` 与主动学习规格仍混写两套接口；现已同步 Web/端侧知识切片，明确 System V `msgtyp` 三分支、POSIX 优先级/FIFO 规则和标准不限定内部链表实现，并更新规格中的现实案例。
- 契约进一步固定 q54 的完整生产文案、端侧 `courseId/topic/difficulty/tags` 元数据、k45 双端五字段和规格关键句，不再仅依赖关键词存在性判定。

### 来源

- POSIX.1-2024 `msgsnd()`：`https://pubs.opengroup.org/onlinepubs/9799919799/functions/msgsnd.html`；2026-07-18 HTTP 200，11,430 bytes，SHA-256 `7485234efb4fb1046d74c6fe21a9b2a9e5fac75a161ea543877dc3e1d1768ab2`。
- POSIX.1-2024 `msgrcv()`：`https://pubs.opengroup.org/onlinepubs/9799919799/functions/msgrcv.html`；HTTP 200，12,347 bytes，SHA-256 `e38afc7a56c683d335bc9eadae1c9c65116ee50cff112b9137a6b7af7e7551f6`。
- POSIX.1-2024 `mq_receive()`：`https://pubs.opengroup.org/onlinepubs/9799919799/functions/mq_receive.html`；HTTP 200，11,838 bytes，SHA-256 `c79acf92b7a0ef1344e1e39da5ccc61e2e87c7f40a0df60e97513506258a6cbd`。
- POSIX.1-2024 `mq_send()`：`https://pubs.opengroup.org/onlinepubs/9799919799/functions/mq_send.html`；HTTP 200，10,775 bytes，SHA-256 `6927afa42e01a021754bb610a32eb12318234bd2f4f78eeb392d8aebb7ca6fe9`。
- POSIX.1-2024 Base Definitions 3.206：`https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap03.html#tag_03_206`；HTTP 200，182,262 bytes，SHA-256 `0037b423cc292c3cd7c55d347a2273407d156be2a161e56771b08c1c0d421d5a`。
- Linux man-pages `pipe(7)`：`https://man7.org/linux/man-pages/man7/pipe.7.html`；2026-07-18 HTTP 200，解码后 UTF-8 内容 21,870 bytes，SHA-256 `5485983943d2a7d8d94a47705b398ae373036b75a0ded5570f694f8039e19c23`。

### 文件

- `apps/web/src/lib/data/quizzes.ts`
- `apps/web/src/lib/data/cs102-knowledge.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`
- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `scripts/test_cs102_message_queue_quiz_facts.py`
- `docs/workstreams/03-course-learning-result.md`

### 证据

- **源码确认**：只读审查逐页复核 POSIX.1-2024 Issue 8 的 `msgsnd()`、`msgrcv()`、`mq_send()`、`mq_receive()` 与 Base Definitions 3.206；q54 题面、选项和解释符合原文，审查发现并推动修正了原提交遗漏的 k45 与主动学习规格矛盾。
- **静态诊断通过**：`python -B scripts/test_cs102_message_queue_quiz_facts.py` 退出码 0，11/11 通过；覆盖两套选择器、精确生产文案、三条 `msgtyp` 规则、POSIX 反向矛盾、注释/导出外对象误绿、q54 端侧元数据、k45 双端一致性和规格关键句。
- **静态诊断通过**：`python -B scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 知识切片、165 道题和 33 份学习体验的结构、引用、DAG、连通性、层级与 Lesson 路由一致性全部通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；36 个测试文件、437/437 通过。
- **构建通过**：Web `pnpm build` 退出码 0；Next.js 14.2.18 生成 10/10 静态页面与 26.8 kB middleware。
- **构建通过**：HarmonyOS API 12 增量 HAP 退出码 0；`CompileArkTS`、`PackageHap`、`PackingCheck` 完成，`BUILD SUCCESSFUL in 37 s 635 ms`，仍未配置签名。

### 未验证

- **未验证**：HDC 实测 `127.0.0.1:5555 / TCP / Connected / localhost`，但本批没有在该共享设备打开 q54/k45；端侧长文本换行、读屏、答题流程、手机/平板适配、真机和线上 API 均未验证。
- `lesson-experiences.json` 的 `cs102-进程间通信` 现实案例仍含旧的统一“按类型筛选”比喻；该文件当前承载 WS09/用户保留的未提交改动，本批不覆盖也不暂存，已向 WS09 发出精确同步请求，待其独立提交后融合。
- 本批未修改 Lesson 页面、Repository/schema、模型、安全边界、用户保留文件或秘密。

## 主线集成：匿名管道描述符、容量与读取边界

### 行为

- `cs102_q53` 改为可审计的普通匿名管道题：一个管道提供单向、无消息边界的字节流；`fork()` 继承描述符是常见交接方式，但不是接口强制的进程亲缘限制。
- 解释明确 Linux 可通过 UNIX 域套接字 `SCM_RIGHTS` 向其他进程传递打开文件描述的引用；管道容量有限但不是固定 64KB，可用 `F_GETPIPE_SZ` 查询并在权限与系统约束内用 `F_SETPIPE_SZ` 请求调整，内核返回实际容量。
- 主线复核发现原提交遗漏的 `cs102_k44` 和主动学习规格仍传播绝对亲缘、固定容量与错误读取时序；现已同步 Web/端侧知识切片及规格源，补 `<stdio.h>`，并区分已有数据立即返回、读空但仍有写端等待、全部写端关闭后 `read()` 返回 0/EOF。
- 目标契约剥离注释并用字符串感知的平衡方括号扫描精确截取 `cs102Quizzes` 和 `cs102KnowledgeChunks` 数组，固定 q53 完整文案、端侧 `courseId/topic/difficulty/tags`、k44 双端五字段和规格关键句；数组闭合前后或注释内对象不能冒充生产题。同源边界修正一并应用到上一批 q54 契约。

### 来源

- POSIX.1-2024 `pipe()`：`https://pubs.opengroup.org/onlinepubs/9799919799/functions/pipe.html`；2026-07-18 HTTP 200，12,561 bytes，SHA-256 `d8425cee340fdacb4f8b3db37a7ed1bced59e9b8227aed4a0cff387ced8d81f4`。
- POSIX.1-2024 `read()`：`https://pubs.opengroup.org/onlinepubs/9799919799/functions/read.html`；HTTP 200，24,752 bytes，SHA-256 `af724071475054a17dde265a540bc39bd6e5d06da2373729141280adb8fdd744`。
- POSIX.1-2024 `write()`：`https://pubs.opengroup.org/onlinepubs/9799919799/functions/write.html`；HTTP 200，31,921 bytes，SHA-256 `1b45e6a71f8bc9bff702da5633d42c88fd927c1d0efc5bafe7a939d23eb66e6a`。
- Linux man-pages `unix(7)`：`https://man7.org/linux/man-pages/man7/unix.7.html`；HTTP 200，47,026 bytes，SHA-256 `52fb2d4fdeebc96d1f2689e2aa6699f3c081b2141b68098d3b058d738c258cfc`。
- Linux man-pages `pipe(7)`：`https://man7.org/linux/man-pages/man7/pipe.7.html`；HTTP 200，21,870 bytes，SHA-256 `5485983943d2a7d8d94a47705b398ae373036b75a0ded5570f694f8039e19c23`。
- Linux man-pages `F_GETPIPE_SZ(2const)`：`https://man7.org/linux/man-pages/man2/F_GETPIPE_SZ.2const.html`；HTTP 200，10,382 bytes，SHA-256 `4267eae9531d7fbdcbd437e21f3aa159fa9a811ba95ae37d0e70afec9ea6a06d`。

### 文件

- `apps/web/src/lib/data/quizzes.ts`
- `apps/web/src/lib/data/cs102-knowledge.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`
- `docs/ACTIVE-LEARNING-SPEC-CS102.md`
- `scripts/test_cs102_pipe_quiz_facts.py`
- `scripts/test_cs102_message_queue_quiz_facts.py`
- `docs/workstreams/03-course-learning-result.md`

### 证据

- **源码确认**：独立只读审查按 POSIX.1-2024 与 Linux man-pages 逐条核对，确认 q53 的单向字节流、描述符继承/传递、容量查询/调整与返回实际容量表述成立；同时定位并推动修复 k44、规格、测试导出范围和端侧元数据缺口。
- **静态诊断通过**：`python -B scripts/test_cs102_pipe_quiz_facts.py` 退出码 0，11/11 通过；覆盖 `fork`/`SCM_RIGHTS` 描述符模型、容量取整/上限/`EBUSY`、旧绝对限制与否定句、数组前/后/注释对象、精确生产文案、端侧元数据、k44 双端字段和规格读取三阶段。
- **静态诊断通过**：`python -B scripts/test_cs102_message_queue_quiz_facts.py` 退出码 0，11/11 通过；在原有 System V/POSIX 契约上补充数组闭合后同 ID 对象的固定误绿反例。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs` 退出码 0；165 道端侧选择题与 Web 唯一源逐字段一致。
- **静态诊断通过**：`python -B scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 知识切片、165 道题和 33 份学习体验的结构、引用、DAG、连通性、层级与 Lesson 路由门禁全部通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；36 个测试文件、437/437 通过。
- **构建通过**：Web `pnpm build` 退出码 0；Next.js 14.2.18 生成 10/10 静态页面与 26.8 kB middleware。
- **构建通过**：HarmonyOS API 12 增量 HAP 退出码 0；`CompileArkTS`、`PackageHap`、`PackingCheck` 完成，最终复跑 `BUILD SUCCESSFUL in 55 s 920 ms`，仍未配置签名。

### 失败与未验证

- 新增来源固定断言首次运行退出码 1，准确发现测试文档头遗漏已使用的 POSIX `read()` URL；补齐来源后同一套 11 项契约退出码 0。
- 独立复核先发现现实案例仍写“只能父子进程”，修正为“是否持有描述符，而不是亲缘关系”；随后复现数组闭合后对象仍会被旧提取器选中，改用匹配括号扫描后该固定输入按预期抛出断言。
- **未验证**：HDC 仍连接 `127.0.0.1:5555 / TCP / Connected / localhost`，但本批未在共享设备打开 q53/k44；长文本换行、读屏、答题流程、横屏、平板、真机和线上 API 未验证。
- `lesson-experiences.json` 当前承载 WS09/用户保留改动，主线未覆盖或暂存；其 IPC 活动仍是旧文案，已向 WS09 发出从规格源受控生成的精确请求，融合前不能宣称 Lesson 内容已同步。
- 本批未修改 Lesson 页面、Repository/schema、模型、安全边界、用户保留文件或秘密；已知失败的 Alibaba/DevEco Provider 未重试，也未回落到 `openai/*`。

## 主线集成：二次探测可达槽位与覆盖边界

### 行为

- `cs101_q53` 从公式记忆题改为固定可执行输入：单侧 `H_i=(H(key)+i²) mod M`，`M=7`、`H(key)=0`、`i=0..6` 的序列为 `0→1→4→2→2→4→1`，不同槽位严格为 `{0,1,2,4}`。
- 解释删除“4k+3 型质数保证遍历所有位置”的错误断言。质数表长配单侧 `i²` 至少访问一半槽位，负载小于一半时可保证找到空槽，但不保证全表覆盖；`M=7` 仍有 `3/5/6` 不可达。
- 全覆盖示例限定为另一组匹配条件：表长为 2 的幂且偏移 `(i²+i)/2`；契约以 `M=8` 执行得到 `0,1,3,6,2,7,5,4`，验证八个槽位恰好各访问一次。
- 目标契约剥离 TypeScript 注释并用平衡方括号精确截取 `cs101Quizzes`，固定完整 Web 文案、端侧 `courseId/topic/difficulty/tags`、单侧全覆盖反向句和数组前/后/注释对象反例。难度审计同步为真实的七次模运算与去重任务，仍为 `easy`，因为公式和全部输入均已给出且不要求插入状态或证明。

### 来源与许可

- Virginia Tech OpenDSA `Improved Collision Resolution / Quadratic Probing` 源文：`https://opendsa-server.cs.vt.edu/ODSA/Books/Everything/html/_sources/HashCImproved.rst.txt`；2026-07-18 HTTP 200，16,711 bytes，SHA-256 `47018e9d1b61874022b0d9417f92a52f0e9c701980c7ab52736dfdd22115deb5`。
- OpenDSA 仓库 MIT 许可文件：`https://raw.githubusercontent.com/OpenDSA/OpenDSA/master/MIT-license.txt`；HTTP 200，1,135 bytes，SHA-256 `a4d83bb66f3f9058c49a9795583fe20a4256def38e9bc365c76c40affaf20709`。
- 本批只用 OpenDSA 作为事实核验来源；题面、选项、执行序列和中文解释均为项目内编写，没有复制外部课程正文或题库。

### 文件

- `apps/web/src/lib/data/quizzes.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- `docs/QUIZ-DIFFICULTY-AUDIT-CS101.md`
- `scripts/test_cs101_quadratic_probing_quiz_facts.py`
- `docs/workstreams/03-course-learning-result.md`

### 证据

- **源码确认**：独立只读审查复算 q53 与同 home=3 的平移序列，确认数学结论及 OpenDSA 对质数半表、2 的幂/三角偏移全覆盖的描述；同时定位并推动修复真实导出、反向语义、端侧元数据和难度审计四类缺口。
- **静态诊断通过**：`python -B scripts/test_cs101_quadratic_probing_quiz_facts.py` 退出码 0，9/9 通过；覆盖 M=7 单侧序列、M=8 全覆盖组合、旧 4k+3 断言、正反语义共存、完整生产文案、九字段端侧对象、真实导出边界、来源 URL 与难度审计。
- **静态诊断通过**：`node scripts/generate-quizzes-json.mjs` 退出码 0；165 道端侧选择题与 Web 唯一源逐字段一致。
- **静态诊断通过**：`python -B scripts/validate-topic-relations.py` 退出码 0；33 Topic、147 知识切片、165 道题和 33 份学习体验的结构、引用、DAG、连通性、层级与 Lesson 路由门禁全部通过。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均退出码 0；36 个测试文件、437/437 通过。
- **构建通过**：Web `pnpm build` 退出码 0；Next.js 14.2.18 生成 10/10 静态页面与 26.8 kB middleware。
- **构建通过**：HarmonyOS API 12 增量 HAP 退出码 0；`CompileArkTS`、`PackageHap`、`PackingCheck` 完成，`BUILD SUCCESSFUL in 35 s 259 ms`，仍未配置签名。

### 失败与未验证

- 新反向语义正则首次运行把“不能保证”中的“保证”误判为肯定句，目标契约退出码 1；改为按句切分并显式识别否定词后，正确生产文案与固定矛盾输入分别按预期绿/红。
- 同 Topic 的 ACTIVE 规格和 Lesson 明确采用线性探测，其 `17→5` 等状态与本题单侧二次探测不矛盾；本批无需修改受保护的 `lesson-experiences.json`。
- **未验证**：HDC 实测 `127.0.0.1:5555 / TCP / Connected / localhost`，但本批未在共享设备打开 q53；Unicode 公式、箭头、长解释、读屏、答题流程、横屏、平板、真机和线上 API 未验证。
- 本批未调用已知失败的模型 Provider，未回落到 `openai/*`，未修改 Repository/schema、模型、安全边界、用户保留文件或秘密。
