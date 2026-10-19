param(
    [string]$ToolsDirectory = (Join-Path $PSScriptRoot "../lib/plugins/agent_chat/tools"),
    [switch]$UpdateIndex,
    [switch]$RemoveUnregistered
)

$ErrorActionPreference = "Stop"
$ToolsDirectory = [System.IO.Path]::GetFullPath($ToolsDirectory)
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $ToolsDirectory "../../../../"))
$indexPath = Join-Path $ToolsDirectory "index.json"
$errors = [System.Collections.Generic.List[string]]::new()
$unregisteredTools = [System.Collections.Generic.List[object]]::new()

function Add-Error([string]$Message) {
    $script:errors.Add($Message)
}

function Remove-TopLevelJsonObject([string]$Json, [string]$PropertyName) {
    $key = [regex]::Escape($PropertyName)
    $pattern = '(?m)^\s*"' + $key + '"\s*:\s*\{'
    $match = [regex]::Match($Json, $pattern)
    if (-not $match.Success) { throw "找不到要移除的工具定义: $PropertyName" }

    $openBrace = $Json.IndexOf('{', $match.Index + $match.Length - 1)
    $depth = 0
    $inString = $false
    $escaped = $false
    $closeBrace = -1
    for ($i = $openBrace; $i -lt $Json.Length; $i++) {
        $char = $Json[$i]
        if ($inString) {
            if ($escaped) { $escaped = $false }
            elseif ($char -eq '\') { $escaped = $true }
            elseif ($char -eq '"') { $inString = $false }
            continue
        }
        if ($char -eq '"') { $inString = $true; continue }
        if ($char -eq '{') { $depth++ }
        elseif ($char -eq '}') {
            $depth--
            if ($depth -eq 0) { $closeBrace = $i; break }
        }
    }
    if ($closeBrace -lt 0) { throw "工具定义 JSON 对象未闭合: $PropertyName" }

    $end = $closeBrace + 1
    while ($end -lt $Json.Length -and [char]::IsWhiteSpace($Json[$end])) { $end++ }
    if ($end -lt $Json.Length -and $Json[$end] -eq ',') {
        $end++
        while ($end -lt $Json.Length -and ($Json[$end] -eq "`r" -or $Json[$end] -eq "`n")) { $end++ }
        return $Json.Remove($match.Index, $end - $match.Index)
    }

    $start = $match.Index
    while ($start -gt 0 -and [char]::IsWhiteSpace($Json[$start - 1])) { $start-- }
    if ($start -gt 0 -and $Json[$start - 1] -eq ',') { $start-- }
    return $Json.Remove($start, $closeBrace + 1 - $start)
}

function Get-FunctionBody([string]$Source, [string]$FunctionName) {
    $escapedName = [regex]::Escape($FunctionName)
    $expression = [regex]::Match($Source, "\b$escapedName\s*\([^)]*\)\s*=>\s*(\w+)\s*\(")
    if ($expression.Success) { return "__CALL__:$($expression.Groups[1].Value)" }
    $match = [regex]::Match($Source, "\b$escapedName\s*\([^)]*\)\s*(?:async\s*)?\{")
    if (-not $match.Success) { return $null }

    $openBrace = $Source.IndexOf('{', $match.Index + $match.Length - 1)
    $depth = 0
    for ($i = $openBrace; $i -lt $Source.Length; $i++) {
        if ($Source[$i] -eq '{') { $depth++ }
        elseif ($Source[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) { return $Source.Substring($openBrace + 1, $i - $openBrace - 1) }
        }
    }
    return $null
}

function Get-RegisteredMethods([string]$PluginId) {
    $pluginDirectory = Join-Path $repoRoot "lib/plugins/$PluginId"
    $pluginSourcePath = Join-Path $pluginDirectory "${PluginId}_plugin.dart"
    if (-not (Test-Path -LiteralPath $pluginSourcePath)) { return $null }

    $source = Get-Content -Raw -LiteralPath $pluginSourcePath
    $body = Get-FunctionBody $source "defineJSAPI"
    if ($null -eq $body) { return $null }

    if ($body.StartsWith("__CALL__:")) {
        $helperName = $body.Substring("__CALL__:".Length)
        $helperSource = $source
        $helperBody = Get-FunctionBody $helperSource $helperName
        if ($null -eq $helperBody) {
            $partPath = Join-Path $pluginDirectory "${PluginId}_js_api.dart"
            if (Test-Path -LiteralPath $partPath) {
                $helperSource = Get-Content -Raw -LiteralPath $partPath
                $helperBody = Get-FunctionBody $helperSource $helperName
            }
        }
        if ($null -eq $helperBody) { return $null }
        $body = $helperBody
    }

    return @([regex]::Matches($body, "'([A-Za-z0-9_]+)'\s*:") | ForEach-Object { $_.Groups[1].Value })
}

if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "缺少工具索引: $indexPath"
}

try {
    $index = Get-Content -Raw -LiteralPath $indexPath | ConvertFrom-Json
} catch {
    throw "工具索引 JSON 无法解析: $($_.Exception.Message)"
}

$indexIds = @{}
foreach ($entry in $index) {
    if ($entry.Count -lt 2) {
        Add-Error "index.json 存在无效条目: $($entry | ConvertTo-Json -Compress)"
        continue
    }
    $id = [string]$entry[0]
    if ($indexIds.ContainsKey($id)) { Add-Error "index.json 工具重复: $id" }
    $indexIds[$id] = $true
}

$specialMethods = @{
    system = @{}
    ui = @{}
    memory = @{ sourcePlugin = "openai" }
    moments = @{ sourcePlugin = "openai" }
}
$bridgePath = Join-Path $repoRoot "lib/core/js_bridge/js_bridge_manager.dart"
$bridgeSource = Get-Content -Raw -LiteralPath $bridgePath
foreach ($m in [regex]::Matches($bridgeSource, "registerFunction\(\s*'Aboutme_(system_[^']+)'") ) {
    $specialMethods.system[$m.Groups[1].Value] = $true
}
$specialMethods.system["system_getLocation"] = $true
$specialMethods.ui = @{ ui_toast = $true; ui_alert = $true; ui_dialog = $true }

$checked = 0
foreach ($file in Get-ChildItem -LiteralPath $ToolsDirectory -Filter "*.json" | Where-Object Name -ne "index.json") {
    $pluginId = $file.BaseName
    try {
        $config = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -AsHashtable
    } catch {
        Add-Error "$($file.Name) JSON 无法解析: $($_.Exception.Message)"
        continue
    }

    $sourcePlugin = $pluginId
    if ($specialMethods.ContainsKey($pluginId) -and $specialMethods[$pluginId].ContainsKey("sourcePlugin")) {
        $sourcePlugin = $specialMethods[$pluginId].sourcePlugin
    }
    $registered = Get-RegisteredMethods $sourcePlugin
    if ($pluginId -in @("system", "ui")) { $registered = $specialMethods[$pluginId].Keys }
    if ($null -eq $registered) {
        Add-Error "$($file.Name) 无法从插件源码提取 defineJSAPI 注册表 ($sourcePlugin)"
        continue
    }

    foreach ($method in $config.Keys) {
        $checked++
        $toolId = if ($method.StartsWith("${pluginId}_")) { $method } else { "${pluginId}_$method" }
        if (-not $UpdateIndex -and -not $indexIds.ContainsKey($toolId)) { Add-Error "索引缺失工具: $toolId" }
        $apiMethod = $method
        if ($pluginId -notin @("system", "ui") -and $apiMethod.StartsWith("${pluginId}_")) {
            $apiMethod = $apiMethod.Substring($pluginId.Length + 1)
        }
        if ($pluginId -eq "ui") { $apiMethod = $method }
        if ($pluginId -eq "openai" -and $apiMethod -in @("list_files", "read_file", "write_file")) { continue }
        if ($apiMethod -notin $registered) {
            $unregisteredTools.Add([pscustomobject]@{ Path = $file.FullName; Name = $method })
            if (-not $RemoveUnregistered) { Add-Error "$($file.Name) 方法未注册: $method (源码插件: $sourcePlugin)" }
        }
    }
}

if ($RemoveUnregistered -and $unregisteredTools.Count -gt 0) {
    foreach ($fileGroup in ($unregisteredTools | Group-Object Path)) {
        $content = Get-Content -Raw -LiteralPath $fileGroup.Name
        foreach ($tool in $fileGroup.Group) {
            $content = Remove-TopLevelJsonObject $content $tool.Name
        }
        Set-Content -LiteralPath $fileGroup.Name -Value $content -NoNewline -Encoding utf8
    }
    Write-Host "已移除 $($unregisteredTools.Count) 个未注册工具定义，并将重建索引。" -ForegroundColor Yellow
    $UpdateIndex = $true
}

if ($UpdateIndex) {
    $newIndex = [System.Collections.Generic.List[object]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $ToolsDirectory -Filter "*.json" | Where-Object Name -ne "index.json") {
        $config = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -AsHashtable
        foreach ($entry in $config.GetEnumerator()) {
            $toolId = if ($entry.Key.StartsWith("$($file.BaseName)_")) { $entry.Key } else { "$($file.BaseName)_$($entry.Key)" }
            $title = [string]$entry.Value.title
            if ([string]::IsNullOrWhiteSpace($title)) { $title = [string]$entry.Value.description }
            $newIndex.Add(@($toolId, $title))
        }
    }
    $indexLines = foreach ($entry in $newIndex) { ConvertTo-Json -InputObject $entry -Compress }
    $indexContent = "[`n" + (($indexLines | ForEach-Object { "  $_" }) -join ",`n") + "`n]"
    Set-Content -LiteralPath $indexPath -Value $indexContent -Encoding utf8
    $indexIds = @{}
    foreach ($entry in $newIndex) { $indexIds[[string]$entry[0]] = $true }
}

foreach ($id in $indexIds.Keys) {
    $pluginFile = Get-ChildItem -LiteralPath $ToolsDirectory -Filter "*.json" |
        Where-Object { $_.Name -ne "index.json" -and $id.StartsWith("$($_.BaseName)_") } |
        Sort-Object { $_.BaseName.Length } -Descending |
        Select-Object -First 1
    if (-not $pluginFile) { Add-Error "索引条目没有对应配置文件: $id"; continue }
    $pluginId = $pluginFile.BaseName
    $method = $id.Substring($pluginId.Length + 1)
    try { $config = Get-Content -Raw -LiteralPath $pluginFile.FullName | ConvertFrom-Json -AsHashtable }
    catch { continue }
    if (-not $config.ContainsKey($method) -and -not $config.ContainsKey($id)) { Add-Error "配置缺少索引工具: $id" }
}

if ($errors.Count -gt 0) {
    Write-Host "发现 $($errors.Count) 个工具配置问题 (已检查 $checked 个工具):" -ForegroundColor Red
    foreach ($errorItem in $errors) { Write-Host " - $errorItem" -ForegroundColor Red }
    exit 1
}

Write-Host "通过: 已检查 $checked 个工具，索引、配置与 API 注册表一致。" -ForegroundColor Green
