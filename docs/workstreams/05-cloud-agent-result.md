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
- RAG 课程隔离与 Safety 输出边界：`ce8f843 fix(web): 封闭 RAG 课程与 Safety 边界`。

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
- production 响应中的 Next RSC `Vary` 覆盖了 middleware 追加的 `Origin`；本节没有把 `Vary: Origin` 记作通过，留给独立 middleware 批次处理。
- **未验证**：线上部署、真实模型 Tutor 输出、浏览器交互、HarmonyOS 模拟器与真机。本批未修改 HarmonyOS 文件、生产模型 ID、题库内容或秘密。

## 10. API CORS 缓存隔离

### 10.1 源码确认与行为

- Next.js 14.2.18 的 `base-server.js` 在 App Route 渲染阶段用 RSC 请求头重设 `Vary`，发生在 middleware 响应头合并之后；本地 production 也确认 pass-through API 最终为 `Vary: RSC, Next-Router-State-Tree, Next-Router-Prefetch`。仅修改 middleware 的 `Vary` 无法覆盖该框架行为。
- middleware 现在对全部 API 响应设置标准 `Cache-Control: private, no-store`。即使 pass-through 的 `Vary: Origin` 被框架覆盖，允许来源的 CORS 响应也不能进入浏览器或共享缓存，避免跨 Origin 复用。
- 不受信 Origin 继续不回显 `Access-Control-Allow-Origin`；middleware 自行终止的 OPTIONS、`ENDPOINT_DISABLED` 和限流响应继续保留 `Vary: Origin`。
- Chat SSE 从 `no-cache, no-transform` 收紧为 `private, no-store, no-transform`，避免实时模型事件被存储后重验证。

### 10.2 验证

- 定向回归：`pnpm exec vitest run src/middleware.test.ts src/app/api/chat/stream-limits.test.ts` exit 0，2 个测试文件、47 项通过。
- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，25 个测试文件、355 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 生产构建完成，middleware 26.8 kB。
- 本地 production `127.0.0.1:4319` 严格断言 exit 0：允许 Origin Knowledge `200`、不受信 Origin Knowledge `200`、无 Origin Health `503`、Chat `503/MODEL_UNAVAILABLE` 均包含语义等价的 `private + no-store`；不受信 Origin 未回显；OPTIONS `204` 和 Knowledge Upload `404/ENDPOINT_DISABLED` 保留 `Vary: Origin`。PID 51756 已停止，端口已关闭。

### 10.3 失败与未验证

- 第一轮 production 脚本按字符串顺序比较 `private, no-store`，而 Node 最终规范化为 `no-store, private`，因此 exit 1；改为解析指令集合并同时要求 `private`、`no-store` 后 exit 0。失败未计作通过。
- pass-through API 的最终 `Vary` 仍由 Next 14 RSC 管理；本批通过禁止存储关闭跨 Origin 缓存风险，没有伪称框架 Vary 已修复。
- **未验证**：线上 CDN/反向代理行为、真实模型 Chat SSE 的 production 响应头、浏览器缓存面板。未修改 HarmonyOS、生产模型 ID 或秘密。

## 11. Chat SSE 单一终态边界

### 11.1 源码确认与行为

- Chat 路由在首个 `done` 成功进入响应后记录终态；编排随后发出的 delta、重复 done 或其他事件不再进入缓冲区或流控制器。
- 编排在 `done` 后抛出的迟到异常不再触发路由补偿 `error -> done`，因此客户端只观察到首个终态。
- `error` 仍需后接 `done` 才完成协议收束；现有流中错误映射、请求取消、单事件 64 KiB、总流 512 KiB 和 128 事件上限保持不变。
- 路由回归覆盖 `done -> throw`、`done -> delta -> duplicate done` 和 `error -> done -> throw`。取消断开继续不补写终态；三类输出超限继续只以一次 `OUTPUT_LIMIT_EXCEEDED -> done` 收束。

### 11.2 委派与复核

- 子 agent `chat_terminal_contract` 新增 `done -> late throw` 路由红测，修复前 exit 1 并精确观察到 `done(session-complete) -> error(INTERNAL_ERROR) -> done(error)`；未修改生产源码、未暂存或提交。
- 主线程采用该红测并补齐另外两个终态反例。独立只读威胁复核确认 `error` 不应单独锁定终态，且当前守卫未破坏取消、Safety 和输出上限路径。

### 11.3 验证

- 定向回归：`pnpm exec vitest run src/app/api/chat/terminal-boundary.test.ts src/app/api/chat/stream-limits.test.ts` exit 0，2 个测试文件、10 项通过。
- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，26 个测试文件、358 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 完成生产构建，10 个静态页面、全部 dynamic API route 与 26.8 kB middleware 进入产物。
- 本地 production 黑盒：`127.0.0.1:4320`，显式无模型测试响应、stateless/off；有效 Chat 请求为 HTTP 503、`MODEL_UNAVAILABLE`、JSON `error` 字段存在且没有建立 SSE。实例 PID 35452 已停止，端口已关闭。

### 11.4 失败与未验证

- 首个 production 启动参数未建立监听，探针超时 exit 124；改用实际 Next CLI 后实例启动。首个业务请求因 userId 含连字符得到 `400/INVALID_USER_ID`；按已读取的精确契约改为字母和下划线后断言 exit 0，失败未计作通过。
- 额外 Quiz 总预算子 agent 因账户并发额度未启动，没有修改文件；该风险留待本批提交后由主代理从源码与测试继续评估。
- **未验证**：当前分支线上部署、带真实模型的 SSE 正文与迟到异常、真实浏览器断连、HarmonyOS 模拟器与真机。未修改 HarmonyOS、RAG、缓存策略、生产模型 ID 或秘密。

## 12. Quiz 模型调用总预算

### 12.1 源码确认与行为

- 旧 Quiz 循环接受修复后的部分批次。请求上限 20 题、每轮最多新增 1 题、每轮一次生成加一次修复时，单请求最多 40 次顺序模型调用；模型层只提供每次 45 秒超时，路由 `maxDuration=120` 不是内部 deadline。
- 模型层新增总预算执行器，统一组合内部 timeout 与外部 AbortSignal。Quiz 路由使用 100000ms 总预算，在平台 120 秒时限前为 Safety、序列化和回收预留 20 秒。
- 内部 deadline 中止派生 signal 并映射为 `504/MODEL_TIMEOUT`；用户断开仍映射为 `499/MODEL_CANCELLED`，两条路径都清理 timer 与外部 signal listener。
- Quiz Agent 在单批内按规范化题干去重；一次修复后仍无法得到完整批次即 `MODEL_INVALID_RESPONSE`。合法 20 题现在最多 4 批，每批最多生成和修复各一次，模型调用上界收敛为 8。

### 12.2 委派与复核

- 子 agent `quiz_request_budget_test` 只新增路由预算测试。修复前目标测试 exit 1：100000ms 后 Agent signal 仍为未中止；同文件的外部取消 `499/MODEL_CANCELLED` 已通过。子 agent 未修改生产源码、未暂存或提交。
- 主线程逐行复核并采用测试；首次联合运行发现测试初始化的 `vi.waitFor` 会推进 fake clock，改为 0ms 微任务冲刷后保留原产品断言，并补齐不足批次与同批重复题的两次调用收束回归。

### 12.3 验证

- 定向联合：`pnpm exec vitest run src/app/api/quiz/request-budget.test.ts src/app/api/quiz/request-cancellation.test.ts src/lib/agents/quiz-agent.test.ts src/app/api/quiz/quiz-flow.test.ts` exit 0，4 个测试文件、30 项通过。
- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，27 个测试文件、362 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 完成生产构建，10 个静态页面、全部 dynamic API route 与 26.8 kB middleware 进入产物。
- 本地 production 黑盒：`127.0.0.1:4321`，显式无模型测试响应、stateless/off；有效 Quiz 请求为 HTTP 503、`MODEL_UNAVAILABLE`，`count=21` 为 HTTP 400、`INVALID_COUNT`。实例 PID 60304 已停止，端口已关闭。

### 12.4 失败与未验证

- 首轮联合回归 28/29：内部预算已触发，但测试自身先通过 `vi.waitFor` 推进时钟，导致 99999ms 前置断言失败；只冲刷 0ms 微任务后 30/30 通过，失败未计作通过。
- **未验证**：真实模型上游连接在 100 秒时的网络级取消、线上平台 120 秒回收、当前分支线上部署、浏览器、HarmonyOS 模拟器与真机。未修改 HarmonyOS、题库内容、RAG、缓存策略、生产模型 ID 或秘密。

## 13. Plan 请求总预算与资源清理

### 13.1 源码确认与行为

- Planner 当前只执行一次模型调用，默认单次 45 秒超时；但 `MODEL_TIMEOUT_MS` 可由部署环境配置为超过路由 `maxDuration=120` 的值，旧路由本身没有硬 deadline，挂起的 Agent 也不会被平台配置主动中止。
- Plan 路由复用模型层 `withModelRequestBudget`，将整个 Planner 操作限制为 100000ms，并把派生 signal 贯穿既有模型调用。
- 内部 deadline 精确映射为 `504/MODEL_TIMEOUT`；外部 Request 中止继续映射为 `499/MODEL_CANCELLED`。成功、失败和取消路径均由预算 helper 清理 timer 与父 Request.signal listener。
- 输出 Safety、Plan 结构校验、日期和本地优先边界不变；本批没有给只有一次模型调用的 Planner 增加重试或静态降级。

### 13.2 测试与复核

- 新增 Plan 路由级预算测试，确认 99999ms 时 Planner signal 未中止、100000ms 精确中止并返回 504；成功响应后 `vi.getTimerCount()` 为 0，父 signal 的 abort listener 已调用对应 remove。
- 既有 Request 取消测试继续验证派生 signal 被中止且响应为 499；Plan 生命周期与 Planner 输出边界联合回归通过。
- 定向命令：`pnpm exec vitest run src/app/api/plan/request-budget.test.ts src/app/api/plan/request-cancellation.test.ts src/app/api/plan/plan-lifecycle.test.ts src/lib/agents/planner-agent.test.ts` exit 0，4 个测试文件、22 项通过。

### 13.3 验证

- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，28 个测试文件、364 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 完成 10 个静态页面和全部 dynamic API route 的生产构建，middleware 26.8 kB。
- 本地 production 黑盒：`127.0.0.1:4322`，显式无模型测试响应、stateless/off；有效 Plan 请求为 HTTP 503、`MODEL_UNAVAILABLE`，`dailyMinutes=10` 为 HTTP 400、`INVALID_DAILY_MINUTES`。实例 PID 10836 已停止，端口已关闭。

### 13.4 未验证

- **未验证**：真实模型连接在 100 秒时的网络级取消、线上平台 120 秒回收、当前分支线上部署、浏览器、HarmonyOS 模拟器与真机。
- 本批未修改 DEVLOG、HarmonyOS、Quiz、Chat SSE 终态、RAG、缓存策略、生产模型 ID 或秘密。

## 14. Chat 编排总预算与中止原因隔离

### 14.1 源码确认与行为

- Chat 的 Tutor、Planner、Evaluator 分支至多执行一次模型调用；Quiz 意图固定请求 5 题，在当前完整批次边界下最多执行一次生成和一次修复，即 2 次模型调用。旧 Chat 路由只有单次模型 timeout、客户端断连和输出上限控制，没有覆盖整段编排的总 deadline。
- Chat 路由现在使用 100000ms 总预算包裹完整 `orchestrateStream`。超时前已建立 HTTP 200 时，流只追加一次 `error(code=MODEL_TIMEOUT) -> done`；首事件前超时仍由既有 JSON 错误路径返回 504。
- 模型预算 helper 新增独立 `abortSignal`，用于组合 Chat 已有的输出上限/reader 取消控制器。内部 route abort 的 Error reason 原样保留，因此 `OUTPUT_LIMIT_EXCEEDED` 不会被误映射为 `MODEL_CANCELLED`。
- 外部 Request abort 仍标记 clientCancelled，不向已断开的流补写 error/done；成功、超时和内部 abort 都清理 deadline timer、Request signal listener 与内部 abortSignal listener。
- 本批没有改变首个 `done` 后的单终态守卫、事件数量/字节上限、Safety 顺序、RAG 课程隔离或 no-store 响应头。

### 14.2 委派与两级复核

- 子 agent `chat_request_budget_test` 只新增 Chat 路由预算测试。实现前目标测试 exit 1：100000ms 时编排 signal 仍为未中止；同文件的外部 Request abort 用例已通过。子 agent 未修改生产源码、未暂存或提交。
- 共享区实现后子 agent 复测 2/2 通过；主线程逐行复核并联合 Chat 输出上限、单终态、Plan/Quiz 预算与模型 helper 资源测试，6 个文件、18 项全部通过。
- 模型 helper 单元回归独立确认成功后 timer 计数为 0、两类 signal listener 均 remove，并确认内部 `OUTPUT_LIMIT_EXCEEDED` Error 对象作为派生 signal.reason 和最终 rejection 原样保留。

### 14.3 验证

- 定向联合：`pnpm exec vitest run src/lib/agents/model-budget.test.ts src/app/api/chat/request-budget.test.ts src/app/api/chat/stream-limits.test.ts src/app/api/chat/terminal-boundary.test.ts src/app/api/plan/request-budget.test.ts src/app/api/quiz/request-budget.test.ts` exit 0，6 个测试文件、18 项通过。
- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，30 个测试文件、368 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 完成生产构建，10 个静态页面、全部 dynamic API route 与 26.8 kB middleware 进入产物。
- 本地 production 黑盒：`127.0.0.1:4323`，显式无模型测试响应、stateless/off；有效 Chat 请求为 HTTP 503、`MODEL_UNAVAILABLE`、JSON content-type，未建立 SSE。实例 PID 57996 已停止，端口已关闭。

### 14.4 未验证

- **未验证**：真实模型编排在 100 秒时的网络级取消、已建立线上 SSE 的 timeout 事件、线上平台 120 秒回收、当前分支线上部署、真实浏览器断连、HarmonyOS 模拟器与真机。
- 本批未修改 DEVLOG、HarmonyOS、Quiz 生成实现、Chat SSE 单终态、RAG、缓存策略、生产模型 ID 或秘密。

## 15. 全局单次模型超时配置上限

### 15.1 源码确认与行为

- `MODEL_TIMEOUT_MS` 原先只拒绝非有限数和小于 1000ms 的值，没有上限。部署误配为数分钟时，未经过路由总预算包装的模型调用会长期占用连接；`maxDuration` 也不是模型客户端内部取消机制。
- 模型运行时现在把单次调用 timeout 封顶为 100000ms；缺失、非法或低于 1000ms 的配置继续使用既有 45000ms 默认值，合法范围内的配置保持不变。
- OpenAI 兼容客户端缓存键继续包含最终 timeout，配置变化时仍会重建客户端；生产模型 ID、base URL、重试次数和输出 token 上限没有改变。

### 15.2 验证

- 新增模型运行时边界测试：缺失配置为 45000ms，`999` 回退 45000ms，`120000` 精确封顶为 100000ms。
- 定向联合：`pnpm exec vitest run src/lib/agents/model-runtime.test.ts src/lib/agents/model-budget.test.ts src/app/api/chat/request-budget.test.ts src/app/api/plan/request-budget.test.ts src/app/api/quiz/request-budget.test.ts` exit 0，5 个测试文件、11 项通过。
- 静态诊断通过：`pnpm lint` exit 0；`pnpm typecheck` exit 0；`pnpm test` exit 0，31 个测试文件、371 项通过。
- 构建通过：`pnpm build` exit 0；Next.js 14.2.18 完成生产构建，10 个静态页面、全部 dynamic API route 与 26.8 kB middleware 进入产物。
- 本地 production 黑盒：`127.0.0.1:4324`，显式 `MODEL_TIMEOUT_MS=120000` 且不配置模型秘密；`/api/model/status` 为 HTTP 200、`timeoutMs=100000`、`configured=false`、`mode=unavailable`。实例 PID 56996 已停止，端口已关闭。

### 15.3 未验证

- **未验证**：线上部署环境当前 `MODEL_TIMEOUT_MS` 的实际值、真实上游在 100 秒时的网络级取消、当前分支线上发布。
- 本批未修改 DEVLOG、HarmonyOS、任何生产模型 ID、API Key、RAG、缓存或端侧状态。
