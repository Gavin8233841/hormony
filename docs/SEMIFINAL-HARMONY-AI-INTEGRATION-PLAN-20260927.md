# 鸿学伴：鸿蒙 AI 接入评估与实施计划（2026-09-27）

## 决策

当前集中推进小艺云 A2A 与 HarmonyOS 原生智能入口，作品 PDF 暂缓。先完善现有 App 的受控学习入口与只读讲解，再以**协议、平台资格和跨请求状态能力核验**作为小艺云 A2A 接入门槛。云 A2A 是优先路线，但尚不能定为可直接在现有无状态 Vercel 服务落地。Intents Kit 与语音朗读分别评估，不依赖云 A2A 成功。不要为展示技术名词而加入 OCR、端侧 RAG 或端 A2A。

当前小艺平台页面给出的适用条件是：云 A2A 面向已有自有云 Agent 和后端接口的开发者；端 A2A 面向已在 HarmonyOS 应用内完成 Agent 开发的开发者；云工作流面向无现成 Agent 资产者。鸿学伴已有 Next.js 服务端 Agent 编排和 ArkTS 客户端，因此**云 A2A 与项目结构最接近**。已登录的平台创建页明确说明“存量云端 Agent 直接适配接入小艺平台，无需改动鸿蒙端应用”；这是平台给出的模式定位，不代表我方服务已经符合云 A2A 协议。这只是可行性判断，协议适配、平台联调和真机测试尚未完成。

## Astra 复审与开工结论

已按 Astra 审查修正四处关键判断：外部 Want 校验后不得重新选择任务；小艺讲解必须由服务端强制锁定 Tutor，不能只靠提示词；现有 `/api/chat` 的请求内取消和进程内限流不足以承诺跨请求取消或全局成本保护；用户自由文本与平台处理链仍需按个人信息风险设计。华为云 A2A 文档确认使用 Streamable HTTP、JSON-RPC 和可选 SSE，服务端无需维持长连接，因而部署评估聚焦共享会话状态、鉴权、幂等、取消和时限。

结论为**有条件推进**：先做不依赖平台资格的原生路由修正与协议夹具；没有确认平台字段、共享状态方案和成本预算之前，不创建公网 A2A 接口或声称小艺已接入。2026-09-27 的首批原生修正已构建并安装启动通过，卡片／提醒的指定动作仍未交互验证。服务端新增强制只读 Tutor 和云 A2A 文本协议适配函数，尚无公网路由或小艺项目联调。

## 已核对现状

- 当前工程 target / compatible SDK 均为 26.0.0；包名 `com.c4ai.hormony`。
- ArkUI / ArkTS 页面与 ArkData 本地状态已经存在；Chat 使用 `/api/chat` 流式接口，Plan 使用 `/api/plan`，Quiz 使用 `/api/quiz`。客户端已有课程、主题、计划、练习之间的动作路由。
- `EntryAbility` 对外部 Want 参数实施来源、目标页、课程和主题校验；`source` 是传入字符串，不是调用方身份凭据。2026-09-27 已修正校验后重新选择今日任务的跳转差异，增量构建通过；冷启动、热启动与重复点击的实际运行仍待核验。小艺入口需按官方实际机制接入，不能凭空扩展一个来源值。
- 目前没有小艺平台 Agent ID、公网 A2A 接口、Intents Kit 接入或 Core Speech Kit 接入。已有本地 A2A 文本消息解析、讲解编排、终态 SSE 编码及单元测试；不能将这部分源码等同于已接入小艺。

## 路线比较

| 路线 | 与学习场景的价值 | 代价和验证条件 | 顺序 |
|---|---|---|---|
| 小艺云 A2A | 在系统智能入口问课程概念，把解释与应用内学习动作相连 | 先核验协议版本、传输/鉴权/会话/取消、部署时限、平台资格，再决定适配 | 协议门槛后 |
| Intents Kit | 从系统意图入口打开今日任务或指定主题 | 需要核实官方意图声明、应用关联与实际设备行为；不能靠普通 Want 或模拟器画面证明系统分发 | 并行评估 |
| Core Speech Kit / Speech Kit | 朗读课程讲解或辅导回答，增强自然交互和可访问性 | 两套能力不同；先按官方 API、设备支持、语音服务和交互限制选型，再做真机听感验证 | 并行评估 |
| 云工作流/云插件 | 对单一、标准化学习动作易于编排 | 容易复制已有业务编排；个人智能体的私有云插件上架有限制 | 备选 |
| 端 A2A | 端侧协作、应用内 Agent 服务 | 需新增 AgentExtensionAbility、AgentCard、应用关联与真实设备联调；当前云端模型不因此变为端侧模型 | 后续 |
| Data Augmentation Kit `localChatModel` | 理论上能让资料本地化 | 已查该 API 标注 PC/2in1；不能据此推断整个 Kit 或所有检索能力仅支持 PC，模拟器支持情况尚待核实 | 暂缓该 API |
| OCR 拍题 | 从图像转成文字问题 | 摄像头/相册、识别误差、版权和个人信息处理会扩大范围 | 暂缓 |

## 分阶段落地

### 0. 先固定产品动作与数据边界

首个小艺能力只处理三门课程内的概念解释。服务端必须显式限制为只读 Tutor，不允许关键字把请求路由到 Planner、Quiz 或 Evaluator；继续执行输入、检索结果、模型输出的既有安全检查。仅接受协议必需字段，不读取端侧画像、计划、练习和错题，不要求绑定鸿学伴账户。用户自由输入仍可能包含个人信息，需按实际平台与模型处理链说明数据使用和最小日志。输出只包含讲解、与结论对应的资料引用和允许的学习动作，不透传内部 trace。

验收用三门课程各自的代表问题，加上未知主题、越界输入、指令注入、模型超时、取消、重复请求、错误跳转、冷启动/热启动和返回应用状态保持。每项记录预期、实际、请求标识与版本；不能用“回答可读”代替正确性和动作校验。

### 1. 协议与平台资格门槛（在开放网络入口之前）

已在浏览器读取华为《云A2A协议技术规范》（更新于 2026-06-12）和《发起会话》《终止会话》，并按文档中的文本消息与 `artifact-update` 示例实现本地适配函数。下一步按下表补齐未核实部分，再开放网络入口：

| 协议点 | 已核实事实 | 尚待核实或决策 |
|---|---|---|
| 传输 | 单个 Endpoint、POST、Streamable HTTP + JSON-RPC；`message/stream` 可用 SSE 响应；服务器无需维护长连接 | 平台首包/总时限、断线重连与重复请求的精确行为 |
| 接口会话 | 推荐有会话模式实现 `initialize`、`notifications/initialized` 并由服务端分配 `agent-session-id`；简化无会话模式可省略这两个方法，每次请求携带鉴权凭据 | 选用哪种模式及平台创建页要求 |
| 对话状态 | `message/stream` 含客户端 `sessionId`；规范要求服务端按该 ID 缓存对话上下文 | 持久存储、留存时间、隔离/清理与费用；当前无状态服务不具备 |
| 消息和结果 | 请求为 `jsonrpc: "2.0"`、`id`、`method: "message/stream"`、`params.id`、`params.sessionId` 和 `message.parts`；SSE 的 `status-update` / `artifact-update` 以 `final:true` 结束 | 文本以外 parts 的拒绝/兼容规则、引用与打开 App 动作的结构化数据格式 |
| 取消与清理 | 文档列出 `tasks/cancel` 与 `clearContext`；取消响应状态为 `canceled`、`failed` 或 `unknown` | 取消请求与在途生成跨实例关联的具体设计、幂等和重放约束 |
| 鉴权 | 规范列举 AK/SK、APIKey、OAuth 等凭据形式，并链接认证参考 | 平台实际配置的方案、签名细节及时间窗口；不可直接套用另一种旧 Fulfillment 接口 |
| 其他方法 | `authorize` / `deauthorize` 供账号授权；`push` 用于异步长任务 | 本首版不绑定用户账号或做长任务，平台是否可不实现须调试确认 |

同步只读核对账户模式权限、设备和系统版本选择、真机测试资格及应用关联条件。账户主体只负责必须亲自操作的条款和权限。

部署门槛：协议已说明服务端不用维护长连接，WebSocket 不是本路线的决定项。真正缺口是客户端 `sessionId` 的跨请求上下文、清理、取消、幂等和成本控制。当前 `/api/chat` 请求内取消不能证明平台任务跨请求取消；进程内 IP 限流也不能证明跨实例、共享平台出口的成本保护。须先选择可恢复的共享状态方案，估算费用与保留期，再做安全的端到端样例；不把 Vercel 单实例内存当持久状态。

### 2. 云 A2A 适配层（门槛通过后）

本地适配已能解析受限 `message/stream` 文本请求，调用只读 Tutor，并编码终态 `artifact-update`；输入个人信息与不支持的媒体 part 会被拒绝。下一步在既有服务旁新增独立协议入口，按选定的会话模式实现矩阵确认的方法；用平台实际配置的凭据验证请求，限制大小、并发和成本。跨请求取消、上下文清理与幂等必须有可观察的实现和测试。A2A 协议与现有 `/api/chat` SSE 格式不能直接互换；不写死平台密钥。

完成条件：本地协议测试覆盖正常问答、无效鉴权、空主题、取消、超时和重复请求；现有 Chat/Plan/Quiz 回归通过。

### 3. 平台开发态联调与真实设备

开发者在小艺开放平台使用现有账号创建已核实可用的模式项目，手机为首个候选设备。只有在适配接口完成且可公开安全访问后再填写服务地址。平台实际要求的身份标识和鉴权凭据字段以创建页和协议为准；秘密只存服务端安全配置，不能发在聊天、截图或源码中。合作协议与安全隐私调查由账户主体自行审阅并处理。

先在平台 Web 调试，再用官方真机白名单进行小艺端联调。官方说明开发态真机测试有效期为最后一次发布测试起 15 天；团队账号须具备权限，Inhouse 账号的该权限例外需按官方规则使用主账号。完成条件：真实 HarmonyOS 设备上从小艺发问、收到课程解释、按已核实的系统机制打开鸿学伴对应主题；保存屏幕录制、时间、设备和版本信息。

### 4. 系统入口与原生体验打磨

先修正现有系统卡片/提醒的指定主题跳转：校验后执行卡片或提醒中展示的受限动作；“打开当前今日推荐”若需要，应作为另一种明确入口设计，避免混淆。冷启动、热启动和重复点击均需验证。之后根据官方 Intents Kit 规则实现系统意图，不把普通 Want 的 `source` 字符串当作系统身份。朗读能力单独做课程讲解页的最小实验，并以设备支持和实机效果决定是否保留。这些 App 内工作可与云 A2A 协议核验并行。

### 5. 完成后再更新作品说明

只把已跑通并留有设备证据的能力写成已实现；未联调的路径不进入功能成果。重新采集同一版本模拟器与真机素材，然后继续编辑当前本地 HTML 草稿，最终再按官方模板规格导出 PDF 并合并团队原始签名页。

## 用户仅需处理的账户动作

现在无需立即“确认创建”。协议与平台资格核实后，开发者审阅协议/隐私调查、按需创建项目并配置真机测试权限。届时只需提供**不含密钥**的平台字段名称与错误提示；凭据只放入安全环境配置。若设备真机不可用，可先用平台 Web 调试，但不宣称系统入口已落地。

## 官方资料

- 小艺平台与开发模式：https://developer.huawei.com/consumer/cn/hag/hagindex.html#/
- 云 A2A 模式：https://developer.huawei.com/consumer/cn/doc/service/cloud-a2a-0000002640266052
- 云 A2A 协议：https://developer.huawei.com/consumer/cn/doc/service/agent2agent-comments-0000002500412353
- 云 A2A 消息定义：https://developer.huawei.com/consumer/cn/doc/service/agent2agent-define-0000002467293060
- 发起会话与 SSE 事件：https://developer.huawei.com/consumer/cn/doc/service/message-stream-0000002505761434
- 终止会话：https://developer.huawei.com/consumer/cn/doc/service/tasks-cancel-0000002537561193
- 官方真机白名单：https://developer.huawei.com/consumer/cn/doc/doccenter-celia/list-of-user-groups-for-real-machine-testing-0000002471264273
- Intents Kit：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/intents-introduction
- Core Speech Kit：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-speech-introduction
- Data Augmentation Kit 端侧问答：https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/dataaugmentation-localchatmodel-api
- 上架流程及私有云插件限制：https://developer.huawei.com/consumer/cn/doc/doccenter-celia/process-introduction-0000002509696971
