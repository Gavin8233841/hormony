# 鸿学伴 HarmonyOS / 小艺技术知识与执行卡（2026-09-27）

本文件是**针对鸿学伴的本地工作知识**：记录官方资料的链接、可执行的技术约束、项目现状和验收门槛。它不复制华为文档全文，也不代表模型权重已训练或能力已接入。开发前重新打开对应官方页面核对版本；仅把同一提交、同一 HAP 的运行证据写入复赛成果。

## 1. 赛事约束与得分动作

权威依据是仓库根目录的《2026“中国高校计算机大赛―人工智能创意赛”鸿蒙高校创新赛竞赛规程.pdf》（SHA-256 `e5093c61bed5a10c249e165095127ac1f03fd3ce5b8b993d3a8d6ae878bec1a9`），[官方赛事页](https://developer.huawei.com/consumer/cn/activity/incentive/C4)和[报名平台](https://developer.huawei.com/home/C4-AI)。2026-09-27 复核 PDF 第 3、5、6 页：当前作品方向为 **Agent 创新**；允许 Agent 或 Skill，自建框架或小艺开放平台；主题是学习陪伴、主动服务、自然交互。复赛需一句话创意、设计稿、作品介绍、可演示文件及 ≤5 分钟视频。Agent 赛题可交运行所需工程文件，或小艺平台测试态 Agent；本项目仍应保留完整 HAP 和服务源码。

| 官方评分 | 能为本项目增加可核验价值的动作 | 证据门槛 |
|---|---|---|
| 创新性 50：鸿蒙技术、产品、交互、技术创新 | 小艺中的课程讲解 Agent 能接续原生学习动作；基于 ArkData 的真实结果改变下一步，卡片呈现及时服务 | 平台真实对话、原生跳转、测验回写与再开应用，均绑定版本 |
| 完备度 20：功能与体验完整顺畅 | 正常、空题、超时、断网、取消、重复请求均有可理解结果；多轮课程上下文不能错串 | 路由与协议测试、同版模拟器、可用时真机 |
| 前景评估 20：真实需求、社会价值、可落地价值 | 聚焦大学课程具体疑难和复习决策，记录目标学生的短任务反馈 | 不凭技术名词推断提分或市场规模 |
| 规范性 10：文档、表达、演示清晰 | 官方模板与文件命名；能力图只画真实链路 | 材料最后制作，逐条引用证据 |
| 实际应用价值附加 20 | 可运行 HAP、可复现源码、平台测试态 Agent；上架仅在实际完成后主张 | 安装与业务回执、平台状态、包哈希；不预估得分 |

应用创新赛题“建议 3 个及以上鸿蒙特性”**不是 Agent 方向硬门槛**。现有 ArkUI、ArkData、Form Kit 与通知依场景呈现；新增 Kit 必须解决具体学习问题。截止日与提交字段见[复赛交接](SEMIFINAL-IMPLEMENTATION-HANDOFF.md)，正式上传前重新核对门户。

## 2. 高收益技术路线

### A. 小艺端 A2A（优先完成 HAP 接入实验）

官方 [端 A2A 模式](https://developer.huawei.com/consumer/cn/doc/service/device-a2a-0000002640106106)要求平台关联应用/元服务、填写应用/模块/服务名称并导入 AgentCard。[应用内 Agent 接入](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-inapp-0000002630346158)（页面更新 2026-07-27）明确：`AgentExtensionAbility` 必选，`AgentUIExtensionAbility` 仅自定义卡片需要时才加。DevEco Studio API 26 本地 SDK 的 `@ohos.app.agent.AgentExtensionAbility.d.ts` 从 API 24 起支持 `onCreate`、`onConnect`、`onData`、`onAuth`、`onDisconnect`、`onDestroy`；`onData` 收 JSON 字符串，通过 `AgentHostProxy.sendData` 回结果。IDE 自带 Agent Extension 模板（本地路径 `/Applications/DevEco-Studio.app/Contents/plugins/openharmony/lib/templates/extension/AgentExtAbility/`），其 `module.json5` 使用 `type: "agent"`、`exported: true`、`ohos.extension.agent` 元数据指向 `$profile:agent_config`。本地 SDK/模板是**接口与结构证据**，不证明当前模拟器/设备可由小艺连接。

[端 A2A 对话交互](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-chat-0000002660585429)（2026-07-27）使用 JSON-RPC `method: "MessageStream"`，`params.message.role: "ROLE_USER"`，`parts[].text`、`mediaType: "text/plain"`，有 `messageId`、后续轮次 `contextId`。简单回答可回 `result.task.id/contextId/status.state: "TASK_STATE_COMPLETED"`、`timestamp` 和 `artifacts[].parts[].text`。官方示例的一组请求/响应 `id` 不一致；实现必须回显收到的请求 `id`，再用平台调试检验。完整协议和取消分别看[端 A2A 技术规范](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-device-0000002624952279)、[异常与任务取消](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-exp-0000002660465491)。首版只做短文本、只读 Tutor，拒绝文件、界面操控和任意 App 动作；不暴露内部推理或学习画像。后续多轮 `contextId`、`TasksCancel`、并发与断连要按真实协议实现。

[AgentCard 规范](https://developer.huawei.com/consumer/cn/doc/service/agentcard-0000002678424557)（2026-07-27）列 `name`、`description`、`agentId`、`version`、`iconUrl`、默认输入/输出 MIME、`skills` 和 `appInfo` 等字段；规范表说明平台导入/导出不支持 `agentId` 与 `appInfo`，它们分别有平台内部与应用关联语义。IDE 简化模板与平台字段不完全一致，**按平台实际导入校验结果确认**，不猜平台生成的 ID。`agentId` 在同包名内唯一。平台上传控件明确要求 APP 工程中的 `agent_config.json`；本项目用 `entry/src/main/resources/base/profile/agent_config.json`。不要在 Card 填未上线 URL、虚构设备支持或未实现的 Skill。

项目现状：`entry/src/main/module.json5` 已注册导出的 `XiaoyiAgentAbility`，其配置位于 `entry/src/main/resources/base/profile/agent_config.json`；API 26 Debug HAP 的 ArkTS 编译、打包检查通过。Extension 只接收短文本课程问题，经 `HttpClient.postSSE` 调用独立的 `/api/xiaoyi/tutor`，复用服务端 Tutor 编排和 Safety；提供按连接隔离的取消、断连、并发及进程内历史上限。**这是端侧协议适配加云端模型调用，不是端侧模型推理**。当前没有小艺实际连接证据，`iconUrl` 在 Web 部署前也不可作为线上可访问资源。

2026-09-27 平台实查：初次进入“端A2A模式”时应用选择器显示“暂无数据”；用户随后在 AppGallery Connect 完成“鸿学伴”应用创建，项目名 `Hormony`，小艺表单现已显示关联应用“鸿学伴”。平台在同页提示最低 HarmonyOS API 24、小艺 App 11.6.6.300；当前 App 目标 API 26 满足代码侧版本条件。平台“应用服务名称”按 `module.json5` 中 `type: "agent"` 的 `name` 填 `XiaoyiAgentAbility`。已在 Safari 填入该值，尝试上传 `agent_config.json` 时平台返回“会话超时”并跳转华为账号登录；**尚无 Card 导入成功或 Agent 创建证据**。登录恢复后重新核对关联应用、上传结果和确认创建状态。真机版本与真实小艺对话也未验证。[官方创建应用指南](https://developer.huawei.com/consumer/cn/doc/app/agc-help-createharmonyapp-0000001945392297)与[端 A2A 创建流程](https://developer.huawei.com/consumer/cn/doc/service/device-a2a-0000002640106106)用于复核后续步骤。若页面提出法律协议或资质验证，由账户主体完成。

### B. 小艺云 A2A（保留现有适配，按门槛再开放）

[云 A2A 模式](https://developer.huawei.com/consumer/cn/doc/service/cloud-a2a-0000002640266052)适配已有自有云 Agent。[协议技术规范](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-comments-0000002500412353)、[消息定义](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-define-0000002467293060)、[发起会话](https://developer.huawei.com/consumer/cn/doc/service/message-stream-0000002505761434)、[终止会话](https://developer.huawei.com/consumer/cn/doc/service/tasks-cancel-0000002537561193)是实现依据。云版使用单 POST Endpoint / Streamable HTTP / JSON-RPC，可返回 SSE；`message/stream` 有 `params.id` 与 `sessionId`，终态可用 `artifact-update`、`final: true` 与 `lastChunk: true`。有会话模式要处理 `initialize` 和 `agent-session-id`；无会话模式每次携带鉴权。当前 `apps/web/src/lib/agents/cloud-a2a-tutor.ts` **只有本地解析/只读讲解/终态格式化与单测**，无公网路由。无共享会话、鉴权、幂等、跨实例取消和全局成本限额之前不公开接入点；Vercel 进程内 Map 不满足跨实例语义。

端 A2A 与云 A2A **是两种协议**：方法名、报文结构和返回方式不同，不能把云适配层直接交给端侧 Extension。首轮以端侧 HAP + 平台测试态为主，云版作为服务分发备选；平台实测或签名条件若否定端侧路线，再转云版，并记录依据。

### C. 原生入口与自然交互

- [Intents Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/intents-introduction)、[意图装饰器 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-app-ability-insightintentdecorator)：可将页面、链接或函数声明为系统意图，面向小艺对话、搜索、建议。`@InsightIntentPage` / `@InsightIntentLink` / `@InsightIntentFunction` 的参数和测试流程需按正式指南核对。当前普通 Want 的 `source` 文本**不等于系统意图身份**。先实现“打开今日任务／指定课程主题”一项，只有系统入口真机触发后才写为已接入。
- [Agent Framework Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hmaf-introduction)：应用内主动拉起智能体组合的 UI 能力，和向小艺提供端 A2A Agent 不是同一件事；取得小艺 Agent ID 和设备支持信息后再评估 `AgentController` 等 API。
- [Core Speech Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-speech-introduction)、[产品页](https://developer.huawei.com/consumer/cn/sdk/core-speech-kit/)：文本转语音和语音识别。首选一个课程讲解/学伴回答朗读动作，核对音频权限、设备支持、10000 字符限制、回调及停播，实机听感通过才保留。不要把语音输入法等同已接入语音 Kit。
- [Data Augmentation Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-augmentation-kit-guide)及[端侧问答 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/dataaugmentation-localchatmodel-api)：`localChatModel` 当前标注 PC/2in1，手机 HAP 不以它作为端侧模型方案；检索组件的手机支持、地区、模拟器限制要另查，不能把整个 Kit 混为一谈。现有云端 RAG 已满足课程依据主线，暂不重建数据底座。

## 3. 每批标准操作与证据

1. 对照本卡与原文核实 API 版本、设备、平台字段；记录要解决的学习问题和一个完整用户动作。仅当源与 App 当前 API 26 兼容才进入代码。
2. 先看 `git status --short` 和调用方、测试，保留其他任务脏文件；一个批次只改一个可验收功能。源码变更执行仓库 `AGENTS.md` 的 Web 或 HAP 必需门禁，失败路径不伪造回复。
3. 平台创建与联调以当前账户页面真实字段为准。合作协议、安全隐私调查和凭据由账户主体处理；项目名、Card、截图和日志不含私密数据。云 A2A 外部 URL 上线前先完成鉴权、共享状态和费用边界。
4. 证据按 **源码确认→静态诊断→构建→模拟器→真机→平台/线上** 分级。登记提交哈希、HAP SHA-256、设备/系统、平台项目测试状态、一次成功与至少一次失败/取消路径。平台显示“创建完成”不等于小艺真实可问答；模拟器通过不等于真机通过。
5. 只有能力已在 HAP 或平台按同版验证，才回写作品叙事和附件。优先完成端 A2A 文本课程讲解、课程动作入口、同版演示，再考虑语音/意图/自定义卡片；PDF 最后制作。

## 4. 当前状态与下一批

- **源码确认**：ArkUI、ArkData、服务卡片、通知、云端多 Agent、只读 Tutor，以及本批新增的端 A2A Extension 和独立 Tutor 接口；包名 `com.c4ai.hormony`、模块 `entry`、API 26。具体范围见[交接](SEMIFINAL-IMPLEMENTATION-HANDOFF.md)和[接入计划](SEMIFINAL-HARMONY-AI-INTEGRATION-PLAN-20260927.md)。
- **本地检查**：Web lint、typecheck、492 项测试及构建通过；Hvigor API 26 增量构建 exit 0，产物仍为未签名 HAP。尚无平台 AgentCard 导入校验。
- **平台确认**：AppGallery Connect 中“鸿学伴”应用已由用户创建，小艺端 A2A 表单已显示关联成功；应用服务名称已填写 `XiaoyiAgentAbility`。AgentCard 上传遇到会话超时，未完成导入与创建。
- **未验证**：Extension 运行和真实小艺对话、系统意图、语音 Kit、真机与已签名 HAP。
- **下一批顺序**：部署并校验 Web 独立接口与头像 URL → 账户重新登录后平台端 A2A 导入与测试态 → 真机问答/取消 → 明确补充 Intents Kit 或朗读。每步不成功则保留上一层结果，并记下具体平台/设备阻塞。
