# DevEco CLI 与 MCP 组合并行工作流

## 设计目标

- 将DevEco MCP工具和DevEco CLI命令整合为统一的并行工作流
- 通过子agent并行处理实现工程效率最大化
- 确保生产工具和生产方式无可优化

## 工具能力矩阵

用表格对比MCP工具和CLI命令的能力：

| 功能 | MCP工具 | CLI命令 | 推荐使用场景 |
|------|---------|---------|-------------|
| 构建 | build_project | hvigorw.bat assembleHap | CLI适合并行构建，MCP适合快速构建 |
| 安装运行 | start_app | hdc install + hdc shell aa start | MCP一键完成，CLI可并行 |
| 截图 | perform_ui_action(screenshot) | hdc shell snapshot_display | MCP更便捷 |
| UI树 | get_app_ui_tree | hdc shell uitest dumpLayout | MCP格式更好 |
| 点击/输入 | perform_ui_action(click/inputText) | hdc shell uitest uiInput | MCP更便捷 |
| ETS检查 | check_ets_files | 无直接等价命令 | MCP独有 |
| 日志 | get_hilog_or_faultlog | hdc shell hilog | MCP过滤更好，CLI适合实时监控 |
| 知识搜索 | harmonyos_knowledge_search | 无 | MCP独有 |
| 项目同步 | project_sync | ohpm install + hvigorw sync | CLI可并行 |

## 并行工作流架构

### 主Agent职责

- 使用MCP工具进行UI交互操作（点击、输入、截图、UI树分析）
- 使用MCP工具进行ETS语法检查和知识搜索
- 协调子agent任务分配

### 子Agent 1: 构建部署Agent (Build & Deploy)

- 使用 hvigorw.bat 构建项目
- 使用 hdc.exe 安装和启动应用
- 适合在主agent编辑代码时并行构建

CLI命令参考：
```
# 构建
cd apps\harmonyos && hvigorw.bat assembleHap --no-daemon

# 安装
hdc.exe -t 127.0.0.1:5555 install entry\build\default\outputs\default\entry-default-unsigned.hap

# 启动
hdc.exe -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.c4ai.hormony
```

### 子Agent 2: 后端验证Agent (Backend Verify)

- 运行 vitest 单元测试
- 运行 tsc 类型检查
- ETS文件审计

### 子Agent 3: 日志监控Agent (Log Monitor)

- 使用 hdc shell hilog 实时监控应用日志
- 捕获崩溃日志
- 过滤关键错误

CLI命令参考：
```
# 实时日志
hdc.exe -t 127.0.0.1:5555 shell hilog

# 崩溃日志
hdc.exe -t 127.0.0.1:5555 shell ls /data/log/faultlog/

# 按包名过滤
hdc.exe -t 127.0.0.1:5555 shell "hilog | grep com.c4ai.hormony"
```

## 并行执行策略

### 场景1: 代码修改→验证循环
```
主Agent: 编辑ETS代码
    ↓ (并行)
子Agent 1: 构建上一个版本（验证回归）
子Agent 2: 运行后端测试
    ↓
主Agent: ETS检查 + MCP构建 + MCP运行 + MCP截图
    ↓ (并行)
子Agent 3: 监控日志捕获运行时错误
```

### 场景2: UI全流程验证
```
主Agent: MCP启动应用 + MCP截图首页
    ↓
主Agent: MCP点击导航 + MCP截图子页面（循环5个页面）
    ↓ (并行)
子Agent 3: 全程监控hilog捕获异常
子Agent 2: 验证后端API响应
```

### 场景3: 多页面并行截图
```
主Agent: MCP截图当前页面
    ↓ (并行)
子Agent 1: CLI截图其他页面（通过hdc shell uitest）
子Agent 2: 分析UI树结构
```

## 效率对比

| 操作方式 | 串行耗时 | 并行耗时 | 提升比例 |
|---------|---------|---------|---------|
| 构建+测试 | ~20s + ~15s = 35s | ~20s（并行） | 43% |
| 5页面截图 | ~25s（串行） | ~10s（并行） | 60% |
| 代码修改+验证 | ~40s（串行） | ~25s（并行） | 38% |

## 关键路径

- DevEco Studio路径: C:\Program Files\Huawei\DevEco Studio\
- hvigorw路径: C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js
- hdc路径: C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe
- ohpm路径: C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat
- 项目路径: C:\Users\guo82\Desktop\Hormony\apps\harmonyos
- 模拟器地址: 127.0.0.1:5555
- 包名: com.c4ai.hormony
- HAP输出: entry\build\default\outputs\default\entry-default-unsigned.hap
