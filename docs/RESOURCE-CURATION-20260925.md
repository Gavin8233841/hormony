# 复赛外部学习资料核对（2026-09-25）

HarmonyOS 课程详情原本已能进入 `ResourceLibrary`，页面也已调用 `LearningContentRepository.getResources(courseId)`。本轮从已有 36 条索引中只展示六条与三门演示课程对应的来源，每门两条。资料通过系统浏览器打开；App 不复制正文、题目或图片，也不把打开链接当成掌握。

| 课程 | 索引 ID、来源 | 本轮核对与学生阅读目标 |
| --- | --- | --- |
| 数据结构 | `res_19` [MIT 6.006 Spring 2020](https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/) | 官方课程页有 Lecture Notes 和 Problem Sets；看数据结构与复杂度分析。 |
| 数据结构 | `res_20` [UC Berkeley CS61B Spring 2021](https://sp21.datastructur.es/) | 官方归档课程站有 Linked Lists 讲义；链表主题优先显示，看节点连接方式。 |
| 操作系统 | `res_07` [OSTEP 在线教材](https://pages.cs.wisc.edu/~remzi/OSTEP/) | 官方目录有 Processes、Concurrency and Threads 等章节；进程与线程主题优先显示。站点请教师生链接原站，不复制教材。 |
| 操作系统 | `res_21` [MIT 6.1810](https://pdos.csail.mit.edu/6.828/) | 官方课程入口现指向当期页面，含 xv6 Labs；看系统调用实验。 |
| 计算机网络 | `res_15` [RFC 9293](https://www.rfc-editor.org/rfc/rfc9293.html) | RFC Editor 原文第 3.5 节讲连接建立；TCP 主题优先显示。 |
| 计算机网络 | `res_22` [Stanford CS144](https://cs144.stanford.edu/) | 官方课程入口现指向课程站，含 Lab；看可靠传输相关材料。 |

以上是 9/25 对官方源页的再次检查。索引 JSON 中 `checkedAt` 仍是原始的 2026-07-17，不代表今天的检查已写回数据；课程入口可能随学期更新。六条索引的 `rightsStatus` 均为 `external-link-only`，本轮只提供 URL 和自写阅读目标。MIT OCW 有自己的 [许可说明](https://ocw.mit.edu/pages/privacy-and-terms-of-use/)，其余课程站的页面可访问性也不等于再分发许可；复赛包内不放第三方正文或截图。

模拟器抽样：Pura X View 1320×2232 竖屏打开 OSTEP 官方页面；返回后可进入“操作系统 · 进程与线程”练习，也可进入学伴并看到“给我一道关于进程与线程的小题，先别给答案。”预填问题。截图在未跟踪的 `.runtime/design-audit-20260925/14-resources-aligned.jpeg`，UI 树在同目录。其他五条完成官网核对，尚未逐条在模拟器浏览器中打开；阅读效果和真实掌握均未验证。
