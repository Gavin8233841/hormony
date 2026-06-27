# 后端 P2 代码清理开发文档

> 本文件为本次后端 P2 代码清理任务的开发记录，按要求保留时间戳与节点进展，不覆写、不删除。
> 任务目录：apps/web
> 执行 Agent：后端代码清理子 Agent
> 关联文档：`BACKEND_P1_FIX_DEVLOG.md`（P1 修复记录，本任务未改动该文件）

## 任务概述

在 apps/web 目录下执行三项 P2 代码清理：
- P2-1: 移除未使用依赖（@ai-sdk/openai、ai、zod）
- P2-2: 移除 src/lib/ 下的死代码（未使用的导出函数 / store 方法）
- P2-3: 统一 API 成功响应格式（评估后跳过，见下方说明）

清理后使用 `npx vitest run` 与 `npx tsc --noEmit --project tsconfig.typecheck.json` 验证。

## 节点进展记录

### 2026-06-27 — P2-1 完成：移除未使用依赖

文件：`apps/web/package.json`、`apps/web/pnpm-lock.yaml`

排查方式：用 Grep 在 `src/` 下搜索包名引用（含 `from 'pkg'` / `require('pkg')` / 核心导出符号），
并在 `apps/web` 全目录（排除 node_modules / .next）复查，确认以下三个包仅在 package.json 与
pnpm-lock.yaml 中出现，源码无任何 import：

- `@ai-sdk/openai@0.0.66` — 无引用（无 streamText / generateText / @ai-sdk 等）
- `ai@3.4.33` — 无引用
- `zod@3.23.8` — 无引用

修改：从 dependencies 中移除上述三项；随后执行 `pnpm install --no-frozen-lockfile`
（.npmrc 启用 frozen-lockfile，需显式 --no-frozen-lockfile 才能更新 lockfile），
lockfile 同步成功，共卸载 57 个包（含 5 个直接依赖及其传递依赖）。

### 2026-06-27 — P2-2 完成：移除 src/lib/ 死代码

排查范围：utils.ts、agents/、store/、rag/、model.ts 的全部导出符号。

排查结论：
- agents/：7 个 agent（profile/retrieval/tutor/planner/quiz/evaluator/safety）均被
  `orchestrator.ts` 引用，无死 agent。
- model.ts：`callModel` / `callModelWithHistory` / `extractJsonPayload` /
  `getModelRuntimeInfo` 均被使用（agents 与 health/model-status 路由）。
- rag/index.ts：`retrieve` / `invalidateRagCache` 均被使用。
- store/db.ts：除 `addKnowledge`（单条）外，其余 16 个方法均被生产代码或测试引用。
- utils.ts：`generateId` / `sanitizeUserId` 被广泛使用；`cn` 无任何调用方。

移除的死代码：

1. `apps/web/src/lib/utils.ts` — 移除未使用的 `cn(...)` 函数及其 import
   （`clsx`、`tailwind-merge`、`ClassValue` 类型）。`cn` 在 src/ 下无任何调用方
   （Grep `\bcn\b` 仅命中定义本身与 model.ts 中 URL 字符串的误匹配）。
   - 连带影响：`clsx`、`tailwind-merge` 此后无任何源码引用，作为死依赖一并从
     package.json 移除（见下方“连带清理”）。这是 P2-2 移除 `cn` 的直接后果，
     留下它们会形成新的死依赖，与清理目标相悖。
2. `apps/web/src/lib/store/db.ts` — 移除未使用的 `addKnowledge(chunk)` 单条方法。
   生产代码与 db.test.ts 均只使用 `addKnowledgeBatch`；单条能力可由
   `addKnowledgeBatch([chunk])` 等价替代，不损失功能。

连带清理（P2-2 移除 cn 的直接后果，非 P2-1 列表内新增项）：
- `apps/web/package.json` 移除 `clsx@2.1.1`、`tailwind-merge@2.5.4`。
  复查确认二者在 apps/web 全目录（排除 node_modules / .next）仅出现在 package.json 与
  pnpm-lock.yaml，无任何源码 / 配置 import。

### 2026-06-27 — P2-3 跳过：API 成功响应格式统一

排查方式：逐一读取 `src/app/api/` 下全部 15 个路由文件，并核对前端页面消费方式。

现状（成功响应格式不统一）：
- 裸对象返回：profile / plan(GET,POST) / quiz(POST) / stats / model/status /
  safety-review / profile/update / courses(POST) / plan/save / quiz/submit
- 命名键包装：courses GET `{courses}`、conversations `{conversations,count}`、
  knowledge/search `{chunks}`、quiz GET `{results}`
- 已带 success：knowledge/upload `{success:true, courseId, source, chunkCount, chunkIds}`
- 非标准：health 自定义健康检查结构 `{status,timestamp,uptime,model,data,version}`；
  chat 为 SSE 流式（`data: <event>\n\n`），非 JSON 成功响应

跳过原因：前端页面与当前各路由响应形状强耦合——
- `courses/page.tsx`：`as { courses?: Course[] }` 后取 `data.courses`
- `profile/page.tsx`：`as UserProfile` 直接当裸对象用（取 `.name` / `.stats` 等）
- `profile/update`：`as UserProfile` 直接用
统一为 `{ success: true, data: ... }` 需联动修改约 13 个路由处理器 + 6 个前端页面，
属“改动范围太大”；且前端用 `as` 断言消费，tsc 不会报错但运行时会取不到字段而白屏 / 崩溃。
按任务要求“如果改动范围太大或会破坏测试，跳过此项”，本项跳过，保持现状。
（注：现有 vitest 不含路由测试，故统一格式不会破坏单测；跳过是为避免破坏前端运行时行为。）

### 2026-06-27 — 验证

- `pnpm install --no-frozen-lockfile`：成功，lockfile 已同步，卸载 57 包。
- `npx vitest run`：通过。4 个测试文件，68 个测试全部通过
  （rag/index.test.ts 15、safety-agent 19、db 17、utils 17）。
  - db.test.ts 17 项全过 → 移除 `addKnowledge` 未影响 store 测试（测试本就只用 addKnowledgeBatch）。
  - utils.test.ts 17 项全过 → 移除 `cn` 未影响测试（测试本就不测 cn）。
- `npx tsc --noEmit --project tsconfig.typecheck.json`：通过。退出码 0，无类型错误。

结论：P2-1、P2-2 清理均未破坏现有测试与类型检查；P2-3 评估后按规跳过。

## 涉及文件清单

1. `apps/web/package.json` — 移除 5 个未使用依赖
   （@ai-sdk/openai、ai、zod、clsx、tailwind-merge）
2. `apps/web/pnpm-lock.yaml` — `pnpm install --no-frozen-lockfile` 同步（卸载 57 包）
3. `apps/web/src/lib/utils.ts` — 移除未使用的 `cn` 函数及其 import
4. `apps/web/src/lib/store/db.ts` — 移除未使用的 `addKnowledge` 单条方法

## 未改动 / 待办

- P2-3（API 响应格式统一）已跳过，原因见上。如后续需统一，建议作为一个独立任务
  同步改造路由 + 前端消费方，并补充路由级集成测试以防回归。
