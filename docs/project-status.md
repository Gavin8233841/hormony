# 项目结构与状态总览

> 更新时间：2026-06-24

## 目录结构

```
Hormony/
├── .gitignore
├── README.md
├── docs/
│   ├── official/                    # 官方附件（待登录下载）
│   ├── notes/
│   │   ├── competition-summary.md   # 竞赛规则摘要
│   │   └── env-setup.md             # 环境配置记录
│   ├── architecture.md              # 技术架构
│   └── api-spec.md                  # 接口规范
├── apps/
│   ├── web/                         # Next.js AI Agent 后端 + Web 原型 ✅
│   │   ├── src/
│   │   │   ├── app/
│   │   │   │   ├── api/             # 6 个 API 路由
│   │   │   │   │   ├── chat/        # SSE 流式对话
│   │   │   │   │   ├── profile/     # 用户画像
│   │   │   │   │   ├── courses/     # 课程列表
│   │   │   │   │   ├── plan/        # 学习计划
│   │   │   │   │   ├── quiz/        # 测验出题
│   │   │   │   │   └── safety-review/ # 安全审核
│   │   │   │   ├── chat/            # 对话页
│   │   │   │   ├── courses/         # 课程页
│   │   │   │   ├── plan/            # 学习计划页
│   │   │   │   ├── knowledge/       # 知识库页
│   │   │   │   ├── profile/         # 个人画像页
│   │   │   │   ├── layout.tsx       # 全局布局（侧边栏导航）
│   │   │   │   ├── page.tsx         # 仪表盘首页
│   │   │   │   └── globals.css      # 全局样式
│   │   │   └── lib/
│   │   │       ├── agents/          # 7 个 Agent + 编排器
│   │   │       │   ├── orchestrator.ts
│   │   │       │   ├── model.ts     # 模型客户端（含演示回退）
│   │   │       │   ├── profile-agent.ts
│   │   │       │   ├── retrieval-agent.ts
│   │   │       │   ├── planner-agent.ts
│   │   │       │   ├── tutor-agent.ts
│   │   │       │   ├── quiz-agent.ts
│   │   │       │   ├── evaluator-agent.ts
│   │   │       │   └── safety-agent.ts
│   │   │       ├── rag/             # 简化版 RAG 检索
│   │   │       ├── store/           # 内存数据存储（globalThis 单例）
│   │   │       ├── types.ts         # 共享类型
│   │   │       └── utils.ts         # 工具函数
│   │   ├── .env.example             # 环境变量模板
│   │   ├── .npmrc                   # npmmirror 镜像
│   │   └── package.json
│   └── harmonyos/                   # ArkTS 鸿蒙端骨架 ✅
│       ├── AppScope/app.json5
│       ├── entry/src/main/
│       │   ├── ets/
│       │   │   ├── entryability/EntryAbility.ets
│       │   │   ├── pages/            # 6 个 ArkTS 页面
│       │   │   │   ├── Index.ets     # 仪表盘
│       │   │   │   ├── Chat.ets      # SSE 对话
│       │   │   │   ├── Course.ets
│       │   │   │   ├── Plan.ets
│       │   │   │   ├── Knowledge.ets
│       │   │   │   └── Profile.ets
│       │   │   ├── common/           # HttpClient + Constants
│       │   │   └── model/            # 数据模型
│       │   ├── resources/            # 字符串/颜色/路由资源
│       │   └── module.json5
│       └── README.md                 # 鸿蒙端使用说明
├── packages/                        # 共享代码（待用）
└── scripts/
    └── test-chat.mjs                # 对话接口测试脚本
```

## 完成状态

| 模块 | 状态 | 说明 |
|------|------|------|
| 环境检查 | ✅ | DevEco Studio 26.0 + SDK + 模拟器镜像 6.1.1 + ohpm + hdc + hvigor 全部就绪 |
| MCP 连接 | ✅ | DevEco MCP 配置已写入 ~/.workbuddy/mcp.json，待 Trust 启用 |
| 项目骨架 | ✅ | Git 仓库 + 目录结构 + 文档 |
| Web 后端 API | ✅ | 6 个路由，构建+类型检查通过 |
| 多 Agent 系统 | ✅ | 7 Agent + 编排器，SSE 流式输出 |
| RAG 检索 | ✅ | 三级回退（token→子串→关键词片段） |
| Web UI | ✅ | 6 个页面，暗色主题 |
| 鸿蒙端骨架 | ✅ | 6 个 ArkTS 页面 + HttpClient + 配置 |
| 官方附件 | ⏳ | 需登录茶思屋下载 |
| DevEco Studio | ✅ | 26.0.0.461 已安装 |
| 模型 API Key | ⏳ | 需配置到 .env.local |
| PPT/视频 | ⏳ | 待后续阶段 |

## 运行方式

### Web 后端
```bash
cd apps/web
cp .env.example .env.local   # 填入 MODEL_API_KEY（可选，不填走演示模式）
pnpm dev                     # http://localhost:3000
```

### 鸿蒙端
用 DevEco Studio 打开 `apps/harmonyos`，详见其 README.md
