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
- `plan_save_contract`：实现任务核心字段、真实日历日期与去空白后唯一 ID 校验；主线程逐行复核并补强重复 ID 回归后采用。
- `production_middleware_regression`：两轮独立 production 黑盒验证；首轮发现 Health 缺少 `persistence.mode`，主线程修复后由同一脚本复测全部通过。子 agent 未修改、暂存或提交文件。

## 5. 提交

- API/无状态/Safety 原子批次：`b372f86 fix(web): 强化无状态 Agent API 契约`。
- Web 调试体验与本文：`bc046b1 fix(web): 对齐无状态调试客户端契约`。
- 生产无状态网关、可信限流与 Health：`04fbd6a fix(web): 加固生产无状态网关`。
- Agent 输出、Chat SSE 预算、Plan/Quiz/日期契约：`93907c8 fix(web): 加固 Agent 生成与流式契约`。
- Web Chat 停止后重发与历史请求边界：`bfdad5d fix(web): 隔离 Chat 停止后重发状态`。

## 6. 失败与未验证

- 请求流读取首次 typecheck exit 2，原因是错误辅助函数返回类型过宽；收窄为纯错误结果后 typecheck 和全量验证 exit 0。
- 第一轮目标测试 238/239，旧 Safety 测试使用不属于课程的 Topic，先得到 `INVALID_TOPIC`；改为合法 Topic + 敏感 focusTag 后 196/196 重点契约通过。
- 第一轮本地 HTTP 脚本对多值 header 的 PowerShell 类型处理错误，没有作为通过证据；严格停止模式重跑 exit 0。
- **未验证**：当前分支线上部署、带真实模型的 Chat SSE 正文/Plan/Quiz、浏览器交互渲染、HarmonyOS 模拟器、真机。
- 本批未执行线上写操作，未使用测试替身伪造产品能力，未提交秘密、日志、截图、缓存、资产、HAP 或压缩包。

## 7. 第三批生产可靠性补强

### 7.1 行为与边界

- 生产环境无论部署变量缺失或误写都强制 `stateless`；文件持久化保持关闭。Health 新增 `persistence.mode`，生产无状态返回精确值 `stateless`。
- middleware 不再信任客户端 `X-Forwarded-For`，只使用运行时 `req.ip`；缺失可信 IP 时进入共享桶。限流键上限 1000，容量满返回 `429/RATE_LIMITED`，窗口到期后清理并恢复。
- Chat SSE 将请求与 reader 取消传到 orchestrator/model；单事件 64 KiB、总流 512 KiB、最多 128 事件，超限以 `OUTPUT_LIMIT_EXCEEDED -> done` 收束。
- Planner 拒绝超出周期/10 项上限、任一坏任务和超每日总预算；Quiz 校验 choice、题干、选项、答案、解析和标签边界。
- `startDate` 从 Web 本地日历经 `readDateKey` 传入 Chat/Plan/Planner，保留主线本地日期契约。
- `/api/plan/save` 要求 `id/title/date/estimatedMin/type`，拒绝空任务、虚假日期和去空白后重复 ID，不再生成核心字段默认值。
- Web Chat history 只发送最后 12 条且逐条截到 1000 字符；控制器身份保护事件、catch、session 与 finally，stop 后旧请求不能覆盖新 assistant 或清除新控制器。

### 7.2 验证

- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，21 个测试文件、343 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 完成 10 个静态页面，API dynamic routes 与 26.8 kB middleware 进入生产产物。
- 定向回归：无状态/中间件 4 文件 58 项、Agent/API/日期 7 文件 139 项、Chat client 1 文件 8 项，均 exit 0。
- 本地 production 黑盒通过：`127.0.0.1:3118` 严格断言脚本 exit 0；Profile `404/ENDPOINT_DISABLED`，Health `503/degraded`、`model.configured=false`、`deploymentMode=stateless`、`persistence.mode=stateless`，轮换 XFF 的第 31 次同路径请求 `429/RATE_LIMITED`。独立实例已停止，既有 3105 实例未受影响。
- 提交前每批 `git diff --check`、`git status --short`、`git diff --cached --name-only` 与不打印值的敏感信息扫描均 exit 0；无敏感值或禁止文件命中。

### 7.3 未验证

- 当前分支尚未部署，线上通过未验证；带真实模型的 Chat SSE 正文、Plan、Quiz 未验证。
- Browser 插件未提供，仓库没有 Playwright 可执行文件且未安装新依赖；Chat stop 后立即重发的真实浏览器交互未验证。
- HarmonyOS 模拟器与真机未验证；第三批未修改 HarmonyOS 文件、生产模型 ID、题库内容或竞赛文档。
