# WS01 学伴与计划真实闭环结果

- 日期：2026-07-17
- 分支：`codex/ws01-chat-plan`
- 基线：`dd2fe16 docs: 新增鸿蒙2.0接力文档`
- 主责：HarmonyOS `Chat.ets`、`Plan.ets` 及直接 HTTP 依赖

## 问题与根因

历史模拟器证据中，UI 树能看到 TextInput 文本，但发送按钮仍按空的 `@State inputText` 计算，点击后没有进入 `sendMessage()`，网关也没有收到 `POST /api/chat`。源码中的输入值采用普通 `text: this.inputText`，自动化输入改变了原生输入框显示值，却没有形成可供按钮读取的可靠状态提交。

本批改为 `text: $$this.inputText` 双向绑定，并按 API 12 已编译通过的 `onSubmit(EnterKeyType, SubmitEvent)` 读取 `event.text`。按钮和键盘提交现在都进入同一个 `sendMessage -> HttpClient.postSSE` 路径。由于当前 `hdc list targets` 返回 `[Empty]`，该根因修复已达到源码确认和构建通过，端侧实际点击后的 POST 仍为模拟器未验证。

Plan 的旧实现还存在三个闭环缺口：生成开始即隐藏旧任务；等待阶段由固定时间推进而不是由真实操作推进；计划生成完成后若 ArkData 保存失败，只能重新调用模型。当前实现分别改为保留旧计划、按真实操作更新阶段、缓存已校验计划并只重试本机保存。

## 行为变化

### Chat

- TextInput 使用双向绑定；按钮与键盘提交均使用当前真实文本。
- 请求代次隔离本机画像读取、SSE 事件、结束和错误回调；旧请求不能污染下一问。
- SSE `error`、缺失 `done`、空正文、网络错误和取消均有独立可见状态；错误详情折叠显示 HTTP 状态和精确业务错误码。
- 取消令牌贯穿 SSE 请求和备用地址；首包前取消后不再尝试 fallback POST。
- 非 2xx SSE 响应等待状态码和响应体都到达后，结构化解析 `{ error, code }`，与正常 `done` 路径互斥。
- 只有完整的 user/assistant 问答对进入下一问上下文和 ArkData；失败、取消、流式残片及其孤立问题均排除。
- 历史读取失败与保存失败分开处理：读取失败只允许重新读取，避免空历史覆盖；保存失败可独立重试。
- 历史写入串行合并，旧快照不会在新回答之后完成并覆盖最新问答。
- 本机历史恢复、保存中、保存成功和保存失败显示在固定高度状态区。
- 复用现有 Markdown Builder：引用可折叠，代码可横向滚动并可继续提问，窄屏表格转换为可读分组，原表格 Builder 仍保留。

### Plan

- 初始 ArkData 读取期间锁定输入和生成；读取代次失效后不再更新已离开的页面。
- 每次生成在第一个 `await` 前冻结目标与周期，避免本机旧计划读取覆盖本次 POST 参数。
- 生成期间保留上一版任务、目标和规划依据；取消、HTTP 失败、端侧校验失败或本机保存失败均不清空旧计划。
- 阶段只在真实操作开始时推进：读取本机状态、在线规划、端侧检查、本机保存、入口更新；长等待计时只改变提示，不伪造阶段完成。
- 网络阶段可取消且不会重试备用地址；进入 ArkData 保存后禁用取消和页面内返回。
- 已校验计划保存失败时保留 `pendingPlan`，点击“重试保存”不会再次调用模型。
- HTTP 状态和 `GOAL_TOO_LONG`、`INPUT_REJECTED`、`SAFETY_BLOCKED` 等精确错误码可折叠查看，主文案保持学生可读。
- 本机保存成功后更新 `@StorageLink('currentPlanTasks')`，首页可立即读取；同时调用现有 `LearningFormUpdater.refreshAll()` 发起服务卡片更新。
- 键盘在生成前通过已编译的 `TextInputController.stopEditing()` 收起，列表和等待区增加底部安全区。

### HttpClient

- 普通 POST 支持 `HttpRequestCancellation`，取消后销毁请求且不再尝试备用地址。
- GET、POST、PATCH 的非 200 响应结构化保留 HTTP 状态、`code` 和安全错误摘要。
- SSE 非 2xx 响应保留响应体错误码，并保证 `onDone` 与 `onError` 互斥。

## 提交文件

- `apps/harmonyos/entry/src/main/ets/common/HttpClient.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Chat.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Plan.ets`
- `scripts/test-ws01-chat-plan-source-contract.mjs`
- `docs/workstreams/01-chat-plan-result.md`
- `DEVLOG.md`

## 可执行回归保护

第二批新增 `scripts/test-ws01-chat-plan-source-contract.mjs`，使用 Node 内置测试运行器读取当前 ArkTS 源码，并按方法边界、调用顺序和负向断言保护七组 P0 契约：

1. TextInput 双向绑定、`SubmitEvent.text` 和按钮输入最终进入真实 `Constants.API_CHAT` SSE 请求。
2. 普通 POST 与 SSE 取消均先于备用地址重试退出。
3. SSE done、HTTP error、结构化状态码与业务错误码终态互斥。
4. 失败、取消和流式残片不进入 ArkData，历史写入串行合并。
5. 引用折叠、代码横向阅读、表格原生展示与窄屏可读降级同时保留。
6. Plan 读取代次、请求参数冻结、旧计划保留，以及保存失败只重试 ArkData。
7. Plan 长等待节点、取消边界、键盘收起和底部安全区保持可观察。

该测试不替代模拟器交互、网络抓包或 ArkData 重启验证；它用于在无 HDC 目标时阻止已确认控制流被后续改动静默回退。

## 旧提交选择性复核

- `ffe0e85`：当前 `Chat.ets` 已有代码语言标签、行号、横向滚动和“解释这段”入口，保留当前实现，不整提交合并。
- `23fdeb5` 与 `bd11a54`：当前实现已将连续表格合并为表格块，提供原生横向表格和窄屏分组阅读，保留当前解析与 Builder，不覆盖本批 SSE/历史状态机。
- `62a31d5`：该提交的 Span 行内解析不在本批真实闭环范围；当前 `cleanInline` 与 Markdown Builder 已通过 HAP 构建，未在无设备视觉证据时替换整套解析器。
- `4ee53b8`：旧计划保留、计划进度和规划依据在当前 `Plan.ets` 中已有等价且更完整的失败保存恢复路径，保留当前实现。
- `2208dca`：页面侧目标建议和生成恢复已由当前实现覆盖；其通用冒烟脚本改动归 WS06，本批不移植、不暂存。

## 验证证据

| 等级 | 命令或流程 | 结果 |
| --- | --- | --- |
| 源码确认 | 17 项 Chat/Plan/HttpClient 源码不变量断言 | exit 0，`SOURCE_INVARIANTS_OK count=17` |
| 静态诊断通过 | `node --check scripts/test-ws01-chat-plan-source-contract.mjs` | exit 0 |
| 静态诊断通过 | `node --test scripts/test-ws01-chat-plan-source-contract.mjs` | exit 0，7/7 通过 |
| 静态诊断通过 | `git diff --check`（WS01 三个产品文件） | exit 0，仅 Git 的 LF/CRLF 工作区提示 |
| 构建通过 | `cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` | exit 0，`CompileArkTS`、`PackageHap` 成功，最终 `BUILD SUCCESSFUL in 27 s 625 ms`；未配置 signingConfigs 的既有警告保留 |
| 线上通过 | `GET https://hormony-ruddy.vercel.app/api/health` | HTTP 200；`status=ready`、`deploymentMode=stateless`、`model.configured=true`、`model.mode=model`、`model.name=doubao-seed-2-1-pro-260628` |
| 线上通过 | `POST https://hormony-ruddy.vercel.app/api/chat` | HTTP 200；12 个 SSE 事件，顺序为 thinking/trace/delta/citation/done；正文 1745 字符、引用 3 条、`done=1` 且最后一帧为 done、无 error；正文含代码围栏和表格分隔符 |
| 线上通过 | `POST https://hormony-ruddy.vercel.app/api/plan` | HTTP 200；目标匹配，10 项任务，必需字段检查无失败，`agentTrace=4` |
| 线上通过 | Chat 2001 字符边界 | HTTP 400；`code=MESSAGE_TOO_LONG`，`error` 非空 |
| 线上通过 | Plan 501 字符目标边界 | HTTP 400；`code=GOAL_TOO_LONG`，`error` 非空 |
| 未验证 | `hdc list targets` | exit 0，返回 `[Empty]`；无模拟器或真机运行目标 |

首次引入结构化 SSE 错误类时，ArkTS 报 `arkts-no-structural-typing`，该次为构建失败。已改为名义类型明确的 `HttpStreamError`，随后多次增量构建通过，失败未被记作通过证据。

## 共享文件后续补丁

### WS04 `LearningFormUpdater.ets`

主线程已明确该文件归 WS04，提交 `a3d2ad4` 的实现基于 `ProactiveLearningService`，因此本 worktree 中基于旧版文件的计数 diff 不得直接提交或移植。主线集成 `a3d2ad4` 后应在其实现上补：

1. 新增 `LearningFormRefreshResult`，字段为 `registeredCount`、`updatedCount`、`failedCount`、`registrationReadFailed`。
2. `refreshAll()` 保留 WS04 的主动学习动作解析，逐个统计卡片更新成功与失败，并区分读取已注册卡片 ID 失败。
3. Plan 再根据真实结果显示“未添加卡片”“更新 N 张”“部分失败”，部分失败只重试卡片刷新，不重新调用模型或重写计划。

当前 Plan 只声明“已发起服务卡片更新”，没有把不可观察的 void 返回伪装成同步成功。

### WS06 `scripts/harmonyos-app-smoke.ps1`

该通用脚本归 WS06，本批不提交现有工作区 diff。主线续批应移植 Plan 流程并把阶段断言更新为当前精确文案：

- `正在读取本机学习状态`
- `正在在线安排学习节奏`
- `正在检查每项任务`
- `正在保存到本机`
- `正在更新学习入口`

Chat 冒烟还需从 UI 树 bounds 输入新问题，验证发送按钮状态、网关真实 `POST /api/chat`、SSE `done`、引用/代码/表格 UI，并重启应用验证 ArkData 恢复。不得使用固定坐标或仅检查旧历史来代替新问答链路。

## 未验证

- 模拟器：TextInput 新输入到真实 POST、SSE error/done/cancel UI、Plan 慢请求取消与重试、本机保存失败注入、应用重启后的 ArkData 恢复，均因无 HDC 目标未验证。
- 真机：全部未验证。
- 服务卡片更新数量与失败回执：等待 WS04 文件集成后未验证。
- Web 源码未修改，未重复执行 Web `pnpm lint/typecheck/test/build`。
- 没有把 HAP、日志、截图、`.tmp`、`assets` 或任何秘密材料纳入提交。
