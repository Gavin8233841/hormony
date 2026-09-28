# HarmonyOS 客户端（ArkTS / Stage 模型）

当前 `compatibleSdkVersion` 与 `targetSdkVersion` 均为 HarmonyOS API 26。

## 打开与构建

1. 在 DevEco Studio 的 SDK Manager 安装 API 26 SDK。
2. 用 DevEco Studio 打开**整个** `apps/harmonyos/` 工程，等待项目同步。
3. 按本机调试签名配置运行在 API 26 模拟器；发布包需单独配置并验证正式签名。

请保留工程中的 `build-profile.json5`、`entry/src/main/module.json5`、资源、服务卡片与 AgentExtension 配置。仅复制 `ets/` 源码到新建工程无法复现这些入口。

## 主要入口

| 文件或目录 | 用途 |
|------------|------|
| `entry/src/main/ets/pages/` | 首页、课程、计划、对话、测验和错题等页面 |
| `entry/src/main/ets/common/LocalLearningRepository.ets` | 端侧学习状态持久化 |
| `entry/src/main/ets/common/HttpClient.ets` | 云端 API 请求和地址回退 |
| `entry/src/main/ets/entryformability/EntryFormAbility.ets` | 桌面服务卡片 |
| `entry/src/main/ets/agentability/XiaoyiAgentAbility.ets` | 小艺 AgentExtension 入口 |

## API 地址与证据边界

`entry/src/main/ets/common/Constants.ets` 当前将 `BASE_URL` 设为 `https://hormony-ruddy.vercel.app`，并将 `http://10.0.2.2:3001` 作为模拟器宿主网关回退地址。宿主网关脚本为仓库根目录的 `scripts/simulator-api-gateway.mjs`；`10.0.2.2` 是模拟器访问宿主机的地址，不能作为远程设备的 API 地址。

已有模拟器演示证明通过宿主网关完成相应 API 流程，尚无 HAP 直连公网证据。服务卡片已在模拟器打开错题本；通知由用户点击后即时发布并可回流到错题本，尚无定时推送证据。小艺平台配置、端侧协议测试和合成云端 Tutor 请求均不证明小艺 App 到 AgentExtension 的真实调用。真机行为未验证。
