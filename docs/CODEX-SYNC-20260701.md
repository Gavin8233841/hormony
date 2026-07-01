# Codex 信息同步文档

> **2026-07-01 Codex 纠正**：本文创建时将另一项目的 Render 配置误认为鸿学伴已部署。本项目当时没有公网 API 地址，当前批准方案为 Vercel Hobby 无状态真实 Agent 网关 + HarmonyOS ArkData 本地状态。下文“云端服务器已配置”及持久卷相关判断不再作为当前事实。

> **2026-07-01 05:10 Codex 实测**：通过项目 ID 复核确认 Vercel 项目 `hormony` 已存在，生产域名为 `https://hormony-ruddy.vercel.app`。提交 `745921d` 已生产部署，`/api/health` 返回 `ready/model/stateless`，聊天 SSE 真实豆包调用成功；计划与出题首次联调因 SDK 默认重试叠加深度推理超过 60 秒，正在以“关闭深度思考 + 禁用自动重试”修复。旧 Token 曾被 Trae 写入未跟踪文档，已脱敏并要求轮换。

> 创建时间：2026-07-01 00:00 CST
> 创建者：Trae（Claude in TRAE Work）
> 目的：消除 Trae 与 Codex 之间的信息差，同步所有 Codex 可能不知道的关键工程决策和已完成工作
> HEAD：a24219b

---

## ⚠️ 最高优先级：Vercel 部署进展

### 已确定事项

| 项目 | 内容 |
|------|------|
| **云平台** | Vercel（Hobby 免费层） |
| **认证方式** | Token（`vcp_` 前缀，已通过 `npx vercel --token` 完成认证） |
| **团队** | GWYY |
| **项目名** | `hormony`（项目 ID `prj_pEkBHRQqLMyNulhHyrKX01YRrLzh`） |
| **框架检测** | Next.js（Vercel 自动识别，默认 Build Command = `next build`） |
| **部署目录** | `apps/web` |
| **Docker** | 仅保留本地复现，不再作为生产前提 |

### 部署状态

- [x] Vercel 账户已具备
- [x] 使用轮换后的 Token 完成生产部署（Token 不落盘）
- [x] 项目经项目 ID 复核
- [x] 框架自动检测（Next.js）
- [x] 提交 `745921d` 生产部署成功
- [x] 公网 HTTPS URL：`https://hormony-ruddy.vercel.app`
- [x] 生产模型与无状态环境变量已配置
- [x] `Constants.ets` 的 `BASE_URL` 已替换为 Vercel URL
- [x] 原生 App 请求无浏览器 Origin，不需要为 HAP 添加 CORS 域名

### Vercel 部署已知问题

1. **Windows 计算机名含中文导致 ByteString 报错**
   - 报错：`TypeError: Cannot convert argument to a ByteString because the character at index 0 has a value of 37101`
   - 根因：计算机名 `郭泳延的笔记本`（含中文字符），Vercel CLI 读取 `COMPUTERNAME` 环境变量构建 HTTP 头时崩溃
   - 修复：部署前需先覆盖环境变量：
     ```powershell
     $env:COMPUTERNAME = "DESKTOP-GUO82"
     $env:USERDOMAIN = "DESKTOP-GUO82"
     $env:LOGONSERVER = "\\DESKTOP-GUO82"
     $env:USERDOMAIN_ROAMINGPROFILE = "DESKTOP-GUO82"
     [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
     chcp 65001 > $null
     ```

2. **项目名必须全小写**
   - Vercel 项目名只允许小写字母、数字、`-`、`_`、`.`
   - 首次用 `Harmony`（大写 H）报错 400

3. **Vercel CLI 未全局安装**
   - 系统未安装全局 `vercel`，需通过 `npx vercel` 运行

### Vercel Hobby 免费层限制

| 限制项 | 值 | 影响 |
|--------|------|------|
| 带宽 | 100GB/月 | 足够 API 服务 |
| Serverless 函数执行 | 100GB-Hours/月 | 足够 |
| 构建时长 | 6000 分钟/月 | 足够 |
| 部署频率 | 100 次/天 | 足够 |
| 函数时长 | 路由显式限制 60 秒，模型超时 45 秒 | 避免模型调用占满函数时长 |
| 持久化 | **无持久卷** | 内存数据重启丢失，需无状态改造 |

### 部署后 Codex 需执行

1. 获取 Vercel 公网 URL 后，将 `Constants.ets` 的 `BASE_URL` 改为 `https://harmony-xxx.vercel.app`
2. 在 Vercel 项目设置中添加环境变量：`MODEL_API_KEY`、`MODEL_BASE_URL`、`MODEL_NAME`
3. `ORIGIN_ALLOWLIST` 添加 Vercel 域名
4. 后端无状态改造（Vercel 无持久卷，`APP_STATE_PERSISTENCE=on` 文件存储不可用）
5. 端侧 ArkData 本地状态作为离线兜底

---

## Trae 已完成但 Codex 可能不知道的工作

### 1. 生产级数据资产（已完成验证）

| 资产类别 | 数量 | 验证状态 | 文件位置 |
|----------|------|---------|---------|
| 知识切片 | 147条 | 每条≥100字，0条不达标 | `apps/web/src/lib/data/cs101-knowledge.ts`（52条）<br>`apps/web/src/lib/data/cs102-knowledge.ts`（48条）<br>`apps/web/src/lib/data/cs103-knowledge.ts`（47条） |
| 题库题目 | 81题 | 60选择+21简答，每题含答案+解析 | `apps/web/src/lib/data/quizzes.ts` |
| 外部资源 | 36条 | URL全部审计通过，无平台首页 | `apps/web/src/lib/data/external-resources.ts` |
| 数据桶导出 | 1文件 | 含 getQuizzesByCourse 辅助函数 | `apps/web/src/lib/data/index.ts` |

### 2. 类型系统扩展（已完成）

- `KnowledgeChunk` 接口新增 `topic?: string` 字段，支持知识切片与题库按主题关联
- 新增 `ExternalResource` 接口（id/title/type/url/description/courseId/tags）
- 文件：`apps/web/src/lib/types.ts`

### 3. 后端数据层改造（已完成）

- `db.ts` 的 `seedDemoData()` 已替换为从数据文件导入全部 147 条切片 + 25 个 Quiz 对象 + 36 条外部资源
- DB 接口新增 `externalResources: ExternalResource[]` 字段
- Store 新增方法：`getQuizzesByCourse(courseId)`、`getExternalResources(courseId?)`、`getExternalResourcesByType(type)`
- 文件：`apps/web/src/lib/store/db.ts`

### 4. Quiz Agent 历史回退逻辑（已由 Codex 废弃）

- 该逻辑曾在 LLM 不可用时返回静态题库，但违反“所有 AI 出题必须由真实模型生成”的当前边界。
- 生产 `POST /api/quiz` 已移除静态回退；精选题库仍可作为明确标注的本地课程内容使用。
- 文件：`apps/web/src/lib/agents/quiz-agent.ts`

### 5. API 路由扩展（已完成）

- `GET /api/quiz?courseId=` — 支持按课程获取题库
- `GET /api/resources?courseId=&type=` — 新增外部资源 API 端点
- 文件：`apps/web/src/app/api/quiz/route.ts`、`apps/web/src/app/api/resources/route.ts`

### 6. 学术核验（已完成）

- 60 道选择题答案全部通过权威学术资源核验（CLRS、Silberschatz、RFC 793/768/8446 等）
- 核验正确率：100%
- 难易梯度分布：记忆/理解 ~40%、应用/分析 ~40%、综合/证明 ~20%
- 核验报告：`DEVLOG.md` 中 2026-06-30T10:25:00Z 条目

### 7. 外部资源 URL 审计（已完成）

- 36 条 URL 逐条通过 WebFetch 访问验证
- 修复 4 条平台首页链接（res_04 清华大学出版社、res_10 电子工业出版社、res_25 中国大学MOOC、res_26 极客时间）
- 修复 3 条标题/URL 不一致（res_16 后缀统一、res_21 MIT课程号更新、res_24 Coursera标题对齐）
- 审计报告：`docs/RESOURCE-AUDIT-20260630.md`

### 8. 数据完整性测试增强（已完成）

- 新增选择题数量验证（每门≥20道）
- 新增题干全局唯一性断言
- 新增资源标题和 URL 全局唯一断言
- 文件：`apps/web/src/lib/data/data-integrity.test.ts`
- 测试结果：81/81 passed（8 test files）

---

## 当前测试与验证状态

| 验证项 | 命令 | 结果 | 最后验证时间 |
|--------|------|------|-------------|
| ESLint | `npx next lint` | No warnings or errors | 2026-06-30 |
| 类型检查 | `npx tsc --noEmit --project tsconfig.typecheck.json` | 0 errors | 2026-06-30 |
| 单元测试 | `npx vitest run` | 81/81 passed (8 test files) | 2026-06-30 |
| Git diff | `git diff --check` | exit code 0 | 2026-06-30 |

---

## 工具链状态

### DevEco MCP（11个工具，已完成实名认证）

| 工具名 | 用途 | 状态 |
|--------|------|------|
| `build_project` | 构建 HAP | 可用 |
| `start_app` | 安装启动应用 | 可用 |
| `check_ets_files` | ETS 静态检查 | 可用 |
| `check_cpp_files` | C/C++ 检查 | 可用 |
| `get_app_ui_tree` | UI 树获取 | 可用 |
| `perform_ui_action` | UI 操作（点击/滑动/输入/截图） | 可用 |
| `get_hilog_or_faultlog_recent` | 日志监控 | 可用 |
| `harmonyos_knowledge_search` | 官方知识检索 | 偶发网络超时 |
| `project_sync` | 工程同步 | 可用 |

### CLI 路径

- **hvigorw**: `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js`
- **hdc**: `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`
- **DevEco Code CLI**: `deveco`（版本 0.1.0）

### 模拟器

- 名称：Pura 90 Pro Max
- 地址：127.0.0.1:5555
- 分辨率：1256x2760

### 模型配置

- **Base URL**: `https://ark.cn-beijing.volces.com/api/v3`（火山引擎豆包）
- **模型名**: `doubao-seed-2-1-pro-260628`
- **API Key**: 通过环境变量 `MODEL_API_KEY` 注入，**禁止写入任何文件**
- **本地 .env.local**: 仅含 `MODEL_BASE_URL` 和 `MODEL_NAME`，不含 `MODEL_API_KEY`
- **模型不可用**: 未配置 `MODEL_API_KEY` 时健康检查和 AI 接口返回 `503 MODEL_UNAVAILABLE`，不存在演示回答

### 当前端侧 BASE_URL

```typescript
// apps/harmonyos/entry/src/main/ets/common/Constants.ets
static readonly BASE_URL: string = 'http://10.0.2.2:3000';
```

> ⚠️ 此地址仅适用于模拟器访问开发机。提交包和远程评审需要改为云端 HTTPS 地址。

---

## 当前架构概览

### 四入口底栏架构（Codex 提交 `7f5ff0b` 重构）

- `Index.ets` 是主框架，通过 `@State currentIndex` 切换4个tab（今日/课程/学伴/我的）
- 只有 `Plan` 和 `Knowledge` 保留独立路由
- `Chat`/`Course`/`Profile` 改为导出组件（`ChatContent`/`CourseContent`/`ProfileContent`）

### 后端架构

- **框架**: Next.js 14 + TypeScript
- **路径**: `apps/web/src/`
- **数据存储**: 内存 Map 单例（`globalThis.__APP_DB__`），支持 JSON 文件持久化
- **RAG 引擎**: 零依赖 TF-IDF + 中文 bigram 分词，`apps/web/src/lib/rag/index.ts`
- **Agent 编排**: 7 个 Agent（Profile/Retrieval/Tutor/Planner/Quiz/Evaluator/Safety）
- **API 路由**: 17 个端点（含新增 `/api/resources`）

### 正反馈闭环设计

```
学知识点 → 做题 → 发现薄弱 → AI讲解 → 再练习
    ↑                                    |
    +---------- 知识切片推荐 <-----------+
```

- 知识切片与题库通过 `courseId + topic` 关联
- 精选题库按 courseId → topic 关联，AI 出题接口不使用静态回退
- 外部资源通过 `courseId` 与课程关联
- 用户画像 `weakTopics` 与知识切片 `topic` 对齐

---

## 竞赛关键信息

| 项目 | 内容 |
|------|------|
| 参赛方向 | Agent 创新 |
| 初赛截止 | 2026-07-26 24:00 |
| 复赛截止 | 2026-09-30 24:00 |
| 评分重点 | 基础创新50分 + 完整度20分 + 前景20分 + 规范性10分 + 应用价值加分20分 |
| 提交材料 | 作品说明PDF + 演示视频MP4(≤5min) + Demo ZIP |
| 上传限制 | 整个上传/更新过程最多10次 |
| 官方赛事页 | https://developer.huawei.com/home/C4-AI |
| 作品提交入口 | https://developer.huawei.com/consumer/cn/activity/incentive/C4 |

### 得分优先顺序

可演示的鸿蒙创新能力 > 端云主流程可靠性 > 正式提交材料 > 更多数据和后台页面

### 暂缓事项

1. Web 管理页面视觉重做
2. 继续扩大题库、知识切片和外链数量
3. 为展示技术数量而增加不可见 Agent 或复杂向量数据库
4. 多用户商业级权限、分布式缓存和多实例部署

---

## 用户硬约束（必须遵守）

1. 颜色全部收口 `Constants.ets`，禁止页面内硬编码
2. UI 文案禁止暴露技术术语（Agent/RAG/Retrieval 等）
3. 构建后必须运行验证
4. 每次节点进展更新 `DEVLOG.md`（时间戳取真实系统时间）
5. MCP 工具调用必须传 `hvd` 参数
6. 禁止批量删除文件
7. 禁止修改 `model.ts`、`orchestrator.ts`、评分算法和 API 返回结构（除非 Codex 明确授权）
8. 禁止修改 `DataModels.ets`、主路由、AppStorage 键名和导航架构
9. API Key 不得明文写入任何文件
10. 品牌色必须使用 `#0a59f7`，禁止使用非官方品牌色 `#007DFF`

---

## Git 提交历史（最近10条）

```
a24219b feat: 建立竞赛得分边界与后端部署基础
48d75b8 feat: 闭环错题复习与再测流程
794fd6a feat: 持久化用户学习状态
2267a3d feat: 打通学习计划同步与任务打卡
32cdec0 feat: 扩充三门课程选择题库
0235baf feat: 打通知识题库与原生测验闭环
2fc3d40 docs: 创建接力交接文档V2
60d17b4 feat: 完善端侧学习闭环与交互体验
7f5ff0b feat: 重构鸿学伴原生端侧体验
a33a3fe chore: 接入端侧设计审查资源
```

### Trae 未提交的工作

以下文件已被 Trae 修改但尚未提交 Git（等待 Codex 复核）：

| 文件 | 修改内容 | Trae 轮次 |
|------|---------|-----------|
| `apps/web/src/lib/data/external-resources.ts` | 7条URL/标题修复（资源审计） | 2026-06-30 |
| `apps/web/src/lib/data/data-integrity.test.ts` | 新增选择题数量+题干唯一性+URL唯一性断言 | 2026-06-30 |
| `docs/RESOURCE-AUDIT-20260630.md` | 新增：36条资源审计报告 | 2026-06-30 |
| `DEVLOG.md` | 追加：题库扩量+学术核验+资源审计记录 | 2026-06-30 |

---

## Trae 与 Codex 分工边界

### Trae 负责（已完成或持续执行）

1. 在既有 TypeScript interface 下扩充知识切片、题目和资源条目
2. 逐条核对外部链接、题目答案、知识点名称和数据唯一性
3. 补充数据完整性测试、API 文档、开发日志和文件清单
4. 执行 lint、typecheck、test、ArkTS 静态检查、构建及截图采集
5. 按 Codex 给定页面与字段做机械性样式统一，不改变信息架构

### Codex 负责

1. API 数据契约、服务端状态边界、评分与安全逻辑
2. Agent 编排、模型调用、RAG 检索策略和用户画像反馈闭环
3. HarmonyOS 主导航、跨页面状态、核心学习流程与系统级能力
4. 重大交互方向、设计系统和每个大阶段的一次视觉总验收
5. Trae 交付的关键代码审查、风险修复与最终 Git 提交

### Trae 禁止范围

1. 不修改 `model.ts`、`orchestrator.ts`、评分算法和 API 返回结构
2. 不修改 `DataModels.ets`、主路由、AppStorage 键名和导航架构
3. 不新增依赖，不迁移存储，不自行增加页面入口
4. 不使用持续循环技能处理明确的单批任务
5. 不为满足数量而复制题目、循环复用题干或使用无法核对的答案

---

## 待解决问题

### 1. 云端服务器信息缺失（最高优先级）

用户已配置免费云端服务器，但以下信息未记录到工作区：
- 云平台名称
- 公网 HTTPS URL
- 环境变量配置方式
- 持久化方案
- 部署方式（GitHub 自动部署 / 手动推送）
- 冷启动行为

**需要用户直接提供上述信息。**

### 2. Docker 部署方案可能冗余

Codex 在 `a24219b` 提交中创建了：
- `apps/web/Dockerfile`
- `apps/web/.dockerignore`
- `DEPLOYMENT-GUIDE.md` 中的 Docker 部署章节

如果用户的云端平台支持直接从 GitHub 仓库自动部署 Next.js 应用（如 Render 的 Web Service），则 Dockerfile 可能不需要使用。需根据实际平台确认。

### 3. BASE_URL 待替换

当前 `Constants.ets` 中 `BASE_URL = 'http://10.0.2.2:3000'` 仅适用于模拟器开发。获取云端 URL 后需替换为 HTTPS 地址。

### 4. CORS 白名单待更新

`ORIGIN_ALLOWLIST` 当前为 `http://localhost:3000,http://10.0.2.2:3000`，需添加云端 HTTPS 域名。

### 5. 官方作品说明模板未找到

仓库中未找到官方作品说明模板。需队长从赛事门户下载。

---

## 文件索引

### 核心文档
- `HANDOVER-V2.md` — 原始交接文档（Claude 25轮 → Codex）
- `PRODUCT.md` — 产品定义
- `DESIGN.md` — 设计系统规范
- `AGENTS.md` — Agent 配置（如存在）
- `DEVLOG.md` — 开发日志（所有轮次记录）
- `README.md` — 项目说明

### 开发边界
- `docs/TRAE-DEVELOPMENT-BOUNDARIES.md` — Codex 给 Trae 的边界与验收线
- `docs/COMPETITION-SCORE-FIRST-PLAN.md` — 竞赛得分优先实施边界

### 部署相关
- `docs/DEPLOYMENT-GUIDE.md` — 部署指南（含 Docker，可能需更新）
- `apps/web/Dockerfile` — Docker 镜像构建文件
- `apps/web/.env.example` — 环境变量示例
- `apps/web/.env.local` — 本地环境变量（不含密钥）

### 数据资产
- `apps/web/src/lib/data/cs101-knowledge.ts` — 数据结构52条知识切片
- `apps/web/src/lib/data/cs102-knowledge.ts` — 操作系统48条知识切片
- `apps/web/src/lib/data/cs103-knowledge.ts` — 计算机网络47条知识切片
- `apps/web/src/lib/data/quizzes.ts` — 81道题库题目
- `apps/web/src/lib/data/external-resources.ts` — 36条外部资源
- `apps/web/src/lib/data/index.ts` — 数据桶导出
- `apps/web/src/lib/data/data-integrity.test.ts` — 数据完整性测试

### 审计报告
- `docs/RESOURCE-AUDIT-20260630.md` — 外部资源URL审计报告

### API 文档
- `docs/api-spec.md` — API 接口规范
- `docs/DEPLOYMENT-GUIDE.md` — 含 API 端点清单

---

## ⚠️ 资产更新通知（2026-07-01 22:27 CST）

> **Codex 必读**：Trae 已完成前端资源调研，方向已调整为鸿蒙端侧原生资源。
> 下列内容是调研记录，不是安装指令；最终采用结论见 `docs/FRONTEND-RESOURCE-ADOPTION.md`。

### 调研概述

Trae 派出14个子代理执行全面调研（10个Web前端 + 4个鸿蒙端侧），用户审查后否决了大部分Web资源（Zustand/Comlink/BlurHash/SpinKit/confetti等），仅保留@ohos/lottie方向和3份Lottie动画JSON素材。方向已调整为鸿蒙端侧原生资源。

### 新增资产

| 资产 | 位置 | 说明 |
|------|------|------|
| **资产清单文档** | `docs/ASSET-INVENTORY.md` | 完整的鸿蒙端侧资源清单，含ohpm安装命令、ArkUI集成方法、竞赛创新策略 |
| SVG图标包 | `assets/frontend-resources/icons/` | 37个教育主题SVG图标（Tabler 31个 + Phosphor 6个），MIT许可证 |
| Lottie动画JSON | `assets/frontend-resources/animations/` | 3个动画文件（成功对勾、进度填充、奖杯庆祝），待@ohos/lottie真机验证 |
| Web端CSS/库模板 | `assets/frontend-resources/css/` `libs/` | Web端专用，HAP不使用（用户已否决） |

### Codex 需关注的核心发现

#### 推荐引入的ohpm三方库

| 优先级 | 包名 | 用途 | 版本 |
|--------|------|------|------|
| P0 | `@ohos/lottie-turbo` | 声明式Lottie动画（官方推荐替代@ohos/lottie） | V1.0.12 |
| P0 | `@ohos/mpchart` | 学习数据可视化（7种图表） | - |
| P0 | `@ohos/axios` | Promise网络请求 | - |
| P0 | `@pura/harmony-utils` | 综合工具库（日期/加密/JSON/首选项/扫码） | V1.3.3 |
| P0 | `@ohos/imageknife` | 图片加载缓存 | - |
| P1 | `@pura/harmony-dialog` | 17种弹窗类型 | V1.1.8 |
| P1 | `@luvi/lv-markdown-in` | Markdown渲染+代码高亮+流式（AI对话必需） | V3.4.4 |
| P1 | `@ohmos/calendar` | 学习计划日历 | V2.1.4 |
| P1 | `@ohos/pulltorefresh` | 下拉刷新/上拉加载 | V2.0.1 |

#### ArkUI原生能力（无需第三方库）

- **Particle粒子动画**（API 12+）：测验全对烟花、成就解锁金粉
- **springMotion弹簧物理**（API 9+）：卡片弹性弹出、拖拽跟随
- **geometryTransition一镜到底**（API 11+）：卡片点击展开详情
- **keyframeAnimateTo关键帧**（API 11+）：成就解锁多段动画
- **DataPanel/Gauge/Progress**：原生数据可视化
- **@ObservedV2/@Trace**（API 12+）：精细状态管理V2
- **AttributeModifier/AttributeUpdater**（API 11+/12+）：动态样式

#### 竞赛核心创新方向（端侧AI + 分布式）

竞赛明确聚焦"HarmonyOS端侧AI + 全场景分布式核心技术"。推荐创新叙事：

> **"端侧AI驱动的无边界学习"**

1. **拍照学**：Core Vision Kit OCR（端侧，拍照教材→知识卡片，创新5/难度2）
2. **听学/说学**：Core Speech Kit TTS/ASR（端侧离线，创新5/难度2）
3. **跨设备学**：distributedKVStore + 跨端迁移（API 12+免权限，创新5/难度3）
4. **系统级学**：Intents Kit/小艺智能体（需白名单，创新5/难度4）
5. **沉浸式学**：分屏多窗口 + Particle粒子 + 毛玻璃（创新4/难度3）

**最高性价比路线**：OCR + TTS + 分布式KVStore + 跨端迁移 + 服务卡片 + 代理提醒 = 创新分28/难度14

### 验证待办（Codex 需执行）

- [ ] `@ohos/lottie-turbo` 在API 12环境 `ohpm install` 验证
- [ ] 3个Lottie JSON在真机/模拟器渲染验证（注意：5.0真机有无法播放的报告）
- [ ] `@ohos/mpchart` 雷达图在Profile页集成验证
- [ ] `@luvi/lv-markdown-in` 流式Markdown在Chat页集成验证
- [ ] Core Vision Kit OCR 真机验证（不支持模拟器）
- [ ] Core Speech Kit TTS 真机验证
- [ ] distributedKVStore 跨设备同步验证（需多设备）

### 注意事项

1. **Web资源已否决**：`assets/frontend-resources/css/` 和 `libs/` 目录中的Web端资源（Zustand/Comlink/BlurHash/SpinKit CSS）已被用户否决，不纳入HAP依赖。保留在工作区仅供参考。
2. **@ohos/lottie真机风险**：搜索显示5.0真机存在Lottie无法播放的报告，引入前务必在目标真机实测。建议优先使用@ohos/lottie-turbo。
3. **品牌色约束**：所有新增UI必须使用 `#0a59f7`，禁止 `#007DFF`。
4. **不涉及Git提交**：本次工作未提交Git，所有新增文件待Codex审查。

---

## ⚠️ ohpm包源验证与评估结果（2026-07-01 22:38 CST）

> **Codex 必读**：Trae 已完成全部11个ohpm包的 `ohpm info` 验证和3个Lottie JSON格式验证。以下为验证结果和可靠性/可用性/创新性评估。

### 包源验证结果

| 包名 | 实际最新版 | 许可证 | 最近发布 | 版本数 | 验证状态 |
|------|-----------|--------|---------|--------|---------|
| `@ohos/lottie` | 2.0.31 | MIT | 11个月前 | 107 | ✅ 可用，稳定版较旧 |
| `@ohos/lottie-turbo` | 1.0.12 | Apache-2.0 | 1个月前 | 39 | ✅ 可用，活跃维护 |
| `@ohos/mpchart` | 3.0.28 | Apache-2.0 | **~2年前** | 64 | ⚠️ 可用但稳定版维护停滞 |
| `@luvi/lv-markdown-in` | 3.4.4 | MIT | **6天前** | 58 | ✅ 可用，非常活跃 |
| `@ohos/axios` | 2.2.10 | MIT | 1个月前 | 39 | ✅ 可用 |
| `@pura/harmony-utils` | **1.4.1** | Apache-2.0 | 1个月前 | 33 | ✅ 可用（版本高于此前报告） |
| `@ohos/imageknife` | 3.2.9 | Apache-2.0 | - | 95 | ✅ 可用 |
| `@pura/harmony-dialog` | 1.1.8 | Apache-2.0 | 9个月前 | 19 | ✅ 可用 |
| `@ohmos/calendar` | 2.1.4 | Apache-2.0 | >1年前 | 7 | ⚠️ 维护停滞 |
| `@ohos/pulltorefresh` | **3.0.1** | Apache-2.0 | 1个月前 | 20 | ✅ 可用（版本高于此前报告） |

### Lottie JSON 验证结果

3个文件全部通过 `ConvertFrom-Json` 验证，Lottie schema v5.7.4：
- `checkmark-success.json`: 200x200, 3层, 60帧/2秒 ✅
- `learning-progress.json`: 320x80, 3层, 90帧/3秒 ✅
- `trophy-celebration.json`: 200x200, 10层, 75帧/2.5秒 ✅

### 项目现状确认

- API版本: `5.0.0(12)` — API 12
- **当前ohpm依赖: 零**（oh-package.json5 dependencies为空）
- Chat.ets: **无Markdown渲染**（纯文本），仅用LoadingProgress
- Profile.ets: **无任何数据可视化**（无DataPanel/Gauge/Chart）
- Quiz.ets: 使用原生Progress(Linear)，无动画

### Trae 评估结论（可靠性/可用性/创新性）

#### 第一优先级 — 立即可引入

1. **`@luvi/lv-markdown-in`** — 可靠性5/可用性5/创新性4
   - Chat.ets当前无Markdown渲染，AI回复纯文本展示，**急需补强**
   - 流式渲染完美匹配AI对话SSE场景
   - 6天前发布，58个版本，非常活跃
   - ⚠️ 3个依赖链需验证兼容性

2. **`@ohos/lottie-turbo`** — 可靠性4/可用性5/创新性3
   - 3个Lottie JSON已就绪待渲染
   - 声明式LottieView，比@ohos/lottie更适配ArkUI
   - ⚠️ native .so需真机架构验证；5.0真机有Lottie播放问题报告

#### 第二优先级 — 推荐引入

3. **`@pura/harmony-utils`** — 可靠性5/可用性5/创新性1
   - 零依赖，V1.4.1，日期/加密/JSON/首选项/扫码

4. **`@pura/harmony-dialog`** — 可靠性4/可用性5/创新性1
   - 17种弹窗，一行代码调用

#### 第三优先级 — 需评估必要性

5. **`@ohos/mpchart`** — ⚠️ 稳定版近2年未更新。建议**先试原生DataPanel/Gauge**
6. **`@ohos/axios`** — 项目已有HttpClient.ets，替换涉及API契约边界（受保护）
7. **`@ohmos/calendar`** — 维护停滞，建议评估原生自实现
8. **`@ohos/imageknife`** — 项目图片量不大，可暂缓
9. **`@ohos/pulltorefresh`** — 列表场景不多，可暂缓

#### 免依赖竞赛加分项 — 立即可用（无需ohpm install）

| 能力 | API版本 | 创新性 | 鸿学伴场景 |
|------|---------|--------|-----------|
| **Particle粒子动画** | 12+ | 4/5 | 测验全对烟花、成就金粉 |
| springMotion弹簧物理 | 9+ | 3/5 | 卡片弹性交互 |
| geometryTransition一镜到底 | 11+ | 3/5 | 卡片展开详情 |
| DataPanel/Gauge数据展示 | 7+/8+ | 2/5 | Profile页学习进度 |

> **关键发现**：Profile.ets当前无任何数据可视化组件，连原生DataPanel/Gauge都未使用。建议优先用原生组件补强。

### Codex 需执行的真机验证

以下待办Trae无法完成（需真机/多设备）：

- [ ] `@ohos/lottie-turbo` 在真机安装并渲染3个Lottie JSON
- [ ] Core Vision Kit OCR 真机验证（不支持模拟器）
- [ ] Core Speech Kit TTS 真机验证
- [ ] distributedKVStore 跨设备同步验证（需多设备）
