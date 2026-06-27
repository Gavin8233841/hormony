# Hormony API 参考文档

> 版本：1.1.0  
> 最后更新：2026-06-27  
> 适用项目：Hormony 智能学习助手（Next.js App Router）

---

## 目录

- [1. API 概述](#1-api-概述)
  - [1.1 Base URL](#11-base-url)
  - [1.2 认证方式](#12-认证方式)
  - [1.3 通用请求约定](#13-通用请求约定)
  - [1.4 通用错误格式](#14-通用错误格式)
  - [1.5 通用响应约定](#15-通用响应约定)
- [2. 端点清单](#2-端点清单)
- [3. 端点详细说明](#3-端点详细说明)
  - [3.1 POST /api/chat — SSE 流式对话](#31-post-apichat--sse-流式对话)
  - [3.2 GET /api/courses — 课程列表](#32-get-apicourses--课程列表)
  - [3.3 POST /api/knowledge/search — 知识检索](#33-post-apiknowledgesearch--知识检索)
  - [3.4 POST /api/knowledge/upload — 知识上传](#34-post-apiknowledgeupload--知识上传)
  - [3.5 GET /api/model/status — 模型状态](#35-get-apimodelstatus--模型状态)
  - [3.6 POST /api/plan — 生成计划](#36-post-apiplan--生成计划)
  - [3.7 POST /api/plan/save — 保存计划](#37-post-apiplansave--保存计划)
  - [3.8 PATCH /api/plan/save — 任务打卡](#38-patch-apiplansave--任务打卡)
  - [3.9 GET /api/profile — 获取画像](#39-get-apiprofile--获取画像)
  - [3.10 PUT /api/profile/update — 更新画像](#310-put-apiprofileupdate--更新画像)
  - [3.11 POST /api/quiz — 生成测验](#311-post-apiquiz--生成测验)
  - [3.12 POST /api/quiz/submit — 提交测验](#312-post-apiquizsubmit--提交测验)
  - [3.13 POST /api/safety-review — 安全审核](#313-post-apisafety-review--安全审核)
  - [3.14 GET /api/stats — 仪表盘统计](#314-get-apistats--仪表盘统计)
  - [3.15 GET /api/conversations — 会话历史](#315-get-apiconversations--会话历史)
  - [3.16 GET /api/health — 健康检查](#316-get-apihealth--健康检查)
- [4. 数据模型](#4-数据模型)
- [5. 错误码索引](#5-错误码索引)

---

## 1. API 概述

### 1.1 Base URL

所有 API 端点均挂载在 Next.js 应用的同源路径下，默认 Base URL 为：

```
http://localhost:3000
```

生产环境请替换为实际部署域名。所有路由文件均声明了 `export const dynamic = "force-dynamic"`，确保每次请求都动态执行，不经过静态缓存。

### 1.2 认证方式

当前版本未实现独立的身份认证机制（无 Token / Cookie / API Key 校验）。用户身份通过请求中的 `userId` 字段标识：

- **GET 请求**：通过查询参数 `?userId=xxx` 传递，未传时默认使用 `"demo"`。
- **POST / PUT / PATCH 请求**：通过请求体中的 `userId` 字段传递，未传时默认使用 `"demo"`。

> 注意：生产环境部署前应补充鉴权中间件，当前实现仅供开发与演示使用。

### 1.3 通用请求约定

| 约定项 | 说明 |
|--------|------|
| 请求体格式 | `application/json`（除 SSE 流式端点外） |
| 字符编码 | UTF-8 |
| 字符串处理 | 服务端会对字符串字段执行 `.trim()` 去除首尾空白 |
| 数值边界 | 数值类参数均会经过 `Math.min / Math.max` 钳制到合法范围 |
| CORS 预检 | 所有端点均实现了 `OPTIONS` 方法，返回 `204 No Content` |

### 1.4 通用错误格式

所有错误响应均使用统一的 JSON 结构：

```json
{
  "error": "错误描述（中文）",
  "code": "ERROR_CODE"
}
```

| HTTP 状态码 | 含义 | 说明 |
|-------------|------|------|
| 400 | 请求参数错误 | JSON 解析失败、必填字段缺失、字段值不合法等 |
| 404 | 资源不存在 | 指定的用户、计划、测验等未找到 |
| 500 | 服务器内部错误 | 服务处理异常，错误细节仅记录到服务端日志 |

### 1.5 通用响应约定

- 成功响应直接返回业务数据对象（如 `UserProfile`、`StudyPlan`），或包裹在具名字段中（如 `{ courses: [...] }`）。
- 所有响应的 `Content-Type` 为 `application/json`，SSE 端点除外（`text/event-stream`）。
- 时间字段统一使用 ISO 8601 格式（如 `"2026-06-27T08:00:00.000Z"`）。

---

## 2. 端点清单

| # | 方法 | 路径 | 功能 | 鉴权 |
|---|------|------|------|------|
| 1 | POST | `/api/chat` | SSE 流式多 Agent 对话（支持多轮上下文） | userId |
| 2 | GET | `/api/courses` | 获取用户课程列表 | userId (query) |
| 3 | POST | `/api/courses` | 添加新课程 | userId |
| 4 | POST | `/api/knowledge/search` | RAG 知识检索 | 无 |
| 5 | POST | `/api/knowledge/upload` | 上传知识文本到 RAG 知识库 | 无 |
| 6 | GET | `/api/model/status` | 查询模型服务配置状态 | 无 |
| 7 | GET | `/api/plan` | 获取已存学习计划 | userId (query) |
| 8 | POST | `/api/plan` | 生成学习计划 | userId |
| 9 | POST | `/api/plan/save` | 保存学习计划 | userId |
| 10 | PATCH | `/api/plan/save` | 更新计划任务打卡状态 | userId |
| 11 | GET | `/api/profile` | 获取用户学习画像 | userId (query) |
| 12 | PUT | `/api/profile/update` | 更新用户学习画像 | userId |
| 13 | GET | `/api/quiz` | 获取测验历史记录 | userId (query) |
| 14 | POST | `/api/quiz` | 生成测验题 | userId |
| 15 | POST | `/api/quiz/submit` | 提交测验答案并评分 | userId |
| 16 | POST | `/api/safety-review` | 内容安全审核 | 无 |
| 17 | GET | `/api/stats` | 仪表盘统计数据聚合 | userId (query) |
| 18 | GET | `/api/conversations` | 获取用户会话历史 | userId (query) |
| 19 | GET | `/api/health` | 服务健康检查 | 无 |

---

## 3. 端点详细说明

### 3.1 POST /api/chat — SSE 流式对话

多 Agent 协作的流式对话接口，通过 Server-Sent Events（SSE）实时推送思考过程、增量内容、引用来源与完成事件。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |
| `message` | string | 是 | — | 用户消息内容，上限 2000 字符 |
| `context.courseId` | string | 否 | — | 当前课程上下文 |
| `context.sessionId` | string | 否 | — | 会话 ID，用于上下文延续 |

**请求示例**

```bash
curl -N -X POST http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "demo",
    "message": "请帮我解释一下操作系统中的进程调度算法",
    "context": { "courseId": "cs101" }
  }'
```

**响应**

- `Content-Type: text/event-stream`
- `Cache-Control: no-cache, no-transform`
- `Connection: keep-alive`

每个事件以 `data: <JSON>\n\n` 格式推送，事件类型（`type` 字段）如下：

| 事件类型 | 载荷字段 | 说明 |
|----------|----------|------|
| `thinking` | `agent: AgentName` | 某个 Agent 开始思考 |
| `delta` | `content: string` | 增量文本片段 |
| `citation` | `source: Citation` | 引用来源 |
| `trace` | `agent: AgentName, content: string` | Agent 执行轨迹 |
| `done` | `sessionId: string` | 对话完成，返回会话 ID |

**响应示例（SSE 流）**

```
data: {"type":"thinking","agent":"Retrieval"}

data: {"type":"trace","agent":"Retrieval","content":"检索到 3 条相关知识片段"}

data: {"type":"delta","content":"进程调度是操作系统"}

data: {"type":"delta","content":"核心功能之一..."}

data: {"type":"citation","source":{"doc":"操作系统导论.pdf","page":42,"snippet":"调度算法决定下一个执行的进程"}}

data: {"type":"done","sessionId":"sess_abc123"}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少 `message` 字段 |
| 400 | `MESSAGE_TOO_LONG` | 消息超过 2000 字符 |

> 流式过程中的内部异常不会以 HTTP 错误返回（响应头已发送），而是通过 `trace` 事件推送错误提示，并以 `done` 事件（`sessionId: "error"`）结束流。

---

### 3.2 GET /api/courses — 课程列表

获取指定用户的所有课程信息。

**请求参数（Query）**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |

**请求示例**

```bash
curl "http://localhost:3000/api/courses?userId=demo"
```

**响应**

```json
{
  "courses": [
    {
      "id": "cs101",
      "title": "操作系统",
      "progress": 65,
      "docCount": 12,
      "topics": ["进程调度", "内存管理", "文件系统"]
    }
  ]
}
```

**响应字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| `courses` | `Course[]` | 课程数组 |
| `courses[].id` | string | 课程 ID |
| `courses[].title` | string | 课程标题 |
| `courses[].progress` | number | 学习进度（0-100） |
| `courses[].docCount` | number | 关联文档数量 |
| `courses[].topics` | string[] | 涵盖主题列表 |

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 500 | `INTERNAL_ERROR` | 课程数据获取失败 |

---

### 3.3 POST /api/knowledge/search — 知识检索

基于 RAG（检索增强生成）的知识库语义检索接口。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `query` | string | 是 | — | 检索查询文本 |
| `courseId` | string | 否 | — | 限定课程范围，未传则全局检索 |
| `topK` | number | 否 | `5` | 返回结果数量，范围 1-20 |

**请求示例**

```bash
curl -X POST http://localhost:3000/api/knowledge/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "进程间通信的方式有哪些",
    "courseId": "cs101",
    "topK": 5
  }'
```

**响应**

```json
{
  "chunks": [
    {
      "id": "k_abc123",
      "text": "进程间通信（IPC）主要包括管道、消息队列、共享内存、信号量、套接字等方式...",
      "source": "操作系统导论.pdf",
      "courseId": "cs101",
      "score": 0.92
    }
  ]
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少 `query` 字段 |

---

### 3.4 POST /api/knowledge/upload — 知识上传

上传知识文本到 RAG 知识库，服务端自动按段落/句子边界进行分块存储。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `courseId` | string | 是 | — | 所属课程 ID |
| `source` | string | 是 | — | 资料来源名称（如文件名） |
| `text` | string | 是 | — | 知识内容文本，上限 50000 字符 |

**分块规则**

- 单块上限：500 字符（`MAX_CHUNK_SIZE`）
- 优先按段落（双换行符）分割
- 段落超长时按句子边界（。！？.!?）二次分割

**请求示例**

```bash
curl -X POST http://localhost:3000/api/knowledge/upload \
  -H "Content-Type: application/json" \
  -d '{
    "courseId": "cs101",
    "source": "操作系统导论.pdf",
    "text": "进程是程序在计算机上的一次执行活动..."
  }'
```

**响应**

```json
{
  "success": true,
  "courseId": "cs101",
  "source": "操作系统导论.pdf",
  "chunkCount": 3,
  "chunkIds": ["k_abc123", "k_def456", "k_ghi789"]
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少 `courseId` / `source` / `text` |
| 400 | `TEXT_TOO_LONG` | 文本超过 50000 字符 |

---

### 3.5 GET /api/model/status — 模型状态

查询服务端模型配置状态。该接口仅返回配置元信息，**不会泄露任何 API 密钥**。

**请求**

无参数。

**请求示例**

```bash
curl http://localhost:3000/api/model/status
```

**响应**

```json
{
  "configured": true,
  "mode": "model",
  "provider": "openai-compatible",
  "baseURL": "https://api.example.com/v1",
  "modelName": "gpt-4o-mini",
  "timeoutMs": 30000
}
```

**响应字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| `configured` | boolean | 模型是否已正确配置（API Key 非空且非占位符） |
| `mode` | `"model" \| "demo"` | 运行模式：`model` 为真实模型，`demo` 为演示模式 |
| `provider` | `"openai-compatible"` | 模型提供商类型 |
| `baseURL` | string | 模型 API 基础地址 |
| `modelName` | string | 模型名称 |
| `timeoutMs` | number | 请求超时时间（毫秒） |

---

### 3.6 POST /api/plan — 生成计划

调用 Planner Agent 根据用户目标自动生成结构化学习计划。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |
| `goal` | string | 否 | `"制定学习计划"` | 学习目标描述，上限 500 字符 |
| `durationDays` | number | 否 | `14` | 计划周期（天），范围 1-30 |
| `dailyMinutes` | number | 否 | `90` | 每日学习时长（分钟），范围 15-480 |

**请求示例**

```bash
curl -X POST http://localhost:3000/api/plan \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "demo",
    "goal": "两周内掌握操作系统进程管理",
    "durationDays": 14,
    "dailyMinutes": 90
  }'
```

**响应**

返回 `StudyPlan` 对象（详见 [数据模型](#studyplan)）。

```json
{
  "planId": "plan_xyz789",
  "userId": "demo",
  "goal": "两周内掌握操作系统进程管理",
  "tasks": [
    {
      "id": "task_001",
      "title": "阅读《操作系统导论》进程章节",
      "date": "2026-06-27",
      "estimatedMin": 60,
      "type": "reading",
      "done": false
    }
  ]
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `GOAL_TOO_LONG` | 目标描述超过 500 字符 |
| 500 | `INTERNAL_ERROR` | 生成计划失败 |

---

### 3.7 POST /api/plan/save — 保存计划

将学习计划持久化存储到服务端。支持新建和覆盖保存。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `planId` | string | 否 | `plan_<时间戳>` | 计划 ID，未传则自动生成 |
| `userId` | string | 否 | `"demo"` | 用户标识 |
| `goal` | string | 是 | — | 学习目标描述，上限 500 字符 |
| `tasks` | `PlanTask[]` | 是 | — | 任务列表，数量 1-50 |

**`PlanTask` 字段**

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `id` | string | `task_<随机>` | 任务 ID |
| `title` | string | `"未命名任务"` | 任务标题，上限 200 字符 |
| `date` | string | 当天日期 | 任务日期（YYYY-MM-DD） |
| `estimatedMin` | number | `30` | 预计时长（分钟），钳制范围 5-480 |
| `type` | `"review"\|"practice"\|"reading"\|"quiz"` | `"review"` | 任务类型 |
| `done` | boolean | `false` | 是否完成 |

**请求示例**

```bash
curl -X POST http://localhost:3000/api/plan/save \
  -H "Content-Type: application/json" \
  -d '{
    "planId": "plan_xyz789",
    "userId": "demo",
    "goal": "两周内掌握操作系统进程管理",
    "tasks": [
      {
        "id": "task_001",
        "title": "阅读进程调度章节",
        "date": "2026-06-27",
        "estimatedMin": 60,
        "type": "reading",
        "done": false
      }
    ]
  }'
```

**响应**

返回保存后的完整 `StudyPlan` 对象。

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少目标描述 |
| 400 | `GOAL_TOO_LONG` | 目标描述超过 500 字符 |
| 400 | `EMPTY_TASKS` | 任务列表为空 |
| 400 | `TOO_MANY_TASKS` | 任务数量超过 50 |

---

### 3.8 PATCH /api/plan/save — 任务打卡

更新学习计划中某个任务的完成状态（打卡 / 取消打卡）。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |
| `taskId` | string | 是 | — | 要更新的任务 ID |
| `done` | boolean | 否 | `false` | 目标完成状态 |

**请求示例**

```bash
curl -X PATCH http://localhost:3000/api/plan/save \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "demo",
    "taskId": "task_001",
    "done": true
  }'
```

**响应**

返回更新后的完整 `StudyPlan` 对象。

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少 `taskId` |
| 404 | `NOT_FOUND` | 计划不存在 |

---

### 3.9 GET /api/profile — 获取画像

获取指定用户的学习画像信息。若指定用户不存在，自动回退到 `demo` 用户。

**请求参数（Query）**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |

**请求示例**

```bash
curl "http://localhost:3000/api/profile?userId=demo"
```

**响应**

返回 `UserProfile` 对象（详见 [数据模型](#userprofile)）。

```json
{
  "userId": "demo",
  "name": "小明",
  "stage": "本科",
  "weakTopics": ["进程调度", "虚拟内存"],
  "strongTopics": ["数据结构", "算法"],
  "learningStyle": "视觉型",
  "stats": {
    "totalQuestions": 128,
    "accuracy": 0.82,
    "studyDays": 15
  }
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 404 | `NOT_FOUND` | 用户不存在（且 demo 用户也不存在） |
| 500 | `INTERNAL_ERROR` | 画像数据获取失败 |

---

### 3.10 PUT /api/profile/update — 更新画像

更新用户学习画像。采用白名单机制，仅接受合法字段，防止非法字段注入。

**请求**

请求体为 `Partial<UserProfile>` 与可选 `userId` 的组合。仅以下字段会被处理：

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| `userId` | string | 默认 `"demo"` | 用户标识 |
| `name` | string | 1-100 字符 | 用户名称 |
| `stage` | string | 1-100 字符 | 学习阶段（本科 / 硕士 / ...） |
| `learningStyle` | string | 1-100 字符 | 学习风格 |
| `weakTopics` | string[] | 每项上限 50 字符，最多 20 项 | 薄弱主题列表 |
| `strongTopics` | string[] | 每项上限 50 字符，最多 20 项 | 擅长主题列表 |

> `stats` 字段为系统自动维护，不接受手动更新。

**请求示例**

```bash
curl -X PUT http://localhost:3000/api/profile/update \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "demo",
    "name": "小明",
    "stage": "硕士",
    "weakTopics": ["进程调度", "虚拟内存", "文件系统"]
  }'
```

**响应**

返回更新后的完整 `UserProfile` 对象。

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少 `userId` |
| 400 | `NO_VALID_FIELDS` | 没有有效的更新字段 |
| 404 | `NOT_FOUND` | 用户不存在 |

---

### 3.11 POST /api/quiz — 生成测验

调用 Quiz Agent 根据课程与主题自动生成测验题。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |
| `courseId` | string | 否 | `"cs101"` | 课程 ID |
| `topic` | string | 否 | `"综合"` | 测验主题 |
| `count` | number | 否 | `5` | 题目数量，范围 1-20 |
| `difficulty` | `"easy"\|"medium"\|"hard"` | 否 | `"medium"` | 难度等级 |

**请求示例**

```bash
curl -X POST http://localhost:3000/api/quiz \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "demo",
    "courseId": "cs101",
    "topic": "进程调度",
    "count": 5,
    "difficulty": "medium"
  }'
```

**响应**

返回 `Quiz` 对象（详见 [数据模型](#quiz)）。

```json
{
  "quizId": "quiz_abc123",
  "courseId": "cs101",
  "topic": "进程调度",
  "questions": [
    {
      "id": "q_001",
      "type": "choice",
      "stem": "以下哪种调度算法是非抢占式的？",
      "options": ["FCFS", "RR", "SRTF", "MLFQ"],
      "answer": "FCFS",
      "explanation": "FCFS（先来先服务）一旦进程获得 CPU 就会运行到结束或阻塞，不会被抢占。"
    },
    {
      "id": "q_002",
      "type": "short",
      "stem": "简述时间片轮转调度算法的基本思想。",
      "answer": "将 CPU 处理时间划分为固定大小的时间片...",
      "explanation": "时间片轮转适合分时系统..."
    }
  ]
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 500 | `INTERNAL_ERROR` | 生成测验失败 |

---

### 3.12 POST /api/quiz/submit — 提交测验

提交测验答案，服务端自动评分并调用 Evaluator Agent 生成诊断报告与薄弱点分析。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `quizId` | string | 是 | — | 测验 ID |
| `userId` | string | 否 | `"demo"` | 用户标识 |
| `answers` | `QuizAnswer[]` | 是 | — | 答案列表，数量 1-50 |

**`QuizAnswer` 字段**

| 字段 | 类型 | 说明 |
|------|------|------|
| `questionId` | string | 题目 ID |
| `userAnswer` | string | 用户答案 |

> 评分规则：将用户答案与标准答案均转为大写后进行精确匹配（`trim().toUpperCase()` 比较）。

**请求示例**

```bash
curl -X POST http://localhost:3000/api/quiz/submit \
  -H "Content-Type: application/json" \
  -d '{
    "quizId": "quiz_abc123",
    "userId": "demo",
    "answers": [
      { "questionId": "q_001", "userAnswer": "FCFS" },
      { "questionId": "q_002", "userAnswer": "时间片轮转将处理时间划分为固定时间片..." }
    ]
  }'
```

**响应**

返回 `QuizResult` 对象（详见 [数据模型](#quizresult)）。

```json
{
  "quizId": "quiz_abc123",
  "userId": "demo",
  "totalQuestions": 2,
  "correctCount": 1,
  "accuracy": 0.5,
  "details": [
    {
      "questionId": "q_001",
      "stem": "以下哪种调度算法是非抢占式的？",
      "userAnswer": "FCFS",
      "correctAnswer": "FCFS",
      "isCorrect": true,
      "explanation": "FCFS（先来先服务）一旦进程获得 CPU 就会运行到结束或阻塞..."
    }
  ],
  "evaluation": "本次测验正确率 50%。在进程调度基础概念上掌握较好，但在算法细节对比方面存在不足...",
  "weakTopics": ["操作系统导论"],
  "submittedAt": "2026-06-27T08:30:00.000Z"
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少 `quizId` |
| 400 | `EMPTY_ANSWERS` | 答案列表为空 |
| 400 | `TOO_MANY_ANSWERS` | 答案数量超过 50 |
| 404 | `QUIZ_NOT_FOUND` | 测验不存在或已过期 |

---

### 3.13 POST /api/safety-review — 安全审核

对生成内容进行安全审核，检测潜在风险与幻觉。

**请求**

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `content` | string | 是 | — | 待审核内容，上限 10000 字符 |
| `userId` | string | 否 | — | 用户标识 |
| `citations` | `Citation[]` | 否 | `[]` | 内容引用来源列表 |

**请求示例**

```bash
curl -X POST http://localhost:3000/api/safety-review \
  -H "Content-Type: application/json" \
  -d '{
    "content": "进程调度算法中，FCFS 是最公平的算法。",
    "citations": [
      { "doc": "操作系统导论.pdf", "page": 42 }
    ]
  }'
```

**响应**

返回 `SafetyResult` 对象（详见 [数据模型](#safetyresult)）。

```json
{
  "passed": false,
  "flags": ["unverified-claim"],
  "hallucinationRisk": "medium",
  "suggestion": "该表述过于绝对，建议补充条件说明或引用权威来源。"
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 400 | `BAD_REQUEST` | 请求体不是有效 JSON |
| 400 | `MISSING_FIELD` | 缺少 `content` 字段 |
| 400 | `CONTENT_TOO_LONG` | 内容超过 10000 字符 |
| 500 | `INTERNAL_ERROR` | 安全审核服务异常 |

---

### 3.14 GET /api/stats — 仪表盘统计

聚合用户的学习统计数据，用于仪表盘展示。

**请求参数（Query）**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |

**请求示例**

```bash
curl "http://localhost:3000/api/stats?userId=demo"
```

**响应**

返回 `DashboardStats` 对象（详见 [数据模型](#dashboardstats)）。

```json
{
  "userId": "demo",
  "totalQuestions": 128,
  "accuracy": 0.82,
  "studyDays": 15,
  "activeCourses": 3,
  "totalTasks": 42,
  "completedTasks": 28,
  "totalQuizSubmissions": 8,
  "recentActivity": [
    {
      "type": "chat",
      "description": "对话：进程调度算法",
      "timestamp": "2026-06-27T08:00:00.000Z"
    },
    {
      "type": "quiz",
      "description": "提交测验：进程调度（正确率 80%）",
      "timestamp": "2026-06-26T20:30:00.000Z"
    }
  ]
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 500 | `INTERNAL_ERROR` | 统计数据获取失败 |

---

### 3.15 GET /api/conversations — 会话历史

获取用户的历史对话记录，按时间倒序返回。

**请求参数（Query）**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `userId` | string | 否 | `"demo"` | 用户标识 |
| `limit` | number | 否 | `20` | 返回条数，范围 1-100 |

**请求示例**

```bash
curl "http://localhost:3000/api/conversations?userId=demo&limit=10"
```

**响应**

```json
{
  "conversations": [
    {
      "sessionId": "sess_abc123",
      "userId": "demo",
      "message": "请解释进程调度算法",
      "response": "进程调度是操作系统的核心功能...",
      "intent": "知识问答",
      "citations": [
        { "doc": "操作系统导论.pdf", "page": 42 }
      ],
      "createdAt": "2026-06-27T08:00:00.000Z"
    }
  ],
  "count": 1
}
```

**错误响应**

| HTTP | code | 触发条件 |
|------|------|----------|
| 500 | `INTERNAL_ERROR` | 会话历史获取失败 |

---

### 3.16 GET /api/health — 健康检查

服务健康检查端点，返回服务运行状态、模型配置摘要与数据概况。

**请求**

无参数。

**请求示例**

```bash
curl http://localhost:3000/api/health
```

**响应**

```json
{
  "status": "ok",
  "timestamp": "2026-06-27T08:00:00.000Z",
  "uptime": 3600.5,
  "model": {
    "configured": true,
    "mode": "model",
    "provider": "openai-compatible"
  },
  "data": {
    "profiles": "loaded",
    "courses": 3,
    "quizSubmissions": 8
  },
  "version": "1.0.0"
}
```

**响应字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| `status` | `"ok"` | 服务状态 |
| `timestamp` | string | 当前服务器时间（ISO 8601） |
| `uptime` | number | 进程运行时长（秒） |
| `model.configured` | boolean | 模型是否已配置 |
| `model.mode` | `"model"\|"demo"` | 运行模式 |
| `model.provider` | string | 模型提供商 |
| `data.profiles` | `"loaded"\|"empty"` | 画像数据状态 |
| `data.courses` | number | 活跃课程数 |
| `data.quizSubmissions` | number | 测验提交总数 |
| `version` | string | API 版本号 |

---

## 4. 数据模型

### UserProfile

用户学习画像。

```typescript
interface UserProfile {
  userId: string;
  name: string;
  stage: string;              // 学习阶段：本科 / 硕士 / ...
  weakTopics: string[];       // 薄弱主题
  strongTopics: string[];     // 擅长主题
  learningStyle: string;      // 学习风格
  stats: {
    totalQuestions: number;   // 累计答题数
    accuracy: number;         // 正确率（0-1）
    studyDays: number;        // 学习天数
  };
}
```

### Course

课程信息。

```typescript
interface Course {
  id: string;
  title: string;
  progress: number;           // 学习进度（0-100）
  docCount: number;           // 关联文档数
  topics: string[];           // 涵盖主题
}
```

### StudyPlan

学习计划。

```typescript
interface StudyPlan {
  planId: string;
  userId: string;
  goal: string;
  tasks: PlanTask[];
}

interface PlanTask {
  id: string;
  title: string;
  date: string;               // YYYY-MM-DD
  estimatedMin: number;       // 预计时长（分钟）
  type: "review" | "practice" | "reading" | "quiz";
  done?: boolean;
}
```

### Quiz

测验。

```typescript
interface Quiz {
  quizId: string;
  courseId: string;
  topic: string;
  questions: QuizQuestion[];
}

interface QuizQuestion {
  id: string;
  type: "choice" | "short";   // 选择题 / 简答题
  stem: string;               // 题干
  options?: string[];         // 选项（仅选择题）
  answer: string;             // 标准答案
  explanation: string;        // 解析
}
```

### QuizResult

测验结果。

```typescript
interface QuizResult {
  quizId: string;
  userId: string;
  totalQuestions: number;
  correctCount: number;
  accuracy: number;           // 正确率（0-1）
  details: QuizResultDetail[];
  evaluation: string;         // 诊断报告
  weakTopics: string[];       // 薄弱主题
  submittedAt: string;        // 提交时间（ISO 8601）
}

interface QuizResultDetail {
  questionId: string;
  stem: string;
  userAnswer: string;
  correctAnswer: string;
  isCorrect: boolean;
  explanation: string;
}
```

### KnowledgeChunk

知识切片。

```typescript
interface KnowledgeChunk {
  id: string;
  text: string;
  source: string;             // 来源名称
  courseId: string;
  score?: number;             // 检索相关性评分
}
```

### Citation

引用来源。

```typescript
interface Citation {
  doc: string;                // 文档名称
  page?: number;              // 页码
  snippet?: string;           // 引用片段
}
```

### ChatMessage

对话消息。

```typescript
interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
  citations?: Citation[];
  agentTrace?: string[];      // Agent 执行轨迹
}
```

### SafetyResult

安全审核结果。

```typescript
interface SafetyResult {
  passed: boolean;
  flags: string[];            // 风险标签
  hallucinationRisk: "low" | "medium" | "high";
  suggestion?: string;        // 修改建议
}
```

### DashboardStats

仪表盘统计。

```typescript
interface DashboardStats {
  userId: string;
  totalQuestions: number;
  accuracy: number;
  studyDays: number;
  activeCourses: number;
  totalTasks: number;
  completedTasks: number;
  totalQuizSubmissions: number;
  recentActivity: RecentActivity[];
}

interface RecentActivity {
  type: "chat" | "quiz" | "plan" | "study";
  description: string;
  timestamp: string;          // ISO 8601
}
```

### ConversationRecord

会话记录。

```typescript
interface ConversationRecord {
  sessionId: string;
  userId: string;
  message: string;
  response: string;
  intent: string;             // 意图分类
  citations: Citation[];
  createdAt: string;          // ISO 8601
}
```

### AgentName

Agent 名称枚举。

```typescript
type AgentName =
  | "Profile"
  | "Retrieval"
  | "Planner"
  | "Tutor"
  | "Quiz"
  | "Evaluator"
  | "Safety";
```

### StreamEvent

SSE 流式事件（联合类型）。

```typescript
type StreamEvent =
  | { type: "thinking"; agent: AgentName }
  | { type: "delta"; content: string }
  | { type: "citation"; source: Citation }
  | { type: "trace"; agent: AgentName; content: string }
  | { type: "done"; sessionId: string };
```

---

## 5. 错误码索引

| 错误码 | HTTP 状态码 | 说明 | 出现端点 |
|--------|-------------|------|----------|
| `BAD_REQUEST` | 400 | 请求体不是有效 JSON | 所有 POST/PUT/PATCH 端点 |
| `MISSING_FIELD` | 400 | 缺少必填字段 | chat, knowledge/search, knowledge/upload, plan/save, plan/save(PATCH), profile/update, quiz/submit, safety-review |
| `MESSAGE_TOO_LONG` | 400 | 消息超过 2000 字符 | chat |
| `TEXT_TOO_LONG` | 400 | 知识文本超过 50000 字符 | knowledge/upload |
| `GOAL_TOO_LONG` | 400 | 目标描述超过 500 字符 | plan, plan/save |
| `EMPTY_TASKS` | 400 | 任务列表为空 | plan/save |
| `TOO_MANY_TASKS` | 400 | 任务数量超过 50 | plan/save |
| `EMPTY_ANSWERS` | 400 | 答案列表为空 | quiz/submit |
| `TOO_MANY_ANSWERS` | 400 | 答案数量超过 50 | quiz/submit |
| `CONTENT_TOO_LONG` | 400 | 安全审核内容超过 10000 字符 | safety-review |
| `NO_VALID_FIELDS` | 400 | 没有有效的更新字段 | profile/update |
| `NOT_FOUND` | 404 | 用户/计划不存在 | profile, profile/update, plan/save(PATCH) |
| `QUIZ_NOT_FOUND` | 404 | 测验不存在或已过期 | quiz/submit |
| `INTERNAL_ERROR` | 500 | 服务器内部错误 | courses, profile, plan, quiz, safety-review, stats, conversations |

---

> **文档维护说明**：本文档基于 `apps/web/src/app/api/` 目录下的 `route.ts` 文件及 `apps/web/src/lib/types.ts` 自动梳理编写。若 API 发生变更，请同步更新本文档。
