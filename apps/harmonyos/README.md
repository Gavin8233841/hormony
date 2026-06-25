# HarmonyOS 客户端（ArkTS / Stage 模型）

> 本目录为鸿蒙端工程骨架。DevEco Studio 未安装时，以下文件已就绪，安装后可直接打开补全。

## 前置条件

1. 安装 DevEco Studio（https://developer.huawei.com/consumer/cn/download/）
2. 通过 DevEco Studio SDK Manager 安装 HarmonyOS SDK（API 12+）
3. 配置 ohpm / hvigor / hdc 到 PATH

## 使用方式

### 方式一：在 DevEco Studio 中导入

1. 打开 DevEco Studio → File → Open → 选择本目录
2. 等待 hvigor 同步完成
3. 如 SDK 版本不匹配，按提示在 SDK Manager 调整
4. 连接模拟器或真机 → Run

### 方式二：用 DevEco Studio 新建工程后替换 ets 源码

1. DevEco Studio → New Project → Empty Ability → 命名后创建
2. 将 `entry/src/main/ets/` 下的源文件替换为本目录对应文件
3. 修改 `Constants.ets` 中的 `BASE_URL` 指向 Web 后端地址

## 页面结构

| 页面 | 文件 | 说明 |
|------|------|------|
| 仪表盘 | `pages/Index.ets` | 首页，统计卡片 + 快捷入口 |
| 对话 | `pages/Chat.ets` | AI 对话，SSE 流式接收 |
| 课程 | `pages/Course.ets` | 课程列表与进度 |
| 学习计划 | `pages/Plan.ets` | 任务列表 |
| 知识库 | `pages/Knowledge.ets` | RAG 检索 |
| 个人画像 | `pages/Profile.ets` | 学习画像 |

## 后端对接

- `Constants.ets` 中配置 `BASE_URL`（默认 `http://localhost:3000`，真机需改为局域网 IP）
- 对话页通过 `HttpClient` 发送 POST 请求并解析 SSE 流
- 模拟器访问宿主机用 `10.0.2.2`，真机用电脑局域网 IP

## 鸿蒙系统体验亮点

- 服务卡片：桌面展示今日学习任务
- 通知：任务到期提醒
- 元服务：免安装快速问答
- 跨设备：手机学习 → 平板阅读 → 手表提醒
- 分布式数据：学习进度多端同步

> 注意：服务卡片/元服务/分布式能力需在 `module.json5` 中声明对应权限与 ExtensionAbility，开发阶段按需添加。
