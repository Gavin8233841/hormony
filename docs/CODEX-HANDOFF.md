# Codex 接手指引文档

> 本文档由 WorkBuddy (Claude) 于 2026-06-25 编写，用于向 Codex (GPT-5) 交接项目全貌。
> Codex 接手后请先通读本文档，再阅读 README.md、DEVLOG.md、docs/ 下各文件。

---

## 一、竞赛信息对齐（必须精确理解）

### 赛事全貌

| 项目 | 内容 |
|------|------|
| 赛事全称 | 2026 中国高校计算机大赛-人工智能创意赛（C4-AI） |
| 赛道 | 鸿蒙高校创新赛 |
| 作品方向 | Agent 创新 |
| 主办 | 全国高等学校计算机教育研究会 |
| 承办 | 华为公司 + 浙江大学 |
| 官方页面 | https://developer.huawei.com/consumer/cn/activity/incentive/C4 |
| 总入口 | https://developer.huaweicloud.com/c4ai.html |
| 官方邮箱 | AiContest@huawei.com |

### 关键规则（影响技术决策）

1. **FAQ 第 13 条：Agent 创新方向不限制模型 API 的使用**——可自由选择市场可用 AI 工具及模型 API（豆包/OpenAI 兼容接口等均可）。
2. 面向中国内地及港澳台地区高校在校生（专科/本科/硕士/博士），不限专业。
3. 每队不超过 3 人，可跨学校跨专业，须有一名指导老师（队长所属高校正式教师）。
4. 开放式命题，鼓励基于 HarmonyOS 技术创新开发。
5. 截止前可多次更新作品（至多 10 次），晋级后只能基于原作品迭代优化，不得换新作品。
6. 大赛不提供硬件设备，可使用模拟器/云测试/自有设备。
7. 提交入口：官方页面 → 华为 OAuth → 黄大年茶思屋平台。
8. 使用 AI Coding 工具需在文档中单独说明（工具名、模型 API、开源库、框架、许可证）。

### 官方附件（已下载至项目根目录）

- `2026"中国高校计算机大赛―人工智能创意赛"鸿蒙高校创新赛竞赛规程.pdf`
- `2026"中国高校计算机大赛―人工智能创意赛"鸿蒙赛道报名手册.pdf`

> 仍需登录茶思屋平台下载第三个附件：作品说明文档模板。提交前必须核对最新截止时间、提交格式、附件要求。

---

## 二、用户明确指令（必须遵守）

1. **不要直接确定沿用现有初稿思路**——先搭建好需要的一切基础设施，再开始开发，之后再评估初稿成果以及是否复用。
2. **开发日志规范**：`DEVLOG.md` 为追加写入，严禁覆写已有内容；每条记录必须包含模型名称、时间戳（UTC + 北京时间）、操作摘要、涉及文件。
3. **协作模式**：WorkBuddy 负责环境配置/脚手架/AI Agent 后端/接口/文档/MCP 配置；Codex 负责代码审查/架构分析/鸿蒙端开发指引/接手后续开发。
4. **文件操作安全规则**：禁止批量/递归/通配符删除；单文件删除需确认路径；不得覆写已有成果；不得修改工作区之外的文件；不确定时停止并询问。
5. **标识符规则**：严禁猜测任何标识符（键名、变量名、路径、字段），必须从文件读取精确表述。

---

## 三、环境核查结果（2026-06-25 WorkBuddy 复核）

### 已就绪

| 工具 | 版本 | 路径 |
|------|------|------|
| DevEco Studio | 26.0.0.461 (build 2600461) | `C:\Program Files\Huawei\DevEco Studio\` |
| HarmonyOS SDK | 随 DevEco 内置 | `sdk\default\openharmony\` (ets/js/native/previewer/toolchains) |
| 模拟器镜像 | HarmonyOS-6.1.1 (phone_x86) | `AppData\Local\Huawei\Sdk\system-image\HarmonyOS-6.1.1\` |
| ohpm | 26.0.0.410 | `DevEco Studio\tools\ohpm\bin\ohpm.bat` |
| hvigor | 随 DevEco | `DevEco Studio\tools\hvigor\` |
| hdc | 随 SDK | `sdk\default\openharmony\toolchains\hdc.exe` |
| Node.js | v22.22.2 | 系统 PATH（WorkBuddy shell） |
| npm | 10.9.7 | 系统 PATH |
| pnpm | 11.9.0 | 系统 PATH |
| Python | 3.13.12 | 系统 PATH |
| Git | 2.54.0.windows.1 | 系统 PATH |
| OpenJDK | 17.0.14 LTS | 系统 PATH |

### 环境差异说明

Codex 在其终端中报告 Node v24.16.0 + npm 11.13.0、pnpm 不在 PATH。这是因为系统存在两个 Node 安装：
- **WorkBuddy shell**：Node v22.22.2（managed preferred）/ npm 10.9.7 / pnpm 11.9.0
- **Codex 终端**：Node v24.16.0（system fallback）/ npm 11.13.0 / pnpm 未安装

建议：Codex 端统一使用 `npx` 或在需要时通过 `npm install -g pnpm` 补齐，或在 Codex 配置中指定 Node 路径。Web 后端已配置 `.npmrc` 指向 npmmirror.com，`pnpm-lock.yaml` 已生成。

### 待配置

| 项目 | 说明 |
|------|------|
| JAVA_HOME | 未设置，建议指向 JDK 17 安装目录 |
| HOS_SDK_HOME | 未设置，建议指向 SDK 目录 |
| 模型 API Key | 需在 `apps/web/.env.local` 中配置 `MODEL_API_KEY`（豆包 OpenAI 兼容接口） |
| 官方第三附件 | 作品说明文档，需登录茶思屋下载 |

---

## 四、DevEco MCP 连接（已验证可用）

### 连接方式

本项目通过 **DevEco Toolbox MCP** 实现AI工具与 DevEco Studio 的连接，类比 Xcode 通过 MCP 连接的方式。

- **MCP 包名**：`@deveco-codegenie/mcp@beta`
- **配置文件**：`~/.workbuddy/mcp.json`
- **启动方式**：`npx -y @deveco-codegenie/mcp@beta`，通过 `DEVECO_PATH` 环境变量指向 DevEco Studio 安装路径，`PROJECT_PATH` 指向鸿蒙工程目录

### 配置内容

```json
{
  "mcpServers": {
    "deveco-mcp": {
      "command": "npx",
      "args": ["-y", "@deveco-codegenie/mcp@beta"],
      "env": {
        "DEVECO_PATH": "C:\\Program Files\\Huawei\\DevEco Studio",
        "PROJECT_PATH": "C:\\Users\\guo82\\Desktop\\Hormony\\apps\\harmonyos"
      },
      "disabled": false
    }
  }
}
```

### 可用工具（10 个，已验证 `harmonyos_knowledge_search` 可用）

| 工具名 | 功能 |
|--------|------|
| `harmonyos_knowledge_search` | 查询鸿蒙云端知识库（API 23），已验证返回 Stage 模型 module.json5 完整文档 |
| `check_ets_files` | ArkTS (.ets) 文件语法检查 |
| `check_cpp_files` | C++ 文件静态语法检查 |
| `build_project` | 项目构建 |
| `start_app` | 在模拟器/真机中启动应用 |
| `get_hilog_or_faultlog_recent` | 获取设备日志 |
| `get_app_ui_tree` | 获取当前页面 UI 树 |
| `project_sync` | 项目同步（初始化/依赖更新后） |
| `perform_ui_action` | 在已启动的 app 中执行点击/输入 |
| `verify_ui` | 基于自然语言测试用例的 UI 自动化验证 |

### 验证记录

WorkBuddy 于 2026-06-25 调用 `harmonyos_knowledge_search`（关键词：Stage模型、module.json5、工程结构），成功返回完整文档，确认 MCP 链路畅通。

### 官方替代方案

华为在 2026 HDC 发布了官方 **DevEco CLI**（https://gitcode.com/openharmony-sig/deveco-cli ），npm 包 `@deveco/deveco-cli` v1.0.0 可查询。deveco-toolbox 项目后续仅做缺陷修复，建议关注官方 CLI 方案。

---

## 五、当前项目状态（Git 首次提交已建立）

### Git 状态

- 仓库已初始化，分支 `main`
- 首次提交：`690b07f`（64 文件，8818 行）
- 工作区干净，无未跟踪文件
- `.gitignore` 已配置：排除 node_modules / .next / oh_modules / .hvigor / .env / .workbuddy / *.tsbuildinfo

### 初稿代码现状（Codex 已审查，详见 DEVLOG.md line 77）

**Web 后端（可运行）：**
- Next.js 14 生产构建通过
- `npm run typecheck` 通过
- `next start -p 3001` + `scripts/test-chat.mjs` 验证 SSE 对话链路返回 Retrieval 轨迹、正文、Citation
- 6 个 API 路由：`/api/chat`、`/api/courses`、`/api/plan`、`/api/profile`、`/api/quiz`、`/api/safety-review`
- 7 个 Agent + 编排器，演示模式回退正常

**已知缺陷（Codex 指出）：**
1. 鸿蒙端缺少完整 Hvigor 工程文件（根级 `build-profile.json5`、`hvigorfile.ts`、`oh-package.json5`；entry 级同名文件也缺失），无法命令行构建
2. 文档写了 `/api/knowledge/upload` 和 `/api/knowledge/search`，源码无对应路由
3. Web 课程页与画像页使用硬编码演示数据，未调用已有 `/api/courses` 与 `/api/profile`
4. 鸿蒙端首页快捷入口路由跳转为注释状态；知识库页用本地演示数据，未调后端检索接口

### 待评估事项（用户要求：先搭好基础设施再决定是否复用初稿）

- 初稿 Web 后端架构是否合理，是否值得在此基础上迭代
- 鸿蒙端骨架是否值得复用，还是用 DevEco Studio 新建标准工程更稳妥
- 多 Agent 编排逻辑是否满足参赛要求的技术亮点
- 演示模式回退机制是否保留

---

## 六、Codex 建议的下一步（来自 DEVLOG.md，供参考）

1. 补齐 HarmonyOS 可构建工程，让 DevEco Studio / DevEco CLI / MCP 能真正检查和构建 ArkTS
2. 补 `/api/knowledge/search`，让 Web 和 ArkTS 知识库页都走后端检索
3. 接入豆包 OpenAI 兼容 API，但保留演示模式兜底
4. 做鸿蒙端页面跳转、对话、计划、知识库的端到端闭环
5. 再加服务卡片、通知或元服务中的一个作为鸿蒙赛道亮点

---

## 七、协作约定

### 开发日志

- 文件：`DEVLOG.md`（项目根目录）
- 规则：追加写入，不得覆写；每条含模型名称 + 时间戳（UTC + CST）+ 操作摘要 + 涉及文件
- Codex 每次操作后必须追加记录

### 文件安全

- 禁止批量/递归/通配符删除
- 单文件删除需确认绝对路径
- 不得覆写已有成果，合理命名新文件
- 不确定时停止并询问用户

### AI 工具声明

最终提交文档需单独列出：WorkBuddy (Claude) / Codex (GPT-5) / 模型 API / 开源库 / 框架 / 许可证。

---

## 八、关键文件索引

| 文件 | 用途 |
|------|------|
| `README.md` | 项目全貌，含竞赛信息/架构/环境/MCP/Agent 详解 |
| `DEVLOG.md` | 开发日志（WorkBuddy line 8, Codex line 77） |
| `docs/notes/competition-summary.md` | 竞赛规则摘要 |
| `docs/architecture.md` | 技术架构设计 |
| `docs/api-spec.md` | API 接口规范 |
| `docs/notes/env-setup.md` | 环境配置记录 |
| `docs/project-status.md` | 项目状态总览 |
| `apps/web/` | Next.js AI Agent 后端 + Web 原型 |
| `apps/harmonyos/` | ArkTS 鸿蒙端骨架 |
| `scripts/test-chat.mjs` | 对话接口测试脚本 |
| `~/.workbuddy/mcp.json` | DevEco MCP 配置（不在 Git 中） |
