# 环境配置记录

> 最近核查：2026-06-25 12:20 CST | 操作系统：Windows 11

## 已就绪

| 工具 | 版本 | 路径 / 说明 |
|------|------|------------|
| Git | 2.54.0.windows.1 | 系统 PATH |
| Node.js | v22.22.2 | 系统 PATH |
| npm | 10.9.7 | 系统 PATH |
| pnpm | 11.9.0 | 系统 PATH |
| Python | 3.13.12 | 系统 PATH |
| OpenJDK | 17.0.14 LTS | 系统 PATH |
| Chrome | 已安装 | OK |
| Edge | 已安装 | OK |
| DevEco Studio | 26.0.0.461 (build 2600461) | `C:\Program Files\Huawei\DevEco Studio\` |
| HarmonyOS SDK | 随 DevEco Studio 内置 | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\` |
| 模拟器镜像 | HarmonyOS-6.1.1 (phone_x86) | `C:\Users\guo82\AppData\Local\Huawei\Sdk\system-image\HarmonyOS-6.1.1\` |
| ohpm | 26.0.0.410 | `C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat` |
| hvigor | 随 DevEco Studio | `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\` |
| hdc | 随 SDK toolchains | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe` |

## 待配置

| 项目 | 说明 | 状态 |
|------|------|------|
| PATH 环境变量 | ohpm / hvigor / hdc 不在系统 PATH | 可通过 DevEco Studio 或 MCP 使用，建议手动添加 |
| JAVA_HOME | 未设置 | 建议指向 JDK 17 安装目录 |
| HOS_SDK_HOME | 未设置 | 建议指向 `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony` |
| 模型 API Key | 不写入仓库、日志或 `.env.local`，启动服务前通过当前进程环境变量注入 | 待注入 |
| 官方第三附件 | 作品说明文档 | 需登录茶思屋下载 |
| DevEco MCP | 已写入 `~/.workbuddy/mcp.json` | 需在连接器管理页面 Trust 启用 |

## 已知问题

1. **corepack shim 路径异常**：corepack 二进制 shim 路径前缀被错误拼接为 `c:\c\Users\...`，无法直接使用。已改用 `npm install -g pnpm` 安装 pnpm 11.9.0。
2. **pip 绑定 Python 3.10**：`pip` 命令解析到 Python 3.10 的 site-packages，而 `python` 为 3.13.12。如需 Python 3.13 的 pip，使用 `python -m pip`。
3. **JAVA_HOME 未设置**：`java` 可用但 `JAVA_HOME` 环境变量为空。DevEco Studio 通常自带 JRE，但建议设置 `JAVA_HOME` 指向 JDK 17 安装目录。

## DevEco Studio 安装后需配置的 PATH

DevEco Studio 安装完成后，将以下路径加入系统 PATH（路径以实际安装位置为准）：

```
<DevEco_Studio>\tools\ohpm\bin          # ohpm
<DevEco_Studio>\tools\hvigor\bin        # hvigor
<HarmonyOS_SDK>\toolchains              # hdc
```

## 模型 API

豆包 Ark 非密钥参数已配置：

- `MODEL_BASE_URL`: `https://ark.cn-beijing.volces.com/api/v3`
- `MODEL_NAME`: `doubao-seed-2-1-pro-260628`
- `MODEL_TIMEOUT_MS`: `60000`

`MODEL_API_KEY` 不写入仓库、日志或 `.env.local`。启动 Web 服务前只通过当前进程环境变量注入。

```powershell
$env:MODEL_API_KEY="<在本机手动填入>"
cd apps/web
pnpm dev
```

未设置 `MODEL_API_KEY` 时，Web 后端自动使用演示模式。
