# 鸿学伴 · 智能学习助理

> C4-AI 鸿蒙高校创新赛 · 智能辅导方向

基于多智能体协作架构的校园学习助理，提供 AI 对话辅导、智能测验、学习计划、知识检索、个性化画像等全流程学习支持。

## 项目架构

```
鸿学伴/
├── apps/
│   ├── harmonyos/              # 鸿蒙 ArkTS 客户端（竞赛交付物）
│   │   └── entry/src/main/ets/
│   │       ├── pages/          # 7 个页面
│   │       │   ├── Index.ets   # 学习仪表盘
│   │       │   ├── Chat.ets    # AI 对话辅导
│   │       │   ├── Quiz.ets    # 智能测验
│   │       │   ├── Course.ets  # 课程管理
│   │       │   ├── Plan.ets    # 学习计划
│   │       │   ├── Knowledge.ets # 知识库
│   │       │   └── Profile.ets # 个人画像
│   │       └── common/         # 公共组件与工具
│   │
│   └── web/                    # Next.js Web 端 + API 服务
│       └── src/
│           ├── app/            # 7 个页面 + 16 个 API 路由
│           ├── lib/
│           │   ├── agents/     # 7 个智能体
│           │   ├── rag/        # TF-IDF 检索引擎
│           │   ├── store/      # 内存数据存储
│           │   └── types.ts    # TypeScript 类型定义
│           └── middleware.ts   # 安全中间件
│
└── docs/                       # 项目文档
    ├── API-REFERENCE.md        # API 参考文档
    ├── DEPLOYMENT-GUIDE.md     # 部署指南
    ├── INTEGRATED-WORKFLOW-SPEC.md # 集成工作流规范
    ├── PROJECT-HANDOVER.md     # 项目交接文档
    ├── COMPETITOR-ANALYSIS.md  # 竞品分析
    ├── HARMONY-COMPONENTS-DESIGN.md # 组件设计
    ├── ARKTS-ERROR-FIX-INDEX.md # ArkTS 错误修复索引
    ├── ARKUI-BEST-PRACTICES.md # ArkUI 最佳实践
    └── ROUTER-MIGRATION-GUIDE.md # 路由迁移指南
```

## 核心功能

| 功能 | 描述 | 技术实现 |
|------|------|----------|
| AI 对话辅导 | 流式对话，带资料引用 | SSE + 7 Agent 编排 |
| 智能测验 | 自动出题、即时评分、错题诊断 | Quiz + Evaluator Agent |
| 学习计划 | 目标拆解为每日任务，支持打卡 | Planner Agent + 任务管理 |
| 知识检索 | TF-IDF 语义匹配，相关度排序 | 中文双字分词 + 余弦相似度 |
| 知识上传 | 文本自动分块存入知识库 | 动态分块 + RAG 索引 |
| 个人画像 | 学习数据画像，支持编辑 | Profile Agent + 标签管理 |
| 仪表盘 | 统计聚合、活动时间线、进度追踪 | Stats API + 实时数据 |
| 安全审核 | 5 层内容安全检测 | Safety Agent + 中间件 |

## 多智能体架构

```
用户请求 → 编排器(Orchestrator)
              ├→ Profile Agent    (用户画像加载)
              ├→ Retrieval Agent  (知识库检索)
              ├→ Tutor Agent      (对话辅导)     ← 按意图路由
              ├→ Planner Agent    (计划生成)     ← 按意图路由
              ├→ Quiz Agent       (自动出题)     ← 按意图路由
              ├→ Evaluator Agent  (错题诊断)     ← 按意图路由
              └→ Safety Agent     (安全审核)     ← 始终执行
```

每个 Agent 调用独立 try-catch，单个 Agent 失败不阻断整体流程。

## 技术栈

- **鸿蒙端**: ArkTS / ArkUI / Stage 模型 / Navigation 路由
- **Web 端**: Next.js 14 / React 18 / TypeScript / Tailwind CSS
- **AI 模型**: OpenAI 兼容接口（火山引擎豆包 / 可配置）
- **检索引擎**: TF-IDF + 中文双字分词 + 余弦相似度（零依赖）
- **安全**: 速率限制 + 安全头 + CORS + 5 层内容审核

## 快速开始

```bash
# Web 端
cd apps/web
npm install
npm run dev    # http://localhost:3000

# 鸿蒙端
# 用 DevEco Studio 打开 apps/harmonyos 目录
```

详细部署请参阅 [部署指南](docs/DEPLOYMENT-GUIDE.md)。

## API 端点

共 16 个 API 端点，详见 [API 参考文档](docs/API-REFERENCE.md)。

## 开发日志

详见 [DEVLOG.md](DEVLOG.md)，记录所有开发过程和决策。

## 许可

竞赛项目，仅用于 C4-AI 鸿蒙高校创新赛。
