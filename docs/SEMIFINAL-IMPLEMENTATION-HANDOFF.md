# 鸿学伴复赛实施交接与本地知识入口

更新时间：2026-09-25。供 GPT-6 Sol / high 实施。本文保存已审计事实与已定计划，不表示功能已经落地。

## 1. 接手规则与真实目录

- 用户要求直接推进实施，允许独立子智能体并行；务实、节约额度，不重复全量调研或反复询问日常技术选择。
- 唯一仓库：`/Users/Admin/Desktop/Hormony/hormony`；外层工作区：`/Users/Admin/Desktop/Hormony`。旧 `/Users/Admin/Desktop/鸿学伴` 已被重命名，不存在。
- 9/25 Codex 保存的“鸿学伴”项目已从旧中文路径改到外层 `/Users/Admin/Desktop/Hormony`；真实 Git 仓库在下一层 `hormony`。若线程默认 cwd 不在仓库，命令显式指定仓库 workdir，不复制工程、不重新克隆。
- 审计时分支 `codex/semifinal-macos-20260920`，HEAD `055674c0249391c4c32971b9de9a7d79598dabec`。先 git status 保留所有准备阶段修改，不 reset/clean/全量暂存。
- 只用模拟器、不用真机。登录和账号授权交用户；付费、公开发布、正式竞赛提交核对具体授权。删除目录/批量清理须列精确路径获得确认。
- 本文为当前实施决策；7 月 Windows、初赛、旧通过数和真机门禁不代表当前事实。源码、新证据和用户最新指令优先。

## 2. 9/25 核查快照

| 对象 | 已知事实 | 接手动作 |
| --- | --- | --- |
| Studio | `/Applications/DevEco-Studio.app`，26.0.0；最后检查进程已打开 | 不重装、不从 DMG 启动 |
| 工具 | DevEco CLI 1.3.3、DevEco Code 0.2.0-release；SDK26、Hvigor6.26.4 | CLI优先，本地帮助确认子命令 |
| 模拟器 | Pura X View ARM64，HarmonyOS7.0.0.106，1320×2232，4GB；最后CLI为stopped、设备列表[] | 启动已有实例，不重下镜像；使用实际device target，勿硬编码5555 |
| MCP | 9/20有CodeGenie握手记录；9/25主控当前工具列表未暴露 | 新线程实际有则用，没有就CLI，不反复装插件 |
| HAP | 9/20本机构建成功，unsigned HAP 3,007,449 bytes | 非9/25新构建或签名通过；改后增量构建 |
| 内容 | 本次内容/Topic/发布依赖闭包 exit0；165题、147知识、36资源、33Topic、59活动 | 相关变更后再跑，不重复不变全套 |
| Python | 本次215项：211过，4因报名手册PDF哈希失败 | 见下一节，不改预期值掩盖 |
| Web | node_modules未安装；packageManager锁pnpm11.9.0 | frozen-lockfile安装并跑本机四项检查 |
| 冒烟 | macOS脚本已适配但未提交；pwsh未发现 | 先检测现有便携运行时，再补一份 |
| 设备证据 | `.runtime/audit/2026-09-20/`有计划生成、Lesson、练习、完成记录 | 不代表完整64项冒烟、Chat/Quiz线上、重启或系统回流 |
| 交付物 | 无最终PDF/MP4/源码ZIP/签名HAP；NOTICE人工项待处理 | 功能验收后生成同版本材料 |

HAP：`apps/harmonyos/entry/build/default/outputs/default/entry-default-unsigned.hap`；9/20 SHA256：`86a06d02c759e11e8c07c713d0c7ededdf0e25d9a21831cae5e7c4b34a6d44dc`。

既有未提交修改：根报名手册PDF、`scripts/harmonyos-app-smoke.ps1`、`scripts/test_knowledge_navigation_contract.py`、`scripts/test_validate_official_deliverables.py`；未跟踪`.runtime/`、`docs/astra-review/`、`docs/workflows/`、冒烟说明。两个测试改动是9/20修复的旧断言/跨平台路径；不可盲目回滚。

## 3. 竞赛规则与PDF问题（已核验，无需重复广搜）

报名手册 `2026“中国高校计算机大赛―人工智能创意赛”鸿蒙赛道报名手册.pdf` 的先前变动不是官方更新；12:27 CST 已按用户确认备份并恢复官方原件：

- Git HEAD与9/25官网原件均908,338 bytes，SHA256 `6034aca8f908d76debd0ea1dc606c3f594df8fe29310866f1e5ef91d170bd26e`。
- 先前工作树974,529 bytes，SHA256 `9feb04aab04028fe01b280b883f9687139ef0a2ed99fb5f014c61ac254faf6f9`；Producer为iOS27 Quartz，9/24重新导出。该文件现备份于 `.runtime/backups/registration-manual-reexport-20260925-9feb04aa.pdf`；根目录文件恢复后 SHA256 为 `6034aca8f908d76debd0ea1dc606c3f594df8fe29310866f1e5ef91d170bd26e`。
- 12页去空白文本相同、未发现新增批注；未做逐像素比较。仅恢复这一个文件，没有改测试哈希或回滚其他脏文件。随后 Python 215/215 项通过。

公开规则，核验日2026-09-25：

- 截止9/30 24:00；内部9/29上传、9/30 21:00前最终核对。
- Agent方向评分：创新50、完备20、前景20、规范10；实际应用价值附加20，并非交源码自动获满分。
- 官方FAQ允许模拟器、自选模型；建议三项鸿蒙特性位于应用创新方向，不是Agent硬门槛。保持原参赛作品，不换题。
- 一句话、设计稿、介绍、Demo/源码、≤5min视频五项必选；独立答辩PPT本轮不做。
- 8/26作品说明模板已公开；介绍模板≤1500字、规程≤800字，采用≤800字同时满足，细节放技术方案。
- 一句话≤100字；作品名≤30字符、团队名≤10字符且无标点；主体≤20页，项目按整份≤20页。
- 模板为宋体/A4纵向/单倍行距，上下2.5cm左右3cm，图表编号；不改成自由海报。
- 原创声明需全员与导师签名及日期；复赛报名证明还需学校/院系教务盖章或导师/教务老师/辅导员签名。用户提供，不伪造。
- 最多10次更新已确认；最多10附件、单个2GB、23:59等门户限制仍待登录核对，不能混同。

一手来源：

- [赛道官网、FAQ、规程和模板](https://developer.huawei.com/consumer/cn/activity/incentive/C4)
- [大赛总入口与报名证明](https://developer.huawei.com/home/C4-AI)
- [8/26作品说明模板ZIP](https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyManage/011/111/111/0000000000011111111.20260826100257.97596810096762747811935425558632:50001231000000:2800:84CA048761704AD9EDAB3DB33EA45FFFAEED0A01F4CEBE746FFBCC23C28B250C.zip?needInitFileName=true)
- 根竞赛规程PDF与官网原件一致，SHA256 `e5093c61bed5a10c249e165095127ac1f03fd3ce5b8b993d3a8d6ae878bec1a9`。

最终上传前只定向复核官方变更及门户条件，不反复搜索全部竞赛。

## 4. 功能实施：一个真实学习Agent闭环

定位：面向大学计算机课程，能根据具体作答安排下一步的鸿蒙原生学习Agent。主故事为现有 `cs101 / 图的表示与遍历`：真实作答→针对性提示/课程依据→一个可执行练习→结果回写→下一步改变。保留三课程，不扩科。

### P0：状态与可信度

1. 复现首页陈旧空态：9/20 `21-practice-result`为5/5、课程进度8%，`23-task-complete`已保存，`24-home-after-complete`仍“等待制定计划”。检查HomeContent生命周期/返回刷新及ProactiveLearningService输入，不只改文案。
2. 首页、计划、课程与卡片读取一致新结果；覆盖首次、部分完成、今日全完成、到期错题；退出重开保留状态。
3. “5题全对”改为本轮表现，不称全部掌握；手动勾选任务不等于通过测评。

### P0：有上下文、有行动、有反馈

现状源码：Profile/Safety以规则为主，检索为TF-IDF，编排为关键词路由；Tutor/Planner/Quiz/Evaluator有模型调用。Chat计划/题目变成文本，evaluate传answers=[]；阶段SSE不等于token级流式。不要夸称自主多Agent、事实核验或消除幻觉。

- 增量扩展 `ChatRequest.context`，传本次课程/主题、当前题目或活动、实际作答、是否已提交。明确学习场景优先于关键词；具体错题分析必须消费真实作答。未提交先提示，提交后复盘。
- 增加可选SSE `action`，动作限 `lesson / practice / quiz / review`，附现有courseId/topic、标题、理由；同步校验、HarmonyOS/Web消费方及必要会话序列化，兼容旧请求/记录。
- 复用现有路由/课程白名单/端侧仓库，用户确认后执行，真实回执影响再次建议；不执行任意URL，不让模型直接写库或重写整个计划。
- 计划/出题聊天提供现有专用页面可执行入口，不把文本称为已保存计划。
- 取消/失败/Safety拒绝不记录成功，重复点击不重复累计；展示真实阶段和可展开引用，删除“幻觉风险低”等过度承诺。
- 保持现有生产模型及API12目标，端侧状态以ArkData为准、云端无状态；不引入新Agent框架、向量库、后台自主循环。

不做OCR/语音、扩科、社区、教师后台、账号体系、跨设备同步、大规模迁移和全量导航重构。卡片/通知只在当前模拟器证实后进入演示，不成为主故事前置条件。

## 5. 设计决策：墨蓝学习工作台

本节为9/20截图与源码支持的设计研究，不冒称9/25现场视觉验收。现状问题：同尺寸大白卡、全宽蓝按钮重复，Lesson整段22fp粗体导致真正操作在屏下。

- 保留品牌蓝 `#176BFF`；深色 `#111827` 用于一块当前行动主卡/推演画布，其余浅灰蓝底与白表面。状态色只表达真实状态。
- 标题24–28fp、模块18–20fp、正文15–16fp/行高24–26、辅助12–13fp；取消整段粗体。手机边距约20vp、卡内16vp、区块24vp，主要触控≥48vp。
- 每屏一个主操作，普通任务扁平列表；延用系统Symbol与160/220ms动效。不加吉祥物、新图标库、粒子效果或全面暗色模式。

| 核心屏 | 确定改法 |
| --- | --- |
| 今日 | 墨蓝主卡回答做什么/为什么/投入；首屏还有一条今日任务，无证据不假称弱点 |
| 计划 | 压缩目标区，默认今天展开、未来按日折叠；学习主操作，手动完成次操作 |
| Lesson | 短解释→操作→检查；压缩掌握标准，正常字重，使练习靠前 |
| Chat | 当前题目/作答上下文保留；一个误解、一条提示、一个下一步；来源近结论、技术过程折叠 |
| 结果 | 本轮表现+待澄清问题+唯一补学动作；错题展开、正确题折叠；无前测不画提升 |

唯一新增教学可视化：图遍历节点/边、队列/访问序列，原生单步和预测；不建通用平台。当前BFS示例和DFS活动图数据不同，分开绑定，未提交测验不提前展示答案。精确活动ID：`cs101-图的表示与遍历-1`（DFS output_predict），`cs101-图的表示与遍历-2`（BFS step_order）。

手机单栏优先，实际可用宽度≥840vp时仅Lesson双栏（内容/推演+练习/依据）；不要把1320物理像素当vp。新版本须取当前截图检查手机、大字号及宽屏。

已查参考，仅借模式不抄品牌/内容资产：

- [HarmonyOS设计](https://developer.huawei.com/consumer/cn/design/)：原生层级与宽屏重排。
- [Brilliant教学方法](https://brilliant.org/resources/choosing-brilliant/how-brilliant-teaches-math/)：预测、动手、即时反馈。
- [Khanmigo](https://www.khanmigo.ai/)：提示学生思考而非代答。
- [Anthropic Agent工程](https://www.anthropic.com/engineering/building-effective-agents)：简单可测的反馈闭环，不要求换供应商。
- [旧产品研究](astra-review/product-experience-direction.md)：外部资源矩阵可复用；Perseus/Moodle/assistant-ui仅借鉴模式，FSRS/Lottie赛前不接入。

## 6. 高效工具入口

先读AGENTS与本文，再按批次读相关源码/测试；不全量加载docs、不重复研究已定策略。9/25已执行的诊断：

```sh
git status --short --branch
git log -5 --oneline
DEVECO_CLI_STUDIO_PATH=/Applications/DevEco-Studio.app devecocli device list --format json
DEVECO_CLI_STUDIO_PATH=/Applications/DevEco-Studio.app devecocli emulator list --format json
```

启动/操作命令先用对应CLI帮助核对；UI和本地官方文档检索见 [CLI/MCP说明](workflows/deveco-cli-mcp.md)。示例5555是历史，不等于当前目标。MCP实际可用则用，没有就CLI；verify_ui另需视觉模型服务，不能假定可用。

在 `apps/harmonyos` 增量构建，复用Studio内置工具，不clean、不再下载API12 SDK：

```sh
env NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node \
  JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
  DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  HVIGOR_USER_HOME=/Users/Admin/Desktop/Hormony/.runtime/hvigor \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleHap --mode module -p product=default -p buildMode=debug --incremental --no-daemon
```

- Python：`/Users/Admin/.local/bin/python3.12 -B -m unittest discover -s scripts -p 'test_*.py'`。
- 同一Python运行 `scripts/validate-competition-content.py`、`scripts/validate-topic-relations.py`、`scripts/validate-release-dependencies.py`。
- Web：packageManager规定pnpm11.9.0，`pnpm install --frozen-lockfile` 后 lint/typecheck/test/build；不重写锁文件。
- 冒烟：[脚本说明](../scripts/harmonyos-app-smoke.md)；pwsh到位后先-SelfTest、-CheckEnvironment，再实际设备。HDC/Hvigor传Studio精确路径。
- UI坐标取实时树；截图验证视觉，业务回执/日志验证行为；不能靠UI提示证明模型与持久化成功。
- 就近测试先行，行为批次结束做全套；不重复不变检查，不为纯文档跑生产构建。保留失败证据，不用假数据或跳过检查“通过”。

## 7. 批次、验收与提交物

| 日期 | 完成定义 |
| --- | --- |
| 9/25 | 补依赖、启动已有模拟器、建立本机基线；PDF确认和团队签字并行 |
| 9/26 | 首页一致性、上下文、受控行动与回写；相关测试通过 |
| 9/27 | 五屏层级和唯一图遍历推演，一条可录制主路径 |
| 9/28 | 集成、真实接口/模拟器/恢复验证，冻结功能 |
| 9/29 | 同版本PDF/MP4/ZIP完成，用户确认上传并保存回执 |
| 9/30 | 只修阻断或提交问题，内部21:00前最终核对 |

主控负责Agent/API/状态核心与集成；子代理以独占文件负责UI、测试、材料。不要多人同时修改同一文件，不建立多套依赖/工程。重要里程碑或阻塞才回报。

验收：本机Web四项、HAP增量构建、相关契约/发布门禁；真实Health/Chat/Plan/Quiz分别记录；模拟器主流程→返回→退出重开，另测断网/取消/重试/重复点击。24个固定教学案例（三课各6+6边界），比较事实、针对性、引用、动作，保留失败。请用户协助3–5名学生短任务反馈，无法招募就保留未验证，不模型扮演、不宣称因果提分。

三份核心文件覆盖五项必选内容：

1. `01-作品说明文档+参赛队伍名称.pdf`：约16–18页、整份≤20，遵模板；团队/原创签字、≤100字创意、设计技术方案/真实图、≤800字介绍、评价限制/来源。报名证明按门户栏位处理。
2. `02-演示视频+参赛队伍名称.mp4`：4:30–4:45、≤5min；前25秒痛点，主体作答→辅导→行动→回写，末尾系统能力/评价；标模拟器，不以设计图冒充运行。
3. `03-作品名称+参赛队伍名称.zip`：HarmonyOS+Web Agent全工程、锁文件、配置示例、运行说明、测试/许可，附实际安装验证HAP和签名/运行条件；排除秘密、SDK、node_modules、缓存及私人数据。复用 [源码清单](SUBMISSION-SOURCE-MANIFEST.md) 和现有发布校验器。

材料绑定同一源码版本/HAP哈希/证据索引。9/28若未完成，先砍宽屏增强、装饰动效、额外系统展示，不砍真实闭环、五屏基本品质或必交材料。不临时上架、不扩产品。

## 8. 存储与知识维护

- 9/25约59GiB空闲；Studio约11GB。`/Users/Admin/Desktop/Hormony/command-line-tools`约6.5GB、`/Users/Admin/Desktop/Hormony/devecostudio-mac-arm-26.0.0.821`约3.8GB是重复候选，确认调用不依赖且逐项获批后处理，不自动递归删除。没有清理完成证据。
- 只保留一工具链、一模拟器、当前与上一轮必要证据；旧`../source-main`为失败克隆，不开发。根 `.gitignore` 已在 `b5c3e10` 忽略 `.runtime/`。
- 复用 [工程工作流](astra-review/engineering-workflows.md)：单批忽略目录增长500MiB或总量25%时查原因，不因清缓存而无限重装。
- 后续更新本文状态表和DEVLOG，不新增成套重复PRD/审计/交接。此文未涵盖的细节才定向检索；实现所需最新API、实际依赖变化及最终规则变更仍应查一手资料。
- 旧工作流引用的 `current-agent-capability-audit.md`、`external-learning-agent-landscape.md` 目前未落地，不能当成已有资产；本文件已收录相关核心结论。
- 本轮仅落盘知识与创建实施线程；不恢复PDF、不安装依赖、不改产品代码、不擅自正式提交。

## 9. 9/25 首批实施状态（12:13 CST）

本节更新第 2、4、5、7 节的实施状态；前文保留接手时快照，不能当作最新结果。

- **源码确认**：首页返回刷新与今日全完成态、Chat 具体题目/作答上下文和受控行动、Plan 日期折叠与今日优先、Lesson 图遍历推演、Practice/Quiz 本轮结果层级已实现。服务端按提交状态路由 Tutor/Evaluator，Safety 通过后才发行动；动作仅使用既有课程、Topic 与页面。Web 新代码尚未部署，线上旧版行为不能证明新闭环。
- **静态诊断通过**：Web `lint`、`typecheck`、`test`、`build` 均 exit 0，36 文件、482 项测试；Lesson 图契约 3/3、主动学习服务 24/24；内容、Topic 关系、发布依赖三项校验均 exit 0。
- **构建通过**：API 12 debug 增量 HAP 构建 exit 0，最终未签名产物 SHA-256 `32ee6654597373b3cfe87df43b91353ef0981187b329e80d9a2df6ffa4ad4704`。未配置正式签名，不代表可直接提交安装包。
- **模拟器通过**：已接受首次启动所需 4 份 HarmonyOS 协议，复用 Pura X View、目标 `127.0.0.1:5555`；最终 HAP 安装成功。完整本地冒烟 64/64 exit 0，证据在 `screenshots/trae-smoke-20260925-120400/`。最终安装版计划页今天任务在首屏，截图 `screenshots/semifinal-20260925-plan.jpeg`；旧版线上 Chat 通过宿主网关真实返回并在 UI 显示本机保存。
- **线上通过范围**：12:06 CST 宿主机健康接口 `GET /api/health` 为 HTTP 200、`status=ready`、模型 `doubao-seed-2-1-pro-260628`。这仅证明当前线上旧部署可用；Web 新的上下文和行动事件仍需部署后实测。没有正式发布授权，本批不部署。
- **未通过**：Python 215 项中 211 项通过、4 项只因根目录报名手册 PDF 与锁定官方 SHA-256 不同；等待用户决定是否保留重新导出的单个文件，不修改哈希断言。NOTICE 仍有 3 个人工确认标记。正式 PDF/MP4/源码 ZIP、用户/学生评估、签名 HAP 和门户回执仍未完成。

模拟器协议接受的授权包括后续同类启动步骤；若新协议条款或范围实质变化，应再次核对。继续按原计划制作同版本交付物，最终证据须绑定实际提交 SHA 与产物哈希。

## 10. 9/25 路径与旧资产复核（12:24 CST）

- Codex 保存项目 `鸿学伴` 仍是不存在的 `/Users/Admin/Desktop/鸿学伴`，`list_projects` 将它识别为非 Git 项目。当前实际工作区为 `/Users/Admin/Desktop/Hormony/hormony`；项目路径需要在 Codex 项目设置中重新指向实际目录，工具没有提供更新项目路径的接口。本线程命令继续显式设置工作目录。
- Studio 内置 HDC 和 Hvigor 已分别从 `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc` 与 `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw` 验证；前者列出当前模拟器，后者配套 `NODE_HOME`、`JAVA_HOME`、`DEVECO_SDK_HOME`、`HVIGOR_USER_HOME` 后完成增量构建。完整冒烟 64/64 exit 0，证据 `screenshots/trae-smoke-20260925-122208/`。第一次不传这些环境变量时 Hvigor exit 255，属于运行环境配置失败，不计产品失败。
- 本机候选旧资产：`/Users/Admin/Desktop/Hormony/command-line-tools` 6.5 GB（替代工具已验证）；`/Users/Admin/Desktop/Hormony/devecostudio-mac-arm-26.0.0.821` 3.8 GB（已安装 Studio 的 DMG）；`/Users/Admin/Desktop/Hormony/source-main` 6.3 MB（失败浅克隆，仅剩 Git 元数据和 `.DS_Store`）。删除前仍须按全局规则取得这些精确目录的确认；当前未删除。

## 11. 9/25 获准清理完成（12:27 CST）

用户确认第 10 节列出的三处目录后，逐项核对最终解析路径并删除；三处现均不存在。DMG 可从官方安装源重新下载，命令行工具包可重新安装，失败浅克隆可从 Git 远端重新克隆。Studio 自带 HDC 删除后仍列出 Pura X View `127.0.0.1:5555`；数据卷当前可用空间约 66 GiB。没有清理仓库缓存、截图、构建物、其他脏文件或回收站。

报名手册重导出版本已备份并仅恢复该单文件到 Git HEAD 中已核对的官方原件；`python3.12 -B -m unittest discover -s scripts -p 'test_*.py'` exit 0，215/215。Codex 保存项目后已改到外层目录，仓库感知仍须指向其下的 `hormony`；它不影响以真实仓库目录显式执行命令。

## 12. 9/25 图遍历模拟器路径（12:38 CST）

Pura X View 竖屏 1320×2232，安装的是提交 `b5c3e10` 对应的未签名 debug HAP。本机 UI 树和截图确认：

- 课程目录打开 `cs101 / 图的表示与遍历`；Lesson 1/4 的原生 BFS 图、队列和访问序列可见。队列 `[0]` 正确预测 0 后变为 `[1,2]`；故意选择 2 时状态未推进并提示先看队首；选择 1 后变为 `[2,3]`、访问序列 `[0,1,2,3]`。
- Lesson 4/4 的 DFS 练习图与 BFS 示例图不同。提交前点击“问学伴给一条提示”，Chat 显示“正在作答 · 图的表示与遍历”及原题；界面没有预先显示答案。输入错误序列 `0 3 1 2 4` 并提交后，逐步对照从 1/5 到 5/5，才显示参考答案 `0 1 2 3 4`、对照重点和来源 `cs101_k25`。选择“关键点有遗漏”后，界面回执明确是自我对照，不称客观测评通过。
- 提交后点击“问学伴讲解”，Chat 显示“已提交作答 · 图的表示与遍历”和实际作答；返回课程再打开同主题，活动落在 2/2，证明本机互动断点在页面导航后可恢复。截图 `screenshots/semifinal-graph-start.jpeg`、`screenshots/semifinal-graph-predict.jpeg`、`screenshots/semifinal-dfs-pre.jpeg`、`screenshots/semifinal-dfs-input.jpeg`；UI 树证据在忽略的 `.runtime/layout-graph-*.json` 与 `.runtime/layout-chat-context-*.json`。

这一轮没有发送新上下文到线上：线上仍是旧 Web 部署。新 Tutor/Evaluator 路由、`action` SSE 的端云真实集成仍需用户授权部署后验证；本机 UI 路径不替代该证据。

## 13. 9/25 Preview 部署阻塞（12:40 CST）

本节记录当时失败现场；身份配置及部署状态已按第 16 节更新。

已推送的 `b5c3e10d451b1f6ccacdbdf72731391122153874` 在 GitHub 上产生 Vercel `Preview` deployment `6653572025`，但状态为 `failure`、说明 `Deployment was blocked`。GitHub 的 Vercel commit status 同为 `failure`，目标是 GWYY 团队对提交作者 GitHub 账号 `DostiAziz` 的邀请页面。`Vercel Preview Comments` check 显示 success 只代表评论检查通过，不代表部署可用。不能把返回的 Preview URL 当作新 API 已上线。

进一步核对 GitHub API：该提交的作者和提交者字段均为 `郭泳延 <Admin@MacBook-Pro.local>`，GitHub 将该邮箱关联到 `DostiAziz`；仓库此前提交使用 `Gavin8233841 <guo8233841@gmail.com>`。本次提交由当前实施过程生成，当时未设仓库级 Git 邮箱，回退成了本机邮箱。这是提交身份配置问题，不能据此判断陌生账号参与开发、获得仓库权限或应被邀请进 Vercel。当前 GitHub 登录账号仍为 `Gavin8233841`，查询 `DostiAziz` 对私有仓库的权限为 `none`。

后续先由项目负责人确认合法的提交身份/邮箱，再仅在本仓库设置 Git 作者信息；用正常新提交触发 Preview 并核对实际部署状态。不要邀请未知账号、改写已推送历史或把 Preview 评论检查当作部署成功。新 Chat 上下文、Evaluator 与行动 SSE 仍待新版本可用后做真实接口和模拟器集成验证。

## 14. 9/25 对齐新增：应用文案整治（P0，录制前）

用户反馈页面文字有明显机械化、过度解释和“AI 味”，影响真实产品感。逐屏检查首页、计划、课程/Lesson、练习/测验结果、Chat、记录与空态/错误态；将“先……再……”“证据/Agent/流程”等内部术语和长句改成学生能立即理解的短提示。保留题目条件、必要错误信息及来源，不把调试说明写给学生，也不改变教学事实。

已定位的例子：`Lesson.ets` 的“下一步出队哪个顶点？先选，再看状态变化。”、“逐层推演 · 先预测队首”；`Practice.ets` 的“先看下方展开的解析，核对判断步骤。”；`Quiz.ets` 的“10题 · 稳定证据”、“本轮题组没有可展示的当前题，已保护页面不再崩溃。”；`Chat.ets` 的“从课程资料中找证据”。这些只是首批样本，不是替换清单的全部。

验收：主演示路径每屏主标题、按钮、反馈与失败提示均经人工逐条读通；截图里不出现开发/验收话术；选 3–5 名学生做短任务时记录他们是否看懂操作。文案整理完成后再录正式视频。Web 前端作为辅助调试界面，不占主演示镜头；Web API 是端侧 AI 功能的必要后端。

Codex 保存项目现已由用户改到 `/Users/Admin/Desktop/Hormony`，但 `list_projects` 仍显示非 Git 项目；实际仓库在下一层 `/Users/Admin/Desktop/Hormony/hormony`。本线程使用显式仓库路径继续工作。

## 15. 9/25 产品方向更新：从答题走向学习行动

用户要求先做出可叙事、可交付的学习能力，再完成复赛材料；前文“保留三课程、不扩科”仅是首批实现范围，不再是长期产品边界。主故事定为：学生先尝试 → 学伴根据真实作答指出一个具体问题 → 进入对应课程内容、练习或可信外部资料 → 再做一次检查 → 本机记录更新下一步。不要把同主题跳转、打开链接或手动勾选说成针对性掌握提升。

**P0，复赛前的功能与界面批次**

1. 把行动建议从按意图固定跳转改为消费真实作答/错因；至少同主题两种不同作答给出不同且可执行的下一步，并在结果写回后改变后续建议。模型负责解释，受控目标由现有课程和状态决定；保留提交前不泄题和用户点击才执行。
2. 现有 36 条外部学习资源有索引，端侧 `ResourceLibrary` 原本已调用 `LearningContentRepository.getResources(courseId)`，课程详情已有入口。复赛演示先收敛到三门课各两条核过来源的外链，显示阅读目标并由系统浏览器打开；返回后进入本主题练习或学伴，访问不等于掌握。现有 `/api/resources` 只能筛选索引，没有外部题库搜索/导入能力。
3. 五屏压实：首页首屏直接看到当前学习动作；计划今天优先；Lesson 图和预测操作尽量同屏；Chat 回答与下一步优先、技术过程默认折叠；结果聚焦本轮表现、错题和唯一补学动作。沿用 ArkUI 原生组件与现有设计令牌，改善层级、留白和信息密度，不以装饰动画替代交互。
4. 第 14 节文案整治与上述交互同时完成。正式录制前用最终 HAP 检查主要屏幕、字号与截断；断网、取消、重试和重复点击在功能稳定后集中回归。

**P1，建立扩科与外部题源能力，不挤占复赛闭环。** 财务会计先做一个“交易→分录→报表影响”原创案例试点，英语先做一个“阅读证据→推断→迁移题”试点；分别确认课程目标、来源许可、题目答案与评价方式，再决定是否进主线。外部题库优先接权利明确、答案可核验的小题包；记录来源、版本、适用课程/主题和题目质量，不开放抓取或直接复制第三方练习。[OpenStax 财务会计页](https://openstax.org/books/principles-financial-accounting/pages/preface)当前提示生成式 AI 使用须另得书面许可，只能先作外链/研究，不纳入 RAG；[British Council 分级阅读](https://learnenglish.britishcouncil.org/free-resources/reading)可作为站外资源候选，复制与模型摄入未获核实授权。

验收顺序：先证明两种作答引发不同下一步及回写，再证明外链入口和返回检查，随后做五屏体验及教学案例，最后产出同版本 PDF/视频/源码包。当前生成器核对 Web 唯一源与端侧产物为 **165 题**；`apps/web/src/lib/data/index.ts` 原“186”注释是旧数，已改正。36 条资源的旧访问记录不等于当前链接全部可用。

## 16. 9/25 提交身份与 Preview 状态更新

仓库级 Git 作者已设置为此前合法提交使用的 `Gavin8233841 <guo8233841@gmail.com>`，没有改全局配置或已推送历史。新提交 `8021d6c8b0c4df0fddc16722820a00c2d4271d72` 在 GitHub 的作者与提交者均关联 `Gavin8233841`；Vercel Preview deployment `6654188982` 状态为 `success`、说明 `Deployment has completed`。原 `DostiAziz` 身份拦截已解除。

Preview 地址 `https://hormony-jymx3ippv-gwyy8233841.vercel.app` 当前受 Vercel 登录保护；未认证请求访问 `/api/health` 最终收到 `vercel.com/login` 的 HTML，不能将 HTTP 200 登录页认作 API 通过。需要项目账号的受限访问方式后再测新 Chat/Evaluator/action SSE，且不应为了测试公开整个项目。

主演示路径的静态文案已做第二批精简：Chat 让回答和行动先于技术过程显示；首页主卡压缩；Lesson、Plan、Practice、Quiz 删除开发/验收式措辞。Pura X View 模拟器的 Chat UI 树显示回答正文先于过程卡，截图 `.runtime/semifinal-copy-chat-answer-first-20260925b.png`。此项仍须在真实新回答、五屏截图及学生短任务中复核，不能仅凭旧会话宣布全部完成；模型输出本身也需要减少报告式长文，待可访问新版 API 后校准提示与案例。

## 17. 9/25 可验证 Preview 与真实回答（14:16 CST）

本节更新第 16 节的 Preview 待验证项。提交 `cc96e41d17f59c77d20699d176dd364f1d9ca7bf` 的 GitHub 作者/提交者均为 `Gavin8233841`；Vercel Preview deployment `6654907669` 为 `success`，地址 `https://hormony-c5owmzq5m-gwyy8233841.vercel.app`。已登录 Vercel CLI 通过部署保护访问该地址，`GET /api/health` 为 HTTP 200、`status=ready`、`model.configured=true`、无状态部署。Preview 仍受 Vercel 登录保护，不公开部署或密钥。

合成图遍历题的真实接口回执：未提交时 Chat 进入 Tutor，只提示按邻接点编号排序，不透露下一顶点；提交错误序列 `0 2 1 3 4` 后进入 Evaluator，指出 `1` 应先于 `2`，给出一题可立即完成的小练习，并发出课程练习 `action` 与三条资料引用。此前同一题返回冗长“学习诊断报告”；`cc96e41` 已改为回答学生具体问题、最多三句，不再把正确率报告和空泛分类塞进聊天正文。`POST /api/plan` 返回三天各 30 分钟的阅读、练习、测验任务；`POST /api/quiz` 返回两道图遍历题且题目与评分条目逐项对应。Web lint、typecheck、482/482 测试、build 均通过；新增端侧短文案的 HAP 增量构建通过。以上是 Preview API 与本机构建证据，不是当前 HAP 经新 Preview 的端云联调。

现有 `MODEL_API_KEY` 是 Vercel 的 Production 敏感变量；本次部署时仅临时扩展到 Preview，部署就绪后已恢复 Production-only，未读取或写出密钥值。这个部署保留其创建时的模型配置，但**后续新 Preview 部署不会自动继承密钥**。下一批推送前应配独立、限额且仅适用于目标分支的测试密钥，或按这次方式短时配置并部署后收回。当前 HAP 的 `Constants.BASE_URL` 仍指向旧 Production 地址 `https://hormony-ruddy.vercel.app`；端侧接入新服务及同一版本完整模拟器路径仍列在复赛集成待办，不能用本节接口回执代替。

## 18. 9/25 前端与功能连续打磨计划（当前执行口径）

快速基线：`6170f87` 上 Python 215/215、API12 增量 HAP 构建通过，Pura X View 在线。当前竖屏截图在 `.runtime/design-audit-20260925/`：`01-knowledge.png`、`02-course-detail.png`、`03-course-list.png`、`04-chat.png`、`05-home.png`、`06-profile.png`；只证明这些画面与操作可达，不证明大字号、横屏、真机或新端云回答。旧版 7 月路线与本节冲突时，以本节和当前源码为准。

### 设计方向与问题

- 沿用浅灰蓝底、白色内容面和品牌蓝，墨蓝只给当前最重要的学习动作。使用原生 Symbol；统一标题、正文、辅助信息、间距和触控尺寸。普通列表靠排版与分隔线组织，减少重复大卡。
- `05-home.png`：主卡与下方任务重复；保留主卡的任务、时间和一个开始操作，下方只列其他事项。`03-course-list.png`：每门课都有全宽蓝按钮，入口喧宾夺主；改为紧凑课程行，已学课程明确“继续”，其他课程用普通进入操作。
- `04-chat.png`：历史回答可读，但回答、行动、资料和输入区之间留白过多；把回答与下一步放近，来源可展开，历史消息保持完整。`02-course-detail.png` 与 `01-knowledge.png`：知识、资源、搜索、主题都可达，但结果卡和动作占屏较高，先压缩重复信息，不删来源。`06-profile.png`：学习建议可见，下一批把待巩固主题、记录入口与统计梳理成同一层级。
- 截图只能指出可见层级与截断风险；焦点、读屏、大字号、键盘、安全区和网络恢复须在对应批次实际操作核验。

### 每批约一小时的交付目标

| 批次 | 范围和产物 | 必须看到的结果 |
| --- | --- | --- |
| A：高频入口视觉基准 | `Chat`、`Course`、必要的共用令牌/导航间距；精简标题、消息层级、课程行和主次操作，不改学习数据 | 学伴旧会话回答与行动邻近、输入区无遮挡；课程三门课同屏更易比较；截图、相关契约、API12 构建通过 |
| B：资料成为学习动作 | 从已有 36 条索引中为演示主题核验并接入少量外部资料，显示来源、阅读目标；系统浏览器打开，返回后给练习或简短检查入口 | 课程/学伴能到真实资料；链接失败可恢复；打开链接不计为掌握；来源和许可证记录可查 |
| C：作答驱动下一步 | Web `nextAction` 消费已提交的题目、实际答案与错因；受控动作保持课程/主题白名单，端侧显示一个明确动作 | 同主题两种作答产生不同且合理的建议；未提交不泄题；取消、重试和重复点击不虚记结果 |
| D：学习与复盘五屏 | `Home`、`Plan`、`Lesson`、`Practice`、`Quiz` 和 `MistakeBook`：首屏任务与图上预测、结果页首要错题、补学动作、当天计划层级 | “尝试→反馈→补学→再练→回写”在同一 HAP 连贯可达，返回与重开状态一致；大字号抽样无主操作截断 |
| E：记录与全应用收口 | `Profile`、`ActivityRecords`、`Achievements`、`LearningMap`、`Knowledge`、`CourseDetail`：统一列表、空态、失败态与关系图选中反馈 | 四入口及详情页视觉一致；记录来源清楚；星图选中后能直接到学习动作；无失效入口 |

每批只认当前源码、测试、构建和模拟器证据；必要时把失败记录进 `DEVLOG.md`。先完成 A，再按 B→C→D→E 调整具体文件边界；不为了计划表扩大未验功能。并行只委派只读调查或明确独占文件，主代理负责核心代码、截图复核和提交。财务会计、英语与外部题库保留为后续试点：先完成当前三门课可演示的学习机制，再按来源许可、答案可核验和学习目标逐门接入。

视觉执行不再只靠口头“调整间距”：Astra 已按上述真实截图逐元素审查，方向定为“理工学习手册”；另用图像模型生成同一组课程/学伴双屏概念，保存在 `.runtime/design-audit-20260925/concept-course-chat.png`。它只作为内部构图参考，不是运行截图，不复制其中不存在的搜索、附件或标签功能。借鉴 [Duolingo 官方跨 Tab 改版](https://blog.duolingo.com/core-tabs-redesign/) 的统一标题与信息节奏、[Brilliant 官方学习路径](https://brilliant.org/) 的单步学习动作、[ChatGPT Study Mode 官方说明](https://openai.com/index/chatgpt-study-mode/) 的上下文内辅导方式；不打包竞品截图、品牌、插图或文案。每轮用相同设备和数据对比改前、概念与改后截图，再验真实按钮、路由和状态。

A 批实际落地为已学课程一张续学卡、其余两门课程组成一个目录容器；学伴保留旧会话与真实回答，把练习操作、参考资料和输入区分出清楚层级。Astra 复审真实页面后又收紧了续学卡底部，并统一目录圆角。Pura X View 1320×2232 竖屏截图为 `10-course-refined.jpeg`、`08-chat-first-pass.png`；UI 树确认课程目录进入“操作系统 · 进程与线程”、续学进入“数据结构 · 链表”，学伴“3 条参考资料”可展开、“去练习”进入“数据结构 · 数组与线性表”练习。此批没有验证新在线回答、横屏、大字号或真机。学伴长回答的分段需在后续从模型输出改进，不能由前端猜句子；下一批继续按真实运行截图验收，不以概念图代替，也不把 A 批称为最终视觉完成。

B 批在已有资料页上做来源收敛与学习引导，没有新造浏览器或课程后端。三门课各展示两条官网资料，首项用深色面强调，正文给出具体阅读目标；打开外链返回后出现“问学伴／练习本主题”。学伴预填只问该主题一道题，不声称学生已读完。Pura X View 1320×2232 竖屏证据：`14-resources-aligned.jpeg`、`b-browser-layout.json`、`b-practice-layout.json`、`b-chat-layout.json`，均在 `.runtime/design-audit-20260925/`，不纳入 Git。OSTEP 官网打开、返回、本主题练习与学伴预填已抽样；另外五条核过官网但未逐条在模拟器浏览器打开。六条的链接、权限边界和阅读目标见 [资料核对](RESOURCE-CURATION-20260925.md)。
