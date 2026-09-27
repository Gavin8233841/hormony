# 鸿学伴开发代理规范

本文件适用于仓库根目录及全部子目录。若子目录以后新增 `AGENTS.md`，离目标文件最近的规范优先；用户在当前任务中的明确指令优先于仓库规范。

## 1. 开始工作前

1. PowerShell 涉及中文时先设置 UTF-8：

   ```powershell
   $OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
   ```

2. 必须先执行：

   ```powershell
   git status --short
   git log -5 --oneline
   ```

3. 读取与任务直接相关的源码、配置和测试。不得凭记忆猜测键名、路径、字段、模型 ID、Bundle Name、API 响应或命令参数。
4. 项目交接任务还需读取：
   - 当前复赛入口：`docs/SEMIFINAL-IMPLEMENTATION-HANDOFF.md`（2026-09-25；先读本机状态、规则、已定方案和工具入口，再按批次读关联资料，避免重复全量调研）
   - `docs/CODEX-HANDOFF-HARMONY-1.1.md`
   - `docs/MODEL-ROLLOUT-STRATEGY.md`
   - `docs/FRONTEND-RESOURCE-ADOPTION.md`
   - `DEVLOG.md` 末尾相关记录
5. 文档与当前源码冲突时，以当前 `HEAD`、构建配置、源码和可执行测试为准，并修正文档，不得为迁就旧文档回滚有效实现。
6. 查找文件或文本优先使用 `rg --files` 和 `rg`。无法从仓库取得精确信息时，停止相关改动并向用户询问。
7. 不得猜测标识符的大小写、格式或层级，不得用 `candidate` 等含糊词代替核验结论。

## 2. 文件与 Git 安全红线

### 2.1 禁止的破坏性操作

未经用户逐项确认，禁止执行任何批量、递归、通配符删除或破坏性恢复，包括但不限于：

- `del /s`
- `rd /s`
- `rmdir /s`
- `Remove-Item -Recurse`
- `Remove-Item` 配合通配符
- `rm -rf`
- `git clean`
- `git reset --hard`
- `git checkout -- .`
- 清空目录、磁盘、回收站或构建缓存

删除文件时每次只能删除一个已检查绝对路径的明确文件。不得删除目录。确需批量清理时，先列出全部绝对路径并等待用户明确确认。

- 不得修改工作区之外的文件，除非用户明确指定绝对路径。
- 不得批量覆盖、移动或重命名文件。
- 需要隔离文件时优先移动到工作区内明确的备份位置，并先取得用户确认，不直接永久删除。

### 2.2 保留并行工作

- 工作区默认可能包含用户、Codex、Trae 或其他工具的未提交改动。
- 不得回滚、覆盖、格式化、移动或提交不属于当前任务的改动。
- 开始和提交前都要重新检查 `git status --short`。
- 只允许使用明确文件路径暂存；禁止 `git add .`、`git add -A` 和通配符暂存。
- 并行任务必须先约定互不重叠的文件边界。发现文件已被另一方修改时停止编辑该文件并协调。

### 2.3 永不提交

- `.env`、`.env.local`、`.env.*.local` 和任何凭证文件
- API Key、Vercel Token、Authorization 值、私钥、签名材料
- `.trae/progress.json`
- `.runtime/`、构建缓存、HAP、日志和本地 IDE 配置
- `screenshots/` 下的本地验收证据，除非用户明确要求纳入版本库
- `assets/`、展示站、压缩包、工具调查等与当前提交无关的资产

## 3. 项目架构不变量

### 3.1 产品边界

- `apps/harmonyos` 是竞赛移动端交付物；`apps/web` 同时承载 Web 界面和云端 API。
- 生产云端按无状态服务设计。画像、计划、课程进度、答题结果、错题、连续学习和最近对话以 HarmonyOS 端 ArkData 为持久状态源。
- 不得为了让 Web 看起来可用而把端侧私有状态偷偷迁回进程内存或无持久保障的云端文件。
- 不得使用静态回复、本地模板、随机结果或测试替身伪造真实 Agent、模型调用或线上验收成功。

### 3.2 Agent 与模型

- 模型调用、超时、取消和运行信息集中在 `apps/web/src/lib/agents/model.ts`。
- Agent 编排集中在 `apps/web/src/lib/agents/orchestrator.ts`；不得在 API 路由或页面复制一套编排。
- Safety 必须覆盖用户输入和模型输出，不得因单测、演示或降级路径绕过。
- 当前生产模型 ID 以 `docs/MODEL-ROLLOUT-STRATEGY.md` 和部署环境的精确值为准。不得根据显示名、认证失败或相似字符串推断模型 ID。
- 模型切换只通过服务端环境变量和明确发布流程完成；切换后必须验证 Health、Chat SSE、Plan、Quiz 及端侧调用。
- 禁止把服务端秘密放入 `NEXT_PUBLIC_*`、客户端组件、HAP、日志或错误响应。

### 3.3 API 契约

- 所有外部输入在进入 store、RAG、Agent 或模型前必须完成运行时结构、长度、枚举和数量边界校验。
- 非对象 JSON、非法嵌套数组和未知枚举必须返回明确 4xx，不得因字段访问变成 500。
- 既有错误响应保持 `{ error, code }`；客户端必须保留 HTTP 状态和精确错误码。
- `/api/chat` 使用 SSE。事件类型、顺序和错误边界以 `StreamEvent` 与路由测试为准，不得把流式错误改成伪造的成功正文。
- Quiz 展示题不得在 `questions` 中泄露答案和解析。HarmonyOS 本地评分所需 `grading` 是单独字段，不得合并回展示题结构。
- API 成功响应结构如需统一，必须同步修改所有消费方并增加路由级测试；禁止只改服务端或只改类型断言。
- CORS、限流、安全头和无状态接口拦截统一由 `apps/web/src/middleware.ts` 管理。

### 3.4 数据单一来源

- Web 题库源文件是 `apps/web/src/lib/data/quizzes.ts`。
- HarmonyOS 题库产物通过 `scripts/generate-quizzes-json.mjs` 生成；禁止手工分别维护两份题库。
- 题库必须覆盖真实 33 个 Topic，每个 Topic 至少 5 道选择题；源数据与端侧 JSON 必须由完整字段一致性测试约束。
- `topic-relations.json` 必须通过 `scripts/validate-topic-relations.py` 的唯一性、引用、DAG、连通性、层级和 Topic 一致性校验。
- 知识切片在 Web 与 HarmonyOS 同时存在时必须同步修改，并以测试或精确比对证明一致。
- 内容事实、协议、模型、依赖版本和 API 能力必须查阅一手资料；不得把“未访问 URL”“静态格式正确”写成“资源可用”。

## 4. Web 开发规则

- 包管理器固定使用 `pnpm`，不得混用 `npm install` 或生成其他锁文件。
- TypeScript 保持 strict；不得用扩大 `any`、无验证的类型断言或关闭检查掩盖问题。
- React 页面不得把非 2xx 响应当成功数据；请求取消不显示为业务错误；加载、空态、失败和 `ENDPOINT_DISABLED` 必须区分。
- 服务端模块不得被客户端组件导入。环境变量默认只在服务端读取。
- 新依赖必须说明现有代码无法满足的具体能力、许可证、维护状态、包体影响和回退方案；一次只引入一个依赖并完成构建与运行验证。
- 优先复用现有零依赖实现，不新增重复的请求层、状态库、工具库、弹窗库或图表库。

Web 变更的最低验证：

```powershell
cd apps/web
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

只改文档时可不执行生产构建，但必须说明未执行原因。

## 5. HarmonyOS 开发规则

- 当前目标配置为 HarmonyOS API 26：`compatibleSdkVersion` 和 `targetSdkVersion` 均为 `26.0.0`。这是用户批准的复赛原生导航升级；后续调整版本仍需核对 SDK 与实际运行证据。
- 遵守 ArkTS 静态类型约束：对象字面量使用明确类型，不依赖运行时增删属性，不照搬不兼容的 JavaScript 动态模式。
- UI 优先 ArkUI 原生组件、系统 Symbol、现有设计令牌和公共 Builder；底部原生 Tabs 使用已核对许可的 Phosphor 导航 SVG。不得用 ArkWeb 承载原生页面或庆祝动画。
- 学生端文案采用正常学习 App 的用户视角：标题说清内容，状态说清当前情况，按钮用简短的“动词＋对象”（如“练习图遍历”“查看错题”“继续学习”）。待办或推荐直接写成“待复习”“接着练”等可行动状态，不写“下一步：先……再……”式流程解说。
- 不把 Agent 推理、开发验收或数据实现写进界面。避免“证据／依据／闭环／真实记录／本机写入／未计数互动”等内部话术，以及重复解释按钮效果的长句；必要的题目条件、来源、隐私和错误信息保留。新增和修改页面须逐屏朗读主标题、按钮、结果、空态及失败提示，删去机械化与重复文字，再用实际 UI 截图检查截断和信息层级。
- 模型生成的计划标题、理由、题目和回答也按同一标准审视。计划卡优先呈现待办、课程和时间；无法核实的生成理由不直接当作学习建议展示。加载状态只说用户需要知道的进度，不展示 Agent 分工或内部校验步骤。
- 本地状态通过现有 Repository 和 ArkData 访问，不在页面复制数据库逻辑。
- 修改 schema 必须提供向前迁移，保留已有用户数据，禁止以清库代替迁移。
- 页面、路由、Ability、FormExtensionAbility 和系统 Kit 调用必须核对项目源码与官方 SDK，不得猜写生命周期或 API。
- 当前 `oh-package.json5` 无第三方依赖。OHPM 源、版本和 API 26 兼容性未验证时不得写入依赖或猜写组件 API。
- OCR、TTS、Lottie 和分布式数据等需要真机的能力，在获得真机证据前只能标记“未验证”，不得标记通过。

HarmonyOS 验证顺序：

1. CLI 增量构建优先，不执行 clean。
2. CLI 环境与 DevEco 当前 SDK 不一致时，先读取实际路径；必要时使用 DevEco MCP 构建，不修改用户级环境来掩盖问题。
3. ArkTS 诊断、安装运行、UI 树和截图使用 DevEco MCP。
4. UI 流程使用 `scripts/harmonyos-app-smoke.ps1`，点击坐标必须来自 UI 树 bounds，不写死设备坐标。
5. 视觉结论必须注明设备、窗口方向、分辨率和证据路径。只读源码不能证明横屏、平板、安全区或真机渲染通过。

推荐构建目标为 `entry@default` 的 debug HAP；命令参数必须先从当前 Hvigor 帮助、构建配置或 DevEco 工具读取。

## 6. 主代理与委派代理边界

### 6.1 仅主代理或用户明确授权后修改

- `apps/web/src/lib/agents/**`
- `apps/web/src/app/api/**`
- `apps/web/src/middleware.ts`
- 模型、安全、RAG 核心和数据库迁移
- `apps/harmonyos/entry/src/main/ets/common/**`
- `apps/harmonyos/entry/src/main/ets/model/**`
- HarmonyOS 页面、导航、设计令牌、Ability 和卡片生命周期
- 顶层构建配置、部署配置、依赖和 Git 历史

修改这些区域前必须读取调用方和测试，改后执行相应全套验证。

### 6.2 Trae 或其他委派代理默认允许

- 用户明确指定的数据扩充
- 生成脚本和无破坏性冒烟脚本
- 纯前端页面内的加载、空态、失败态和可访问性完善
- 只读审计、资料核验和结果文档
- 主代理预先划定的独立文件范围

委派代理默认不得修改上一节的核心区域，不得提交或推送 Git。完成后提供文件清单、命令、退出码、失败项和证据，由主代理逐文件复核后采用。

## 7. 证据与审计标准

结论必须使用以下明确等级，不使用含糊措辞：

- **源码确认**：只证明代码或配置存在。
- **静态诊断通过**：只证明 lint、类型或 ArkTS 检查通过。
- **构建通过**：只证明产物成功生成。
- **模拟器通过**：必须有具体流程和 UI/日志证据。
- **真机通过**：必须记录设备和真实运行证据。
- **线上通过**：必须记录端点、HTTP 状态、业务字段和不含秘密的时间信息。
- **未验证**：没有对应层级证据时必须明确写出。

认证失败只能证明认证或权限失败，不能证明模型、包或 API 不存在。HTTP 200 也不能单独证明业务成功，必须校验响应结构和关键字段。

## 8. DEVLOG、提交与交付

- 主代理每个可提交批次向 `DEVLOG.md` 追加：背景、文件、行为变化、验证命令、退出码、失败或未验证项。
- 并行委派代理不得同时修改 `DEVLOG.md`；先写独立结果文档，由主代理复核后汇总。
- 提交前必须执行：

  ```powershell
  git diff --check
  git status --short
  git diff --cached --name-only
  ```

- 对暂存内容执行敏感信息扫描。扫描命令本身不得打印环境变量值。
- 提交必须只包含一个清晰主题。主代理验证通过后精确提交并推送当前分支；不得把无关工作树内容一起提交。
- 最终汇报必须列出：完成内容、验证结果、提交哈希、推送状态、保留的未提交文件和仍未验证的事项。

## 9. 外部规范依据

- AGENTS.md 开放格式与分层说明：<https://agents.md/>
- Next.js 环境变量与客户端暴露规则：<https://nextjs.org/docs/pages/guides/environment-variables>
- Next.js 自托管与反向代理安全边界：<https://nextjs.org/docs/app/guides/self-hosting>
- OWASP API Security Top 10 2023：<https://owasp.org/API-Security/editions/2023/en/0x00-header/>
- OWASP 第三方 API 输入、超时和资源限制：<https://owasp.org/API-Security/editions/2023/en/0xaa-unsafe-consumption-of-apis/>
- HarmonyOS ArkTS 语言与静态约束：<https://developer.huawei.com/consumer/cn/arkts/>
- HarmonyOS 应用开发最佳实践：<https://developer.huawei.com/consumer/cn/best-practices/>
- Hvigor 命令行工具：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-commandline>
- Hvigor 增量构建：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-incremental-build>
