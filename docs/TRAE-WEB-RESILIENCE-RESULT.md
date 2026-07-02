# Trae Web 前端 API 消费层与异常体验完善 — 交付报告

> 时间：2026-07-01
> 范围：鸿学伴 Web 前端 API 错误处理统一化

## 一、修改文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `apps/web/src/lib/client-api.ts` | 新建 | 零依赖客户端 API 工具（ApiError + requestJson + getErrorMessage + isNotFound + isEndpointDisabled） |
| `apps/web/src/lib/client-api.test.ts` | 新建 | 24 个测试用例覆盖所有核心路径 |
| `apps/web/src/app/page.tsx` | 修改 | Dashboard 统计请求迁移 |
| `apps/web/src/app/courses/page.tsx` | 修改 | 课程列表请求迁移 |
| `apps/web/src/app/plan/page.tsx` | 修改 | 学习计划 GET/POST/PATCH 迁移 |
| `apps/web/src/app/quiz/page.tsx` | 修改 | 测验 GET/POST/Submit 迁移 |
| `apps/web/src/app/knowledge/page.tsx` | 修改 | 知识检索 POST + 上传 POST 迁移 |
| `apps/web/src/app/profile/page.tsx` | 修改 | 画像 GET + PUT 迁移 |

## 二、每个页面修复的精确问题

### page.tsx（Dashboard）

| 问题 | 修复 |
|------|------|
| 非 2xx 响应静默忽略，catch 块降级到默认值 0 | 用 `requestJson<DashboardStats>` 替换，非 2xx 抛出 ApiError |
| 统计失败时显示 0 可能被误认为真实值 | 失败时 `setStats(null)`，卡片显示"—"，下方显示"统计数据暂不可用"+重试按钮 |
| 无 AbortController | 添加 AbortController，useEffect cleanup 时 abort |
| 无重试按钮 | 添加 retry 函数（通过 retryKey 重新触发 effect） |

### courses/page.tsx

| 问题 | 修复 |
|------|------|
| `throw new Error(`加载失败 (HTTP ${res.status})`)` 丢失服务端错误消息 | 用 `requestJson` 替换，ApiError 保留服务端 `error` 字段 |
| `as { courses?: Course[] }` 非 2xx 时也会执行 | `requestJson` 仅在 `response.ok` 时返回数据 |
| 无 AbortController | 添加 AbortController + active 标志守护 |
| 无重试按钮 | 添加 retry 按钮 |

### plan/page.tsx

| 问题 | 修复 |
|------|------|
| GET 非 2xx 静默忽略 | 用 `requestJson<StudyPlan>` 替换 |
| `throw new Error("生成失败")` 丢失服务端错误 | 用 `getErrorMessage` 直接展示服务端 error |
| `throw new Error("打卡失败")` 丢失服务端错误 | 同上 |
| `as StudyPlan` 非 2xx 时也会执行 | `requestJson` 仅在 ok 时返回 |
| NOT_FOUND 被当作错误处理 | `isNotFound(e)` → 正常空态，显示生成表单 |
| ENDPOINT_DISABLED 未处理 | `isEndpointDisabled(e)` → 显示"请在鸿学伴 HarmonyOS App 中查看或操作" |
| MODEL_UNAVAILABLE 等错误被统一替换为"生成失败" | 直接展示服务端 error 消息 |
| 无 AbortController | GET 添加 AbortController |
| 生成失败时用户输入丢失 | goal/days/minutes 在错误时保持不变 |
| 打卡失败时乐观更新未回滚 | 错误时回滚乐观更新 |

### quiz/page.tsx

| 问题 | 修复 |
|------|------|
| GET 历史非 2xx 静默忽略 | 用 `requestJson<{ results: QuizResult[] }>` 替换 |
| `throw new Error("生成失败")` 丢失服务端错误 | 用 `getErrorMessage` 直接展示服务端 error |
| `throw new Error("提交失败")` 丢失服务端错误 | 同上 |
| `as QuizView` / `as QuizResult` 非 2xx 时也会执行 | `requestJson` 仅在 ok 时返回 |
| ENDPOINT_DISABLED 未处理 | `isEndpointDisabled(e)` → 显示"请在鸿学伴 HarmonyOS App 中查看"提示（非红色） |
| MODEL_UNAVAILABLE 等错误被统一替换为"生成失败" | 直接展示服务端 error 消息 |
| 无 AbortController | GET 添加 AbortController |
| 生成失败时用户输入丢失 | courseId/topic/count/difficulty 在错误时保持不变 |

### knowledge/page.tsx

| 问题 | 修复 |
|------|------|
| `throw new Error(`检索失败 (HTTP ${res.status})`)` 丢失服务端错误 | 用 `requestJson` 替换，ApiError 保留服务端 error |
| `as { chunks?: KnowledgeChunk[] }` 非 2xx 时也会执行 | `requestJson` 仅在 ok 时返回 |
| 上传错误解析方式与其他页面不一致 | 统一用 `requestJson` + `getErrorMessage` |
| 无 AbortController（用户快速多次搜索时旧请求不取消） | 添加 `searchAbortRef`，新搜索前 abort 旧请求 |
| 搜索错误时用户输入丢失 | query 在错误时保持不变 |
| 上传错误时用户输入丢失 | source/text 仅在成功时清空 |

### profile/page.tsx

| 问题 | 修复 |
|------|------|
| `throw new Error(`加载失败 (HTTP ${res.status})`)` 丢失服务端错误 | 用 `requestJson<UserProfile>` 替换 |
| `as UserProfile` 非 2xx 时也会执行 | `requestJson` 仅在 ok 时返回 |
| PUT 错误解析方式与其他页面不一致 | 统一用 `requestJson` + `getErrorMessage` |
| NOT_FOUND 被当作错误处理 | `isNotFound(e)` → 显示"暂无画像数据"空态 |
| 无 AbortController | GET 添加 AbortController |
| 无重试按钮 | 添加重试按钮（RotateCcw 图标） |
| PUT 失败时用户编辑内容丢失 | 错误时不退出编辑模式，保留用户输入 |

## 三、API 错误码处理矩阵

| 错误码 | HTTP | page.tsx | courses | plan | quiz | knowledge | profile |
|--------|------|----------|---------|------|------|-----------|---------|
| `INTERNAL_ERROR` | 500 | 错误态+重试 | 错误态+重试 | 错误态+重试 | 历史区错误 | 错误消息 | 错误态+重试 |
| `NOT_FOUND` | 404 | — | — | 正常空态 | — | — | 正常空态 |
| `ENDPOINT_DISABLED` | 404 | — | — | App引导提示 | App引导提示 | — | — |
| `MODEL_UNAVAILABLE` | 503 | — | — | 服务端error | 服务端error | — | — |
| `MODEL_INVALID_RESPONSE` | 502 | — | — | 服务端error | 服务端error | — | — |
| `RATE_LIMITED` | 429 | — | — | 服务端error | 服务端error | — | — |
| `MISSING_FIELD` | 400 | — | — | 服务端error | 服务端error | 服务端error | 服务端error |
| `BAD_REQUEST` | 400 | — | — | 服务端error | 服务端error | 服务端error | 服务端error |
| `QUIZ_NOT_FOUND` | 404 | — | — | — | 服务端error | — | — |
| `NO_VALID_FIELDS` | 400 | — | — | — | — | — | 服务端error |
| 网络异常 | — | 错误态+重试 | 错误态+重试 | 错误态+重试 | 历史区错误 | 错误消息 | 错误态+重试 |
| AbortError | — | 不显示 | 不显示 | 不显示 | 不显示 | 不显示 | 不显示 |

## 四、测试数量与命令退出码

### 新增测试（client-api.test.ts）

| 测试用例 | 覆盖场景 |
|----------|---------|
| 200 JSON 成功响应 | 成功路径 |
| 201 JSON 成功响应 | POST 成功路径 |
| 400 `{ error, code }` | ApiError 保留 status/code/message |
| 404 `NOT_FOUND` | 资源不存在 |
| 404 `ENDPOINT_DISABLED` | 端点禁用 |
| 429 `RATE_LIMITED` | 限流 |
| 500 非 JSON 响应 | 通用 HTTP 状态消息 |
| 200 非法 JSON 响应 | INVALID_JSON 错误 |
| 网络异常 | 原始 Error 不包装 |
| AbortError | 不被吞掉 |
| 503 `MODEL_UNAVAILABLE` | 模型不可用 |
| 502 `MODEL_INVALID_RESPONSE` | 模型返回无效 |
| getErrorMessage: ApiError | 服务端消息 |
| getErrorMessage: AbortError | 返回 null |
| getErrorMessage: 普通 Error | message |
| getErrorMessage: 未知错误 | 回退文本 |
| isNotFound: NOT_FOUND | true |
| isNotFound: 其他 | false |
| isNotFound: 非 ApiError | false |
| isEndpointDisabled: ENDPOINT_DISABLED | true |
| isEndpointDisabled: 其他 | false |
| isEndpointDisabled: 非 ApiError | false |

共 24 个测试用例。Codex 复核时修正了“网络异常”用例，使同一次请求同时证明原始 `TypeError` 不被包装成 `ApiError`。

### 验收命令结果

| 命令 | 退出码 | 结果 |
|------|--------|------|
| `pnpm lint` | 0 | No ESLint warnings or errors |
| `pnpm typecheck` | 0 | 0 errors |
| `pnpm test` | 0 | 12 files, 139 tests passed（含新增 24 个） |
| `pnpm build` | 0 | Build completed, 所有页面静态生成 |
| `git diff --check` | 0 | Codex 复核时无空白错误 |
| 敏感信息扫描 | 0 | 无 Token/API Key/认证头泄露 |

## 五、尚未解决的问题

1. **Chat SSE 页面**：按任务要求不修改，其错误处理已在 `chat/route.ts` 服务端按错误码分类。
2. **运行时端到端验证**：本轮完成单元测试和生产构建验证，未在真实浏览器中点击操作验证。

## 六、受保护区域声明

以下文件本轮**未修改**：

- `apps/web/src/app/api/**` — 所有 API 路由
- `apps/web/src/lib/agents/**` — 所有 Agent 文件
- `apps/web/src/lib/api-errors.ts` — 服务端错误工具
- `apps/web/src/lib/store/**` — 状态管理
- `apps/web/src/lib/rag/**` — RAG 检索
- `apps/web/src/middleware.ts` — 中间件
- `apps/harmonyos/**` — 鸿蒙应用
- `DEVLOG.md` — 开发日志
- `docs/FRONTEND-RESOURCE-ADOPTION.md` — 前端资源文档
- `package.json` / `pnpm-lock.yaml` — 依赖配置
- 三份未跟踪审计文档（`CONTENT-QUALITY-AUDIT.md`、`HARMONYOS-LAYOUT-AUDIT-2.md`、`QUIZ-CONTENT-AUDIT-2.md`）

## 七、待 Codex 复核的文件

| 文件 | 复核要点 |
|------|---------|
| `apps/web/src/lib/client-api.ts` | ApiError 设计是否与服务端 `{ error, code }` 格式一致；requestJson 的错误解析逻辑是否覆盖所有服务端响应路径 |
| `apps/web/src/lib/client-api.test.ts` | 测试用例是否覆盖所有需要支持的错误码；mock 方式是否合理 |
| `apps/web/src/app/page.tsx` | 统计失败时显示"—"而非 0 是否符合产品预期 |
| `apps/web/src/app/plan/page.tsx` | NOT_FOUND 和 ENDPOINT_DISABLED 的区分处理是否与 API 路由实际返回一致 |
| `apps/web/src/app/quiz/page.tsx` | QuizView 类型兼容性（QuizPackage extends QuizView） |
| `apps/web/src/app/knowledge/page.tsx` | 搜索 AbortController 的 controller 身份校验逻辑 |
| `apps/web/src/app/profile/page.tsx` | NOT_FOUND 空态显示是否与产品预期一致 |
