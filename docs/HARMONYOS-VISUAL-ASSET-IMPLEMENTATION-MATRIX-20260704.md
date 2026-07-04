# HarmonyOS 视觉资产与端侧实现矩阵（2026-07-04）

本矩阵把资源、竞品机制和当前端侧源码映射到具体文件。默认边界：API 12 不升级，ArkUI 原生优先，不安装未验证依赖，不复制大体积素材，不修改 Web Agent、API、安全和端侧持久层。

## 一、实现分层

| 层级 | 可做内容 | 禁止内容 | 证据 |
|---|---|---|---|
| P0 主线 | 现有 ArkUI、现有数据结构、现有 rawfile 资源、页面内视觉与交互增强 | 新 OHPM 依赖、大体积素材、ArkWeb 承载原生体验 | 源码确认 |
| P1 proof | 单包 `@luvi/lv-markdown-in`、单包 `@ohos/lottie-turbo`、单张插画、单个音效 | 多依赖同时引入、直接进主线资源目录 | 未验证 |
| P2 后置 | 图表库、RichEditor、Rive、音效体系、字体子集化 | 在无真机证据时标记通过 | 未验证 |
| 参考 | 第三方图标、竞品机制、官方样例 | 复制品牌视觉、课程内容、角色、声音 | 线上通过 + 源码确认 |

## 二、文件级落地矩阵

| 模块 | 当前源码基础 | 可采用资源/机制 | 具体改造 | 负责人边界 | 验证 |
|---|---|---|---|---|---|
| `common/Constants.ets` | 已有品牌、功能、背景、星图、按钮禁用态色值 | HarmonyOS 设计令牌收口 | 不盲目扩色；补按钮语义注释和页面使用规范 | Codex 主线程 | ArkTS 诊断 + HAP 构建 |
| `common/Builders.ets` | `StagedProgress`、`AnswerOption`、`ReviewDetailRow` | ArkUI `Progress`、`LoadingProgress`、`SymbolGlyph` | 扩展长任务组件：成功、失败、重试、保留输入 | Codex 主线程 | 断网、4xx、5xx、成功截图 |
| `pages/Chat.ets` | 白名单 Markdown、表格整理、代码块行号、引用、任务项、`解释这段` | Brilliant/Mimo 代码学习机制；`StyledString` 仅研究 | 增加“预测输出”“定位错因”；统一引用卡和链接展示 | Codex 主线程 | 真实 SSE 表格/代码/引用截图 |
| `pages/Quiz.ets` | `generationSteps`、`scoringSteps`、题量选择、标签复盘 | Duolingo/Khan/Quizlet 透明复习与掌握反馈 | 失败后保留条件；结果页错因标签前置；高分轻反馈 | Codex 主线程 | 本地题、AI 题、低分、高分截图 |
| `pages/Plan.ets` | 真实计划接口与页面状态 | `StagedProgress` 长任务阶段反馈 | 加“读取画像、拆目标、排日程、校验可执行” | Codex 主线程 | 成功、失败、重试截图 |
| `pages/LearningMap.ets` | `MapNode`、`MapEdge`、`Line`、推荐节点 | Obsidian Local Graph、Duolingo 路径 | 一跳邻域、箭头、线型图例、外环编码、锁定原因 | Codex 主线程 | 三门课程截图，无标签重叠 |
| `pages/Lesson.ets` | `LessonExperience`、`LearningActivity`、`CodeRunPanel()` | Brilliant 先尝试再讲解；Mimo 代码片段 | 首屏显示现实案例和互动目标；练后展示三出口 | Codex 主线程 | 每门课程至少 1 个互动样例截图 |
| `pages/Profile.ets` | `getTagInsights(5)`、`TagInsightRow()`、`Progress` | Khan mastery、Codecademy skill tracking | 三档标签：待巩固、熟练、稳定；显示题量和错题数 | Trae 可做页面内草案，Codex 复核 | 空、少、多标签截图 |
| `pages/ActivityRecords.ets` | `getTagInsights(4)`、事件时间线 | Anki/Quizlet 到期复习、周目标 | 周目标、标签筛选、到期复习入口 | Trae 可做页面内草案，Codex 复核 | 空、少、多标签截图 |
| `pages/Practice.ets` | 本地练习、错题复盘基础 | Practice Pack、Mastery Challenge | 10 分钟复习包：错题、到期、未练透明排序 | Codex 主线程 | 本地数据驱动截图 |
| `pages/MistakeBook.ets` | 错题复盘入口 | Anki 到期复习 | 显示 `nextReviewAt` 和 intervalDays；到期优先 | Codex 主线程 | 到期/未到期数据截图 |
| `pages/Achievements.ets` | 真实成就进度 | Duolingo 徽章机制，ArkUI 原生轻动画 | 完成任务、修复错题、稳定标签触发轻反馈 | Codex 主线程 | 真实本地事件触发截图 |
| `pages/Knowledge.ets` | 知识检索和引用基础 | Obsidian 一跳知识关联 | 当前知识点相关 Topic、引用材料、下一步练习 | Codex 主线程 | 检索结果与下一步截图 |
| `widget/pages/LearningPlanCard.ets` | 读取当天计划，但硬编码色值 | 设计令牌一致性 | 后续收口色值；服务卡片与主 App 视觉一致 | Codex 主线程 | 卡片截图与主 App 对比 |

## 三、资源到模块映射

| 资源 | 目标模块 | 使用方式 | 进入条件 | 回退方案 |
|---|---|---|---|---|
| 系统 `SymbolGlyph` | 全部页面按钮、空态、标签、结果反馈 | 默认图标体系 | symbol 名从源码或 SDK 核验 | 文本按钮 + 已有 symbol |
| ArkUI `Progress` | Quiz、Lesson、Profile、ActivityRecords、LearningMap | 线性、环形、标签准确率、掌握度 | 已在源码使用 | 文本状态 |
| ArkUI `LoadingProgress` | Chat、Quiz、Plan、公共 Loading | 搭配 `StagedProgress`，禁止孤立转圈 | 已在源码使用 | 内嵌阶段文本 |
| ArkUI `Line` | LearningMap、Profile 时间线 | 先修边、时间线 | 已在源码使用 | 简化列表 |
| ArkUI `animateTo` | 节点点亮、按钮反馈、答对反馈 | 小范围、短时、可关闭思路 | 构建和截图通过 | 静态状态 |
| `promptAction` | 短成功/失败提示 | 少量 Toast，不替代页面 banner | 运行证据 | 页面内 banner |
| `@luvi/lv-markdown-in` | Chat Markdown proof | 独立 proof 页面或分支，不替换主线 | API 12 构建、长表格/代码/引用截图、包体和许可 | 现有 `MarkdownContent()` |
| `@ohos/lottie-turbo` | Achievements、Quiz 成功反馈 proof | 单动画，播放/暂停/销毁 | API 12 构建、真机生命周期、HAP 体积 | ArkUI 原生轻动效 |
| `@ohos/mpchart` | Profile/ActivityRecords 趋势 proof | 单图表，不替代首批标签卡 | API 12 构建、包体、截图 | `Progress` + 列表 |
| Open Peeps | EmptyState proof | 1 张空态插画 | CC0、素材 URL、哈希、体积、模拟器截图 | 系统 Symbol 空态 |
| Mixkit 音效 | 成就或全对反馈 proof | 1 个 300-800ms 音效 | 许可证、体积、可关闭入口、真机播放 | 无音效 |
| Tabler/Phosphor/Lucide/Iconoir | 单图补缺 | 仅在系统 Symbol 无合适表达时使用 | 单 SVG 建账、notice、ArkUI 渲染截图 | 系统 Symbol |
| Noto Sans CJK | 字体缺字 proof | 子集化后单独评估 | OFL、体积、字体注册和渲染证据 | 系统字体 |

## 四、Codex 主线程可做

| 任务 | 原因 |
|---|---|
| 修改 `apps/harmonyos/entry/src/main/ets/common/Builders.ets` | 公共 Builder 会影响多页面状态与错误恢复 |
| 修改 `apps/harmonyos/entry/src/main/ets/common/Constants.ets` | 设计令牌影响全局视觉 |
| 修改 `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` | 涉及 SSE、模型输出、安全展示和本地历史 |
| 修改 `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets` | 涉及题组契约、本地评分、标签画像、错题写入 |
| 修改 `apps/harmonyos/entry/src/main/ets/pages/Practice.ets` 与 `MistakeBook.ets` | 涉及复习排序和本地学习事件 |
| 修改 `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets` | 涉及 DAG 语义、推荐和锁定逻辑 |
| 修改 `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets` | 涉及互动练习写回与学习活动记录 |
| 写入 `oh-package.json5` | 依赖、包体、许可证、构建责任 |
| 复制素材到 `resources/` | 版权、包体、构建和运行责任 |

## 五、Trae 可做

| 任务 | 文件范围 | 输出 |
|---|---|---|
| 页面内只读审计 | `apps/harmonyos/entry/src/main/ets/pages/*.ets` | 列出按钮、空态、加载态、图标语义不一致项，不改文件 |
| 标签洞察 UI 草案 | `Profile.ets`、`ActivityRecords.ets` | 仅页面内展示，不改 repository、schema、API |
| Lesson 数据质量审计 | `lesson-experiences.json` | 字段完整性、互动类型分布、现实案例质量，不改页面 |
| 素材许可证审计 | `docs/` 独立报告 | URL、许可证、作者、体积、风险、证据等级 |
| 视觉验收资料整理 | `screenshots/` 证据目录和独立报告 | 不提交截图，只记录设备、分辨率、页面、结论 |

## 六、必须真机后置

| 能力 | 原因 | 前置证据 |
|---|---|---|
| Lottie 动画 | 原生库、ABI、帧率、销毁生命周期需要设备证据 | API 12 构建 + 真机播放/暂停/销毁 |
| 音效反馈 | 音量、打扰程度、播放延迟需要真实设备 | 单音效授权 + 可关闭入口 + 真机播放 |
| Rive 状态机 | API 12 原生运行链未建立 | 官方运行链 + 构建 + 真机 |
| OCR / TTS / distributedKVStore | 属于设备能力，不在本轮视觉资源主线 | 真机日志和截图 |
| 平板/横屏星图 | 只读源码不能证明适配 | 设备、方向、分辨率、截图 |

## 七、只做参考

| 资源 | 参考方式 | 不做内容 |
|---|---|---|
| Duolingo | 学习路径、习惯反馈、回访节奏 | 不复制角色、音效、路径视觉 |
| Khan Academy | mastery 阶段和挑战机制 | 不复制课程内容和 UI 文案 |
| Brilliant | 先尝试再讲解 | 不复制题目和插画 |
| Mimo | 移动端代码片段学习 | 不执行任意用户代码 |
| GitHub Skills | 小步骤任务和检查点 | 不暗示端侧拥有 CI 自动判题 |
| Obsidian | 一跳关联 | 不上全图力导向 |
| Quizlet / Anki | 透明复习排序和到期复习 | 不做黑箱分数 |

## 八、验证路线

| 层级 | 命令或证据 | 本轮状态 |
|---|---|---|
| 文档校验 | `git diff --check` | 待执行 |
| HarmonyOS 静态诊断 | DevEco MCP `check_ets_files` | 本轮未改源码，未执行 |
| HAP 构建 | `cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` | 本轮未改源码，未执行 |
| 模拟器视觉 | DevEco MCP UI 树和截图 | 本轮未执行 |
| 真机 | 设备型号、方向、分辨率、截图或日志 | 未验证 |
| 第三方依赖 | 单包安装、构建、包体、许可证、运行截图 | 未验证 |
| 素材 | URL、许可证、SHA-256、体积、构建、渲染 | 未验证 |
