<#
.SYNOPSIS
  HarmonyOS App CLI 冒烟回归脚本
.DESCRIPTION
  使用 hvigorw + hdc + uitest 进行非破坏性 UI 回归验证。
  从 UI 树 bounds 计算点击中心，不写死坐标。
  不包含密钥、Token、代理地址。
  截图输出到带时间戳的新目录。
.NOTES
  要求：Pura 90 Pro Max 模拟器已连接。
  输出：UTF-8
#>

[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot | Split-Path -Parent
$HARMONYOS_DIR = Join-Path $PROJECT_ROOT "apps\harmonyos"
$HDC = "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
$HVIGOR = Join-Path $HARMONYOS_DIR "hvigorw.bat"
$BUNDLE_NAME = "com.c4ai.hormony"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$SCREENSHOT_DIR = Join-Path $PROJECT_ROOT "screenshots\trae-smoke-$TIMESTAMP"

if (-not (Test-Path $SCREENSHOT_DIR)) {
    New-Item -ItemType Directory -Path $SCREENSHOT_DIR -Force | Out-Null
}

$script:passCount = 0
$script:failCount = 0
$script:results = @()

function Write-Step($step, $status, $detail = "") {
    $symbol = if ($status -eq "PASS") { "[PASS]" } elseif ($status -eq "FAIL") { "[FAIL]" } else { "[INFO]" }
    $line = "$symbol $step" + $(if ($detail) { " - $detail" } else { "" })
    [Console]::WriteLine($line)
    $script:results += $line
    if ($status -eq "PASS") { $script:passCount++ }
    elseif ($status -eq "FAIL") { $script:failCount++ }
}

function Invoke-HdcShell([string[]]$arguments) {
    $result = & $HDC shell @arguments 2>&1
    return ($result -join "`n")
}

function Get-UiTree() {
    $dumpResult = ""
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $dumpResult = Invoke-HdcShell @("uitest", "dumpLayout")
        if ($dumpResult -match 'DumpLayout saved to:(\S+)') {
            $json = Invoke-HdcShell @("cat", $Matches[1])
            return $json | ConvertFrom-Json
        }
        Start-Sleep -Milliseconds 750
    }
    throw "dumpLayout did not return a device JSON path: $dumpResult"
}

function Find-ElementByText($uiTree, $text) {
    function Search-Node($node, $exactText) {
        $results = @()
        if ($node.attributes.text -eq $exactText -and $node.attributes.visible -eq 'true') {
            $results += $node
        }
        if ($node.children) {
            foreach ($child in $node.children) {
                $results += Search-Node $child $exactText
            }
        }
        return $results
    }
    return Search-Node $uiTree $text
}

function Find-OptionA($uiTree) {
    function Search-Node($node) {
        $results = @()
        if ($node.attributes.text -eq 'A' -and $node.attributes.visible -eq 'true') {
            $results += $node
        }
        if ($node.children) {
            foreach ($child in $node.children) { $results += Search-Node $child }
        }
        return $results
    }
    return Search-Node $uiTree
}

function Get-PagePath($uiTree) {
    function Search-Node($node) {
        if ($node.attributes.pagePath) { return $node.attributes.pagePath }
        if ($node.children) {
            foreach ($child in $node.children) {
                $path = Search-Node $child
                if ($path) { return $path }
            }
        }
        return $null
    }
    return Search-Node $uiTree
}

function Get-BoundsCenter($bounds) {
    # bounds format: "[x1,y1][x2,y2]" or {left, top, right, bottom}
    if ($bounds -is [string]) {
        if ($bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
            $x1 = [int]$Matches[1]; $y1 = [int]$Matches[2]
            $x2 = [int]$Matches[3]; $y2 = [int]$Matches[4]
            $cx = [math]::Round(($x1 + $x2) / 2)
            $cy = [math]::Round(($y1 + $y2) / 2)
            return "$cx $cy"
        }
    } elseif ($bounds -is [object]) {
        if ($bounds.left -ne $null) {
            $cx = [math]::Round(($bounds.left + $bounds.right) / 2)
            $cy = [math]::Round(($bounds.top + $bounds.bottom) / 2)
            return "$cx $cy"
        }
    }
    return $null
}

function Click-Element($textPattern, $description) {
    $uiTree = Get-UiTree
    if (-not $uiTree) {
        Write-Step "Click: $description" "FAIL" "UI tree not available"
        return $false
    }
    $elements = Find-ElementByText $uiTree $textPattern
    if ($elements.Count -eq 0) {
        Write-Step "Click: $description" "FAIL" "Element not found: $textPattern"
        return $false
    }
    $target = $elements[0]
    $center = Get-BoundsCenter $target.attributes.bounds
    if (-not $center) {
        Write-Step "Click: $description" "FAIL" "Cannot parse bounds: $($target.attributes.bounds)"
        return $false
    }
    $parts = $center -split ' '
    $cx = $parts[0]; $cy = $parts[1]
    Invoke-HdcShell @("uitest", "uiInput", "click", $cx, $cy) | Out-Null
    Start-Sleep -Seconds 1
    Write-Step "Click: $description" "PASS" "at ($cx, $cy)"
    return $true
}

function Try-ClickElement($textPattern, $description) {
    $uiTree = Get-UiTree
    if (-not $uiTree) { return $false }
    $elements = Find-ElementByText $uiTree $textPattern
    if ($elements.Count -eq 0) { return $false }
    $center = Get-BoundsCenter $elements[0].attributes.bounds
    if (-not $center) { return $false }
    $parts = $center -split ' '
    Invoke-HdcShell @("uitest", "uiInput", "click", $parts[0], $parts[1]) | Out-Null
    Start-Sleep -Seconds 1
    Write-Step "Click: $description" "PASS" "at ($($parts[0]), $($parts[1]))"
    return $true
}

function Take-Screenshot($name) {
    $devicePath = "/data/local/tmp/smoke_screenshot.jpeg"
    Invoke-HdcShell @("snapshot_display", "-f", $devicePath) | Out-Null
    $localPath = Join-Path $SCREENSHOT_DIR "$name.jpeg"
    & $HDC file recv $devicePath $localPath 2>&1 | Out-Null
    if (Test-Path $localPath) {
        Write-Step "Screenshot: $name" "PASS" $localPath
    } else {
        Write-Step "Screenshot: $name" "FAIL" "File not received"
        exit 1
    }
}

function Verify-Page($pagePath, $description) {
    $actual = ""
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        $actual = Get-PagePath (Get-UiTree)
        if ($actual -eq $pagePath) {
            Write-Step "Page: $description" "PASS" $actual
            return $true
        }
        Start-Sleep -Milliseconds 750
    }
    Write-Step "Page: $description" "FAIL" "expected=$pagePath actual=$actual"
    return $false
}

function Click-FirstOptionA() {
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $uiTree = Get-UiTree
        $elements = Find-OptionA $uiTree
        if ($elements.Count -gt 0) {
            $center = Get-BoundsCenter $elements[0].attributes.bounds
            if (-not $center) {
                Write-Step "Choose option A" "FAIL" "Invalid bounds"
                return $false
            }
            $parts = $center -split ' '
            Invoke-HdcShell @("uitest", "uiInput", "click", $parts[0], $parts[1]) | Out-Null
            Start-Sleep -Milliseconds 500
            Write-Step "Choose option A" "PASS" "$($elements[0].attributes.text) attempt=$attempt"
            return $true
        }
        if ($attempt -eq 0) {
            if (-not (Swipe-Viewport "down")) { return $false }
        } elseif ($attempt -eq 1) {
            if (-not (Swipe-Viewport "up")) { return $false }
        }
    }
    Write-Step "Choose option A" "FAIL" "No visible A. option"
    return $false
}

function Swipe-Viewport($direction) {
    $uiTree = Get-UiTree
    $center = Get-BoundsCenter $uiTree.attributes.bounds
    if (-not $center -or $uiTree.attributes.bounds -notmatch '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
        Write-Step "Swipe: $direction" "FAIL" "Invalid root bounds"
        return $false
    }
    $x = [math]::Round(([int]$Matches[1] + [int]$Matches[3]) / 2)
    $top = [int]$Matches[2]
    $bottom = [int]$Matches[4]
    $fromY = if ($direction -eq 'up') { [math]::Round($top + ($bottom - $top) * 0.75) } else {
        [math]::Round($top + ($bottom - $top) * 0.35)
    }
    $toY = if ($direction -eq 'up') { [math]::Round($top + ($bottom - $top) * 0.35) } else {
        [math]::Round($top + ($bottom - $top) * 0.75)
    }
    Invoke-HdcShell @("uitest", "uiInput", "swipe", $x, $fromY, $x, $toY, "600") | Out-Null
    Start-Sleep -Milliseconds 700
    Write-Step "Swipe: $direction" "PASS" "root=$($uiTree.attributes.bounds)"
    return $true
}

function Verify-TextExists($textPattern, $description) {
    $uiTree = Get-UiTree
    if (-not $uiTree) {
        Write-Step "Verify: $description" "FAIL" "UI tree not available"
        return $false
    }
    $elements = Find-ElementByText $uiTree $textPattern
    if ($elements.Count -gt 0) {
        Write-Step "Verify: $description" "PASS" "Found: $textPattern"
        return $true
    } else {
        Write-Step "Verify: $description" "FAIL" "Not found: $textPattern"
        return $false
    }
}

function Verify-TextExistsWithScroll($textPattern, $description, $maxSwipes = 2) {
    for ($attempt = 0; $attempt -le $maxSwipes; $attempt++) {
        $uiTree = Get-UiTree
        if ($uiTree) {
            $elements = Find-ElementByText $uiTree $textPattern
            if ($elements.Count -gt 0) {
                Write-Step "Verify: $description" "PASS" "Found: $textPattern attempt=$attempt"
                return $true
            }
        }
        if ($attempt -lt $maxSwipes) {
            if (-not (Swipe-Viewport "up")) { return $false }
        }
    }
    Write-Step "Verify: $description" "FAIL" "Not found after scroll: $textPattern"
    return $false
}

function Test-TextVisible($textPattern) {
    try {
        $uiTree = Get-UiTree
        if (-not $uiTree) { return $false }
        $elements = Find-ElementByText $uiTree $textPattern
        return $elements.Count -gt 0
    } catch {
        return $false
    }
}

function Wait-TextVisible($textPattern, $attempts = 8, $sleepMs = 500) {
    for ($attempt = 0; $attempt -lt $attempts; $attempt++) {
        if (Test-TextVisible $textPattern) { return $true }
        Start-Sleep -Milliseconds $sleepMs
    }
    return $false
}

function Click-And-WaitText($buttonText, $expectedText, $description) {
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        if (Try-ClickElement $buttonText "$description attempt=$attempt") {
            if (Wait-TextVisible $expectedText 6 500) {
                Write-Step $description "PASS" "Reached $expectedText"
                return $true
            }
        }
        if ($attempt -eq 0) {
            Swipe-Viewport "up" | Out-Null
        } elseif ($attempt -eq 1) {
            Swipe-Viewport "down" | Out-Null
        }
    }
    Write-Step $description "FAIL" "Expected after click: $expectedText"
    return $false
}

# ==================== 主流程 ====================

Write-Output "========================================"
Write-Output "HarmonyOS App Smoke Test"
Write-Output "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Screenshot dir: $SCREENSHOT_DIR"
Write-Output "========================================"
Write-Output ""

# 0. 检查设备连接
Write-Output "[INFO] Checking device connection..."
$deviceList = & $HDC list targets 2>&1
if ($deviceList -match "No device" -or $deviceList -match "Empty") {
    Write-Step "Device connection" "FAIL" "No device found"
    Write-Output "`n=== SUMMARY: $script:passCount passed, $script:failCount failed ==="
    exit 1
}
Write-Step "Device connection" "PASS" $deviceList.Trim()

# 1. 构建增量 HAP（不 clean）
Write-Output "`n[INFO] Building HAP (incremental, no clean)..."
Push-Location $HARMONYOS_DIR
$buildResult = & $HVIGOR assembleHap --no-daemon 2>&1
$buildExit = $LASTEXITCODE
Pop-Location
$buildTail = ($buildResult | Select-Object -Last 3) -join ' '
if ($buildExit -eq 0) {
    Write-Step "HAP build" "PASS" "exit=$buildExit, $buildTail"
} else {
    Write-Step "HAP build" "FAIL" "exit=$buildExit, $buildTail"
    Write-Output "`n=== SUMMARY: $script:passCount passed, $script:failCount failed ==="
    exit 1
}

# 2. 安装 HAP
Write-Output "`n[INFO] Installing HAP..."
$hapDirectory = Join-Path $HARMONYOS_DIR "entry\build\default\outputs\default"
$hapFiles = Get-ChildItem -LiteralPath $hapDirectory -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.hap' } |
    Sort-Object LastWriteTime -Descending
if (-not $hapFiles) {
    Write-Step "HAP install" "FAIL" "No HAP file found"
    exit 1
}
$hapPath = $hapFiles[0].FullName
$installResult = & $HDC install "$hapPath" 2>&1
$installExit = $LASTEXITCODE
if ($installExit -eq 0 -and (($installResult -join "`n") -match "success")) {
    Write-Step "HAP install" "PASS" $hapFiles[0].Name
} else {
    Write-Step "HAP install" "FAIL" "exit=$installExit output=$($installResult -join ' ')"
    exit 1
}

# 3. 启动 App
Write-Output "`n[INFO] Starting app..."
Invoke-HdcShell @("aa", "start", "-a", "EntryAbility", "-b", $BUNDLE_NAME) | Out-Null
Start-Sleep -Seconds 3
for ($attempt = 0; $attempt -lt 10; $attempt++) {
    $currentPage = Get-PagePath (Get-UiTree)
    if ($currentPage -eq 'pages/Index') { break }
    if ($currentPage) {
        Invoke-HdcShell @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
    }
    Start-Sleep -Milliseconds 500
}
Take-Screenshot "01-launch"
if (-not (Verify-Page "pages/Index" "Root")) { exit 1 }

# 4. 验证首页 Tab (今日)
Write-Output "`n[INFO] Verifying Home tab..."
$uiTree = Get-UiTree
if ($uiTree) {
    $todayElements = Find-ElementByText $uiTree "今日"
    if ($todayElements.Count -gt 0) {
        Write-Step "Home tab (今日)" "PASS" "Found 今日 tab"
    } else {
        Write-Step "Home tab (今日)" "FAIL" "今日 tab not found"
    }
} else {
    Write-Step "Home tab (今日)" "FAIL" "UI tree unavailable"
}

# 5. 点击"课程" Tab
Write-Output "`n[INFO] Navigating to Course tab..."
Click-Element "课程" "Course tab" | Out-Null
Start-Sleep -Seconds 2
Take-Screenshot "02-course-tab"

# 6. 验证课程列表
Write-Output "`n[INFO] Verifying course list..."
$uiTree = Get-UiTree
if ($uiTree) {
    # Look for course names (数据结构, 操作系统, 计算机网络)
    $courseFound = $false
    foreach ($courseName in @("数据结构", "操作系统", "计算机网络")) {
        $elements = Find-ElementByText $uiTree $courseName
        if ($elements.Count -gt 0) {
            Write-Step "Course list: $courseName" "PASS" "Found"
            $courseFound = $true
        }
    }
    if (-not $courseFound) {
        Write-Step "Course list" "FAIL" "No course names found"
    }
} else {
    Write-Step "Course list" "FAIL" "UI tree unavailable"
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

# 8. 完成练习并进入逐题复盘
$practiceQuestionCount = 5
for ($questionIndex = 0; $questionIndex -lt $practiceQuestionCount; $questionIndex++) {
    $currentProgressText = "$($questionIndex + 1) / $practiceQuestionCount"
    if (-not (Wait-TextVisible $currentProgressText 6 500)) {
        Write-Step "Practice progress" "FAIL" "Expected $currentProgressText"
        exit 1
    }
    if (-not (Click-FirstOptionA)) { exit 1 }
    if ($questionIndex -lt ($practiceQuestionCount - 1)) {
        $nextProgressText = "$($questionIndex + 2) / $practiceQuestionCount"
        if (-not (Click-And-WaitText "下一题" $nextProgressText "Next practice question")) { exit 1 }
    } else {
        if (-not (Click-And-WaitText "提交评分" "本轮已完成" "Submit practice")) { exit 1 }
    }
}
if (-not (Verify-TextExists "本轮闭环" "Practice learning loop")) { exit 1 }
if (-not (Verify-TextExists "逐题复盘" "Question review")) { exit 1 }
Take-Screenshot "05-practice-result"

# 9. 从错题解析进入真实学伴，再返回主框架
if (-not (Click-Element "让学伴讲这题" "Ask tutor from loop card")) {
    if (-not (Swipe-Viewport "up")) { exit 1 }
    if (-not (Click-Element "向学伴追问" "Ask tutor from review")) { exit 1 }
}
if (-not (Verify-Page "pages/Chat" "Tutor follow-up")) { exit 1 }
Take-Screenshot "06-review-chat"
Invoke-HdcShell @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
Start-Sleep -Milliseconds 500
Invoke-HdcShell @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
Start-Sleep -Milliseconds 500
Invoke-HdcShell @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
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
if (-not (Verify-TextExistsWithScroll "连续天数" "Learning streak" 2)) { exit 1 }
Take-Screenshot "08-profile-tab-scrolled"
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
    Invoke-HdcShell @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
    Start-Sleep -Milliseconds 500
}

# 17. 验证学习星图三门课程
if (-not (Click-Element "学习星图" "Learning map")) { exit 1 }
if (-not (Verify-Page "pages/LearningMap" "Learning map")) { exit 1 }
if (-not (Verify-TextExists "箭头表示先修方向" "Learning map direction legend")) { exit 1 }
$mapIndex = 12
foreach ($courseName in @('数据结构', '操作系统', '计算机网络')) {
    if (-not (Click-Element $courseName "Learning map: $courseName")) { exit 1 }
    if (-not (Verify-TextExists "Level 0" "Learning map graph level")) { exit 1 }
    Take-Screenshot (("{0:D2}-learning-map-{1}" -f $mapIndex, $courseName))
    $mapIndex++
}
Invoke-HdcShell @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
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
