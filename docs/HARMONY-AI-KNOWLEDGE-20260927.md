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

项目现状：`entry/src/main/module.json5` 已注册导出的 `XiaoyiAgentAbility`，其配置位于 `entry/src/main/resources/base/profile/agent_config.json`；API 26 Debug HAP 的 ArkTS 编译、打包检查通过。Extension 只接收短文本课程问题，经 `HttpClient.postSSE` 调用独立的 `/api/xiaoyi/tutor`，复用服务端 Tutor 编排和 Safety；提供按连接隔离的取消、断连、并发及进程内历史上限。**这是端侧协议适配加云端模型调用，不是端侧模型推理**。Web 部署 `dpl_6LQpd9gP8pwQWfpSdApnQaDdLGeV` 已提升到 `hormony-ruddy.vercel.app`，线上图标 URL 返回 PNG 200，小艺专用接口的合成课程问题返回 200、正文和 `done`；仍没有小艺实际连接证据。

2026-09-27 初次平台实查：进入“端A2A模式”时应用选择器显示“暂无数据”；用户随后报告完成“鸿学伴”注册并给出项目名 `Hormony`，当时的小艺表单曾显示关联应用“鸿学伴”。平台在同页提示最低 HarmonyOS API 24、小艺 App 11.6.6.300；当前 App 目标 API 26 满足代码侧版本条件。平台“应用服务名称”按 `module.json5` 中 `type: "agent"` 的 `name` 填 `XiaoyiAgentAbility`。当时在 Safari 填入该值，尝试上传 `agent_config.json` 时平台返回“会话超时”并跳转华为账号登录；**尚无 Card 导入成功或 Agent 创建证据**。真机版本与真实小艺对话也未验证。[官方创建应用指南](https://developer.huawei.com/consumer/cn/doc/app/agc-help-createharmonyapp-0000001945392297)与[端 A2A 创建流程](https://developer.huawei.com/consumer/cn/doc/service/device-a2a-0000002640106106)用于复核后续步骤。若页面提出法律协议或资质验证，由账户主体完成。

2026-09-27 登录恢复后复查：刷新小艺“新建项目”并选择端 A2A，当前关联步骤显示“暂无HarmonyOS应用”；Agent 列表显示共 0 条，之前表单的“鸿学伴”关联没有留下已创建项目。AGC 的 **APP ID** 列表确有一条“鸿学伴”／`com.c4ai.hormony`（APP ID `6917617536495682419`）；但 **APP 与元服务** 的 HarmonyOS 列表显示“暂无数据”。进入 AGC“开发与服务”项目管理时弹出《AppGallery Connect协议包》，其中预选了多项服务条款，包含付费服务协议；关闭弹窗后回到 AGC 首页，未读取到项目列表。不能由 APP ID 存在推断已完成 AGC 应用/项目配置，也不能确定小艺列表为空仅由该协议造成。账户主体需审阅并处理协议后，再分别复核 AGC 项目、应用列表和小艺选择器；代理不代签法律协议。此时仍无 Card 导入、Agent 创建或小艺对话证据。

2026-09-27 约 21:53–22:03 CST 平台续查：用户完成账户协议/登录后，AGC「APP 与元服务」创建了鸿学伴的 HarmonyOS 应用记录，列表显示「准备提交」、详情显示「未提交」；此前 APP ID `6917617536495682419` 仍对应 `com.c4ai.hormony`。小艺端 A2A 选择器随后可关联鸿学伴。上传工程 `agent_config.json` 后平台成功解析名称、版本、文本输入输出与「讲解课程概念」Skill，并创建 **小鸿 Agent 草稿**，平台 Agent ID `agent1e478cf9ea75464495020ca66bc39fb0`，应用内 ID `xiaohong_learning_tutor`，服务名称 `XiaoyiAgentAbility`，分类「教育 / 学习」。编排中保存了「解释二叉搜索树」文本快捷指令。测试白名单组「鸿学伴小鸿真机测试」已创建，当前账户在组中，开关在页面显示 `on`。Card 的线上 PNG URL 由本机请求返回 200，但平台提示「iconUrl解析失败，已替换成默认图标」；现有草稿仍为平台默认头像，不能写成品牌头像已接入。

点击平台「上架（1项未完成）」得到唯一未完成项「内容合规未填写」。该表单要求判断是否包含人工智能生成的文件、是否接入非小艺平台三方大模型；选三方模型「是」后新增必填「生成式人工智能服务上线备案号」和「算法备案号」，并有对法规审视及申报真实性承担责任的确认框。**未填写备案号、未勾选确认、未上架或发布真机测试**。仓库 `apps/web/src/lib/agents/model.ts` 默认使用火山方舟兼容接口；当时公开 `/api/health` 只读结果显示模型已配置且名称 `doubao-seed-2-1-pro-260628`，因此不能如实选择「未接入三方大模型」。火山引擎[客户资质材料说明](https://www.volcengine.com/docs/82379/1326340?lang=zh)指向按账户、已开通商品取得对应合同及备案说明；其他产品的公开备案号不能未经核对直接填作本 Agent 的申报。另在当前 Web 源码中未找到可直接用于该 Agent 的隐私政策页面；平台「隐私协议服务」默认隐私托管但政策选择为空。正式发布前需由账户主体核定备案/登记材料、模型使用关系、AI 标识和隐私政策，并审阅平台声明。草稿和白名单均不证明小艺真机可问答。

2026-09-27 22:22 CST，Mac 解锁后进入「小鸿」编排页，打开预览区的「真机测试」。平台说明此操作把当前编排发布至**仅白名单可触达的开发测试态**，有效期 15 天。点击「发布真机测试」后页面显示「保存成功」「发布成功」，菜单变为「取消发布／重新发布」；随后复核「测试白名单」，「鸿学伴小鸿真机测试」仍为 `on`，用户数量 1，当前账号在组中。故**平台测试态发布已完成**，但左侧仍标「草稿」，正式「上架（1项未完成）」与前述内容合规门槛未变。当前 HDC 只有模拟器，尚无实体 HarmonyOS 设备安装已签名 HAP，也没有小艺 App 中出现「小鸿」或真实问答的证据。下一步在属于该白名单的账号所登录真机上安装身份匹配的 HAP，重启小艺并核对「开发中」Agent 的实际触达与 SSE 回答；不得把平台发布回执写成端到端通过。操作依据见[小艺真机测试指南](https://developer.huawei.com/consumer/cn/doc/doccenter-celia/list-of-user-groups-for-real-machine-testing-0000002471264273)。

### B. 小艺云 A2A（保留现有适配，按门槛再开放）

[云 A2A 模式](https://developer.huawei.com/consumer/cn/doc/service/cloud-a2a-0000002640266052)适配已有自有云 Agent。[协议技术规范](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-comments-0000002500412353)、[消息定义](https://developer.huawei.com/consumer/cn/doc/service/agent2agent-define-0000002467293060)、[发起会话](https://developer.huawei.com/consumer/cn/doc/service/message-stream-0000002505761434)、[终止会话](https://developer.huawei.com/consumer/cn/doc/service/tasks-cancel-0000002537561193)是实现依据。云版使用单 POST Endpoint / Streamable HTTP / JSON-RPC，可返回 SSE；`message/stream` 有 `params.id` 与 `sessionId`，终态可用 `artifact-update`、`final: true` 与 `lastChunk: true`。有会话模式要处理 `initialize` 和 `agent-session-id`；无会话模式每次携带鉴权。当前 `apps/web/src/lib/agents/cloud-a2a-tutor.ts` **只有本地解析/只读讲解/终态格式化与单测**，无公网路由。无共享会话、鉴权、幂等、跨实例取消和全局成本限额之前不公开接入点；Vercel 进程内 Map 不满足跨实例语义。

端 A2A 与云 A2A **是两种协议**：方法名、报文结构和返回方式不同，不能把云适配层直接交给端侧 Extension。首轮以端侧 HAP + 平台测试态为主，云版作为服务分发备选；平台实测或签名条件若否定端侧路线，再转云版，并记录依据。

### C. 原生入口与自然交互

- [Intents Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/intents-introduction)、[意图装饰器 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-app-ability-insightintentdecorator)：`@InsightIntentPage` 可把现有 ArkUI 页面声明为意图，API 20 起支持。2026-09-27 分别在 `Plan.ets`、`Chat.ets` 的 `@Entry` 页面声明自定义 `ViewStudyPlan`、`AskLearningCompanion`，均用 `EducationDomain`、`EntryAbility`，不传递学生数据。意图编译产物列出两项声明，签名与未签名 HAP 均含 `resources/base/profile/insight_intent.json` 且 `module.json` 的 `hasInsightIntent=true`。首次编译要求标准化 OHMUrl，按[华为工程构建配置示例](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ide-hvigor-compilation-options-customizing-sample)在产品 `buildOption.strictMode` 设置 `useNormalizedOHMUrl=true` 后构建成功。**这仅证明意图打包，当前没有小艺系统入口触发证据。**普通 Want 的 `source` 文本也不等于系统意图身份。
- [Agent Framework Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hmaf-introduction)：应用内主动拉起智能体组合的 UI 能力，和向小艺提供端 A2A Agent 不是同一件事。本地 API 26 SDK 的 `AgentController.isAgentSupport(context, agentId)` 会异步返回 Agent 可用性，`FunctionComponent` 需要平台 `agentId`；小鸿平台 ID 已知，但模拟器上尚无可用性/弹窗回执。本阶段先保留可运行的学伴原生对话，不添加无法验证的系统组件入口。
- [Core Speech Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-speech-introduction)、[文本转语音指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/texttospeech-guide)：官方注明 Kit 从 HarmonyOS 6.0.0(20) 起支持模拟器，文本转语音支持手机、平板、PC/2in1 和中国境内的中英文文本，上限 10000 字符。`createEngine` 使用离线模式 `online: 1`；`SpeakListener.onComplete` 的 `type=0` 表示合成完成，`type=1` 才表示播放完成。学伴页现为最后一条完整回答提供朗读/停止；退出页面停止并释放引擎，超长或引擎失败有提示。模拟器 UI、开始/完成/停止回调已核对；真实听感留待决赛后。不要把语音输入法等同已接入语音 Kit。
- [Data Augmentation Kit 概览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-augmentation-kit-guide)及[端侧问答 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/dataaugmentation-localchatmodel-api)：`localChatModel` 当前标注 PC/2in1，手机 HAP 不以它作为端侧模型方案；检索组件的手机支持、地区、模拟器限制要另查，不能把整个 Kit 混为一谈。现有云端 RAG 已满足课程依据主线，暂不重建数据底座。

## 3. 每批标准操作与证据

1. 对照本卡与原文核实 API 版本、设备、平台字段；记录要解决的学习问题和一个完整用户动作。仅当源与 App 当前 API 26 兼容才进入代码。
2. 先看 `git status --short` 和调用方、测试，保留其他任务脏文件；一个批次只改一个可验收功能。源码变更执行仓库 `AGENTS.md` 的 Web 或 HAP 必需门禁，失败路径不伪造回复。
3. 平台创建与联调以当前账户页面真实字段为准。合作协议、安全隐私调查和凭据由账户主体处理；项目名、Card、截图和日志不含私密数据。云 A2A 外部 URL 上线前先完成鉴权、共享状态和费用边界。
4. 证据按 **源码确认→静态诊断→构建→模拟器→平台/线上→真机** 分级。登记提交哈希、HAP SHA-256、设备/系统、平台项目测试状态、一次成功与至少一次失败/取消路径。2026-09-27 用户决定本阶段全部使用模拟器，真机议题留待决赛后；复赛材料只主张已验证的模拟器、平台与线上结果。平台显示“创建完成”不等于小艺真实可问答；模拟器通过不等于真机通过。
5. 只有能力已在 HAP 或平台按同版验证，才回写作品叙事和附件。优先完成端 A2A 文本课程讲解、课程动作入口、同版演示，再考虑语音/意图/自定义卡片；PDF 最后制作。

### 签名与小艺真机测试的官方路径

- [DevEco 自动签名](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ide-signing-auto)区分关联与未关联注册应用。2026-09-27 在 DevEco 完成项目同步后，`Compatible SDK` 显示 `26.0.0`，并在 `File > Project Structure > Project > Signing Configs` 选择 **Associate with registered application**；团队与包名分别显示当前账号和 `com.c4ai.hormony`。首次打开签名页曾提示未验证用户须签协议，项目同步后该提示未再出现，关联及签名构建成功；不能据首次提示推断当前仍缺协议。API 26 支持先在 AGC 注册设备再签名。DevEco 将包含本机签名口令和路径的配置写入**已跟踪的** `apps/harmonyos/build-profile.json5`，该文件只保留为本地未提交修改，绝不得暂存、提交或输出内容；`.p12`、`.csr`、`.cer`、`.p7b` 也不得入库。
- [小艺真机测试](https://developer.huawei.com/consumer/cn/doc/doccenter-celia/list-of-user-groups-for-real-machine-testing-0000002471264273)先在 Agent 调试与预览设置白名单用户组，再发布真机测试；官方说明测试态有效期 15 天，重新启动小艺后约 3–5 分钟可见“开发中”Agent。测试账号必须是有小艺开放平台权限的团队成员；主账号可按平台实际资格测试。只有同一签名包在支持版本真机中完成成功对话及失败/取消路径，才写入复赛演示叙事。

## 4. 当前状态与下一批

- **源码确认**：ArkUI、ArkData、服务卡片、通知、云端多 Agent、只读 Tutor，以及本批新增的端 A2A Extension 和独立 Tutor 接口；包名 `com.c4ai.hormony`、模块 `entry`、API 26。具体范围见[交接](SEMIFINAL-IMPLEMENTATION-HANDOFF.md)和[接入计划](SEMIFINAL-HARMONY-AI-INTEGRATION-PLAN-20260927.md)。
- **本地检查**：Web lint、typecheck、492 项测试及构建通过；原 API 26 未签名 HAP 已构建。关联 AGC“鸿学伴”的本机签名配置之后，`devecocli build` exit 0，含 `SignHap`；初版签名 HAP 的 SHA-256 为 `62f741b2782da864f0d2929988aba3ec4b2a84b2e1ae1c6a8578e53b28a1b061`。2026-09-27 22:10 CST 修复端 A2A 非字符串 `parts[0].text` 在校验前调用 `.trim()` 的异常后，增量 `devecocli build` exit 0，`CompileArkTS`、`PackageHap`、`PackingCheck`、`SignHap` 完成；新签名 HAP SHA-256 `dfa95e2e4b34f95afd200788302b476dec8a8baa60b95a330d41d71138d4c4c0`，本地 SDK `hap-sign-tool.jar verify-app` exit 0。新包没有安装或真机运行证据，不能沿用旧模拟器的运行结果；签名可验证也不证明 Profile 包含目标真机。
- **模拟器通过（有限范围）**：Pura X View 模拟器 `127.0.0.1:5555` 上 `devecocli run --skip-build` 安装、启动 exit 0；`bm dump -n com.c4ai.hormony` 包含 `XiaoyiAgentAbility` 与 `ohos.extension.agent` 元数据。仅证实扩展能力已随包注册，不证明小艺能连接、请求与取消协议能运行。
- **签名包安装尝试**：对同一模拟器执行 HDC `install -r entry-default-signed.hap`，安装器返回 `code:9568332 error: install sign info inconsistent`。设备原有安装为未签名调试包（`appSignType: none`），尝试后仍保留原包。因此这是覆盖安装时签名身份不一致的失败证据，不能据此判定签名 HAP 本身无效；也没有签名包安装成功的证据。没有卸载原包或清除数据。
- **线上通过**：部署 `dpl_6LQpd9gP8pwQWfpSdApnQaDdLGeV` 已提升为公开域名目标；公开域名 `GET /api/health` 为 200 且 `status=ready`，头像 PNG 为 200，`POST /api/xiaoyi/tutor` 的合成课程问题为 200 SSE，含非空 `delta` 与 `done`、无 `error`；空问题为 400 `MISSING_FIELD`。这只证明云端接口，不证明端侧 Extension 或小艺平台连接。
- **平台确认**：AGC 已有 APP ID 与单独的「APP 与元服务」鸿学伴记录，后者为「准备提交／未提交」。小艺平台已创建「小鸿」端 A2A **草稿**，导入 Card、分类、快捷指令、含当前账户且已开启的真机测试组均在页面确认；默认头像替代了未解析的 `iconUrl`。2026-09-27 22:22 CST 点击「发布真机测试」后得到「保存成功／发布成功」，按钮变为「取消发布／重新发布」，刷新后仍为已发布测试态；白名单组开关 `on`、成员数 1。**这不是正式上架或真实对话**：「内容合规」仍缺备案字段及主体确认。
- **最新 HAP（双意图声明）**：`AskLearningCompanion` 加入后直接运行 Hvigor 增量构建 exit 0、`BUILD SUCCESSFUL in 2 s 962 ms`，完成 `CompileArkTS`、`PackageHap`、`PackingCheck`、`SignHap`。签名 `entry-default-signed.hap` SHA-256 `9626cb9dd6af214f72501b62cfa5f1729b7a441409bb3217a54ce881de50cedb`，未签名包 SHA-256 `62bbe68d00965828c76b337adc09a297c5816abb25832fd78b3f67463a6f65dc`；两包都含上述两项意图。仍有 `TextInputController` 系统能力告警。前一版 `devecocli build` 曾内层成功、外层 exit 1；本版以直接 Hvigor exit 0 和产物为准。
- **最新模拟器证据**：在 Pura X View 模拟器 `127.0.0.1:5555` 无卸载覆盖安装当前未签名包（SHA-256 `62bbe68d00965828c76b337adc09a297c5816abb25832fd78b3f67463a6f65dc`）成功，`aa start` 启动 `EntryAbility` 成功；学伴标签 UI 树出现「学伴」、历史回答和参考资料，证明当前包的原生对话页能打开。前一版未签名包（SHA-256 `59f535d8ea4bea993a47c7e01e8eae01e90f43bfc2e20bba1280ae3eb4f39c2a`）曾从首页「查看安排」进入学习计划页，UI 树出现课程任务，截图在忽略目录 `.runtime/hongxueban-plan-20260927.png`。这些仅是普通页面入口；**没有小艺系统意图唤起、当前包的学习计划页复测、当前包的实时 AI 回答证据**。模拟器安装的是未签名包，签名 HAP 只有构建证据。
- **朗读增量 HAP 与模拟器**：`Chat.ets` 接入 Core Speech Kit 离线文本转语音后，直接 Hvigor 增量构建 exit 0，`CompileArkTS`、`PackageHap`、`PackingCheck`、`SignHap` 完成。最终补充新问题发出时停播逻辑后再次构建 exit 0；最新签名包 SHA-256 `66414dc32268043e166223bbf6ad6f9dd173883eaaf8d40f9cbbac76c10310a5`，未签名包 SHA-256 `a884203a85f908d22783da6a681f3f434dfd06dabc82d39ffd42df7d90af9608`。Pura X View 模拟器覆盖安装该未签名包并进入学伴页后，已有回答出现「朗读回答」；点击后 UI 变为「停止朗读」，系统引擎创建成功，应用日志显示 `speak`、`onStart`、`onComplete 0`、`onComplete 1`；点击停止后 UI 恢复。播放中截图位于忽略目录 `.runtime/hongxueban-tts-active-20260927.jpeg`，截图属于前一版朗读包，最后版本的 UI 树和回调另行复测通过。这是模拟器语音引擎和 UI 状态证据，**不包含人工听感或真机证据**；这次使用已保存的历史回答，未发起新一轮在线 AI 请求。
- **未验证**：用户决定决赛后再讨论真机。Extension 与小艺端到端问答/取消、系统意图从小艺唤起、朗读的人耳听感、签名 HAP 的真机安装与使用均未验证；复赛材料不得写成完成。
- **下一批顺序**：以模拟器为本阶段验收环境，优先完成意图元数据、端 A2A 异常协议、学习流程与 HAP 构建的可复现检查，并用平台测试态截图和线上接口回执组成诚实的复赛证据。正式上架仍需账户主体核定三方模型备案/登记、AI 标识与隐私政策并审阅合规声明；真机验证延至决赛后。PDF 与复赛叙事在模拟器成果稳定后制作。
