# HarmonyOS 学习闭环增强记录

日期：2026-07-02

## 目标

本轮聚焦 HarmonyOS 端课程学习页、课程详情、精选练习和 AI 测验入口，把“读完正文”推进为“概念建立 -> 主动练习 -> 精选题组 -> AI 测验复盘”的可执行闭环。

## 参考机制

- GitHub Skills 与 Classroom autograding：互动课程和自动评分强调提交后即时反馈。依据：<https://docs.github.com/en/get-started/start-your-journey/git-and-github-learning-resources>、<https://docs.github.com/en/education/manage-coursework-with-github-classroom/teach-with-github-classroom/use-autograding>
- Codecademy Lesson / Project / Quiz 边界：Lesson 负责低风险引导和自动检查，Quiz 用于短测与理解检查。依据：<https://help.codecademy.com/hc/en-us/articles/14298560842267-How-Lessons-and-Projects-Differ-in-Codecademy-s-Learning-Environment>、<https://help.codecademy.com/hc/en-us/articles/15373426748187-Quizzes-Assessments-and-Exams-What-s-the-Difference>
- Brilliant：单概念、视觉直觉、主动练习和递进题组。依据：<https://brilliant.org/about/>
- Duolingo：错题回流、间隔重复、主动回忆优先。依据：<https://blog.duolingo.com/spaced-repetition-for-learning/>
- Khan Academy Course / Unit Mastery：用掌握度和推荐练习表达学习状态，不只显示单次分数。依据：<https://support.khanacademy.org/hc/en-us/articles/115002552631-What-are-Course-and-Unit-Mastery>
- IES/WWC 学习指南：图文结合、worked example 与练习穿插、测验促进再暴露。依据：<https://ies.ed.gov/ncee/wwc/practiceguide/1>

## 本轮落地

- CourseDetail 增加主题学习闭环说明，并为每个主题提供“学习 / 精选练习 / AI 测验”三段入口。
- CourseDetail 不再把单一学习或测验记录标为“已闭环”，仅显示“有学习记录”或“待掌握”，避免高估掌握状态。
- Lesson 增加“学习闭环”四步轨道：概念、拆解、练习、题组；主动练习显示题型、反馈方式和完成后的下一步。
- Lesson 自由作答的“还需巩固”不计入完成，必须选择“我答对了”才推进活动完成状态。
- Practice 结果页增加“进入 AI 测验”，把离线精选题组接到 AI 标签化复盘。
- Quiz 主题建议从 `LearningContentRepository.getTopics(courseId)` 读取真实 Topic；非课程 Topic 会回退到综合练习并提示，避免污染本地学习记录。
- Quiz 结果页增加“下一步闭环”，错题时提供复习薄弱关键词和问学伴入口，全对时建议挑战难度。

## 证据等级

- 源码确认：上述入口、文案、Topic 读取和页面状态均已落在源码。
- 构建通过：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` 通过。
- 模拟器通过：Pura 90 Pro Max 模拟器安装当前 worktree 的 `entry-default-unsigned.hap`，完成 CourseDetail、Lesson、Practice 结果页 UI 树和截图核验。
- 未验证：真机、生产 Vercel AI 出题完整在线链路、本轮新增 Quiz 结果页“下一步闭环”的真实提交后页面。
