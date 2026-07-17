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
    "scripts/test_validate_official_deliverables.py",
    "scripts/test_validate_release_bundle.py",
    "scripts/validate-competition-content.py",
    "scripts/validate-competition-evidence.py",
    "scripts/validate-official-deliverables.py",
    "scripts/validate-release-bundle.py",
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
必须是正整数；`sha256` 必须是 64 位小写十六进制值。以下五个 `role` 必须
且只能各出现一次，不接受未定义角色：

- `hap`
- `third-party-license-index`
- `originality-declaration`
- `ai-usage-declaration`
- `release-evidence-index`

运行命令：

```powershell
python -B scripts/validate-release-bundle.py --bundle-path <最终 ZIP 的明确路径>
```

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

`fbe0ad2` 的发布包脚本动态复用 `scripts/validate-competition-content.py` 的路径、
manifest、NOTICE 与敏感信息合同。主线采用本门禁时只需要按文件合入当前版本的：

- `scripts/validate-competition-content.py` 及其测试
- `docs/COMPETITION-NOTICE.md`
- 本文件与发布包脚本/测试

不得整提交采用 `5d1e75f`，也不得用该提交的
`apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json`
覆盖主线文件。集成提交应让本文件 `include` 中的每个路径对应主线当前已跟踪文件，
保留 `apps/harmonyos` 与 `apps/web` 两个完整源码根，并把新增发布门禁文件逐项加入
清单；随后运行内容门禁和 manifest 展开测试。最终 `release-manifest.json` 的
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

脚本只读流式计算三文件字节数和 SHA-256。通过只证明本地文件名、解析元数据、
哈希与 ZIP 静态门禁，不证明 PDF 使用了官方最新模板、视频已完整人工播放、HAP
可安装运行或门户上传成功。报名手册第 12 页限制整个上传更新流程最多 10 次，
必须先完成本地验收再使用正式上传次数。

门禁只证明一个 HAP 文件存在、可作为 ZIP 读取且通过上述静态检查，不证明 HAP
已经正式签名、能够安装、模拟器通过或真机通过。原创声明和 AI 使用说明的文件
存在、大小与哈希通过，也不等于真实团队已审阅或签署。
