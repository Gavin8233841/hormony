# 部署指南

## 环境要求

| 组件 | 版本要求 | 说明 |
|------|----------|------|
| Node.js | 22 LTS | 与容器运行时保持一致 |
| pnpm | 11.9.0 | 版本已锁定在 `package.json` |
| HarmonyOS SDK | >= 5.0 | DevEco Studio 内置 |

## 环境变量配置

在 `apps/web/` 目录下创建 `.env.local` 文件：

```bash
# 模型 API Key（真实 Agent 必填）
MODEL_API_KEY=your-api-key-here

# 模型 Base URL（可选，默认火山引擎）
MODEL_BASE_URL=https://ark.cn-beijing.volces.com/api/v3

# 模型名称（可选，默认 doubao-seed-2-1-pro-260628）
MODEL_NAME=doubao-seed-2-1-pro-260628

# 请求超时（Vercel Hobby 函数上限内保留收尾时间）
MODEL_TIMEOUT_MS=45000

# Vercel 仅运行无状态 Agent 网关，学习状态由 HarmonyOS ArkData 保存
DEPLOYMENT_MODE=stateless
APP_STATE_PERSISTENCE=off

# Web 跨域白名单；鸿蒙原生网络请求通常不携带 Origin
ORIGIN_ALLOWLIST=http://localhost:3000,http://10.0.2.2:3000
```

未配置 `MODEL_API_KEY` 时，健康检查和所有 AI 生成接口返回 `503 MODEL_UNAVAILABLE`。产品代码禁止使用规则文本或静态模板冒充 AI。

## 本地开发

### Web 端

```bash
cd apps/web
pnpm install --frozen-lockfile
pnpm dev
# 访问 http://localhost:3000
```

### 鸿蒙端

1. 打开 DevEco Studio
2. 导入 `apps/harmonyos` 目录
3. 等待项目同步完成
4. 连接模拟器或真机
5. 点击运行

### 修改后端 API 地址

鸿蒙端的 API 地址在 `apps/harmonyos/entry/src/main/ets/common/Constants.ets` 中配置：

```typescript
static readonly BASE_URL: string = 'http://10.0.2.2:3000';
```

## Vercel Hobby 部署

1. 将项目推送到私有 GitHub 仓库，在 Vercel 导入仓库并将 Root Directory 设为 `apps/web`。
2. 在 Vercel Project Settings 配置上述环境变量；密钥只粘贴到 Vercel，不进入文件。
3. 部署完成后访问 `/api/health`，必须返回 HTTP 200 且 `status` 为 `ready`。
4. 验证 `/api/chat` SSE、`/api/plan`、`/api/quiz` 与 `/api/knowledge/search`。
5. Vercel 部署模式关闭画像、计划保存、答题提交、会话和知识上传接口；这些状态由 HarmonyOS 本机负责。

Dockerfile 仅用于本地复现和备用部署，不是竞赛运行前提，也不需要持久卷。

### 更新鸿蒙端 API 地址

将 `Constants.ets` 中的 `BASE_URL` 改为 Vercel HTTPS 地址，然后重新构建 HAP：

```typescript
static readonly BASE_URL: string = 'https://<project>.vercel.app';
```

`10.0.2.2` 只适用于模拟器访问开发机，不能用于提交包或远程评审。

## API 端点清单

| 方法 | 路径 | 功能 |
|------|------|------|
| POST | /api/chat | SSE 流式对话 |
| GET | /api/courses | 只读课程列表 |
| POST | /api/knowledge/search | 知识检索 |
| POST | /api/knowledge/upload | Vercel 禁用 |
| GET | /api/model/status | 模型状态 |
| POST | /api/plan | 生成计划 |
| POST/PATCH | /api/plan/save | Vercel 禁用，本机 ArkData 负责 |
| GET/PUT | /api/profile | Vercel 禁用，本机 ArkData 负责 |
| POST | /api/quiz | 生成测验 |
| POST | /api/quiz/submit | Vercel 禁用，本机评分 |
| POST | /api/safety-review | 安全审核 |
| GET | /api/stats | Vercel 禁用，本机统计 |
| GET | /api/conversations | Vercel 禁用，本机会话 |
| GET | /api/health | 健康检查 |

## 安全配置

### 速率限制

中间件默认配置：
- 窗口：60 秒
- 最大请求：30 次/窗口/IP
- 超限返回 HTTP 429 + Retry-After 头

### 安全响应头

- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block
- Referrer-Policy: strict-origin-when-cross-origin
- Permissions-Policy: camera=(), microphone=(), geolocation=()

### 安全 Agent

所有 AI 输出经 5 层安全检查：
1. 敏感内容检测（暴力/色情/违法/自残/仇恨）
2. Prompt 注入检测
3. PII 泄露检测（手机号/身份证/邮箱）
4. 学术诚信检查
5. 反幻觉评估（无引用强论断检测）

## 构建验证

```bash
# TypeScript 类型检查
cd apps/web && pnpm typecheck

# Next.js 生产构建
cd apps/web && pnpm build

# 鸿蒙端构建
cd apps/harmonyos && hvigorw.bat assembleHap --no-daemon
```

## 架构概览

```
鸿学伴/
├── apps/
│   ├── harmonyos/          # 鸿蒙 ArkTS 客户端
│   │   └── entry/src/main/ets/
│   │       ├── pages/      # 7个页面(Index/Chat/Quiz/Course/Plan/Knowledge/Profile)
│   │       └── common/     # 公共组件和工具
│   └── web/                # Next.js Web 端 + API 服务
│       └── src/
│           ├── app/         # 7个页面 + 16个API路由 + 中间件
│           ├── lib/
│           │   ├── agents/  # 7个Agent(Profile/Retrieval/Tutor/Planner/Quiz/Evaluator/Safety)
│           │   ├── rag/     # TF-IDF 检索引擎
│           │   ├── store/   # 内存数据存储
│           │   └── types.ts # TypeScript 类型定义
│           └── middleware.ts # 安全中间件
└── docs/                    # 项目文档
```
