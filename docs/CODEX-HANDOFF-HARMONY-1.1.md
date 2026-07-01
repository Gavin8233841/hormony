# Codex 接力：鸿蒙1.1

更新时间：2026-07-01

## 首要读取

1. 根目录 `AGENTS.md`
2. `docs/FRONTEND-RESOURCE-ADOPTION.md`
3. `docs/MODEL-ROLLOUT-STRATEGY.md`
4. `docs/TRAE-NEXT-WORK-20260701.md`
5. `DEVLOG.md` 末尾 250 行

## 当前 Git 状态

- 主分支：`main`
- 当前最新提交：`c674783 feat: 课程资料支持端侧离线检索`
- 远端：`origin/main` 已同步
- Trae 正在修改 `apps/web/src/lib/data/quizzes.ts`，并维护 `.trae/progress.json`；不得覆盖或纳入 Codex 提交，等待其完整汇报后复核。
- 未跟踪 `scripts/harmonyos-app-smoke.ps1` 是 Trae 初稿，已发现错误 Bundle Name 与 PATH 假设，必须按任务文档修正后才能提交。
- `assets/`、展示站、工具调查等未跟踪目录不是当前 HAP 主线，不得整包提交。

## 本轮已完成并推送

- 真实答题选项、环形成绩、逐题折叠复盘、AI 选项 A-D 契约。
- 33 节点课程先修 DAG 与真实掌握度学习星图；模拟器截图已消除标签重叠。
- 首页只显示真实当天任务，课程进度由本地学习事件推导。
- Chat 连接中/可用/不可用状态收紧，失败不生成助手回复。
- 错题复盘可预填问题进入真实学伴，用户确认后才发送。
- 本地练习按未解决错题、未做题、已做题排序。
- 服务卡片读取 ArkData 当天计划，不显示未来任务。
- 147 条端侧知识切片用于明确标注的离线关键词检索。
- 最新 HarmonyOS 各轮增量构建全部成功；视觉证据：
  `screenshots/codex-visual-pass-20260701/learning-map-dag-final.png`。

## 模型边界

- 当前已验真模型：`doubao-seed-2-1-pro-260628`。
- 官方低成本备选：`doubao-seed-2-0-lite-260215`。
- 模型仅通过 Vercel `MODEL_NAME` 切换；每次切换必须验证 Health、Chat SSE、Plan、Quiz 与端侧流程。
- 不在源码、日志、HAP 或命令输出中写入 API Key / Vercel Token。

## 外部资源状态

- OHPM 查询 `@luvi/lv-markdown-in` 连续返回 502；没有修改依赖，没有猜写 API。
- 依赖源恢复后优先单独验证 Markdown；Lottie 必须真机验证后再进入主线。
- 不引入 axios、工具库、弹窗库、图表库等重复依赖；ArkUI 原生能力优先。

## 下一步顺序

1. 等 Trae 完成题库覆盖与 CLI 冒烟，逐文件复核并运行 Web 全套检查、关系校验、HAP 构建。
2. 确保 Web 题库与 HarmonyOS `rawfile/learning/quizzes.json` 同源，每个 33 Topic 至少 3 道题。
3. 修正并执行真实 CLI 冒烟：Practice 选择/提交/复盘、LearningMap 三课程、Chat 状态、Profile 子页面。
4. 统一做一次大环节模拟器视觉验收，重点检查 Practice/Quiz 结果、错题追问、知识离线结果、首页无今日任务。
5. OHPM 恢复后验证 Markdown 组件；失败则保持纯 ArkUI，不手写 Markdown 解析器。
6. 之后推进真实复习到期队列、连续学习统计和卡片更新时机；不要先做 OCR/TTS/分布式多设备。

## 工作方式

- Ponytail full：读取完整流程后优先现有代码、ArkUI 原生能力和最小可靠改动。
- CLI 优先；只有 ArkTS 诊断、安装运行、UI 树和截图需要 DevEco MCP。
- 关键架构、UI 底层、Agent、安全和仓库由 Codex 修改；数据扩充、脚本、只读审计交给 Trae。
- 每批次追加 DEVLOG、精确提交并推送；不提交 `.trae/progress.json` 或无关资产。
