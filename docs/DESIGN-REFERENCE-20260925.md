# 鸿学伴移动界面参考与采用决定（2026-09-25）

这份清单服务复赛 App 的实际页面。用户提供的九张图用于表达希望达到的构图和完成度；下面另查了可看具体屏幕或代码的产品与设计稿。只借信息结构、交互组织和视觉原则，不复制第三方截图、插画、品牌或文案。

| 来源 | 看到的具体结构 | 鸿学伴采用决定 |
| --- | --- | --- |
| [HarmonyOS 官方设计资源](https://developer.huawei.com/consumer/cn/design/resource/) | 官方提供手机、折叠屏、平板的 Sketch/PIX 组件包，以及字体、图标等资源。 | 核对原生安全区、导航、控件规格；用现有 ArkUI 和系统 Symbol 画实际页面。下载包的具体素材尚未逐项验权，不直接打包。 |
| [Lingo Lessons](https://github.com/Open-Apps-Studio/lingo-lessons) · [屏幕目录](https://github.com/Open-Apps-Studio/lingo-lessons/tree/main/screenshots/final) | 开源语言学习 App 的路径节点、练习反馈、错题复习和个人进度分屏；仓库标明 MIT。 | 课程和练习分别承载“学到哪里”与“一题后的反馈”；计划列出真实任务状态，首页只强调当前一项。借结构，不移植 React Native 代码或课程内容。 |
| [Kelivo](https://github.com/Chevey339/kelivo) | Flutter 对话客户端把工具与模式放在输入附近，长对话与设置分开；仓库标明 AGPL-3.0。 | 学伴保留阅读正文，资料、行动和过程靠近对应消息并按需展开；不塞入通用模型配置面板，也不移植代码。 |
| [Caatuu](https://github.com/savethebeesandseeds/caatuu) | Word World、Verb Nebula 等语言任务使用不同内容表达，仓库有 AGPL-3.0 与素材分项许可。 | 以后英语试点按“阅读、词义、迁移练习”设计原生任务，不给所有学科套同一答题卡；不复制插画世界。 |
| [E-Learning Flutter App](https://github.com/erico19/e-learning-app) | README 可看 Explore、Planner、Subjects、Test 等整套旧版移动屏幕，代码为 BSD-3-Clause。 | 只参考发现、计划、课程、测验的页面分工；样式与技术栈较旧，不作为最终审美基准。 |
| [Galaxy](https://github.com/uiverse-io/galaxy) | 找到的同名候选仓库是 MIT 的 CSS/Tailwind 小组件集合，非整套手机 App 设计稿。 | 可研究单个按钮或状态反馈的动效节奏；当前不引入 Web 组件，也不把它当移动端设计系统。若用户指的是另一个 Galaxy，需按准确仓库再评估。 |
| [Dribbble 学习 App 五屏作品](https://dribbble.com/shots/27047294-Online-Learning-Mobile-App-UI) | 作者展示 Home、Dashboard、Course Detail、Profile、Settings 的分工。 | 学习它把继续学习和课程发现分开的信息层级；作品未给产品素材复用授权，只作视觉参考。 |
| [Dribbble 学习进度作品](https://dribbble.com/shots/26777686-Learning-Progress-App-UI-Modern-EdTech-Mobile-App-Design) | 作者展示进度、路径状态和课时信息的组合。 | 计划摘要显示待办数和预计时间，避免用无依据的图表装饰；作品只作灵感。 |
| [Figma 官方 Mobile UI Kit](https://www.figma.com/templates/mobile-ui-kit/) | 可编辑的移动端组件模板，包括聊天、列表和导航示例，不是完整学习 App。 | 可用于检查输入栏、列表、导航比例。实际产品沿用 ArkUI，具体素材复用仍逐项看许可。 |

小红书、抖音的案例继续作为视觉观察面；本轮检索没有得到可核对许可、可直接用于复赛 App 的原始设计文件。社交平台截图和 Dribbble 成品都不进入安装包。

## 落地到当前页面

- **首页**：一项当前任务成为唯一重点；今天其他任务只列摘要和入口，别重复主卡。提问入口保留，但不和主任务争视觉重心。
- **计划**：按真实日期分组，今天突出；其他日期用轻列表。每项任务把题名、课程、时长放在同一阅读顺序，主要学习按钮与“完成/恢复”区分层级。
- **课程、学伴、资料**：沿用已改的目录、连续回答和重点阅读结构；之后为三门课补统一的课程识别色与原创小图形，不向课程页塞无实际内容的装饰图。
- **各屏共同规则**：一屏一个明显主操作；普通条目主要靠排版与分隔线，状态同时用文字说明；现有安全区和至少 48vp 的主要触控尺寸保持。

设计取舍以 1320×2232 Pura X View 的运行画面和实际操作为准。开放源码许可不自动覆盖其中的图片、字体、课程内容；本轮没有复制或导入这些第三方资产。

## 本轮落地与证据

首页保留一项由真实计划或学习状态生成的主任务，移走重复的今日任务行；另两门课按课程色展示，主题数量来自课程仓库。计划页把今天的待办数与剩余分钟并列，历史日期收成可展开列表，任务的学习与完成操作仍分开。课程目录沿用同一套识别色。

Pura X View 竖屏截图存于 `.runtime/design-audit-20260925/23-home-final-d1.jpeg` 和 `22-plan-verified-d1.jpeg`。抽样验证了首页课程直达、首页进入计划、计划任务进入对应 Lesson；这些截图不代表大字号、横屏或真机验收。
