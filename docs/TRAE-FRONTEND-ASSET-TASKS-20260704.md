# Trae 前端资源任务提示词（2026-07-04）

本文件给 Trae 使用。所有任务默认只读或限制在页面内草案、独立报告范围。Trae 不得提交 Git，不得推送，不得修改核心区域，不得安装依赖，不得复制外部素材进 `apps/harmonyos/entry/src/main/resources/`。

## 一、统一硬边界

1. 开始前执行 `git status --short` 和 `git log -5 --oneline`，记录输出。
2. PowerShell 涉及中文时先设置 UTF-8：`$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()`。
3. 不执行批量、递归、通配符删除；不执行 `git clean`、`git reset --hard`、`git checkout -- .`。
4. 不使用 `git add .`、`git add -A` 或通配符暂存。
5. 不修改 `apps/web/src/lib/agents/**`、`apps/web/src/app/api/**`、`apps/web/src/middleware.ts`。
6. 不修改 `apps/harmonyos/entry/src/main/ets/common/**`、`apps/harmonyos/entry/src/main/ets/model/**`、`apps/harmonyos/entry/src/main/ets/pages/Index.ets`。
7. 不修改 `oh-package.json5`、`build-profile.json5`、依赖、Bundle、签名、Git 历史。
8. 不下载、不提交外部 SVG、PNG、JSON、MP3、WAV、OTF、TTF、HAP、日志、截图。
9. 所有结论使用证据等级：源码确认、静态诊断通过、构建通过、模拟器通过、真机通过、线上通过、未验证。
10. 无法从文件或一手资料确认的内容写未验证，不补写推断。

## 二、任务 1：页面视觉状态只读审计

```text
你是鸿学伴 HarmonyOS 前端资源审计线程。只读审计，不修改任何源码。

必须读取：
- AGENTS.md
- docs/TRAE-BOUNDARY-20260701.md
- docs/FRONTEND-RESOURCE-DEEP-HUNT-2-20260704.md
- docs/HARMONYOS-VISUAL-ASSET-IMPLEMENTATION-MATRIX-20260704.md
- apps/harmonyos/entry/src/main/ets/common/Constants.ets
- apps/harmonyos/entry/src/main/ets/common/Builders.ets
- apps/harmonyos/entry/src/main/ets/pages/Chat.ets
- apps/harmonyos/entry/src/main/ets/pages/Quiz.ets
- apps/harmonyos/entry/src/main/ets/pages/Lesson.ets
- apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets
- apps/harmonyos/entry/src/main/ets/pages/Profile.ets
- apps/harmonyos/entry/src/main/ets/pages/ActivityRecords.ets

输出一个新文档 docs/TRAE-VISUAL-STATE-AUDIT-20260704.md，只包含审计结果：
- 页面
- 源码行号
- 当前状态
- 问题类型：按钮语义、空态、加载态、失败态、图标语义、安全区、文字溢出、颜色漂移
- 建议改法
- 是否涉及 Codex 主线程核心区域
- 证据等级

禁止修改页面源码。禁止下载资源。禁止安装依赖。禁止提交 Git。
```

## 三、任务 2：Profile 与 ActivityRecords 标签洞察 UI 草案

```text
你是鸿学伴标签洞察页面内草案线程。只允许修改以下两个文件：
- apps/harmonyos/entry/src/main/ets/pages/Profile.ets
- apps/harmonyos/entry/src/main/ets/pages/ActivityRecords.ets

不得修改 LocalLearningRepository、DataModels、LearningMetadataModels、Builders、Constants、Index、任何 API、任何 oh-package.json5。

目标：
1. 基于现有 LearningTagInsight 字段展示三档标签：待巩固、熟练、稳定。
2. 每个标签显示题量、错题数、准确率、最近练习信息中源码已有字段能支持的部分。
3. 保留现有“练这个标签”或进入 Quiz 的 AppStorage 契约，不新增路由。
4. 空数据、少数据、多标签都要有清晰状态。
5. 不使用外部素材，不新增依赖，不新增 schema。

开始前读取相关文件并记录精确字段名；无法确认字段时停止并报告。

完成后输出：
- 修改文件清单
- 每个变更点和行号
- 使用的字段名
- 验证命令与退出码
- 未验证项

建议验证：
- DevEco MCP check_ets_files 针对这两个文件
- 如环境可用，执行 apps/harmonyos 增量 HAP 构建，不执行 clean

禁止提交 Git。
```

## 四、任务 3：Lesson 互动数据质量审计

```text
你是鸿学伴 LessonExperience 数据质量审计线程。只读审计，不修改文件。

必须读取：
- apps/harmonyos/entry/src/main/ets/model/DataModels.ets 中 LessonExperience 和 LearningActivity
- apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json
- apps/harmonyos/entry/src/main/ets/pages/Lesson.ets

输出 docs/TRAE-LESSON-EXPERIENCE-AUDIT-20260704.md。

审计项：
1. 33 条记录是否都包含 schemaVersion、courseId、topic、visualTitle、visualSteps、caseTitle、caseBody、workedExampleTitle、workedExampleSteps、activities。
2. 每个 activity 是否包含 id、type、title、prompt、content、language、interactionMode、options、answerIndexes、answer、feedback、source。
3. interactionMode 分布：single_choice、ordered_choice、free_response 等精确值。
4. 每门课是否至少有一个代码预测或现实案例足够强的样例。
5. 找出文案过长、反馈不具体、来源不足、选项不清晰的问题，列出精确 topic 和 activity id。
6. 给 Codex 主线程的改造建议，不直接修改 JSON。

证据等级只使用源码确认或未验证。禁止下载资源。禁止提交 Git。
```

## 五、任务 4：素材许可证审计报告

```text
你是鸿学伴视觉素材许可证审计线程。只写独立报告，不下载素材，不改工程源码。

审计范围：
- Open Peeps
- Tabler Icons
- Phosphor Icons
- Lucide
- Iconoir
- Mixkit sound effects
- LottieFiles
- Rive runtime
- Noto Sans CJK

输出 docs/TRAE-ASSET-LICENSE-AUDIT-20260704.md。

每项必须记录：
- sourceName
- sourceUrl
- licenseName
- licenseUrl
- 是否允许商业/竞赛使用
- 是否需要署名
- 是否存在用户上传素材权利风险
- 是否适合进入 HarmonyOS HAP
- 进入 HAP 前还缺什么证据
- 证据等级

只引用官方页面、仓库 LICENSE 或平台许可页面。无法访问或无法确认时写未验证。

禁止下载素材。禁止提交 Git。
```

## 六、任务 5：LearningMap 一跳关系视觉方案只读说明

```text
你是鸿学伴 LearningMap 产品方案线程。只读源码并输出方案文档，不修改页面。

必须读取：
- apps/harmonyos/entry/src/main/ets/pages/LearningMap.ets
- apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json
- docs/LEARNING-APP-COMPETITOR-UX-STUDY-20260704.md
- docs/HARMONYOS-VISUAL-ASSET-IMPLEMENTATION-MATRIX-20260704.md

输出 docs/TRAE-LEARNINGMAP-ONE-HOP-PROPOSAL-20260704.md。

方案必须包含：
- 当前 MapNode、MapEdge 字段和源码行号
- 一跳邻域规则：当前、前置、后继、非邻域
- 线型规则：已完成、可学、锁定
- 节点外环规则：未练、已练、稳定、到期复习
- 底部详情卡文案结构
- 小屏与横屏风险
- Codex 主线程需要改哪些函数
- 验证截图清单

不修改源码。禁止提交 Git。
```

## 七、任务 6：服务卡片色值漂移只读审计

```text
你是鸿学伴服务卡片视觉一致性审计线程。只读审计，不修改文件。

必须读取：
- apps/harmonyos/entry/src/main/ets/common/Constants.ets
- apps/harmonyos/entry/src/main/ets/widget/pages/LearningPlanCard.ets
- apps/harmonyos/entry/src/main/ets/common/LearningFormUpdater.ets

输出 docs/TRAE-WIDGET-VISUAL-AUDIT-20260704.md。

审计项：
- LearningPlanCard.ets 中所有直接色值和行号
- 对应 Constants.ets 中的现有令牌
- 无对应令牌时写“需 Codex 主线程判断”，不得新增令牌
- 服务卡片与主 App 视觉差异
- 后续 Codex 修改建议
- 证据等级

不修改源码。禁止提交 Git。
```

## 八、交付格式

每个 Trae 任务完成后必须汇报：

```text
任务：
读取文件：
修改文件：
验证命令：
退出码：
证据等级：
失败项：
未验证项：
需 Codex 主线程处理：
未提交文件：
```

Trae 不得同时修改 `DEVLOG.md`。如需记录过程，写独立报告，由 Codex 主线程复核后决定是否汇总。
