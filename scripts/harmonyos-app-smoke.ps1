<#
.SYNOPSIS
  HarmonyOS App CLI 冒烟回归脚本
.DESCRIPTION
  使用 hvigorw + hdc + uitest 进行非破坏性 UI 回归验证。
  从 UI 树 bounds 计算点击中心，不写死坐标。
  不包含密钥、Token、代理地址。
  截图输出到带时间戳的新目录。
.PARAMETER SelfTest
  仅运行 UI 树、bounds 与错误边界离线自检；不连接设备、不构建、不创建截图目录。
.PARAMETER DeviceTarget
  多设备连接时，传入 `hdc list targets` 返回的一个精确目标值。
.NOTES
  要求：至少一个 HarmonyOS 设备或模拟器已连接。
  输出：UTF-8
#>

[CmdletBinding()]
param(
    [switch]$SelfTest,
    [string]$DeviceTarget = ""
)

[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot | Split-Path -Parent
$HARMONYOS_DIR = Join-Path $PROJECT_ROOT "apps\harmonyos"
$HDC = "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
$HVIGOR = Join-Path $HARMONYOS_DIR "hvigorw.bat"
$BUNDLE_NAME = "com.c4ai.hormony"
$HAP_PATH = Join-Path $HARMONYOS_DIR "entry\build\default\outputs\default\entry-default-unsigned.hap"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$SCREENSHOT_DIR = Join-Path $PROJECT_ROOT "screenshots\trae-smoke-$TIMESTAMP"

$script:passCount = 0
$script:failCount = 0
$script:results = @()
$script:activeDeviceTarget = ""

function Write-Step($step, $status, $detail = "") {
    $symbol = if ($status -eq "PASS") { "[PASS]" } elseif ($status -eq "FAIL") { "[FAIL]" } else { "[INFO]" }
    $line = "$symbol $step" + $(if ($detail) { " - $detail" } else { "" })
    [Console]::WriteLine($line)
    $script:results += $line
    if ($status -eq "PASS") { $script:passCount++ }
    elseif ($status -eq "FAIL") { $script:failCount++ }
}

function Convert-CommandOutput([object[]]$outputLines) {
    return (($outputLines | ForEach-Object { [string]$_ }) -join "`n").TrimEnd()
}

function Invoke-NativeCommand([string]$filePath, [string[]]$arguments) {
    $outputLines = & $filePath @arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = -1 }
    return [PSCustomObject]@{
        ExitCode = [int]$exitCode
        Output = Convert-CommandOutput $outputLines
    }
}

function Get-HdcArguments([string[]]$arguments, [switch]$withoutTarget) {
    $resolved = @()
    if (-not $withoutTarget) {
        if (-not $script:activeDeviceTarget) {
            throw "No exact HDC device target has been selected"
        }
        $resolved += @("-t", $script:activeDeviceTarget)
    }
    $resolved += $arguments
    return $resolved
}

function Invoke-Hdc([string[]]$arguments, [switch]$withoutTarget, [switch]$allowFailure) {
    $resolvedArguments = Get-HdcArguments -arguments $arguments -withoutTarget:$withoutTarget
    $result = Invoke-NativeCommand -filePath $HDC -arguments $resolvedArguments
    if ($result.ExitCode -ne 0 -and -not $allowFailure) {
        throw "hdc $($arguments -join ' ') failed with exit code $($result.ExitCode): $($result.Output)"
    }
    return $result
}

function Invoke-HdcShell([string[]]$arguments) {
    return (Invoke-Hdc -arguments (@("shell") + $arguments)).Output
}

function Get-DumpLayoutDevicePath([string]$dumpOutput) {
    if ($dumpOutput -cmatch '(?m)^\s*Wait for subscribe[^\r\n]*timeout\s*$') {
        throw "uitest dumpLayout reported a subscription timeout"
    }

    $pathMatches = [regex]::Matches(
        $dumpOutput,
        '(?m)^\s*DumpLayout saved to:\s*(?<path>/\S+)\s*$'
    )
    if ($pathMatches.Count -ne 1) {
        throw "uitest dumpLayout returned $($pathMatches.Count) device JSON paths: $dumpOutput"
    }
    return $pathMatches[0].Groups['path'].Value
}

function ConvertTo-UiTree([string]$json) {
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "UI tree JSON is empty"
    }

    try {
        $parsed = $json | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "UI tree JSON is invalid: $($_.Exception.Message)"
    }

    $roots = @($parsed)
    if ($roots.Count -ne 1 -or $null -eq $roots[0]) {
        throw "UI tree JSON must contain exactly one root node"
    }
    if ($null -eq $roots[0].PSObject.Properties['attributes']) {
        throw "UI tree root is missing attributes"
    }
    return $roots[0]
}

function Get-UiTree([int]$maxAttempts = 3) {
    $errors = @()
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $dumpOutput = Invoke-HdcShell -arguments @("uitest", "dumpLayout")
            $devicePath = Get-DumpLayoutDevicePath $dumpOutput
            $json = Invoke-HdcShell -arguments @("cat", $devicePath)
            return ConvertTo-UiTree $json
        } catch {
            $errors += "attempt $attempt/${maxAttempts}: $($_.Exception.Message)"
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Milliseconds 500
            }
        }
    }
    throw "Unable to obtain a current UI tree after $maxAttempts attempts: $($errors -join ' | ')"
}

function Test-UiNodeVisible($node) {
    if ($null -eq $node -or $null -eq $node.PSObject.Properties['attributes']) {
        return $false
    }
    $visibleProperty = $node.attributes.PSObject.Properties['visible']
    if ($null -eq $visibleProperty) { return $false }
    if ($visibleProperty.Value -is [bool]) { return $visibleProperty.Value }
    return ($visibleProperty.Value -is [string] -and $visibleProperty.Value -ceq 'true')
}

function Get-UiNodes($node) {
    if ($null -eq $node) { return }
    Write-Output $node
    if ($null -ne $node.PSObject.Properties['children'] -and $node.children) {
        foreach ($child in @($node.children)) {
            Get-UiNodes $child
        }
    }
}

function Find-ElementByText($uiTree, [string]$text) {
    return @(Get-UiNodes $uiTree | Where-Object {
        $null -ne $_.attributes.PSObject.Properties['text'] -and
        $_.attributes.text -ceq $text -and
        (Test-UiNodeVisible $_)
    })
}

function Get-PagePath($uiTree) {
    foreach ($node in @(Get-UiNodes $uiTree)) {
        if ($null -ne $node.attributes.PSObject.Properties['pagePath'] -and $node.attributes.pagePath) {
            return [string]$node.attributes.pagePath
        }
    }
    return $null
}

function ConvertTo-Coordinate([object]$value) {
    if ($value -is [int]) { return $value }
    $parsed = 0
    if ($null -ne $value -and [int]::TryParse([string]$value, [ref]$parsed)) {
        return $parsed
    }
    return $null
}

function Get-BoundsRectangle($bounds) {
    $left = $null
    $top = $null
    $right = $null
    $bottom = $null

    if ($bounds -is [string]) {
        $match = [regex]::Match(
            $bounds,
            '^\[\s*(?<left>\d+)\s*,\s*(?<top>\d+)\s*\]\[\s*(?<right>\d+)\s*,\s*(?<bottom>\d+)\s*\]$'
        )
        if (-not $match.Success) { return $null }
        $left = ConvertTo-Coordinate $match.Groups['left'].Value
        $top = ConvertTo-Coordinate $match.Groups['top'].Value
        $right = ConvertTo-Coordinate $match.Groups['right'].Value
        $bottom = ConvertTo-Coordinate $match.Groups['bottom'].Value
    } elseif ($null -ne $bounds) {
        $properties = $bounds.PSObject.Properties
        foreach ($propertyName in @('left', 'top')) {
            if ($null -eq $properties[$propertyName]) { return $null }
        }
        $left = ConvertTo-Coordinate $properties['left'].Value
        $top = ConvertTo-Coordinate $properties['top'].Value

        if ($null -ne $properties['right'] -and $null -ne $properties['bottom']) {
            $right = ConvertTo-Coordinate $properties['right'].Value
            $bottom = ConvertTo-Coordinate $properties['bottom'].Value
        } elseif ($null -ne $properties['width'] -and $null -ne $properties['height']) {
            $width = ConvertTo-Coordinate $properties['width'].Value
            $height = ConvertTo-Coordinate $properties['height'].Value
            if ($null -eq $width -or $null -eq $height) { return $null }
            $right = $left + $width
            $bottom = $top + $height
        } else {
            return $null
        }
    }

    if ($null -eq $left -or $null -eq $top -or $null -eq $right -or $null -eq $bottom) {
        return $null
    }
    if ($left -lt 0 -or $top -lt 0 -or $right -le $left -or $bottom -le $top) {
        return $null
    }

    return [PSCustomObject]@{
        Left = [int]$left
        Top = [int]$top
        Right = [int]$right
        Bottom = [int]$bottom
    }
}

function Get-BoundsCenter($bounds) {
    $rectangle = Get-BoundsRectangle $bounds
    if ($null -eq $rectangle) { return $null }
    return [PSCustomObject]@{
        X = [int][math]::Floor(($rectangle.Left + $rectangle.Right) / 2)
        Y = [int][math]::Floor(($rectangle.Top + $rectangle.Bottom) / 2)
        Rectangle = $rectangle
    }
}

function Click-Element(
    [string]$text,
    [string]$description,
    [int]$matchIndex = 0,
    [int]$maxAttempts = 6
) {
    $visibleCount = 0
    $boundedTargets = @()
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $uiTree = Get-UiTree
        $elements = @(Find-ElementByText $uiTree $text)
        $visibleCount = $elements.Count
        $boundedTargets = @(
            foreach ($element in $elements) {
                $center = Get-BoundsCenter $element.attributes.bounds
                if ($null -ne $center) {
                    [PSCustomObject]@{ Element = $element; Center = $center }
                }
            }
        )
        if ($matchIndex -ge 0 -and $matchIndex -lt $boundedTargets.Count) { break }
        if ($attempt -lt $maxAttempts) { Start-Sleep -Milliseconds 500 }
    }

    if ($matchIndex -lt 0 -or $matchIndex -ge $boundedTargets.Count) {
        Write-Step "Click: $description" "FAIL" (
            "exactText=$text visibleMatches=$visibleCount boundedMatches=$($boundedTargets.Count) matchIndex=$matchIndex"
        )
        return $false
    }

    $target = $boundedTargets[$matchIndex]
    $x = [string]$target.Center.X
    $y = [string]$target.Center.Y
    Invoke-HdcShell -arguments @("uitest", "uiInput", "click", $x, $y) | Out-Null
    Start-Sleep -Milliseconds 500
    $rectangle = $target.Center.Rectangle
    Write-Step "Click: $description" "PASS" (
        "exactText=$text match=$($matchIndex + 1)/$($boundedTargets.Count) " +
        "bounds=[$($rectangle.Left),$($rectangle.Top)][$($rectangle.Right),$($rectangle.Bottom)] center=($x,$y)"
    )
    return $true
}

function Take-Screenshot($name) {
    $devicePath = "/data/local/tmp/smoke_screenshot.jpeg"
    Invoke-HdcShell -arguments @("snapshot_display", "-f", $devicePath) | Out-Null
    $localPath = Join-Path $SCREENSHOT_DIR "$name.jpeg"
    $receiveResult = Invoke-Hdc -arguments @("file", "recv", $devicePath, $localPath) -allowFailure
    if ($receiveResult.ExitCode -eq 0 -and (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        Write-Step "Screenshot: $name" "PASS" $localPath
    } else {
        Write-Step "Screenshot: $name" "FAIL" "exit=$($receiveResult.ExitCode) output=$($receiveResult.Output)"
        exit 1
    }
}

function Verify-Page($pagePath, $description, [int]$maxAttempts = 8) {
    $actual = $null
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $actual = Get-PagePath (Get-UiTree)
        if ($actual -ceq $pagePath) { break }
        if ($attempt -lt $maxAttempts) { Start-Sleep -Milliseconds 500 }
    }
    if ($actual -cne $pagePath) {
        Write-Step "Page: $description" "FAIL" "expected=$pagePath actual=$actual"
        return $false
    }
    Write-Step "Page: $description" "PASS" $actual
    return $true
}

function Click-FirstOptionA() {
    return Click-Element 'A' 'Choose option A'
}

function Swipe-Viewport($direction) {
    $uiTree = Get-UiTree
    $rectangle = Get-BoundsRectangle $uiTree.attributes.bounds
    if ($null -eq $rectangle) {
        Write-Step "Swipe: $direction" "FAIL" "Invalid root bounds"
        return $false
    }
    if ($direction -cne 'up' -and $direction -cne 'down') {
        Write-Step "Swipe: $direction" "FAIL" "Direction must be up or down"
        return $false
    }
    $x = [int][math]::Floor(($rectangle.Left + $rectangle.Right) / 2)
    $top = $rectangle.Top
    $bottom = $rectangle.Bottom
    $fromY = if ($direction -eq 'up') { [math]::Round($top + ($bottom - $top) * 0.75) } else {
        [math]::Round($top + ($bottom - $top) * 0.35)
    }
    $toY = if ($direction -eq 'up') { [math]::Round($top + ($bottom - $top) * 0.35) } else {
        [math]::Round($top + ($bottom - $top) * 0.75)
    }
    Invoke-HdcShell -arguments @(
        "uitest", "uiInput", "swipe", [string]$x, [string]$fromY, [string]$x, [string]$toY, "600"
    ) | Out-Null
    Start-Sleep -Milliseconds 700
    Write-Step "Swipe: $direction" "PASS" "root=$($uiTree.attributes.bounds)"
    return $true
}

function Verify-TextExists($text, $description, [int]$maxAttempts = 8) {
    $elements = @()
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $elements = @(Find-ElementByText (Get-UiTree) $text)
        if ($elements.Count -gt 0) { break }
        if ($attempt -lt $maxAttempts) { Start-Sleep -Milliseconds 500 }
    }
    if ($elements.Count -gt 0) {
        Write-Step "Verify: $description" "PASS" "Found exact text: $text"
        return $true
    } else {
        Write-Step "Verify: $description" "FAIL" "Exact text not found: $text"
        return $false
    }
}

function Assert-SelfTest([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

function Assert-SelfTestThrows([scriptblock]$action, [string]$messagePattern) {
    $caught = $null
    try {
        & $action | Out-Null
    } catch {
        $caught = $_.Exception.Message
    }
    if ($null -eq $caught) { throw "Expected an exception matching: $messagePattern" }
    if ($caught -notmatch $messagePattern) {
        throw "Exception did not match '$messagePattern': $caught"
    }
}

function Invoke-SelfTest() {
    $tests = @(
        @{
            Name = 'string bounds center'
            Run = {
                $center = Get-BoundsCenter '[0,0][101,201]'
                Assert-SelfTest ($center.X -eq 50 -and $center.Y -eq 100) 'Unexpected string bounds center'
            }
        },
        @{
            Name = 'edge object bounds center'
            Run = {
                $center = Get-BoundsCenter ([PSCustomObject]@{ left = 10; top = 20; right = 30; bottom = 50 })
                Assert-SelfTest ($center.X -eq 20 -and $center.Y -eq 35) 'Unexpected edge object center'
            }
        },
        @{
            Name = 'size object bounds center'
            Run = {
                $center = Get-BoundsCenter ([PSCustomObject]@{ left = 10; top = 20; width = 30; height = 50 })
                Assert-SelfTest ($center.X -eq 25 -and $center.Y -eq 45) 'Unexpected size object center'
            }
        },
        @{
            Name = 'invalid bounds rejected'
            Run = {
                Assert-SelfTest ($null -eq (Get-BoundsCenter '[20,10][10,30]')) 'Reversed bounds were accepted'
                Assert-SelfTest ($null -eq (Get-BoundsCenter '[0,0][10,10] trailing')) 'Trailing bounds text was accepted'
                Assert-SelfTest ($null -eq (Get-BoundsCenter ([PSCustomObject]@{ left = 0; top = 0; width = 0; height = 10 }))) 'Empty bounds were accepted'
            }
        },
        @{
            Name = 'dumpLayout path parsed'
            Run = {
                $output = "notice`nDumpLayout saved to:/data/local/tmp/layout.json"
                Assert-SelfTest ((Get-DumpLayoutDevicePath $output) -ceq '/data/local/tmp/layout.json') 'Wrong dumpLayout path'
            }
        },
        @{
            Name = 'dumpLayout timeout rejected'
            Run = {
                Assert-SelfTestThrows { Get-DumpLayoutDevicePath 'Wait for subscribe layout timeout' } 'subscription timeout'
            }
        },
        @{
            Name = 'UI tree exact visible text search'
            Run = {
                $tree = [PSCustomObject]@{
                    attributes = [PSCustomObject]@{ visible = 'true'; pagePath = 'pages/Index'; bounds = '[0,0][100,200]' }
                    children = @(
                        [PSCustomObject]@{ attributes = [PSCustomObject]@{ visible = 'true'; text = '课程'; bounds = '[0,100][50,200]' }; children = @() },
                        [PSCustomObject]@{ attributes = [PSCustomObject]@{ visible = 'true'; text = '课程列表'; bounds = '[50,100][100,200]' }; children = @() },
                        [PSCustomObject]@{ attributes = [PSCustomObject]@{ visible = 'false'; text = '课程'; bounds = '[0,0][10,10]' }; children = @() }
                    )
                }
                $matches = @(Find-ElementByText $tree '课程')
                Assert-SelfTest ($matches.Count -eq 1) 'Exact visible text search returned the wrong count'
                Assert-SelfTest ((Get-PagePath $tree) -ceq 'pages/Index') 'Page path was not found'
            }
        },
        @{
            Name = 'UI tree JSON boundary validation'
            Run = {
                Assert-SelfTestThrows { ConvertTo-UiTree '{"children":[]}' } 'missing attributes'
                Assert-SelfTestThrows { ConvertTo-UiTree '{broken' } 'UI tree JSON is invalid'
            }
        },
        @{
            Name = 'HDC device target arguments'
            Run = {
                $previousTarget = $script:activeDeviceTarget
                try {
                    $script:activeDeviceTarget = '127.0.0.1:5555'
                    $arguments = @(Get-HdcArguments -arguments @('shell', 'uitest', 'dumpLayout'))
                    Assert-SelfTest ($arguments.Count -eq 5) 'Unexpected targeted HDC argument count'
                    Assert-SelfTest (
                        $arguments[0] -ceq '-t' -and
                        $arguments[1] -ceq '127.0.0.1:5555' -and
                        $arguments[2] -ceq 'shell' -and
                        $arguments[3] -ceq 'uitest' -and
                        $arguments[4] -ceq 'dumpLayout'
                    ) 'HDC arguments did not preserve the exact device target'
                } finally {
                    $script:activeDeviceTarget = $previousTarget
                }
            }
        }
    )

    $failed = 0
    foreach ($test in $tests) {
        try {
            & $test.Run
            [Console]::WriteLine("[PASS] Self-test: $($test.Name)")
        } catch {
            $failed++
            [Console]::WriteLine("[FAIL] Self-test: $($test.Name) - $($_.Exception.Message)")
        }
    }
    [Console]::WriteLine("Self-test summary: $($tests.Count - $failed) passed, $failed failed")
    if ($failed -gt 0) { return 1 }
    return 0
}

function Select-DeviceTarget() {
    $targetResult = Invoke-Hdc -arguments @('list', 'targets') -withoutTarget
    $rawTargets = @(
        $targetResult.Output -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
    if ($rawTargets.Count -eq 0 -or ($rawTargets.Count -eq 1 -and $rawTargets[0] -ceq '[Empty]')) {
        throw "No HDC device is connected"
    }

    if ($DeviceTarget) {
        if (-not ($rawTargets -ccontains $DeviceTarget)) {
            throw "Requested HDC target '$DeviceTarget' is not connected. Connected targets: $($rawTargets -join ', ')"
        }
        $script:activeDeviceTarget = $DeviceTarget
    } elseif ($rawTargets.Count -eq 1) {
        $script:activeDeviceTarget = $rawTargets[0]
    } else {
        throw "Multiple HDC devices are connected; rerun with -DeviceTarget using one exact value: $($rawTargets -join ', ')"
    }
}

if ($SelfTest) {
    exit (Invoke-SelfTest)
}

# ==================== 主流程 ====================

trap {
    Write-Step "Smoke test" "FAIL" $_.Exception.Message
    Write-Output "`n=== SUMMARY: $script:passCount passed, $script:failCount failed ==="
    exit 1
}

foreach ($requiredFile in @($HDC, $HVIGOR)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required executable does not exist: $requiredFile"
    }
}

Write-Output "[INFO] Checking device connection..."
Select-DeviceTarget
Write-Step "Device connection" "PASS" $script:activeDeviceTarget

Write-Output "========================================"
Write-Output "HarmonyOS App Smoke Test"
Write-Output "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Device target: $script:activeDeviceTarget"
Write-Output "Screenshot dir: $SCREENSHOT_DIR"
Write-Output "========================================"
Write-Output ""

# 1. 构建增量 HAP（不 clean）
Write-Output "`n[INFO] Building HAP (incremental, no clean)..."
Push-Location $HARMONYOS_DIR
try {
    $buildResult = Invoke-NativeCommand -filePath $HVIGOR -arguments @('assembleHap', '--no-daemon')
} finally {
    Pop-Location
}
$buildTail = (($buildResult.Output -split "`r?`n") | Select-Object -Last 3) -join ' '
if ($buildResult.ExitCode -eq 0) {
    Write-Step "HAP build" "PASS" "exit=$($buildResult.ExitCode), $buildTail"
} else {
    Write-Step "HAP build" "FAIL" "exit=$($buildResult.ExitCode), $buildTail"
    Write-Output "`n=== SUMMARY: $script:passCount passed, $script:failCount failed ==="
    exit 1
}

# 2. 安装 HAP
Write-Output "`n[INFO] Installing HAP..."
if (-not (Test-Path -LiteralPath $HAP_PATH -PathType Leaf)) {
    Write-Step "HAP install" "FAIL" "Expected build output does not exist: $HAP_PATH"
    exit 1
}
$installResult = Invoke-Hdc -arguments @('install', $HAP_PATH) -allowFailure
if ($installResult.ExitCode -eq 0 -and $installResult.Output -cmatch 'install bundle successfully') {
    Write-Step "HAP install" "PASS" (Split-Path -Leaf $HAP_PATH)
} else {
    Write-Step "HAP install" "FAIL" "exit=$($installResult.ExitCode) output=$($installResult.Output)"
    exit 1
}

# 3. 启动 App
Write-Output "`n[INFO] Starting app..."
$startOutput = Invoke-HdcShell -arguments @("aa", "start", "-a", "EntryAbility", "-b", $BUNDLE_NAME)
if ($startOutput -cnotmatch 'start ability successfully') {
    Write-Step "App start" "FAIL" $startOutput
    exit 1
}
Write-Step "App start" "PASS" "$BUNDLE_NAME/EntryAbility"
Start-Sleep -Seconds 3
for ($attempt = 0; $attempt -lt 8; $attempt++) {
    if ((Get-PagePath (Get-UiTree)) -eq 'pages/Index') { break }
    Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
    Start-Sleep -Milliseconds 500
}
if (-not (Verify-Page "pages/Index" "Root")) { exit 1 }
if (Test-Path -LiteralPath $SCREENSHOT_DIR) {
    throw "Refusing to overwrite an existing screenshot directory: $SCREENSHOT_DIR"
}
New-Item -ItemType Directory -Path $SCREENSHOT_DIR | Out-Null
Take-Screenshot "01-launch"

# 4. 验证首页 Tab (今日)
Write-Output "`n[INFO] Verifying Home tab..."
if (-not (Verify-TextExists "今日" "Home tab")) { exit 1 }

# 5. 点击"课程" Tab
Write-Output "`n[INFO] Navigating to Course tab..."
if (-not (Click-Element "课程" "Course tab")) { exit 1 }
Start-Sleep -Seconds 2
Take-Screenshot "02-course-tab"

# 6. 验证课程列表
Write-Output "`n[INFO] Verifying course list..."
foreach ($courseName in @("数据结构", "操作系统", "计算机网络")) {
    if (-not (Verify-TextExists $courseName "Course list: $courseName")) { exit 1 }
}

# 7. 进入课程详情与精选练习
Write-Output "`n[INFO] Entering course detail and practice..."
if (-not (Click-Element "进入课程" "First course")) { exit 1 }
if (-not (Verify-Page "pages/CourseDetail" "Course detail")) { exit 1 }
if (-not (Verify-TextExists "真实学习进度" "Course detail content")) { exit 1 }
Take-Screenshot "03-course-detail"
if (-not (Click-Element "精选练习" "Curated practice")) { exit 1 }
if (-not (Verify-Page "pages/Practice" "Practice")) { exit 1 }
if (-not (Verify-TextExists "离线精选题库" "Practice question")) { exit 1 }
Take-Screenshot "04-practice"

# 8. 完成五题并进入逐题复盘
for ($questionIndex = 0; $questionIndex -lt 5; $questionIndex++) {
    if (-not (Click-FirstOptionA)) { exit 1 }
    if ($questionIndex -lt 4) {
        if (-not (Click-Element "下一题" "Next question")) { exit 1 }
    } else {
        if (-not (Click-Element "提交评分" "Submit practice")) { exit 1 }
    }
}
if (-not (Verify-TextExists "本轮已完成" "Practice result")) { exit 1 }
if (-not (Verify-TextExists "逐题复盘" "Question review")) { exit 1 }
Take-Screenshot "05-practice-result"

# 9. 从错题解析进入真实学伴，再返回主框架
if (-not (Click-Element "向学伴追问" "Ask tutor from review")) { exit 1 }
if (-not (Verify-Page "pages/Chat" "Tutor follow-up")) { exit 1 }
Take-Screenshot "06-review-chat"
Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
Start-Sleep -Milliseconds 500
Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
Start-Sleep -Milliseconds 500
Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
Start-Sleep -Milliseconds 500
if (-not (Verify-Page "pages/Index" "Root after practice")) { exit 1 }

# 13. 点击"学伴" Tab
Write-Output "`n[INFO] Navigating to Chat tab..."
if (-not (Click-Element "学伴" "Chat tab")) { exit 1 }
Start-Sleep -Seconds 2
Take-Screenshot "07-chat-tab"

# 14. 验证 AI 学伴页面
if (-not (Verify-TextExists "基于课程资料，为每个问题给出依据" "Chat status area")) { exit 1 }

# 15. 点击"我的" Tab
Write-Output "`n[INFO] Navigating to Profile tab..."
if (-not (Click-Element "我的" "Profile tab")) { exit 1 }
Start-Sleep -Seconds 2
Take-Screenshot "08-profile-tab"
if (-not (Swipe-Viewport "up")) { exit 1 }
if (-not (Verify-TextExists "连续天数" "Learning streak")) { exit 1 }
if (-not (Swipe-Viewport "down")) { exit 1 }

# 16. 验证三个 Profile 子页面
foreach ($profilePage in @(
    @{ Text = '学习记录'; Path = 'pages/ActivityRecords'; Shot = '09-activity-records' },
    @{ Text = '错题本'; Path = 'pages/MistakeBook'; Shot = '10-mistake-book' },
    @{ Text = '成就'; Path = 'pages/Achievements'; Shot = '11-achievements' }
)) {
    if (-not (Click-Element $profilePage.Text $profilePage.Text)) { exit 1 }
    if (-not (Verify-Page $profilePage.Path $profilePage.Text)) { exit 1 }
    if (-not (Verify-TextExists $profilePage.Text $profilePage.Text)) { exit 1 }
    Take-Screenshot $profilePage.Shot
    Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
    Start-Sleep -Milliseconds 500
}

# 17. 验证学习星图三门课程
if (-not (Click-Element "学习星图" "Learning map")) { exit 1 }
if (-not (Verify-Page "pages/LearningMap" "Learning map")) { exit 1 }
$mapIndex = 12
foreach ($courseName in @('数据结构', '操作系统', '计算机网络')) {
    if (-not (Click-Element $courseName "Learning map: $courseName")) { exit 1 }
    if (-not (Verify-TextExists "Level 0" "Learning map graph level")) { exit 1 }
    Take-Screenshot (("{0:D2}-learning-map-{1}" -f $mapIndex, $courseName))
    $mapIndex++
}
Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
Start-Sleep -Milliseconds 500
if (-not (Verify-Page "pages/Index" "Root after profile")) { exit 1 }

# 18. 回到首页
Write-Output "`n[INFO] Returning to Home tab..."
if (-not (Click-Element "今日" "Home tab")) { exit 1 }
Start-Sleep -Seconds 1
Take-Screenshot "15-home-return"

# ==================== 汇总 ====================
Write-Output ""
Write-Output "========================================"
Write-Output "SUMMARY"
Write-Output "========================================"
Write-Output "Passed: $script:passCount"
Write-Output "Failed: $script:failCount"
Write-Output "Screenshots: $SCREENSHOT_DIR"
Write-Output "========================================"

if ($script:failCount -gt 0) {
    exit 1
} else {
    exit 0
}
