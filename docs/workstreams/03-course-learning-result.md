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
