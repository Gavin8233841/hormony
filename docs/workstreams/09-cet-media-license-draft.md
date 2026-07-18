# WS09 CET-4 / CET-6 音频、转写与许可审计及摄取记录

> 初次审计：2026-07-18T21:18:14+08:00；复核：2026-07-18T22:33:37+08:00
> 工作流：`academic-research-suite` / `deep-research` fact-check
> 实施状态：两条开放音频已按原始字节进入 HAP rawfile 并通过生成期哈希门禁；CET-4/CET-6 原创内容与诊断入口已完成模拟器验证。AVPlayer 播放仍未验证。

## 1. 结论先行

1. **官方 CET 依据只能 `link_only`**。教育部教育考试院现行 CET 页面可访问，2016 年修订版英语四、六级考试大纲 PDF 也已取得字节级哈希，但页面和 PDF 未声明允许修改或再分发的开放许可，不能复制进题库或 HAP。[考试大纲索引](https://cet.neea.edu.cn/html1/folder/16113/1588-1.htm) [PDF](https://cet.neea.edu.cn/res/Home/1704/55b02330ac17274664f06d9d3db8249d.pdf)
2. **官方大纲页当前没有英语样卷听力音频**。页面明确列出了日语四/六级与俄语四/六级样卷音频，却只为英语提供大纲 PDF。此结论只针对 2026-07-18 实际访问到的该页面，不外推为全站绝对不存在。
3. **首个可安全落地的微型音频来源是 Wikimedia Commons 的逐文件许可资源**。两个已复核的英文词/短语文件分别为 CC BY 4.0 与 CC BY-SA 4.0，媒体本体、许可、作者、时长、字节数、SHA-1 与 SHA-256 均已核验；它们适合词音辨识和跟读，不足以冒充 CET 真题或完整听力模拟。
4. **LibriSpeech 与 VCTK 可用于后续原创听力片段制作，但不能整包进入 HAP**。二者都是 CC BY 4.0，带文本对齐或转写；原始包分别从数百 MB 到 11.7 GB，需要在受控构建阶段选段、复核文本来源、保留署名并生成应用内媒体清单。
5. **Common Voice 26.0 English 暂不进入 HAP**。数据页声明 CC0-1.0，并发布了 94,639,372,950 字节的包及 SHA-256；但下载要求认证并接受 Data Consumer License，当前页面只声明 MP3，未暴露转写结构，本次也未下载归档。完成合同复核和包内结构核验前不得镜像或拆包再分发。
6. **API 12 仅完成 SDK 源码确认，未完成模拟器播放**。本机 API 12 SDK 声明 `createAVPlayer()`、`ResourceManager.getRawFd()`，并明确 `fdSrc` 支持 OGG、WAV、MP3 等音频格式；本文件没有修改端侧代码，因此真实播放、音频焦点、后台行为和无障碍朗读仍为未验证。

## 2. 可复现检索方法

### 2.1 研究问题

> 哪些 CET-4 / CET-6 相关官方材料和开放英文语音资源，能够在不复制受保护题库、教材或网页专有音频的前提下，支持鸿学伴的离线词音、跟读、短听力与可见转写？

### 2.2 检索面与查询

| 来源面 | 实际查询或入口 |
| --- | --- |
| 教育部教育考试院 CET | `https://cet.neea.edu.cn/html1/folder/1608/1178-1.htm`、站内“考试大纲”“考核内容”“CET笔试”链接 |
| 旧 CET 域名 | `http(s)://(www.)cet.edu.cn/news_show20.html`、`news_show25.html`、`news_show26.html`；用于复核历史入口，HTTP 返回 502，HTTPS TLS 握手出现 `Received an unexpected EOF or 0 bytes from the transport stream` |
| 开放语音库 | OpenSLR SLR12、University of Edinburgh DataShare VCTK 0.92、Mozilla Data Collective Common Voice 26.0 English |
| 小粒度开放媒体 | Wikimedia Commons API：`accounting filetype:audio`、`could you filetype:audio`、精确文件名查询 |
| 许可原文 | Creative Commons CC BY 4.0、CC BY-SA 4.0、CC0 1.0 legal code |

### 2.3 纳入与排除规则

- 纳入研究矩阵：发布者或机构仓库可定位；2026-07-18 实际访问成功；页面或文件级许可可核验；能取得媒体/元数据哈希；音频与文本转写可以建立确定映射。
- 可进入 HAP：许可明确允许所需的复制、修改与再分发；媒体本体实际下载并校验；署名/相同方式共享条件可在产品内履行；文件体量适合离线；API 12 实机或模拟器播放通过。
- 排除：版权不清、只允许网页播放、要求绕过访问控制、仅有项目级宣传而无文件级许可、没有可核验转写、受保护考试题库或教材内容、未实际访问却声称可用。
- 官方考试材料用于确定能力结构和内容边界，不因“官方”身份自动获得打包或改编权。

### 2.4 来源分级

- **ARS Level VII / Grade A**：考试组织方、法律文本或机构仓库的一手页面；虽然不是实验研究，但对考试规则、许可条款和仓库事实是该问题的最高适配证据。
- **ARS Level VI / Grade A**：机构仓库的描述性数据集记录与原始 README，可直接证明版本、包体、转写和仓库许可。
- **ARS Level VI / Grade B**：自发布媒体的文件级仓库元数据；媒体字节和许可记录已复核，但作者身份与录音质量不等同于机构背书。
- 无法访问或只有二手描述的条目不进入可用清单。

## 3. 官方 CET 证据边界

| 项目 | 一手来源与发布者 | 实际访问、版本与哈希 | 许可 / 使用结论 | 音频与无障碍 | 决策 |
| --- | --- | --- | --- | --- | --- |
| CET 项目首页 | [教育部教育考试院](https://cet.neea.edu.cn/html1/folder/1608/1178-1.htm) | HTTP 200；22,329 B；SHA-256 `0569471A76C3BC0138A529CE90BCC5BA898ACD8DB218970E4ACAC941E110AE4F` | 未发现开放修改/再分发许可 | HTML 可提取文本 | `link_only`，Grade A |
| 英语四、六级考试大纲索引 | [教育部教育考试院](https://cet.neea.edu.cn/html1/folder/16113/1588-1.htm) | HTTP 200；21,220 B；SHA-256 `E56B04ECD21E1EC28FD9ADE758FFB094153DF4DB3FD159227D1F9F635E8C0C90` | 未发现开放许可；只作来源引用 | 页面列出英语大纲 PDF；列出的听力音频是日语/俄语，不是英语 | `link_only`，Grade A |
| 英语四、六级考试大纲（2016 年修订版） | [教育部教育考试院 PDF](https://cet.neea.edu.cn/res/Home/1704/55b02330ac17274664f06d9d3db8249d.pdf) | HTTP 200；`application/pdf`；12,070,155 B；SHA-256 `9166D3C03B7BC43ABD9D9DF91BD2EF8085B4419286F1E5CA100DEA68F3CFD1F1` | 未发现允许复制、改编或再分发的开放许可；不得打包 PDF 或复制受保护样题 | 本次未取得独立英语音频、VTT/SRT 或无障碍音轨 | `link_only`，Grade A |
| CET 笔试结构 | [教育部教育考试院](https://cet.neea.edu.cn/html1/folder/16113/1586-1.htm) | HTTP 200；36,168 B；SHA-256 `8CD20693E28C2BA8FA6CAAEE98910C2CB2C841B4BE5CDED5FC54D5520EF17CCC` | 未发现开放许可；只引用结构事实 | CET4 听力为短篇新闻、长对话、听力篇章，共 25 分钟；CET6 为长对话、听力篇章、讲话/报道/讲座，共 30 分钟 | `link_only`，Grade A |
| CET4/CET6 考核内容索引 | [教育部教育考试院](https://cet.neea.edu.cn/html1/category/16123/192-1.htm) | HTTP 200；19,306 B；SHA-256 `09E1373761B65E6409083509F688893FBBA78D3C654A3BEE61E20A1E0CA62E38` | 未发现开放许可 | 仅为官方内容入口，不是媒体包 | `link_only`，Grade A |
| CET-4 考核内容 | [教育部教育考试院](https://cet.neea.edu.cn/html1/report/16123/196-1.htm) | HTTP 200；23,431 B；SHA-256 `28A0BB1481E53EC39593CED17F4E0677DF610D84B1436ABD4A9AAA42C45C05D5` | 未发现开放许可 | HTML 可提取文本；无独立英语音频或字幕 | `link_only`，Grade A |
| CET-6 考核内容 | [教育部教育考试院](https://cet.neea.edu.cn/html1/report/16123/201-1.htm) | HTTP 200；23,501 B；SHA-256 `8D4F5966174EEB6D99AE45DAA3D7242420F031951E2D45C1A005ACADCFB0F35B` | 未发现开放许可 | HTML 可提取文本；无独立英语音频或字幕 | `link_only`，Grade A |

实施含义：CET 下一批应依据上述结构创作**全新**新闻、对话、篇章和讲座短材料及原创问题；不得复制 PDF 中的样题、官方录音或商业题库。

## 4. 可许可小媒体：已取得媒体本体哈希

### 4.1 `En-us-bookkeeper.ogg`

- 文件页：[Wikimedia Commons](https://commons.wikimedia.org/wiki/File:En-us-bookkeeper.ogg)；发布者/作者：Paul2520；日期：2026-05-13。
- 媒体 URL：`https://upload.wikimedia.org/wikipedia/commons/6/63/En-us-bookkeeper.ogg`
- 内容：美国中西部口音单词 `bookkeeper`；0.777868 秒；OGG；27,324 B。
- 完整媒体 SHA-1：`4975f04bb3b3367c536060d56de023da90e54d43`；SHA-256：`10F0C4A6880A63B3D6F1CFCA38BE8B0F5274A3D5067682F087BDDE5F783CDD22`。
- Commons API 元数据响应：2,176 B；SHA-256 `BC212BCC681C94467AA9CD7C59B07734EA49926E890EAAB2DBC0B1091922CA68`。
- 许可：CC BY 4.0；[许可原文](https://creativecommons.org/licenses/by/4.0/legalcode.en) HTTP 200，48,970 B，SHA-256 `6D55B998ED5C54F43426D059A8C549ED58A3321E5463E6A6AF1C6B56AB78C333`。
- 权利：允许复制、再分发和改编；公开时必须保留作者、许可、来源链接并标明修改。允许转码，但转码结果仍需履行署名。
- 文本标签：文件元数据给出单词文本；没有独立 VTT/SRT 或时间码，本轮未完成人工听辨。应用只把该文本标为文件级静态文本，不称逐词字幕。
- 教学范围：只用于词音辨识、拼读和跟读，不得描述成 CET 官方词汇录音或真题。
- 决策：**可进入小规模离线试点**，ARS Level VI / Grade B。

建议署名文本：`bookkeeper pronunciation — Paul2520, CC BY 4.0, Wikimedia Commons`。

### 4.2 `En-us-one could hear a pin drop.oga`

- 文件页：[Wikimedia Commons](https://commons.wikimedia.org/wiki/File:En-us-one_could_hear_a_pin_drop.oga)；发布者/作者：Paul2520；日期：2022-02-23。
- 媒体 URL：`https://upload.wikimedia.org/wikipedia/commons/f/f4/En-us-one_could_hear_a_pin_drop.oga`
- 内容：美式英语短语 `one could hear a pin drop`；2.763175 秒；OGG；89,071 B。
- 完整媒体 SHA-1：`49ee6b08a64b91ac6e3faae71c65fd59cece11cb`；SHA-256：`46975A7D62CC58CE59D2B02818D17127EB3C8E44D1BC543CFA99BF8B4191E8FE`。
- Commons API 元数据响应：2,083 B；SHA-256 `2D59BFF6B498E6203C99F7FD7BDCB1B523ADEE87AD8E9B7BCE2DB268B5DCE237`。
- 许可：CC BY-SA 4.0；[许可原文](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en) HTTP 200，51,859 B，SHA-256 `A7DBAD04E9A44A69A06D2EA5F20CCECCB163091550591ED41AC610F112789246`。
- 权利：允许复制、再分发和改编；必须署名；公开改编后的音频要使用兼容许可并保留修改说明。应用自身代码和与音频可分离的原创题目不应被表述为该音频的改编物，最终发布仍需法务复核相同方式共享边界。
- 文本标签：文件元数据给出完整短语；无独立时间码，本轮未完成人工听辨。应用可显示文件级静态文本，但不能称同步字幕。
- 教学范围：短语边界、弱读和听辨微练习；不是 CET 样题。
- 决策：**可进入小规模离线试点，但署名与相同方式共享门禁必须自动化**，ARS Level VI / Grade B。

建议署名文本：`one could hear a pin drop — Paul2520, CC BY-SA 4.0, Wikimedia Commons`。

## 5. 开放语料矩阵

### 5.1 LibriSpeech SLR12

- 一手来源：[OpenSLR SLR12](https://www.openslr.org/12)，发布者 Open Speech and Language Resources；页面声明约 1,000 小时、16 kHz、英语朗读语音，来源为 LibriVox，并经过分段与对齐。
- 实际访问：HTTP 200；8,245 B；页面 SHA-256 `9B012C60F8FE6A5435F96CF034C042FFE4222E7936C88CB835671413E74A5301`。
- 许可：页面明确标注 CC BY 4.0；允许改编与再分发，须署名与标明修改。
- 包体：`dev-clean.tar.gz` 337 M、`test-clean.tar.gz` 346 M、`train-clean-100.tar.gz` 6.3 G。OpenSLR 发布的 `test-clean.tar.gz` MD5 为 `32fa31d27d2e1cad72775fee3f4849a9`。
- 校验限制：本次未下载 346 M 归档，因此没有本地 SHA-256。`md5sum.txt` 可经 CN 镜像读到，但镜像证书在 2026-07-18 返回 `NotTimeValid`，不得作为生产下载通道；正式摄取必须使用有效 TLS 镜像并自行生成 SHA-256。
- 转写：资源页明确称语音经过分段和对齐；归档内逐片段文本仍需下载后做一一对应审计。
- 教学适配：适合原创短篇听力、复述和速度适应；朗读体裁不能替代 CET4 新闻/对话或 CET6 讲座的全部结构。
- 离线策略：构建期从 `dev-clean` / `test-clean` 选取少量短片段，保留原片段 ID、说话人、原文、归档 MD5、自生成 SHA-256、裁剪区间和署名；只把审核后的片段放入 HAP。
- 决策：**条件纳入，不整包分发**，ARS Level VI / Grade A。

### 5.2 CSTR VCTK 0.92

- 一手来源：[University of Edinburgh DataShare](https://datashare.ed.ac.uk/items/30e7453c-9ea8-48b4-8e18-f96d0dc62928)，DOI `10.7488/ds/2645`；发布者 CSTR；版本 0.92；2019-09 发布。
- 仓库 API 元数据：HTTP 200；9,950 B；SHA-256 `39C765F6531B0F21D9B7B6CE8B096698922E0E38F47E4D10218C9CB6194C124A`。
- 许可：CC BY 4.0。仓库 `license_text.txt` 17,416 B，SHA-256 `B34E17103BFB246F2549FC82A279E6BA28834E0CB42F76A92EFC14B72E3A3723`。
- README：5,236 B，SHA-256 `BA814954324641403096C224E20061F80819D50DCDE6B98DD253DC8C21395D44`。
- 主归档：`VCTK-Corpus-0.92.zip`，11,747,302,977 B，仓库 MD5 `8a6ba2946b36fcbef0212cad601f4bfa`；本次未下载归档，未生成本地 SHA-256。
- 媒体与转写：110 位多口音英语说话人，每人约 400 句；README 与仓库摘要明确说明 `/txt` 为 109/110 位说话人提供转写，`p315` 文本因硬盘错误丢失。原始音频为 48 kHz、16 bit。
- 版权注意：部分文本来自 Herald Glasgow，README 表述为已获 Herald & Times Group 许可；数据集整体标为 CC BY 4.0，但没有公开该第三方许可全文。进入 HAP 前应只选取文本权属清楚的片段，或让法务确认数据集级 CC BY 覆盖目标转写。
- 教学适配：多口音辨识、同句跨说话人比较、跟读；体量过大，不适合作为端侧运行时下载源。
- 离线策略：仅在构建环境下载，按片段做版权与转写检查，重采样/转码时记录修改，生成片段级 SHA-256 和署名；不得把 `p315` 当作有转写素材。
- 决策：**条件纳入，第三方文本权利复核后再打包片段**，ARS Level VI / Grade A（仓库事实）/ Grade B（第三方文本覆盖范围）。

### 5.3 Common Voice Scripted Speech 26.0 - English

- 一手来源：[Mozilla Data Collective 数据页](https://mozilladatacollective.com/datasets/cmqim2hn800ssnr07gvmpcnwu)，发布者 Common Voice；页面创建时间 `2026-06-17T21:56:49.748Z`。
- 实际访问：HTTP 200；302,211 B；SHA-256 `8C9638E7300FFE12FE9D782324F5B34807DBC72B8716AF9D0883D9424405ECCB`。
- 许可与包：页面声明 `Creative Commons Zero v1.0 Universal (CC0-1.0)`；格式字段为 MP3；归档 94,639,372,950 B；发布的 SHA-256 `6809228e6ab506d18f6a1ebc830056450f8266c8f513d6038bdb0fc88a49e6cb`。
- [CC0 1.0 原文](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en)：HTTP 200；32,451 B；SHA-256 `001E3D1C905C18B1D034B34200CC952026ABB38457C2294C23EAEF7F6BDA64DF`。
- 分发合同：[MDC Data Consumer Terms](https://mozilladatacollective.com/terms/consumers) HTTP 200；360,010 B；SHA-256 `4B568781EB536B0CF8FD67CDF45E69059E2F799B5FFC2B34A6C1183DAFE3D5F3`。条款要求下载前认证、审阅并接受具体 Data Consumer License，并禁止绕过访问控制或超出该许可使用数据。
- 转写：当前数据页只声明 MP3，未公开包内文件清单或转写字段；本次没有登录、接受合同或下载 94.6 GB 归档，因此不能声称已取得音频-文本映射。
- 教学适配：理论上可提供广泛口音与说话人素材；当前体量、合同和转写未验证使其不适合首批 HAP。
- 决策：**暂不纳入；完成账户合同审阅、归档下载、包内转写审计和隐私/人口属性最小化后复评**，ARS Level VI / Grade A（页面许可与包事实），运行可用性未验证。

## 6. API 12 播放、字幕与离线门禁

### 6.1 已由本地 SDK 源码确认

本机 `DEVECO_HOME\sdk\default\openharmony\ets\api` 的 API 12 定义确认：

- `@ohos.multimedia.media.d.ts` 的 `createAVPlayer()` 标注 `@since 12`，可创建音视频播放器。
- `AVPlayer.fdSrc` 标注 `@since 12`，支持 MP4/MPEG-TS/MKV 视频与 M4A/AAC/MP3/**OGG**/WAV/FLAC/AMR 音频。
- `@ohos.resourceManager.d.ts` 的 `ResourceManager.getRawFd(path)` 可取得 HAP `resources/rawfile` 中媒体的文件描述符；使用后必须关闭 FD。

SDK API 的证据等级仍为**源码确认**。两个 Commons OGG/OGA 原始文件已进入 `resources/rawfile/learning/media`，生成器逐文件校验实际大小与媒体本体 SHA-256，API 12 HAP 已构建并替换安装；尚未实际触发 `prepare()` / `play()`，因此播放能力仍为未验证。

### 6.2 首批端侧实现要求

1. 小文件放在 `resources/rawfile`，播放器通过 raw FD 读取；不要依赖网页播放器、重定向 URL 或运行时抓取。
2. 每个媒体旁展示完整可见转写；播放按钮提供“播放/暂停 + 文本内容 + 口音”可访问名称；错误态仍显示转写和重试入口。
3. 词/短语音频不需要伪造逐字时间码；较长材料必须提供片段级时间范围、整篇转写和当前句高亮的明确数据来源。
4. 网络态与离线态分离：HAP 内置片段始终可播；未缓存远端媒体显示“仅有文本/稍后下载”，不得把网络失败变成空白控件。
5. 媒体哈希校验在生成链和测试中完成；运行时只读取已进入签名 HAP 的资源，不在前端临时修改许可元数据。
6. 完成后需在 API 12 模拟器对 OGG 与 MP3 各验证一次：准备、播放、暂停、完成、页面离开释放、离线重进、系统音频中断、TalkBack/无障碍名称。

## 7. 已实施的单一来源媒体契约

Web `ExternalResource.type` 已增加 `audio`，并以可选 `media` 记录媒体 URL、MIME、大小、时长、文件级静态文本、语言、时间码状态、口音说明、文本来源、HAP rawfile 路径、署名、许可 URL、修改状态、相同方式共享要求和源 SHA-1。共享官方来源使用 `courseIds`，专属音频继续使用 `courseId`；两者互斥并由测试约束。

HarmonyOS `ExternalLearningResource` 与 `LessonExperience.mediaResourceIds` 使用同一生成产物，没有新增平行媒体 JSON。统一生成器在写出六份学习资产前读取 HAP 内媒体本体，校验实际字节数和 SHA-256；Web/HarmonyOS 全字段一致性测试同时验证许可、课程关联和媒体资源外键。

当前已覆盖资源类型、媒体 URL、媒体本体 SHA-256、字节数、时长、MIME、源 SHA-1、作者署名、许可 URL、修改/相同方式共享状态、文件级静态文本、语言、时间码状态和 HAP rawfile 路径。尚未覆盖页面播放、网络/加载/格式不支持状态和离页释放；这些必须在 AVPlayer 页面实现后再验收。

## 8. 明确排除与未验证

- **排除商业题库、培训机构听力、教材音频和受保护真题**：无论页面可否播放，都不能复制题目、录音、解析或字幕。
- **排除官方 CET PDF/网页打包**：可引用链接、标题、发布者与哈希，不能把缺少开放许可解释成允许再分发。
- **排除仅网页播放或无文件级许可的媒体**：网站总页脚许可不能替代具体音频文件许可。
- **排除旧 `cet.edu.cn` 访问结果作为当前证据**：HTTP 502、HTTPS TLS 异常只证明本次访问失败；当前事实以可访问的教育部教育考试院 CET 页面为准。
- **暂缓 Common Voice 归档**：未接受下载合同、未下载、未验证转写和隐私字段。
- **暂缓 VCTK 报刊文本片段**：第三方文字许可范围未公开核验。
- **LibriSpeech / VCTK 设备播放未验证**：只完成许可、仓库和 SDK 源码证据。
- **没有英语官方样卷音频的结论仅限官方大纲索引当前页面**；全站和后续更新仍需发布前重查。

## 9. 当前可运行范围与下一步

1. 已完成：两个 Commons 文件按原始字节打包；媒体清单由 Web 单一来源生成到 HarmonyOS，并以 SHA-256、大小、许可、静态文本和课程关联门禁阻止漂移。
2. 已完成：CET-4/CET-6 各 5 个知识切片、5 道原创题、1 个关系、1 个 Lesson experience 和 2 个活动；官方来源只限定目标结构，开放音频不称官方材料。
3. 已完成：API 12 模拟器显示两门课程和两条基线诊断，并完成一次 CET-6 5/5 诊断与 ArkData/Plan 回流。
4. 下一步：在独立页面域实现播放、暂停、文件级静态文本、离线失败态、署名、离页释放与可访问名称，并取得真实 OGG 播放证据。
5. 通过后再从 LibriSpeech 或权利复核后的 VCTK 选取10-30秒片段；不得把朗读语料标记为官方模拟题。

## 10. 限制与 AI 披露

- 本次是 2026-07-18 的一次性访问快照；页面内容、下载合同、许可标注和媒体文件可能更新，正式发布前必须重抓并比对哈希。
- 未登录需要认证的平台，未下载大体量归档，也未对开放语料的全部说话人、隐私属性和文本来源做穷尽审计。
- 许可判断是工程门禁，不是法律意见；涉及 CC BY-SA 聚合边界、VCTK 第三方文本或 MDC 合同的发布必须由项目责任人复核。
- 本文件由 AI 辅助检索与整理；所有列为“实际访问”的 URL、字节数与哈希均由本轮工具调用取得，未访问项明确标为未验证。
