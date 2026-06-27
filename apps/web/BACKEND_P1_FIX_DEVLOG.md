# 后端性能优化 P1 修复开发文档

> 本文件为本次后端 P1 修复任务的开发记录，按要求保留时间戳与节点进展，不覆写、不删除。
> 任务目录：apps/web
> 执行 Agent：后端性能优化子 Agent

## 任务概述

修复 apps/web 目录下三个 P1 问题：
- P1-1: orchestrator 重复代码
- P1-2: RAG 检索无缓存
- P1-3: quiz/submit 和 knowledge/upload 缺少 try-catch

修复后使用 `npx vitest run` 与 `npx tsc --noEmit --project tsconfig.typecheck.json` 验证。

## 节点进展记录

### 2026-06-27 — P1-1 完成：orchestrator 重复代码提取

文件：`apps/web/src/lib/agents/orchestrator.ts`

原状：`orchestrate`（非流式）与 `orchestrateStream`（流式）两个入口函数存在约 90 行重复逻辑
（上下文准备、前置 Agent、意图路由 switch、安全审核、会话持久化）。

修改：
- 提取公共辅助函数（均为模块私有，仅入口函数 export）：
  - `prepareContext(req)`：意图识别 + sessionId + 加载对话历史
  - `runPreAgents(req, emit?)`：Profile + Retrieval，可选流式推送
  - `routeMainAgent(intent, req, retrievalResult, history, emit?)`：意图路由；
    通过 `isStream = !!emit` 区分流式 / 非流式下 plan/quiz 的内容格式化
  - `runSafetyCheck(content, citations, emit?)`：安全审核，返回 safety + AgentResult
  - `persistConversation(sessionId, req, mainResult, intent)`：会话历史持久化
- import 新增 `SafetyResult` 类型用于 `runSafetyCheck` 返回标注
- 两个入口函数改用上述辅助函数，事件顺序、内容格式、降级文案与原实现完全一致

行为保持：非流式 plan/quiz 返回 `JSON.stringify(...)`；流式返回人类可读格式；
安全审核失败降级文案（流式 / 非流式略有差异）原样保留。

### 2026-06-27 — P1-2 完成：RAG 检索 TF-IDF 缓存

文件：`apps/web/src/lib/rag/index.ts`

原状：`retrieve()` 每次调用都对全部文档重新 tokenize + computeIdf + 计算各文档向量，
这部分仅依赖文档集、与查询无关，存在重复计算。

修改：
- 新增 `RagIndexCache` 接口（key / idf / docVectors）
- 新增模块级缓存 `ragCacheMap`（Map，上限 8 条，FIFO 驱逐），支持多 courseId 并存不抖动
- 新增 `hashDocuments(docs)`（djb2 变体）：用 `id:text长度:text前64字符` 组合生成指纹
- 新增 `getRagIndex(docs)`：命中返回缓存，未命中构建并缓存
- 新增并 export `invalidateRagCache()`：清空全部缓存
- `retrieve()` 改为：取 `getRagIndex(knowledgePool)`，复用缓存的 idf / docVectors，
  仅查询向量每次计算；后续过滤 / 排序 / 回退逻辑不变

文档变更失效策略（双重保障）：
1. 自动：文档指纹变化 → 旧条目不再命中 → 自动重建
2. 显式：上传 / 删除知识时调用 `invalidateRagCache()`（见 P1-3 upload 路由）

测试影响：种子数据恒定 → 指纹恒定 → 首次构建后续命中；结果与评分完全一致，不破坏现有测试。

### 2026-06-27 — P1-3 完成：API 路由顶层 try-catch

文件 A：`apps/web/src/app/api/quiz/submit/route.ts`
- 在 `POST` 体外层包 `try { ... } catch (err) { ... return 500 }`
- 保留原有内层 try-catch（JSON 解析 400、评估 Agent 降级）
- 之前未捕获的异常（如 store.getQuiz / 评分循环 / recordQuizResult 抛错）现返回 500 而非崩溃

文件 B：`apps/web/src/app/api/knowledge/upload/route.ts`
- 在 `POST` 体外层包 `try { ... } catch (err) { ... return 500 }`
- 保留原有内层 try-catch（JSON 解析 400）
- import 新增 `invalidateRagCache`
- 在 `store.addKnowledgeBatch(chunks)` 后调用 `invalidateRagCache()`（文档变更清缓存）
- 之前未捕获的异常（如 chunkText / addKnowledgeBatch / logActivity 抛错）现返回 500

### 2026-06-27 — 验证

- `npx vitest run`：通过。4 个测试文件，68 个测试全部通过
  （含 rag/index.test.ts 15 个、safety-agent 19 个、db 17 个、utils 17 个）
- `npx tsc --noEmit --project tsconfig.typecheck.json`：通过。退出码 0，无类型错误

结论：三项 P1 修复均未破坏现有测试与类型检查。

## 涉及文件清单

1. `apps/web/src/lib/agents/orchestrator.ts` — 重构（提取 5 个辅助函数）
2. `apps/web/src/lib/rag/index.ts` — 新增 TF-IDF 索引缓存
3. `apps/web/src/app/api/quiz/submit/route.ts` — 顶层 try-catch
4. `apps/web/src/app/api/knowledge/upload/route.ts` — 顶层 try-catch + 缓存失效
