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
$KNOWLEDGE_CHUNKS_PATH = Join-Path $HARMONYOS_DIR "entry\src\main\resources\rawfile\learning\knowledge-chunks.json"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$SCREENSHOT_DIR = Join-Path $PROJECT_ROOT "screenshots\trae-smoke-$TIMESTAMP"
$COURSE_NAMES = @('数据结构', '操作系统', '计算机网络')
$COURSE_CTA_TEXTS = @('进入课程', '继续课程')

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

function Test-UiNodeClickable($node) {
    if ($null -eq $node -or $null -eq $node.PSObject.Properties['attributes']) {
        return $false
    }
    $clickableProperty = $node.attributes.PSObject.Properties['clickable']
    if ($null -eq $clickableProperty) { return $false }
    if ($clickableProperty.Value -is [bool]) { return $clickableProperty.Value }
    return ($clickableProperty.Value -is [string] -and $clickableProperty.Value -ceq 'true')
}

function Test-UiNodeScrollable($node) {
    if ($null -eq $node -or $null -eq $node.PSObject.Properties['attributes']) {
        return $false
    }
    $scrollableProperty = $node.attributes.PSObject.Properties['scrollable']
    if ($null -eq $scrollableProperty) { return $false }
    if ($scrollableProperty.Value -is [bool]) { return $scrollableProperty.Value }
    return ($scrollableProperty.Value -is [string] -and $scrollableProperty.Value -ceq 'true')
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

function Invoke-ReturnToPage(
    [string]$expectedPagePath,
    [scriptblock]$getPagePathAction,
    [scriptblock]$backAction,
    [int]$maxBacks = 8,
    [int]$pollsPerBack = 8,
    [int]$pollDelayMilliseconds = 500,
    [int]$initialPolls = 20
) {
    if ([string]::IsNullOrWhiteSpace($expectedPagePath)) {
        throw 'Expected page path must be non-empty'
    }
    if ($maxBacks -lt 0 -or $pollsPerBack -lt 1 -or $pollDelayMilliseconds -lt 0 -or $initialPolls -lt 1) {
        throw 'Return-to-page limits are invalid'
    }

    $backs = 0
    $lastPath = $null
    for ($poll = 0; $poll -lt $initialPolls; $poll++) {
        $lastPath = & $getPagePathAction
        if ($lastPath -ceq $expectedPagePath) {
            return [PSCustomObject]@{ PagePath = $lastPath; BackCount = $backs }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$lastPath)) { break }
        if ($poll -lt ($initialPolls - 1) -and $pollDelayMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $pollDelayMilliseconds
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$lastPath)) {
        throw "Unable to obtain a non-empty page path before returning to $expectedPagePath"
    }

    while ($lastPath -cne $expectedPagePath) {
        if ($backs -ge $maxBacks) {
            throw "Unable to return to $expectedPagePath after $backs Back events; last=$lastPath"
        }

        $pathBeforeBack = [string]$lastPath
        & $backAction | Out-Null
        $backs++
        $transitionSettled = $false
        for ($poll = 0; $poll -lt $pollsPerBack; $poll++) {
            $lastPath = & $getPagePathAction
            if ($lastPath -ceq $expectedPagePath) {
                return [PSCustomObject]@{ PagePath = $lastPath; BackCount = $backs }
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$lastPath) -and
                $lastPath -cne $pathBeforeBack) {
                $transitionSettled = $true
                break
            }
            if ($poll -lt ($pollsPerBack - 1) -and $pollDelayMilliseconds -gt 0) {
                Start-Sleep -Milliseconds $pollDelayMilliseconds
            }
        }
        if (-not $transitionSettled) {
            throw (
                "Back transition did not leave $pathBeforeBack after $pollsPerBack polls; " +
                "last=$lastPath"
            )
        }
    }

    return [PSCustomObject]@{ PagePath = $lastPath; BackCount = $backs }
}

function Get-SourceTopicTexts() {
    if (-not (Test-Path -LiteralPath $KNOWLEDGE_CHUNKS_PATH -PathType Leaf)) {
        throw "Knowledge chunks source does not exist: $KNOWLEDGE_CHUNKS_PATH"
    }

    try {
        $chunks = Get-Content -LiteralPath $KNOWLEDGE_CHUNKS_PATH -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Knowledge chunks source is invalid JSON: $($_.Exception.Message)"
    }

    $topics = @()
    foreach ($chunk in @($chunks)) {
        if ($null -eq $chunk.PSObject.Properties['topic'] -or
            -not ($chunk.topic -is [string]) -or
            [string]::IsNullOrWhiteSpace($chunk.topic)) {
            throw "Knowledge chunk is missing an exact topic text"
        }
        if (-not ($topics -ccontains $chunk.topic)) {
            $topics += [string]$chunk.topic
        }
    }
    if ($topics.Count -eq 0) {
        throw "Knowledge chunks source contains no topic texts"
    }
    return $topics
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

function Test-BoundsRectangleEqual($left, $right) {
    return (
        $null -ne $left -and
        $null -ne $right -and
        $left.Left -eq $right.Left -and
        $left.Top -eq $right.Top -and
        $left.Right -eq $right.Right -and
        $left.Bottom -eq $right.Bottom
    )
}

function Get-ExactTextClickableTargets(
    $node,
    [string[]]$texts,
    [object[]]$ancestors = @()
) {
    if ($null -eq $node -or $null -eq $node.PSObject.Properties['attributes']) { return }

    $textProperty = $node.attributes.PSObject.Properties['text']
    if ($null -ne $textProperty -and
        $textProperty.Value -is [string] -and
        $texts -ccontains $textProperty.Value -and
        (Test-UiNodeVisible $node)) {
        $lineage = @($node)
        for ($index = $ancestors.Count - 1; $index -ge 0; $index--) {
            $lineage += $ancestors[$index]
        }
        foreach ($clickableNode in $lineage) {
            if ((Test-UiNodeVisible $clickableNode) -and (Test-UiNodeClickable $clickableNode)) {
                $center = Get-BoundsCenter $clickableNode.attributes.bounds
                if ($null -ne $center) {
                    Write-Output ([PSCustomObject]@{
                        Text = [string]$textProperty.Value
                        TextElement = $node
                        Element = $clickableNode
                        Center = $center
                    })
                }
                break
            }
        }
    }

    if ($null -ne $node.PSObject.Properties['children'] -and $node.children) {
        $childAncestors = @($ancestors) + @($node)
        foreach ($child in @($node.children)) {
            Get-ExactTextClickableTargets $child $texts $childAncestors
        }
    }
}

function Get-BoundedExactTextTargets($uiTree, [string[]]$texts) {
    $targets = @(Get-ExactTextClickableTargets $uiTree $texts)
    $sortProperties = @(
        @{ Expression = { $_.Center.Rectangle.Top }; Ascending = $true },
        @{ Expression = { $_.Center.Rectangle.Left }; Ascending = $true }
    )
    return @($targets | Sort-Object -Property $sortProperties)
}

function Get-BoundedScrollableTargets($uiTree, [string[]]$anchorTexts) {
    if ($anchorTexts.Count -eq 0) { return @() }

    $targets = @(
        foreach ($node in @(Get-UiNodes $uiTree)) {
            if (-not (Test-UiNodeVisible $node) -or -not (Test-UiNodeScrollable $node)) {
                continue
            }
            $boundsProperty = $node.attributes.PSObject.Properties['bounds']
            if ($null -eq $boundsProperty) { continue }
            $rectangle = Get-BoundsRectangle $boundsProperty.Value
            if ($null -eq $rectangle) { continue }

            $matchedTexts = @(
                foreach ($anchorText in $anchorTexts) {
                    if (@(Find-ElementByText $node $anchorText).Count -gt 0) {
                        Write-Output $anchorText
                    }
                }
            )

            Write-Output ([PSCustomObject]@{
                Element = $node
                Rectangle = $rectangle
                MatchedTexts = $matchedTexts
                HasAnchor = $matchedTexts.Count -gt 0
                Area = [long]($rectangle.Right - $rectangle.Left) * [long]($rectangle.Bottom - $rectangle.Top)
            })
        }
    )
    $sortProperties = @(
        @{ Expression = { $_.HasAnchor }; Descending = $true },
        @{ Expression = { $_.Area }; Ascending = $true },
        @{ Expression = { $_.Rectangle.Top }; Ascending = $true },
        @{ Expression = { $_.Rectangle.Left }; Ascending = $true }
    )
    return @($targets | Sort-Object -Property $sortProperties)
}

function Get-CourseScrollableTarget(
    $uiTree,
    [string[]]$anchorTexts,
    $expectedRectangle = $null
) {
    $targets = @(Get-BoundedScrollableTargets $uiTree $anchorTexts)
    if ($targets.Count -eq 0) {
        throw "No visible scrollable node with valid bounds is available for the course list"
    }

    if ($null -ne $expectedRectangle) {
        $matchingTargets = @(
            $targets | Where-Object {
                Test-BoundsRectangleEqual $_.Rectangle $expectedRectangle
            }
        )
        if ($matchingTargets.Count -eq 1) {
            return $matchingTargets[0]
        }
        if ($matchingTargets.Count -eq 0) {
            throw "Course list scrollable no longer matches its initial bounds"
        }
        throw "Course list scrollable initial bounds match multiple visible nodes"
    }

    $anchoredTargets = @($targets | Where-Object { $_.HasAnchor })
    if ($anchoredTargets.Count -gt 0) {
        $target = $anchoredTargets[0]
    } elseif ($targets.Count -eq 1) {
        $target = $targets[0]
    } else {
        throw "Multiple visible scrollable nodes with valid bounds have no exact course or CTA anchor"
    }
    return $target
}

function Get-ScrollableSwipeCoordinates(
    $uiTree,
    [string[]]$anchorTexts,
    [string]$direction,
    $expectedRectangle = $null
) {
    if ($direction -cne 'up' -and $direction -cne 'down') {
        throw "Scrollable swipe direction must be up or down"
    }

    $target = Get-CourseScrollableTarget $uiTree $anchorTexts $expectedRectangle
    $rectangle = $target.Rectangle
    $height = $rectangle.Bottom - $rectangle.Top
    $upperY = [int][math]::Floor($rectangle.Top + ($height * 0.25))
    $lowerY = [int][math]::Floor($rectangle.Top + ($height * 0.75))
    if ($lowerY -le $upperY) {
        throw "Scrollable node bounds are too small for a bounded swipe"
    }

    return [PSCustomObject]@{
        Direction = $direction
        X = [int][math]::Floor(($rectangle.Left + $rectangle.Right) / 2)
        FromY = if ($direction -ceq 'up') { $lowerY } else { $upperY }
        ToY = if ($direction -ceq 'up') { $upperY } else { $lowerY }
        Rectangle = $rectangle
    }
}

function Invoke-ScrollableSwipe(
    $uiTree,
    [string[]]$anchorTexts,
    [string]$direction,
    $expectedRectangle = $null
) {
    $swipe = Get-ScrollableSwipeCoordinates $uiTree $anchorTexts $direction $expectedRectangle
    Invoke-HdcShell -arguments @(
        'uitest', 'uiInput', 'swipe', [string]$swipe.X, [string]$swipe.FromY,
        [string]$swipe.X, [string]$swipe.ToY, '600'
    ) | Out-Null
    Start-Sleep -Milliseconds 700
    $rectangle = $swipe.Rectangle
    Write-Step "Course list scroll: $direction" "PASS" (
        "scrollableBounds=[$($rectangle.Left),$($rectangle.Top)][$($rectangle.Right),$($rectangle.Bottom)] " +
        "from=($($swipe.X),$($swipe.FromY)) to=($($swipe.X),$($swipe.ToY))"
    )
}

function Invoke-CourseListTraversal(
    [string[]]$courseNames,
    [string[]]$ctaTexts,
    [scriptblock]$getUiTreeAction,
    [scriptblock]$swipeAction,
    [int]$maxForwardScrolls = 4
) {
    if ($courseNames.Count -eq 0) { throw "No exact course names were supplied" }
    if ($ctaTexts.Count -eq 0) { throw "No exact course CTA texts were supplied" }
    if ($maxForwardScrolls -lt 1) { throw "Course list maxForwardScrolls must be at least 1" }

    $anchorTexts = @($courseNames) + @($ctaTexts)
    $seenCourseNames = @()
    $seenCtaTexts = @()
    $swipeResults = @()
    $forwardScrolls = 0
    $currentTree = & $getUiTreeAction
    $courseRectangle = $null

    while ($true) {
        $currentScrollable = Get-CourseScrollableTarget $currentTree $anchorTexts $courseRectangle
        if ($null -eq $courseRectangle) {
            $courseRectangle = $currentScrollable.Rectangle
        }
        foreach ($courseName in $courseNames) {
            if (-not ($seenCourseNames -ccontains $courseName) -and
                @(Find-ElementByText $currentScrollable.Element $courseName).Count -gt 0) {
                $seenCourseNames += $courseName
            }
        }
        foreach ($ctaTarget in @(Get-BoundedExactTextTargets $currentScrollable.Element $ctaTexts)) {
            if (-not ($seenCtaTexts -ccontains $ctaTarget.Text)) {
                $seenCtaTexts += [string]$ctaTarget.Text
            }
        }

        $missingCourseNames = @($courseNames | Where-Object { -not ($seenCourseNames -ccontains $_) })
        if ($missingCourseNames.Count -eq 0) { break }
        if ($forwardScrolls -ge $maxForwardScrolls) {
            throw (
                "Course list scan exhausted $maxForwardScrolls forward scrolls; " +
                "missing exact texts: $($missingCourseNames -join ', ')"
            )
        }

        $swipeResults += @(& $swipeAction $currentTree 'up' $anchorTexts $courseRectangle)
        $forwardScrolls++
        $currentTree = & $getUiTreeAction
    }

    $recoveryScrolls = 0
    $maxRecoveryScrolls = $forwardScrolls + 1
    while ($true) {
        $currentScrollable = Get-CourseScrollableTarget $currentTree $anchorTexts $courseRectangle
        $firstCourseVisible = @(
            Find-ElementByText $currentScrollable.Element $courseNames[0]
        ).Count -gt 0
        $visibleCtaTargets = @(
            Get-BoundedExactTextTargets $currentScrollable.Element $ctaTexts
        )
        if ($firstCourseVisible -and $visibleCtaTargets.Count -gt 0) { break }
        if ($forwardScrolls -eq 0 -or $recoveryScrolls -ge $maxRecoveryScrolls) {
            throw (
                "Course list recovery did not restore the first exact course text and a visible bounded CTA " +
                "after $recoveryScrolls reverse scrolls"
            )
        }

        $swipeResults += @(& $swipeAction $currentTree 'down' $anchorTexts $courseRectangle)
        $recoveryScrolls++
        $currentTree = & $getUiTreeAction
    }

    return [PSCustomObject]@{
        CourseNamesSeen = @($seenCourseNames)
        CtaTextsSeen = @($seenCtaTexts)
        ForwardScrolls = $forwardScrolls
        RecoveryScrolls = $recoveryScrolls
        SwipeResults = @($swipeResults)
        VisibleCtaTargets = @($visibleCtaTargets)
        ScrollableRectangle = $courseRectangle
    }
}

function Get-CourseScrollableCtaTargets(
    $uiTree,
    [string[]]$courseNames,
    [string[]]$ctaTexts,
    $expectedRectangle
) {
    $anchorTexts = @($courseNames) + @($ctaTexts)
    $scrollable = Get-CourseScrollableTarget $uiTree $anchorTexts $expectedRectangle
    return [PSCustomObject]@{
        Scrollable = $scrollable
        Targets = @(Get-BoundedExactTextTargets $scrollable.Element $ctaTexts)
    }
}

function Click-FirstVisibleCourseCta(
    [string[]]$courseNames,
    [string[]]$ctaTexts,
    $expectedRectangle,
    [int]$maxAttempts = 6
) {
    $scope = $null
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $scope = Get-CourseScrollableCtaTargets (Get-UiTree) `
                $courseNames $ctaTexts $expectedRectangle
            if ($scope.Targets.Count -gt 0) { break }
        } catch {
            if ($attempt -eq $maxAttempts) { throw }
        }
        if ($attempt -lt $maxAttempts) { Start-Sleep -Milliseconds 500 }
    }
    if ($null -eq $scope -or $scope.Targets.Count -eq 0) {
        Write-Step "Click: First visible course CTA" "FAIL" (
            "No visible bounded course CTA exists inside the initial course scrollable"
        )
        return $null
    }

    $target = $scope.Targets[0]
    $x = [string]$target.Center.X
    $y = [string]$target.Center.Y
    Invoke-HdcShell -arguments @('uitest', 'uiInput', 'click', $x, $y) | Out-Null
    Start-Sleep -Milliseconds 500
    $rectangle = $target.Center.Rectangle
    Write-Step "Click: First visible course CTA" "PASS" (
        "exactText=$($target.Text) " +
        "clickableBounds=[$($rectangle.Left),$($rectangle.Top)]" +
        "[$($rectangle.Right),$($rectangle.Bottom)] center=($x,$y)"
    )
    return [string]$target.Text
}

function Click-FirstVisibleExactText(
    [string[]]$texts,
    [string]$description,
    [int]$maxAttempts = 6
) {
    if ($texts.Count -eq 0) {
        Write-Step "Click: $description" "FAIL" "No exact source texts were supplied"
        return $null
    }

    $targets = @()
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $targets = @(Get-BoundedExactTextTargets (Get-UiTree) $texts)
        if ($targets.Count -gt 0) { break }
        if ($attempt -lt $maxAttempts) { Start-Sleep -Milliseconds 500 }
    }
    if ($targets.Count -eq 0) {
        Write-Step "Click: $description" "FAIL" "No visible clickable row with bounds matched the exact source texts"
        return $null
    }

    $target = $targets[0]
    $x = [string]$target.Center.X
    $y = [string]$target.Center.Y
    Invoke-HdcShell -arguments @("uitest", "uiInput", "click", $x, $y) | Out-Null
    Start-Sleep -Milliseconds 500
    $rectangle = $target.Center.Rectangle
    Write-Step "Click: $description" "PASS" (
        "exactText=$($target.Text) " +
        "clickableBounds=[$($rectangle.Left),$($rectangle.Top)][$($rectangle.Right),$($rectangle.Bottom)] center=($x,$y)"
    )
    return [string]$target.Text
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
            Name = 'root recovery waits through empty transition paths'
            Run = {
                $paths = [System.Collections.Queue]::new()
                foreach ($path in @('', 'pages/Practice', '', 'pages/Plan', '', 'pages/Index')) {
                    $paths.Enqueue($path)
                }
                $backCount = 0
                $getPath = {
                    if ($paths.Count -eq 0) { throw 'Synthetic page path queue is empty' }
                    return $paths.Dequeue()
                }.GetNewClosure()
                $goBack = { $script:syntheticBackCount++ }
                $script:syntheticBackCount = 0
                $result = Invoke-ReturnToPage 'pages/Index' $getPath $goBack 4 3 0
                Assert-SelfTest ($result.PagePath -ceq 'pages/Index') 'Root page was not recovered'
                Assert-SelfTest ($result.BackCount -eq 2) 'Unexpected returned Back count'
                Assert-SelfTest ($script:syntheticBackCount -eq 2) 'Transition polling sent an extra Back event'
                $script:syntheticBackCount = $null
            }
        },
        @{
            Name = 'root recovery ignores the old non-empty path after Back'
            Run = {
                $paths = [System.Collections.Queue]::new()
                foreach ($path in @(
                    'pages/Practice', 'pages/Practice', '', 'pages/Plan',
                    'pages/Plan', '', 'pages/Index'
                )) {
                    $paths.Enqueue($path)
                }
                $getPath = {
                    if ($paths.Count -eq 0) { throw 'Synthetic page path queue is empty' }
                    return $paths.Dequeue()
                }.GetNewClosure()
                $goBack = { $script:syntheticBackCount++ }
                $script:syntheticBackCount = 0
                $result = Invoke-ReturnToPage 'pages/Index' $getPath $goBack 4 3 0
                Assert-SelfTest ($result.PagePath -ceq 'pages/Index') 'Root page was not recovered'
                Assert-SelfTest ($result.BackCount -eq 2) 'Old paths caused extra returned Back events'
                Assert-SelfTest ($script:syntheticBackCount -eq 2) 'Old paths caused extra Back input events'
                $script:syntheticBackCount = $null
            }
        },
        @{
            Name = 'root recovery allows a bounded cold-start render delay'
            Run = {
                $paths = [System.Collections.Queue]::new()
                foreach ($path in @('', '', '', '', '', '', '', '', '', 'pages/Index')) {
                    $paths.Enqueue($path)
                }
                $getPath = {
                    if ($paths.Count -eq 0) { throw 'Synthetic page path queue is empty' }
                    return $paths.Dequeue()
                }.GetNewClosure()
                $script:syntheticBackCount = 0
                $result = Invoke-ReturnToPage 'pages/Index' $getPath { $script:syntheticBackCount++ } 4 3 0 10
                Assert-SelfTest ($result.PagePath -ceq 'pages/Index') 'Cold-start root page was not recovered'
                Assert-SelfTest ($result.BackCount -eq 0) 'Cold-start wait sent an unnecessary Back event'
                Assert-SelfTest ($script:syntheticBackCount -eq 0) 'Cold-start wait invoked the Back action'
                $script:syntheticBackCount = $null
            }
        },
        @{
            Name = 'course CTA entry and continue states'
            Run = {
                foreach ($ctaText in $COURSE_CTA_TEXTS) {
                    $tree = [PSCustomObject]@{
                        attributes = [PSCustomObject]@{ visible = 'true'; bounds = '[0,0][100,200]' }
                        children = @(
                            [PSCustomObject]@{
                                attributes = [PSCustomObject]@{
                                    visible = 'true'
                                    clickable = 'true'
                                    bounds = '[10,90][90,160]'
                                }
                                children = @(
                                    [PSCustomObject]@{
                                        attributes = [PSCustomObject]@{
                                            visible = 'true'
                                            text = $ctaText
                                            bounds = '[25,110][75,140]'
                                        }
                                        children = @()
                                    }
                                )
                            }
                        )
                    }
                    $targets = @(Get-BoundedExactTextTargets $tree $COURSE_CTA_TEXTS)
                    Assert-SelfTest ($targets.Count -eq 1) "Wrong target count for course CTA: $ctaText"
                    Assert-SelfTest ($targets[0].Text -ceq $ctaText) "Wrong exact course CTA selected: $ctaText"
                    Assert-SelfTest (
                        $targets[0].Center.Rectangle.Left -eq 10 -and
                        $targets[0].Center.Rectangle.Top -eq 90 -and
                        $targets[0].Center.Rectangle.Right -eq 90 -and
                        $targets[0].Center.Rectangle.Bottom -eq 160
                    ) "Course CTA did not use the clickable button bounds: $ctaText"
                }
            }
        },
        @{
            Name = 'course list finite scroll scan and recovery'
            Run = {
                $newCourseTree = {
                    param(
                        [string[]]$courseTexts,
                        [string]$ctaText,
                        [object]$scrollBounds,
                        [object]$scrollableValue
                    )
                    $children = [System.Collections.ArrayList]::new()
                    $top = 30
                    foreach ($courseText in $courseTexts) {
                        [void]$children.Add([PSCustomObject]@{
                            attributes = [PSCustomObject]@{
                                visible = 'true'
                                text = $courseText
                                bounds = "[20,$top][80,$($top + 20)]"
                            }
                            children = @()
                        })
                        $top += 35
                    }
                    [void]$children.Add([PSCustomObject]@{
                        attributes = [PSCustomObject]@{
                            visible = 'true'
                            clickable = 'true'
                            bounds = '[10,110][90,150]'
                        }
                        children = @(
                            [PSCustomObject]@{
                                attributes = [PSCustomObject]@{
                                    visible = 'true'
                                    text = $ctaText
                                    bounds = '[25,120][75,140]'
                                }
                                children = @()
                            }
                        )
                    })

                    $scrollAttributes = [ordered]@{
                        visible = 'true'
                        scrollable = $scrollableValue
                    }
                    if ($null -ne $scrollBounds) {
                        $scrollAttributes['bounds'] = $scrollBounds
                    }
                    return [PSCustomObject]@{
                        attributes = [PSCustomObject]@{ visible = 'true'; bounds = '[0,0][100,200]' }
                        children = @(
                            [PSCustomObject]@{
                                attributes = [PSCustomObject]$scrollAttributes
                                children = @($children)
                            }
                        )
                    }
                }

                $initialTree = & $newCourseTree @('数据结构', '操作系统') '进入课程' '[10,20][90,180]' 'true'
                $scrolledTree = & $newCourseTree @('操作系统', '计算机网络') '继续课程' '[10,20][90,180]' $true
                $initialTree.children += [PSCustomObject]@{
                    attributes = [PSCustomObject]@{
                        visible = 'true'
                        text = '计算机网络'
                        bounds = '[5,5][95,18]'
                    }
                    children = @()
                }
                $initialTree.children += [PSCustomObject]@{
                    attributes = [PSCustomObject]@{
                        visible = 'true'
                        clickable = 'true'
                        bounds = '[1,1][99,19]'
                    }
                    children = @(
                        [PSCustomObject]@{
                            attributes = [PSCustomObject]@{
                                visible = 'true'
                                text = '继续课程'
                                bounds = '[20,2][80,18]'
                            }
                            children = @()
                        }
                    )
                }
                $middleTree = [PSCustomObject]@{
                    attributes = [PSCustomObject]@{ visible = 'true'; bounds = '[0,0][100,200]' }
                    children = @(
                        [PSCustomObject]@{
                            attributes = [PSCustomObject]@{
                                visible = 'true'
                                scrollable = $true
                                bounds = '[10,20][90,180]'
                            }
                            children = @(
                                [PSCustomObject]@{
                                    attributes = [PSCustomObject]@{
                                        visible = 'true'
                                        text = '学习进度'
                                        bounds = '[20,80][80,100]'
                                    }
                                    children = @()
                                }
                            )
                        },
                        [PSCustomObject]@{
                            attributes = [PSCustomObject]@{
                                visible = 'true'
                                scrollable = 'true'
                                bounds = '[1,1][99,19]'
                            }
                            children = @()
                        }
                    )
                }
                $initialScrollable = Get-CourseScrollableTarget $initialTree `
                    (@($COURSE_NAMES) + @($COURSE_CTA_TEXTS))
                Assert-SelfTest (
                    @(Find-ElementByText $initialTree '计算机网络').Count -eq 1 -and
                    @(Find-ElementByText $initialScrollable.Element '计算机网络').Count -eq 0
                ) 'Off-list third course fixture was not isolated from the course scrollable'
                $initialCtaScope = Get-CourseScrollableCtaTargets $initialTree `
                    $COURSE_NAMES $COURSE_CTA_TEXTS $initialScrollable.Rectangle
                Assert-SelfTest (
                    @(Get-BoundedExactTextTargets $initialTree $COURSE_CTA_TEXTS).Count -eq 2 -and
                    $initialCtaScope.Targets.Count -eq 1 -and
                    $initialCtaScope.Targets[0].Text -ceq '进入课程'
                ) 'Off-list CTA was not isolated from the course scrollable'
                Assert-SelfTest (@(Find-ElementByText $scrolledTree '计算机网络').Count -eq 1) 'Third course was absent after scrolling'
                Assert-SelfTest (
                    @(Find-ElementByText $middleTree '数据结构').Count -eq 0 -and
                    @(Find-ElementByText $middleTree '操作系统').Count -eq 0 -and
                    @(Find-ElementByText $middleTree '计算机网络').Count -eq 0 -and
                    @(Get-BoundedExactTextTargets $middleTree $COURSE_CTA_TEXTS).Count -eq 0
                ) 'Synthetic middle viewport unexpectedly contains a course or CTA anchor'

                $trees = [System.Collections.Queue]::new()
                $trees.Enqueue($initialTree)
                $trees.Enqueue($middleTree)
                $trees.Enqueue($scrolledTree)
                $trees.Enqueue($middleTree)
                $trees.Enqueue($initialTree)
                $getUiTreeAction = {
                    if ($trees.Count -eq 0) { throw 'Synthetic UI tree queue is empty' }
                    return $trees.Dequeue()
                }.GetNewClosure()
                $swipeAction = {
                    param($uiTree, [string]$direction, [string[]]$anchorTexts, $expectedRectangle)
                    return Get-ScrollableSwipeCoordinates $uiTree $anchorTexts `
                        $direction $expectedRectangle
                }

                $scan = Invoke-CourseListTraversal $COURSE_NAMES $COURSE_CTA_TEXTS `
                    $getUiTreeAction $swipeAction 3
                Assert-SelfTest ($trees.Count -eq 0) 'Course scan did not consume the expected live UI trees'
                Assert-SelfTest ($scan.CourseNamesSeen.Count -eq 3) 'Course scan did not verify all exact course names'
                foreach ($courseName in $COURSE_NAMES) {
                    Assert-SelfTest ($scan.CourseNamesSeen -ccontains $courseName) "Course scan missed: $courseName"
                }
                Assert-SelfTest ($scan.CtaTextsSeen -ccontains '进入课程') 'Entry CTA was not observed'
                Assert-SelfTest ($scan.CtaTextsSeen -ccontains '继续课程') 'Continue CTA was not observed'
                Assert-SelfTest ($scan.ForwardScrolls -eq 2 -and $scan.RecoveryScrolls -eq 2) 'Unexpected finite scroll counts'
                Assert-SelfTest ($scan.SwipeResults.Count -eq 4) 'Unexpected bounded swipe count'
                Assert-SelfTest (
                    $scan.SwipeResults[0].Direction -ceq 'up' -and
                    $scan.SwipeResults[0].X -eq 50 -and
                    $scan.SwipeResults[0].FromY -eq 140 -and
                    $scan.SwipeResults[0].ToY -eq 60
                ) 'Forward swipe was not derived from scrollable bounds'
                Assert-SelfTest (
                    $scan.SwipeResults[1].Direction -ceq 'up' -and
                    $scan.SwipeResults[1].X -eq 50 -and
                    $scan.SwipeResults[1].FromY -eq 140 -and
                    $scan.SwipeResults[1].ToY -eq 60
                ) 'Anchor-free forward swipe did not use the unique scrollable bounds'
                Assert-SelfTest (
                    $scan.SwipeResults[2].Direction -ceq 'down' -and
                    $scan.SwipeResults[2].X -eq 50 -and
                    $scan.SwipeResults[2].FromY -eq 60 -and
                    $scan.SwipeResults[2].ToY -eq 140
                ) 'Recovery swipe was not derived from scrollable bounds'
                Assert-SelfTest (
                    $scan.SwipeResults[3].Direction -ceq 'down' -and
                    $scan.SwipeResults[3].X -eq 50 -and
                    $scan.SwipeResults[3].FromY -eq 60 -and
                    $scan.SwipeResults[3].ToY -eq 140
                ) 'Anchor-free recovery swipe did not use the unique scrollable bounds'
                Assert-SelfTest ($scan.VisibleCtaTargets.Count -eq 1) 'Recovered viewport has no single visible bounded CTA'
                Assert-SelfTest ($scan.VisibleCtaTargets[0].Text -ceq '进入课程') 'First recovered legal CTA was not selected'
            }
        },
        @{
            Name = 'course list rejects missing scrollable bounds'
            Run = {
                $tree = [PSCustomObject]@{
                    attributes = [PSCustomObject]@{ visible = 'true'; bounds = '[0,0][100,200]' }
                    children = @(
                        [PSCustomObject]@{
                            attributes = [PSCustomObject]@{ visible = 'true'; scrollable = $true }
                            children = @(
                                [PSCustomObject]@{
                                    attributes = [PSCustomObject]@{ visible = 'true'; text = '数据结构'; bounds = '[20,30][80,50]' }
                                    children = @()
                                },
                                [PSCustomObject]@{
                                    attributes = [PSCustomObject]@{ visible = 'true'; text = '操作系统'; bounds = '[20,65][80,85]' }
                                    children = @()
                                }
                            )
                        }
                    )
                }
                $getUiTreeAction = { return $tree }.GetNewClosure()
                $swipeAction = {
                    param($uiTree, [string]$direction, [string[]]$anchorTexts, $expectedRectangle)
                    Get-ScrollableSwipeCoordinates $uiTree $anchorTexts `
                        $direction $expectedRectangle | Out-Null
                }
                Assert-SelfTestThrows {
                    Invoke-CourseListTraversal $COURSE_NAMES $COURSE_CTA_TEXTS `
                        $getUiTreeAction $swipeAction 1
                } 'No visible scrollable node with valid bounds'
            }
        },
        @{
            Name = 'topmost exact Topic uses clickable row bounds'
            Run = {
                $sourceTopics = @(Get-SourceTopicTexts)
                Assert-SelfTest ($sourceTopics.Count -eq 33) 'Knowledge source did not expose the exact 33 Topic texts'
                $upperTopic = '数组与线性表'
                $lowerTopic = '链表'
                Assert-SelfTest ($sourceTopics -ccontains $upperTopic) 'Fixed upper Topic is absent from the knowledge source'
                Assert-SelfTest ($sourceTopics -ccontains $lowerTopic) 'Fixed lower Topic is absent from the knowledge source'
                $tree = [PSCustomObject]@{
                    attributes = [PSCustomObject]@{ visible = 'true'; bounds = '[0,0][100,300]' }
                    children = @(
                        [PSCustomObject]@{ attributes = [PSCustomObject]@{ visible = 'true'; text = '下一步 · ' + $upperTopic; bounds = '[10,20][90,50]' }; children = @() },
                        [PSCustomObject]@{
                            attributes = [PSCustomObject]@{ visible = 'true'; clickable = $true; bounds = '[5,80][95,160]' }
                            children = @(
                                [PSCustomObject]@{
                                    attributes = [PSCustomObject]@{ visible = 'true'; bounds = '[10,90][90,150]' }
                                    children = @(
                                        [PSCustomObject]@{
                                            attributes = [PSCustomObject]@{ visible = 'true'; text = $upperTopic; bounds = '[20,105][80,130]' }
                                            children = @()
                                        }
                                    )
                                }
                            )
                        },
                        [PSCustomObject]@{
                            attributes = [PSCustomObject]@{ visible = 'true'; clickable = 'true'; bounds = '[5,190][95,270]' }
                            children = @(
                                [PSCustomObject]@{
                                    attributes = [PSCustomObject]@{ visible = 'true'; text = $lowerTopic; bounds = '[20,215][80,240]' }
                                    children = @()
                                }
                            )
                        }
                    )
                }
                $targets = @(Get-BoundedExactTextTargets $tree @($upperTopic, $lowerTopic))
                Assert-SelfTest ($targets.Count -eq 2) 'Topic row matching included a non-exact text or lost a source Topic'
                Assert-SelfTest ($targets[0].Text -ceq $upperTopic) 'Topmost exact Topic row was not selected from live bounds'
                Assert-SelfTest (
                    $targets[0].Center.Rectangle.Left -eq 5 -and
                    $targets[0].Center.Rectangle.Top -eq 80 -and
                    $targets[0].Center.Rectangle.Right -eq 95 -and
                    $targets[0].Center.Rectangle.Bottom -eq 160
                ) 'Topmost Topic target did not use the whole clickable row bounds'
            }
        },
        @{
            Name = 'clickable exact text without row bounds rejected'
            Run = {
                $tree = [PSCustomObject]@{
                    attributes = [PSCustomObject]@{ visible = 'true'; bounds = '[0,0][100,200]' }
                    children = @(
                        [PSCustomObject]@{
                            attributes = [PSCustomObject]@{ visible = 'true'; clickable = 'true' }
                            children = @(
                                [PSCustomObject]@{
                                    attributes = [PSCustomObject]@{
                                        visible = 'true'
                                        text = '数组与线性表'
                                        bounds = '[20,100][80,130]'
                                    }
                                    children = @()
                                }
                            )
                        }
                    )
                }
                $targets = @(Get-BoundedExactTextTargets $tree @('数组与线性表'))
                Assert-SelfTest ($targets.Count -eq 0) 'Clickable Topic row without bounds was accepted'
            }
        },
        @{
            Name = 'Lesson page path asserted exactly'
            Run = {
                $tree = [PSCustomObject]@{
                    attributes = [PSCustomObject]@{
                        visible = 'true'
                        pagePath = 'pages/Lesson'
                        bounds = '[0,0][100,200]'
                    }
                    children = @()
                }
                $actual = Get-PagePath $tree
                Assert-SelfTest ($actual -ceq 'pages/Lesson') 'Exact Lesson page path was not accepted'
                Assert-SelfTest ($actual -cne 'pages/lesson') 'Lesson page path assertion was not case-sensitive'
                Assert-SelfTest ($actual -cne 'pages/LessonDetail') 'A different Lesson page path was accepted'
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
try {
    $rootRecovery = Invoke-ReturnToPage 'pages/Index' `
        { Get-PagePath (Get-UiTree) } `
        { Invoke-HdcShell -arguments @('uitest', 'uiInput', 'keyEvent', 'Back') } `
        8 8 500 20
} catch {
    Write-Step "Page: Root recovery" "FAIL" $_.Exception.Message
    exit 1
}
if (-not (Verify-Page "pages/Index" "Root")) { exit 1 }
Write-Step "Root recovery" "PASS" "backEvents=$($rootRecovery.BackCount)"
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
try {
    $courseScan = Invoke-CourseListTraversal $COURSE_NAMES $COURSE_CTA_TEXTS `
        { Get-UiTree } `
        { param($uiTree, [string]$direction, [string[]]$anchorTexts, $expectedRectangle)
            Invoke-ScrollableSwipe $uiTree $anchorTexts $direction $expectedRectangle
        }
} catch {
    Write-Step "Verify: Course list" "FAIL" $_.Exception.Message
    exit 1
}
foreach ($courseName in $COURSE_NAMES) {
    Write-Step "Verify: Course list: $courseName" "PASS" "Found exact text across live scrollable viewports"
}
Write-Step "Course list viewport recovery" "PASS" (
    "forwardScrolls=$($courseScan.ForwardScrolls) recoveryScrolls=$($courseScan.RecoveryScrolls)"
)

# 7. 进入课程详情与精确 Topic 行
Write-Output "`n[INFO] Entering course detail and a source-backed Topic row..."
$courseCta = Click-FirstVisibleCourseCta $COURSE_NAMES $COURSE_CTA_TEXTS `
    $courseScan.ScrollableRectangle
if ([string]::IsNullOrWhiteSpace($courseCta)) { exit 1 }
if (-not (Verify-Page "pages/CourseDetail" "Course detail")) { exit 1 }
Take-Screenshot "03-course-detail"
$sourceTopics = @(Get-SourceTopicTexts)
$selectedTopic = Click-FirstVisibleExactText $sourceTopics 'Topmost visible source Topic row'
if ([string]::IsNullOrWhiteSpace($selectedTopic)) { exit 1 }
if (-not (Verify-Page "pages/Lesson" "Lesson from Topic row")) { exit 1 }
if (-not (Verify-TextExists $selectedTopic "Lesson Topic title")) { exit 1 }
Take-Screenshot "04-lesson"

Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
if (-not (Verify-Page "pages/CourseDetail" "Course detail after Lesson")) { exit 1 }
Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
if (-not (Verify-Page "pages/Index" "Root after Lesson")) { exit 1 }

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

# 19. 验证首页到学习计划的核心次级路径
Write-Output "`n[INFO] Navigating to learning plan..."
if (-not (Click-Element "查看全部" "Learning plan entry")) { exit 1 }
if (-not (Verify-Page "pages/Plan" "Learning plan")) { exit 1 }
if (-not (Verify-TextExists "学习计划" "Learning plan title")) { exit 1 }
Take-Screenshot "16-plan"
Invoke-HdcShell -arguments @("uitest", "uiInput", "keyEvent", "Back") | Out-Null
if (-not (Verify-Page "pages/Index" "Root after learning plan")) { exit 1 }

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
