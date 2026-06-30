# 接口规范

> 所有接口由 `apps/web` 的 Next.js API Routes 提供，鸿蒙端通过 HTTP/SSE 调用。
> Base URL: `http://<host>:3000/api`

## 通用约定

- 请求/响应均为 JSON（流式接口除外）
- 认证：`Authorization: Bearer <token>`（初期可省略）
- 错误格式：`{ "error": string, "code": string }`
- 模型密钥只由 Web 服务端进程环境变量读取，不出现在任何接口响应中

---

## GET /api/model/status

获取模型服务端配置状态，用于联调确认当前处于真实模型模式还是演示模式。

**响应**
```json
{
  "configured": false,
  "mode": "demo",
  "provider": "openai-compatible",
  "baseURL": "https://ark.cn-beijing.volces.com/api/v3",
  "modelName": "doubao-seed-2-1-pro-260628",
  "timeoutMs": 60000
}
```

> 响应不包含 `MODEL_API_KEY`。

---

## POST /api/chat

多 Agent 对话主入口，支持流式输出。

**请求**
```json
{
  "userId": "string",
  "message": "string",
  "context": {
    "courseId": "string?",
    "sessionId": "string?"
  }
}
```

**响应（SSE 流）**
```
data: {"type":"thinking","agent":"Retrieval"}\n\n
data: {"type":"delta","content":"根据课程资料"}\n\n
data: {"type":"citation","source":{"doc":"数据结构.pdf","page":12}}\n\n
data: {"type":"done","sessionId":"xxx"}\n\n
```

---

## GET /api/profile?userId=...

获取用户学习画像。

**响应**
```json
{
  "userId": "string",
  "name": "string",
  "stage": "本科",
  "weakTopics": ["树", "图论"],
  "strongTopics": ["数组"],
  "learningStyle": "视觉型",
  "stats": { "totalQuestions": 120, "accuracy": 0.78 }
}
```

---

## GET /api/courses?userId=...

获取课程列表。

**响应**
```json
{
  "courses": [
    { "id": "cs101", "title": "数据结构", "progress": 0.65, "docCount": 12 }
  ]
}
```

---

## POST /api/plan

生成学习计划。

**请求**
```json
{
  "userId": "string",
  "goal": "两周内复习数据结构期末考试",
  "durationDays": 14,
  "dailyMinutes": 90
}
```

**响应**
```json
{
  "planId": "string",
  "tasks": [
    { "id": "t1", "title": "复习树与二叉树", "date": "2026-06-25", "estimatedMin": 45, "type": "review" }
  ]
}
```

生成成功后计划会保存到当前用户，首页与计划页可通过 GET 读取同一份任务状态。

---

## GET /api/plan?userId=...

获取用户当前学习计划；不存在时返回 `404 NOT_FOUND`。

---

## PATCH /api/plan/save

更新单个计划任务的完成状态。

```json
{
  "userId": "demo",
  "taskId": "task_id",
  "done": true
}
```

返回更新后的完整 `StudyPlan`；计划或任务不存在时返回 `404 NOT_FOUND`。

---

## POST /api/quiz

生成测验题。

**请求**
```json
{
  "userId": "string",
  "courseId": "cs101",
  "topic": "树",
  "count": 5,
  "difficulty": "medium"
}
```

**响应**
```json
{
  "quizId": "string",
  "courseId": "cs101",
  "topic": "树",
  "questions": [
    {
      "id": "q1",
      "type": "choice",
      "stem": "二叉搜索树中序遍历的结果是？",
      "options": ["A. 升序", "B. 降序", "C. 随机", "D. 不确定"]
    }
  ]
}
```

生成接口不返回答案和解析。完整题目只保存在服务端，提交后才返回评分与解析。

---

## GET /api/quiz?courseId=...

返回指定课程的题库目录，不返回题目正文、答案或解析。

```json
{
  "quizzes": [
    {
      "quizId": "quiz_cs101_tree",
      "courseId": "cs101",
      "topic": "二叉树与BST",
      "questionCount": 3
    }
  ]
}
```

---

## POST /api/quiz/submit

提交答案并返回整份测验的评分、逐题解析和薄弱知识点。缺失答案按未作答计入总题数。

**请求**
```json
{
  "quizId": "string",
  "userId": "demo",
  "answers": [
    { "questionId": "q1", "userAnswer": "A. 升序" }
  ]
}
```

**响应**
```json
{
  "quizId": "string",
  "userId": "demo",
  "totalQuestions": 5,
  "correctCount": 1,
  "accuracy": 0.2,
  "details": [],
  "evaluation": "string",
  "weakTopics": ["二叉树与BST"],
  "submittedAt": "ISO-8601"
}
```

---

## GET /api/resources

获取学习资源索引。可使用 `courseId` 和 `type` 筛选；`type` 仅支持 `textbook`、`documentation`、`course`、`standard`、`tool`。

```json
{
  "resources": [],
  "total": 0
}
```

---

## POST /api/safety-review

内容安全审核（内部调用，也可独立测试）。

**请求**
```json
{
  "content": "string",
  "userId": "string?"
}
```

**响应**
```json
{
  "passed": true,
  "flags": [],
  "hallucinationRisk": "low",
  "suggestion": "string?"
}
```

---

## POST /api/knowledge/search

检索知识库（简化版 RAG）。

**请求**
```json
{
  "query": "二叉搜索树",
  "courseId": "cs101",
  "topK": 5
}
```

**响应**
```json
{
  "chunks": [
    {
      "id": "k1",
      "text": "二叉搜索树（BST）...",
      "source": "数据结构.pdf",
      "courseId": "cs101",
      "score": 1
    }
  ]
}
```

> 上传接口暂未实现。初赛阶段先保持内置课程切片，后续再补 `POST /api/knowledge/upload`。
