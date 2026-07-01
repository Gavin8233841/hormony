# Trae 工作边界与操作规范（2026-07-01 Codex 审查后修订）

## 背景

本文档基于 Codex 2026-07-01 审查反馈制定。此前 Trae 在 Agent 模块工作中存在以下错误：

1. **模型名误判**：将用户控制台提供的 `doubao-seed-2-1-pro-260628` 判为"无效"并改为 `doubao-seed-1-6-250615`。认证错误只能证明端点可达，不能证明模型不存在。Codex 已恢复正确模型名。
2. **假降级移除后引入不完善超时**：`withAgentTimeout` 未覆盖 Profile/Safety，未清理定时器，未取消 HTTP 请求。Codex 已用 `AbortSignal` + `setTimeout` 在 `model.ts` 中统一实现。
3. **终端回显敏感变量**：在命令中回显了 Vercel Token，违反安全边界。
4. **未基于真实证据推进**：在未验证模型名是否有效的情况下就修改代码默认值并推送部署。

## 禁止修改的区域

以下区域 Trae 不得修改，发现问题只报告给 Codex：

| 区域 | 路径 | 说明 |
|------|------|------|
| 模型调用 | `apps/web/src/lib/agents/model.ts` | 模型名、超时、客户端配置 |
| 编排器 | `apps/web/src/lib/agents/orchestrator.ts` | Agent 编排逻辑 |
| Safety Agent | `apps/web/src/lib/agents/safety-agent.ts` | 安全审核逻辑 |
| API 路由 | `apps/web/src/app/api/` | 所有 API 端点 |
| Agent 目录 | `apps/web/src/lib/agents/` | 整个 Agent 目录 |
| 数据模型 | `apps/harmonyos/.../model/DataModels.ets` | 数据结构定义 |
| 本地仓库 | `apps/harmonyos/.../common/LocalLearningRepository.ets` | 本地学习数据仓库 |
| 内容仓库 | `apps/harmonyos/.../common/LearningContentRepository.ets` | 学习内容仓库 |
| 主导航 | `apps/harmonyos/.../pages/Index.ets` | 顶层导航 |
| HarmonyOS UI | `apps/harmonyos/.../pages/*.ets` | 所有 UI 页面和设计令牌 |
| 数据库迁移 | 任何数据库迁移文件 | 迁移脚本 |

## 安全操作规范

1. **Token 处理**：Vercel Token、Ark API Key 等敏感凭证仅通过环境变量传递，绝对禁止：
   - 在终端输出中回显
   - 写入任何文件（包括日志、DEVLOG、配置文件）
   - 出现在 Git 提交信息中
   - 在任何报告中引用具体值
2. **日志记录**：只记录变量名和"已配置"状态，不记录值。
3. **命令构造**：设置环境变量时不使用 `Write-Output` / `echo` 等输出命令。

## 工作流程规范

1. **CLI 优先**：优先使用 DevEco CLI、hvigor、hdc、pnpm、Git。仅在需要 ArkTS 诊断或 UI 树证据时使用 DevEco MCP。
2. **不提交 Git**：所有改动由 Codex 复核后提交。
3. **不使用 loop-engineering**：按任务包顺序推进，不使用自驱循环。
4. **最新 HEAD 为准**：每次开始前执行 `git status --short` 和 `git log -5 --oneline`，以最新 `main`/`HEAD` 为准。
5. **不回滚 Codex 改动**：不得回滚或覆盖 Codex 的任何提交。
6. **DEVLOG 同步**：每批次工作完成后追加 DEVLOG.md，记录文件、统计、命令、退出码、失败项和证据路径。

## 验证规范

1. **真实调用验证**：不得用静态回复、本地模板或测试替身伪造通过。
2. **失败处理**：失败时记录精确 HTTP 状态、错误码、Vercel request ID 和不含秘密的错误消息。
3. **验证命令**：
   - Web：`pnpm lint`、`pnpm typecheck`、`pnpm test`
   - HarmonyOS：CLI 增量构建，不执行 clean
   - 敏感信息扫描：`git diff --check`

## 当前任务包

按 `docs/TRAE-CONTINUATION-20260701.md` 执行：

1. **P1**：修正 Vercel MODEL_NAME → 部署 → 验证 Chat/Plan/Quiz/Health
2. **P2**：数据与自动化施工（B→C→A→E→D）
   - B: `topic-relations.json` 生成与校验
   - C: CLI 冒烟脚本
   - A: 题库补充（每 topic ≥ 5 题）
   - E: 知识切片、题库、外部资源审计
   - D: 适配与可访问性只读审计
3. **P3**：前端资源收口（`docs/FRONTEND-RESOURCE-ADOPTION.md`）
