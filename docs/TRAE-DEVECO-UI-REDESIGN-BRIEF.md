# Trae 下一阶段指令：DevEco Code + HarmonyOS 端产品化重设计

> Codex 编写于 2026-06-27。Trae 执行前必须先读本文档，再读 `docs/TRAE-DEVELOPMENT-BOUNDARIES.md`。本阶段目标是把鸿蒙端从“能跑的功能骨架”推进到“可展示的用户端 App 原型”。

---

## 一、先统一项目定位

当前项目有两端：

1. **Web 端**
   - 角色：服务端 / 调试台 / 管理后台。
   - 作用：放模型调用、RAG、Agent 编排、课程数据、API。
   - 不作为最终参赛主界面。
   - 不继续投入大量视觉设计，只保持可调试、可演示即可。

2. **HarmonyOS 端**
   - 角色：参赛作品的用户端。
   - 用户真正看到和操作的是鸿蒙 App。
   - 下一阶段重点全部转向 HarmonyOS 端体验。

用户已经明确：当前界面“太丑”，不能接受。这是合理反馈。本阶段必须把 UI 产品化，而不是继续堆功能。

---

## 二、当前状态摘要

最新已知提交：

- `e2ba3bf docs: 可视化演示 — Web 端 + 鸿蒙端模拟器截图 9 张 + DEVLOG 记录`
- `bac7d32 feat: Web 课程页/画像页接入真实 API + 加载态/错误态/空态`
- `8380817 docs: DevEco MCP 自证可用 + 6 个 ArkTS 页面跳转链路只读梳理`
- `4cd3177 docs: 明确 Trae 开发边界与验收线`

当前已完成：

1. Web 后端 8 个 API + Agent 编排 + 模型服务端封装。
2. HarmonyOS 工程可构建，可安装到模拟器。
3. 页面能跳转，能截图，能导出 UI 树。
4. DevEco Studio 已打开工程，用户能看到项目，不再是盲盒。
5. DevEco Code 已安装，右侧面板能看到 Skills / Tools。

当前问题：

1. HarmonyOS 端 UI 仍是临时功能骨架。
2. 首页是深色控制台感，不像正式 App。
3. 页面文字里有过多技术词，如 Agent、RAG、Profile、Retrieval。
4. 统计卡片显示 `--`，运行态数据链路还需确认。
5. Web 端不是重点，不要把时间耗在 Web 美化上。
6. `apps/web/package.json` 有包管理器自动写入的 `packageManager` 字段改动，处理前不要混入 UI 提交。

---

## 三、DevEco Code 必须使用

Trae 不要只用普通终端。当前本机已安装：

```powershell
deveco --version
```

已确认版本：

```text
0.1.0
```

DevEco Code 官方说明中明确它面向 HarmonyOS 开发，支持代码编写、编译构建、设备运行、文档查阅、运行时调试、ArkTS 问题修复。

Trae 必须在 DevEco Studio / DevEco Code 中使用以下能力：

1. **Skills**
   - `arkui-knowledge`：写或改 ArkUI 页面前必须使用。
   - `arkts-grammar-standards`：写或改 `.ets` 前必须使用。
   - `arkts-error-fixes`：编译或类型检查报错后使用。
   - `arkts-runtime-fix`：模拟器白屏、崩溃、点击无效、日志异常时使用。

2. **Tools**
   - `knowledge`：查 HarmonyOS / ArkUI 官方知识，不猜 API。
   - `check`：ArkTS 语法检查。
   - `build`：编译构建。
   - `run`：安装并启动到模拟器/真机。
   - `log`：运行期日志。

3. **UI 检查**
   - 如 DevEco Code UI 检查可用，必须对改版页面做截图或 UI 检查。
   - 如不可用，必须用 DevEco MCP 或手动模拟器截图补齐证据。

---

## 四、DevEco Code 操作方法

在 DevEco Studio 中：

1. 打开工程目录：

```text
C:\Users\guo82\Desktop\Hormony\apps\harmonyos
```

2. 打开右侧 CodeGenie / DevEco Code 面板。
3. 确认 Skills 页面能看到：

```text
arkui-knowledge
arkts-grammar-standards
arkts-error-fixes
arkts-runtime-fix
```

4. 确认 Tools 页面能看到：

```text
check
build
run
log
knowledge
```

5. 每次改 UI 前，先在 DevEco Code 里明确要求：

```text
使用 arkui-knowledge 和 arkts-grammar-standards。请先读取当前页面源码，不要猜 ArkUI API。目标是把页面改成 HarmonyOS 原生学习助手风格，保持业务逻辑不变。
```

6. 每次改完后执行：

```text
check 当前修改的 .ets 文件
build entry@default debug
run 到当前已打开模拟器
截图
```

如果 `run` 不能自动启动模拟器，则先请用户手动打开模拟器，再继续。

---

## 五、HarmonyOS 端设计方向

产品名：**鸿学伴**

产品感觉：

- 校园学习助理
- 轻量、清爽、可信
- 不像程序员后台
- 不像 Web 控制台
- 不用大片深色蓝黑
- 少用英文 Agent 术语

建议主题：

- 主色：鸿蒙蓝 / 青蓝，少量绿色表达完成与进度。
- 背景：浅色或柔和渐变，不要全黑。
- 卡片：8-16px 圆角即可，间距统一。
- 字体层级：标题清楚，说明文字少而短。
- 图标：使用 ArkUI / 系统图标或简洁符号，避免随意色块。

信息架构：

1. 首页不叫“学习仪表盘”，改成更用户化：
   - `今天学什么`
   - `鸿学伴`
   - `我的学习`

2. 首页优先展示：
   - 今日学习任务
   - 继续学习课程
   - 向 AI 提问入口
   - 课程进度
   - 知识库搜索入口

3. 不在首页展示“多 Agent 协作架构”。
   - Agent 架构是评委材料和技术说明，不是普通用户首页内容。
   - 如要展示，放到“技术说明”或隐藏的演示页。

4. 页面文案替换：

| 当前文案 | 建议文案 |
|----------|----------|
| AI 对话辅导 | 问问鸿学伴 |
| Tutor Agent | AI 助教 |
| Planner Agent | 学习计划 |
| RAG 检索 | 搜课程资料 |
| Profile Agent | 学习画像 |
| Retrieval Agent | 资料检索 |
| Safety Agent | 安全审核 |

---

## 六、第一批 UI 改版范围

第一批只改 2 个页面，不要一次改全项目：

1. `apps/harmonyos/entry/src/main/ets/pages/Index.ets`
2. `apps/harmonyos/entry/src/main/ets/pages/Course.ets`

目标：

1. 首页变成能展示给用户看的 App 首页。
2. 课程页变成清爽课程列表，不再像数据卡片堆叠。
3. 保持现有路由和 API 逻辑，不做 Navigation 迁移。
4. 不新增依赖。
5. 不动 Web 后端。
6. 不动模型代码。

改版后必须截图给用户确认，再决定是否继续改 Chat / Plan / Knowledge / Profile。

---

## 七、验收标准

每轮 UI 改版必须满足：

1. ArkTS 检查无 Error。
2. HAP 构建成功。
3. 模拟器能启动应用。
4. 至少提供以下截图：
   - 首页
   - 改版页面
   - 点击进入页面后的截图
5. 截图必须保存在：

```text
screenshots/harmonyos/
```

6. DEVLOG 必须记录：
   - 使用了哪些 DevEco Code skills
   - 使用了哪些 tools
   - 修改了哪些文件
   - 截图路径
   - 是否仍有运行态问题

7. 提交前运行：

```powershell
git diff --check
git status --short
```

8. 提交中不得混入：
   - `apps/web/package.json` 的自动 `packageManager` 改动
   - `.env.local`
   - 生成缓存
   - 模型密钥

---

## 八、当前禁止任务

Trae 本阶段不要做：

1. 不做 Web 端美化。
2. 不做知识库上传接口。
3. 不做模型 API 改动。
4. 不做 router → Navigation 迁移。
5. 不做服务卡片、通知、元服务实现。
6. 不做签名配置。
7. 不一次性重写所有 ArkTS 页面。

这些任务等 Codex 评审第一批 UI 改版截图后再决定。

---

## 九、给 Trae 可直接复制的启动提示词

```text
请先阅读 docs/TRAE-DEVECO-UI-REDESIGN-BRIEF.md 和 docs/TRAE-DEVELOPMENT-BOUNDARIES.md。

当前阶段不是继续堆功能，而是把 HarmonyOS 用户端从临时功能骨架改成可展示的鸿蒙 App 原型。Web 端是服务端/调试台，不是参赛主界面，暂不做 Web 美化。

请使用 DevEco Code 的 arkui-knowledge、arkts-grammar-standards、arkts-error-fixes、arkts-runtime-fix skills，并使用 knowledge/check/build/run/log tools。不要只靠普通终端。

第一批只改两个页面：
1. apps/harmonyos/entry/src/main/ets/pages/Index.ets
2. apps/harmonyos/entry/src/main/ets/pages/Course.ets

目标：
- 首页改成用户能看懂的“鸿学伴/今天学什么/我的学习”风格。
- 去掉首页的多 Agent 架构展示，不在普通用户首页堆技术词。
- 课程页改成清爽课程列表。
- 保留现有 router 跳转和 API 逻辑，不做 Navigation 迁移。
- 不新增依赖，不动 Web 后端，不动 model.ts / orchestrator.ts / 模型 API。
- 不接触 MODEL_API_KEY。

验收：
- check 修改过的 .ets 文件。
- build entry@default debug。
- run 到用户已打开的模拟器。
- 截图首页和课程页，保存到 screenshots/harmonyos/。
- 追加 DEVLOG，记录使用的 DevEco Code skills/tools、修改文件、截图路径、验收结果。
- 提交前确认 git status 只有本轮 UI 文件、截图和 DEVLOG；不要混入 apps/web/package.json 的 packageManager 自动改动。
```

---

## 十、Codex 的评审口径

Codex 评审第一批 UI 改版时只看四件事：

1. 是否像一个普通用户愿意打开的学习 App。
2. 是否符合 HarmonyOS 端体验，而不是 Web 控制台。
3. 是否保持现有业务闭环不被破坏。
4. 是否有模拟器截图和构建证据。
