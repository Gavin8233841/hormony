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

D2 把学习页的推演改成“当前步骤、下一步”的紧凑结构，未展开步骤不占整屏；练习页以课程色题干和独立选项替换整页大白卡。结果页将首道错题的所选答案、正确答案和原有解析放在学伴入口之前。布局比较见同目录 `24-lesson-before-d2.jpeg`、`32-lesson-inline-d2.jpeg`、`27-practice-before-d2.jpeg`、`33-practice-after-d2.jpeg`、`29-result-before-d2.jpeg`、`34-result-after-d2.jpeg`。本批继续使用 ArkUI 和现有数据，没有移植外部代码或设计素材。

## D3：图像层次、导航和学伴角色

再对照用户提供的学习卡片、Agent 工作台和较完整的手机界面参考，采用“少量高质量图像＋有用途的嵌套卡片＋安静底色”。参考 [HarmonyOS 卡片设计](https://developer.huawei.com/consumer/cn/doc/design-guides/harmonyos-widget2-0000002731312633) 的低饱和与主次节奏、[ArkUI 动画指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-animation-usage-guide) 的原生轻动效；未调用 API 26 的沉浸式光感，也没有引入 Web 动画库。

今日主卡改为深灰绿背景与奶油色进度／行动内嵌卡，学习阶梯图只说明连续推进；操作系统、网络和数据结构使用分别生成的纸艺小图。课程页用一张重点续学卡与不同色的其他课程卡，真实名称和进度仍来自现有数据。底部 Tab 用选中深色横向胶囊、其余轻量纵向符号；学伴聊天中的重复气泡改为原创“小鸿”头像和更克制的系统符号，完整角色用于无会话欢迎卡及真正全题答对后的结果页。角色的资产、质量门槛和页面位置见 [小鸿规范](VISUAL-IDENTITY-XIAOHONG-20260926.md)。

本批素材均为新生成并人工挑选，未复用用户参考截图、社交媒体图、其他品牌角色或开源仓库的图片。当前 1320×2232 Pura X View 竖屏最终截图为 `.runtime/design-audit-20260925/40-home-layered-e.jpeg`、`43-chat-final-e.jpeg`、`45-course-final-e.jpeg`，不进入提交。无历史聊天欢迎卡尚未在现有模拟器状态中截屏；不得用代码构建通过代替视觉验收。

## D4：隔离空态与结果反馈

在 `.runtime/isolated-visual/` 从已提交源码生成独立测试包 `com.c4ai.hormony.visualqa`，保留正式包 `com.c4ai.hormony` 的学习记录。无历史学伴页实际呈现完整小鸿欢迎卡；首次截图发现四条推荐问题延伸至输入栏下方，改用独立滚动区后，上滑可见全部四条，输入栏固定。对比图：`47-chat-empty-isolated.jpeg`、`50-chat-empty-scroll-final.jpeg`、`52-chat-empty-scrolled.jpeg`。

结果页保留答题得分为唯一主信息。只有真实保存并且本轮 5/5 时，在深灰绿主卡右侧显示一次小鸿挥手形态；环形得分以原生动画到达实际分数。满分后的第二张卡改为暖纸色，只保留“全部答对”和“测验这个主题”，删除重复的说明句。隔离包通过实际五题选择和本地保存后取得 `62-result-all-correct-final.jpeg`。这证明隔离包的页面渲染与保存流程，不代表正式包的额外数据迁移、云端测验或真机验收。
