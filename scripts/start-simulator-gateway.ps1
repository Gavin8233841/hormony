[Console]::InputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "simulator-api-gateway.mjs"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Simulator gateway script not found: $scriptPath"
}

Write-Output "Starting HongXueBan simulator API gateway: http://0.0.0.0:3001"
Write-Output "Target is fixed to production API. Request bodies and credentials are not logged. Press Ctrl+C to stop."
& node --use-env-proxy $scriptPath
