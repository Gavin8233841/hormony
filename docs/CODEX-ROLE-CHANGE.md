# Codex 角色改变说明文档

> 本文档由 WorkBuddy (GLM-5.2) 于 2026-06-26 编写，用于向 Codex (GPT-5) 同步协作角色变化。
> Codex 请通读本文件，了解新的协作分工。

---

## 一、角色变化概要

由于额度问题，WorkBuddy（GLM-5.2）的执行角色暂时由 **Trae AI Agent** 接手接力。

### 角色调整前后对比

| 角色 | 调整前 | 调整后 |
|------|--------|--------|
| 架构师/指挥 | Codex (GPT-5) | Codex (GPT-5)（不变） |
| 执行者 | WorkBuddy (GLM-5.2) | **Trae（接替 WorkBuddy）** |
| 退出执行 | — | WorkBuddy (GLM-5.2)（暂时退出） |

### 不变的部分

- **Codex 的角色不变**：继续担任架构师/指挥，负责核心底层框架、相关约束、架构决策、代码审查、给出开发指引和分析。
- **项目目标不变**：2026 C4-AI 鸿蒙高校创新赛 Agent 创新方向，产品名「鸿学伴」。
- **协作约定不变**：DEVLOG 追加写入、文件安全规则、标识符规则、MCP 配置、Git 规范。

### 变化的部分

- **执行者由 WorkBuddy 换为 Trae**：后续 Codex 的开发指引和任务分配，由 Trae 负责执行。
- **Trae 将加入项目目录工作**：与 Codex 在 `C:\Users\guo82\Desktop\Hormony` 共同工作。
- **WorkBuddy 暂时退出**：不再执行任务，产物和进展已交接给 Trae（详见 `docs/HANDOFF-TO-TRAE.md`）。

---

## 二、Codex 与 Trae 的新协作方式

### 分工原则

| 协作方 | 职责范围 |
|--------|----------|
| Codex | 核心底层框架、模型相关代码（model.ts/orchestrator.ts/模型 API）、架构决策（如 router→Navigation 迁移）、知识库数据结构、端侧关键闭环与竞赛主线约束、代码审查 |
| Trae | 听取 Codex 指挥执行任务，优先解决简单和不易出错的任务：页面补齐、样式统一、资源整理、文档同步、重复性 ArkTS 类型修复、构建回归、配置相关问题 |

### 协作流程

```
Codex 给出开发指引和约束（通过 DEVLOG 或直接对话）
  ↓
Trae 执行任务
  ↓
Trae 每次改动后追加 DEVLOG 记录（含模型名 + 时间戳）
  ↓
Trae 每次 ArkTS 改动后执行 DevEco MCP check_ets_files
  ↓
Trae 完成一轮改动后执行 build_project
  ↓
Codex 审查 Trae 的工作成果
  ↓
（如需）Codex 复核通过后提交，保持工作区干净
```

### Trae 的约束（Codex 需知悉，便于指挥）

1. **不修改** `apps/web/src/lib/agents/model.ts`、`orchestrator.ts` 和模型相关 API（由 Codex 负责）
2. **不接触 MODEL_API_KEY**，不写入任何文件或日志
3. **不擅自做架构级重构**（如 router → Navigation 迁移由 Codex 决策）
4. **遵守文件安全规则**：禁止批量/递归/通配符删除，单文件删除需确认路径
5. **遵守标识符规则**：严禁猜测标识符，必须从文件读取精确表述

---

## 三、当前项目状态（供 Codex 参考）

### Git 状态

- 最新提交：`3f96850 feat: 封装模型服务端调用`
- 工作区有 **9 个未提交改动**（WorkBuddy 最后两轮产物）：
  - 端侧导航闭环（6 个 ArkTS 页面加路由跳转 + 返回按钮）
  - HttpClient 废弃 API 修复（escape → TextDecoder）
  - Web 知识库页错误提示
  - Knowledge.ets score 显示
  - DEVLOG 记录

> **待 Codex 决策**：这批改动是否提交，还是需要复核后再提交。

### 已完成里程碑

1. ✅ 基础设施全部就绪（DevEco Studio / SDK / MCP / Hvigor 工程 / Web 工具链）
2. ✅ Web 后端 8 API + 7 Agent + 模型服务端封装 + 演示模式兜底
3. ✅ HarmonyOS 编译闭环（check_ets_files 0 Error + build_project BUILD SUCCESSFUL + HAP 产物）
4. ✅ 端侧导航闭环（Dashboard → 6 页面跳转 + 返回按钮）
5. ✅ 知识库 API 闭环（Web + ArkTS 同一后端接口）
6. ✅ 产品命名（鸿学伴）

### 下一步待办（Codex 决策优先级）

1. 提交或复核当前未提交改动
2. router → Navigation 组件迁移（架构级，需 Codex 指引）
3. 鸿蒙赛道亮点择一（服务卡片 / 通知 / 元服务）
4. 知识库上传接口 `POST /api/knowledge/upload`
5. Web 课程页/画像页接入真实 API
6. Knowledge.ets 请求体传 courseId（需课程选择器 UI）
7. 签名配置（HAP 当前 unsigned）
8. README 产品名同步为「鸿学伴」
9. 报名材料准备（作品说明文档、技术方案、创意描述、PPT、演示视频）

---

## 四、交接文档索引

| 文档 | 说明 |
|------|------|
| `docs/HANDOFF-TO-TRAE.md` | 给 Trae 的详尽接力指引（含项目全貌/MCP连接/角色定位/操作经验） |
| `docs/CODEX-HANDOFF.md` | 早期 Codex 接手指引（WorkBuddy 编写，信息可能部分过时） |
| `docs/CODEX-ROLE-CHANGE.md` | 本文件 |
| `DEVLOG.md` | 全部开发历史记录 |
| `README.md` | 项目全貌 |

---

## 五、WorkBuddy 的说明

WorkBuddy 在本次协作中的角色是「听取 Codex 的指挥精准执行大型大量任务，首要解决简单和不易出错的任务和配置相关问题」。目前已完成所有指派的基础设施和执行类任务，将执行角色交接给 Trae。

WorkBuddy 的全部工作记录均可在 `DEVLOG.md` 中查到（搜索 "WorkBuddy" 或 "GLM-5.2"）。关键产物包括：
- 环境核查与 MCP 配置
- Hvigor 工程文件补齐与 hvigorw.bat wrapper 修复
- app_icon 资源补齐与 ArkTS 严格检查全部修复
- HAP 构建闭环打通
- 端侧导航闭环
- 遗留技术债修复
- 产品命名
- 全部交接文档

Trae 接手后，Codex 可继续按原有方式通过 DEVLOG 和对话指挥开发，执行端从 WorkBuddy 切换为 Trae 即可。

---

_本文档由 WorkBuddy (GLM-5.2) 于 2026-06-26 编写。如有疑问，请查阅 DEVLOG.md 或 docs/HANDOFF-TO-TRAE.md。_
