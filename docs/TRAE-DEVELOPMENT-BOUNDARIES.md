# Codex 给 Trae 的开发边界与验收线

> 本文档由 Codex 于 2026-06-26 编写，约束 Trae 后续执行范围。Trae 负责大量执行工作，Codex 负责架构、核心底层、关键验收与最终方向。

---

## 一、对当前交接状态的判定

Trae 已完成接力阅读、提交遗留导航闭环和汇报文档，当前 Git 工作区干净。

但需要纠正一个表述边界：

- `hvigorw.bat` 构建成功，只能证明 HarmonyOS 工程的命令行构建链路可用。
- Trae 当前会话未挂载 DevEco MCP，因此不能声称已具备完整 DevEco MCP 能力。
- DevEco MCP 的 `check_ets_files`、`harmonyos_knowledge_search`、`start_app`、`get_app_ui_tree`、`verify_ui` 等能力，必须在 Trae 会话内实际暴露并调用成功后，才能写入报告为“可用”。

Codex 在当前会话独立验收结果：

| 项目 | 结果 |
|------|------|
| DevEco MCP `project_sync` | 通过 |
| DevEco MCP `check_ets_files` | 10 个 `.ets` 文件无 Error |
| DevEco MCP `build_project` | `entry@default` debug 构建成功 |
| DevEco MCP `harmonyos_knowledge_search` | 本次云端请求失败，不能作为 Trae 可用性的证明 |

---

## 二、Trae 的硬性执行边界

Trae 可以执行：

1. 页面样式统一、布局微调、资源整理。
2. ArkTS 页面补齐、重复性类型修复、返回按钮、状态提示、空态和错误态。
3. Web 页面接入已有 API、错误提示、加载态、表单交互。
4. 文档同步、README 校对、DEVLOG 追加。
5. 按 Codex 指定范围执行构建回归和问题复核。

Trae 不得执行：

1. 不修改 `apps/web/src/lib/agents/model.ts`。
2. 不修改 `apps/web/src/lib/agents/orchestrator.ts`。
3. 不新增或改动模型相关 API 合同。
4. 不接触、读取、打印、保存、提交 `MODEL_API_KEY`。
5. 不擅自做 router 到 Navigation 的迁移。
6. 不擅自引入新依赖、换框架、改构建系统。
7. 不擅自改签名配置、证书、真机安装凭据。
8. 不执行批量删除、递归删除、清理目录、破坏性 Git 操作。
9. 不根据记忆或经验猜测 HarmonyOS API、字段名、路径、JSON 结构。

凡是涉及架构、核心数据结构、模型调用、API 合同、构建系统、签名、Navigation 迁移、服务卡片、通知、元服务的任务，Trae 只能先做只读调研和方案草案，等 Codex 明确批准后再动代码。

---

## 三、工具可用性要求

Trae 在继续 HarmonyOS 任务前，必须先完成以下验证之一。

优先验收线：Trae 自身 DevEco MCP 可用

1. 调用 HarmonyOS 官方知识检索，返回官方文档内容。
2. 调用 `check_ets_files` 检查本轮将修改的 `.ets` 文件。
3. 调用 `build_project` 完成 `entry@default` debug 构建。
4. 将工具名、输入范围、结果摘要写入 DEVLOG。

降级验收线：Trae DevEco MCP 暂不可用

1. 明确在 DEVLOG 写明“Trae 当前 DevEco MCP 未挂载”。
2. 对 ArkTS 改动使用 `apps/harmonyos/hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon` 验证。
3. 不得声称已完成 DevEco MCP 单文件检查、UI 树、模拟器自动化或开发平台完整连接。
4. 如任务依赖官方 API 用法，必须暂停并请求 Codex 用 DevEco MCP 查询，或由用户让 Trae 先配置 MCP。

---

## 四、验收证据格式

Trae 每轮交付必须在 DEVLOG 中写明：

1. 修改文件清单。
2. 每个核心行为对应的源码位置。
3. Web 验收：
   - `pnpm lint`
   - `pnpm typecheck`
   - `pnpm build`
   - 如改 API，还需给出运行时请求结果。
4. ArkTS 验收：
   - MCP 可用时：`check_ets_files` + `build_project`
   - MCP 不可用时：明确说明原因 + `hvigorw.bat assembleHap` 构建结果
5. UI 行为验收：
   - 若声称“可点击、可跳转、可返回、可展示”，必须提供模拟器/真机运行、UI 树、截图或人工可复现实测步骤。
   - 未做运行态验证时，只能写“编译层面通过”，不能写“交互闭环已完整验证”。
6. Git 状态：
   - 提交前后都要记录 `git status` 结果。

---

## 五、当前下一阶段优先级

Codex 当前排序如下：

1. **端侧运行态验证**：先证明当前 Dashboard、Chat、Course、Plan、Knowledge、Profile 在模拟器或真机里可启动、可跳转、可返回。
2. **Web 课程页/画像页接入已有 API**：这是低风险联调任务，可交给 Trae。
3. **Knowledge.ets 课程过滤 UI**：先做只读方案，等 Codex 看过再实现。
4. **Navigation 迁移调研**：只做官方资料检索和迁移影响清单，不直接改代码。
5. **鸿蒙赛道亮点选择**：暂定优先调研服务卡片，其次通知，元服务最后评估。
6. **知识库上传接口**：由 Codex 处理后端数据结构和 API 合同，Trae 暂不动。

---

## 六、给 Trae 的首批任务

在没有配置 DevEco MCP 前，Trae 只执行以下只读或低风险任务：

1. 只读梳理当前 HarmonyOS 端页面跳转链路：
   - `Index.ets`
   - `Chat.ets`
   - `Course.ets`
   - `Plan.ets`
   - `Knowledge.ets`
   - `Profile.ets`
2. 输出每个按钮、目标页面、返回方式、依赖 API、未验证点。
3. 不改代码。
4. 配置 Trae 自身 DevEco MCP，配置完成后必须先用官方知识检索和 `check_ets_files` 验证。
5. DevEco MCP 验证失败时，不继续做 HarmonyOS API 迁移类任务。

Trae 配好 MCP 后，再执行低风险开发任务：

1. Web `courses/page.tsx` 接入 `GET /api/courses`。
2. Web `profile/page.tsx` 接入 `GET /api/profile`。
3. 为两个页面补加载态、错误态、空态。
4. 跑 Web 三项检查并追加 DEVLOG。

---

## 七、提交规则

Trae 可以在 Codex 指定的任务范围内提交，但提交前必须满足：

1. 工作范围与 Codex 指令一致。
2. DEVLOG 已追加。
3. 验收命令已完成。
4. 未触碰禁止文件。
5. `git diff --check` 通过。
6. `git status` 中只包含本轮任务文件。

提交信息使用：

```text
feat: <短任务描述>
fix: <短任务描述>
docs: <短任务描述>
chore: <短任务描述>
```

---

## 八、给 Trae 的一句话原则

能从源码、官方工具、构建结果、运行态证据中确认的才写成结论；不能确认的写成待验证，不猜。

---

## 十、2026-06-30 核心开发与执行分工

为控制 Token 消耗并保持核心质量，后续不再要求 Codex 对每个小改动执行完整视觉回归。

### Codex 负责

1. API 数据契约、服务端状态边界、评分与安全逻辑。
2. Agent 编排、模型调用、RAG 检索策略和用户画像反馈闭环。
3. HarmonyOS 主导航、跨页面状态、核心学习流程与系统级能力。
4. 重大交互方向、设计系统和每个大阶段的一次视觉总验收。
5. Trae 交付的关键代码审查、风险修复与最终 Git 提交。

### Trae 负责

1. 在既有 TypeScript interface 下扩充知识切片、题目和资源条目。
2. 逐条核对外部链接、题目答案、知识点名称和数据唯一性。
3. 补充数据完整性测试、API 文档、开发日志和文件清单。
4. 执行 lint、typecheck、test、ArkTS 静态检查、构建及截图采集。
5. 按 Codex 给定页面与字段做机械性样式统一，不改变信息架构。

### Trae 禁止范围

1. 不修改 `model.ts`、`orchestrator.ts`、评分算法和 API 返回结构。
2. 不修改 `DataModels.ets`、主路由、AppStorage 键名和导航架构。
3. 不新增依赖，不迁移存储，不自行增加页面入口。
4. 不使用持续循环技能处理明确的单批任务；完成一次修改、一次检查、一次汇报即可。
5. 不为满足数量而复制题目、循环复用题干或使用无法核对的答案。

### 下一批低风险任务

题库扩量任务已于提交 `32cdec0` 完成。下一批执行外部学习资源审计：

1. 逐条检查 `external-resources.ts` 的 36 个 URL，确认可访问、域名属于官方机构或出版方、标题与落地页一致。
2. 具体教材或课程不得只链接平台首页；能找到官方详情页时改为详情页。
3. 新建 `docs/RESOURCE-AUDIT-20260630.md`，记录资源 ID、最终 URL、HTTP 结果、官方归属和处理结论。
4. 只允许修改 `external-resources.ts`、`data-integrity.test.ts`、新审计文档和追加 `DEVLOG.md`。
5. 增加资源 ID、标题、URL 全局唯一测试；不得修改类型、Agent、API、Store、ArkTS、依赖和导航。
6. 运行 `pnpm lint`、`pnpm typecheck`、`pnpm test`、`git diff --check`；不提交 Git，交由 Codex 复核。

## 九、2026-06-28 Codex 复核后的当前边界

此前“7/7 验收完成、仅差提交材料”的结论作废。当前工程具备可运行骨架和基本后端闭环，但端侧产品结构、视觉质量、主要学习流程、系统级鸿蒙能力和正式提交材料均未完成。

已核实的工具状态：

1. DevEco MCP 已完成工程同步、单文件 ArkTS 检查、HAP 构建、模拟器安装启动、UI 树和截图。
2. DevEco MCP 云端知识检索本次连接失败，官方 API 结论须改由华为开发者官网核对。
3. 本机 DevEco Code CLI 为 `deveco` 0.1.0；`deveco run --dir <workspace> <message>` 可执行窄范围只读审查。
4. DevEco Code 的技能发现结果混有无关全局技能，因此不能让它自主选择工程方向或直接大范围改代码。

Trae 下一批只执行以下任务，不修改业务代码：

1. 从当前六个 ArkTS 页面和已有 API 源码提取“页面目标、数据来源、主要动作、加载/空/错状态、缺失闭环”，写入 `docs/HARMONY-UX-INVENTORY.md`。
2. 对照华为官方设计入口、设计资源和最佳实践，只收集与手机端学习应用直接相关的组件与规范链接；不得使用社区文章替代官方依据。
3. 标出当前首页大面积空白、课程不可进入详情、计划不可打卡、知识库课程固定、非交互卡片存在按压反馈、无障碍文本缺失等已由源码或 UI 树确认的问题。
4. 记录实际使用的 DevEco Code CLI 命令、MCP 工具名和输出摘要；某项工具未成功就写“未验证”。
5. 不创建视觉稿，不调整颜色/圆角/阴影，不迁移导航，不新增依赖，不修改 API。

交付标准：仅允许修改 `docs/HARMONY-UX-INVENTORY.md` 和追加 `DEVLOG.md`，执行 `git diff --check`，不提交，由 Codex 复核后再决定端侧重构任务。

---

## 十一、2026-06-30 得分优先边界

权威实施清单见 `docs/COMPETITION-SCORE-FIRST-PLAN.md`。后续任务必须能直接支撑基础创新、完整度、前景、规范性或实际应用价值加分，不能仅以代码量和数据数量作为完成标准。

当前停止继续扩充题库、知识切片和外链。Trae 下一批只执行提交资产清点：

1. 新建 `docs/SUBMISSION-SOURCE-MANIFEST.md`，逐项列出源码 ZIP 应包含的目录、应排除的文件类型、构建入口和运行入口。
2. 从 `package.json`、`oh-package.json5`、源码资源和现有审计文件提取第三方依赖与素材来源；找不到许可证时标为“待人工确认”，不得猜测。
3. 检查仓库是否存在官方作品说明模板，仅报告精确路径；不存在就写“仓库未找到”。
4. 只允许新增该清单并追加 `DEVLOG.md`，不修改业务代码、依赖、构建配置和现有竞赛文档。
5. 运行 `git diff --check`，不提交 Git，交由 Codex 复核。

服务端容器、持久化、模型密钥、公网配置、HarmonyOS `BASE_URL` 和系统级能力仍由 Codex 处理。
