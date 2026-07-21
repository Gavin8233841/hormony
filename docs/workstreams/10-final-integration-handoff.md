# 鸿学伴竞赛提交前主线整合收尾

更新时间：2026-07-22

## 1. 冻结基线

- 主线分支：`codex/harmony-integration-20260717`。
- 本文核验时 `HEAD`：`5ca76d5 test: 同步 Chat Plan 整合契约`。
- 远端 `origin/codex/harmony-integration-20260717` 仍停在 `e779a22`；本文提交后必须推送并以推送后的精确提交为后续证据基线。
- 工作树保留 `.trae/progress.json`、`lesson-experiences.json`、`.tmp/`、`assets/`、展示站、压缩包和本地提案；这些内容不是本次提交的一部分。
- 2026-07-22 两次指定 HDC 检查均为 `[Empty] / hdc`，当前没有设备证据。

## 2. 已完成的主线整合

| 工作流 | 原成果 | 主线采用结果 | 结论 |
| --- | --- | --- | --- |
| WS07 测验状态 | `c03930e` | `52a9492` | 主线没有机械套用单一时间标记，而是以 `legacyHistorySnapshot`、窗口 marker 和故障注入覆盖旧测验迁移重入、再次降级及累计回退。 |
| WS07 迟到写回 | `c04e468` | `d3d9fb8` | Reducer 与动态 Repository 反例已进入主线，迟到结果继续累计但不回退题面、难度、间隔、下一复习时间和最近练习时间。 |
| WS06 正式交付 | `affba53` | `f250027` | 跨视口设备冒烟脚本和 17 项离线自测进入主线；当前无设备，不沿用旧分支运行证据。 |
| WS06 正式交付 | `b8130ea` | `86bdb8e` | 发布 evidence、HAP/ZIP 绑定与有限错误合同进入主线。 |
| WS06 正式交付 | `4d9acc3` | `9f11b1c` | 正式 MP4 实际帧、尺寸、编码和工具 stderr 门禁进入主线。 |
| WS06 正式交付 | `13fb838` | `e527a2b`、`1eb115a` | NOTICE 正式模式和评分/演示文档闭包进入主线，人工确认项继续阻断正式发布。 |
| WS08 Chat/Plan | `04da452` | `f207b82` | Chat 大字号、48 vp、对象化无障碍语义和宽屏正文约束进入主线。 |
| WS08 Plan | `6acb0b9` | `3a00e63` | 已有任务优先、表单折叠、失败恢复和可访问任务文本进入主线。 |
| WS08 Plan | `97e3984` | `fb52420`、`5ca76d5` | 任务操作随字号增长，测试契约与当前 Home/Repository 并发事实同步。 |

## 3. 未直接融合的提交

### WS07 后续链

- `87ca721` 依赖当前主线不存在的精确 `AppliedQuizProof` / `appliedQuizProofs` 持久摘要模型。它必须连同 `67cdcdf -> 7132eb4 -> 6d68d6d -> f1513ad` 的完整前置重新审计，不能把 7 行后续补丁孤立移植。
- `4b1b8cf` 依赖同一前置链中的 AI/精选题草稿仓储 API、attempt CAS 和结果页冻结状态。当前主线没有 `clearAiQuizDraft`、`clearCuratedPracticeDraft` 等精确 API，不能只移植页面按钮。
- 两项均保留为最终评估任务的可靠性缺口，不以“提交存在”写成主线已通过。

### WS09 多学科与媒体链

- `0badf17 -> 04c0514 -> 2ea7ce9` 同时修改 Web 内容源、生成脚本、Agent、数据库、页面、HarmonyOS 生成物、二进制媒体和 AVPlayer 页面。该分支从旧 `c94d72b` 分叉，整枝合并会回退当前发布门禁、模型安全、测验状态和产品体验修正。
- `lesson-experiences.json` 是用户保留的未提交产物，不能被旧分支覆盖；课程、题库、知识、关系和媒体必须由核验后的 Web 单一来源及生成链统一生成。
- 主线当前不存在 `accounting.ts`、`cet.ts`、`course-catalog.ts`、`generate-learning-content.mjs`、`LocalAudioPlayer.ets` 和两个媒体文件，因此初级会计/CET/本地音频不属于当前主线交付能力。
- WS09 分支的历史模拟器流程和 OGG 许可研究只保留为支线来源记录。当前主线没有 AVPlayer、字幕/转写、离线/失败态和 API 12 设备播放闭环，不提升证据等级。

## 4. 2026-07-22 主线回归

| 验证 | 结果 | 证据等级 |
| --- | --- | --- |
| `pnpm lint` | exit 0 | 静态诊断通过 |
| `pnpm typecheck` | exit 0 | 静态诊断通过 |
| `pnpm test` | exit 0，36 文件、477/477 | 静态诊断通过 |
| `pnpm build` | exit 0，Next.js 10/10 静态页面与全部 API 路由构建完成 | 构建通过 |
| `python -B scripts/validate-topic-relations.py` | exit 0，33 Topic、147 知识切片、165 道题、33 份 Lesson experience | 静态诊断通过 |
| 七组正式发布门禁单测 | exit 0，137/137 | 静态诊断通过 |
| `harmonyos-app-smoke.ps1 -SelfTest` | exit 0，17/17 | 静态诊断通过 |
| `validate-release-dependencies.py` | exit 0，18 个直接文件、7 个测试文件、11 条运行时边、7 条测试边 | 静态诊断通过 |
| API 12 Hvigor 增量 HAP | exit 0，`BUILD SUCCESSFUL in 9 s 650 ms`；未配置签名 | 构建通过 |
| 指定 `hdc list targets -v` | exit 0，`[Empty] / hdc` | 未验证设备流程 |

## 5. 当前真实阻断项

### P0：正式提交前必须关闭

1. 内容门禁 exit 1：165 道题答案位置为 `A=20, B=106, C=34, D=5`，难度为 `easy=96, medium=65, hard=4`；需在 Web 单一来源修正并重新生成，不得手改端侧 JSON。
2. 147 条知识切片和 36 条外部资源缺少完整 provenance；4 条已知失实内容仍在当前源/生成物中。
3. `scripts/generate-learning-content-json.mjs` 与对应测试缺失，source manifest 闭包失败；两个测试文件触发高置信秘密字面量门禁。
4. `docs/COMPETITION-NOTICE.md` 及引用文档仍有 `CHECK-BEFORE-SUBMISSION`；团队身份、权利、原创/AI 使用和签署事实必须由责任人确认。
5. 正式 PDF、MP4、源码 ZIP、正式签名 HAP、release evidence index、两张提交图、黄金流程证据和门户回执尚不存在或未验证。
6. 当前无 HDC 设备；最终提交版本的模拟器/真机安装、横屏、窄宽、大字号、屏幕阅读器、服务卡片/手动提醒回流和完整黄金路径未验证。
7. 当前部署版本的 Health、Chat SSE、Plan、Quiz 与 HarmonyOS 端调用没有本轮线上业务证据。

### P1：高价值工程缺口

1. 重新评估完整 WS07 草稿生命周期与长期幂等摘要链，优先证明结果写回、草稿清理失败和重试不会阻断下一步或重复累计。
2. 多学科只能在内容门禁和生成单一来源闭合后进入主线；初级会计/CET 需逐学科做专家事实复核，不能复制受保护题库或教材。
3. 媒体只有来源、精确许可证/再分发结论、SHA-256、可见转写、真实 AVPlayer、离线/失败态、API 12 构建和设备播放同时齐备后才能进入提交叙事。

### P2：可优化但不应挤占 P0

1. 在真实设备证据基础上继续打磨 Chat/Plan 的横屏、平板、大字号和焦点顺序。
2. 用同一最终提交和 HAP 采集两张结构化效果图与 4:45 黄金演示，避免旧展示站或历史支线截图。
3. 在正式材料冻结前统一检查产品叙事、视频字幕、PDF、README 与门户简介，删除旧数量、旧测试总数和未验证能力。

## 6. 新任务接力规则

新任务必须从本文件、`DEVLOG.md`、官方两份 PDF、评分计划、NOTICE、当前源码和实际门禁输出开始。先按 P0/P1/P2 给出精确缺口矩阵，再实施一项当前最高价值且可验证的改进；不得以创建更多线程替代主线闭环，不得伪造设备、线上、许可、签署、门户或正式材料证据。
