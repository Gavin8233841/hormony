# Trae App 落地工作包 2

> 执行原则：CLI 优先，只有 CLI 无法提供静态诊断或 UI 树证据时才使用 DevEco MCP。不得使用 loop-engineering。不得提交 Git，由 Codex 复核后统一提交。

## 目标

为 HarmonyOS App 提供足够完整、可复现的课程数据与回归基础。工作重点是数据、测试、适配证据和重复接线，不决定产品信息架构与视觉骨架。

## 受保护区域

不得修改：

- `apps/harmonyos/entry/src/main/ets/common/LocalLearningRepository.ets`
- `apps/harmonyos/entry/src/main/ets/common/LearningContentRepository.ets`
- `apps/harmonyos/entry/src/main/ets/model/DataModels.ets`
- `apps/harmonyos/entry/src/main/ets/pages/Index.ets`
- `apps/web/src/lib/agents/`
- `apps/web/src/app/api/`
- `apps/web/src/lib/model.ts`
- `apps/web/vercel.json`
- 任何设计令牌、顶层导航、数据库迁移、Safety 与模型调用

## 批次 A：精选题库扩充

1. 从 `knowledge-chunks.json` 程序化提取三门课程全部 topic，不手写猜测 topic 名。
2. 统计每个 topic 当前选择题数量，将每个 topic 补到至少 5 道。
3. 每题固定四个选项，ID、题干全局唯一，答案必须对应选项，解析至少两句。
4. 先修改 `apps/web/src/lib/data/quizzes.ts`，再从该源文件生成端侧 `quizzes.json`，禁止两边手工分别维护。
5. 每道新增题必须用教材、RFC、大学课程资料或官方文档核验。把来源和核验结论写入 `docs/QUIZ-CONTENT-AUDIT-2.md`，不要把 URL 塞进 App 题目正文。
6. 扩展 `data-integrity.test.ts`：每个知识 topic 至少 5 道选择题；源数据和端侧 JSON 的 ID、题干、答案、解析完全一致。

## 批次 B：知识星图关系数据

1. 从三门课程现有 topic 精确生成 `apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json`。
2. 每个节点字段固定为 `id`、`courseId`、`topic`、`prerequisiteIds`、`level`。
3. `id` 使用稳定英文短标识；`prerequisiteIds` 只能引用文件内真实存在的节点 ID。
4. 每门课程必须形成连通的有向无环图；不得为了视觉效果编造错误先修关系。
5. 新增只读校验脚本，检查引用完整性、无环、每门课程连通、topic 与知识资产完全一致。
6. 输出 `docs/TOPIC-RELATION-AUDIT.md`，逐门课程说明关系依据。不得修改 ArkTS 仓库或页面。

## 批次 C：CLI 自动回归脚本

新增 `scripts/harmonyos-app-smoke.ps1`，要求：

- UTF-8 输出；只使用 `hvigorw`、`hdc`、`uitest dumpLayout/uiInput/screenCap`。
- 不使用 MCP，不执行删除、清理、卸载、重置数据库或破坏性 Git 命令。
- 从 UI 树文本节点的 `bounds` 计算点击中心，禁止写死整套坐标。
- 验证：启动 App、四个 Tab、课程列表、课程详情、精选练习首题、返回链路。
- 网络相关只检查云端状态文案，不要求代理，不在脚本中包含密钥、Token、VPN 或本机代理地址。
- 截图输出到带时间戳的新目录，不覆盖既有证据。

## 批次 D：设备适配与可访问性审计

1. 使用现有模拟器/DevEco 设备能力检查手机竖屏、手机横屏和一个平板窗口尺寸。
2. 仅审计，不修改视觉代码。
3. 检查状态栏、底部手势区、底栏遮挡、长标题、动态数据、按钮触控区、字体缩放、空态和错误态。
4. 输出 `docs/HARMONYOS-LAYOUT-AUDIT-2.md`，按 P0/P1/P2 列出精确页面、元素、分辨率与截图路径。
5. 对当前已存在页面执行 ArkTS 静态检查和 HAP 构建，记录精确命令与退出码。

## 批次 E：资源与内容质量

1. 对 147 条知识切片检查重复、相互矛盾、过时表述、来源过泛和 topic 错配。
2. 对 36 条外部资源重新检查移动端可打开性、HTTPS、标题一致性和课程归属。
3. 只修复有明确证据的问题；每项修复记录旧值、新值和来源。
4. 禁止把未经许可的教材全文、付费课程内容或大段版权文本写入项目。

## 验收命令

- Web：`pnpm lint`、`pnpm typecheck`、`pnpm test`
- HarmonyOS：CLI 增量构建，不执行 clean
- `git diff --check`
- 敏感信息扫描：工作区新增内容不得包含 `MODEL_API_KEY`、Vercel Token、Ark Key 或代理凭据

## 汇报格式

按批次报告文件清单、数据统计、命令、退出码、失败项和证据路径。把记录追加到 `DEVLOG.md`，不要提交 Git。
