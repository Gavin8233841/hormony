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

## 2026-09-28 下午接续结果（覆盖上方部署待办）

- 先审 `dpl_2XaBqih64XYjTXx6EusWaECbQrp9`：Health `200/ready`，非法数量和跨主题均明确 `400`；一次图遍历生成被输出 Safety 以 `502/SAFETY_BLOCKED` 拒绝。数组主题样本混入归并排序且题意有歧义，未提升。提交 `3cf05e0` 让精确主题只使用本课节知识片，聊天自由文本仍走原检索；受保护候选 `dpl_A6KaT1w6cNFAKvQGjkUGre27du5i` 暴露选项重排后解析字母未更新，亦未提升。提交 `7faabbf` 修复明确的选项字母引用，保留 `A[i][j]` 等表达式；Web 495/495、lint、typecheck、build 均 exit 0。
- 第三候选 `dpl_GrVQfooMMk5cHgFb6TZXsJz9YPEy` 的 Health、图遍历和数组主题生成均 `200`，两组五题人工抽检题意、选项与解析一致。`vercel promote` 成功后，`vercel inspect hormony-ruddy.vercel.app` 确认公开域名指向此 ID。公开 Health、Quiz、Chat 业务字段重验通过；合成四接口实际响应 HAR `.runtime/semifinal-attachments/public-four-api-20260928.har`，SHA-256 `57d3155f99dbb59b4d29d68d6a4f8307487cc4aa2c63abc57d1276ed138186ce`。Health、Chat、Plan、Quiz 均 HTTP 200；证据解析器从 HAR 推导 16 项业务检查、零结构错误。HAR 健康接口的 `version` 为 `1.0.1`，部署 ID 由独立 `vercel inspect` 记录，两者不可混同。
- 原有未签名 HAP SHA-256 `8507122ccf4b16f8a812dd39b4520ad45fb6d65f2e97fcdac1ddf62f8dba2219` 未变；API 26 Hvigor 6.26.4 增量构建 exit 0，签名 HAP 哈希亦保持。Pura X View 1320×2232 模拟器通过宿主 API 网关在新公开域名生成图遍历挑战五题，按 B/D/C/A/A 作答，UI 显示 5/5、结果已保存、累计答题 75→80。应用进程重启后和模拟器一次自动冷启动恢复后，学习记录仍显示 15:32 的“AI 出题 · 挑战 · 图的表示与遍历 · 5/5”。新出题加载时返回记录页，等待 25 秒后仍为 22 次学习，没有新增已保存结果。证据与哈希索引为 `.runtime/semifinal-attachments/post-promote-simulator-20260928/run-evidence.json`。其中第 5 题把 `O(出度(i))` 作为更紧界，但题干“最坏时间复杂度”也容许较松的 `O(n)` 上界，应在教学质量限制中保留，不能把 UI 5/5 当成五题均无歧义。
- 用 Git 提交快照逐字节构建 235 个清单源码文件和同字节 HAP；当前预备 ZIP 为 `.runtime/semifinal-attachments/03-鸿学伴+双子星-源码预备包-7faabbf.zip`，已附 `release-manifest.json` 与七记录证据索引（源码、Web 线上、HAP 构建有证据；黄金演示、正式媒体、许可原创、门户上传未验证）。包内索引以实际条目 resolver 验证 7/7 结构且无错误；正式 `validate-release-bundle.py` 因三处 Git 文档的 `CHECK-BEFORE-SUBMISSION` 及 NOTICE 人工项失败，不是正式交付 ZIP。此文与 DEVLOG 后续提交会改变 HEAD，须按新提交重新生成预备包，旧名包不能充当同版最终附件。
- Web 已安装依赖扫描为 456 个版本实例，7 个直接运行依赖和 15 个直接开发依赖；机器汇集的许可证文本草稿在 `.runtime/semifinal-attachments/third-party-license-index-draft-20260928.md`，26 个包未在包根找到许可文件，其中直接开发依赖 `eslint-config-next@14.2.18` 一项。`pnpm licenses list` 因本机 store 缺 package index 失败，不能把机器扫描说成完整权利核实。团队仍需课程/题目/素材来源、许可全文、原创和 AI 使用记录及真实签名；正式 PDF、≤5 分钟视频、门户上传都未完成。用户本阶段只要求模拟器，小艺 App→Extension 真实会话和真机继续列为未验证。
