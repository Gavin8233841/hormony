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
- `quiz_request_cancellation`：仅修改 Quiz 路由与独立取消测试，把 `Request.signal` 贯穿至 Quiz Agent；主线程复核后与 Plan 取消链联合验证。子 agent 未暂存、提交或推送。

## 5. 提交

- API/无状态/Safety 原子批次：`b372f86 fix(web): 强化无状态 Agent API 契约`。
- Web 调试体验与本文：`bc046b1 fix(web): 对齐无状态调试客户端契约`。
- 生产无状态网关、可信限流与 Health：`04fbd6a fix(web): 加固生产无状态网关`。
- Agent 输出、Chat SSE 预算、Plan/Quiz/日期契约：`93907c8 fix(web): 加固 Agent 生成与流式契约`。
- Web Chat 停止后重发与历史请求边界：`bfdad5d fix(web): 隔离 Chat 停止后重发状态`。
- 第三批结果证据：`6290c92 docs(ws05): 记录第三批生产可靠性证据`。
- Plan 与 Quiz 请求取消贯穿：`2b240af fix(web): 贯穿 Plan 与 Quiz 请求取消`。

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

## 8. Plan 与 Quiz 取消链

- `/api/plan` 和 `/api/quiz` 均把派生的 `req.signal` 传给现有 Agent/model 取消链；既有输入 Safety、输出 Safety、Topic 精确校验、grading 分离和错误映射不变。
- 路由级回归用源 AbortController 中止 Request，确认 Agent 收到的派生 signal 变为 `aborted=true`，并验证响应为 HTTP 499、`code=MODEL_CANCELLED`，没有静态成功替代。
- 定向验证：4 个测试文件、32 项通过；全量 `pnpm lint`、`pnpm typecheck`、`pnpm test`、`pnpm build` 均 exit 0，全量测试为 23 文件、345 项。
- 首轮 Plan 测试错误比较源/派生 signal 对象身份，1 项失败；改为验证 WHATWG Request 的取消状态传播后，Plan 15/15 项通过。失败未被记为通过证据。
- **未验证**：真实模型上游网络请求的取消、本批本地 production 黑盒与线上部署。

## 9. RAG 课程隔离与 Safety 输出边界

### 9.1 行为与边界

- 新增检索结果运行时白名单：只接受非空 `id/text/source`、受支持 `courseId`、精确课程 Topic、有限数值 score，并要求结果数量不超过调用方请求数量。
- 合法空数组保持正常无结果；非数组、超量、畸形、跨课程或非法 Topic 被视为下游合约失效。Knowledge 返回既有 `500/INTERNAL_ERROR`，Chat 终止处理，不降级为无引用通用回答。
- 返回值按 `KnowledgeChunk` 合约重建，检索层附带的未知字段不会进入 Tutor 上下文或 Knowledge Search 响应；无 Topic 的本地上传切片继续兼容。
- Knowledge Search 在输出 Safety 和 JSON 响应前应用课程边界；Chat Retrieval Agent 在格式化上下文和生成引用前应用同一边界。
- Chat 对 RAG 正文和引用先执行 Safety；失败时直接发出 `SAFETY_BLOCKED -> done`，不进入 Tutor。通过后 SSE Retrieval trace 也只公开真实检索条数，不再在后置 Safety 前发送 RAG 正文。
- 147 条内置知识切片及三门课程的 33 Topic 对照全部通过新边界，没有误删合法课程资料。

### 9.2 委派与复核

- 子 agent `knowledge_cross_course_contract` 独立新增 Knowledge Search 路由反例，红测确认合法 `cs101` 请求会原样返回异常 `cs102` 切片；同课程真实 Safety 反例已在旧实现正确返回 `502/SAFETY_BLOCKED`。主线程逐行复核后采用测试并补充非法 Topic、Chat 隔离、trace 和 RAG Safety 回归。
- 独立只读复核 `rag_boundary_review` 指出静默过滤会混淆正常空结果与下游合约失效；主线程采纳为 fail-closed `INTERNAL_ERROR`，没有固化伪空结果。

### 9.3 验证

- 定向回归：`pnpm exec vitest run src/app/api/knowledge/search/course-isolation.test.ts src/lib/agents/orchestrator.test.ts src/lib/rag/course-boundary.test.ts` exit 0，3 个测试文件、12 项通过。
- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，25 个测试文件、354 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 完成生产构建，10 个静态页面、全部 dynamic API route 与 26.8 kB middleware 进入产物。
- 最终重建后本地 production 黑盒：`127.0.0.1:4318`，显式 stateless/off；Health `503/degraded`、`deploymentMode=stateless`、`persistence.mode=stateless`、`model.configured=false`。Knowledge Search `200` 返回 3 条 `cs101` 切片，全部课程-Topic 和字段白名单有效；OPTIONS `204`，安全头有效；Knowledge Upload 为 `404/ENDPOINT_DISABLED`。监听端口已关闭。

### 9.4 失败与未验证

- 首次 typecheck 因测试 mock 的字面量返回类型过窄 exit 2；显式标注 `string` 后定向与全量 typecheck 均 exit 0。
- fail-closed 调整后的首轮目标测试为 11/12；旧测试仍把三门课程混合全集传给指定课程边界。改为逐门课程验证精确下游结果后目标测试通过，失败未计作通过证据。
- 前两次 production 断言已完成业务响应，但 PowerShell 对多值 header 的读取方式不正确而 exit 1；按实际响应头字典归一化后严格脚本 exit 0，失败未计作通过。
- production 响应中的 Next RSC `Vary` 覆盖了 middleware 追加的 `Origin`；本节没有把 `Vary: Origin` 记作通过，留给独立 middleware 批次修复。
- **未验证**：线上部署、真实模型 Tutor 输出、浏览器交互、HarmonyOS 模拟器与真机。本批未修改 HarmonyOS 文件、生产模型 ID、题库内容或秘密。
