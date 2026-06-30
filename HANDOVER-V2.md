# 鸿学伴项目接力交接文档 V2

> **交接时间**: 2026-06-30 14:30 CST
> **上一接力**: Claude (TRAE Work, 25轮) → Codex (4次提交)
> **当前接力**: → 新线程
> **Git HEAD**: `60d17b4` — "feat: 完善端侧学习闭环与交互体验"
> **项目状态**: 功能完整，70/70测试通过，模拟器全流程验证通过

---

## 一、项目当前状态

### 1.1 Git 历史（最近10次提交）

```
60d17b4  06-30 13:07  feat: 完善端侧学习闭环与交互体验          ← Codex 最终提交
7f5ff0b  06-30 02:33  feat: 重构鸿学伴原生端侧体验              ← Codex 大重构
a33a3fe  06-28 02:13  chore: 接入端侧设计审查资源               ← Codex
296968b  06-28 01:47  fix: 加固端侧流式对话与检索缓存           ← Codex
f85fff8  06-28 00:49  docs: DEVLOG更新 - 创建Codex接力交接文档   ← Claude
b43f74d  06-28 00:48  docs: 创建Codex接力交接文档               ← Claude
3de17a7  06-28 00:40  docs: DEVLOG更新 - Loop 23-25             ← Claude
73fe5d2  06-28 00:33  docs: 更新验收备注                        ← Claude
f339bb2  06-28 00:32  fix: HttpClient显式catch错误处理          ← Claude
9a6e5d0  06-28 00:24  refactor: 消除deprecated API警告          ← Claude
```

### 1.2 未跟踪文件（不在Git中）

```
harmonyos-tools-survey/          # 鸿蒙开发工具调研HTML（参考用）
ponytail-codex-deploy-prompt.md  # Ponytail技能部署到Codex的提示词
```

### 1.3 关键指标

| 指标 | 数值 |
|------|------|
| Git tracked 文件 | 275 |
| 鸿蒙 ETS 文件 | 12 (含新增 HomeContent.ets) |
| 后端 TS 文件 | 34 (含新增 request-validation.test.ts) |
| API 端点 | 19 |
| 单元测试 | 70 (全部通过) |
| Git commits | 40+ |

---

## 二、Codex 做了什么（4次提交，06-28 至 06-30）

### 2.1 架构重构

**核心变化：从多页面路由改为四入口底栏架构**

- `main_pages.json` 只保留 3 个路由：`Index`、`Plan`、`Knowledge`
- Chat、Course、Profile 不再是独立路由页面，改为 Index 内的 tab 切换组件
- Index.ets 作为主框架，通过 `@State currentIndex` 控制四个 tab：今日(0)、课程(1)、学伴(2)、我的(3)
- 底栏使用浮动设计：90% 宽度、72vp 高度、玻璃模糊、圆角 20vp

**新增文件**:
- `HomeContent.ets` (455行) — 首页内容组件，包含品牌头部、当前课程、今日计划、快速提问
- `request-validation.test.ts` — API 参数校验测试

**页面导出方式变化**:
- Chat.ets 导出 `ChatContent` 组件（不再 @Entry）
- Course.ets 导出 `CourseContent` 组件（不再 @Entry）
- Profile.ets 导出 `ProfileContent` 组件（不再 @Entry）
- Plan.ets 和 Knowledge.ets 仍保留 @Entry（因为是独立路由页面）

### 2.2 设计系统更新

**新增 `DESIGN.md`** — Codex 建立的端侧设计规范：
- 页面背景从 `#f5f6f8` 改为 `#f4f7fc`
- 品牌色从 `#0a59f7` 改为 `#176bff`
- 主文字色从 `#1f2937` 改为 `#111827`
- 圆角体系：8/12/16/20vp
- 动画时长：160ms(快)/220ms(标准)，移除了弹跳动画
- 阴影体系：低强度阴影 + 玻璃模糊仅用于底栏
- 字体层级明确：32fp品牌标题 / 21-26fp内容标题 / 15-18fp卡片标题 / 11-15fp正文

**Constants.ets 更新**:
- 新增：`COLOR_BG_SKELETON`、`COLOR_BORDER`、`COLOR_SURFACE_TINT`、`COLOR_NAV_SURFACE`、`COLOR_NAV_INACTIVE`、`COLOR_BRAND_LIGHT`、`COLOR_ERROR_LIGHT`、`SHADOW_CARD_LG`、`SHADOW_BRAND`、`ANIM_FAST`、`RADIUS_XL`
- 品牌色变更：`#0a59f7` → `#176bff`
- 动画时长变更：`ANIM_NORMAL` 从 300ms 改为 220ms

### 2.3 功能完善

- **课程页**：3门离线演示课程、骨架加载、空/错状态、进度条统一品牌蓝
- **知识库**：课程上下文传递（AppStorage）、建议词、结果骨架、全文展开/收起、移除重复成功提示
- **学习计划**：7/14/21天分段选择替代自由输入、目标建议、生成中状态、任务骨架、中文任务类型
- **学习画像**：三张统计卡合并为单一指标面板、薄弱+已掌握合并、移除无操作按压反馈、支持滚动
- **学伴**：推荐问题改用标准Button、思考状态收口到回答气泡、失败重试、引用展开/收起
- **首页**：品牌头部+今日提示+头像+通知、当前课程+继续学习、今日计划+任务状态、快速提问

### 2.4 后端加固

- `/api/chat` 拒绝仅含空白字符的消息
- `/api/plan` 拒绝缺失或空白目标
- 新增 `request-validation.test.ts`（2个测试），测试从 68 增加到 70

### 2.5 性能优化

- SSE 自动滚动增加调度锁，合并高频分片
- List cachedCount 按实际数据量收敛
- 加载态使用固定尺寸骨架，减少布局跳变
- 清理未使用的 StatCard、旧渐变色、失效令牌

---

## 三、完整文件清单

### 3.1 鸿蒙端 ETS 文件（12个）

| 文件 | 行数 | 职责 |
|------|------|------|
| `Constants.ets` | 82 | 全局常量（颜色/动画/圆角/API/日志） |
| `Builders.ets` | 113 | 共享@Builder（GradientHeader/EmptyState/LoadingState/Skeleton） |
| `HttpClient.ets` | 150 | HTTP客户端（GET/POST/SSE流式） |
| `DataModels.ets` | 100 | 数据模型接口 |
| `EntryAbility.ets` | 42 | 应用入口 |
| `Index.ets` | 121 | 主框架（四入口底栏 + tab切换 + 转场动画） |
| `HomeContent.ets` | 455 | 首页内容（品牌头部/课程/计划/快速提问） |
| `Chat.ets` | 423 | AI辅导（SSE流式/推荐问题/引用展开/重试） |
| `Course.ets` | 235 | 课程列表（进度条/知识点标签/骨架/空错态） |
| `Plan.ets` | 306 | 学习计划（分段选择/目标建议/任务骨架/中文标签） |
| `Knowledge.ets` | 290 | 知识库检索（课程上下文/建议词/展开收起/骨架） |
| `Profile.ets` | 223 | 学习画像（指标面板/知识点合并/滚动） |

### 3.2 后端结构

```
apps/web/src/
├── app/
│   ├── api/                    # 19个API端点
│   │   ├── chat/route.ts       # SSE流式对话
│   │   ├── plan/route.ts       # 学习计划（含参数校验）
│   │   ├── profile/route.ts    # 用户画像
│   │   ├── profile/update/route.ts
│   │   ├── courses/route.ts    # 课程列表
│   │   ├── quiz/route.ts       # 测验
│   │   ├── quiz/submit/route.ts
│   │   ├── knowledge/search/route.ts  # RAG检索
│   │   ├── knowledge/upload/route.ts
│   │   ├── safety-review/route.ts
│   │   ├── health/route.ts
│   │   ├── stats/route.ts
│   │   ├── conversations/route.ts
│   │   ├── model/status/route.ts
│   │   └── request-validation.test.ts # 新增：参数校验测试
│   └── (7个Web页面)
├── lib/
│   ├── agents/                 # 7个Agent
│   │   ├── orchestrator.ts     # 编排器（5个辅助函数）
│   │   ├── tutor-agent.ts      # 主辅导
│   │   ├── plan-agent.ts       # 计划生成
│   │   ├── quiz-agent.ts       # 测验生成
│   │   ├── evaluate-agent.ts   # 意图识别
│   │   ├── safety-agent.ts     # 安全检测（5层）
│   │   ├── retrieval-agent.ts  # RAG检索
│   │   └── profile-agent.ts    # 画像管理
│   ├── rag/index.ts            # TF-IDF + FIFO缓存
│   ├── store/db.ts             # 内存存储
│   └── utils.ts                # 工具函数
└── middleware.ts               # CORS白名单
```

### 3.3 测试文件（5个，70个测试）

| 文件 | 测试数 |
|------|--------|
| `utils.test.ts` | 17 |
| `db.test.ts` | 17 |
| `rag/index.test.ts` | 15 |
| `safety-agent.test.ts` | 19 |
| `request-validation.test.ts` | 2 |

---

## 四、开发环境与工具链

### 4.1 DevEco Studio

**安装路径**: `C:\Program Files\Huawei\DevEco Studio\`

**关键工具路径**:
| 工具 | 路径 |
|------|------|
| hvigorw.js | `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js` |
| hdc.exe | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe` |
| Node.js | `C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe` |

### 4.2 模拟器

- **设备名**: `Pura 90 Pro Max`
- **连接地址**: `127.0.0.1:5555`
- **分辨率**: 1256 x 2760

### 4.3 DevEco MCP 工具（11个）

> 已完成实名认证，MCP工具挂载在DevEco Studio中可用。

| 工具 | 功能 |
|------|------|
| `mcp_deveco-mcp_build_project` | 构建HAP |
| `mcp_deveco-mcp_start_app` | 安装+启动应用 |
| `mcp_deveco-mcp_check_ets_files` | ETS语法检查 |
| `mcp_deveco-mcp_perform_ui_action` | UI操作(click/screenshot/inputText/keyEvent) |
| `mcp_deveco-mcp_get_app_ui_tree` | 获取UI树(simple/full) |
| `mcp_deveco-mcp_get_hilog_or_faultlog_recent` | 日志监控 |
| `mcp_deveco-mcp_harmonyos_knowledge_search` | 知识库搜索 |
| `mcp_deveco-mcp_project_sync` | 项目同步 |

**注意事项**:
- 必须传 `hvd: "Pura 90 Pro Max"` 参数
- `harmonyos_knowledge_search` 可能返回空（服务端无匹配，非认证错误）
- 偶发 `REQUEST_TIMEOUT`，重试即可
- `perform_ui_action` 的 `inputText` 不触发 ArkUI `onChange`（UI自动化已知限制）

### 4.4 CLI 命令速查

```powershell
# 构建鸿蒙应用
cd C:\Users\guo82\Desktop\Hormony\apps\harmonyos
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --no-daemon

# 安装+启动
$hdc = "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
& $hdc -t 127.0.0.1:5555 install "C:\Users\guo82\Desktop\Hormony\apps\harmonyos\entry\build\default\outputs\default\entry-default-unsigned.hap"
& $hdc -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.c4ai.hormony

# 截图
& $hdc -t 127.0.0.1:5555 shell snapshot_display -f /data/local/tmp/shot.jpeg
& $hdc -t 127.0.0.1:5555 file recv /data/local/tmp/shot.jpeg "C:\Users\guo82\Desktop\Hormony\screenshots\shot.jpeg"

# 后端测试+类型检查
cd C:\Users\guo82\Desktop\Hormony\apps\web
npx vitest run          # 70/70
npx tsc --noEmit --project tsconfig.typecheck.json  # 0 errors

# 后端开发服务器
pnpm dev                # http://localhost:3000
```

### 4.5 子Agent CLI并行工作流

> 主线程专注代码编辑和MCP UI操作，子Agent通过CLI处理耗时任务

```
主线程                          子Agent (CLI)
──────                          ────────────
代码编辑         ←并行→         Build Agent: hvigorw + hdc + 截图
MCP ETS检查      ←并行→         Backend Agent: vitest + tsc
MCP UI操作                      Research Agent: HarmonyOS API研究
```

通过 Task 工具启动子Agent：
- `subagent_type: "general_purpose_task"` — 执行CLI命令
- `subagent_type: "Explore"` — 只读研究（最多同时3个）

---

## 五、设计系统规范

### 5.1 颜色（Constants.ets 收口，禁止页面内硬编码）

```
品牌蓝: #176bff        成功: #2fb86b      警告: #f59e0b      错误: #e5484d
页面背景: #f4f7fc       卡片背景: #ffffff   边框: #e5ebf4
主文字: #111827        次文字: #6f7a8f     占位符: #a7b0c2
品牌浅底: #eaf2ff       成功浅底: #eaf8ef   错误浅底: #fff0f1
禁用态: #e8edf5(底) / #98a3b5(文字)
导航未选: #778197       导航背景: #f2ffffff(半透明白)
骨架: #e7edf6
阴影: #120f2748(普通) / #1a0f2748(大) / #35176bff(品牌)
```

### 5.2 圆角与动画

```
圆角: 8(SM) / 12(MD) / 16(LG) / 20(XL)
动画: 160ms(FAST) / 220ms(NORMAL)
```

### 5.3 共享组件（Builders.ets）

- `GradientHeader(title, subtitle, onBack)` — 渐变标题栏（Plan/Knowledge用）
- `EmptyState(message)` — 空状态
- `LoadingState()` — 加载状态
- `Skeleton(width, height)` — 骨架屏

### 5.4 页面结构

```
Index.ets (主框架)
├── HomeContent (tab 0 - 今日)
│   ├── 品牌头部 + 今日提示 + 头像 + 通知
│   ├── 当前课程 + 继续学习
│   ├── 今日计划 + 任务状态
│   └── 快速提问
├── CourseContent (tab 1 - 课程)
├── ChatContent (tab 2 - 学伴)
└── ProfileContent (tab 3 - 我的)

独立路由页面 (从首页进入):
├── Plan.ets (学习计划)
└── Knowledge.ets (课程资料检索)
```

---

## 六、API 路由

**后端地址**: `http://10.0.2.2:3000`（模拟器访问宿主机）
**调试模式**: `Constants.__DEBUG__ = true`（网络失败回退演示数据）

| API路径 | 方法 | 用途 | 参数校验 |
|---------|------|------|---------|
| `/api/chat` | POST | SSE流式对话 | 拒绝空白消息 |
| `/api/profile` | GET | 用户画像 | - |
| `/api/profile/update` | POST | 更新画像 | - |
| `/api/courses` | GET | 课程列表 | - |
| `/api/plan` | GET/POST | 学习计划 | 拒绝空白目标 |
| `/api/plan/save` | POST | 保存计划 | - |
| `/api/quiz` | GET | 测验列表 | - |
| `/api/quiz/submit` | POST | 提交测验 | - |
| `/api/knowledge/search` | POST | 知识库检索 | - |
| `/api/knowledge/upload` | POST | 上传知识 | - |
| `/api/safety-review` | POST | 安全审查 | - |
| `/api/health` | GET | 健康检查 | - |
| `/api/stats` | GET | 统计数据 | - |
| `/api/conversations` | GET | 对话历史 | - |
| `/api/model/status` | GET | 模型状态 | - |

---

## 七、安全机制

- **CORS**: 白名单制（`localhost:3000` + `10.0.2.2:3000`，通过 `ORIGIN_ALLOWLIST` 环境变量）
- **userId**: 正则 `^[a-zA-Z0-9_]+$`，长度 1-50，空值回退 `demo`
- **Safety Agent**: 5层检测（输入注入/PII/有害内容/角色/输出审查）
- **SSE错误**: 首事件前抛错返回 HTTP 500
- **API try-catch**: quiz/submit + knowledge/upload 顶层异常捕获

---

## 八、已知技术债

### 8.1 可接受的警告

1. **HttpClient.ets "Function may throw exceptions"**（2处）— ArkTS编译器对 `httpRequest.request()` 的固定顾问性警告，已有try-catch
2. **签名配置 "No signingConfigs"** — 使用unsigned HAP，竞赛提交时可能需要配置签名

### 8.2 潜在优化方向

1. **API响应格式统一** — 当前各路由格式不完全统一，统一需改13路由+前端页面，风险高
2. **Navigation框架迁移** — 当前用 UIContext.getRouter()，华为长期推荐 Navigation+NavPathStack
3. **数据库持久化** — 当前内存存储，重启丢失
4. **更多知识库内容** — 当前5条演示数据
5. **Rate Limiting优化** — 当前按路径隔离导致实际限额放大
6. **真机测试** — 需修改 BASE_URL 为局域网IP

### 8.3 环境注意事项

- PowerShell中文命令必须UTF-8编码
- MCP工具调用必须传 `hvd: "Pura 90 Pro Max"`
- UI树坐标可能与CLI uitest坐标不同，用MCP `get_app_ui_tree` 获取准确坐标
- 禁止批量/递归/通配符删除文件
- 不得回滚/覆盖用户未提交修改

---

## 九、用户偏好与硬约束

### 9.1 硬约束

1. 代码必须用 `deveco run` 或等价方式审查 — 构建后必须运行验证
2. 编译错误对照 arkts-error-fixes 指南
3. ArkUI代码参考 Skill 文档
4. UI文案禁止暴露技术术语（Agent/RAG/Retrieval等）
5. 每次节点进展更新 DEVLOG.md
6. 时间戳取自真实系统时间（读末尾→取真实时间→比对递增）
7. 已提交的错位条目不得原地修改，末尾新增勘误
8. 颜色全部收口 Constants.ets，禁止页面内硬编码

### 9.2 设计偏好

- 专业、流畅、舒适，高端简洁，不花哨
- 最多4模块每页，最少交互按钮，清晰导航
- 禁用不可用按钮（灰色）
- 用户语言非开发者语言
- 背景适度美化，更多动画但不拖慢性能
- 按压反馈只用于真实可点击控件，静态信息不伪装按钮

### 9.3 工作流偏好

- 使用子Agent并行减轻主线程压力
- 开发前深入研究（竞品+开源+权威文档）
- 充分整合 DevEco Code + DevEco MCP 组合工作流
- 完成任务后收口未提交改动
- 不留废弃产物

---

## 十、快速启动指南

### 10.1 环境检查（3分钟）

```powershell
cd C:\Users\guo82\Desktop\Hormony
git status                    # 确认工作区状态
git log --oneline -5          # 确认 HEAD = 60d17b4

# 检查模拟器
& "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" list targets
# 期望: 127.0.0.1:5555

# 检查后端
cd C:\Users\guo82\Desktop\Hormony\apps\web
npx vitest run                # 期望: 70/70 passed
npx tsc --noEmit --project tsconfig.typecheck.json  # 期望: 0 errors
```

### 10.2 构建并运行（3分钟）

```powershell
# 方法A: MCP工具（推荐）
# mcp_deveco-mcp_build_project → mcp_deveco-mcp_start_app

# 方法B: CLI
cd C:\Users\guo82\Desktop\Hormony\apps\harmonyos
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --no-daemon

$hdc = "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
& $hdc -t 127.0.0.1:5555 install "C:\Users\guo82\Desktop\Hormony\apps\harmonyos\entry\build\default\outputs\default\entry-default-unsigned.hap"
& $hdc -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.c4ai.hormony
```

### 10.3 后端服务器（端到端测试时需要）

```powershell
cd C:\Users\guo82\Desktop\Hormony\apps\web
pnpm dev    # http://localhost:3000，模拟器通过 http://10.0.2.2:3000 访问
```

### 10.4 UI验证

```powershell
# 用MCP工具截图和点击（推荐，坐标更准确）
# mcp_deveco-mcp_get_app_ui_tree mode="simple" → 获取坐标
# mcp_deveco-mcp_perform_ui_action actionType="click" x=... y=...
# mcp_deveco-mcp_perform_ui_action actionType="screenshot"
```

---

## 十一、关键文件索引

| 文件 | 用途 |
|------|------|
| `DEVLOG.md` | 完整开发日志（Claude 25轮 + Codex 4次提交） |
| `DESIGN.md` | Codex 建立的端侧设计规范 |
| `HANDOVER-FOR-CODEX.md` | Claude→Codex 交接文档（12章节，历史参考） |
| `HANDOVER-V2.md` | 本文件 |
| `.trae/loop_config.json` | Loop Engineering 配置 |
| `.trae/progress.json` | 25轮循环记录 |
| `apps/harmonyos/build-profile.json5` | 鸿蒙构建配置 |
| `apps/harmonyos/entry/src/main/resources/base/profile/main_pages.json` | 路由注册（仅3页） |
| `apps/web/package.json` | 后端依赖 |
| `apps/web/.env.example` | 环境变量（含 ORIGIN_ALLOWLIST） |
| `ponytail-codex-deploy-prompt.md` | Ponytail技能部署提示词（未跟踪） |

---

## 十二、推荐下一步方向

### 高优先级 — 竞赛准备
1. 竞赛材料整理（项目介绍/PPT/演示视频/技术方案）
2. 签名配置（如竞赛需要正式签名HAP）
3. 真机测试（修改BASE_URL为局域网IP）

### 中优先级 — UI增强
1. 骨架屏 shimmer 动画效果
2. Chat 打字机效果优化
3. 暗色主题支持
4. 消息长按复制

### 低优先级 — 后端增强
1. API响应格式统一
2. 数据库持久化
3. 更多知识库内容
4. Rate Limiting优化

---

*本文档由 Claude (TRAE Work) 在 Codex 完成4次提交后整理，确保新线程可以零摩擦接力。*
