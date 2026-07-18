# WS06 竞赛验收、内容质量与正式交付结果

更新时间：2026-07-17

## 工作边界

- 分支：`codex/ws06-competition-release`
- 官方依据：仓库根目录的竞赛规程 PDF 与报名手册 PDF。
- 产品数据单一来源：`apps/web/src/lib/data/quizzes.ts`；HarmonyOS `quizzes.json` 只由生成器同步。
- 禁止项：不修改 `DEVLOG.md` 既有记录，不提交 `.trae/`、构建产物、HAP、日志、截图、根目录资产、展示站、ZIP 或秘密。

## 批次 1：题库答案位置、难度梯度与事实修正

背景：165 道选择题原始答案分布为 A=20、B=106、C=34、D=5，难度仅 4 道 hard，存在明显位置泄漏与梯度失衡。

文件：

- `apps/web/src/lib/data/quizzes.ts`
- `apps/web/src/lib/data/data-integrity.test.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 依据稳定题目 ID 对四个选项做确定性轮换；每个 Topic 的 5 道选择题覆盖 A-D，单一位置最多出现 2 次。
- 165 道题最终答案位置为 A=42、B=43、C=41、D=39。
- 本批次当时记录的 `easy=66、medium=66、hard=33` 与“33 个 Topic 均同时具备三级难度”已由批次 4 复算并纠正；当前精确统计与有效门禁以批次 4 为准。
- 修正 AVL 双旋次数、链地址法期望复杂度、分页碎片题双正确项，以及 HTTP 请求目标、HTTP/2 队头阻塞、现代 TLS、DNS TCP 回退和包过滤字段等表述。
- 修正题库源码中的旧题量注释；当前为 165 道选择题与 21 道简答题。
- Web 数据完整性测试新增全局、分课程和逐 Topic 的答案位置与难度门禁。

验证：

- **静态诊断通过**：`cd apps/web; pnpm lint`，exit 0，无警告或错误。
- **静态诊断通过**：`cd apps/web; pnpm typecheck`，exit 0。
- **静态诊断通过**：`cd apps/web; pnpm test`，exit 0，13 个测试文件、168 项测试通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建成功。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，`BUILD SUCCESSFUL in 34 s 387 ms`；仍有未配置 `signingConfigs` 的既有警告。
- **源码确认**：`node scripts/generate-quizzes-json.mjs`，exit 0，生成 165 道题且 Web 与 HarmonyOS JSON 完全一致。
- **源码确认**：`python scripts/validate-topic-relations.py`，exit 0，关系、Topic 与题库一致性全部通过。

未验证：

- **未验证**：本批只改变题库数据和测试，未进行模拟器逐题答题、真机或线上 API 回归。
- **未验证**：HAP 未配置正式签名；构建通过不等于可发布安装包通过。

## 后续批次

- 独立竞赛内容与提交包门禁。
- 147 条知识切片和 36 条外部资源的结构化出处、许可证与访问状态。
- 官方交付材料、源码清单、NOTICE、原创与 AI 使用说明。
- 基于实时 UI 树 bounds 的 HarmonyOS 冒烟门禁。

## 批次 2：基于实时 UI 树 bounds 的 HarmonyOS 冒烟门禁

背景：原脚本会复用已抓取的 UI 树、对节点文本做宽松匹配，并在多设备或多个 HAP 并存时隐式选择目标，无法形成可重复的竞赛验收证据。

文件：

- `scripts/harmonyos-app-smoke.ps1`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 每次点击、页面断言和文本断言都重新执行 `uitest dumpLayout`，只匹配当前可见节点的精确文本，并从节点 `bounds` 计算点击中心。
- 对当前工具已见的三种 bounds 编码进行显式解析：`[x1,y1][x2,y2]`、`left/top/right/bottom`、`left/top/width/height`；反向、空尺寸和尾随内容均拒绝。
- 多设备连接时要求传入 `-DeviceTarget` 的精确值，所有 HDC 命令固定到该目标；安装产物固定为当前构建配置的 `entry-default-unsigned.hap`。
- UI 树 JSON、dump 路径、命令退出码、安装与启动结果都设置失败边界；截图只写入新的时间戳目录，已存在时拒绝覆盖。
- 新增 `-SelfTest` 离线入口，验证 bounds、UI 树、dump 路径和目标设备参数，不连接设备、不构建、不创建截图目录。

验证：

- **静态诊断通过**：PowerShell AST 解析，exit 0，`AST_PARSE=PASS`。
- **静态诊断通过**：PowerShell 7.6.3 执行 `./scripts/harmonyos-app-smoke.ps1 -SelfTest`，exit 0，9/9 通过。
- **静态诊断通过**：Windows PowerShell 5.1 执行同一 `-SelfTest`，exit 0，9/9 通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，`BUILD SUCCESSFUL in 8 s 559 ms`；仍有未配置 `signingConfigs` 的既有警告。
- **未验证**：`hdc list targets` 返回 `[Empty]`，因此没有运行安装、启动、页面点击和截图流程，不能标记为模拟器通过或真机通过。

## 批次 3：官方评分证据与正式材料口径

背景：正式材料需要直接映射官方 PDF，消除把项目内部严格要求写成官方要求、复用历史测试数字或夸大 AI 引用覆盖范围的风险。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 逐页列出初赛截止时间、三项必备内容、Demo 可选备注、PDF/MP4/ZIP 规格、上传次数和原创要求，并记录两份 PDF 的页数与 SHA-256。
- 建立创新性 50、完备度 20、前景评估 20、规范性 10、实际应用价值 20 的证据矩阵，不自行拆分官方未公开分值。
- 定稿一句话创新点、467 字项目介绍、两张真实图的取证规则、4 分 45 秒黄金演示镜头表和 20 页内作品说明结构。
- 补齐 PDF、MP4、源码 ZIP、NOTICE、原创声明、AI 使用说明和上传前真实性门禁。
- 明确“2 张图”是项目严格口径，不是 PDF 原文；明确拒绝复用“总题库 60 题”“78/78”“答案 100% 正确”“所有 AI 输出都有引用”等旧表述。
- 修正文档中证据等级数量，将源码确认、静态诊断通过、构建通过、模拟器通过、真机通过、线上通过、未验证准确写为七种。

验证：

- **源码确认**：使用 `pypdf` 读取两份官方 PDF 的关键页，exit 0；规程 11 页、报名手册 12 页。
- **源码确认**：`Get-FileHash -Algorithm SHA256`，exit 0；规程哈希 `E5093C61BED5A10C249E165095127AC1F03FD3CE5B8B993D3A8D6AE878BEC1A9`，报名手册哈希 `6034ACA8F908D76DEBD0EA1DC606C3F594DF8FE29310866F1E5EF91D170BD26E`。
- **静态诊断通过**：文档门禁确认项目介绍为 467 个 Unicode 字符，评分项、截止时间、4 分 45 秒和 20 页上限均存在，exit 0。
- **未验证**：官方作品说明模板最新版、门户实时字段、单文件大小限制、真实队名和剩余更新次数仍须队长登录核对。
- **未验证**：最终 PDF、MP4、ZIP、截图、HAP 哈希和签署材料尚未生成；本文不把准备清单写成已交付。

## 批次 4：纠正 hard 题认知复杂度与难度统计

背景：对提交 `d0f9f95` 的复核发现，29 道新增 hard 中有 24 道正文相对父提交没有实质升级；批次 1 还把真实难度统计 `easy=67、medium=65、hard=33` 错写为 `66/66/33`。逐 Topic 强制三级难度会诱导只改标签，不能作为内容质量门禁。

文件：

- `apps/web/src/lib/data/quizzes.ts`
- `apps/web/src/lib/data/data-integrity.test.ts`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 实质重写 29 道 hard：数据结构 8 道、操作系统 10 道、计算机网络 11 道。题目改为扩容/树与图状态推演、调度与页面置换、地址转换、TCP/UDP/TLS/DNS/HTTP 状态与边界计算等需要多步推理的固定输入，不再以定义记忆题承载 hard 标签。
- 当前精确难度分布为 `easy=67、medium=65、hard=33`；答案位置仍为 `A=42、B=43、C=41、D=39`。
- 删除逐 Topic 必须同时出现 easy/medium/hard 和每课程 hard 数量的机械门槛；保留 165 题、33 Topic、每 Topic 5 题、答案位置覆盖及全局难度区间门禁。
- 导出确定性选项轮换函数并增加固定输入单测，逐目标位置断言正确答案正文、全部选项正文集合、题干和解析在轮换前后不变，且源对象不被修改。

验证：

- **源码确认**：PowerShell 从 `d0f9f95^` 读取旧 `quizzes.ts`，按 29 个指定题目 ID 精确提取并比较题干，exit 0，`HARD_STEMS_CHANGED=29/29`、`UNCHANGED=`。
- **源码确认**：`node scripts/generate-quizzes-json.mjs`，exit 0；生成 165 道题，Web 单一源与 HarmonyOS JSON 完全一致。
- **静态诊断通过**：`cd apps/web; pnpm lint`，exit 0，无警告或错误。
- **静态诊断通过**：`cd apps/web; pnpm typecheck`，exit 0。
- **静态诊断通过**：`cd apps/web; pnpm test`，exit 0，13 个测试文件、169 项测试通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建成功。
- **源码确认**：`python scripts/validate-topic-relations.py`，exit 0，关系、Topic、知识切片与题库一致性全部通过。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，`BUILD SUCCESSFUL in 31 s 833 ms`；仍有未配置 `signingConfigs` 的既有警告。

失败后纠正：

- 首次从 `apps/web` 目录误执行根目录相对路径 `node scripts/generate-quizzes-json.mjs`，exit 1；生成器未运行，随后定向同源测试按预期因端侧 JSON 陈旧而失败。改从仓库根执行生成器后，同一测试 7/7 通过，未用失败结果充当通过证据。

未验证：

- **未验证**：29 道题尚未完成具名学科专家逐题签字，不能宣称“答案 100% 正确”。
- **未验证**：未进行模拟器逐题作答、真机或线上 API 回归；本批只达到静态诊断通过与构建通过。
- **未验证**：HAP 未配置正式签名，构建通过不等于可发布安装包通过。

## 批次 5：课程 CTA 与 Topic 整行 Lesson 冒烟路径

背景：WS03 提交 `4fd5bef` 已将课程入口收敛为“进入课程/继续课程”两种真实进度状态，并由 Topic 整行进入 `pages/Lesson`；批次 2 的脚本仍断言已移除的“真实学习进度/精选练习”路径。

文件：

- `scripts/harmonyos-app-smoke.ps1`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 从知识切片原始数据读取 33 个精确 Topic 文本，不在脚本中复制维护 Topic 名单。
- 同时接受“进入课程”和“继续课程”，每次从实时 UI 树找到精确文本，再使用最近可见、可点击祖先的整行 `bounds` 计算点击中心。
- Topic 可点击行缺少合法 `bounds` 时直接失败，不退回标题文本坐标；进入后精确断言大小写一致的 `pages/Lesson` 与所选 Topic 标题。
- 删除已失效的“真实学习进度”“精选练习”和固定选择 A 的旧课程路径断言。
- 固定 fixture 新增两种 CTA、最上方精确 Topic、整行无 bounds 拒绝和 Lesson 路径大小写边界，共 13 项离线自测。

验证：

- **源码确认**：`git show 4fd5bef -- apps/harmonyos/entry/src/main/ets/pages/Course.ets apps/harmonyos/entry/src/main/ets/pages/CourseDetail.ets`，exit 0；确认两种 CTA、Topic 整行点击与 `pages/Lesson` 路由契约。
- **静态诊断通过**：PowerShell AST 解析，exit 0，`AST_PARSE=PASS`。
- **静态诊断通过**：PowerShell 7.6.3 执行 `./scripts/harmonyos-app-smoke.ps1 -SelfTest`，exit 0，13/13 通过。
- **静态诊断通过**：Windows PowerShell 5.1 执行同一 `-SelfTest`，exit 0，13/13 通过。

未验证：

- **未验证**：`hdc list targets` 返回 `[Empty]`；没有执行安装、启动、实时页面点击或截图，不能标记为模拟器通过或真机通过。
- **未验证**：当前 WS06 分支尚未集成 WS03 `4fd5bef` 的页面改动；脚本按该已核实契约前置更新，需在主线集成后执行设备流程。
- **未验证**：本批只修改无破坏性冒烟脚本与记录，未重新构建 HAP。

## 批次 6：AI 引用能力真实性口径

背景：架构与交接文档仍把“所有 AI 输出附带引用”写成产品原则，超过当前编排器可证明的行为，也会把 Plan 等不保证引用的输出误写成必有来源。

文件：

- `docs/architecture.md`
- `docs/HANDOFF-TO-TRAE.md`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- 将引用能力收敛为：课程检索问答只在主 Agent 实际返回 `citations` 时展示引用，Plan 等输出不保证引用。
- 架构流程图同步标注“主 Agent 实际返回的引用（如有）”，不再暗示结构化输出必然附带引用。
- 文档使用源码中的精确结果字段 `citations`；SSE 单条引用事件的类型仍为 `citation`，两者不混写。

验证：

- **源码确认**：`apps/web/src/lib/agents/orchestrator.ts` 第 231 行返回 `citations: mainResult.citations ?? []`，第 269-270 行只对实际数组逐条发送 `type: "citation"` 事件。
- **源码确认**：扫描 `README.md` 与 `docs/**/*.md` 的“所有 AI 输出/所有引用/保证引用/附带资料引用”类表述，exit 0；剩余命中均为禁止夸大、NOTICE 待确认项或与 AI 引用无关的设计说明。
- **静态诊断通过**：`git diff --check -- docs/architecture.md docs/HANDOFF-TO-TRAE.md`，exit 0。

未验证：

- **未验证**：本批只纠正文档口径，未发起线上 Chat SSE 或 Plan 请求，不能证明当前线上部署的引用行为。
- **未验证**：未运行 Web 四项或 HarmonyOS 构建；产品源码与数据未改变。

## 批次 7：内容溯源、Lesson 合同与源码提交真实性门禁

背景：147 条知识切片和 36 条外部资源此前只有自由文本来源，端侧 JSON 与 Web 数据分别维护；Lesson 规格中的 6 个状态推演虽有“最终状态”，生成器却输出空 `answer`，页面会显示空“标准答案”。正式源码集合也缺少可执行的 manifest、内容同一性、禁止项和秘密扫描门禁。

文件：

- `apps/web/src/lib/types.ts`
- `apps/web/src/lib/data/cs101-knowledge.ts`
- `apps/web/src/lib/data/cs102-knowledge.ts`
- `apps/web/src/lib/data/cs103-knowledge.ts`
- `apps/web/src/lib/data/external-resources.ts`
- `apps/harmonyos/entry/src/main/ets/model/DataModels.ets`
- `apps/harmonyos/entry/src/main/ets/common/LearningContentRepository.ets`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/external-resources.json`
- `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
- `docs/ACTIVE-LEARNING-SPEC-CS103.md`
- `docs/COMPETITION-NOTICE.md`
- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/generate-learning-activities.mjs`
- `scripts/generate-learning-content-json.mjs`
- `scripts/generate-learning-content-json.test.mjs`
- `scripts/validate-competition-content.py`
- `scripts/test_validate_competition_content.py`
- `docs/workstreams/06-competition-release-result.md`
- `DEVLOG.md`

行为变化：

- Web TypeScript 成为知识切片和外部资源的单一来源；生成器确定性写出两份 HarmonyOS rawfile，并以深相等测试约束 147/36 数量、ID 唯一、33 Topic 和跨端字段完全一致。
- 147 条知识切片补齐书名、版次、Topic 对应章节、官方 URL、权利边界和访问记录；全部明确为 `reference-only`，只证明书目映射，不冒充内容许可。
- 36 条外部资源补齐版次/定位、官方 URL、`external-link-only`、访问状态和 HTTP 状态。当前记录为 35 条 `reachable/200`、`res_01` 为 `unreachable/403`；10 条没有 `courseId` 的既有全局资源在 HarmonyOS 模型中改为可选字段，无筛选时返回全部、按课程筛选时只返回对应 26 条课程资源，不虚构课程归属。
- 修正 HTTP/2 仍受 TCP 层队头阻塞、RFC 9000 不定义内置 FEC、HPKP 已弃用三处事实；失实片段进入回归门禁。
- 状态推演复用规格中的精确“最终状态”生成标准答案，59/59 活动均有非空答案；既有 v2 迁移会过滤代码空行，避免页面出现空示例步骤。
- Lesson 门禁校验 33 Topic、59 活动、首屏/案例/示例展示字段、三种交互模式、options/answerIndexes、单选答案和排序答案映射；知识切片与题库比较完整 `(courseId, topic)` 集合，而非只比较数量。
- 源码 manifest 固定完整展开 `apps/web` 与 `apps/harmonyos`，只允许三个精确排除项；源码目录/ZIP 门禁比较文件集合和逐字内容，拒绝空必备文件、未列文件、危险路径、符号链接、禁止目录/后缀、超过 2 MiB 无法扫描的条目及可识别秘密。
- 固定输入对抗测试证明 manifest 缩减、README 篡改/置空、包内 manifest 漏项、`.npmrc` `_authToken` 和超大文本均被拒绝，错误不回显秘密值。
- `--submission-path` 明确只证明 Git 源码子集逐字一致，不再冒充包含 HAP、许可证附件、原创/AI 声明和发布证据的最终 Demo/源码 ZIP。
- NOTICE 按真实资源树修正为 5 个 PNG 文件、3 个唯一哈希；System Symbol 为 76 次引用、29 个不同 ID。浏览器标识请求的精确 UA、最终 URL 和时刻未留存，文档明确标为不可复现的当日审计记录。

验证：

- **源码确认**：`node scripts/generate-learning-activities.mjs`，exit 0，33/33 Topic、59 个活动；全量类型分布 `code_fill=13、step_order=16、state_trace=17、output_predict=13`。
- **源码确认**：`node scripts/generate-learning-content-json.mjs --check`，exit 0，147 条知识切片和 36 条资源与 Web 单一源完全一致。
- **静态诊断通过**：`node --test scripts/generate-learning-content-json.test.mjs`，exit 0，4/4 通过。
- **静态诊断通过**：`python -m unittest scripts/test_validate_competition_content.py -v`，exit 0，29/29 通过。
- **源码确认**：`python scripts/validate-competition-content.py`，exit 0；题库 `A=42、B=43、C=41、D=39`，难度 `easy=67、medium=65、hard=33`，147/36/33/59、Topic 对齐、失实回归和源码提交集合均通过。
- **源码确认**：独立子 agent 从 Git 索引加载门禁，运行 7 类固定输入对抗验证，整体 exit 0；六类绕过被拒绝，源码子集证据边界输出符合预期。
- **源码确认**：`python scripts/validate-topic-relations.py`，exit 0，关系、知识切片与题库的 33 Topic 一致。
- **静态诊断通过**：`cd apps/web; pnpm lint`，exit 0，无警告或错误。
- **静态诊断通过**：`cd apps/web; pnpm typecheck`，exit 0。
- **静态诊断通过**：`cd apps/web; pnpm test`，exit 0，13 个测试文件、169 项测试通过。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建成功。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，exit 0，`BUILD SUCCESSFUL in 27 s 714 ms`；仍有未配置 `signingConfigs` 的既有警告。
- **静态诊断通过**：`git diff --cached --check`，exit 0。

失败后纠正：

- 新增 manifest 尚未精确暂存时，首次完整门禁 exit 1，提交集合检查按预期报告未跟踪文件；精确暂存后同一检查通过。
- 第一轮 Lesson 完整性门禁 exit 1，发现 6 个状态推演 `answer` 为空；核对现有 schema、生成器、规格“最终状态”和 `Lesson.ets` 消费逻辑后修复单一源生成规则，未手工复制答案。
- 第二轮 Lesson 门禁 exit 1，发现 HTTP 既有体验含 1 个空示例步骤，同时步骤数组的重复限制超过现有契约；生成器过滤迁移空行，门禁只对 tags/options 保留唯一性要求后通过。
- 两次用于哈希/资源报告的内联 PowerShell 最初因 `foreach` 后直接接管道产生解析错误，exit 1；改为先收集行再输出后 exit 0，未改写数据。

未验证：

- **未验证**：本次最终门禁不联网；35/1 是 2026-07-17 已记录状态，不证明当前实时可达。`res_26` 的浏览器标识请求没有保存精确 UA、最终 URL 和时刻，不能复现。
- **未验证**：147 条内容与教材章节的实际创作/改写关系、165 道题答案、59 个活动和 3 个唯一 PNG 内容尚未完成具名负责人签字；不能宣称版权已解决或答案百分之百正确。
- **未验证**：NOTICE 仍含正式提交前待人工处理标记；最终逐包许可证附件、原创声明、AI 使用明细、团队签字和发布证据索引未完成。
- **未验证**：最终签名 HAP、含 HAP 的 Demo/源码 ZIP、PDF、MP4、文件名、大小、SHA-256、独立目录解压和从零构建尚未验收。源码子集门禁通过不等于最终 ZIP 通过。
- **未验证**：没有模拟器、真机或线上流程证据；构建通过不等于安装、运行、真机或线上通过。

## 批次 8：最终 Demo/源码 ZIP 发布 manifest 与真实性门禁

背景：批次 7 的 `--submission-path` 只能证明 Git manifest 展开的源码子集逐字
一致，不能核验最终 ZIP 中的 HAP、许可证索引、原创/AI 声明和发布证据，也没有
把包声明绑定到执行门禁时的明确提交。

文件：

- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-release-bundle.py`
- `scripts/test_validate_release_bundle.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 包根 `release-manifest.json` 顶层只接受 `sourceCommit` 与 `nonGitFiles`；附件项
  只接受 `path`、`role`、`bytes`、`sha256`。HAP、第三方许可证索引、原创声明、
  AI 使用说明和发布证据索引五种角色必须且只能各出现一次。
- `sourceCommit` 必须为本仓库可解析的 40 位小写完整提交，并等于运行门禁时的
  当前 `HEAD`。脚本直接读取该提交的 Git tree、源码 manifest 和 blob，不使用
  工作树同名文件替代，再复用既有源码提交集合门禁检查必要文件、NOTICE、禁止项
  和可识别敏感信息。
- 最终 ZIP 的源码集合必须与提交快照逐字一致；五个非 Git 附件必须与 manifest
  的路径集合、正整数字节数和 SHA-256 一致。未声明附件、Git/非 Git 重叠、空
  HAP、多 HAP、错误角色或错误扩展名都会阻断。
- ZIP 与 HAP 都拒绝路径穿越、非规范路径、大小写折叠冲突、重复条目、符号链接、
  特殊文件和加密条目；共享路径校验拒绝反斜杠，Windows `zipfile` 读取原始 ZIP
  时会先将其规范化为 `/`。ZIP 注释、条目文件名、条目注释、扩展字段、
  HAP 容器和 HAP 解压后条目均进入敏感信息扫描，错误只输出规则名，路径本身
  命中时统一显示 `<redacted-path>`。
- 内部门禁限制 `release-manifest.json` 不超过 64 KiB、包内路径 UTF-8 编码不
  超过 512 字节、HAP 单条目解压后不超过 64 MiB、HAP 可读条目合计不超过
  256 MiB。以上均为项目安全上限，不是尚未核实的官方门户大小限制。
- 官方 PDF 的精确边界是：应用赛题提交 Demo 时，HAP 位于 ZIP；Agent 赛题提供
  运行所需源码。规程第 5 页又明确初赛第 4 项 Demo 可选，而报名手册第 10 页
  列出 PDF、MP4、ZIP 三项且未标可选。鸿学伴把 HAP、双端源码、NOTICE、声明和
  证据索引合并验收是内部加严口径，不冒充两份 PDF 一致规定的初赛硬要求。

验证：

- **静态诊断通过**：`python -m unittest scripts/test_validate_release_bundle.py -v`，
  exit 0，19/19 通过；覆盖路径、重复条目、符号链接、角色/路径唯一性、bytes、
  SHA-256、HEAD 绑定、ZIP/HAP 元数据、长字段和秘密不回显。
- **静态诊断通过**：`python -m py_compile scripts/validate-release-bundle.py scripts/test_validate_release_bundle.py`，
  exit 0。
- **源码确认**：独立子 agent 复跑 19/19，且对 60013 字符路径、秘密路径与 SHA
  错误、10000 层 JSON、10 类非规范路径及大小写折叠重复执行只读固定输入；全部
  被拒绝，路径正文和秘密值未回显，未再发现错误放行。
- **静态诊断通过**：既有内容门禁单测 29/29、Node 单一源测试 4/4、147/36
  生成一致性检查、165 题/33 Topic 内容门禁、Topic 关系门禁和冒烟自测 13/13
  均 exit 0。
- **静态诊断通过**：`cd apps/web; pnpm lint`、`pnpm typecheck`、`pnpm test`
  均 exit 0；13 个测试文件、169 项测试通过，无 ESLint 警告或错误。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建成功。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，
  exit 0，`BUILD SUCCESSFUL in 4 s 910 ms`；仍有未配置 `signingConfigs` 的既有警告。

失败后纠正：

- 初始实现把 manifest 自己声明的提交作为期望提交，比较属于同值自证；改为绑定
  当前 `HEAD`，并让声明提交的 Git 快照再次经过既有源码包门禁。
- 独立对抗固定输入先后发现 ZIP/HAP 元数据未扫描、长引号字段跨固定 overlap
  漏检、超长路径可通过、秘密路径会在后续 SHA 错误中回显，以及深层 JSON 可能
  触发未捕获递归错误；逐项增加元数据扫描、整条 HAP 条目扫描、安全上限、统一
  路径脱敏和解析异常边界后复跑通过。
- 新增长度测试首次用 2000 层 JSON 期望触发解析边界，但当前 Python 正常解析，
  因此单测 exit 1；按已复现输入改为 10000 层后，同一测试与全量 19 项 exit 0。
- outer ZIP 反斜杠用例最初断言读取后的错误仍含反斜杠，单项测试 exit 1；核对
  `ZipInfo.filename` 后确认 Windows `zipfile` 已先规范化为 `/`，改为直接固定共享
  路径函数的反斜杠拒绝合同，同时保留 outer ZIP 的 `a/./b` 拒绝断言。

未验证：

- **未验证**：本批没有生成、修改或提交最终 ZIP、HAP、许可证附件、声明或发布
  证据文件；因此没有运行 `--bundle-path` 的真实最终包通过记录。
- **未验证**：HAP 只完成增量构建且仍未配置正式签名；可读 ZIP 静态检查不等于
  正式签名、安装、模拟器或真机通过。
- **未验证**：许可证索引、原创声明和 AI 使用说明的文件存在性门禁不等于内容
  已由真实团队审阅、权利已解决或声明已签署。
- **未验证**：最终 PDF、MP4、门户实时字段、大小限制、上传结果和线上业务流程
  仍未验收。

## 批次 9：ZIP 原始结构、名称一致性与读取资源边界

背景：批次 8 只检查了 `ZipInfo.filename`。Windows Python 会把反斜杠规范化，
并在 NUL 截断解析名称，同时把原始文本保留在 `ZipInfo.orig_filename`；因此原始
名称与解析名称分叉时，旧门禁可把异常条目当作正常文件名。旧实现还接受 outer
ZIP 的自解压前缀和 EOCD 后尾随数据，并在 `read(info)` 前缺少 outer 条目数、
单项/总解压大小和压缩比上限。

文件：

- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-release-bundle.py`
- `scripts/test_validate_release_bundle.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- outer ZIP 与 HAP 共用的 `_archive_infos` 同时检查 `orig_filename` 和
  `filename`；原始名称单独进入敏感信息、控制字符、反斜杠、相对路径与 512
  字节长度校验。两者不相等即失败，控制字符路径只显示固定安全标签。
- outer ZIP 原始容器以固定块和重叠窗口只读扫描；需从 ZIP 结构开始并精确结束于
  EOCD 及其声明注释。首个被中央目录引用的本地文件头还必须位于偏移 0，因此
  普通前缀、ZIP 头样式伪装前缀和尾随数据都阻断。
- outer/HAP 在读取条目正文前统一限制条目数不超过 10000、单项压缩比不超过
  200:1。outer 单项/总解压上限为 512 MiB/1 GiB，HAP 为 64 MiB/256 MiB；
  均为项目内部资源边界，不是官方门户限制。
- UTF-8 标志与非法名称字节导致的 `UnicodeDecodeError` 转为只含异常类型的
  结构化失败，不回显原始字节。正式命令改用 `python -B`，脚本在动态导入内容
  门禁前设置 `sys.dont_write_bytecode`，不靠事后清理隐藏副作用。
- 主线不得整提交采用 `5d1e75f`。发布门禁的最小前置文件是当前版本的
  `scripts/validate-competition-content.py` 及其测试、`docs/COMPETITION-NOTICE.md`
  和主线校准后的 `docs/SUBMISSION-SOURCE-MANIFEST.md`；主线自己的
  `lesson-experiences.json` 必须保留。集成后逐项校准 manifest 存在性与跟踪状态，
  并将 `sourceCommit` 绑定到校准完成后的主线 `HEAD`。

验证：

- **源码确认**：修复前真实 ZIP 字节固定输入显示 `orig_filename != filename`，
  NUL、反斜杠在 outer/HAP 的错误数均为 0；修复后同一输入三类均被拒绝，控制
  字符未进入错误正文。
- **静态诊断通过**：`python -B -m unittest scripts/test_validate_release_bundle.py -v`，
  exit 0，25/25 通过；覆盖真实 local/central 同长原位替换、outer/HAP 名称分叉、
  长秘密跨流式块、普通/伪装前缀、尾随数据、资源上限读前阻断、非法 UTF-8 名称
  和合法 ZIP/HAP 正向控制。
- **静态诊断通过**：`python -B -m py_compile scripts/validate-release-bundle.py scripts/test_validate_release_bundle.py`，
  exit 0。
- **静态诊断通过**：内容门禁单测 29/29、Node 单一源测试 4/4、147/36 生成
  一致性检查、165 题/33 Topic 内容门禁、Topic 关系门禁和冒烟自测 13/13 均
  exit 0；未运行会写入 `lesson-experiences.json` 的活动生成器。
- **静态诊断通过**：`cd apps/web; pnpm lint`、`pnpm typecheck`、`pnpm test`
  均 exit 0；13 个测试文件、169 项测试通过，无 ESLint 警告或错误。
- **构建通过**：`cd apps/web; pnpm build`，exit 0，Next.js 生产构建成功。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon`，
  exit 0，`BUILD SUCCESSFUL in 5 s 858 ms`；仍有未配置 `signingConfigs` 的既有警告。

失败后纠正：

- 首轮新增名称分叉测试在旧实现上按预期失败；实现原始名称校验后，既有文件名
  敏感信息断言需改为精确的“条目原始文件名”标签，再次运行通过。
- 初版只检查容器首 4 字节，不能排除以 `PK` 本地头伪装的未引用前缀；增加中央
  目录引用的最小本地头偏移必须为 0 后，固定输入从可读变为结构化失败。
- 资源阻断首次把含秘密注释的 HAP 条目排除在内容扫描之外，导致既有深层内容
  断言失败；保留元数据错误但只对路径/名称分叉和资源越界禁止读取，恢复深层扫描
  后 25/25 通过。

未验证：

- **未验证**：本批未创建或修改最终 ZIP/HAP，未执行真实 `--bundle-path` 通过
  记录；固定输入通过只证明门禁合同，不证明正式附件存在。
- **未验证**：outer/HAP 上限是项目内部边界；官方门户的实时总大小、单文件大小、
  上传次数和服务端解包规则尚未在线核验。
- **未验证**：HAP 增量构建仍未签名；模拟器、真机、最终 PDF/MP4、完整播放和
  门户上传均未验证。

## 批次 10：官方 PDF、MP4 与 Demo/源码 ZIP 三文件解析门禁

背景：最终材料此前只有文档清单，没有可执行工具证明文件名、PDF 页数、视频
时长/容器和 ZIP 发布包同时满足合同。以扩展名或自报元数据替代实际解析会把错误
格式误写成通过。

文件：

- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-official-deliverables.py`
- `scripts/test_validate_official_deliverables.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 严格生成并逐字核对 `01-作品说明文档+队名.pdf`、`02-演示视频+队名.mp4`、
  `03-作品名+队名.zip`。`+` 来自官方模板；PDF/MP4 后缀来自同段格式要求。
- 要求调用者提供现有绝对普通文件形式的 `pdfinfo` 与 `ffprobe` 路径，拒绝符号
  链接；使用参数数组、`shell=False`、有限超时和 C locale。工具缺失、超时、
  非零退出、输出超限/无效时只返回结构化错误，不回显媒体路径或工具输出。
- `pdfinfo` 必须解析唯一 `Pages`/`Encrypted`；整份 PDF 为 1..20 页且未加密。
  官方口径是主体不超过 20 页、参考资料及附录不计；整份页数门禁与不得加密是
  内部加严。
- `ffprobe` 必须解析大于 0 且不超过 300 秒的有限时长、至少一个视频流和精确
  `mp4` format token。证据记录实际 `format_names`；失败的 Matroska/WebM 不再
  显示为 `format=mp4`。
- ZIP 直接复用 `validate-release-bundle.py`；三文件只读流式计算 bytes/SHA-256。
  媒体脚本在动态导入前禁用 bytecode，并纳入源码提交 manifest。

官方材料核验：

- **源码确认**：竞赛规程第 6 页与报名手册第 10 页给出三项命名/格式；规程第
  6 页给出主体不超过 20 页及视频 5 分钟内；报名手册第 5 页要求团队名不得使用
  符号，第 12 页限制整个上传更新流程最多 10 次。规程第 5 页将初赛 Demo 标为
  可选，而报名手册上传须知列出三文件；鸿学伴按三文件全部准备的严格口径执行。
- **源码确认**：绝对 `pdfinfo.exe` 路径只读解析两份官方 PDF，均 exit 0；竞赛
  规程 11 页、报名手册 12 页，均 `Encrypted: no`。SHA-256 分别为
  `E5093C61BED5A10C249E165095127AC1F03FD3CE5B8B993D3A8D6AE878BEC1A9` 与
  `6034ACA8F908D76DEBD0EA1DC606C3F594DF8FE29310866F1E5EF91D170BD26E`。
  这只证明官方依据文件，不是鸿学伴最终作品 PDF 通过。

验证：

- **静态诊断通过**：`python -B scripts/test_validate_official_deliverables.py`，
  exit 0，18/18 通过；覆盖 1/20/21 页、加密/字段异常、0/300/300.001 秒、无
  视频流、错误容器、非法 UTF-8、工具路径/符号链接/缺失/超时/非零/输出超限、
  Windows 参数数组、C locale、秘密不回显、实际格式证据与 bytecode 兜底。
- **静态诊断通过**：四个 Python 文件 `py_compile`、发布包固定输入 25/25、内容
  门禁 29/29、Node 单一源 4/4、147/36 生成一致性、165 题/33 Topic 内容门禁、
  Topic 关系门禁与冒烟自测 13/13 均 exit 0。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均 exit 0；
  13 个测试文件、169 项测试通过，无 ESLint 警告或错误。
- **构建通过**：Web `pnpm build` exit 0；HarmonyOS
  `.\hvigorw.bat assembleHap --no-daemon` exit 0，`BUILD SUCCESSFUL in 4 s 961 ms`；
  HAP 仍未配置 `signingConfigs`。

失败后纠正：

- 初次媒体单测 14 项中 1 项失败：Windows 将 `Path` 参数渲染为反斜杠，而测试
  硬编码正斜杠；改为断言 `str(Path(...))` 后通过，没有放宽绝对工具路径合同。
- 首次官方 PDF 汇总 PowerShell 在 `foreach` 后直接接管道，解析失败 exit 1；
  改为先收集对象再输出后 exit 0，未修改任何 PDF 或产品文件。

未验证：

- **未验证**：仓库没有最终鸿学伴作品 PDF、PPT 源文件或 MP4，也没有正式三
  文件 ZIP；因此没有运行真实 `validate-official-deliverables.py` 全通过流程。
- **未验证**：没有最终 MP4 可供实际 `ffprobe` 与完整人工播放核验；固定输入不
  等于成片编码、音画同步、字幕可读性或 5 分钟演示完成。
- **未验证**：官方最新作品说明模板文件仍不在仓库；当前门禁不能证明最终 PDF
  使用了门户当期模板。门户大小限制、10 次额度余量和实际上传结果未在线核验。

## 批次 11：评分证据矩阵与黄金 4:45 演示结构门禁

背景：50/20/20/10 + 应用价值 20 证据矩阵、初赛一句话/两图/800 字和黄金镜头
表已经写入交付计划，但没有自动检查分值、证据等级、字数与时间轴连续性；文档
编辑可能重新引入旧失实口径或把未采集的图片写成已完成。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-competition-evidence.py`
- `scripts/test_validate_competition_evidence.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 直接把现有 Markdown 作为单一来源，解析评分矩阵的精确表头与 13 行数据；五个
  官方维度必须为创新性 50、完备度 20、前景评估 20、规范性 10、实际应用价值
  20，且证据等级只能使用仓库定义的七种明确等级。
- 一句话创新点和 800 字介绍必须分别是唯一非空 Markdown 引用；当前介绍为 467
  个 Unicode 字符。严格交付口径必须保留图 1、图 2 两个小节，真实证据采集前
  两图各自保持**未验证**。
- 黄金镜头表逐段解析 `mm:ss-mm:ss`，要求从 00:00 无空档、无重叠地连续到
  04:45，任何段不得超过 300 秒。当前为 7 段、总终点 285 秒。
- 正式产品叙事、两图说明和镜头表拒绝“总题库 60 题”“78/78”“答案 100%
  正确”“所有 AI 输出都有引用”；审计章节可保留这些文字用于说明禁止项。
- 门禁和测试纳入源码提交 manifest；命令输出明确说明只证明结构与口径，不提升
  卡片、通知、模型请求、ArkData 回写、两图或成片的证据等级。
- 独立只读复核纠正矩阵中的 NOTICE 状态：仓库已有未签署审计草案，但最终逐包
  许可证索引、真实团队审阅和签署声明仍为**未验证**，不再写成文件尚未生成。

验证：

- **静态诊断通过**：`python -B -m py_compile scripts/validate-competition-evidence.py scripts/test_validate_competition_evidence.py`，exit 0。
- **静态诊断通过**：`python -B -m unittest scripts/test_validate_competition_evidence.py -v`，
  exit 0，6/6 通过；覆盖错误分值、非法证据等级、时间轴空档/超时、801 字介绍、
  缺图和正式叙事重新出现旧失实口径。
- **静态诊断通过**：`python -B scripts/validate-competition-evidence.py`，exit 0，
  `scoreRows=13; timelineSegments=7; timelineSeconds=285; introductionCharacters=467`。

失败后纠正：

- 首轮新单测把当前镜头表误数为 6 段，实际表格为 7 段，单测 exit 1；按 Markdown
  真实行数修正固定断言后 6/6 通过，未修改产品镜头表或压缩时间段。

未验证：

- **未验证**：两张图仍未从最终 HAP 采集；门禁只要求继续如实标记未验证。
- **未验证**：黄金时间轴连续不等于真实 Chat、Quiz、卡片/通知和 ArkData 回写
  已在同一提交、同一 HAP、同一账号状态运行通过。
- **未验证**：最终旁白、字幕、原始录屏、完整播放和镜头/证据编号映射尚不存在。

## 批次 12：正式发布证据索引与包内提交/HAP 绑定门禁

背景：最终发布包此前只要求 `release-evidence-index` 角色的附件存在且 bytes/SHA-256
与 manifest 一致，没有解析附件语义；同步修改附件与 manifest 后，空 JSON 对象也能
满足完整发布包门禁。评分矩阵 13 行已有独立 Markdown 门禁，本批只负责最终发布
流水的七个证据面，不复制评分声明 schema。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-release-evidence.py`
- `scripts/test_validate_release_evidence.py`
- `scripts/validate-release-bundle.py`
- `scripts/test_validate_release_bundle.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 新增只读 UTF-8 JSON 门禁。顶层与记录字段使用精确白名单，拒绝重复键、未知字段、
  超限内容和非法时间；`sourceCommit` 与 `hapSha256` 分别绑定发布 manifest 和包内
  唯一 HAP 的实际字节。
- 记录必须恰好覆盖 `source-package`、`web-validation`、`harmonyos-build`、
  `golden-demo`、`final-media`、`license-and-originality`、`portal-upload` 七个发布面
  各一次；缺失、重复、额外标识和大小写变体都会失败。该固定集合是项目内部加严，
  不冒充官方 PDF 新增字段。
- 证据等级只接受仓库七种精确等级。静态诊断/构建记录必须绑定成功命令，构建记录
  必须有产物；模拟器、真机、线上记录还必须有成功命令、明确环境、证据文件和业务
  检查。`未验证` 必须说明缺口，且不得夹带命令、退出码、环境、产物或业务通过字段。
- 完整发布包门禁动态复用新门禁。合法七记录固定输入保持正向通过；将索引替换为
  空对象并同步更新 manifest bytes/hash 后仍失败；分别伪造索引提交与 HAP 哈希时，
  两个绑定错误都会从完整包检查返回。
- 独立子 agent 只读复核确认必须使用固定完整集合并阻断“未验证”夹带通过字段。
  复核提出的 13 个评分声明 ID 已由既有评分矩阵门禁负责；本批保留七个发布流水面，
  避免用一个 JSON 同时承担评分声明与发布验收两种合同。子 agent 未修改文件或 Git。

验证：

- **静态诊断通过**：`python -B -m unittest scripts/test_validate_release_evidence.py -v`，
  exit 0，7/7 通过；覆盖完整七记录、提交/HAP 绑定、精确字段、缺失/重复/额外 ID、
  证据等级、未验证互斥、时间、重复 JSON 键和资源上限。
- **静态诊断通过**：`python -B -m unittest scripts/test_validate_release_bundle.py -v`，
  exit 0，27/27 通过；新增全包空对象和提交/HAP 绑定固定输入，既有归档结构、资源
  上限、秘密不回显及合法 ZIP/HAP 正向控制继续通过。
- **静态诊断通过**：`python -B scripts/test_validate_official_deliverables.py`，
  exit 0，18/18 通过。
- **静态诊断通过**：内容门禁单测 29/29、Node 单一源测试 4/4、147/36 生成一致性、
  165 题/33 Topic 内容门禁、Topic 关系门禁、评分证据 6/6 与两个 PowerShell 运行时
  的冒烟自测 13/13 均 exit 0。内容门禁继续报告答案位置 `A=42、B=43、C=41、D=39`、
  难度 `easy=67、medium=65、hard=33`。
- **静态诊断通过**：Web `pnpm lint`、`pnpm typecheck`、`pnpm test` 均 exit 0；
  13 个测试文件、169 项测试通过，无 ESLint 警告或错误。
- **构建通过**：Web `pnpm build` exit 0；HarmonyOS API 12 增量命令
  `.\hvigorw.bat assembleHap --no-daemon` exit 0，`BUILD SUCCESSFUL in 6 s 504 ms`；
  仍有未配置 `signingConfigs` 的既有警告。

未验证：

- **未验证**：本批没有生成或提交发布证据 JSON、最终 ZIP、HAP、PDF 或 MP4；固定
  输入通过只证明门禁合同，不能证明正式附件已经准备或完整发布包通过。
- **未验证**：增量 HAP 未配置正式签名，也没有安装、模拟器、真机或线上业务流程
  证据；构建通过不能升级为这些等级。
- **未验证**：内容门禁未联网复查 36 条外部 URL，NOTICE 仍含正式提交前人工处理
  标记；许可证/原创/AI 声明签署、最终媒体完整播放和门户上传均未验证。

## 批次 13：黄金 4:45 镜头 ID、分列业务锚点与同版合同门禁

背景：批次 11 只检查镜头表四列非空、时间连续和 04:45 收束。纯内存固定输入把
`01:20-02:25` 的 Chat 段替换成“占位操作/占位讲解/占位证据”后，旧门禁仍输出
`GENERIC_TIMELINE_FALSE_PASS=True`、`ERROR_COUNT=0`。它不能阻止镜头表保留时间但
丢失真实 Chat、Quiz、ArkData 或主动服务业务合同。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `scripts/validate-competition-evidence.py`
- `scripts/test_validate_competition_evidence.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 黄金时间轴增加 `D01-release-identity` 至 `D07-evidence-close` 七个稳定镜头 ID，
  与现有七段和 `00:00` 到 `04:45` 时间逐段绑定；缺失、重复、额外、乱序或时间变化
  均会失败。这些 ID、4:45 目标和锚点是项目内部加严，不冒充官方新增要求；官方
  边界仍是视频不超过 5 分钟并完整展示核心功能。
- 每个镜头分别校验“画面与操作”“讲解重点”“通过证据”三列，共 52 个当前计划中
  已存在的最小业务锚点。把全部关键词堆入错误列不能通过；Chat 段必须分别保留
  真实等待/SSE/当次引用、Agent 链路，以及新 `POST /api/chat`、`done` 和实际返回
  检查，其他六段同样约束发布身份、主动服务、Topic、Quiz、ArkData 与证据收束。
- 时间轴还必须保留“同一提交、同一 HAP、同一测试账号状态、真实线上调用”四项
  全链路合同。把它改成不同版本、不同账号或历史缓存时，静态计划门禁明确失败。
- 计划要求 `D01..D07` 同时进入原始片段清单和证据登记表，每段记录完整提交、
  HAP SHA-256、采集时间、设备、方向、分辨率和原始证据路径；真实素材未采集前
  明确保持**未验证**。
- 独立子 agent 只读确认七个 ID、七段、时间和原 30 个锚点均与当前计划精确一致，
  同时复现“锚点堆错列”和“同版合同改反仍通过”两个漏检。本批逐项修复并扩展为
  52 个分列锚点与 4 个上下文锚点；子 agent 未修改文件或 Git。

验证：

- **源码确认**：修复前纯内存占位 Chat 固定输入返回零错误；修复后同类输入、锚点
  放错列、七段逐项移除 52 个锚点、镜头 ID 重复/缺失、时间不连续/超限和四项同版
  合同反向表述均由固定测试拒绝。
- **静态诊断通过**：`python -B -m unittest scripts/test_validate_competition_evidence.py -v`，
  exit 0，8/8 通过；子测试逐一覆盖 52 个分列业务锚点。
- **静态诊断通过**：`python -B scripts/validate-competition-evidence.py`，exit 0，
  `scoreRows=13; timelineSegments=7; timelineSeconds=285; introductionCharacters=467`。
- **静态诊断通过**：`python -B -m unittest scripts/test_validate_competition_content.py -v`，
  exit 0，29/29 通过；`python -B scripts/validate-competition-content.py` exit 0，
  165 题/33 Topic、147/36、33 个 Lesson 体验与源码 manifest 预检继续通过。

未验证：

- **未验证**：`D01..D07` 原始片段、证据登记表、最终两图和 MP4 均不存在；门禁只
  证明计划保留可复现合同，不证明任何镜头已经拍摄或真实业务已经通过。
- **未验证**：同一提交/HAP/账号的整条链路、最终 HAP 的服务卡片和系统通知、端侧
  新输入触发真实 Chat SSE、Quiz 全流程及 ArkData 退出重进持久化均未验证。
- **未验证**：本批只修改文档和 Python 门禁，没有重复执行 Web/HAP 构建；批次 12
  的构建记录属于前一提交，不自动升级为本批提交证据。签名 HAP、PDF/ZIP、最终
  媒体完整播放和门户上传仍未验证。

## 批次 14：评分、证据、发布包、媒体与源码 manifest 最小依赖闭包

背景：`SUBMISSION-SOURCE-MANIFEST.md` 的“主线最小依赖”仍停留在早期发布包门禁，
只列内容门禁、NOTICE 和发布包脚本；后续增加的评分矩阵、证据索引和正式媒体门禁
及测试没有形成可执行闭包。单看文件存在不能证明动态导入、测试目标和操作手册命令
仍指向同一组精确文件。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-release-dependencies.py`
- `scripts/test_validate_release_dependencies.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 新增只读依赖门禁，要求 source manifest 直接收录 16 个运行时、测试和审计文件，
  并保留 `apps/harmonyos`、`apps/web` 两个完整源码根；所有直接文件必须在 Git 索引。
- 从实际模块属性读取 6 条运行时边：内容门禁到 source manifest/NOTICE、评分门禁到
  评分计划、发布包到内容/证据门禁、正式媒体到发布包。另加载 6 个测试的
  `SCRIPT_PATH`，证明每个固定输入仍指向对应验证脚本。
- 评分计划必须保留内容、评分、证据索引、发布包、依赖闭包和正式三文件六个命令。
  正式媒体清单补入 `validate-official-deliverables.py` 的完整参数；内容章节补入总内容
  门禁，不再只列题库生成器和 Topic 关系检查。
- 文档用当前运行时闭包替换 `fbe0ad2` 时代的最小依赖描述。主线采用时保留自己当前
  的完整应用根；`lesson-experiences.json` 是内容门禁运行输入，但不是 WS06 独立
  移植依赖，门禁会拒绝把该路径直接加入 include。不得整提交采用 `5d1e75f` 覆盖它。
- 独立子 agent 只读确认既有闭包为 14 个文件、6 条运行时边，并核对五个既有测试
  的相邻脚本导入；新门禁再把自身脚本/测试加入闭包，形成 16 个直接文件和六组测试。
  `pdfinfo`、`ffprobe` 必须由调用者传入现有绝对普通文件路径，不是仓库文件依赖；
  子 agent 未修改文件或 Git。

验证：

- **静态诊断通过**：`python -B -m unittest scripts/test_validate_release_dependencies.py -v`，
  exit 0，6/6 通过；覆盖直接缺失、未跟踪文件、运行时/测试边漂移、文档命令缺失和
  Lesson 内容被列为独立移植依赖。
- **静态诊断通过**：`python -B scripts/validate-release-dependencies.py`，exit 0，
  `directFiles=16; testFiles=6; runtimeEdges=6; testEdges=6; planCommands=6`。
- **静态诊断通过**：评分/演示 8/8 与当前计划、证据索引 7/7、发布包 27/27、正式
  PDF/MP4/ZIP 媒体 18/18、内容/manifest 29/29 及内容总门禁均 exit 0。
- **源码确认**：依赖子 agent 逐文件读取动态导入和默认路径，结论与门禁采集的六条
  运行时边一致；没有新增或读取伪证据 JSON，也没有创建正式媒体或发布包。

失败后纠正：

- 新脚本加入 manifest 但尚未暂存时，正式命令首次 exit 1，精确报告两个新增文件
  “未被 Git 跟踪”；精确暂存脚本、测试与 manifest 后，同一命令 exit 0。没有放宽
  Git 索引约束或把未跟踪文件写成通过。
- 首轮固定输入示例把 `test_validate_release_evidence.py` 的下划线写成连字符；按当前
  manifest 精确文件名修正后，依赖单测 6/6 和真实门禁均通过。

未验证：

- **未验证**：依赖闭包通过只证明当前 Git 索引、动态路径、测试目标和文档命令一致，
  不证明最终 PDF/MP4/ZIP、证据索引或签名 HAP 已经生成和通过。
- **未验证**：仓库没有最终媒体可供真实 `pdfinfo`/`ffprobe` 解析，也没有执行完整
  人工播放、HAP 安装、模拟器、真机或门户上传。
- **未验证**：本批没有修改应用源码，因此未重复 Web/HAP 构建；此前提交的构建记录
  不自动升级为本批提交证据。NOTICE 人工处理、签署声明和线上业务流程仍未完成。

## 批次 15：发布证据 schema v2、线上业务谓词与实际 artifact 绑定

背景：批次 12 的证据索引已绑定提交和 HAP，但运行证据字段仍是自由文本。纯内存
固定输入把 `web-validation` 标为线上通过，只填写 `curl endpoint`、`HTTP 200`、
`output`、`ok`，旧门禁仍返回 `GENERIC_ONLINE_EVIDENCE_FALSE_PASS=True`、
`ERROR_COUNT=0`。HTTP 200 和泛化 `ok` 不能证明 Health、Chat、Plan、Quiz 的业务成功。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-release-evidence.py`
- `scripts/test_validate_release_evidence.py`
- `scripts/validate-release-bundle.py`
- `scripts/test_validate_release_bundle.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 证据索引升级为不兼容的 `schemaVersion=2`，旧 v1 自由文本明确失败。命令必须是
  1..32 项 argv 数组；环境、artifact 和业务检查改用精确对象，未知/缺失字段、错误
  类型、重复 ID、非法路径和资源超限都会失败。
- 静态/构建环境固定为 `os/tool/toolVersion`；模拟器/真机固定为设备、系统、方向及
  `{widthPx,heightPx}` 分辨率。线上 Web 环境必须在同一无凭证 HTTPS origin 上恰好
  记录 `GET /api/health`、`POST /api/chat`、`POST /api/plan`、`POST /api/quiz`，路径、
  方法精确且四项状态均为 200，URL 不接受 query/fragment。
- Web 线上记录必须恰好覆盖 16 个业务检查。Health 要求 `ready`、精确模型与部署；
  Chat 要求正文长度、事件顺序、无 error 事件、有效 done 与真实引用数；Plan 要求
  日期、任务数量/结构与安全；Quiz 要求展示题不泄露答案/解析且 grading 独立、结构
  正确。每项 `actual` 按布尔、正整数、非负整数或精确字符串分别校验，统一 `ok`
  不能通过。
- 核对当前源码后修正线上口径：生产无状态中间件对 `/api/quiz/submit` 返回
  `404 ENDPOINT_DISABLED`。Web 线上只验 `/api/quiz` 生成包；提交评分和 ArkData
  写回属于 HarmonyOS 黄金演示设备证据，不再伪称线上评分通过。
- Artifact 每项使用 `{path,kind,bytes,sha256}`。完整发布包把实际 ZIP entries 传给
  证据门禁逐条核对；新增端到端固定输入证明真实 `README.md` bytes/hash 可通过，
  即使同步重哈希 evidence 附件，篡改 artifact metadata 仍失败。独立 evidence CLI
  没有 resolver，含正向等级时明确失败，只能验收全部未验证索引。
- 独立子 agent 复现自由文本、单 endpoint 和未绑定 artifact 三类 false-pass，核对
  无状态 Quiz 与 Chat 错误流源码，并提出四请求、actual 谓词、设备分辨率对象及
  artifact 实际字节绑定。本批逐项采用；子 agent 未修改文件或 Git。

验证：

- **静态诊断通过**：`python -B -m unittest scripts/test_validate_release_evidence.py -v`，
  exit 0，10/10 通过；覆盖 v1 拒绝、四请求、16 业务谓词、设备分辨率、argv、等级
  互斥、artifact resolver、提交/HAP、重复键和资源上限。
- **静态诊断通过**：`python -B -m unittest scripts/test_validate_release_bundle.py -v`，
  exit 0，28/28 通过；新增 evidence artifact 与实际 ZIP 条目 bytes/hash 的正反控制。
- **静态诊断通过**：正式媒体 18/18、最小依赖 6/6、评分/演示 8/8、内容/manifest
  29/29 及对应总门禁均 exit 0。
- **源码确认**：正向 online 固定输入使用 `.invalid` 域名和明确“只验证 schema”的
  合成 artifact 字节；它只证明结构校验路径，不证明任何真实端点、模型或产品流程
  通过，也没有生成正式 evidence JSON。

失败后纠正：

- 首轮 v2 单测 10 项中 1 项失败：`chat.body` 同时误入布尔集合，而合同要求正整数
  正文长度；移出布尔集合并保留固定检查全集后重跑 10/10 通过。
- 第二轮门禁已正确拒绝字符串 `chat.done`，但错误只显示数组下标，单测无法定位
  固定检查 ID；错误标签加入经过小写 ID 校验的 `chat.done`，仍不回显 actual 正文，
  再次重跑通过。

未验证：

- **未验证**：当前没有正式 evidence JSON，也没有实际线上日志、UI 树、截图、视频
  或门户回执可作为包内 artifact；七个发布面继续保持未验证。
- **未验证**：结构化固定输入与 `.invalid` URL 不发起网络请求，不能证明 Health、
  Chat、Plan、Quiz 当前在线、业务成功或错误边界通过。
- **未验证**：本批没有修改应用源码，因此未重复 Web/HAP 构建；签名 HAP、模拟器、
  真机、最终 PDF/MP4/ZIP、完整播放、NOTICE/签署声明和门户上传仍未验证。

## 批次 16：课程列表跨视口与转场安全的实时 UI 树冒烟门禁

背景：已连接模拟器上的原脚本在课程列表直接断言三门课程，第三张卡片不在首屏时
失败；第一次改为滚动后，转场期空 `pagePath` 会触发连续 Back，且整棵 UI 树中的
同名课程或 CTA 可以劫持列表验收。上述行为会使五分钟演示在不同学习进度和列表
位置下不稳定，也可能把错误控件点击写成通过。

文件：

- `scripts/harmonyos-app-smoke.ps1`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 课程 CTA 精确接受当前源码确认的 `进入课程` 和主线集成态的 `继续课程`；三门课程
  在有限实时视口内累计核验，不再要求同时出现在首屏。
- 首次通过精确课程/CTA 锚点识别课程 `scrollable`，保存其实时 bounds；后续前向滚动、
  反向恢复和最终 CTA 点击均只接受同一 bounds 的子树。bounds 消失、重复匹配、缺失
  或越界时明确失败，不回退到整棵 UI 树或固定设备坐标。
- 最终 CTA 从恢复后的新 UI 树重新取得，但只在已绑定课程列表子树内选择可见、可点击
  祖先 bounds；列表外更靠上的同文案按钮不能劫持点击。
- 根页恢复在每次 Back 后同时忽略空路径与 Back 前的旧非空路径，只在页面真正迁移到
  新非空路径后才允许下一次 Back；有限轮询内未迁移则失败，避免越过 `pages/Index`。
- 课程详情不再依赖易漂移的中间标题文案，真实合同收束为 `pages/CourseDetail`、来自
  `knowledge-chunks.json` 的精确 Topic 可点击行及最终 `pages/Lesson`。
- 独立红队以旧非空路径、多滚动区、列表外 CTA 和媒体帧计数固定输入复核旧实现，
  复现多发 Back 与 CTA 越界；子 agent 全程只读，未修改文件或 Git。

验证：

- **静态诊断通过**：PowerShell 7.6.3 执行
  `pwsh -NoProfile -File .\scripts\harmonyos-app-smoke.ps1 -SelfTest`，exit 0，
  17/17 通过；Windows PowerShell 5.1 同一 `-SelfTest`，exit 0，17/17 通过。
- **静态诊断通过**：PowerShell AST `ParseFile`，exit 0，`AST_PARSE=PASS`。
- **构建通过**：`scripts\harmonyos-app-smoke.ps1 -DeviceTarget 127.0.0.1:5555`
  内部 API 12 增量构建 exit 0，`BUILD SUCCESSFUL in 8 s 497 ms`；未执行 clean。
- **模拟器通过**：设备 `127.0.0.1:5555 / TCP / Connected / localhost / hdc`，竖屏
  1256 x 2760。HAP 安装、EntryAbility 启动、`pages/Index`、首页、课程 Tab、三门课程
  跨一个前向视口和一个恢复视口、列表内 `进入课程`、`pages/CourseDetail` 均通过。
  三张本地截图位于 `screenshots/trae-smoke-20260718-203708/`，哈希互不相同；截图
  属于本地验收证据，未加入 Git。

失败后纠正：

- 第一轮设备实跑在首次滚动后遇到多个无锚点 `scrollable`，exit 1；改为首次列表
  bounds 贯穿后，第二、三轮均稳定完成三门课程跨视口与恢复。
- 第二轮在旧 `课程进度` 文案断言处 exit 1；从当前 `CourseDetail.ets` 与 WS03
  `4fd5bef` 精确核对后移除中间文案依赖，第三轮到达真实 Topic 点击合同。

未验证：

- **未验证**：第三轮设备命令整体 exit 1，精确停在“Topmost visible source Topic
  row”没有可点击祖先 bounds；失败后没有运行 `pages/Lesson` 及其后续流程。
- **源码确认**：`git merge-base --is-ancestor 4fd5bef HEAD` exit 1；当前 WS06 分支未含
  WS03 的 Topic 整行进入 Lesson 改动，当前 `CourseDetail.ets` 仍把“学习内容”作为
  独立按钮。不得把本批局部模拟器证据写成完整黄金路径通过；主线集成 WS03 后需重跑。
- **未验证**：未配置正式签名，未执行真机、线上 API、最终 MP4/PDF/ZIP 或门户上传。

## 批次 17：正式证据 artifact、真实 capture 与统一发布预检

背景：批次 15 的 schema v2 仍允许把自由文本、自报 HTTP 200 和合成 JSON 解释为
线上通过；发布包又只允许五类固定附件，导致真实截图、UI 树、视频和原始响应没有
受控角色。评分计划中的两张图长期固定为未验证，官方权重、字数和时长也只依赖文档
硬编码，无法证明与仓库跟踪的两份官方 PDF 同版。

文件：

- `docs/COMPETITION-SCORE-FIRST-PLAN.md`
- `docs/SUBMISSION-SOURCE-MANIFEST.md`
- `scripts/validate-competition-evidence.py`
- `scripts/test_validate_competition_evidence.py`
- `scripts/validate-release-evidence.py`
- `scripts/test_validate_release_evidence.py`
- `scripts/validate-release-bundle.py`
- `scripts/test_validate_release_bundle.py`
- `scripts/validate-official-deliverables.py`
- `scripts/test_validate_official_deliverables.py`
- `scripts/validate-release-dependencies.py`
- `scripts/test_validate_release_dependencies.py`
- `scripts/validate-competition-release.py`
- `scripts/test_validate_competition_release.py`
- `docs/workstreams/06-competition-release-result.md`

行为变化：

- 发布证据升级为 `schemaVersion=3`。运行证据只接受包内 `evidence-artifact`，路径固定
  在 `evidence/artifacts/`；manifest 限制最多 50 项、单项 64 MiB、合计 256 MiB，
  并逐项绑定角色、大小、SHA-256 与 evidence ID 引用闭包。未引用、越界、Git 源文件
  伪装运行证据和附加 ZIP 条目均失败。
- Web `线上通过` 只接受最多 2 MiB、跨度不超过 15 分钟的 HAR 1.2 capture；从原始
  request/response 解析同源 Health、Chat、Plan、Quiz 的 endpoint、时间、HTTP 状态
  和业务字段。旧自报 capture JSON、`.invalid`/本地地址、非 capture artifact、正文
  与索引 hash 不一致均不能授予线上等级。
- `golden-demo` 只接受未验证、模拟器通过或真机通过，且正向等级必须绑定 D01-D07
  七项业务检查和实际 artifact。D02 精确为用户手动创建系统学习提醒、选择时间并
  同步服务卡片；“系统定时主动触达”和无需用户的后台自动提醒叙事被拒绝。
- 两张效果图支持从未验证迁移到模拟器/真机通过：未验证时必须列精确缺口；正向状态
  必须与 `golden-demo` 等级一致并绑定同一 screenshot artifact。已有正向证据时继续
  保留过期“未验证”文本会失败。
- 发布包对 screenshot 解析 PNG 块、CRC、IDAT 解压、位深/色型和扫描行；UI tree 要求
  `pages/*`、有效根 bounds、非空 children 与可见文本 bounds；MP4 先验 box 结构，
  设备正向等级还必须由调用者提供绝对普通文件 `ffprobe`，实际解码出唯一视频流、
  有效尺寸和正帧数。`nb_read_frames=N/A` 与非空 stderr 由两个互不依赖的固定负例
  分别拒绝；ZIP 比较、哈希与秘密扫描使用流式读取，不整包载入内存。
- 官方规则绑定仓库跟踪 PDF：竞赛规程为 11 页、SHA-256
  `E5093C61BED5A10C249E165095127AC1F03FD3CE5B8B993D3A8D6AE878BEC1A9`；报名手册
  为 12 页、SHA-256
  `6034ACA8F908D76DEBD0EA1DC606C3F594DF8FE29310866F1E5EF91D170BD26E`。门禁同时要求
  800 字、视频 5 分钟、50/20/20/10 + 20 权重、三类材料和最多更新 10 次的条款锚点，
  证据等级仍为源码确认，不写成门户线上确认。
- 正式三文件门禁把 PDF 页数、MP4 时长/格式/视频流和最终 ZIP 错误收束为有限 reason
  code；`pdfinfo`、`ffprobe` 路径必须是调用者明确提供的绝对普通文件，超时、缺失、
  非零退出、非法输出均结构化失败且不回显子进程内容。
- 新增统一入口，顺序执行最小依赖、评分证据、内容和正式三文件四阶段；运行前后绑定
  同一 Git HEAD 与干净工作树，单阶段失败不阻止后续只读检查，汇总只输出状态、退出码
  和有限 reason code。所有子 Python 命令带 `-B` 并禁用 bytecode 写入。
- source manifest 闭包扩展为 18 个直接文件、7 个测试文件、11 条运行时边和 7 条
  测试边；统一入口、媒体解析、证据 artifact 和官方 PDF 绑定不能在主线移植时遗漏。

验证：

- **静态诊断通过**：七组 Python 固定输入分别 exit 0，共 133 项：内容 29、评分证据
  11、发布证据 13、发布包 39、正式三文件 20、依赖闭包 8、统一入口 13。
- **静态诊断通过**：`python -B scripts/validate-competition-content.py` exit 0，
  165 题/33 Topic、147 条知识、36 条外部资源、33 个 Lesson 体验与源码 manifest
  通过；外部 URL 仅核验记录状态，未联网。
- **静态诊断通过**：`python -B scripts/validate-competition-evidence.py` exit 0，
  `scoreRows=13; timelineSegments=7; timelineSeconds=285; introductionCharacters=480`。
- **静态诊断通过**：`python -B scripts/validate-release-dependencies.py` exit 0，
  `directFiles=18; testFiles=7; runtimeEdges=11; testEdges=7; planCommands=7`。
- **静态诊断通过**：`cd apps/web; pnpm lint; pnpm typecheck; pnpm test; pnpm build`
  分别 exit 0；13 个测试文件、169 项测试通过，Next.js 生产构建成功。
- **构建通过**：`cd apps/harmonyos; .\hvigorw.bat assembleHap --no-daemon` exit 0，
  `BUILD SUCCESSFUL in 4 s 918 ms`，未执行 clean；仍明确警告没有 signingConfigs。

失败后纠正：

- 内容总门禁首次 exit 1，只报告两个新统一入口尚未被 Git 跟踪；精确暂存两个文件后
  同一命令 exit 0，没有放宽 manifest 的 Git 索引约束。
- 七组聚合测试的工具会话丢失结果，未把它记为通过；改为七个互不依赖的进程后取得
  每组明确 exit 0 和测试数量。
- 独立红队确认旧媒体测试同时设置 `nb_read_frames=N/A` 与非空 stderr，只覆盖先返回的
  stderr 分支；拆为两项后发布包测试从 37 项增至 39 项，两个错误分别独立触发。

未验证：

- **未验证**：仓库没有最终作品说明 PDF、演示 MP4、Demo/源码 ZIP、真实队名和作品名，
  不能构造统一入口的正式实参；没有用两份规则 PDF 或固定输入冒充参赛材料。
- **未验证**：没有正式 evidence index、HAR、截图、UI 树、完整视频、门户回执或签名
  HAP；schema 与解析器通过不证明模拟器/真机/线上/门户业务已经通过。
- **未验证**：`pdfinfo`/`ffprobe` 尚未对最终三文件联合执行，最终 PDF 页数、MP4 完整
  解码与时长、ZIP/HAP 同版绑定和门户上传仍须材料生成后重跑统一入口。
