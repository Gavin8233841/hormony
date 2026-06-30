# 接口规范

> 所有接口由 `apps/web` 的 Next.js API Routes 提供，鸿蒙端通过 HTTP/SSE 调用。
> 生产 Base URL: `https://<project>.vercel.app/api`。Vercel 只提供无状态 Agent 网关，用户学习状态保存在 HarmonyOS ArkData。

## 通用约定

- 请求/响应均为 JSON（流式接口除外）
- 生产调用频率由 Vercel Firewall 与豆包额度上限共同约束
- 错误格式：`{ "error": string, "code": string }`
- 模型密钥只由 Web 服务端进程环境变量读取，不出现在任何接口响应中
- `MODEL_API_KEY` 缺失或模型不可用时，AI 接口返回 `503 MODEL_UNAVAILABLE`，不存在演示回答

---

## GET /api/model/status

获取模型服务端配置状态，用于联调确认真实模型是否就绪。

**响应**
```json
{
  "configured": false,
  "mode": "unavailable",
  "provider": "openai-compatible",
  "baseURL": "https://ark.cn-beijing.volces.com/api/v3",
  "modelName": "doubao-seed-2-1-pro-260628",
  "timeoutMs": 45000
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
  },
  "profile": {
    "stage": "本科二年级",
    "weakTopics": ["树与图"],
    "strongTopics": ["数组"],
    "learningStyle": "视觉型",
    "stats": { "totalQuestions": 128, "accuracy": 0.76, "studyDays": 23 }
  },
  "history": [
    { "role": "user", "content": "上一轮问题" },
    { "role": "assistant", "content": "上一轮真实模型回答" }
  ]
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

无状态部署中禁用，返回 `404 ENDPOINT_DISABLED`。用户画像由 HarmonyOS ArkData 读取。

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

生成结果不在服务端保存。HarmonyOS 收到结果后写入 ArkData，首页与计划页读取同一份本地状态。

---

## GET /api/plan?userId=...

无状态部署中禁用，返回 `404 ENDPOINT_DISABLED`。

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

无状态部署中禁用。任务完成状态由 HarmonyOS 本地更新。

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

生成接口同时返回 `grading` 数组，HarmonyOS 状态层单独保存该数组，答题界面提交前不展示答案。评分、画像与课程进度更新均在本地执行，服务端不保存。

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

无状态部署中禁用。HarmonyOS 使用本次 `QuizPackage.grading` 在本地评分并保存结果。

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
  "userId": "demo",
  "query": "二叉搜索树",
  "courseId": "cs101",
  "topK": 5
}
```

检索成功后会记录当前用户的学习活动，用于后续学习轨迹与推荐。

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
