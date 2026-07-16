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
