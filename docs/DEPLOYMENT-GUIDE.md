# 部署指南

## 环境要求

| 组件 | 版本要求 | 说明 |
|------|----------|------|
| Node.js | >= 18.17 | Next.js 14 最低要求 |
| npm | >= 9 | 随 Node.js 安装 |
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
npm install
npm run dev
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
export const BASE_URL = 'http://10.0.2.2:3000'; // 模拟器访问宿主机
```

## 生产部署（Vercel）

### 1. 部署 Web 端

```bash
cd apps/web
vercel --prod
```

或在 Vercel 控制台导入 Git 仓库，设置：
- Root Directory: `apps/web`
- Framework Preset: Next.js
- Environment Variables: 配置 `MODEL_API_KEY` 等

### 2. 更新鸿蒙端 API 地址

将 `Constants.ets` 中的 `BASE_URL` 改为 Vercel 部署地址：

```typescript
export const BASE_URL = 'https://your-app.vercel.app';
```

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
cd apps/web && npx tsc --noEmit

# Next.js 生产构建
cd apps/web && npm run build

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
