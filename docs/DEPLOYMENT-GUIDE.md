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
# 模型 API Key（必填，不填则自动进入演示模式）
MODEL_API_KEY=your-api-key-here

# 模型 Base URL（可选，默认火山引擎）
MODEL_BASE_URL=https://ark.cn-beijing.volces.com/api/v3

# 模型名称（可选，默认 doubao-seed-2-1-pro-260628）
MODEL_NAME=doubao-seed-2-1-pro-260628

# 请求超时（可选，默认 60000ms）
MODEL_TIMEOUT_MS=60000

# 运行状态持久化（本地默认写入 apps/web/.runtime）
APP_STATE_PERSISTENCE=on
# APP_STATE_FILE=C:/absolute/path/hongxueban-state.json

# Web 跨域白名单；鸿蒙原生网络请求通常不携带 Origin
ORIGIN_ALLOWLIST=http://localhost:3000,http://10.0.2.2:3000
```

### 演示模式

未配置 `MODEL_API_KEY` 时，系统自动进入演示模式：
- 基于关键词的规则应答
- 覆盖常见知识点（二叉搜索树、动态规划、进程调度、TCP 等）
- 所有 API 端点正常工作，仅 AI 生成内容降级

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

## 生产部署边界

当前服务会把计划、答题、画像和会话状态写入 JSON 文件，因此生产环境必须满足：

1. 公网 HTTPS，可被远程评审设备访问。
2. Node.js 长驻进程，支持 SSE 流式响应。
3. 挂载可写持久卷，容器重启后数据仍存在。
4. 通过平台密钥管理注入 `MODEL_API_KEY`，不得写入镜像或仓库。
5. 单实例运行。当前文件存储和内存限流不支持多实例并发写入。

Vercel 等无持久本地文件系统的 Serverless 平台不适合当前版本。若以后迁移到托管数据库和分布式限流，再重新评估。

standalone 输出只在 Docker 的 Linux 构建阶段启用。Windows 本地 `pnpm build` 使用普通 Next.js 产物，避免 pnpm 依赖追踪创建符号链接时受系统权限限制。

## Docker 部署

### 1. 构建镜像

```bash
cd apps/web
docker build -t hongxueban-web:latest .
```

### 2. 启动单实例服务

PowerShell 示例：

```powershell
docker run -d --name hongxueban-web `
  -p 3000:3000 `
  -v hongxueban-data:/data `
  -e MODEL_API_KEY=$env:MODEL_API_KEY `
  -e MODEL_BASE_URL=https://ark.cn-beijing.volces.com/api/v3 `
  -e MODEL_NAME=doubao-seed-2-1-pro-260628 `
  -e ORIGIN_ALLOWLIST=https://your-domain.example `
  hongxueban-web:latest
```

云平台还需配置 HTTPS 反向代理或平台域名，并把 `/api/health` 设为健康检查路径。

### 3. 验证服务

```bash
curl https://your-domain.example/api/health
```

必须确认返回 `status: "ok"`，再测试对话 SSE、计划保存和答题提交。重启容器后再次读取画像与计划，确认持久卷生效。

### 4. 更新鸿蒙端 API 地址

将 `Constants.ets` 中的 `BASE_URL` 改为实际 HTTPS 地址，然后重新构建 HAP：

```typescript
static readonly BASE_URL: string = 'https://your-domain.example';
```

`10.0.2.2` 只适用于模拟器访问开发机，不能用于提交包或远程评审。

## API 端点清单

| 方法 | 路径 | 功能 |
|------|------|------|
| POST | /api/chat | SSE 流式对话 |
| GET | /api/courses | 课程列表 |
| POST | /api/knowledge/search | 知识检索 |
| POST | /api/knowledge/upload | 知识上传 |
| GET | /api/model/status | 模型状态 |
| POST | /api/plan | 生成计划 |
| POST | /api/plan/save | 保存计划 |
| PATCH | /api/plan/save | 任务打卡 |
| GET | /api/profile | 获取画像 |
| PUT | /api/profile/update | 更新画像 |
| POST | /api/quiz | 生成测验 |
| POST | /api/quiz/submit | 提交测验 |
| POST | /api/safety-review | 安全审核 |
| GET | /api/stats | 仪表盘统计 |
| GET | /api/conversations | 会话历史 |
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
