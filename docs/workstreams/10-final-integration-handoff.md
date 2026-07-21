# 鸿学伴竞赛提交前主线整合收尾

更新时间：2026-07-22

## 1. 冻结基线

- 主线分支：`codex/harmony-integration-20260717`。
- 本轮起始 `HEAD`：`8e343a4 docs: 冻结竞赛提交前整合基线`；本批提交后以推送后的精确提交为后续证据基线。
- 远端 `origin/codex/harmony-integration-20260717` 已与 `8e343a4` 对齐；本批提交后必须再次核对推送状态。
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

## 4. 2026-07-22 本批主线回归

| 验证 | 结果 | 证据等级 |
| --- | --- | --- |
| `pnpm lint` / `pnpm typecheck` | exit 0 | 静态诊断通过 |
| `pnpm test` | exit 0，36 文件、477/477 | 静态诊断通过 |
| `pnpm build` | exit 0，Next.js 10/10 页面与 API 构建完成 | 构建通过 |
| `node --test scripts/generate-learning-content-json.test.mjs` | exit 0，4/4；147/147 知识、36/36 资源与 rawfile 一致 | 静态诊断通过 |
| `python -B scripts/validate-competition-content.py` | 题库/知识/资源门禁通过；仅受保护 Lesson `index=28` 旧事实失败 | 未完全通过，失败项可定位 |
| `python -B scripts/validate-topic-relations.py` | exit 0，33 Topic、147 知识、165 题、33 Lesson | 静态诊断通过 |
| `python -B scripts/validate-release-dependencies.py` | exit 0，18/7 文件、11/7 运行时/测试边 | 静态诊断通过 |
| 四组事实回归 | exit 0，41/41 | 静态诊断通过 |
| API 12 Hvigor 增量 HAP | exit 0，`BUILD SUCCESSFUL in 15 s 730 ms`；未配置签名 | 构建通过 |
| 指定 `hdc list targets -v` | exit 0，`[Empty] / hdc` | 未验证设备流程 |

## 5. 当前真实阻断项

### P0：正式提交前必须关闭

| 缺口 | 当前事实与证据等级 | 完成定义 | 依赖/风险 | 最短验证路径 |
| --- | --- | --- | --- | --- |
| 内容门禁 | **部分关闭**：源码确认 + 静态诊断通过；题库 `A=41,B=41,C=41,D=42`、难度 `easy=67,medium=66,hard=32`；147/147 知识与 36/36 资源 provenance 通过；`cs103_k26/k31/k33` 通过；受保护 Lesson `index=28` 仍失败 | 受控更新 Lesson 单一来源并重新生成，`validate-competition-content.py` exit 0 | `lesson-experiences.json` 为用户保留文件，未经确认不得改写/提交 | 责任人确认来源后运行 `generate-learning-activities.mjs`，再跑内容门禁、Topic 门禁和事实回归 |
| 生成闭包与秘密门禁（已关闭） | **静态诊断通过**：生成器及 4 项测试已恢复；新脚本精确暂存后，manifest 展开与源码秘密门禁均 PASS | 已达成：必要源码被跟踪，禁止项与可识别秘密均未命中 | 后续仍只能精确暂存；用户保留产物不得进入提交 | 每批运行 `python -B scripts/validate-competition-content.py` 并扫描 staged 内容 |
| NOTICE 与正式材料 | **未验证/人工阻断**：`CHECK-BEFORE-SUBMISSION` 仍存在；正式 PDF、MP4、源码 ZIP、签名 HAP、证据索引、提交图、门户回执未形成 | 责任人逐项确认身份、原创/AI、权利、签署；按最终提交生成并核验所有材料 | 不得猜测队伍、成员、导师、许可证、门户或签署事实 | 责任人提供事实后运行发布门禁、PDF/MP4/ZIP/HAP 绑定检查 |
| 设备与线上黄金路径 | **未验证**：指定 HDC 为 `[Empty] / hdc`；无安装、UI 树、横屏/大字号/读屏、服务卡片回流或线上业务证据 | 最终 HAP 在指定 API 12 设备完成安装、黄金流程和 Health/Chat/Plan/Quiz 业务验证 | 依赖设备、签名和部署权限；不可用历史设备结论替代 | 连接设备后运行指定 HDC、`harmonyos-app-smoke.ps1` 和线上端点结构校验 |

### P1：高价值工程可靠性

| 缺口 | 当前事实与证据等级 | 完成定义 | 依赖/风险 | 最短验证路径 |
| --- | --- | --- | --- | --- |
| WS07 草稿与长期幂等链 | **源码确认**：`AppliedQuizProof/appliedQuizProofs` 和完整草稿 CAS 前置仍未进入主线 | 完整前置链经当前 API/Repository/页面审计，证明清理失败、重试、迟到写回不重复累计 | 不能孤立采用 `87ca721` 或 `4b1b8cf` | 逐提交重建 `67cdcdf -> 7132eb4 -> 6d68d6d -> f1513ad` 后跑故障注入/持久化回归 |
| 多学科 | **未验证**：主线无 `accounting.ts`、`cet.ts`；当前三门内容门禁已闭合到可继续审计 | Web 单一来源、生成脚本、专家事实与许可逐学科通过，再生成端侧 | 不能复制受保护题库或教材；依赖内容专家与许可证据 | 逐文件采用并跑内容/Topic/发布门禁 |
| 媒体 | **未验证**：主线无 AVPlayer、转写、离线/失败态及设备播放闭环 | 来源、精确许可/再分发、SHA-256、可见转写、真实播放器、API 12 构建、设备播放全部齐备 | 不能用历史模拟器或支线 OGG 研究替代 | 逐资产核验后跑媒体门禁、Hvigor 和设备播放 |

### P2：可延后优化

| 缺口 | 当前事实与证据等级 | 完成定义 | 最短验证路径 |
| --- | --- | --- | --- |
| Chat/Plan 视口与焦点 | **源码确认**；无本轮设备证据 | 在最终设备证据基础上完成横屏、平板、大字号和焦点顺序细化 | 设备连接后执行跨视口冒烟与读屏检查 |
| 提交图与黄金演示 | **未验证**；正式材料不存在 | 用同一最终提交和签名 HAP 采集两张结构化效果图与 4:45 演示 | 发布材料冻结后运行证据索引门禁 |
| 叙事一致性 | **未验证**；旧数量/测试总数可能散落在材料中 | 统一 PDF、README、字幕、门户简介中的数量与能力边界 | 正式材料冻结前全文检索并由责任人复核 |

## 6. 新任务接力规则

新任务必须从本文件、`DEVLOG.md`、官方两份 PDF、评分计划、NOTICE、当前源码和实际门禁输出开始。先按 P0/P1/P2 给出精确缺口矩阵，再实施一项当前最高价值且可验证的改进；不得以创建更多线程替代主线闭环，不得伪造设备、线上、许可、签署、门户或正式材料证据。
