# DevEco Code 平台能力参考文档

> **创建时间**: 2026-06-27
> **创建者**: Trae (Claude)
> **研究方法**: 深度调研 DevEco Code/CLI/MCP 官方文档 + 社区资源 + 源码分析报告
> **目标**: 最大化利用 DevEco 平台提高鸿学伴 App 开发效率

---

## 一、平台架构总览

### 1.1 产品关系

| 产品 | 性质 | 状态 |
|------|------|------|
| **DevEco Studio** | IDE（集成开发环境） | 持续演进，26.0 Beta 内嵌 DevEco Code |
| **DevEco Code** | 终端 AI Agent 工具（HDC 2026 发布） | 当前最新，基于毕方大模型 + OpenCode |
| **DevEco CLI** | 命令行工具链，原生 MCP 协议 + Skills | 官方开源，未来方向 |
| **DevEco Toolbox** (`@deveco-codegenie/mcp`) | 社区 MCP 服务（**我们当前在用**） | **已进入维护模式**，仅缺陷修复 |

### 1.2 我们当前的工具栈

```
Trae (Claude)  ←→  DevEco MCP (社区版 @deveco-codegenie/mcp v0.2.4)
                         ↓
              DevEco Studio SDK (hvigorw / hdc / LSP)
                         ↓
              Pura 90 Pro Max 模拟器
```

### 1.3 迁移路线

- **当前（竞赛阶段）**: 继续用社区 MCP + hvigorw 命令行
- **赛后**: 迁移到官方 DevEco CLI (`npm install -g @deveco/deveco-cli`) + DevEco Code

---

## 二、MCP 工具集完整能力（11 个工具）

### 2.1 工具清单

| # | 工具名 | 功能 | 我们已用 | 使用频率 |
|---|--------|------|----------|----------|
| 1 | `harmonyos_knowledge_search` | 查询鸿蒙云端知识库 | ✅（返回空，云端问题） | 低 |
| 2 | `check_ets_files` | .ets 静态语法检查（LSP） | ✅（管道错误，降级到 build） | 中 |
| 3 | `check_cpp_files` | .cpp 静态语法检查 | ❌ | 低 |
| 4 | `build_project` | 编译构建（Hap/App） | ✅（主力验证工具） | 高 |
| 5 | `start_app` | 安装+启动到模拟器/真机 | ✅ | 高 |
| 6 | `perform_ui_action` | 点击/滑动/输入/按键/截图 | ✅ | 高 |
| 7 | `get_app_ui_tree` | 获取 UI 树（Full/Simple） | ✅ | 中 |
| 8 | `get_hilog_or_faultlog_recent` | 获取 hilog/faultlog 日志 | ✅ | 中 |
| 9 | `project_sync` | 项目同步（ohpm + hvigor） | ✅ | 低 |
| 10 | `verify_ui` | 自然语言 UI 验证（需配 AI 视觉模型） | ❌ **未启用** | 待用 |
| 11 | `init_project_path` | 初始化工程路径 | ❌ | 低 |

### 2.2 关键工具用法

#### build_project（主力验证工具）
```
参数：build_mode (debug/release), clean (bool), module, product, log_path
等效语法检查：当 check_ets_files 管道错误时，build 的 CompileArkTS 阶段可替代
```

#### start_app（部署工具）
```
参数：hvd (设备名), module, ability, target
注意：自动启动模拟器常失败，需手动启动或用 Emulator.exe 命令行
```

#### perform_ui_action（UI 自动化）
```
actionType: click/directionalFling/inputText/keyEvent/screenshot
参数：x/y (坐标), text (输入), key1 (按键), localPath (截图保存路径)
注意：hvd 参数必填（多设备时）
```

#### get_app_ui_tree（UI 树转储）
```
mode: simple (窗口节点) / full (完整 UI 树含 @State 变量值)
outputDirectory: dump JSON 保存路径
注意：使用时建议关闭 DevEco Studio 避免冲突
```

#### get_hilog_or_faultlog_recent（日志诊断）
```
参数：bundle_name, tag, keyword, level (D/I/W/E/F), is_crash_log (bool)
关键：router.pushUrl 失败时查 E 级日志 "Uri error"
```

### 2.3 官方推荐工具闭环

```
① check_ets_files    → 代码迭代至无语法报错
② build_project      → 编译构建
③ start_app          → 安装并启动
④ verify_ui          → 自然语言测试验证（需配视觉模型）
⑤ 失败 → 定位问题 → 修复 → 重新执行 ①-④
⑥ get_app_ui_tree    → 获取界面全量结点
⑦ save_ui_screenshot → 保存截图复盘
```

**我们的降级容错策略**:
- check_ets_files 管道错误 → 用 build_project 的 CompileArkTS 阶段
- start_app 自动启动模拟器失败 → 用 `Emulator.exe -start 'Pura 90 Pro Max' -noWindow`
- harmonyos_knowledge_search 返回空 → 用 WebSearch 查社区文档 + ArkUI 官方文档 URL

---

## 三、DevEco Code AI Skills（5 个内置技能包）

### 3.1 Skills 清单

| Skill | 功能 | 我们的适用场景 |
|-------|------|----------------|
| **arkui-knowledge** | ArkUI 组件、布局、状态管理、导航、动画 | UI 改版、状态管理设计 |
| **arkts-grammar-standards** | ArkTS 语法限制（与 TS 差异）、装饰器规则 | 避免写出不合规代码 |
| **arkts-error-fixes** | 30+ 常见编译错误修复指南 | 编译报错时快速定位 |
| **arkts-runtime-fix** | 运行时崩溃排查、JS Crash 解析 | 应用闪退诊断 |
| **deveco-create-project** | 新工程模板生成 | 未来新项目 |

### 3.2 Skills 调用方式

Skills **不是 MCP 工具那样直接调用**。它们是 DevEco Code Agent 自动加载的知识/指令包：
- 在 DevEco Code 终端中，Agent 根据任务自动参考
- 在我们的 Trae 环境中，Skills 表现为指令文件约束——在对话中提及 skill 名，AI 即按其约束生成代码
- 华为宣称集成 "70+ 鸿蒙专属 Skill 能力"，核心打包 5 个，其余为扩展

### 3.3 arkts-error-fixes 覆盖的错误类型

涵盖 30+ 种编译错误，每个有独立 .ets 示例 + 修复指南：
- `AnyTypeError` — 使用 any 类型
- `AppStorageError` — AppStorage 使用错误
- `ArrowFunctionConversionError` — 箭头函数转换
- `DecoratorStateError` — 装饰器状态错误
- `ESObjectTypeError` — ESObject 类型错误
- `ObjectLiteralTypeError` — 对象字面量类型
- `PossiblyNullError` — 可能为 null
- `ResourceConversionError` — 资源转换
- `StandaloneFunctionError` — 独立函数
- `UnusedVariableWarning` — 未使用变量
- 等

### 3.4 arkts-runtime-fix 脚本链

```
collect-hilog.mjs     → 从设备收集日志
fetch-faultlog.mjs    → 拉取 faultlogger 记录
parse-jscrash-log.mjs → 解析 JS Crash 日志
probe-faultlogger.mjs → 探测 faultlogger 状态
jscrash-report.mjs   → 报告生成（未注册为 MCP 工具，仅 skill 内部使用）
```

---

## 四、DevEco Studio 其他 AI 能力

| 能力 | 说明 | 我们的使用情况 |
|------|------|----------------|
| 代码补全 | 毕方大模型驱动，ArkTS 上下文补全 | 用户在 DevEco Studio 中手动使用 |
| 代码审查 | Add To Chat 提取编译错误到 AI | 用户手动使用 |
| 知识问答 | CodeGenie RAG 官方文档问答 | 替代 harmonyos_knowledge_search |
| 预览器 | 实时预览 ArkUI 组件/页面 | 用户手动使用 |
| UI Inspector | 可视化 UI 树检查 | MCP get_app_ui_tree 可替代 |
| Profiler | 性能分析 | 未来用于性能优化 |
| FaultLog | 故障日志分析 | MCP get_hilog_or_faultlog_recent 可替代 |

---

## 五、故障排除经验库

### 5.1 check_ets_files 管道错误

**症状**: "Failed to flush stdin: 管道正在被关闭 (os error 232)"
**原因**: DevEco Studio 语言服务冲突或重启后未完全初始化
**解决**: 用 `build_project` 的 CompileArkTS 阶段作为等效语法检查
**状态**: 持续存在，需 DevEco Studio 重启 LSP

### 5.2 harmonyos_knowledge_search 返回空

**症状**: 调用返回 `[]`
**原因**: 华为云端知识库服务波动 / OAuth token 未验证 / 关键词不匹配
**解决**:
1. 用精确 API 名/类名/错误码作为关键词
2. 调大 maxCharSize 参数
3. 持续空结果时判断为服务端问题，改用 WebSearch + 官方文档 URL
**状态**: 云端问题持续，已用替代方案

### 5.3 start_app 自动启动模拟器失败

**症状**: 返回空 `[]`
**原因**: MCP 无法自动冷启动模拟器
**解决**:
```powershell
# 1. 接受许可协议
& 'C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe' -license accept

# 2. 清理残留进程
Stop-Process -Name "emulator-crash-service" -Force -ErrorAction SilentlyContinue

# 3. 启动模拟器（无窗口模式）
& 'C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe' -start 'Pura 90 Pro Max' -noWindow

# 4. 等待 45 秒后验证
& 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets

# 5. 检测到 127.0.0.1:5555 后，用 MCP start_app 部署
```

### 5.4 router.pushUrl URI 错误

**症状**: `router.pushUrl failed: Uri error`
**原因**: URI 用了前导斜杠 `/pages/Chat`，但 main_pages.json 注册的是 `pages/Chat`
**解决**: 去掉前导斜杠，所有 pushUrl 用 `pages/X` 格式
**验证**: hilog E 级日志确认 `call pushUrl with mode: 0, url: pages/Course` 成功

### 5.5 @Builder 事件绑定失效

**症状**: @Builder 内的组件 onClick 不触发
**原因**: @Builder 某些情况下的事件绑定问题
**解决**: 将 @Builder 内容直接内联到 build() 中
**代价**: 代码重复增加，但可靠性提升

### 5.6 corepack 注入 packageManager 字段

**症状**: 每次 pnpm 命令后 `apps/web/package.json` 多出 `packageManager` 字段
**原因**: corepack 自动行为
**解决**: 每次提交前检查并移除该字段

---

## 六、工具链优化建议

### 6.1 当前流程（已优化）

```
代码改写 → hvigorw assembleHap (构建+语法检查)
         → MCP start_app (部署到模拟器)
         → MCP perform_ui_action screenshot (截图)
         → 读取截图自行确认
         → MCP get_hilog_or_faultlog_recent (查日志，如需)
```

### 6.2 可优化方向

| 优化项 | 当前 | 优化后 | 收益 |
|--------|------|--------|------|
| verify_ui 启用 | 未用 | 配置 AI 视觉模型 + 自然语言测试 | 自动化 UI 功能验证 |
| check_ets_files 修复 | 降级到 build | 重启 DevEco Studio LSP | 独立语法检查，更快 |
| 模拟器启动 | 手动 Emulator.exe | 脚本化自动启动+等待+部署 | 减少人工等待 |
| harmonyos_knowledge_search | 返回空 | 等待云端恢复 / 用 CodeGenie 替代 | 官方知识检索 |
| 批量页面验证 | 逐页导航截图 | verify_ui 自然语言批量测试 | 全流程自动化 |

### 6.3 verify_ui 启用方案（待执行）

需要配置 AI 视觉模型：
```
环境变量:
  UI_VERIFY_BASE_URL = <阿里云百炼 endpoint>
  UI_VERIFY_API_KEY = <API Key>
  UI_VERIFY_MODEL_NAME = qwen3-vl (支持 Function Call 的视觉模型)
```

启用后可以用自然语言写测试用例：
```
testPlan: "
1. 首页显示标题「鸿学伴」和副标题「今天学什么？」
2. 点击「问问鸿学伴」，跳转到 AI 辅导页
3. AI 辅导页显示输入框和发送按钮
4. 按返回键回到首页
5. 点击「我的课程」，跳转到课程页
6. 课程页显示至少一个课程卡片
"
```

---

## 七、来源清单

1. 腾讯云 MCP 广场 - DevEco MCP — https://cloud.tencent.com/developer/mcp/server/11809
2. CSDN - DevEco Code & DevEco CLI 配置指南 — https://blog.csdn.net/qiaomu8559968/article/details/161971849
3. 博客园 - DevEco Code 源码分析报告 — https://www.cnblogs.com/getmoon/p/20606515
4. CSDN - DevEco Code 全链路 AI 编程智能体 — https://blog.csdn.net/zjpjay/article/details/162003697
5. 头条 - DevEco Code 到 DevEco CLI — http://m.toutiao.com/group/7655181994561503744/
6. GitHub - open-deveco/deveco-toolbox（社区 MCP 仓库） — https://github.com/open-deveco/deveco-toolbox
7. GitHub - toolbox-instruction.md — https://raw.githubusercontent.com/open-deveco/deveco-toolbox/main/toolbox-instruction.md
8. 掘金 - DevEco-Code & DevEco-CLI — https://juejin.cn/post/7651782338701410350
9. 51CTO - HDC 2026 深度复盘 — https://blog.51cto.com/u_17517821/14704037
10. 华为官方 - CodeGenie 文档 — https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-codegenie-V5
