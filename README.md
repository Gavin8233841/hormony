# 鸿学伴 · 智能学习助理

> C4-AI 鸿蒙高校创新赛 · 智能辅导方向

鸿学伴由 HarmonyOS 原生客户端和 Next.js 云端 API 组成。客户端提供课程、计划、测验、错题复习与对话辅导；学习状态保存在端侧 ArkData。云端提供无状态的模型调用、检索与 Agent 编排。

## 代码入口

| 目录 | 用途 |
|------|------|
| `apps/harmonyos/` | API 26 ArkTS / ArkUI 客户端、桌面服务卡片和 AgentExtension |
| `apps/web/` | Next.js Web 界面和云端 API |
| `apps/web/src/lib/agents/orchestrator.ts` | 按请求意图编排 Agent |
| `apps/web/src/lib/agents/model.ts` | 模型调用、超时与运行信息 |
| `docs/` | 接口、部署与竞赛交付资料 |

已提交错题的提问会进入画像、错题诊断与安全处理路径；其他请求由编排器按意图选择辅导、计划或测验等能力。服务端错误会作为错误返回，不以静态文本冒充模型结果。具体输入、输出与错误结构见 [API 参考文档](docs/API-REFERENCE.md)。

## 本地启动

```bash
cd apps/web
pnpm install --frozen-lockfile
pnpm dev
```

Web 开发地址为 `http://localhost:3000`。使用 DevEco Studio 打开整个 `apps/harmonyos/` 工程；当前目标 SDK 为 HarmonyOS API 26。完整配置和验证步骤见 [部署指南](docs/DEPLOYMENT-GUIDE.md) 与 [HarmonyOS 客户端说明](apps/harmonyos/README.md)。

## 验证范围

已有 Pura X View API 26 **模拟器**上的学习、测验、服务卡片和用户触发即时通知证据。模拟器 API 路径使用宿主网关回退；该记录不证明 HAP 直连公网。小艺平台配置、端侧 AgentExtension 源码和协议测试不等于小艺 App 真实会话。真机、小艺 App 调用和正式发布签名仍需分别验证；具体证据范围以提交包中的索引和竞赛材料为准。

开发记录见 [DEVLOG.md](DEVLOG.md)。第三方依赖与素材权利应以提交包的许可证索引及团队签署材料核对，不能仅凭本页推定授权。
