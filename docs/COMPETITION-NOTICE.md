# 鸿学伴竞赛第三方 NOTICE、原创与 AI 使用声明

> 审计日期：2026-07-17
>
> 文档状态：正式提交前草案，尚未签署。
>
> 适用范围：鸿学伴竞赛作品说明 PDF、演示视频、可运行 HAP 与 Demo/源码 ZIP。
>
> 事实边界：**源码确认**只证明当前仓库或当前安装依赖中存在对应信息；`CHECK-BEFORE-SUBMISSION` 表示必须由队长或内容负责人在最终提交版本人工核对并清除的阻断项。

## 一、使用方式与当前结论

1. 本文件不是对第三方权利的法律意见，也不自动授予作品代码、课程内容或素材任何许可。
2. 当前仓库根目录没有项目 `LICENSE` 或 `NOTICE`；`.agents/skills/imagegen-frontend-mobile/LICENSE` 与 `.agents/skills/impeccable/LICENSE` 只覆盖对应开发工具，不覆盖鸿学伴产品代码。
3. Web 直接依赖的精确版本由 `apps/web/package.json`、`apps/web/pnpm-lock.yaml` 与当前安装包的 `package.json` 交叉核对。
4. HarmonyOS 的 `apps/harmonyos/oh-package.json5`、`apps/harmonyos/entry/oh-package.json5` 和 `apps/harmonyos/oh-package-lock.json5` 当前未声明第三方 OHPM 依赖。
5. 当前 HarmonyOS 产品资源树没有 Lottie、第三方 SVG、音频或自带字体；发现 5 个 PNG 文件（3 个唯一内容哈希）和 5 个学习数据 JSON。旧 `assets/` 调研记录不等于产品采用，相关文件不得进入正式 HAP 或 ZIP。
6. 最终提交前必须把所有 `CHECK-BEFORE-SUBMISSION` 处理完毕。仍有标记时，本文件只能作为审计草案，不能作为已完成的版权或原创声明。

## 二、Web 直接依赖 NOTICE

### 1. 生产直接依赖

| 包与精确版本 | 当前用途依据 | 许可证依据 | 当前状态 | 正式提交前动作 |
|---|---|---|---|---|
| `@vercel/analytics@2.0.1` | `apps/web/src/app/layout.tsx`；锁文件解析为 2.0.1 | 安装包 `package.json` 为 MIT；`apps/web/node_modules/@vercel/analytics/LICENSE` 存在；repository 为 `github:vercel/analytics` | **源码确认** | CHECK-BEFORE-SUBMISSION：把该精确版本许可证全文纳入最终第三方许可附件，并核对分析数据披露 |
| `@vercel/speed-insights@2.0.0` | `apps/web/src/app/layout.tsx`；锁文件解析为 2.0.0 | 安装包 `package.json` 为 Apache-2.0；`apps/web/node_modules/@vercel/speed-insights/LICENSE` 存在；repository 为 `github:vercel/speed-insights` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入 Apache-2.0 全文，核对是否存在额外 NOTICE 与遥测披露 |
| `lucide-react@0.460.0` | Web 页面图标；锁文件解析为 0.460.0 | 安装包 `package.json` 为 ISC；`apps/web/node_modules/lucide-react/LICENSE` 说明 Lucide 为 ISC，Feather 派生部分为 MIT | **源码确认** | CHECK-BEFORE-SUBMISSION：同时保留 Lucide、Lucide Contributors 与 Feather 部分的版权和许可文字 |
| `next@14.2.18` | Web 应用与 API 框架；锁文件解析为 14.2.18 | 安装包 `package.json` 为 MIT；`apps/web/node_modules/next/license.md` 存在；repository 为 `vercel/next.js` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入该精确版本许可证全文，并由最终生产构建生成传递依赖报告 |
| `openai@4.73.1` | `apps/web/src/lib/agents/model.ts`；锁文件解析为 4.73.1 | 安装包 `package.json` 为 Apache-2.0；`apps/web/node_modules/openai/LICENSE` 存在；repository 为 `github:openai/openai-node` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入 Apache-2.0 全文；不得把 SDK 许可证写成远程模型服务授权 |
| `react@18.3.1` | Web 客户端组件；锁文件解析为 18.3.1 | 安装包 `package.json` 为 MIT；`apps/web/node_modules/react/LICENSE` 存在；repository 为 `https://github.com/facebook/react.git` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入该精确版本许可证全文 |
| `react-dom@18.3.1` | Next.js Web 渲染；锁文件解析为 18.3.1 | 安装包 `package.json` 为 MIT；`apps/web/node_modules/react-dom/LICENSE` 存在；repository 为 `https://github.com/facebook/react.git` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入该精确版本许可证全文 |

### 2. 开发直接依赖

开发依赖通常不进入 HAP 或生产运行包，但会出现在源码构建链和锁文件中，因此仍需随源码 ZIP 提供可追溯清单。

| 包与精确版本 | 许可证依据 | 当前状态 | 正式提交前动作 |
|---|---|---|---|
| `@types/node@22.9.0` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/@types/node/LICENSE` 存在 | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `@types/react@18.3.12` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/@types/react/LICENSE` 存在 | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `@types/react-dom@18.3.1` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/@types/react-dom/LICENSE` 存在 | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `autoprefixer@10.4.20` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/autoprefixer/LICENSE` 存在；repository 为 `postcss/autoprefixer` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `eslint@8.57.1` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/eslint/LICENSE` 存在；repository 为 `eslint/eslint` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `eslint-config-next@14.2.18` | 安装包 `package.json` 为 MIT，repository 为 `vercel/next.js`；安装包根目录未发现独立许可证文件 | **源码确认** | CHECK-BEFORE-SUBMISSION：从精确 14.2.18 上游来源核对并收录许可证全文，不以相邻包许可证代替 |
| `postcss@8.4.49` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/postcss/LICENSE` 存在；repository 为 `postcss/postcss` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `tailwindcss@3.4.15` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/tailwindcss/LICENSE` 存在；repository 为 `https://github.com/tailwindlabs/tailwindcss.git` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `typescript@5.6.3` | 安装包 `package.json` 为 Apache-2.0；`apps/web/node_modules/typescript/LICENSE.txt` 存在；repository 为 `https://github.com/microsoft/TypeScript.git` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |
| `vitest@4.1.9` | 安装包 `package.json` 为 MIT；`apps/web/node_modules/vitest/LICENSE.md` 存在；repository 为 `git+https://github.com/vitest-dev/vitest.git` | **源码确认** | CHECK-BEFORE-SUBMISSION：纳入完整构建依赖报告 |

### 3. 传递依赖

当前本机安装树的只读结果如下；该汇总不是完整许可证附件，也不能替代最终部署平台的报告。

| 范围 | `pnpm licenses list --json` 当前结果 | 当前状态 | 正式提交前动作 |
|---|---|---|---|
| 生产依赖树 | 63 条记录：MIT 51、Apache-2.0 5、ISC 3、0BSD 1、BSD-2-Clause 1、BSD-3-Clause 1、CC-BY-4.0 1 | **源码确认** | CHECK-BEFORE-SUBMISSION：在最终锁文件和实际生产构建平台重新生成逐包报告；逐项附版本、来源、许可证全文与版权文字 |
| 开发依赖树 | 386 条记录：MIT 327、ISC 26、Apache-2.0 12、BSD-2-Clause 7、BlueOak-1.0.0 4、BSD-3-Clause 3、MPL-2.0 2，以及 `(MIT OR CC0-1.0)`、0BSD、CC-BY-4.0、ODC-By-1.0、Python-2.0 各 1 | **源码确认** | CHECK-BEFORE-SUBMISSION：在最终源码 ZIP 构建环境重新生成逐包报告，区分仅开发使用与可能进入产物的依赖 |

特别注意：

- 生产树当前包含 `caniuse-lite@1.0.30001799`，其安装包元数据为 CC-BY-4.0。CHECK-BEFORE-SUBMISSION：核对最终构建是否分发其数据，并按精确许可证完成署名。
- 当前命令只检查本机已安装包；Next.js 的平台可选二进制会随构建操作系统变化。CHECK-BEFORE-SUBMISSION：在正式生产构建平台重新运行，不得复用 Windows 安装树结果。
- 最终许可证附件必须保存机器可读逐包报告和需要随分发保留的许可证/NOTICE 全文；本节的数量汇总不能代替该附件。

建议在最终版本执行：

```powershell
cd apps/web
pnpm licenses list --prod --long --json
pnpm licenses list --dev --long --json
```

## 三、HarmonyOS 平台与产品素材

### 1. OHPM 与系统能力

| 项目 | 当前事实 | 当前状态 | 正式提交前动作 |
|---|---|---|---|
| 根模块 OHPM 依赖 | `apps/harmonyos/oh-package.json5` 的 `dependencies` 和 `devDependencies` 为空 | **源码确认** | CHECK-BEFORE-SUBMISSION：对最终提交文件重复核对 |
| `entry` 模块 OHPM 依赖 | `apps/harmonyos/entry/oh-package.json5` 的 `dependencies` 为空，`license` 字段也为空 | **源码确认** | CHECK-BEFORE-SUBMISSION：确认项目代码对评委的查看、构建与运行授权文字，并保持不引入未审计包 |
| OHPM 锁文件 | `apps/harmonyos/oh-package-lock.json5` 的 `specifiers` 与 `packages` 均为空 | **源码确认** | CHECK-BEFORE-SUBMISSION：对最终锁文件重复核对 |
| HarmonyOS Kit 与系统 Symbol | ArkTS 源码引用 HarmonyOS SDK Kit 和 `sys.symbol.*`；当前通过 `rg -o "sys\.symbol\.[A-Za-z0-9_]+" apps/harmonyos/entry/src/main/ets` 统计到 76 次引用、29 个不同 Symbol ID | **源码确认** | CHECK-BEFORE-SUBMISSION：按最终 SDK、开发者协议和竞赛分发方式核对使用权；系统 API 不得写成开源第三方资产 |

旧资产调研文档中出现的 `@ohos/lottie`、`@ohos/lottie-turbo`、Tabler、Phosphor、canvas-confetti、SpinKit、Zustand、Comlink 和 BlurHash 均不在当前 HarmonyOS 依赖或产品资源树中。它们只可作为历史调研记录，不能进入最终 NOTICE 的“已采用”清单。

### 2. 当前 5 个 PNG 文件（3 个唯一内容哈希）

| 精确路径 | 字节 | SHA-256 | 当前状态 | 正式提交前动作 |
|---|---:|---|---|---|
| `apps/harmonyos/AppScope/resources/base/media/background.png` | 91942 | `497EDEAFC51AF043C73E72EE8C4FBAC4663357EF1BA275C0289F31A366B26239` | **源码确认**：与 `entry` 的 `background.png` 内容相同；文件在提交 `1c1562cc76f67ce4bcf07be5c38894793e510072` 加入；原始作者、生成方式和授权未记录 | CHECK-BEFORE-SUBMISSION：由提交者确认作者/来源、创作或生成方式、使用权和是否需要署名 |
| `apps/harmonyos/AppScope/resources/base/media/foreground.png` | 8805 | `57E549283F255505A649042F36A1D6793C307A69A94C9FA7E27A38AF38DDBE8C` | **源码确认**：与 `entry` 的 `foreground.png` 内容相同；文件在提交 `1c1562cc76f67ce4bcf07be5c38894793e510072` 加入；原始作者、生成方式和授权未记录 | CHECK-BEFORE-SUBMISSION：由提交者确认作者/来源、创作或生成方式、使用权和是否需要署名 |
| `apps/harmonyos/entry/src/main/resources/base/media/background.png` | 91942 | `497EDEAFC51AF043C73E72EE8C4FBAC4663357EF1BA275C0289F31A366B26239` | **源码确认**：文件在提交 `1c1562cc76f67ce4bcf07be5c38894793e510072` 加入；原始作者、生成方式和授权未记录 | CHECK-BEFORE-SUBMISSION：由提交者确认作者/来源、创作或生成方式、使用权和是否需要署名 |
| `apps/harmonyos/entry/src/main/resources/base/media/foreground.png` | 8805 | `57E549283F255505A649042F36A1D6793C307A69A94C9FA7E27A38AF38DDBE8C` | **源码确认**：文件在提交 `1c1562cc76f67ce4bcf07be5c38894793e510072` 加入；原始作者、生成方式和授权未记录 | CHECK-BEFORE-SUBMISSION：由提交者确认作者/来源、创作或生成方式、使用权和是否需要署名 |
| `apps/harmonyos/entry/src/main/resources/base/media/startIcon.png` | 20093 | `567C7C0C7A321CA180E010AD880F0F7519F6D351AC2B9665E2EE710E7CFE7778` | **源码确认**：文件在提交 `1c1562cc76f67ce4bcf07be5c38894793e510072` 加入；原始作者、生成方式和授权未记录 | CHECK-BEFORE-SUBMISSION：由提交者确认作者/来源、创作或生成方式、使用权和是否需要署名 |

在 5 个 PNG 文件对应的 3 个唯一内容来源和权利未确认前，不得在原创声明中写“全部视觉资产均为团队原创”，也不得把它们标成 HarmonyOS 官方素材。

## 四、课程内容、题库与外部资源

### 1. 当前学习数据账本

| 数据 | 数量与 SHA-256 | 现有来源字段 | 当前状态 | 正式提交前动作 |
|---|---|---|---|---|
| `apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json` | 147 条；`E6C07471F7E607A91FC9F70598F50B109592E3C23EE2F4BCD3C22F1B908253D4` | 每条含版次、Topic 对应章节、官方 URL、权利状态和访问记录；由三份 Web TS 数据生成 | **源码确认**：三批均为 `reference-only`，只建立书目参考映射，不证明文本逐字来自对应章节或已经取得改写授权 | CHECK-BEFORE-SUBMISSION：内容负责人逐批确认实际创作/改写关系和合法依据；不能仅凭字段齐全宣称版权已解决 |
| `apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json` | 165 条；`87D686BD895297CC71CBB9ECDCF4A0200D85B09CCEDA19980B0760B94E69D65D` | 没有内容来源或作者字段 | **源码确认**：结构和单一来源可校验，不证明题目原创或学科正确 | CHECK-BEFORE-SUBMISSION：团队逐题确认原创/改写来源、答案与解析，不得宣称“答案 100% 正确” |
| `apps/harmonyos/entry/src/main/resources/rawfile/learning/lesson-experiences.json` | 33 个 Topic、59 个活动；`420CD7334FD85FF937F2E08003E714DB3FECFDD5FE5ED2870196CC0CBAC0CAD1` | 26 个 Topic 来自三份主动学习规格，7 个为既有体验迁移；59 个活动均含非空标准答案与 `source` | **源码确认**：生成关系和来源文字可校验，不证明案例、代码与图解已完成人工权利复核 | CHECK-BEFORE-SUBMISSION：确认每条案例、示例、代码和图解步骤的作者与来源，补充必要署名 |
| `apps/harmonyos/entry/src/main/resources/rawfile/learning/topic-relations.json` | 33 条；`E3F9DAEBB1E14DDB320B4B6DC6C88BA48F72CFF4BE923E359B13F3CE13CA2562` | 只有课程、Topic 与先修关系 | **源码确认** | CHECK-BEFORE-SUBMISSION：确认关系设计为团队原创分析或披露参考来源 |
| `apps/harmonyos/entry/src/main/resources/rawfile/learning/external-resources.json` | 36 条；`7D23998C8018C092067E4D3DB4108C21DB780A98F93DC6FD4C4889E384B010E9` | 每条含版次/定位、官方 URL、`external-link-only`、检查日期和 HTTP 状态；26 条绑定课程，10 条按 Web 既有可选 `courseId` 契约作为全局资源；由 Web TS 数据生成 | **源码确认**：35 条记录为 200，`res_01` 为 403；只证明已记录请求条件下的最终响应 | CHECK-BEFORE-SUBMISSION：临近截止再次访问并核对业务页面、使用条款与描述原创性；HTTP 状态不等于内容长期可用或取得许可证 |

`docs/RESOURCE-AUDIT-20260630.md` 绑定旧提交 `48d75b8`，只作为历史记录。当前逐项事实以 `apps/web/src/lib/data/external-resources.ts` 为单一来源，经 `scripts/generate-learning-content-json.mjs` 生成端侧 JSON；NOTICE 不再手工复制 36 行数据。

### 2. 36 条外部资源访问与权利边界

2026-07-17 使用 `curl.exe -L -sS -o NUL --max-time 20 -w "%{http_code}"` 逐项访问：32 条默认请求最终为 200。对历史失败或响应分歧项曾使用浏览器标识请求复核，但仓库未保存精确 UA 字符串、最终 URL 和检查时刻，因此下表只能作为当日审计记录，不能单独复现对应响应：

| ID | 默认请求 | 浏览器 UA 复核 | 产品数据记录 | 结论边界 |
|---|---:|---:|---|---|
| `res_01` | 未作为最终证据 | 403 | `unreachable / 403` | 页面拒绝本次请求；不得写成可用 |
| `res_10` | 未作为最终证据 | 200 | `reachable / 200` | 只证明图书详情页在该 UA 下响应；页面同时核出第 9 版、2026-06、ISBN 9787121527852 |
| `res_26` | 451 | 200 | `reachable / 200` | 页面按 UA 返回不同状态；精确 UA 未留存，当前记录不可复现，不得泛化为长期可用 |
| `res_34` | 未作为最终证据 | 200 | `reachable / 200` | 只证明 GNU GDB 项目页在该 UA 下响应 |

每条资源都记录 `sourceTitle`、`sourceVersion`、`sourceLocator`、`sourceUrl`、`rightsStatus`、`rightsName`、`rightsUrl`、`accessStatus`、`checkedAt` 和 `httpStatus`。`rightsStatus=external-link-only` 的含义只是产品保存并打开第三方链接，不复制或再分发页面及附件；它不是第三方授予鸿学伴的内容许可证。最终提交前仍须逐项核对实际使用方式、页面业务内容和适用条款。

## 五、外部服务与模型

| 服务 | 当前源码事实 | 当前状态 | 正式提交前动作 |
|---|---|---|---|
| 火山方舟模型 API | `apps/web/src/lib/agents/model.ts` 默认 Base URL 为 `https://ark.cn-beijing.volces.com/api/v3`，默认模型 ID 为 `doubao-seed-2-1-pro-260628` | **源码确认**：只证明默认配置，不证明最终部署仍使用该模型或账户有权提交演示 | CHECK-BEFORE-SUBMISSION：用最终线上 Health 和真实业务请求记录精确模型、时间、业务字段；核对服务条款、账户授权和演示数据使用范围 |
| Vercel 托管 | `apps/harmonyos/entry/src/main/ets/common/Constants.ets` 的生产地址为 `https://hormony-ruddy.vercel.app` | **源码确认**：只证明客户端配置 | CHECK-BEFORE-SUBMISSION：核对部署所有权、可访问期、平台条款、隐私披露和最终部署版本 |
| Vercel Analytics / Speed Insights | Web 布局实际加载两个对应包 | **源码确认** | CHECK-BEFORE-SUBMISSION：确认竞赛演示与评委访问时的数据收集范围，并在需要时提供隐私说明或关闭非必要遥测 |
| HarmonyOS SDK、Kit 与系统 Symbol | 产品使用平台 SDK 和系统资源，不把模型密钥放入 HAP | **源码确认** | CHECK-BEFORE-SUBMISSION：核对最终 SDK、应用签名、开发者协议和竞赛分发授权；不要把平台使用权描述成开源许可证 |

远程模型服务条款、云平台条款和账户权限与 SDK/包的开源许可证是不同问题，必须分别核对。

## 六、原创声明草案

以下内容在全部阻断项完成、团队真实信息填写并签署后，才可作为正式原创声明。

### 1. 签署信息

- 作品名称：CHECK-BEFORE-SUBMISSION：填写门户最终作品名称。
- 参赛队伍：CHECK-BEFORE-SUBMISSION：填写门户最终队伍名称。
- 队长与队员：CHECK-BEFORE-SUBMISSION：逐人填写门户真实姓名。
- 指导老师：CHECK-BEFORE-SUBMISSION：填写门户真实姓名。
- 对应 Git 提交：CHECK-BEFORE-SUBMISSION：填写最终提交完整哈希。
- 对应 HAP 与 ZIP：CHECK-BEFORE-SUBMISSION：填写精确文件名、字节数和 SHA-256。

### 2. 逐项确认

- CHECK-BEFORE-SUBMISSION：团队确认作品核心创意和主要开发过程在本届竞赛期间独立完成，并保留可核对的提交记录。
- CHECK-BEFORE-SUBMISSION：团队逐文件确认产品代码、课程内容、题库、Lesson 体验、图像、图表、字幕、旁白和演示素材的作者或合法来源。
- CHECK-BEFORE-SUBMISSION：团队确认所有第三方软件、内容、标准、课程、教材、图标、字体、图片、音频与在线服务均已在最终 NOTICE 或引用表中准确披露。
- CHECK-BEFORE-SUBMISSION：团队确认未把其他同类同级赛事获奖作品直接重复申报；如存在赛前基础，单独列出本届竞赛期间的实质性新增内容。
- CHECK-BEFORE-SUBMISSION：团队确认 PDF、视频和 Demo 中的页面与数据来自同一最终版本，没有使用静态回复、测试替身、手工改数或合成截图伪造产品能力。
- CHECK-BEFORE-SUBMISSION：队长、全体队员与指导老师审阅并签署；签署日期与门户提交时间一致。

### 3. 声明正文模板

> 本团队郑重声明：鸿学伴作品的核心创意和主要开发过程由本团队在本届竞赛期间完成。作品中使用的第三方软件、课程与教材参考、外部资源、平台服务和 AI 辅助过程，均按最终 NOTICE、引用表和 AI 使用说明如实披露。提交的 PDF、视频、HAP 与源码 ZIP 对应同一最终版本，未以静态回复、测试替身、手工改数或合成运行截图伪造产品能力。本团队对作品的原创性、内容准确性、知识产权合规性和提交材料真实性承担责任。

该正文目前为**未验证**：尚未签署，不能单独证明任何一句事实成立。

## 七、AI 使用说明草案

### 1. 产品运行时 AI

- **源码确认**：Web 服务通过 `apps/web/src/lib/agents/model.ts` 调用远程模型，默认模型 ID 为 `doubao-seed-2-1-pro-260628`；Profile、Retrieval、Planner、Quiz、Evaluator、Tutor 与 Safety 的编排位于 `apps/web/src/lib/agents/orchestrator.ts`。
- **源码确认**：模型密钥由服务端环境变量读取，没有放入 `NEXT_PUBLIC_*` 或 HarmonyOS HAP。
- CHECK-BEFORE-SUBMISSION：通过最终线上 Health、Chat SSE、Plan 和 Quiz 记录确认实际部署模型、业务字段、时间和安全结果；默认源码值不能代替线上证据。
- CHECK-BEFORE-SUBMISSION：在作品说明中披露模型服务提供方、AI 生成内容类型、人工复核方式、失败边界和用户数据范围，不宣称所有输出都有引用或答案百分之百正确。

### 2. 开发与内容制作中的 AI 辅助

- **源码确认**：仓库存在 `AGENTS.md`、`docs/CODEX-HANDOFF-HARMONY-2.0-20260707.md` 和 `docs/HANDOFF-TO-TRAE.md`，证明项目采用过 AI 辅助开发流程；现有文件不能完整证明每名成员实际使用的工具、模型版本、日期与具体贡献。
- CHECK-BEFORE-SUBMISSION：由每名团队成员填写实际使用的 AI 工具、精确产品/模型名称、使用日期范围和用途，至少区分需求分析、代码辅助、测试、课程内容、题库、文案、图像和视频。
- CHECK-BEFORE-SUBMISSION：逐项列出直接采用、修改后采用和未采用的 AI 输出；对进入提交物的内容记录负责人和人工复核结果。
- CHECK-BEFORE-SUBMISSION：确认没有把 AI 生成的界面图、静态答案、假日志或测试替身作为模拟器、真机或线上运行证据。
- CHECK-BEFORE-SUBMISSION：确认 5 个 PNG 文件对应的 3 个唯一内容是否由生成式 AI、设计工具模板或人工绘制产生；来源未确认前不得写“全部视觉资产原创”。
- CHECK-BEFORE-SUBMISSION：确认 147 条课程切片、165 道题和 33 个 Topic 下的 59 个 Lesson 活动是否使用 AI 辅助生成或改写，并完成学科、版权、事实和答案人工复核。
- CHECK-BEFORE-SUBMISSION：确认 AI 工具没有接收 API Key、Authorization、私钥、签名材料、未公开个人信息或超出授权范围的教材全文。

### 3. AI 使用说明正文模板

> 本项目在开发与材料制作中使用了生成式 AI 辅助。AI 的实际工具、模型、使用日期、用途和被采用内容详见本声明附表。所有进入源码、课程内容、题库、图片、PDF 和视频的 AI 辅助结果均须由具名团队成员复核；未完成复核的结果不进入正式提交。AI 不作为作品作者，也不替代团队对代码安全、学科正确、版权合规和材料真实性承担的责任。产品运行时的模型输出来自真实服务调用；失败时明确报错，不使用静态回复或测试替身冒充成功。

CHECK-BEFORE-SUBMISSION：只有实际工具附表、逐项复核记录和团队签字齐备后，才能删除本标记并采用正文。

## 八、正式提交前阻断门禁

### 1. 许可证与素材

- CHECK-BEFORE-SUBMISSION：生成最终生产与开发传递依赖逐包报告，保留每个包的精确版本、来源、许可证和所需版权/NOTICE 全文。
- CHECK-BEFORE-SUBMISSION：核对生产构建平台的可选二进制依赖，不复用本机 Windows 报告。
- CHECK-BEFORE-SUBMISSION：确认根项目对评委查看、构建和运行源码的授权文字；第三方许可证不覆盖项目自身代码。
- CHECK-BEFORE-SUBMISSION：确认 5 个 PNG 文件对应的 3 个唯一内容的原始作者、生成方式、授权、哈希和用途。
- CHECK-BEFORE-SUBMISSION：内容负责人复核 147 个知识切片现有三批书目/章节映射，确认实际创作或合法改写关系并签字。
- CHECK-BEFORE-SUBMISSION：完成 165 道题、33 个 Topic 下 59 个 Lesson 活动和 33 条 Topic 关系的作者/来源与内容复核。
- CHECK-BEFORE-SUBMISSION：临近截止重新访问 36 条外部资源，补记北京时间、最终 URL 和关键业务页面，并核对作者/机构、版次/章节及使用条款；当前 2026-07-17 状态不能替代提交时复核。
- CHECK-BEFORE-SUBMISSION：最终 ZIP 排除 `.agents/`、`assets/`、`.tmp/`、旧展示站、开发缓存、截图、日志和未采用调研资源。

### 2. 原创与 AI

- CHECK-BEFORE-SUBMISSION：填写真实作品、队伍、成员、指导老师、提交哈希、HAP/ZIP 文件名和 SHA-256。
- CHECK-BEFORE-SUBMISSION：每名成员填写 AI 工具与贡献附表，内容负责人逐项签字。
- CHECK-BEFORE-SUBMISSION：队长、全体队员和指导老师审阅并签署原创声明与 AI 使用说明。
- CHECK-BEFORE-SUBMISSION：PDF、视频旁白、门户简介、README 与本文件使用完全一致的功能数字和证据等级。

### 3. 完成判定

草案阶段可用以下命令列出所有未完成项：

```powershell
rg -n "CHECK-BEFORE-SUBMISSION" docs/COMPETITION-NOTICE.md
```

正式提交版必须满足：

1. 上述命令没有匹配项。
2. 所有引用的仓库路径在最终提交清单中存在，或明确标为只读审计证据且不进入 ZIP。
3. 许可证报告、许可证全文、内容来源表、外部资源访问记录、签名页、HAP/ZIP 哈希均能打开并互相对应。
4. 不使用“源码确认”替代人工权利确认、签署、模拟器、真机或线上证据。

