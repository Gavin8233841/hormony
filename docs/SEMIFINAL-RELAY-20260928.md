# 鸿学伴复赛交接卡（2026-09-28，6 Sol / high）

## 目标与边界

继续围绕官方 Agent 创新评分点，把鸿学伴 HarmonyOS 原生学习闭环、小艺端 A2A 平台测试配置与可核查的复赛附件收口。先完成应用／HAP／源码 ZIP 与模拟器证据，再制作说明文档和 ≤5 分钟视频。用户要求本阶段只用模拟器，真机留到决赛以后；不要把小艺平台 Card 已保存、端侧协议测试或线上 Tutor 回答写成小艺 App 实际调用 Extension。正式上架、竞赛门户上传和队员签署仍有独立边界。

真实 Git 根目录为 `/Users/Admin/Desktop/Hormony/hormony`，Codex 保存项目“鸿学伴”的根目录是外层 `/Users/Admin/Desktop/Hormony`。新线程所有仓库命令须显式 `workdir` 到内层。先读根目录 `AGENTS.md`、`docs/SEMIFINAL-IMPLEMENTATION-HANDOFF.md`、`docs/HARMONY-AI-KNOWLEDGE-20260927.md`、`docs/SEMIFINAL-ATTACHMENT-READINESS-20260928.md`，按需读 `docs/SUBMISSION-SOURCE-MANIFEST.md`。不重复全量调研。

## 当前可追溯状态

- 分支 `codex/semifinal-macos-20260920`，HEAD `3e8a0ebf85ae908491f64752c46fdc51641cb2c2`，已推送 `origin`。该提交增加 AI 生成题正确选项位置平衡及复赛证据记录。Web 495/495、lint、typecheck、build 均通过。当前提交尚未形成新的正式发布 ZIP。
- 当前 Pura X View HarmonyOS 7 / API 26 / 1320×2232 模拟器安装的未签名 HAP SHA-256 `8507122ccf4b16f8a812dd39b4520ad45fb6d65f2e97fcdac1ddf62f8dba2219`，HAP 源码基点 `62ad1a760b150509e763572fac24ae7450519b40`；本轮只改 Web，HAP 字节未变。签名 HAP `c4b75e4471bda2be545cbab8a24adee4e5a244e5ec7d0f61a4ade0db73136f01`，SDK verify-app 成功；模拟器安装的是未签名包，不要混同。
- 同版主链模拟器已走通“课程→4 课节→5 题本地练习→3/5→问学伴→云端针对性回答与 3 条资料→去练习回跳→学习记录”；即时通知从首页手动触发，通知栏出现后点入错题本。原始连续窗口视频 `.runtime/semifinal-attachments/semifinal-practice-20260928/uncut-simulator-mainchain-final.mov`，180.02 秒、SHA-256 `4eee27696181a943f10e9b81fef23c9199cf78bc86d58d59ec6defc6a9982e6d`；50.509 秒连续片段 `mainchain-evidence-50s.mp4`，SHA-256 `f5d1d9877a2ff0f4d2e71d0b51996558f694eced05c728276f7ebe90273348e6`。逐项 UI 树、截图与哈希索引见同目录 `run-evidence.json`。片段不是正式参赛视频。
- AI 测验在旧公开云端用同一模拟器实测生成 5 题、作答和本机保存，五题全选 A 得 5/5。客户端按服务端 `grading.answer` 评分；单次样本不能证明必然总 A。提交 `3e8a0eb` 对真实模型输出做四题一组 A–D 答案位置平衡，选项正文与评分键同步移动。候选 Vercel 部署 `dpl_2XaBqih64XYjTXx6EusWaECbQrp9` 为 Production `Ready`，`--skip-domain` 未切换应用使用的 `hormony-ruddy.vercel.app`。候选合成 `POST /api/quiz` 返回 5 道展示题、5 条独立 grading，答案 A/C/D/B/C；响应仅存忽略目录 `.runtime/semifinal-attachments/quiz-balanced-candidate-response.json`，SHA-256 `09bd3c00e78b318ef7870fcd8abe24bbf2dea433597aa79ea497fe7b994f67d4`。尚需进一步检查这些生成题的教学正确性、候选 Health 和失败路径，再考虑 `vercel promote`；提升后必须重新验证公开接口及模拟器出题路径。当前公开域名经 `vercel inspect` 仍指向旧部署 `dpl_8jiitXWSn51hQVyxGjBD9k5hvKpP`。
- 小艺平台既有“端 A2A”小鸿项目已关联鸿学伴应用，AgentCard 1.1.0 两技能保存并刷新仍在，白名单测试态开启。模拟器缺少小艺端 A2A 会话所需运行时，**没有**小艺 App→`XiaoyiAgentAbility` 真实调用。正式上架仍需账户主体/内容合规材料。不要把此缺口当成用户当前要求真机的理由。
- 现有预备源码 ZIP `.runtime/semifinal-attachments/03-鸿学伴+双子星-源码预备包-62ad1a7.zip` 对应旧 Web 源码快照；**因本轮 Web 改动已过时**。正式包须使用新提交 `3e8a0eb`（或后续冻结提交）重建源文件集合和 release manifest，同时保留同一 HAP 哈希和差异说明。该旧 ZIP 不可重命名为最终附件。

## 立刻接续的顺序

1. 对候选部署做 Health 与 Quiz 多样本/错误路径的受保护地址检查，核对题意与答案；如足够稳健，再提升候选到 `hormony-ruddy.vercel.app`，读取 `vercel inspect` 的目标 ID，并在公开域名重验 Health、Quiz、Chat。Vercel CLI 60.1.3 已存在 `/Users/Admin/.npm/_npx/0d70516da7555b82/node_modules/.bin/vercel`，仓库根 `.vercel/project.json` 已关联项目。不要输出凭据或合成请求的用户私有数据。此项不需要改 HAP。
2. 提升后在 Pura X View 模拟器重新走一次 AI 生成题的作答与结果保存，核对答案不是集中 A；补录 UI 树/截图、失败回退和服务卡片（若模拟器支持）。主链已有有效连续录像，避免重复全量录制，除非源/HAP再改或镜头不足。
3. 依据 `docs/SUBMISSION-SOURCE-MANIFEST.md` 重建源码快照和正式包结构；对包内 Git 源码按冻结提交逐字节核对、HAP 按实际字节哈希核对，写 `release-manifest.json`、七记录证据索引和限制，跑 `scripts/validate-release-bundle.py`、`scripts/validate-release-evidence.py`、内容/依赖门禁。NOTICE 中素材来源、题目权利、第三方许可、原创与 AI 使用声明及真实签名仍需团队确认，不得删除标记或代签。未通过门禁时只能称预备包。
4. 当应用与附件冻结，再制作官方模板作品说明和正式 ≤5 分钟视频。内容只写已验证等级；官方评分重点为创新 50、完备 20、前景 20、规范 10，另有实际应用价值附加项。最后核对报名门户实时规则与提交回执。

## 并行工作与安全

当前工作区已有其他任务未提交修改：`apps/harmonyos/build-profile.json5`（签名配置，可能含秘密）、`scripts/harmonyos-app-smoke.ps1`、`scripts/test_validate_official_deliverables.py`，以及未跟踪的 `docs/astra-review/`、`docs/workflows/`、`scripts/harmonyos-app-smoke.md`。未获归属前不覆盖、不暂存、不提交它们。`run-evidence.json`、视频、候选 API 响应、HAP 与 ZIP 都在忽略的 `.runtime/`，不提交 Git。提交前精确暂存、敏感扫描、`git diff --check`。保留旧包和失败探针作为历史，不批量删除。
