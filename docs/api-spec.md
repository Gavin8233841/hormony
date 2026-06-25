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
  "questions": [
    {
      "id": "q1",
      "type": "choice",
      "stem": "二叉搜索树中序遍历的结果是？",
      "options": ["A. 升序", "B. 降序", "C. 随机", "D. 不确定"],
      "answer": "A",
      "explanation": "二叉搜索树中序遍历得到有序序列。"
    }
  ]
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
