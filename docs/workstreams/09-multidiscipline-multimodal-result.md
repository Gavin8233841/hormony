# WS09 多学科与多模态学习闭环结果

更新时间：2026-07-18

## 本批范围

- 分支：`codex/ws09-multidiscipline-multimodal`
- 首条非计算机闭环：`acc101 / 初级会计实务 / 会计要素与会计等式`
- 内容边界：5 个原创知识切片、5 道原创选择题、1 个关系根节点、1 个 schema v2 Lesson experience、2 个主动学习活动、3 条官方 `link_only` 来源。
- 保留边界：原 3 门计算机课程、33 个 Topic、147 个知识切片、165 道题及既有 ArkData 用户状态均保留；不以清库迁移。
- 本批不修改 `DEVLOG.md`，不提交 HAP、构建缓存、日志或 `screenshots/`。

## 可运行闭环

用户可在原生 HarmonyOS 页面完成以下路径：

1. Plan 从生成的课程目录显示“初级会计职称 · 基线诊断”。
2. 选择目标后先校验正式 Topic，再进入 `acc101` 的 5 题基线诊断。
3. 题目由 Web 单一来源生成到 HAP；提交后通过现有串行仓储写入 ArkData 画像、Topic 掌握度、课程进度和错题队列。
4. 结果页显示逐题复盘、确定性解析、向学伴追问入口、错题本入口和“根据诊断生成个性计划”。
5. 回到 Plan 后目标预填为“两周掌握初级会计实务基础”，Plan 请求继续读取本机画像。
6. acc101 错题重练复用课程目录标题；基线诊断路由失败会回收本次一次性目标和诊断标志。

图文学习由 Lesson 的原生概念推演、连续余额示例、状态推演和步骤排序组成。本批没有把音频、视频或网页正文打包进 HAP，也没有声称 TTS、字幕或视频在线播放已通过。

## 单一来源与证据护栏

- `apps/web/src/lib/data/course-catalog.ts` 是课程域、考试目标、建议目标和基线 Topic 的目录源。
- `apps/web/src/lib/data/accounting.ts` 是 acc101 知识、题目、关系、体验和外部来源的内容源。
- `scripts/generate-learning-content.mjs` 一次生成课程目录、知识、题库、资源、关系和体验，并调用 CS 活动生成器；`generate-quizzes-json.mjs` 保留为兼容入口并委托统一生成器。
- acc101 知识、题目和活动均带 `provenance=original_instructional_content`，并以 `sourceResourceIds` 引用同课程的官方来源记录。测试拒绝缺少原创标记、未知资源 ID、重复资源 ID或跨课程引用。
- 官方页面和 PDF 均为 `link_only`；HAP 只保存 URL、发布者、版本、SHA-256、许可结论、无障碍说明、包体策略和 API 12 打开方式，不复制官方正文、教材或受保护题库。

统一生成结果：

| 资产 | 总量 | acc101 |
| --- | ---: | ---: |
| 课程目录 | 4 | 1 |
| 知识切片 | 152 | 5 |
| 选择题 | 170 | 5 |
| 外部资源 | 39 | 3 |
| Topic 关系 | 34 | 1 |
| Lesson experience | 34 | 1 |
| LearningActivity | 61 | 2 |

## 一手来源与许可

访问日期均为 2026-07-18。Grade A 表示发布者的一手官方来源；HTTP、字节数和 SHA-256 已逐项核验，但“HTTP 200”不替代许可判断。

| 来源 | 核验 | 许可与纳入结论 |
| --- | --- | --- |
| [财政部会计司：2026 年考试大纲发布页](https://kjs.mof.gov.cn/gongzuodongtai/202512/t20251225_3980176.htm) | Grade A；HTTP 200；15,027 B；SHA-256 `69A5E7421473F4E0DB892C81EFE0E02F8DB12795E7DDDF2B547DF8A167E86D58` | 未发现允许修改或再分发的开放许可；`link_only`；HTML 可提取文本，无独立字幕或转写；不打包正文。 |
| [财政部会计司：2026 年初级考试大纲 PDF](https://kjs.mof.gov.cn/gongzuodongtai/202512/P020251225378678530611.pdf) | Grade A；HTTP 200；23 页；166,463 B；SHA-256 `F892ACF5D23CC72BC55A123FBCBC42D1A3CF22E52AFC59E6570D2C1CE4B35961` | 未发现开放许可；`link_only`；仅依据第 3 页确定掌握级首主题，不复制 PDF 或样题；文本提取已核验，无独立字幕。 |
| [中国政府网国务院公报：企业会计准则——基本准则](https://www.gov.cn/gongbao/content/2007/content_549050.htm) | Grade A；HTTP 200；35,307 B；SHA-256 `0562D5291659A6E6EAFE299B315907CB0B3B8FAF82F7D1170A9E1DDCC92AC948` | 未发现开放许可；`link_only`；只核验第二十、二十三、二十六、二十八条的事实边界，教学解释与题目为原创，不复制准则段落。 |

## IPC 同批事实修正

- `cs102_k44` 与活动反馈明确：普通匿名管道是单向、无消息边界字节流；fork 继承只是常见共享方式，能否使用取决于是否持有描述符；Linux 可用 `SCM_RIGHTS` 传递描述符引用。
- 管道容量使用 `F_GETPIPE_SZ` 查询、`F_SETPIPE_SZ` 请求调整并检查实际返回值，不固定写成 64KB。
- 阻塞式 read 先返回已有数据；只有读空且仍有写端打开时才等待；全部写端关闭后，读空返回 0/EOF。C 示例包含 `<stdio.h>`。
- 消息队列明确区分 System V 的 `mtype/msgtyp` 与 POSIX 的 `msg_prio`；POSIX 先取最高优先级、同优先级最早消息，两者均保留消息边界。
- 规格现实案例已改为“能否使用取决于是否持有描述符，而不是亲缘关系本身”，统一生成后旧句不再传播。

## 验证证据

### 静态与生成

- **静态诊断通过**：`node scripts/generate-learning-content.mjs`，exit 0；生成计数 `4/152/170/39/34/34`，活动为 `34/34 Topic、61 个`。
- **静态诊断通过**：`python scripts/validate-topic-relations.py`，exit 0；schema、唯一性、引用、DAG、连通性、单根、层级、Topic 和 Lesson flow 全部通过。
- **静态诊断通过**：`python scripts/test_validate_topic_relations.py`，exit 0；11 项通过。
- **静态诊断通过**：定向 Vitest 最终 3 文件、25 项通过，覆盖单一来源、证据外键、IPC 事实、诊断状态回收和 acc101 错题标题。
- **静态诊断通过**：`pnpm lint`，exit 0，无 warning/error。
- **静态诊断通过**：`pnpm typecheck`，exit 0。
- **静态诊断通过**：`pnpm test`，exit 0；34 文件、440 项通过。
- **构建通过**：`pnpm build`，exit 0；Next.js production build 完成 10/10 静态页面和全部 API 路由构建。

### API 12 与模拟器

- 构建配置源码确认：`compatibleSdkVersion` 与 `targetSdkVersion` 均为 `5.0.0(12)`。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon --incremental`，最终 exit 0；`CompileArkTS`、`PackageHap` 均为当前增量产物，`BUILD SUCCESSFUL in 14 s 6 ms`；仅有未配置 `signingConfigs` 的既有警告。
- **模拟器通过**：目标 `127.0.0.1:5555 / TCP / Connected / localhost`；1256×2760，竖屏。
- **模拟器通过**：`hdc install -r <entry-default-unsigned.hap>` 返回 `install bundle successfully`。
- 首次误用 `aa force-stop -b com.c4ai.hormony` 返回 `10104002 Failed to retrieve specified package information`；读取设备 `aa help` 后使用精确语法 `aa force-stop com.c4ai.hormony`，返回 `force stop process successfully`，随后 `aa start -a EntryAbility -b com.c4ai.hormony` 返回 `start ability successfully`。
- **模拟器通过**：冷启动 UI 树为 `pages/Index`；Plan 显示第四目标“初级会计职称 · 基线诊断”，进入 Practice 后显示“初级会计实务 · 会计要素与会计等式”和 `1 / 5`。
- **模拟器通过**：新 HAP 完成一次 4/5 诊断，UI 树显示 `4 / 5 题正确`、掌握度 `90%`、画像累计 `110 题`、当前错题 `3 道`、课程进度 `100%`。
- **模拟器通过**：错题本显示新增会计原题、`练 1 次` 和 `7月19日复习`；结果页按钮进入 Plan 后输入框为“两周掌握初级会计实务基础”。
- **模拟器通过**：最终证据链字段构建完成后再次执行 `install -r`、强停和启动，均返回成功；递归 UI 树断言唯一页面为 `pages/Index`，路径 `/data/local/tmp/layout_22675816720.json`。
- UI 树：`/data/local/tmp/layout_21838154262.json`（结果）、`/data/local/tmp/layout_21892896266.json`（错题本）、`/data/local/tmp/layout_21932292965.json`（计划预填）。
- 截图：`screenshots/ws09-acc101-20260718-220602/01-plan-prefilled.jpeg`、`02-diagnostic-result.jpeg`；均已目视检查无重叠或截断，不提交版本库。

## 批次二：CET-4 / CET-6 与开放词音

### 内容与数据

- 课程目录新增 `cet4` 与 `cet6`，各自具有唯一基线 Topic、诊断目标和计划建议，不把两级考试折叠成一个空目录。
- 每门课程包含 5 个原创知识切片、5 道原创 A-D 题、1 个关系根节点、1 个 schema v2 Lesson experience 和 2 个主动学习活动。
- CET-4 首主题为“连续短语听辨与转写复核”；CET-6 首主题为“讲座关键词骨架与延迟复述”。官方来源只限定考试结构，Commons 录音只用于原创词音/短语微练习。
- 资源 schema 增加 `audio`、共享课程 `courseIds`、媒体本体 `media` 和体验侧 `mediaResourceIds`。共享官方页面只存一条记录，课程专属音频不跨课索引。
- HAP rawfile 新增原始 `en-us-bookkeeper.ogg` 与 `en-us-one-could-hear-a-pin-drop.oga`。统一生成器读取本地字节并校验大小、SHA-256 后才写出六份学习资产。
- 最新生成计数为：6 门课程、162 个知识切片、180 道选择题、46 条外部资源、36 个关系、36 个体验、65 个活动。

### 来源与许可

- CET 项目首页、考试大纲索引/PDF、笔试结构和 CET-4/CET-6 分级详情均由教育部教育考试院发布，作为考试规则事实为 ARS Level VII / Grade A；未发现开放许可，全部 `link_only`。
- CET 根地址本次直接请求为 HTTP 403；可访问结论只适用于已逐项取得 HTTP 200 与哈希的具体页面，不外推根地址。
- `En-us-one could hear a pin drop.oga`：89,071 B，SHA-256 `46975A7D62CC58CE59D2B02818D17127EB3C8E44D1BC543CFA99BF8B4191E8FE`，CC BY-SA 4.0，原始字节未修改，保留署名和相同方式共享记录。
- `En-us-bookkeeper.ogg`：27,324 B，SHA-256 `10F0C4A6880A63B3D6F1CFCA38BE8B0F5274A3D5067682F087BDDE5F783CDD22`，CC BY 4.0，原始字节未修改并保留署名。
- 两个文件只有文件级静态文本标签，没有 VTT/SRT 或时间码，本轮未完成人工听辨。完整来源矩阵、动态页面限制和 AI 披露见 `docs/workstreams/09-cet-media-license-draft.md`。

### 验证

- **静态诊断通过**：统一生成器输出 `6/162/180/46/36/36`，活动为 `36/36 Topic、65 个`；媒体本体大小和 SHA-256 门禁通过。
- **静态诊断通过**：36 Topic 的 schema、唯一性、引用、DAG、6 课程连通性、单根、层级和 Lesson flow 全部通过；Python 11 项单测通过。
- **静态诊断通过**：CET 目录、来源外键、媒体许可/哈希、Planner、Web/Harmony 共享仓储定向测试通过。
- **静态诊断通过**：最终 `pnpm lint`、`pnpm typecheck` 均 exit 0；`pnpm test` 为 34 文件、444 项通过。
- **构建通过**：最终 `pnpm build` exit 0；10/10 静态页面和全部 API 路由完成 production build。
- **构建通过**：最终 API 12 增量 HAP `BUILD SUCCESSFUL in 23 s 85 ms`；两个媒体文件由 `CompileResource` 与 `PackageHap` 纳入产物，仅有既有签名警告。
- **模拟器通过**：课程页显示“大学英语四级（CET-4）”“大学英语六级（CET-6）”、各 `5 份资料` 与唯一 Topic，UI 树 `/data/local/tmp/layout_24706049526.json`。
- **模拟器通过**：Plan 同时显示 `CET-4 · 基线诊断` 和 `CET-6 · 基线诊断`，两者均进入对应 `1 / 5` Practice；UI 树 `/data/local/tmp/layout_24753209754.json`、`layout_24777221848.json`、`layout_24809137013.json`。
- **模拟器通过**：完成 CET-6 5/5 诊断后显示掌握度 100%、画像累计 115 题、课程进度 100%；结果页回流 Plan 后目标为“四周强化CET-6讲座关键词笔记”。UI 树 `/data/local/tmp/layout_24930824687.json`、`layout_24972336816.json`。
- **模拟器通过**：最终 HAP 再次 `install -r`、强停、启动均成功；递归 UI 树唯一页面为 `pages/Index`，路径 `/data/local/tmp/layout_25449094164.json`。
- 截图：`screenshots/ws09-cet-20260718-230031/01-cet6-plan-prefilled.jpeg`、`02-cet6-result.jpeg`；已目视检查长标题、六个目标按钮、复盘与底部动作无重叠或截断，不提交版本库。

## 协作契约

- WS08 / Lesson 展示域：在 `Lesson.ets` 读取 `LearningContentRepository.getResources(courseId)` 与 `experience.mediaResourceIds`。普通来源以非嵌套原生区块展示标题、发布者、许可和系统浏览器动作；音频必须使用 raw FD、显示文件级静态文本和署名，提供播放/暂停、加载/失败/离线、离页释放与可访问名称。验收要求 acc101 显示 3 条来源，CET 两条 OGG/OGA 分别完成 prepare/play/pause/complete，失败不伪装成功。
- WS05 / Agent 与 RAG：消费知识、题目和活动的 `sourceResourceIds`，只把已命中的资源记录转成 citation；输出前验证资源 ID、课程 ID 和许可状态，未知 ID 拒绝引用。验收要求 Chat SSE citation 可回溯到 acc101 官方 URL，取消和安全前后置保持既有契约。
- WS06 / 许可门禁：将 `provenance`、资源外键完整性、`link_only` 不入包和截图不提交纳入发布扫描；不得把原创练习写成官方真题。

## 未验证与下一批

- **未验证**：DevEco Agent 模型不可用；Alibaba `qwen3-coder-plus` 已知 403 `AllocationQuota.FreeTierOnly`，`deveco/glm-5` 已知 401 `Token refresh failed`，按要求停止重试，禁止 `openai/*`。本批未把这些认证失败写成模型不存在。
- **未验证**：acc101 的在线 Agent 实际解释正文与 citation；本批只验证真实入口、上下文和现有取消/安全架构未被绕过。
- **未验证**：来源浏览器打开、断网降级和来源元数据的页面可见性；协调契约已交给 WS08 展示域。
- **未验证**：acc101 错题到期后的重练标题设备路径；新增错题尚未到期，当前只有源码、定向测试和 API 12 构建证据。
- **未验证**：两个 OGG/OGA 已校验并打包，但 AVPlayer 的 prepare/play/pause/complete、音频焦点、离页释放、离线重进和可访问名称仍未验证；不得写成音频播放通过。
- **未验证**：视频、同步字幕、TTS、横屏、平板和真机。CET 官方 PDF、页面和受保护题目未进入 HAP。
