# Trae 下一批执行任务（2026-07-01）

以当前 `main` 最新 HEAD 为准。先运行 `git status --short` 和 `git log -5 --oneline`，不得覆盖 Codex 未提交改动，不提交 Git。

## 禁止修改

- `apps/web/src/lib/agents/`、`apps/web/src/app/api/`
- `DataModels.ets`、`LearningContentRepository.ets`、`LocalLearningRepository.ets`
- `Index.ets`、`LearningMap.ets`、所有设计令牌与页面视觉结构
- Vercel 环境变量、模型名、API Key、安全策略

## A. 修正并执行 CLI 冒烟脚本

修正 `scripts/harmonyos-app-smoke.ps1`，所有标识符必须从源码核验：

- Bundle Name 使用 `AppScope/app.json5` 中的精确值 `com.c4ai.hormony`。
- HDC 使用已验证绝对路径 `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`，不得假设在 PATH。
- Hvigor 使用项目 `apps/harmonyos/hvigorw.bat`。
- HAP 从 `entry/build/default/outputs/default/` 读取当前实际产物，不要求不存在的 signed 文件。
- UI 点击必须由 UI 树文本与 bounds 计算，不写死设备坐标。
- 流程至少覆盖：首页、课程、课程详情、本地练习选择一题、提交、逐题复盘、学伴、我的、学习星图。
- 每一步失败立即给出精确页面文本和命令输出，不把“已安装或更新”无条件记为 PASS。

在当前 Pura 90 Pro Max 模拟器执行一次，证据写入新的 `screenshots/trae-smoke-*` 目录。

## B. 本地题库 Topic 覆盖施工

只修改题库数据、数据校验和 DEVLOG：

- 对照 `topic-relations.json` 的 33 个 `(courseId, topic)`，统计 HarmonyOS rawfile 与 Web 题库覆盖率。
- 每个 Topic 至少提供 3 道四选一题；选项必须依次为 `A.`、`B.`、`C.`、`D.`，答案只能为 A-D，解析至少两句。
- ID、题干全局唯一；课程与 Topic 必须逐字匹配现有关系资产，禁止近似匹配或自行改名。
- HarmonyOS `quizzes.json` 与 Web `quizzes.ts` 保持同源一致，不修改 API、Agent、Store 或页面。
- 新增/扩展自动化校验：33 个 Topic 无缺失、每 Topic 数量达标、答案对应选项、格式完整。

## C. 只读适配审计

- 使用 UI 树与截图检查手机竖屏的安全区、文字截断、点击区域、滚动可达性。
- 页面范围：Practice、Quiz 结果复盘、LearningMap 三门课程、ActivityRecords、MistakeBook、Achievements。
- 只输出 `docs/APP-UI-ADAPTATION-AUDIT-20260701.md`；不改页面代码。

## 验收

- `python scripts/validate-topic-relations.py`
- Web：`pnpm lint`、`pnpm typecheck`、`pnpm test`
- HarmonyOS：CLI 增量 `assembleHap`，不 clean
- 冒烟脚本真实退出码为 0
- `git diff --check`
- DEVLOG 记录精确文件、统计、退出码和证据路径

完成后停下汇报，不提交 Git。
