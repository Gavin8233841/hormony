# 鸿学伴端侧前端产品化执行手册（2026-07-03）

本手册把资源深猎结果转成主线 Codex 可执行的 2-3 周落地节奏。默认边界：HarmonyOS API 12、ArkUI 原生优先、端侧 ArkData 为持久状态源、不新增未验证依赖、不下载未建账资产。

## 1. 交付原则

1. 先把现有 ArkUI 组件做成成熟学习产品体验，再评估第三方包。
2. 所有学习状态必须来自真实本地事件、题组评分、错题记录或课程进度。
3. 学生端文案不暴露 Agent、RAG、Retrieval、Trace 等工程词。
4. 所有新素材进入 HAP 前必须在资产账本补齐 URL、许可证、作者、哈希、体积、用途和运行证据。
5. 每批改动都要按 `AGENTS.md` 做增量构建；涉及页面视觉必须补模拟器 UI 树和截图。

## 2. 第 1 周：P0 原生体验收紧

### 2.1 Chat Markdown 与代码学习

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Chat.ets` |
| 当前基础 | 已有标题、引用、任务列表、代码块语言栏、行号、横向滚动、“解释这段” |
| 改造 | 表格拆成表头/行并横向滚动；增加行内代码和粗体白名单；链接只显示文本和域名，不自动外跳；大代码块折叠到安全高度 |
| 验收 | 长代码、表格、引用、任务列表、失败消息各一张截图；Chat SSE 过程中不闪烁，不把工程 trace 暴露给学生 |

### 2.2 AI 出题与计划生成反馈

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/common/Builders.ets`、`apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`、`apps/harmonyos/entry/src/main/ets/pages/Plan.ets` |
| 当前基础 | `StagedProgress()` 已被 Chat、Plan、Quiz 使用 |
| 改造 | 失败态统一：错误说明、保留输入、重试、返回编辑；成功态给下一动作；阶段进度不超过 90%，完成后由真实响应驱动 |
| 验收 | 断网、HTTP 4xx、HTTP 5xx、模型超时、取消请求路径都不清空主题、难度和目标 |

### 2.3 Quiz / Practice 结果复盘

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Quiz.ets`、`apps/harmonyos/entry/src/main/ets/pages/Practice.ets`、`apps/harmonyos/entry/src/main/ets/common/Builders.ets` |
| 改造 | 结果页按标签汇总：本次正确率、错题数、样本数、掌握等级变化、下一步动作 |
| 下一步动作 | 复盘错题、再练同标签 2-3 题、学习主题、向学伴追问 |
| 验收 | 全对、部分错、全错、评分数据缺失、低样本数五种状态截图；按钮都能到真实页面 |

### 2.4 标签洞察等级

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Profile.ets`、`apps/harmonyos/entry/src/main/ets/pages/ActivityRecords.ets`、必要时只读复核 `LearningMetadataModels.ets` |
| 不改 schema 的等级 | 未开始、尝试、熟悉、熟练、掌握 |
| 推导 | 使用 `totalQuestions`、`correctQuestions`、`wrongQuestions`、`accuracy`、最近练习时间；样本不足时显示“先完成 2 题建立基线” |
| 验收 | 颜色不是唯一信息；每行同时显示等级文本、进度条、样本数、错题数和下一步 |

### 2.5 错题追问

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/MistakeBook.ets`、`apps/harmonyos/entry/src/main/ets/pages/Chat.ets` |
| 改造 | 错题卡分组：未复盘、已追问、已解决；追问预填题干、选项、我的答案、正确答案、解析、标签 |
| 验收 | 不自动发送；用户确认后才进入真实 Chat SSE；已解决题不再默认排在顶部 |

## 3. 第 2 周：P1 结构化产品感

### 3.1 学习地图星云图可读性

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets` |
| 改造 | 边增加方向箭头；选中节点时一跳前置/后继高亮，非邻域降透明；节点外环表示错题量或练习量；图例解释颜色、外环、箭头、线型 |
| 数据来源 | `TopicRelation.prerequisiteIds`、`TopicMastery`、`LessonProgress` |
| 验收 | 任意节点截图能看出前置、后继、当前推荐和锁定原因；标签不重叠 |

### 3.2 首页学习任务

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/HomeContent.ets`、`apps/harmonyos/entry/src/main/ets/pages/Plan.ets` |
| 改造 | 首页只突出今日主任务、到期复习、连续学习状态；完成后给轻量收束，不堆无关卡片 |
| 验收 | 无今日任务、1 个任务、多任务、全完成四种状态截图；任务均来自本地计划和学习事件 |

### 3.3 ActivityRecords 视图切换

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/ActivityRecords.ets` |
| 改造 | 增加 3-5 个轻量视图：日期、标签、课程、错因、待复习；每个视图有空态 |
| 验收 | 不做复杂数据库 UI；移动端一屏内可理解当前筛选 |

### 3.4 Lesson 概念玩具样板

| 项目 | 内容 |
|---|---|
| 目标文件 | `apps/harmonyos/entry/src/main/ets/pages/Lesson.ets` |
| 首批主题 | 栈/队列、TCP 三次握手、进程调度时间线 |
| 改造 | 每张卡只有一个主操作：选择、排序或揭示；提交后显示“你的推演 / 标准答案 / 差异点 / 下一题” |
| 验收 | 每门课程至少一个样板截图；不执行任意用户代码 |

### 3.5 原生正反馈

| 项目 | 内容 |
|---|---|
| 目标文件 | `Achievements.ets`、`Quiz.ets`、`Practice.ets`、`HomeContent.ets` |
| 改造 | 使用 `animateTo`、`keyframeAnimateTo`、`SymbolGlyph` 做 600-1200ms 局部反馈 |
| 触发 | 全对、成就解锁、当天任务完成、连续学习达成 |
| 验收 | 动效不遮挡解析和下一步按钮；低分或错题复盘不播放庆祝反馈 |

## 4. 第 3 周：单项 proof 与资产试验

### 4.1 OHPM 单包 proof

| 顺序 | 资源 | 进入条件 | 验收 |
|---|---|---|---|
| 1 | `@luvi/lv-markdown-in` | 独立 proof 分支，一次只装一个包 | API 12 构建、长 Markdown、表格、代码块、流式更新、包体、依赖许可证 |
| 2 | `@ohos/mpchart` | 原生 Progress/Grid 无法满足趋势图时 | API 12 构建、标签趋势图截图、包体 |
| 3 | `@ohos/lottie-turbo` | 只有原生动效无法满足成就反馈时 | API 12 构建、模拟器、真机、销毁生命周期、HAP 体积 |

proof 不通过时立即回到原生实现，不把依赖留在主线。

### 4.2 单素材试验

| 资源 | 用途 | 进入条件 |
|---|---|---|
| Tabler / Phosphor / Lucide / Iconoir 单 SVG | 系统 Symbol 缺口 | 单图 URL、LICENSE、SHA-256、体积、rawfile 渲染截图 |
| Open Peeps 单张 | 空态亲和插画 | CC0 页面、单图 URL、视觉复核、包体 |
| Mixkit 或 Freesound `CC0` 单音效 | 完成/成就轻提示 | 单音效 URL、许可证、体积、可关闭设置、真机播放 |
| LottieFiles 单动画 | 成就/全对 | Lottie Simple License、作者、JSON 无外链图片/音频、Lottie 包真机通过 |

## 5. 页面级执行清单

| 页面 | 本轮目标 | 成熟产品参照 | 验证 |
|---|---|---|---|
| Chat | Markdown 可读、代码块可学习、过程文案去技术化 | GitHub Docs、Copilot Chat、Codecademy | 构建 + Chat 页面截图 + 新 SSE 回答截图 |
| Quiz | 生成反馈、失败恢复、标签复盘 | Khan、Duolingo Practice | 构建 + 成功/失败路径截图 |
| Practice | 精选练习结果接到再练和追问 | Khan、LeetCode 小题组节奏 | 构建 + 一题错题复盘截图 |
| ActivityRecords | 标签洞察从流水账变为视图 | Notion、Linear | 构建 + 各视图截图 |
| LearningMap | 关系可读，不只是星图装饰 | Obsidian Graph、Khan Mastery | 构建 + 三课程截图 |
| Home | 今日任务与复习收束 | Duolingo Path/Streak | 构建 + 空态/完成态截图 |
| MistakeBook | 错题追问和复习状态 | Linear triage、Codecademy explain | 构建 + 未复盘/已追问/已解决截图 |
| Achievements | 原生正反馈，后续再评估 Lottie | Duolingo feedback | 构建 + 动效前后截图 |

## 6. 每批验证命令

只改 HarmonyOS 代码的最低验证：

```powershell
cd apps/harmonyos
.\hvigorw.bat assembleHap --no-daemon
```

涉及 UI 的验证：

- DevEco MCP `check_ets_files` 对修改文件无诊断。
- 安装当前 HAP 到模拟器。
- 使用 UI 树 bounds 点击，不写死坐标。
- 截图记录设备、方向、分辨率和证据路径。

只改文档时：

- `git diff --check`
- `git status --short`
- 不执行 HarmonyOS 构建，并在 DEVLOG 写明原因。

## 7. 实施红线

- 不升级 `compatibleSdkVersion` / `targetSdkVersion`。
- 不把 Web/CSS/React 库复制到 HarmonyOS。
- 不用 ArkWeb 承载原生页面、Markdown 主体验、庆祝动画或图谱。
- 不执行任意用户代码。
- 不把 OHPM registry 字段写成 API 12 运行通过。
- 不下载、提交或复制未建账资产。
- 不把 OCR、TTS、Lottie、音效、字体、distributedKVStore 写成已通过，除非有对应设备证据。

