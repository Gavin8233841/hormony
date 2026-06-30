# Trae 下一阶段持续任务包

将以下内容原样交给 Trae Work 执行。该任务允许持续推进，但每个批次必须独立可验证，不得使用无限循环技能。

---

你是鸿学伴 HarmonyOS 项目的执行 Agent。先完整阅读：

1. `docs/APP-LEARNING-LOOP-ROADMAP.md`
2. `docs/TRAE-DEVELOPMENT-BOUNDARIES.md`
3. `docs/CODEX-SYNC-20260701.md` 顶部纠正说明
4. `DEVLOG.md` 最后两条记录

目标：把现有表层 App 推进为真实可学习的 HarmonyOS Demo。竞赛交付重点是 App，不建设 Web 产品页面。凡 CLI 能完成的工作优先使用 DevEco Code CLI / DevEco CLI / hvigor / hdc / pnpm / Git；只有 UI 树、模拟器交互或 IDE 诊断确实需要时才使用 DevEco MCP。

## 允许持续执行的工作流

### 批次 A：现状清单与竞品证据

- 遍历所有 `.ets` 页面和 ArkData/API 调用，输出“入口 -> 页面 -> 当前数据源 -> 真实/写死 -> 可交互/不可交互 -> 缺失状态”的矩阵。
- 用官方产品帮助页或应用商店开发者说明研究 Khan Academy、Quizlet、Anki、Duolingo，以及 2 个国内题库/MOOC 产品；只提炼学习流程，不复制视觉或文案。
- 产出 `docs/APP-FEATURE-GAP-MATRIX.md`，按 P0/P1/P2 排序，不修改核心代码。

### 批次 B：端侧只读学习资产

- 从现有 TypeScript 数据文件精确转换 147 条知识切片、60 道已审计选择题和 36 条外部资源为端侧 JSON 资产。
- ID、courseId、topic、题干、选项、答案、解析和 URL 必须逐项保持一致，不得改写或猜测。
- 编写脚本化完整性检查：全局 ID 唯一、每题四选项、答案存在、课程引用有效、资源 URL/标题非空、JSON 可解析。
- 不修改 `DataModels.ets`、`LocalLearningRepository.ets`、模型 Agent、API 契约、主导航。

### 批次 C：页面与交互设计准备

- 基于 `APP-LEARNING-LOOP-ROADMAP.md` 为 CourseDetail、Lesson、Practice、QuizResult、Review、Resources、ActivityRecords、MistakeBook、Achievements 输出页面规格：信息层级、唯一主操作、状态（加载/空/错误/离线/完成）、导航来源和返回目标。
- 复用现有设计令牌和鸿蒙系统 Symbol，禁止添加第三方 UI 库、硬编码新主题或重复入口。
- 先只创建规格与静态预览建议，不修改 Index、路由、仓库 schema。

### 批次 D：可安全机械实现的页面壳

- 只有在 A-C 全部通过且 Codex 已提供领域接口后，才按接口实现重复页面 UI、状态绑定、空态/错误态和端侧资产读取。
- 每完成一个页面，执行 ArkTS 静态检查、增量 HAP 构建、模拟器入口/返回/滚动/点击回归，并保存截图与 UI 树。
- 不得自行设计进度算法、成就规则、间隔复习算法或数据库迁移。

## 每批强制汇报

- 精确修改文件清单。
- 使用的 CLI/MCP、命令、退出码和关键结果。
- 哪些数据来自现有源码，哪些来自官方资料。
- 未完成项和阻塞，不得把静态壳描述为功能完成。
- 追加 `DEVLOG.md`，不得提交 Git，由 Codex 审阅提交。

立即从批次 A 和批次 B 并行开始；完成并验证后继续批次 C。批次 D 等待 Codex 明确提供领域接口，不要越界。
