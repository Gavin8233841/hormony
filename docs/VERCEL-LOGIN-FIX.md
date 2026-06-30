# Vercel CLI 登录修复说明（Codex 必读）

> 创建时间：2026-07-01 01:30 CST
> 问题：Vercel CLI 在本机报 ByteString 错误，无法正常登录

## 根因

本机 Windows 计算机名为 `郭泳延的笔记本`（含中文字符）。Vercel CLI 登录时读取 `COMPUTERNAME` 等环境变量构建 HTTP 请求头，中文字符（Unicode 37101）无法转换为 ByteString（要求 0-255），导致 `TypeError` 崩溃。

这是 Vercel CLI 设备登录流程与本机中文主机名组合触发的兼容问题。仅覆盖环境变量仍不能稳定绕过，当前可靠路径是使用新建的 Access Token。

## 修复方案

在执行任何 `vercel` 命令前，必须先覆盖以下环境变量为 ASCII 值：

```powershell
$env:COMPUTERNAME = "DESKTOP-GUO82"
$env:USERDOMAIN = "DESKTOP-GUO82"
$env:LOGONSERVER = "\\DESKTOP-GUO82"
$env:USERDOMAIN_ROAMINGPROFILE = "DESKTOP-GUO82"
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null
```

## 平台实测状态

| 项目 | 值 |
|------|------|
| 团队 | `gwyy8233841` |
| 目标项目名 | `hongxueban-agent-api` |
| 部署目录 | `apps/web` |
| 框架 | Next.js（自动检测） |
| Vercel 插件项目列表 | 0 个项目（2026-07-01 01:25 CST 实测） |
| 历史 URL | 两个历史地址的 `/api/health` 均返回 404，不能作为可用部署 |
| Production URL | 待真实生产部署成功后记录 |

## Token 认证方式

Vercel CLI 未全局安装，通过 `npx vercel` 运行。使用 Token 跳过交互登录：

```powershell
npx vercel --token <在交互终端隐藏输入 Vercel Token>
```

> **安全要求**：旧 Token 曾被明文写入本文件，已脱敏但必须立即撤销。部署只能使用新 Token，并在交互窗口隐藏输入，不得再次写入文档、终端截图或 Git。

## 部署后待办

1. 在交互部署窗口添加环境变量：`MODEL_API_KEY`、`MODEL_BASE_URL`、`MODEL_NAME`、`MODEL_TIMEOUT_MS=45000`、`DEPLOYMENT_MODE=stateless`、`APP_STATE_PERSISTENCE=off`
2. 将 `Constants.ets` 的 `BASE_URL` 改为 Vercel 公网 URL
3. 验证 `/api/health`、`/api/chat`、`/api/plan`、`/api/quiz`、`/api/knowledge/search`
4. 后端无状态改造已完成，不得重新启用生产持久化或假 AI 回退
