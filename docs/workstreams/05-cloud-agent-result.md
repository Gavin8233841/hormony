# 鸿学伴 05 · 云端 Agent 与 API 生产可靠性结果

日期：2026-07-17

分支：`codex/ws05-web-agent-api`

主责：`apps/web` Agent、API、middleware、RAG、安全、无状态边界与调试客户端

## 1. 基线与范围

- 开工基线为 `dd2fe16 docs: 新增鸿蒙2.0接力文档`。
- `9f24d0c feat: 增强 Web AI API 可靠性` 不是当前 `HEAD` 的祖先；本批逐文件对照其 Chat、Plan、Quiz、模型错误与 Safety 行为，没有用历史操作覆盖当前实现。
- WS02 提交 `c9572d2` 也不在当前分支历史中；本批逐行吸收其 `isCourseTopic(courseId, topic)`、Topic 必填、近似/跨课程 Topic 拒绝和路由测试，并让 Web 调试页改为消费课程题库目录。
- 未修改生产模型 ID，当前源码与本地 Health 仍为 `doubao-seed-2-1-pro-260628`。
- 未把 HarmonyOS 画像、计划、答题、错题、连续学习或会话状态迁入云端文件或进程内持久状态。

## 2. 产品行为变化

### 2.1 无状态部署与 Docker

- 新增 `src/lib/deployment.ts` 作为部署模式单一判断入口。
- 文件持久化默认关闭，只有非 stateless 部署显式设置 `APP_STATE_PERSISTENCE=on` 才允许读写；stateless 模式强制关闭。
- Docker runner 显式设置 `DEPLOYMENT_MODE=stateless`、`APP_STATE_PERSISTENCE=off`，移除 `/data` 状态文件配置与 volume。
- Quiz 生成在 stateless 模式不写进程内测验状态；Knowledge Search 不记录用户活动。

### 2.2 middleware 生产契约

- 无状态模式精确禁用 `/api/conversations`、`/api/courses`、`/api/knowledge/upload`、`/api/plan/save`、`/api/profile`、`/api/quiz/submit`、`/api/stats` 及其子路径。
- 相似前缀不误封；OPTIONS 在禁用判断前返回 204。
- 禁用和限流响应都包含 `{ error, code }`、允许来源 CORS、`Vary: Origin`、安全头；不受信 Origin 不回显。
- middleware 测试覆盖允许继续下游的 Health、Chat、Plan、Quiz、Knowledge Search，以及第 31 次同路由请求的 429/`RATE_LIMITED`/`Retry-After`。

### 2.3 输入边界与请求预算

- `readJsonObject` 统一拒绝非对象 JSON；请求正文上限为 256 KiB UTF-8 实际字节。
- 正文改为流式累计，超限立即取消 reader 并返回 `413 PAYLOAD_TOO_LARGE`；伪小、非法或缺失 `Content-Length` 不能绕过。
- 外部 `userId`、query integer、画像、历史、context、课程、计划任务、Quiz、Knowledge、引用和资源枚举均执行结构、类型、长度、数量和整数边界检查。
- Chat history 最大 12 条、单条最大 1000 字符；越界返回 `400 INVALID_HISTORY`，不再静默裁剪。
- 仓库没有为 `courses.docCount`、`profile.stats.totalQuestions`、`profile.stats.studyDays`、`citation.page` 定义最大值；本批只保留非负整数约束，没有猜测上限。

### 2.4 Safety 前后置

- Chat message、history、profile；Plan goal、profile；Quiz topic、focusTag；Knowledge query/upload；课程、计划保存、Quiz submit 等用户文本在进入模型、RAG 或 store 前执行输入 Safety。
- Chat、Plan、Quiz 模型输出在返回正文前执行输出 Safety。
- Safety 现在覆盖会展示给客户端的 citation `doc/snippet`，防止引用字段绕过 PII、注入或敏感内容检查。
- Knowledge Search 在返回 chunk 前执行输出 Safety；旧 Quiz submit 在最终评分、Evaluator 文本和 weak topics 组装后再次审核。

### 2.5 Chat SSE 客户端

- 独立 SSE parser 运行时校验 `thinking/delta/citation/trace/error/done` 字段。
- 必须收到 `done`；`error` 后只允许紧邻 `done`；`done` 后禁止额外事件；协议错误取消并释放 reader。
- 非 2xx 保留 HTTP 状态和精确错误码；SSE `error` 在页面展示 code/message，不写入错误流的 sessionId。

### 2.6 Quiz 与 Plan

- `/api/quiz` 的 `topic` 必填，必须与所选 `courseId` 的真实 33 Topic 源逐字匹配；近似主题和跨课程主题为 `400 INVALID_TOPIC`。
- Quiz API 继续分离展示题 `questions` 与本地评分 `grading`；Web 页面不再调用生产 middleware 禁用的 `/api/quiz/submit`。
- Web 页面从 `GET /api/quiz?courseId=...` 加载并校验目录，下拉选择精确 Topic；课程切换/卸载取消旧目录和生成请求，旧响应不能覆盖新课程。
- 本地评分校验 questions/grading 一一对应、四个唯一选项、A-D 答案、标签和题量，再计算逐题结果、正确率和真实 weak topics；不伪造 Evaluator 报告。
- Planner 模型输出要求真实 course/topic/action、非空 title/reason 和整数 estimatedMin；单项任务时长不超过请求的 dailyMinutes。

### 2.7 禁用端点与响应式调试页

- Plan、Knowledge Upload、Stats、Profile、Quiz History 对精确 `ENDPOINT_DISABLED` 呈现 HarmonyOS 端侧持久化状态，不把 404 当普通失败或空数据。
- 新增移动端导航，Chat 输入、Quiz 配置/结果、Plan、Knowledge、Profile 和 Dashboard 在窄屏改为稳定单列或可换行布局。

## 3. 验证证据

### 静态诊断通过

- `cd apps/web; pnpm lint`：exit 0，无 warning/error。
- `cd apps/web; pnpm typecheck`：exit 0。
- `cd apps/web; pnpm test`：exit 0，17 个测试文件、299 项全部通过。
- 重点后端契约：7 个测试文件、196 项通过。
- 请求体与 API 输入边界组合：107 项通过。
- SSE、Quiz 本地评分与 client API：35 项通过。
- 多轮 `git diff --check`：exit 0。

### 构建通过

- `cd apps/web; pnpm build`：exit 0。
- Next.js 14.2.18 完成 10 个静态页面生成；全部 API dynamic route 与 26.7 kB middleware 进入生产产物。

### 本地生产 HTTP 补充证据

该证据不等同“线上通过”。实例为 `http://127.0.0.1:3105`，显式清空模型 Key 与测试响应，设置 stateless/off。严格 PowerShell 断言脚本 exit 0：

- Health：HTTP 503，`status=degraded`、`model.configured=false`、`model.mode=unavailable`、精确模型名、`deploymentMode=stateless`。
- Profile：HTTP 404，`code=ENDPOINT_DISABLED`；允许来源 CORS 与安全头存在，不受信 Origin 不回显。
- Profile Update OPTIONS：HTTP 204。
- cs101 Quiz Catalog：HTTP 200，12 个唯一 Topic，每项 `courseId=cs101`、`questionCount>=5`。
- 近似 Topic：HTTP 400，`INVALID_TOPIC`；目录精确 Topic 在无模型配置下进入模型边界并返回 HTTP 503，`MODEL_UNAVAILABLE`。
- Knowledge Search：HTTP 200，2 个 chunk，关键字段与课程一致。
- Chat：HTTP 503，`MODEL_UNAVAILABLE`，没有伪造 SSE 成功正文。
- 超限 Chat JSON：HTTP 413，`PAYLOAD_TOO_LARGE`。
- Quiz/Chat 页面：HTTP 200，SSR 正文包含对应页面标题。
- 独立限流路径第 31 次请求：HTTP 429，`RATE_LIMITED` 且 `Retry-After>0`。

## 4. 委派与复核

- `route_contract_audit`：补齐 256 KiB UTF-8、Content-Length 绕过和 413 精确契约测试；主线程复核后采用。
- `agent_core_audit`：补齐 97 项路由输入/Safety 契约，并定位 Chat 静默裁剪；主线程修改源码并复跑。
- `client_contract_audit`：实现 SSE parser、Quiz 本地评分、禁用端点状态、精确 Topic 目录和请求竞态取消；主线程逐文件复核并纳入全量验证。

## 5. 提交

- API/无状态/Safety 原子批次：`b372f86 fix(web): 强化无状态 Agent API 契约`。
- Web 调试体验与本文：同一原子提交。

## 6. 失败与未验证

- 请求流读取首次 typecheck exit 2，原因是错误辅助函数返回类型过宽；收窄为纯错误结果后 typecheck 和全量验证 exit 0。
- 第一轮目标测试 238/239，旧 Safety 测试使用不属于课程的 Topic，先得到 `INVALID_TOPIC`；改为合法 Topic + 敏感 focusTag 后 196/196 重点契约通过。
- 第一轮本地 HTTP 脚本对多值 header 的 PowerShell 类型处理错误，没有作为通过证据；严格停止模式重跑 exit 0。
- **未验证**：当前分支线上部署、带真实模型的 Chat SSE 正文/Plan/Quiz、浏览器交互渲染、HarmonyOS 模拟器、真机。
- 本批未执行线上写操作，未使用测试替身伪造产品能力，未提交秘密、日志、截图、缓存、资产、HAP 或压缩包。
