# 鸿蒙1.12 Web AI/API 可靠性记录

更新时间：2026-07-02

## 本批次范围

- Web 后端 Plan、Quiz、Chat SSE 的输入校验、错误码和模型输出 Safety。
- Agent/model 的模型超时、客户端取消、解析失败和资料缺失错误边界。
- Web Quiz 生成后提交服务端评分的闭环。
- 端侧仅做只读审计；未修改 HarmonyOS 页面、模型或网络层。

## 已固定契约

### Chat SSE

- 请求体必须是对象；`message` 必须是非空字符串，长度不超过 2000。
- `context` 必须是对象；`context.courseId` 只能是 `cs101`、`cs102`、`cs103`。
- `history` 必须是 `user` 或 `assistant` 消息对象数组；`content` 必须是字符串。
- 当前 `message`、`history.content`、`profile.stage/learningStyle/weakTopics/strongTopics` 都进入输入 Safety。
- SSE 仍使用 `thinking`、`trace`、`delta`、`citation`、`error`、`done`。
- 流中模型解析失败、资料缺失、超时会保留结构化 `code`：`MODEL_INVALID_RESPONSE`、`KNOWLEDGE_UNAVAILABLE`、`MODEL_TIMEOUT`。
- 客户端取消 SSE 时会触发服务端 `AbortSignal`，模型请求不再继续跑到超时。

### Plan

- `goal` 必须是非空字符串，长度不超过 500。
- `durationDays` 必须是 1-30 的整数；`dailyMinutes` 必须是 15-480 的整数。
- `profile` 必须是对象，画像数组只能包含字符串，`profile.stats` 必须是对象。
- Planner 仍只从真实 Topic 清单逐字选择 `courseId/topic/action`。
- 生成结果返回 `planId/userId/goal/tasks/agentTrace`；每个任务保留 `courseId/topic/action/reason`。
- 模型输出字段进入 Safety；未通过时返回 502 `{ code: "SAFETY_BLOCKED" }`。

### Quiz

- `courseId` 只能是 `cs101`、`cs102`、`cs103`；题库目录查询未知课程返回 400。
- `topic` 必须是 1-100 字符字符串；`count` 必须是 1-20 的整数；`difficulty` 只能是 `easy`、`medium`、`hard`。
- 题目生成仍要求 4 个 `A.`、`B.`、`C.`、`D.` 选项，答案只能是 A-D，标签 1-3 个短标签。
- 成功响应继续分离展示题和本地评分数据：`questions` 不含答案/解析，`grading` 单独返回。
- 模型输出字段进入 Safety；未通过时返回 502 `{ code: "SAFETY_BLOCKED" }`。
- Web 后台生成的 AI Quiz 会保存到服务端 store，随后 `/api/quiz/submit` 可用同一个 `quizId` 完成服务端评分。HarmonyOS 端仍使用 `grading` 本地评分。

## 错误码

- `BAD_REQUEST`：请求体不是 JSON 对象或 JSON 无效。
- `INPUT_REJECTED`：用户输入、历史或画像文本未通过输入 Safety。
- `INVALID_CONTEXT`、`INVALID_HISTORY`、`INVALID_PROFILE`：嵌套结构不符合契约。
- `INVALID_COURSE`、`INVALID_TOPIC`、`INVALID_COUNT`、`INVALID_DIFFICULTY`、`INVALID_DURATION`、`INVALID_DAILY_MINUTES`：字段枚举、类型或边界不符合契约。
- `MODEL_UNAVAILABLE`：模型未配置或上游不可用。
- `MODEL_TIMEOUT`：模型请求超过服务端超时。
- `MODEL_CANCELLED`：请求已取消。
- `MODEL_INVALID_RESPONSE`：模型返回不能解析为合格结构。
- `KNOWLEDGE_UNAVAILABLE`：当前主题缺少课程资料。
- `SAFETY_BLOCKED`：模型输出未通过 Safety。

## 验证等级

- **静态诊断通过**：`pnpm lint`、`pnpm typecheck` 均通过。
- **测试通过**：`pnpm test`，11 files / 132 tests passed。
- **构建通过**：`pnpm build` 通过，Next.js production build 成功。
- **源码确认**：端侧 `HttpClient` 当前普通 JSON/SSE 非 200 仍只抛 `HTTP <status>`，不解析 `{ error, code }`。
- **未验证**：本批次未部署到 Vercel，未做线上端点回归，未做 HarmonyOS 模拟器/真机流程回归。

## 需要主线程同步

- HarmonyOS `HttpClient` 若要满足“客户端保留 HTTP 状态和精确错误码”，需要解析非 200 响应体中的 `{ error, code }`，并把 `status/code/error` 传给页面。
- HarmonyOS `PlanTask` 基础接口未声明 `reason?: string`，页面内使用 `AgentPlanTask` 扩展读取；后续可同步到 `DataModels.ets`。
- HarmonyOS Quiz 端侧当前只校验 `questions/grading` 数组长度；如需离线防御，需要补 A-D 选项、`grading.answer` 和 `tags` 类型校验。
- 离线 Practice 题库尚未携带 `difficulty/tags/grading`；如要把离线练习纳入标签画像，需要同步数据结构与生成脚本。
