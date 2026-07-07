# Codex 接力：鸿蒙2.0

更新时间：2026-07-07

本文件给下一位接手模型使用。请先读完本文件，再读根目录 `AGENTS.md`。当前主线以 `HEAD`、源码、构建配置和可执行验证为准；旧文档只作为线索，不覆盖当前源码结论。

## 1. 接手前必须执行

```powershell
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
git status --short --branch
git log -5 --oneline
```

随后读取：

1. `AGENTS.md`
2. `docs/MODEL-ROLLOUT-STRATEGY.md`
3. `docs/HARMONY-2.0-INTEGRATION-DECISIONS-20260706.md`
4. `docs/FRONTEND-RESOURCE-ADOPTION.md`
5. `docs/TRAE-BOUNDARY-20260701.md`
6. `DEVLOG.md` 末尾记录

## 2. 当前 Git 状态

- 分支：`main`
- 当前远端同步提交：`9e4ccad docs: 补充 Chat 核查证据`
- 最近提交顺序：
  - `9e4ccad docs: 补充 Chat 核查证据`
  - `a3ddd5e feat: 补验鸿蒙2.0 Chat 发送状态`
  - `c57d594 feat: 强化学习计划生成反馈`
  - `fbfa31f feat: 强化 AI 出题等待反馈`
  - `fea46ee fix: 收束学伴 Markdown 表格碎片`
- 当前工作区保留项：
  - `.trae/progress.json` 有内容 diff，禁止提交。该文件包含旧的模型名误判记录，不可作为当前模型事实来源。
  - `.tmp/` 未跟踪，本地验收证据约 319 个文件，约 176.9 MB，禁止提交。
  - `assets/` 未跟踪，前端资源约 52 个文件，约 189 KB，禁止整包提交。
  - `harmonyos-tools-survey/` 未跟踪，约 1 个文件，禁止无关提交。
  - `hongxueban-showcase.zip` 未跟踪，约 6.58 MB，禁止提交。
  - `hongxueban-showcase/` 未跟踪，约 94 个文件，约 12.3 MB，禁止整包提交。
  - `ponytail-codex-deploy-prompt.md` 未跟踪，禁止无关提交。
  - `鸿学伴-创意提案.html` 未跟踪，约 3.59 MB，禁止无关提交。

不要为了让工作区“看起来干净”执行 `git clean`、递归删除、目录删除、通配符删除、`git reset --hard` 或批量移动。确需清理时，必须先列绝对路径并获得用户明确确认。

## 3. 产品边界与核心记忆

- `apps/harmonyos` 是竞赛移动端交付物。
- `apps/web` 同时承载 Web 界面和云端 API。
- 生产云端按无状态服务设计；画像、计划、进度、答题结果、错题、连续学习和最近对话以 HarmonyOS 端 ArkData 为持久状态源。
- 不得用静态回复、本地模板、随机结果或测试替身伪造真实 Agent、模型调用或线上验收成功。
- 模型名只能以 `docs/MODEL-ROLLOUT-STRATEGY.md`、线上 Health 和部署环境精确值为准。`.trae/progress.json` 中出现过 `doubao-seed-1-6-250615` 的旧记录，不能当作当前生产模型。
- 端侧当前目标是 HarmonyOS API 12：`compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)`。
- HarmonyOS 当前 `oh-package.json5` 无第三方依赖。不得未验证就写入 OHPM 依赖。
- ArkWeb 不得承载原生页面或庆祝动画。
- Lottie、OCR、TTS、distributedKVStore 仍需真机证据，不能标记通过。

## 4. 模型与云端

- 当前生产模型：`doubao-seed-2-1-pro-260628`
- 成本优先备选：`doubao-seed-2-0-lite-260215`
- 默认模型配置源码：`apps/web/src/lib/agents/model.ts`
  - 默认 Base URL：`https://ark.cn-beijing.volces.com/api/v3`
  - 默认模型名：`doubao-seed-2-1-pro-260628`
  - 默认模型超时：`45000ms`
  - 环境变量：`MODEL_API_KEY`、`MODEL_BASE_URL`、`MODEL_NAME`、`MODEL_TIMEOUT_MS`
  - 模型调用统一走 `callModel()` / `callModelWithHistory()`，内部使用 `AbortController` 与超时清理。
- Agent 编排源码：`apps/web/src/lib/agents/orchestrator.ts`
  - 意图：`tutor`、`plan`、`quiz`、`evaluate`、`general`
  - 前置 Agent：Profile，Tutor/General 再加 Retrieval
  - 主 Agent：Planner、Quiz、Evaluator、Tutor
  - Safety 必须在正文输出前完成，失败走结构化错误，不做假成功。
- 端侧 API 配置：`apps/harmonyos/entry/src/main/ets/common/Constants.ets`
  - `BASE_URL = 'https://hormony-ruddy.vercel.app'`
  - `SIMULATOR_GATEWAY_URL = 'http://10.0.2.2:3001'`
  - `API_BASE_URLS = [BASE_URL, SIMULATOR_GATEWAY_URL]`
- 模拟器网关脚本：`scripts/simulator-api-gateway.mjs`
  - 监听 `0.0.0.0:3001`
  - 固定转发线上 `https://hormony-ruddy.vercel.app`
  - 只允许 `/api/`，不记录请求体或凭证。

## 5. 数据与内容资产

端侧 rawfile 数据源位置：

- `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/external-resources.json`

当前数据规模：

- 端侧题库：165 道选择题。
- Topic 覆盖：33 个 Topic，每个 Topic 正好 5 道选择题。
- 课程题量：`cs101=60`、`cs102=50`、`cs103=55`。
- 知识切片：147 条，分布 `cs101=52`、`cs102=48`、`cs103=47`。
- Topic 关系：33 个，分布 `cs101=12`、`cs102=10`、`cs103=11`。
- Lesson 体验：33 个。
- 外部资源：36 条。

课程与 Topic：

- `cs101` 数据结构：数组与线性表、链表、栈与队列、二叉树与BST、AVL树与红黑树、图的表示与遍历、排序算法、动态规划、哈希表、堆与优先队列、最短路径算法、贪心算法与分治。
- `cs102` 操作系统：进程与线程、CPU调度算法、内存管理基础、虚拟内存与分页、文件系统、死锁、同步与互斥、I/O系统与磁盘调度、分段与段页式、进程间通信。
- `cs103` 计算机网络：OSI与TCP/IP模型、TCP握手与挥手、TCP流量控制与拥塞控制、UDP协议、HTTP协议、HTTPS与TLS、DNS系统、路由算法与协议、网络安全基础、物理层与数据链路层、网络层与IP协议。

数据单一来源规则：

- Web 题库源文件：`apps/web/src/lib/data/quizzes.ts`
- 端侧题库产物：`apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- 生成脚本：`scripts/generate-quizzes-json.mjs`
- 关系校验脚本：`scripts/validate-topic-relations.py`

本次只读校验：

```powershell
python scripts/validate-topic-relations.py
```

结果：`ALL CHECKS PASSED`。通过项包括 schema、ID 唯一性、引用完整性、DAG、课程连通性、单根节点、level 一致性、知识切片 Topic 一致性、题库 Topic 一致性。

## 6. HarmonyOS 端结构

核心通用层：

- `common/Constants.ets`：API 地址、超时、颜色、圆角、日志等常量。
- `common/HttpClient.ets`：GET/POST/PATCH/SSE 客户端；SSE 支持 `dataReceive`、`dataEnd`、多行 `data:`、`\r\n` 归一化、done 清理、fallback base URL。
- `common/LocalLearningRepository.ets`：ArkData 本地学习数据源。
- `common/LearningContentRepository.ets`：rawfile 学习内容仓储。
- `common/Builders.ets`：共用 Builder，包括标题、空态、加载态、分阶段进度、选项和复盘行。
- `model/DataModels.ets` 与 `model/LearningMetadataModels.ets`：端侧结构模型。

主导航：

- `pages/Index.ets`：四个底部 Tab：今日、课程、学伴、我的。
- `entryability/EntryAbility.ets`：初始化 ArkData，写入课程目录：`cs101 数据结构`、`cs102 操作系统`、`cs103 计算机网络`；启动时探测 `cloudAgentReady`。

页面职责：

- `HomeContent.ets`：首页下一步行动，优先到期错题、薄弱标签、今日任务、当前课程。
- `Course.ets` / `CourseDetail.ets`：课程列表与主题入口，AI 测验入口已可见。
- `Lesson.ets`：课程阅读与互动练习，互动练习可导向学伴讲解和同标签测验。
- `Practice.ets`：本地练习。
- `Quiz.ets`：AI 出题、题组等待反馈、答题与结果页。
- `Plan.ets`：AI 学习计划生成，含软键盘收起和分阶段等待反馈。
- `Chat.ets`：学伴页，SSE 接收、Markdown 阅读卡、表格碎片收束、发送按钮状态。
- `MistakeBook.ets`：错题复盘。
- `LearningMap.ets`：Topic 关系星图。
- `Profile.ets` / `ActivityRecords.ets` / `Achievements.ets`：画像、学习记录、成就。
- `Knowledge.ets`：离线知识检索。
- `widget/pages/LearningPlanCard.ets`：服务卡片读取本地计划。

## 7. Web 端结构

核心 API：

- `app/api/health/route.ts`
- `app/api/chat/route.ts`
- `app/api/plan/route.ts`
- `app/api/quiz/route.ts`
- `app/api/quiz/submit/route.ts`
- `app/api/knowledge/search/route.ts`
- `app/api/resources/route.ts`
- `app/api/safety-review/route.ts`
- `app/api/model/status/route.ts`

核心库：

- `lib/agents/model.ts`
- `lib/agents/orchestrator.ts`
- `lib/agents/profile-agent.ts`
- `lib/agents/retrieval-agent.ts`
- `lib/agents/tutor-agent.ts`
- `lib/agents/planner-agent.ts`
- `lib/agents/quiz-agent.ts`
- `lib/agents/evaluator-agent.ts`
- `lib/agents/safety-agent.ts`
- `lib/rag/index.ts`
- `lib/store/db.ts`
- `lib/api-validation.ts`
- `lib/request-json.ts`
- `lib/client-api.ts`

Web 包管理：

- `apps/web/package.json`
- 包管理器固定 `pnpm@11.9.0`
- Next.js `14.2.18`
- React `18.3.1`
- OpenAI SDK `4.73.1`

## 8. 已验证证据

最近主线证据：

- `Chat.ets` DevEco MCP `check_ets_files`：`no diagnostics`。
- `cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`：构建通过，`BUILD SUCCESSFUL in 3 s 742 ms`；仍提示未配置 signingConfigs。
- 线上 Health：`GET https://hormony-ruddy.vercel.app/api/health` 返回 HTTP 200，`status=ready`，模型名 `doubao-seed-2-1-pro-260628`。
- 线上 Chat SSE：`POST /api/chat` 返回 HTTP 200；SSE 统计为 `frames=12`、`delta=1`、`done=1`、`citation=3`、`trace=3`、`thinking=4`，正文长度 1246，包含 Java 代码内容。
- 模拟器 fallback：启动 `scripts/simulator-api-gateway.mjs` 后，本地 `GET http://127.0.0.1:3001/api/health` 返回 HTTP 200，`status=ready`，模型名 `doubao-seed-2-1-pro-260628`。
- 模拟器 UI：`Pura 90 Pro Max` 竖屏，窗口 `bundleName:com.c4ai.hormony`。UI 树证据显示 Chat 进入 `输入你的问题...` 可输入态，并显示“输入问题后发送按钮会亮起”。
- 模拟器 UI：历史真实回答渲染包含“数组”“链表”“随机访问”和“参考资料 (3)”。
- Topic 关系：`python scripts/validate-topic-relations.py` 全部通过。

历史证据在 `DEVLOG.md` 末尾包括：

- Plan 线上 `POST /api/plan` HTTP 200，返回 `tasks=7`、`agentTrace=4`。
- Quiz 模拟器路径“课程列表 AI 出题入口 -> Quiz 设置页 -> 开始答题 -> 等待态 -> 首题生成”通过。
- Chat Markdown 表格碎片收束通过历史回答 UI 树负向扫描。

## 9. 仍未验证或受阻

- 端侧新输入问题完整链路未通过：`uitest inputText` 与 `hdc shell uitest uiInput text` 能让输入框 UI 显示文本，但点击真实发送按钮后，`simulator-api-gateway` 日志未出现新的 `POST /api/chat`。不能标记“端侧新输入问题 -> 发送 -> SSE 返回 -> 保存历史”为模拟器通过。
- Quiz 完整“提交答案 -> 评分 -> 写回画像”链路仍需模拟器证据。
- Plan 长等待停留态在慢网络或模型长耗时场景仍需补截图证据。
- Web 本轮未重新跑 `pnpm lint`、`pnpm typecheck`、`pnpm test`、`pnpm build`。
- 真机未验证：Chat、Plan、Quiz、Lottie、OCR、TTS、distributedKVStore。
- Lottie 资源只做过图层结构层面评估；未安装 `@ohos/lottie`，未放入产品 rawfile，未做 API 12 构建和真机验证。
- 未跟踪本地资产没有进入主线，下一模型不得直接提交。

## 10. 前端资源与核心资产

`assets/frontend-resources/` 当前未跟踪，资源决策以 `docs/FRONTEND-RESOURCE-ADOPTION.md` 为准：

- 可保留为验证方向但未进产品：`checkmark-success.json`、`learning-progress.json`、`trophy-celebration.json`。
- 禁止接入 HarmonyOS HAP：`canvas-confetti.browser.min.js`、`confetti-examples.js`、`spinkit.css`、`skeleton.css`、`zustand-setup.ts`、`comlink-setup.ts`、`blurhash-setup.ts`、`web-vitals-setup.ts`。
- Tabler/Phosphor SVG 只作设计参考，不直接作为产品功能图标。应用内功能图标默认使用 HarmonyOS 系统 Symbol。

本地展示资产：

- `hongxueban-showcase.zip` 与 `hongxueban-showcase/` 是展示站资产，不纳入 HAP 主线。
- `鸿学伴-创意提案.html` 是本地 HTML 提案，不纳入当前提交。
- `.tmp/` 是本地证据目录，禁止提交。

## 11. 下一步建议

1. 先处理端侧 Chat 新输入发送链路：不要修改业务逻辑前先确认真实设备/模拟器输入方式能触发 `onChange`。建议用 UI 树 bounds、真实软键盘输入或 DevEco 更底层工具验证，网关日志必须出现新的 `POST /api/chat`。
2. 补 Quiz 完整闭环：从课程/标签进入 Quiz，生成题组，提交答案，确认评分结果、错题、标签画像和 ActivityRecords 写回。
3. 补 Plan 长等待态证据：构造慢网络或模型长耗时场景，证明等待面板在真实停留期间可见，且软键盘不遮挡。
4. 逐提交复核旧分支中 1.13 的题库、标签洞察、真实 Topic 掌握度改动；不要整枝合并。
5. Web 若有 API 或 Agent 改动，必须运行：

```powershell
cd apps/web
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

6. HarmonyOS 若有端侧改动，优先运行：

```powershell
cd apps/harmonyos
.\hvigorw.bat assembleHap --no-daemon
```

7. 只有需要 ArkTS 诊断、安装运行、UI 树和截图时使用 DevEco MCP。

## 12. 提交规则

- 每批只提交一个清晰主题。
- 提交前必须：

```powershell
git diff --check
git status --short
git diff --cached --name-only
```

- 暂存必须使用明确文件路径，禁止 `git add .`、`git add -A` 和通配符暂存。
- 对暂存内容做敏感信息扫描，命令不得打印环境变量值。
- 禁止提交 `.trae/progress.json`、`.tmp/`、`assets/`、展示站、zip、HAP、截图、secrets、本地提示词和无关资产。

## 13. 给下一模型的一句话

先守住证据边界：当前项目已经具备真实 Agent、真实模型、真实题库、真实 Topic 图谱和端侧本地状态闭环的骨架；下一步不要扩张架构，也不要接入新依赖，先把 Chat 新输入、Quiz 提交写回、Plan 长等待三个真实链路补到可复现。
