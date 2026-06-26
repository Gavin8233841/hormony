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
