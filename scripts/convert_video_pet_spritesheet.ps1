#requires -Version 7.0
# Run with pwsh, which reads this UTF-8 script and Chinese filenames correctly.
# Full package: pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -All
[CmdletBinding()]
param(
  [string]$Action = '东张西望',
  [switch]$All,
  [switch]$Resume,
  [ValidateRange(1, 8192)][int]$FrameWidth = 640,
  [ValidateRange(1, 8192)][int]$FrameHeight = 360,
  [ValidateRange(1, 120)][int]$Fps = 12,
  [ValidateRange(1, 100)][int]$Columns = 8,
  [ValidateRange(1, 2147483647)][int]$MaxBytes = 1000000,
  [ValidateRange(0, 100)][int]$Quality = 100,
  [string]$Ffmpeg = 'E:/ffmpeg/ffmpeg.exe',
  [string]$Ffprobe = '',
  [string]$Cwebp = 'D:/tmp/webp-1.6.0/libwebp-1.6.0-windows-x64/bin/cwebp.exe'
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$root = Split-Path -Parent $PSScriptRoot
$packageDir = Join-Path $root 'assets/live2d/video/dsh_pet'
$manifestPath = Join-Path $packageDir 'manifest.json'
$outDir = Join-Path $packageDir 'spritesheet'

function Resolve-Tool([string]$ConfiguredPath) {
  if (-not (Test-Path -LiteralPath $ConfiguredPath -PathType Leaf)) {
    throw "Tool not found: $ConfiguredPath"
  }
  return (Resolve-Path -LiteralPath $ConfiguredPath).Path
}

function Write-Json($Value, [string]$Path) {
  $json = ConvertTo-Json -InputObject $Value -Depth 100
  [System.IO.File]::WriteAllText($Path, $json + "`n", $utf8)
}

$ffmpegPath = Resolve-Tool $Ffmpeg
if (-not $Ffprobe) { $Ffprobe = Join-Path (Split-Path -Parent $ffmpegPath) 'ffprobe.exe' }
$ffprobePath = Resolve-Tool $Ffprobe
$cwebpPath = Resolve-Tool $Cwebp
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
$actions = @($manifest.animations | Where-Object { $All -or $_.id -ceq $Action })
if ($actions.Count -eq 0) { throw "Action not found in manifest: $Action" }
foreach ($entry in $actions) {
  $source = Join-Path $packageDir "webm/$($entry.id).webm"
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Source video not found: $source" }
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aboutme-spritesheet-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workDir | Out-Null
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$results = @{}
$index = 0
try {
  foreach ($entry in $actions) {
    $id = $entry.id
    $source = Join-Path $packageDir "webm/$id.webm"
    $output = Join-Path $outDir "$id.webp"
    $metadataPath = Join-Path $outDir "$id.json"
    if ($Resume -and (Test-Path -LiteralPath $output) -and (Test-Path -LiteralPath $metadataPath)) {
      $existing = Get-Content -LiteralPath $metadataPath -Raw -Encoding utf8 | ConvertFrom-Json
      if ($existing.FrameWidth -eq $FrameWidth -and $existing.FrameHeight -eq $FrameHeight -and
          $existing.SampleFps -eq $Fps -and $existing.Columns -eq $Columns -and
          $existing.MaxImageBytes -eq $MaxBytes -and $existing.AlphaQuality -gt 0 -and
          $existing.EncodedBytes -eq (Get-Item -LiteralPath $output).Length -and $existing.EncodedBytes -lt $MaxBytes) {
        $results[$id] = [ordered]@{ frameWidth=$FrameWidth; frameHeight=$FrameHeight; columns=$Columns; rows=$existing.Rows; frameCount=$existing.FrameCount; fps=$Fps }
        $index++
        Write-Host "[$index/$($actions.Count)] $id reused bytes=$($existing.EncodedBytes)"
        continue
      }
    }
    $rawSheet = Join-Path $workDir 'sheet.png'
    $candidate = Join-Path $workDir 'candidate.webp'
    $best = Join-Path $workDir 'best.webp'
    $probeText = & $ffprobePath -v error -select_streams v:0 `
      -show_entries 'format=duration:stream=r_frame_rate' -of json $source
    if ($LASTEXITCODE -ne 0) { throw "Unable to probe source: $source" }
    $probe = ($probeText -join "`n") | ConvertFrom-Json
    $duration = [double]::Parse($probe.format.duration, $culture)
    $rational = $probe.streams[0].r_frame_rate.Split('/')
    $sourceFps = [double]::Parse($rational[0], $culture) / [double]::Parse($rational[1], $culture)

    # Duration is descriptive only; count after the fps filter's EOF rounding.
    $progress = & $ffmpegPath -hide_banner -nostdin -v error -nostats `
      -c:v libvpx-vp9 -i $source -map 0:v:0 -an -sn `
      -vf "fps=$Fps" -fps_mode passthrough -progress pipe:1 -f null -
    if ($LASTEXITCODE -ne 0) { throw "Frame counting failed: $source" }
    $frameLines = @($progress | Where-Object { $_ -match '^frame=\d+$' })
    if ($frameLines.Count -eq 0 -or $progress -notcontains 'progress=end') {
      throw "Missing completed FFmpeg progress: $source"
    }
    $frameCount = [int]($frameLines[-1].Split('=')[1])
    if ($frameCount -le 0) { throw "No sampled frames: $source" }
    $rows = [int][math]::Ceiling($frameCount / [double]$Columns)

    # Preserve source alpha and transparent padding before lossy RGB encoding.
    & $ffmpegPath -hide_banner -nostdin -y -v error -c:v libvpx-vp9 -i $source `
      -map 0:v:0 -an -sn `
      -vf "fps=$Fps,scale=${FrameWidth}:${FrameHeight}:flags=lanczos,format=rgba,tile=layout=${Columns}x${rows}:nb_frames=${frameCount}:color=0x00000000" `
      -frames:v 1 -update 1 -pix_fmt rgba $rawSheet
    if ($LASTEXITCODE -ne 0) { throw "Spritesheet conversion failed: $source" }

    # Prefer usable RGB detail; quantize soft alpha edges only as needed.
    $bestQuality = -1
    $alphaQuality = 50
    $baseQuality = [math]::Min(35, $Quality)
    foreach ($trialAlpha in @(50, 25, 10, 1)) {
      & $cwebpPath -quiet -m 4 -mt -alpha_q $trialAlpha -q $baseQuality $rawSheet -o $candidate
      if ($LASTEXITCODE -ne 0) { throw "WebP encoding failed: $id" }
      if ((Get-Item -LiteralPath $candidate).Length -lt $MaxBytes) {
        Copy-Item -LiteralPath $candidate -Destination $best -Force
        $bestQuality = $baseQuality
        $alphaQuality = $trialAlpha
        break
      }
    }
    $low = if ($bestQuality -ge 0) { $baseQuality + 1 } else { 0 }
    $high = if ($bestQuality -ge 0) { $Quality } else { $baseQuality - 1 }
    if ($bestQuality -lt 0) { $alphaQuality = 1 }
    while ($low -le $high) {
      $trialQuality = [int][math]::Floor(($low + $high) / 2)
      & $cwebpPath -quiet -m 4 -mt -alpha_q $alphaQuality -q $trialQuality $rawSheet -o $candidate
      if ($LASTEXITCODE -ne 0) { throw "WebP encoding failed: $id quality=$trialQuality" }
      if ((Get-Item -LiteralPath $candidate).Length -lt $MaxBytes) {
        Copy-Item -LiteralPath $candidate -Destination $best -Force
        $bestQuality = $trialQuality
        $low = $trialQuality + 1
      } else {
        $high = $trialQuality - 1
      }
    }
    if ($bestQuality -lt 0) { throw "Cannot fit $id below $MaxBytes bytes without changing dimensions or frames" }
    $encodedBytes = (Get-Item -LiteralPath $best).Length
    if ($encodedBytes -ge $MaxBytes) { throw "WebP exceeds byte limit: $id" }
    $imageText = & $ffprobePath -v error -select_streams v:0 `
      -show_entries stream=width,height,pix_fmt -of json $best
    if ($LASTEXITCODE -ne 0) { throw "Unable to probe WebP: $id" }
    $image = (($imageText -join "`n") | ConvertFrom-Json).streams[0]
    if ($image.width -ne ($FrameWidth * $Columns) -or $image.height -ne ($FrameHeight * $rows) -or $image.pix_fmt -notin @('rgba', 'bgra', 'yuva420p')) {
      throw "WebP dimensions or alpha format mismatch: $id"
    }
    Move-Item -LiteralPath $best -Destination $output -Force
    $sheet = [ordered]@{
      frameWidth = $FrameWidth
      frameHeight = $FrameHeight
      columns = $Columns
      rows = $rows
      frameCount = $frameCount
      fps = $Fps
    }
    Write-Json ([ordered]@{
      Source = Split-Path -Leaf $source
      FrameWidth = $FrameWidth
      FrameHeight = $FrameHeight
      Columns = $Columns
      Rows = $rows
      FrameCount = $frameCount
      SampleFps = $Fps
      SourceDurationSeconds = $duration
      SourceFps = $sourceFps
      CanvasWidth = $image.width
      CanvasHeight = $image.height
      SourceVideoBytes = (Get-Item -LiteralPath $source).Length
      Alpha = 'RGBA'
      ImageFormat = 'webp'
      Lossless = $false
      EncodingQuality = $bestQuality
      AlphaQuality = $alphaQuality
      Encoder = 'cwebp -m 4 -mt'
      EncodedBytes = $encodedBytes
      MaxImageBytes = $MaxBytes
      License = 'Non-commercial; attribution required. See NOTICE.txt and SOURCE-upstream.txt.'
    }) $metadataPath
    $results[$id] = $sheet
    $index++
    Write-Host "[$index/$($actions.Count)] $id quality=$bestQuality frames=$frameCount grid=${Columns}x${rows} texture=$($image.width)x$($image.height) bytes=$encodedBytes limit=$MaxBytes"
  }

  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
  foreach ($entry in $manifest.animations) {
    if ($results.ContainsKey($entry.id)) {
      $entry.sources = [ordered]@{ webp = "spritesheet/$($entry.id).webp" }
      $entry.spritesheet = $results[$entry.id]
    }
  }
  if (-not $manifest.metadata) { $manifest.metadata = [ordered]@{} }
  $manifest.metadata.Remove('movRelease') | Out-Null
  $manifest.metadata.Remove('movZipSha256') | Out-Null
  $manifest.metadata['resourceFormat'] = 'Per-action lossy WebP spritesheets with alpha'
  $manifest.metadata['sourceVideos'] = 'webm/ (local conversion inputs; gitignored and excluded from Flutter assets)'
  $manifest.metadata['conversion'] = [ordered]@{
    frameWidth = $FrameWidth
    frameHeight = $FrameHeight
    fps = $Fps
    columns = $Columns
    rows = 'ceil(actual fps-filtered frame count / columns)'
    frameCountMethod = 'FFmpeg fps filter -> null output -> final progress frame count'
    imageFormat = 'webp'
    lossless = $false
    maxImageBytes = $MaxBytes
    qualityCeiling = $Quality
    qualitySearch = 'Per-image RGB integer binary search; alpha quality 50/25/10/1 as needed; encoded bytes strictly below maxImageBytes'
    encoder = 'cwebp -m 4 -mt'
    script = 'scripts/convert_video_pet_spritesheet.ps1'
  }
  Write-Json $manifest $manifestPath

  # Remove only superseded generated PNGs after their WebP references are saved.
  foreach ($id in $results.Keys) {
    $oldPng = Join-Path $outDir "$id.png"
    if (Test-Path -LiteralPath $oldPng -PathType Leaf) { Remove-Item -LiteralPath $oldPng }
  }
  $checksums = [ordered]@{}
  foreach ($directory in @('webm', 'spritesheet')) {
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $packageDir $directory) -File | Sort-Object Name)) {
      $checksums["$directory/$($file.Name)"] = [ordered]@{
        bytes = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      }
    }
  }
  Write-Json $checksums (Join-Path $packageDir 'checksums.json')
  $timer.Stop()
  $images = @(Get-ChildItem -LiteralPath $outDir -Filter '*.webp' -File)
  $largest = Get-ChildItem -LiteralPath $outDir -Filter '*.json' -File | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8 | ConvertFrom-Json
  } | Sort-Object { $_.CanvasWidth * $_.CanvasHeight } -Descending | Select-Object -First 1
  Write-Host "Completed $index actions in $([math]::Round($timer.Elapsed.TotalSeconds, 2)) seconds. WebP count=$($images.Count), WebP bytes=$(($images | Measure-Object Length -Sum).Sum), max bytes=$(($images | Measure-Object Length -Maximum).Maximum)."
  Write-Host "Largest texture: $($largest.CanvasWidth)x$($largest.CanvasHeight), RGBA bytes=$($largest.CanvasWidth * $largest.CanvasHeight * 4), source=$($largest.Source)."
} finally {
  Remove-Item -LiteralPath $workDir -Recurse -Force
}
