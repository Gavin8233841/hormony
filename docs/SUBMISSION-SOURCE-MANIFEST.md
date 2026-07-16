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
    "scripts/test_validate_competition_content.py",
    "scripts/test_validate_release_bundle.py",
    "scripts/validate-competition-content.py",
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
清单内的新增文件，再运行 `python scripts/validate-competition-content.py`；未跟踪文件
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
python scripts/validate-release-bundle.py --bundle-path <最终 ZIP 的明确路径>
```

脚本只读打开 ZIP，不解压到磁盘，不构建、不清理也不改写文件。它从声明提交的
Git tree 读取本清单展开的源码并逐字比较，同时要求声明提交等于当前 `HEAD`；
非 Git 附件必须与 manifest 的文件集合、字节数和 SHA-256 完全一致。ZIP 与 HAP
内部的路径穿越、大小写折叠冲突、重复条目、符号链接、特殊文件、加密条目、
禁止路径、待处理 NOTICE 和可识别敏感信息都会阻断。HAP 内部扫描采用项目安全
上限：`release-manifest.json` 不超过 64 KiB，每条包内路径的 UTF-8 编码不超过
512 字节，HAP 单条目解压后不超过 64 MiB、全部可读条目合计不超过 256 MiB；
这些值不是官方门户大小限制，门户限制仍为**未验证**。

门禁只证明一个 HAP 文件存在、可作为 ZIP 读取且通过上述静态检查，不证明 HAP
已经正式签名、能够安装、模拟器通过或真机通过。原创声明和 AI 使用说明的文件
存在、大小与哈希通过，也不等于真实团队已审阅或签署。
