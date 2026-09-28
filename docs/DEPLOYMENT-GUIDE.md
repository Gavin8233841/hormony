# 部署与复现指南

## 环境要求

| 组件 | 当前要求 | 说明 |
|------|----------|------|
| Node.js | 安装与当前 Next.js 项目兼容的版本 | 仓库未在 `package.json` 固定 `engines` |
| pnpm | 11.9.0 | 锁定在 `apps/web/package.json` |
| HarmonyOS SDK | API 26 | 通过 DevEco Studio SDK Manager 安装 |

## 环境变量配置

在 `apps/web/` 目录下参考 `.env.example` 创建未提交的 `.env.local` 文件。以下仅为字段示例，不要将真实密钥写入源码或提交包：

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

未配置可用模型凭据时，不能把 AI 接口错误当成模型成功；应逐项检查 HTTP 状态及业务响应。产品代码不得以静态模板冒充 AI。

## 本地开发

### Web 端

```bash
cd apps/web
pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm test
pnpm build
pnpm dev
# 访问 http://localhost:3000
```

### 鸿蒙端

1. 打开 DevEco Studio
2. 导入 `apps/harmonyos` 目录
3. 等待项目同步完成
4. 连接 API 26 模拟器并运行。真机运行需另行验证

### 当前后端 API 地址

鸿蒙端的 API 地址在 `apps/harmonyos/entry/src/main/ets/common/Constants.ets` 中配置：

```typescript
static readonly BASE_URL: string = 'https://hormony-ruddy.vercel.app';
static readonly SIMULATOR_GATEWAY_URL: string = 'http://10.0.2.2:3001';
```

`HttpClient.ets` 按 `API_BASE_URLS` 尝试请求。当前模拟器演示走宿主网关回退，不能据此认定 HAP 直连公网。需要本机网关时，在仓库根目录运行 `NODE_USE_ENV_PROXY=1 node scripts/simulator-api-gateway.mjs`；网关仅代理 `/api/`。

## Vercel Hobby 部署

1. 在 Vercel 导入仓库并将 Root Directory 设为 `apps/web`。
2. 在 Vercel Project Settings 配置上述环境变量；密钥只粘贴到 Vercel，不进入文件。
3. 部署完成后检查 `/api/health` 的 HTTP 状态、`status`、模型和部署版本。
4. 分别验证 `/api/chat` SSE、`/api/plan`、`/api/quiz` 与 `/api/knowledge/search` 的业务字段。
5. Vercel 部署模式关闭画像、计划保存、答题提交、会话和知识上传接口；这些状态由 HarmonyOS 本机负责。

Dockerfile 仅用于本地复现和备用部署，不是竞赛运行前提，也不需要持久卷。

### 更新鸿蒙端 API 地址

如果部署地址变更，修改 `Constants.ets` 中的 `BASE_URL` 后重建 HAP，逐项验证新服务及客户端实际链路。`10.0.2.2` 只适用于模拟器访问开发机，不能作为远程设备的服务地址。

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

### 安全处理

用户输入和模型输出的安全处理以 `apps/web/src/lib/agents/` 当前实现及对应测试为准；不能以本页的分类描述代替具体检测或线上验证。

## 构建验证

```bash
# TypeScript 类型检查
cd apps/web && pnpm typecheck

# Next.js 生产构建
cd apps/web && pnpm build

# 鸿蒙端构建：在 DevEco Studio 打开整个 apps/harmonyos 工程，
# 按本机 SDK 与调试签名配置构建 entry@default。
```

## 架构概览

```
鸿学伴/
├── apps/
│   ├── harmonyos/          # 鸿蒙 ArkTS 客户端
│   │   └── entry/src/main/ets/
│   │       ├── pages/      # 学习、课程、测验、错题等原生页面
│   │       └── common/     # 公共组件和工具
│   └── web/                # Next.js Web 端 + API 服务
│       └── src/
│           ├── app/         # Web 页面与 API 路由
│           ├── lib/
│           │   ├── agents/  # 7个Agent(Profile/Retrieval/Tutor/Planner/Quiz/Evaluator/Safety)
│           │   ├── rag/     # TF-IDF 检索引擎
│           │   ├── store/   # Web 内部数据结构；端侧学习状态以 ArkData 为准
│           │   └── types.ts # TypeScript 类型定义
│           └── middleware.ts # 安全中间件
└── docs/                    # 项目文档
```
