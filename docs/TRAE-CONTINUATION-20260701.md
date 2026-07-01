# Trae 续作任务：真实 Agent 验证与端侧数据施工

> 开始前必须执行 `git status --short`、`git log -5 --oneline`，以最新 `main`/`HEAD` 为准。不得回滚或覆盖 Codex 改动。CLI 优先，CLI 无法得到 ArkTS 诊断或 UI 树证据时才使用 DevEco MCP。不得使用 loop-engineering，不得提交 Git。

## 最高优先级：纠正模型与完成真实调用验收

1. 读取最新 `apps/web/src/lib/agents/model.ts` 和 `DEVLOG.md`。官方资料已确认 Doubao Seed 2.1 Pro 存在，Chat API 支持 `thinking.type=disabled`；模型 ID 固定为用户控制台提供的 `doubao-seed-2-1-pro-260628`。禁止恢复 1.6 默认值。
2. Vercel Production/Preview/Development 的 `MODEL_NAME` 均更新为上述精确值；不要在命令、截图、日志、DEVLOG 或报告中回显 Vercel Token、Ark Key 或环境变量值。只记录变量名和“已配置”。
3. 部署最新 `main` 后，依次验证：
   - `/api/health` 返回 `200`、`ready`，且 `model.name` 精确为上述模型 ID。
   - `/api/chat` 收到真实 `thinking`、`delta`、`done`；必须记录 HTTP 状态、首事件时间、首正文时间、总耗时。
   - `/api/plan` 返回可解析计划，任务非空。
   - `/api/quiz` 返回可解析题目、答案和解析，题目数量与请求一致。
4. 失败时记录精确 HTTP 状态、错误码、Vercel request ID 和不含秘密的错误消息。不得用静态回复、本地模板或测试替身伪造通过。
5. 不得修改 `model.ts`、`orchestrator.ts`、Safety、API 契约；发现问题只报告给 Codex。

## 数据与自动化施工

真实 Agent 验收完成后，完整执行 `docs/TRAE-APP-IMPLEMENTATION-WORK-PACKAGE-2.md`，顺序为 B -> C -> A -> E -> D：

1. 先生成并校验 `topic-relations.json`，为 Codex 的新学习图谱提供真实 DAG。
2. 再完成基于 UI 树 bounds 的无破坏 CLI 冒烟脚本。
3. 把每个真实 topic 的精选选择题补到至少 5 道，并保持 Web 单一数据源到 HAP JSON 的自动生成。
4. 完成知识切片、题库、外部资源质量审计。
5. 最后执行适配与可访问性只读审计。

## 前端资源收口

1. `assets/frontend-resources` 中 Web 专用 Zustand、Comlink、BlurHash、SpinKit、canvas-confetti 不得接入 HarmonyOS App。
2. 不得通过 ArkWeb 承载原生页面或庆祝动画。
3. 只保留 OpenHarmony-TPC `@ohos/lottie` 方向的资料与 Lottie JSON；写 `docs/FRONTEND-RESOURCE-ADOPTION.md`，列出来源、许可证、API 12 兼容性、包大小、目标页面、采用或拒绝理由。
4. 不安装依赖、不修改 UI 页面；Codex 在 OHPM 源恢复后负责集成与真机性能判断。

## 受保护区域

不得修改：

- `apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets`
- `apps/harmonyos/entry/src/main/ets/common/LearningContentRepository.ets`
- `apps/harmonyos/entry/src/main/ets/model/DataModels.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Index.ets`
- 所有 HarmonyOS UI 页面和设计令牌
- `apps/web/src/lib/agents/`
- `apps/web/src/app/api/`
- 数据库迁移、Safety、模型调用、顶层导航

## 验收与汇报

- Web：`pnpm lint`、`pnpm typecheck`、`pnpm test`。
- HarmonyOS：CLI 增量构建，不执行 clean。
- `git diff --check` 与敏感信息扫描。
- 按批次把文件、统计、命令、退出码、失败项和证据路径追加到 `DEVLOG.md`。
- 不提交 Git，等待 Codex 复核。
