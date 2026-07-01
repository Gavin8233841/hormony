[Console]::InputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "simulator-api-gateway.mjs"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "模拟器网关脚本不存在：$scriptPath"
}

Write-Output "启动鸿学伴模拟器 API 网关：http://0.0.0.0:3001"
Write-Output "目标固定为生产 API；请求正文和凭证不会写入日志。按 Ctrl+C 停止。"
& node --use-env-proxy $scriptPath
