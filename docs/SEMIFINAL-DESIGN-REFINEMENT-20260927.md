# 复赛体验升级：设计取舍与验收

日期：2026-09-27。范围：HarmonyOS API 12 原生端与学伴提示策略。本记录描述本轮设计依据和实际证据，不等同于正式复赛附件。

## 设计依据

- [Khan Academy 的 2026 色彩系统复盘](https://blog.khanacademy.org/how-we-rebuilt-khan-academys-color-system-from-the-ground-up/)强调用语义色区分核心、学习与组件角色；[Material 3 颜色角色](https://developer.android.com/design/ui/wear/guides/styles/color/roles-tokens)也把主操作、容器和中性表面分开。本项目据此将正文改为中性墨蓝，钴蓝只强调操作与选中态，成功/错误继续使用独立语义色。这里借鉴的是角色划分，非复制其品牌色。
- 用户提供的学习应用、社媒设计图与 [Dribbble 教育应用看板](https://dribbble.com/search/education-app-dashboard)体现主视觉、课程插画、编辑式列表与非对称卡片组合。本轮沿用本项目原创纸艺素材，首页只保留一个深色主焦点；课程列表改成白底行与小幅插画。没有下载或直接复制外部作品资产。
- [Duolingo 官方视觉规范](https://design.duolingo.com/identity/imagery)说明角色插画应有统一身份。小鸿保留在学伴标题、消息作者及签到卡；其他内容卡不反复铺放角色。
- [Apple 材质规范](https://developer.apple.com/design/human-interface-guidelines/materials)把动态材质主要放在导航与控制层。[华为 ArkUI 背景属性](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V13/ts-universal-attributes-background-V13)和本机 API 12 SDK 都确认 `backgroundBlurStyle`、`linearGradient` 可用。本轮仅在底部导航用轻模糊与透明表面，在主卡用有方向的两色渐变；不把模糊放进正文或大面积滚动内容。HarmonyOS 7 的沉浸光感要求更高目标 API，不纳入当前 API 12 构建。
- [HKUDS/DeepTutor](https://github.com/HKUDS/DeepTutor)的学习对话、练习与资料上下文共享思路，以及 [Socratic](https://github.com/GitExcited/Socratic)的分级帮助，启发了“再给提示／换个例子”两个追问动作。它们复用现有对话历史、题目上下文与 SSE 接口；没有移植外部代码、引入新依赖或声称实现了 DeepTutor 的完整记忆与规划架构。
- [Duolingo 对连续学习习惯的说明](https://blog.duolingo.com/how-duolingo-streak-builds-habit/)与[里程碑动效案例](https://blog.duolingo.com/streak-milestone-design-animation/)支持让反馈紧贴一次明确行动。[Khan Academy 学习首页](https://blog.khanacademy.org/meet-the-new-khan-academy-classroom-experience/)把近期学习任务放在主页。签到因此是主页可见的一次点击，显示近七日与可展开的 28 日记录；没有引入积分、惩罚、补签或虚构奖励。
- [Apple 深色模式](https://developer.apple.com/design/human-interface-guidelines/dark-mode)与[颜色规范](https://developer.apple.com/design/human-interface-guidelines/color)建议根据系统外观使用语义色与分层表面。实现以 HarmonyOS API 12 的系统 `colorMode` 驱动双主题；暗色页面、内容卡、输入区、用户气泡和导航分别设色。新接入的 Mobbin 等插件在本次工具环境中没有可调用入口，因此本轮没有声称使用其私有设计资产。

## 本轮实际改动

1. 统一色彩角色：雾白页面、白色内容、墨蓝正文、钴蓝主行动、冰川青少量强调；暗色主题使用独立页面、卡片和浮层表面。课程仍用紫色与青绿作识别色，系统浅色／深色切换会更新原生页面。
2. 首页主卡只保留一次“8 道待复习”，用“今日复习—错题复习—课程与数量—开始复习”形成明确层级，不再三处重复同一信息。课程入口用已有原创插画形成次级视觉；课程页以“接着学”主卡和紧凑目录行分层。
3. 首页新增一次点击签到，独立保存本地日期且重复点击不产生重复记录。卡片显示七日状态和独立签到连续天数，可展开近 28 天；成功后小鸿与星点短暂运动，保存失败时提供重试。签到与答题或学习事件的连续学习天数互不混算。
4. 计划页把目标区、未展开日期和今日任务压缩，日期行使用轻色表面和展开动效。今日计划折叠行显示实际任务名，不显示“还有 1 项”之类低信息文字。我的学习把真实统计提前，正确率按中性数据展示，接着练卡独立强调。
5. 学伴回复下增加“再给提示／换个例子”追问，用户提问与学伴回复使用不同表面，行动卡置于回复内。追问发送为自然短句。云端提示词要求按追问类型分级讲解，题目未提交时继续不直接给答案。
6. 检查窗口属性后发现当前非沉浸式布局已由系统避让状态栏和手势区，原页面额外应用避让区造成空带。现在仅在沉浸式窗口使用手动避让值；Pura X View 上首页、计划和学伴顶部留白收敛。

## 验证边界

- Pura X View 模拟器，竖屏 1320×2232：最终浅色首页 `.runtime/design-final-light-home-20260927.png`，暗色首页 `.runtime/design-final-dark-home-20260927.png`，暗色课程／聊天／我的分别为 `.runtime/design-dark-course-20260927.png`、`design-dark-chat-20260927.png`、`design-dark-profile-20260927.png`。浅暗切换来自系统设置，未重新安装；签到点击后显示已签到、七日标记与独立连续天数，展开 28 日历史，并在重装 HAP 后保留。截图位于本机忽略目录，不提交 Git。
- UI 树确认主操作和导航可点击；学伴“换个例子”真实请求和回复截图为 `.runtime/design-chat-followup-20260927.png`（该次调用发生在云端新提示词发布前）。签到动画仅在成功保存新日期时触发；截图不是逐帧动画证明。
- API 12 增量 `assembleHap`、`CompileArkTS`、`PackageHap`、`PackingCheck` 通过；HAP 仍未配置签名。Web `lint`、`typecheck`、482/482 测试与生产构建通过。
- 这些证据不代表实体设备、横屏/展开态、大字号、真实学生学习成效或门户提交通过。正式录屏前仍须抽查长内容、键盘和展开态。
