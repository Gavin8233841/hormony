# 项目设计技能边界

本目录保存仅供当前项目使用的设计辅助技能，不属于 HarmonyOS 应用依赖，也不会进入 HAP。

## 已接入

1. `skills/impeccable`
   - 来源：https://github.com/pbakaus/impeccable
   - 用途：设计原则、反模式、排版、布局、交互和无障碍审查。
   - 许可证：Apache-2.0，原文见技能目录内 `LICENSE`。
   - 边界：默认只读取规则。其脚本包含联网、本地服务和子进程能力，未经明确审查不得执行；未安装任何 Hook。
2. `skills/imagegen-frontend-mobile`
   - 来源：https://github.com/Leonxlnx/taste-skill/tree/main/skills/imagegen-frontend-mobile
   - 用途：移动端视觉方向和流程图像生成约束。
   - 许可证：MIT，原文见技能目录内 `LICENSE`。
   - 边界：只生成视觉参考，不产生 ArkTS 代码，不替代 DevEco 构建和模拟器验收。

## 未接入代码

- `nextlevelbuilder/ui-ux-pro-max-skill`：未列出 ArkUI 技术栈，仅作为通用设计研究来源。
- `VoltAgent/awesome-design-md`：设计规范资料集合，不是执行工具；不直接复制第三方品牌设计。

## 验收原则

- 鸿蒙组件、图标、导航和交互以华为官方设计资源、SDK 类型定义和 DevEco 实际诊断为准。
- 外部技能只能影响设计判断，不能覆盖项目安全规则、ArkTS 约束或竞赛边界。
