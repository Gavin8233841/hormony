# HarmonyOS 客户端（ArkTS / Stage 模型）

当前 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 HarmonyOS API 26。

## 打开与构建

1. 在 DevEco Studio 的 SDK Manager 安装 API 26 SDK。
2. 用 DevEco Studio 打开**整个** `apps/harmonyos/` 工程，等待项目同步。
3. 配置本机调试签名并构建 `entry@default`；交付构建使用与提交版本对应的签名配置。

请保留工程中的 `build-profile.json5`、`entry/src/main/module.json5`、资源、服务卡片与 AgentExtension 配置。仅复制 `ets/` 源码到新建工程无法复现这些入口。

## 主要入口

| 文件或目录 | 用途 |
|------------|------|
| `entry/src/main/ets/pages/` | 首页、课程、计划、对话、测验和错题等页面 |
| `entry/src/main/ets/common/LocalLearningRepository.ets` | 端侧学习状态持久化 |
| `entry/src/main/ets/common/HttpClient.ets` | 云端 API 请求和地址回退 |
| `entry/src/main/ets/entryformability/EntryFormAbility.ets` | 桌面服务卡片 |
| `entry/src/main/ets/agentability/XiaoyiAgentAbility.ets` | 小艺 AgentExtension 入口 |

## API 地址

`entry/src/main/ets/common/Constants.ets` 中的 `BASE_URL` 指向 `https://hormony-ruddy.vercel.app`。`LOCAL_GATEWAY_URL` 为本地开发网关回退地址 `http://10.0.2.2:3001`，对应仓库根目录的 `scripts/local-api-gateway.mjs`。部署到独立网络环境时，应将服务地址配置为可访问的 HTTPS API，并在端侧完成接口验收。
