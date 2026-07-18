<!-- competition-source-manifest:v1 -->
```json
{
  "include": [
    "AGENTS.md",
    "DESIGN.md",
    "PRODUCT.md",
    "README.md",
    "apps/harmonyos",
    "apps/web",
    "docs/ACTIVE-LEARNING-SPEC-CS101.md",
    "docs/ACTIVE-LEARNING-SPEC-CS102.md",
    "docs/ACTIVE-LEARNING-SPEC-CS103.md",
    "docs/COMPETITION-NOTICE.md",
    "docs/COMPETITION-SCORE-FIRST-PLAN.md",
    "docs/DEPLOYMENT-GUIDE.md",
    "docs/MODEL-ROLLOUT-STRATEGY.md",
    "docs/SUBMISSION-SOURCE-MANIFEST.md",
    "docs/architecture.md",
    "docs/workstreams/06-competition-release-result.md",
    "scripts/generate-learning-activities.mjs",
    "scripts/generate-learning-content-json.mjs",
    "scripts/generate-learning-content-json.test.mjs",
    "scripts/generate-quizzes-json.mjs",
    "scripts/harmonyos-app-smoke.ps1",
    "scripts/simulator-api-gateway.mjs",
    "scripts/start-simulator-gateway.ps1",
    "scripts/test-chat.mjs",
    "scripts/test_validate_competition_evidence.py",
    "scripts/test_validate_competition_content.py",
    "scripts/test_validate_competition_release.py",
    "scripts/test_validate_official_deliverables.py",
    "scripts/test_validate_release_bundle.py",
    "scripts/test_validate_release_dependencies.py",
    "scripts/test_validate_release_evidence.py",
    "scripts/validate-competition-content.py",
    "scripts/validate-competition-evidence.py",
    "scripts/validate-competition-release.py",
    "scripts/validate-official-deliverables.py",
    "scripts/validate-release-bundle.py",
    "scripts/validate-release-dependencies.py",
    "scripts/validate-release-evidence.py",
    "scripts/validate-topic-relations.py"
  ],
  "exclude": [
    "apps/harmonyos/screenshot",
    "apps/web/BACKEND_P1_FIX_DEVLOG.md",
    "apps/web/BACKEND_P2_CLEANUP_DEVLOG.md"
  ]
}
```

默认门禁通过 `git ls-files` 展开本清单。最终核验前，必须先精确暂存或提交
清单内的新增文件，再运行 `python -B scripts/validate-competition-content.py`；未跟踪文件
不会被目录项隐式纳入，也不得据此宣称最终 Demo ZIP 已通过。

## 最终发布包 manifest

最终 Demo/源码 ZIP 的包根必须包含 `release-manifest.json`。这是鸿学伴为
正式交付设置的内部加严门禁，不是两份官方 PDF 规定的独立上传文件。

顶层必须且只能包含：

| 字段 | 精确合同 |
|---|---|
| `sourceCommit` | 40 位小写十六进制完整 Git 提交哈希，必须等于运行门禁时当前 `HEAD`，且能解析为本仓库提交 |
| `nonGitFiles` | 非 Git 附件对象数组；数组外的额外附件会被拒绝 |

`nonGitFiles` 每项必须且只能包含 `path`、`role`、`bytes`、`sha256`。`path`
必须是规范化的包内相对路径，路径与大小写折叠后的路径都必须唯一；`bytes`
必须是正整数；`sha256` 必须是 64 位小写十六进制值。以下五个基础 `role` 必须
且只能各出现一次：

- `hap`
- `third-party-license-index`
- `originality-declaration`
- `ai-usage-declaration`
- `release-evidence-index`

此外只允许重复角色 `evidence-artifact`：路径必须位于 `evidence/artifacts/`，后缀
只接受 `.har|.jpeg|.jpg|.json|.log|.mp4|.png|.txt|.xml`，最多 50 项，单项不超过
64 MiB、合计不超过 256 MiB。每项都必须被至少一个发布证据 ID 的 `artifacts`
引用；未引用、越界、未声明或额外附件均阻断。

`release-evidence-index` 对应的 UTF-8 JSON 是项目内部证据合同。顶层必须且只能包含
`schemaVersion`、`sourceCommit`、`hapSha256`、`records`、`limitations`；
`schemaVersion` 固定为 `3`，不兼容接受旧自由文本 v1/v2；提交与 HAP 哈希分别绑定
`release-manifest.json` 和包内唯一 HAP 的实际字节，`limitations` 至少保留一项真实
边界。

`records` 必须恰好覆盖以下七个发布面各一次，不接受缺失、重复、大小写变体或额外
标识：

- `source-package`
- `web-validation`
- `harmonyos-build`
- `golden-demo`
- `final-media`
- `license-and-originality`
- `portal-upload`

每条记录必须且只能包含 `id`、`claim`、`level`、`recordedAt`、`command`、
`exitCode`、`environment`、`artifacts`、`businessChecks`、`notes`。`level` 只接受
仓库定义的七种精确证据等级；`recordedAt` 必须是含时区的 RFC 3339 秒级时间。
`command` 只能是 1..32 项 argv 字符串数组或 `null`，与 `exitCode` 同时存在或同时
为空；通过等级必须为 `exitCode=0`。`environment` 使用按等级区分的精确对象：

- 源码确认和未验证：空对象 `{}`。
- 静态诊断/构建：`{os,tool,toolVersion}`。
- 模拟器/真机：`{device,systemVersion,orientation,resolution}`；方向只接受
  `portrait|landscape`，分辨率为 `{widthPx,heightPx}` 正整数对象。
- 线上：`{deploymentVersion,requests}`。`web-validation` 的 requests 必须恰好覆盖
  同一 HTTPS origin 上的 `GET /api/health`、`POST /api/chat`、`POST /api/plan`、
  `POST /api/quiz`，四项 HTTP 状态均精确为 200；URL 不得含凭证、query 或 fragment。

`artifacts` 每项必须且只能含 `{path,kind,bytes,sha256}`。完整发布包门禁会按 path
读取实际 ZIP 条目并逐项核对 bytes/SHA-256；找不到条目或哈希不一致即失败。独立
evidence CLI 没有 artifact resolver，因此只能验收全部保持未验证的索引，不能单靠
自报 metadata 产生正向等级。

`businessChecks` 每项必须且只能含 `{id,passed,actual,artifactPath}`，`passed` 必须为
`true`，`artifactPath` 必须指向本记录声明并由最终 ZIP 解析的实际 artifact。
Web 线上通过必须恰好覆盖以下 16 项，且 actual 使用对应类型/值，不接受统一 `ok`：

- Health：`health.status=ready`、非空 `health.model`、与 deploymentVersion 相同的
  `health.deployment`。
- Chat：正整数 `chat.body`，布尔 `chat.event-order`、`chat.no-error-event`、
  `chat.done`，非负整数 `chat.citations-as-returned`。
- Plan：布尔 `plan.date`、正整数 `plan.task-count`、布尔 `plan.task-shape`、
  `plan.safety`。
- Quiz：布尔 `quiz.no-answer-leak`、`quiz.no-explanation-leak`、
  `quiz.grading-separated`、`quiz.grading-shape`。生产无状态部署不把
  `/api/quiz/submit` 写成线上评分通过，本地评分/回写归黄金演示设备证据。

Web 线上通过必须绑定唯一 `.har` capture。门禁只接受 HAR 1.2 `log`，从恰好四个
`entries[].request/response/content.text` 原始记录推导请求方法、HTTPS endpoint、
含时区时间、HTTP 状态、Content-Type、部署版本及上述业务字段；四个请求须在 15 分钟
内完成。旧 `schemaVersion/capturedAt/deploymentVersion/requests` 自报 JSON、示例域名、
本机地址、非 200、混合 origin、query/fragment、元数据与原始响应不一致均阻断。
固定输入 HAR 只证明解析合同，不构成线上通过证据。

静态诊断、构建、模拟器、真机和线上通过还须分别提供对应类型的实际 artifact。
`golden-demo` 只接受未验证、模拟器通过或真机通过；升级设备等级时必须同时绑定
UI tree 与 MP4，并完整覆盖 `demo.d01` 至 `demo.d07` 七个固定业务检查。两张图在
`docs/COMPETITION-SCORE-FIRST-PLAN.md` 中仍为未验证时必须列出缺口且不得绑定图片；
迁移到模拟器/真机通过时，等级必须与 `golden-demo` 相同，图片必须是该记录实际引用
的 `screenshot` evidence-artifact。若 `golden-demo` 已升级而计划仍写未验证，视为过期
状态并阻断。

完整 ZIP 门禁读取 artifact 实际字节：PNG/JPEG 校验容器、块/段和正尺寸；UI tree
复用当前 `dumpLayout` JSON 根节点的 `attributes/pagePath/bounds/children` 合同；MP4
解析 ISO BMFF box，并要求 `ftyp`、非空 `mdat` 与 `moov/trak/mdia/hdlr=vide`。这些
结构检查只拒绝任意字节伪装，不证明截图内容真实、UI 流程完成或视频可播放；正式
演示视频仍必须由正式三文件门禁使用明确 `ffprobe` 路径解析，并保留人工真实性复核。

`未验证` 必须说明真实缺口，且不得夹带命令、退出码、环境、产物或业务通过字段。
结构通过只证明索引合同和实际包内字节绑定，不会把任一记录自动升级为产品通过。

独立检查命令如下；最终包检查会自动用 manifest 提交和包内 HAP 实际哈希执行同一
校验，因此最终以完整发布包门禁为准：

```powershell
python -B scripts/validate-release-evidence.py `
  --index-path <发布证据索引的明确路径> `
  --source-commit <release-manifest.json 的完整提交> `
  --hap-sha256 <包内唯一 HAP 的 SHA-256>
```

运行命令：

```powershell
python -B scripts/validate-release-bundle.py `
  --bundle-path <最终 ZIP 的明确路径> `
  --ffprobe-path <ffprobe 现有绝对普通文件路径>
```

当全部运行记录保持未验证时，独立 ZIP 静态检查可以省略 `--ffprobe-path`；只要
`golden-demo` 声明模拟器或真机通过，就必须提供该工具并让包内截图、MP4 实际字节
通过解码探测。正式三文件与一条入口始终传入同一个明确工具路径。

脚本只读打开 ZIP，不解压到磁盘，不构建、不清理也不改写文件。它从声明提交的
Git tree 读取本清单展开的源码并逐字比较，同时要求声明提交等于当前 `HEAD`；
非 Git 附件必须与 manifest 的文件集合、字节数和 SHA-256 完全一致。ZIP 与 HAP
内部的原始名称/解析名称分叉、路径穿越、大小写折叠冲突、重复条目、符号链接、
特殊文件、加密条目、非法名称编码、禁止路径、待处理 NOTICE 和可识别敏感信息
都会阻断。最终 ZIP 还必须从 ZIP 结构起始，精确结束于中央目录结束记录及其声明
注释；自解压前缀和尾随数据均不接受。原始 outer 容器以固定大小块只读扫描，
不会把命中的秘密正文写入错误。

门禁采用项目内部安全上限：`release-manifest.json` 不超过 64 KiB，每条包内路径
的 UTF-8 编码不超过 512 字节，ZIP/HAP 条目数不超过 10000，单项压缩比不超过
200:1；outer ZIP 单条目解压后不超过 512 MiB、全部条目合计不超过 1 GiB；HAP
单条目解压后不超过 64 MiB、全部条目合计不超过 256 MiB。所有资源上限都在
读取条目正文前检查。这些值不是官方门户大小限制，门户限制仍为**未验证**。

`-B` 与脚本导入前设置的 `sys.dont_write_bytecode` 共同保证正式门禁不会在源码树
写入 `__pycache__`/`.pyc`。不得通过清理命令掩盖门禁自身的文件副作用。

### 主线最小依赖与 manifest 校准

当前正式交付链的运行时依赖闭包为：

- 内容/源码：`scripts/validate-competition-content.py`、本文件和
  `docs/COMPETITION-NOTICE.md`。
- 评分/演示：`scripts/validate-competition-evidence.py` 和
  `docs/COMPETITION-SCORE-FIRST-PLAN.md`。
- 发布证据：`scripts/validate-release-evidence.py`。
- 最终 ZIP：`scripts/validate-release-bundle.py`，运行时动态复用内容门禁、评分门禁和
  发布证据门禁，并交叉绑定两图状态。
- 正式媒体：`scripts/validate-official-deliverables.py`，运行时动态复用最终 ZIP
  门禁。
- 一条入口：`scripts/validate-competition-release.py`，按依赖、评分证据、内容源码、
  正式三文件顺序运行，正式三文件继续递归覆盖最终 ZIP，不重复执行同一包门禁。
- 依赖闭包：`scripts/validate-release-dependencies.py`；上述七个门禁各自的
  `scripts/test_validate_*.py` 固定输入测试必须一并采用。
- 审计记录：`docs/workstreams/06-competition-release-result.md`。

执行以下只读命令，核验这些直接包含项均在 manifest 与 Git 索引中，并确认十一条
运行时路径仍指向上述精确文件：

```powershell
python -B scripts/validate-release-dependencies.py
```

不得整提交采用 `5d1e75f`，也不得用该提交的
`apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
覆盖主线文件。集成提交应让本文件 `include` 中的每个路径对应主线当前已跟踪文件，
保留主线当前 `apps/harmonyos` 与 `apps/web` 两个完整源码根，并把新增发布门禁文件
逐项加入清单；`lesson-experiences.json` 随主线当前 HarmonyOS 根进入包，不是需要从
WS06 单独移植的文件。随后运行依赖闭包、内容门禁和 manifest 展开测试。最终
`release-manifest.json` 的
`sourceCommit` 必须填写完成上述校准后的主线完整 `HEAD`，不能沿用 WS06 分支哈希。

## 正式三文件门禁

竞赛规程第 6 页和报名手册第 10 页给出的三项正式命名/格式合同为：

- `01-作品说明文档+参赛队伍名称.pdf`
- `02-演示视频+参赛队伍名称.mp4`
- `03-作品名称+参赛队伍名称.zip`

其中 `+` 是官方模板的字面分隔符；`.pdf`、`.mp4` 是按同段格式要求补入的严格
文件名后缀。团队名称和作品名称必须使用门户最终真实值。报名手册第 5 页要求团队
名称不得使用符号，但未定义可执行字符集；脚本只拒绝路径分隔符、NUL、控制字符
和首尾空白，不猜测门户尚未提供的字符白名单。

运行命令：

```powershell
python -B scripts/validate-official-deliverables.py `
  --pdf-path <正式 PDF 的明确路径> `
  --video-path <正式 MP4 的明确路径> `
  --bundle-path <正式 ZIP 的明确路径> `
  --team-name <门户真实队名> `
  --work-name <门户真实作品名> `
  --pdfinfo-path <pdfinfo 现有绝对普通文件路径> `
  --ffprobe-path <ffprobe 现有绝对普通文件路径>
```

脚本不按扩展名或自报元数据判定格式。`pdfinfo` 必须解析到唯一 `Pages` 与
`Encrypted` 字段；整份 PDF 必须为 1..20 页且未加密。官方原文是“主体内容不
超过 20 页，参考资料及附录不计入总页数”，所以整份不超过 20 页和不得加密均为
项目内部加严，不冒充官方原文。`ffprobe` 必须返回大于 0 且不超过 300 秒的有限
时长、至少一个视频流，并在 `format_name` 中包含精确 `mp4` token。ZIP 继续复用
上一节完整发布包门禁。两个工具路径必须是调用者明确提供的现有绝对普通文件，
拒绝符号链接；工具缺失、超时、非零退出、超限或无效输出均为结构化失败，工具
输出和媒体路径不会写入错误正文。

总入口调用该脚本时追加 `--summary-json`，此模式只返回 `status` 与固定白名单
`reasonCodes`，不返回文件路径、探测工具 stdout/stderr、哈希或任意错误正文。总入口
对未知、重复、乱序、超限或退出码不一致的摘要闭锁失败；普通独立调用仍保留原有
可读输出。

脚本只读流式计算三文件字节数和 SHA-256。通过只证明本地文件名、解析元数据、
哈希与 ZIP 静态门禁，不证明 PDF 使用了官方最新模板、视频已完整人工播放、HAP
可安装运行或门户上传成功。报名手册第 12 页限制整个上传更新流程最多 10 次，
必须先完成本地验收再使用正式上传次数。

门禁只证明一个 HAP 文件存在、可作为 ZIP 读取且通过上述静态检查，不证明 HAP
已经正式签名、能够安装、模拟器通过或真机通过。原创声明和 AI 使用说明的文件
存在、大小与哈希通过，也不等于真实团队已审阅或签署。
