# 外部资源审计报告

> 审计日期：2026-06-30（北京时间）
> 审计范围：`apps/web/src/lib/data/external-resources.ts` 全部 36 条资源
> 审计方法：WebFetch 逐条访问 URL + WebSearch 核验官方归属与详情页
> HEAD：48d75b8

---

## 审计总结

| 指标 | 结果 |
|------|------|
| 资源总数 | 36 |
| URL 可访问 | 36/36 |
| 官方归属正确 | 36/36 |
| 标题与落地页一致 | 36/36 |
| 平台首页（已修复） | 4（res_04, res_10, res_25, res_26） |
| 标题/描述微调 | 3（res_21, res_24 标题, res_24 描述） |
| URL 后缀统一 | 1（res_16） |
| 保留不变 | 28 |

---

## 逐条审计记录

### 教材（textbook）— 10 条

| 资源 ID | 标题 | 最终 URL | HTTP | 官方归属 | 处理结论 |
|---------|------|---------|------|---------|---------|
| res_01 | 算法导论（CLRS） | https://mitpress.mit.edu/9780262046305/introduction-to-algorithms/ | 200 | MIT Press 官方 | 保留（详情页，ISBN 9780262046305） |
| res_02 | 数据结构与算法分析（Mark Allen Weiss） | https://users.cs.fiu.edu/~weiss/ | 200 | FIU 官方作者主页 | 保留（作者官方资源汇总页） |
| res_03 | 算法（Robert Sedgewick） | https://algs4.cs.princeton.edu/home/ | 200 | Princeton 官方 | 保留（教材配套站） |
| res_04 | 数据结构（严蔚敏·C语言版） | https://www.tup.com.cn/wap/tsxqy.aspx?id=00236807 | 200 | 清华大学出版社 | **替换**：原 `https://www.tup.com.cn/` 为出版社首页，已改为 ISBN 9787302023685 详情页 |
| res_05 | 操作系统概念（Silberschatz） | https://www.os-book.com/ | 200 | 教材作者团队官方 | 保留（配套网站） |
| res_06 | 现代操作系统（Tanenbaum） | https://www.cs.vu.nl/~ast/books/mos2/ | 200 | VU Amsterdam 官方 | 保留（第2版目录页，作者官方页面） |
| res_07 | 操作系统导论（OSTEP） | https://pages.cs.wisc.edu/~remzi/OSTEP/ | 200 | 威斯康星大学官方 | 保留（免费在线教材） |
| res_08 | 计算机网络：自顶向下方法（Kurose & Ross） | https://www.pearson.com/en-us/subject-catalog/p/computer-networking-a-top-down-approach/P200000013385 | 200 | Pearson 官方 | 保留（详情页） |
| res_09 | TCP/IP详解（W. Richard Stevens） | https://www.informit.com/store/tcp-ip-illustrated-volume-1-the-protocols-9780321336316 | 200 | Addison-Wesley / InformIT | 保留（详情页，ISBN 9780321336316） |
| res_10 | 计算机网络（谢希仁） | https://www.phei.com.cn/module/goods/wssd_content.jsp?bookid=70139 | 200 | 电子工业出版社 | **替换**：原 `https://www.phei.com.cn/` 为出版社首页，已改为 bookid=70139 详情页（第9版，ISBN 9787121527852） |

### 文档（documentation）— 8 条

| 资源 ID | 标题 | 最终 URL | HTTP | 官方归属 | 处理结论 |
|---------|------|---------|------|---------|---------|
| res_11 | MDN Web Docs | https://developer.mozilla.org/ | 200 | Mozilla 官方 | 保留（文档总入口，合理） |
| res_12 | Node.js 官方文档 | https://nodejs.org/en/docs | 200 | Node.js 官方 | 保留（文档总入口，合理） |
| res_13 | HarmonyOS 官方开发文档 | https://developer.huawei.com/consumer/cn/doc/ | 200 | 华为官方 | 保留（文档中心入口，合理） |
| res_14 | RFC 9110 — HTTP 语义 | https://www.rfc-editor.org/rfc/rfc9110.html | 200 | IETF RFC Editor | 保留（具体 RFC 全文） |
| res_15 | RFC 9293 — TCP | https://www.rfc-editor.org/rfc/rfc9293.html | 200 | IETF RFC Editor | 保留（具体 RFC 全文） |
| res_16 | RFC 768 — UDP | https://www.rfc-editor.org/rfc/rfc768.html | 200 | IETF RFC Editor | **后缀统一**：原 URL 无 `.html` 后缀，已统一补充 |
| res_17 | TypeScript 官方文档 | https://www.typescriptlang.org/docs/ | 200 | TypeScript 官方 | 保留（文档总入口，合理） |
| res_18 | ArkTS / ArkUI 开发指南 | https://developer.huawei.com/consumer/cn/arkts/devstart/ | 200 | 华为官方 | 保留（ArkTS 开发入门专属门户，路径有效） |

### 在线课程（course）— 8 条

| 资源 ID | 标题 | 最终 URL | HTTP | 官方归属 | 处理结论 |
|---------|------|---------|------|---------|---------|
| res_19 | MIT 6.006 — Introduction to Algorithms | https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/ | 200 | MIT OCW 官方 | 保留（具体课程页） |
| res_20 | CS61B — Data Structures（UC Berkeley） | https://sp21.datastructur.es/ | 200 | UC Berkeley 官方 | 保留（2021 春季课程站） |
| res_21 | MIT 6.1810（原 6.828）— Operating Systems | https://pdos.csail.mit.edu/6.828/ | 200 | MIT CSAIL 官方 | **标题更新**：MIT 已将 6.828 重新编号为 6.1810，URL 仍可访问，标题已更新为"MIT 6.1810（原 6.828）" |
| res_22 | Stanford CS144 — Networking | https://cs144.stanford.edu/ | 200 | Stanford 官方 | 保留（具体课程页） |
| res_23 | Harvard CS50 — Introduction to Computer Science | https://cs50.harvard.edu/ | 200 | Harvard 官方 | 保留（CS50 专属站点） |
| res_24 | Coursera — Algorithms Part I（Princeton） | https://www.coursera.org/learn/algorithms-part1 | 200 | Coursera / Princeton | **标题和描述更新**：原标题含"Part I & II"但 URL 仅覆盖 Part I，已将标题改为"Part I"，描述注明 Part II 需单独选课 |
| res_25 | 中国大学MOOC — 数据结构 | https://www.icourse163.org/course/detail.htm?cid=93001 | 200 | 网易/高教社官方 | **替换**：原 `https://www.icourse163.org/` 为平台首页，已改为浙江大学陈越/何钦铭《数据结构》课程详情页（cid=93001） |
| res_26 | 极客时间 — 数据结构与算法之美 | https://time.geekbang.org/column/intro/100017301 | 200 | 极客邦官方 | **替换**：原 `https://time.geekbang.org/` 为平台首页，已改为王争《数据结构与算法之美》专栏详情页（intro/100017301，81讲/28万+学员） |

### 标准规范（standard）— 5 条

| 资源 ID | 标题 | 最终 URL | HTTP | 官方归属 | 处理结论 |
|---------|------|---------|------|---------|---------|
| res_27 | IEEE 802.3 — 以太网标准 | https://www.ieee802.org/3/ | 200 | IEEE 802 工作组官方 | 保留（工作组专属页） |
| res_28 | RFC 9113 — HTTP/2 | https://www.rfc-editor.org/rfc/rfc9113.html | 200 | IETF RFC Editor | 保留（具体 RFC 全文） |
| res_29 | RFC 9114 — HTTP/3 | https://www.rfc-editor.org/rfc/rfc9114.html | 200 | IETF RFC Editor | 保留（具体 RFC 全文） |
| res_30 | POSIX 标准 | https://pubs.opengroup.org/onlinepubs/9699919799/ | 200 | The Open Group 官方 | 保留（POSIX.1-2017 Issue 7 在线版） |
| res_31 | Unicode / UTF-8 编码标准 | https://www.unicode.org/ | 200 | Unicode 联盟官方 | 保留（官方标准站点） |

### 开发工具（tool）— 5 条

| 资源 ID | 标题 | 最终 URL | HTTP | 官方归属 | 处理结论 |
|---------|------|---------|------|---------|---------|
| res_32 | Visual Studio Code | https://code.visualstudio.com/ | 200 | Microsoft 官方 | 保留（产品官方页） |
| res_33 | Wireshark 网络协议分析工具 | https://www.wireshark.org/ | 200 | Wireshark Foundation 官方 | 保留（产品官方页） |
| res_34 | GDB 调试器 | https://www.gnu.org/software/gdb/ | 200 | GNU 官方 | 保留（项目官方页） |
| res_35 | Git 版本控制 | https://git-scm.com/ | 200 | Git 官方 / SFC 维护 | 保留（项目官方页） |
| res_36 | Postman API 测试工具 | https://www.postman.com/ | 200 | Postman 官方 | 保留（产品官方页） |

---

## 修改清单

| 资源 ID | 修改类型 | 修改前 | 修改后 |
|---------|---------|--------|--------|
| res_04 | URL 替换 | `https://www.tup.com.cn/`（出版社首页） | `https://www.tup.com.cn/wap/tsxqy.aspx?id=00236807`（书籍详情页） |
| res_10 | URL 替换 | `https://www.phei.com.cn/`（出版社首页） | `https://www.phei.com.cn/module/goods/wssd_content.jsp?bookid=70139`（书籍详情页） |
| res_16 | URL 后缀统一 | `https://www.rfc-editor.org/rfc/rfc768` | `https://www.rfc-editor.org/rfc/rfc768.html` |
| res_21 | 标题更新 | `MIT 6.828 — Operating Systems` | `MIT 6.1810（原 6.828）— Operating Systems` |
| res_24 | 标题+描述更新 | `Coursera — Algorithms Part I & II（Princeton）` | `Coursera — Algorithms Part I（Princeton）`，描述注明 Part II 需单独选课 |
| res_25 | URL 替换 | `https://www.icourse163.org/`（平台首页） | `https://www.icourse163.org/course/detail.htm?cid=93001`（课程详情页） |
| res_26 | URL 替换 | `https://time.geekbang.org/`（平台首页） | `https://time.geekbang.org/column/intro/100017301`（专栏详情页） |

---

## 未修改但需说明的资源

| 资源 ID | 说明 |
|---------|------|
| res_02 | URL 为作者 Mark Allen Weiss 在 FIU 的个人主页，汇总全部教材版本与源码，作为作者官方资源汇总页用于教材引用合理 |
| res_06 | URL 指向《Modern Operating Systems》第2版，该书最新为第4版，但当前 URL 为作者官方页面，归属无问题 |
| res_11/res_12/res_13/res_17 | 均为文档总入口/索引页，对于"官方文档"类资源作为入口是合理且常规的做法 |
| res_30 | URL 指向 POSIX.1-2017（Issue 7），最新为 Issue 8（2024），但当前 URL 本身有效且为官方在线标准 |

---

## 新增测试覆盖

在 `data-integrity.test.ts` 的外部资源测试中新增以下断言：
- 资源标题（`title`）全局唯一
- 资源 URL 全局唯一

原有断言（资源 ID 唯一、类型合法、HTTPS 协议、描述≥30字、标签非空、courseId 合法）保持不变。
