[CmdletBinding()]
param(
  [string]$ConfigPath = "",
  [string]$GameDir = "",
  [switch]$Force,
  [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$BackupDir = Join-Path $Root 'backup'
$BackupFile = Join-Path $BackupDir 'level2.original'
$ManifestFile = Join-Path $BackupDir 'manifest.json'
$Encoder = [Text.Encoding]::GetEncoding(28591)
$script:GameDirFromPrompt = $false

# ---------------- helpers ----------------
function New-FloatBytes([double]$v) { return [BitConverter]::GetBytes([single]$v) }

function New-IntBytes([int]$v) { return [BitConverter]::GetBytes([int]$v) }

function Join-Bytes([object[]]$parts) {
  $total = 0
  foreach ($p in $parts) { $total += $p.Length }
  $result = New-Object byte[] $total
  $offset = 0
  foreach ($p in $parts) {
    [Array]::Copy($p, 0, $result, $offset, $p.Length)
    $offset += $p.Length
  }
  return ,$result
}

function Find-UniqueOffset([string]$Text, [byte[]]$Pattern, [string]$Name) {
  $needle = $Encoder.GetString($Pattern)
  $i = $Text.IndexOf($needle, [StringComparison]::Ordinal)
  if ($i -lt 0) {
    throw "在 level2 中找不到 [$Name] 的原始数据。请确认游戏版本为 Flotsam 1.0.1f9 / Unity 6000.3，或先用 Epic 的「验证文件完整性」恢复原版 level2。"
  }
  $j = $Text.IndexOf($needle, $i + 1, [StringComparison]::Ordinal)
  if ($j -ge 0) {
    throw "[$Name] 的原始数据在 level2 中出现多次，无法安全定位。"
  }
  return $i
}

function Get-FileSha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-GameDir([string]$Dir) {
  if (-not $Dir) { return $false }
  try {
    $level2 = [IO.Path]::Combine($Dir, 'Flotsam_Data', 'level2')
    return (Test-Path -LiteralPath $level2 -ErrorAction SilentlyContinue)
  } catch {
    return $false
  }
}

function Read-GameDirFromUser {
  if ($script:NonInteractive -or -not [Environment]::UserInteractive) { return $null }
  Write-Host ""
  Write-Host "没有自动找到 Flotsam 游戏目录。" -ForegroundColor Yellow
  Write-Host "请输入游戏根目录（包含 Flotsam.exe 的文件夹），直接回车取消。"
  for ($i = 1; $i -le 3; $i++) {
    $answer = $null
    try { $answer = Read-Host "游戏目录" } catch { return $null }
    if (-not $answer) { return $null }
    $path = $answer.Trim().Trim('"').Trim("'")
    if (Test-GameDir $path) {
      return (Resolve-Path -LiteralPath $path).Path
    }
    Write-Host "该目录下没有找到 Flotsam_Data\level2，请检查后重新输入（$i/3）。" -ForegroundColor Yellow
  }
  return $null
}
function Resolve-GameDir([string]$Explicit, [string]$FromConfig) {
  $candidates = New-Object System.Collections.Generic.List[string]
  if ($Explicit) { $candidates.Add($Explicit) }
  if ($FromConfig) { $candidates.Add($FromConfig) }

  # 1) Epic launcher manifests
  $manifestDir = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'
  if (Test-Path -LiteralPath $manifestDir) {
    foreach ($f in Get-ChildItem -LiteralPath $manifestDir -Filter *.item -ErrorAction SilentlyContinue) {
      try {
        $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
        if ($j.DisplayName -eq 'Flotsam' -and $j.InstallLocation) { $candidates.Add($j.InstallLocation) }
      } catch { }
    }
  }

  # 2) Steam libraries (registry + libraryfolders.vdf)
  $steamRoots = @()
  foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
    try {
      $props = Get-ItemProperty -Path $key -ErrorAction Stop
      if ($props.SteamPath) { $steamRoots += $props.SteamPath }
      if ($props.InstallPath) { $steamRoots += $props.InstallPath }
    } catch { }
  }
  foreach ($steam in $steamRoots) {
    if (-not $steam) { continue }
    $candidates.Add([IO.Path]::Combine($steam, 'steamapps', 'common', 'Flotsam'))
    $vdf = [IO.Path]::Combine($steam, 'steamapps', 'libraryfolders.vdf')
    if (Test-Path -LiteralPath $vdf -ErrorAction SilentlyContinue) {
      try {
        $text = Get-Content -LiteralPath $vdf -Raw
        foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
          $lib = $m.Groups[1].Value -replace '\\\\', '\'
          $candidates.Add([IO.Path]::Combine($lib, 'steamapps', 'common', 'Flotsam'))
        }
      } catch { }
    }
  }

  # 3) Common install layouts on every ready drive
  $relative = @(
    'Program Files\Epic Games\Flotsam',
    'Program Files (x86)\Epic Games\Flotsam',
    'Epic Games\Flotsam',
    'Games\Flotsam',
    'Game\Flotsam',
    'Flotsam',
    'SteamLibrary\steamapps\common\Flotsam'
  )
  try {
    foreach ($drive in [IO.DriveInfo]::GetDrives()) {
      if (-not $drive.IsReady) { continue }
      foreach ($rel in $relative) {
        $candidates.Add([IO.Path]::Combine($drive.RootDirectory.FullName, $rel))
      }
    }
  } catch { }

  foreach ($dir in ($candidates | Select-Object -Unique)) {
    if (Test-GameDir $dir) {
      return (Resolve-Path -LiteralPath $dir).Path
    }
  }
  $manual = Read-GameDirFromUser
  if ($manual) {
    $script:GameDirFromPrompt = $true
    return $manual
  }
  throw "没有找到 Flotsam 安装目录。请在 config.json 的 game_dir 中填写游戏根目录（包含 Flotsam.exe 的文件夹），或重新运行后按提示输入路径。"
}

function Assert-Number($value, [string]$name) {
  if ($null -eq $value) { throw "config.json 缺少字段：$name" }
  $d = 0.0
  if (-not [double]::TryParse([string]$value, [ref]$d)) { throw "config.json 字段 [$name] 不是数字：$value" }
  return $d
}

# ---------------- load config ----------------
if (-not $ConfigPath) { $ConfigPath = Join-Path $Root 'config.json' }
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "找不到配置文件：$ConfigPath" }

try {
  $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
} catch {
  throw "config.json 解析失败：$($_.Exception.Message)"
}

$main = $cfg.main_camera
$map = $cfg.map_camera
if (-not $main -or -not $map) { throw "config.json 必须包含 main_camera 和 map_camera 两段。" }

# ---------------- values + validation ----------------
$P = @{
  pitchMin = Assert-Number $main.pitch_min_degrees 'main_camera.pitch_min_degrees'
  pitchMax = Assert-Number $main.pitch_max_degrees 'main_camera.pitch_max_degrees'
  zoomMin  = Assert-Number $main.zoom_min_distance 'main_camera.zoom_min_distance'
  zoomMaxM = Assert-Number $main.zoom_max_distance_mouse 'main_camera.zoom_max_distance_mouse'
  zoomMaxJ = Assert-Number $main.zoom_max_distance_joystick 'main_camera.zoom_max_distance_joystick'
  speedM   = Assert-Number $main.zoom_speed_mouse 'main_camera.zoom_speed_mouse'
  speedJ   = Assert-Number $main.zoom_speed_joystick 'main_camera.zoom_speed_joystick'
  wait     = Assert-Number $main.switch_wait_seconds 'main_camera.switch_wait_seconds'
  pan      = Assert-Number $main.pan_speed 'main_camera.pan_speed'
  rotStep  = Assert-Number $main.rotate_step_degrees 'main_camera.rotate_step_degrees'
  rotSmooth= Assert-Number $main.rotate_smoothness 'main_camera.rotate_smoothness'
  mapMin   = Assert-Number $map.zoom_min_distance 'map_camera.zoom_min_distance'
  mapMax   = Assert-Number $map.zoom_max_distance 'map_camera.zoom_max_distance'
  mapInit  = Assert-Number $map.default_zoom 'map_camera.default_zoom'
  mapSpeedM= Assert-Number $map.zoom_speed_mouse 'map_camera.zoom_speed_mouse'
  mapSpeedJ= Assert-Number $map.zoom_speed_joystick 'map_camera.zoom_speed_joystick'
  mapWait  = Assert-Number $map.switch_wait_seconds 'map_camera.switch_wait_seconds'
  fade     = Assert-Number $map.fade_seconds 'map_camera.fade_seconds'
  mapPanMin= Assert-Number $map.pan_speed_min 'map_camera.pan_speed_min'
  mapPanMax= Assert-Number $map.pan_speed_max 'map_camera.pan_speed_max'
}

if ($P.pitchMin -ge $P.pitchMax) { throw "pitch_min_degrees 必须小于 pitch_max_degrees。" }
if ($P.zoomMin -ge $P.zoomMaxM) { throw "zoom_min_distance 必须小于 zoom_max_distance_mouse。" }
if ($P.zoomMin -ge $P.zoomMaxJ) { throw "zoom_min_distance 必须小于 zoom_max_distance_joystick。" }
if ($P.speedM -le 0 -or $P.speedJ -le 0) { throw "缩放速度必须大于 0。" }
if ($P.wait -lt 0 -or $P.mapWait -lt 0) { throw "switch_wait_seconds 不能为负数。" }
if ($P.mapInit -lt 0 -or $P.mapInit -gt 1) { throw "default_zoom 必须在 0 到 1 之间。" }
if ($P.mapMin -ge $P.mapMax) { throw "map_camera.zoom_min_distance 必须小于 zoom_max_distance。" }
if ($P.mapSpeedM -le 0 -or $P.mapSpeedJ -le 0) { throw "地图相机缩放速度必须大于 0。" }
if ($P.fade -lt 0) { throw "fade_seconds 不能为负数。" }
if ($P.mapPanMin -le 0 -or $P.mapPanMax -le 0 -or $P.mapPanMin -ge $P.mapPanMax) { throw "地图相机平移速度范围无效。" }

# ---------------- locate game ----------------
$game = Resolve-GameDir $GameDir $cfg.game_dir
if ($script:GameDirFromPrompt -and -not $cfg.game_dir) {
  try {
    $cfg.game_dir = $game
    ($cfg | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    Write-Host "已把游戏目录写入 config.json 的 game_dir，下次运行不再询问。" -ForegroundColor Green
  } catch {
    Write-Host "提示：可以把游戏目录手动写入 config.json 的 game_dir，下次就不再询问。" -ForegroundColor Yellow
  }
}
$level2 = Join-Path $game 'Flotsam_Data\level2'
Write-Host ""
Write-Host "游戏目录: $game"
Write-Host "场景文件: $level2"

$proc = Get-Process -Name Flotsam -ErrorAction SilentlyContinue
if ($proc) { throw "游戏正在运行，请先完全退出 Flotsam 再应用修改。" }

if (-not (Test-Path -LiteralPath $BackupFile)) {
  New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
  $currentBytes = [IO.File]::ReadAllBytes($level2)
  $currentText = $Encoder.GetString($currentBytes)
  # 首次运行：当前文件必须是未被本工具修改过的原版（用全部原始特征校验）
  $null = Find-UniqueOffset $currentText ([byte[]](New-FloatBytes 200.0) + [byte[]](New-FloatBytes 8.75) + [byte[]](New-FloatBytes 0.75) + [byte[]](New-FloatBytes 27.5) + [byte[]](New-FloatBytes 61.25)) 'CameraController 原始数据'
  [IO.File]::WriteAllBytes($BackupFile, $currentBytes)
  $sourceHash = Get-FileSha256 $level2
  $manifest = [pscustomobject]@{ game_dir = $game; source_sha256 = $sourceHash; last_applied_sha256 = '' }
  ($manifest | ConvertTo-Json) | Set-Content -LiteralPath $ManifestFile -Encoding UTF8
  Write-Host "已保存原版备份: $BackupFile"
} else {
  $sourceHash = Get-FileSha256 $BackupFile
  $currentHash = Get-FileSha256 $level2
  if (Test-Path -LiteralPath $ManifestFile) {
    try { $old = Get-Content -LiteralPath $ManifestFile -Raw | ConvertFrom-Json } catch { $old = $null }
    if ($old -and $old.source_sha256 -and $currentHash -ne $old.source_sha256 -and $currentHash -ne $old.last_applied_sha256) {
      if (-not $Force) {
        throw "当前 level2 既不是原版也不是本工具上次生成的文件（可能是游戏更新或其他工具修改过）。请先删除 backup 文件夹后重试，或加 -Force 参数强制以备份为基准。"
      }
      Write-Host "警告：当前文件状态未知，强制以备份为基准继续。" -ForegroundColor Yellow
    }
  }
}

# ---------------- build patch plan ----------------
$originalPan    = New-FloatBytes 200.0
$originalPitch  = Join-Bytes @((New-FloatBytes 27.5), (New-FloatBytes 61.25))

$plan = @(
  @{ Name = '主相机（平移/旋转/俯仰）'; Pattern = (Join-Bytes @($originalPan, (New-FloatBytes 8.75), (New-FloatBytes 0.75), $originalPitch)); Target = (Join-Bytes @((New-FloatBytes $P.pan), (New-FloatBytes $P.rotStep), (New-FloatBytes $P.rotSmooth), (New-FloatBytes $P.pitchMin), (New-FloatBytes $P.pitchMax))) },
  @{ Name = '主相机鼠标缩放设置'; Pattern = (Join-Bytes @((New-FloatBytes 0.0), (New-FloatBytes 15.0), (New-FloatBytes 130.0), (New-FloatBytes 7.5), (New-FloatBytes 0.75))); Target = (Join-Bytes @((New-FloatBytes 0.0), (New-FloatBytes $P.zoomMin), (New-FloatBytes $P.zoomMaxM), (New-FloatBytes $P.speedM), (New-FloatBytes $P.wait))) },
  @{ Name = '主相机手柄缩放设置'; Pattern = (Join-Bytes @((New-FloatBytes 0.0), (New-FloatBytes 15.0), (New-FloatBytes 100.0), (New-FloatBytes 1.0), (New-FloatBytes 1.0))); Target = (Join-Bytes @((New-FloatBytes 0.0), (New-FloatBytes $P.zoomMin), (New-FloatBytes $P.zoomMaxJ), (New-FloatBytes $P.speedJ), (New-FloatBytes $P.wait))) },
  @{ Name = '地图相机鼠标缩放设置'; Pattern = (Join-Bytes @((New-FloatBytes 0.3), (New-FloatBytes 500.0), (New-FloatBytes 1500.0), (New-FloatBytes 10.0), (New-FloatBytes 1.0))); Target = (Join-Bytes @((New-FloatBytes $P.mapInit), (New-FloatBytes $P.mapMin), (New-FloatBytes $P.mapMax), (New-FloatBytes $P.mapSpeedM), (New-FloatBytes $P.mapWait))) },
  @{ Name = '地图相机手柄缩放设置'; Pattern = (Join-Bytes @((New-FloatBytes 0.3), (New-FloatBytes 500.0), (New-FloatBytes 1500.0), (New-FloatBytes 5.0), (New-FloatBytes 1.0))); Target = (Join-Bytes @((New-FloatBytes $P.mapInit), (New-FloatBytes $P.mapMin), (New-FloatBytes $P.mapMax), (New-FloatBytes $P.mapSpeedJ), (New-FloatBytes $P.mapWait))) },
  @{ Name = '地图相机平移速度范围'; Pattern = (Join-Bytes @((New-FloatBytes 2.5), (New-IntBytes 200), (New-IntBytes 1000))); Target = (Join-Bytes @((New-FloatBytes 2.5), (New-IntBytes ([int]$P.mapPanMin)), (New-IntBytes ([int]$P.mapPanMax)))) },
  @{ Name = '地图打开/关闭淡入淡出时长'; Pattern = (Join-Bytes @((New-FloatBytes 0.05098039284348488), (New-FloatBytes 0.6509804129600525), (New-FloatBytes 0.8941176533699036), (New-FloatBytes 1.0), (New-FloatBytes 0.5))); Target = (Join-Bytes @((New-FloatBytes 0.05098039284348488), (New-FloatBytes 0.6509804129600525), (New-FloatBytes 0.8941176533699036), (New-FloatBytes 1.0), (New-FloatBytes $P.fade))) }
)

$baseBytes = [IO.File]::ReadAllBytes($BackupFile)
$baseText = $Encoder.GetString($baseBytes)
$patched = $baseBytes.Clone(); $patched = [byte[]]$patched
$replacements = @()

foreach ($item in $plan) {
  $offset = Find-UniqueOffset $baseText $item.Pattern $item.Name
  $replacements += [pscustomobject]@{ Name = $item.Name; Offset = $offset; Length = $item.Pattern.Length; Target = $item.Target }
}

# 确保各修改区间不重叠
$sorted = $replacements | Sort-Object Offset
for ($i = 1; $i -lt $sorted.Count; $i++) {
  if ($sorted[$i].Offset -lt ($sorted[$i - 1].Offset + $sorted[$i - 1].Length)) {
    throw "内部错误：修改区间重叠（$($sorted[$i - 1].Name) / $($sorted[$i].Name)）。"
  }
}

foreach ($r in $replacements) {
  [Array]::Copy($r.Target, 0, $patched, $r.Offset, $r.Target.Length)
}

# 写回前校验：发生变化的项，其旧值特征应全部消失
$patchedText = $Encoder.GetString($patched)
foreach ($item in $plan) {
  $changed = [Convert]::ToBase64String($item.Pattern) -ne [Convert]::ToBase64String($item.Target)
  if (-not $changed) { continue }
  $oldNeedle = $Encoder.GetString($item.Pattern)
  if ($patchedText.IndexOf($oldNeedle, [StringComparison]::Ordinal) -ge 0) {
    throw "内部错误：替换后仍检测到 [$($item.Name)] 的旧值。"
  }
}

try {
  [IO.File]::WriteAllBytes($level2, $patched)
} catch [System.UnauthorizedAccessException] {
  throw "没有权限写入游戏目录。请右键使用「以管理员身份运行」，或把游戏安装在可写目录。"
}

$newHash = Get-FileSha256 $level2
$manifest = $null
if (Test-Path -LiteralPath $ManifestFile) {
  try { $manifest = Get-Content -LiteralPath $ManifestFile -Raw | ConvertFrom-Json } catch { $manifest = $null }
}
if (-not $manifest) {
  $manifest = [pscustomobject]@{ game_dir = $game; source_sha256 = $sourceHash; last_applied_sha256 = '' }
}
$manifest.game_dir = $game
$manifest.last_applied_sha256 = $newHash
($manifest | ConvertTo-Json) | Set-Content -LiteralPath $ManifestFile -Encoding UTF8

Write-Host ""
Write-Host "================ 修改完成 ================" -ForegroundColor Green
$rows = @(
  @('主相机俯仰角', '27.5 – 61.25 度', "$($P.pitchMin) – $($P.pitchMax) 度"),
  @('主相机缩放距离（鼠标）', '15 – 130', "$($P.zoomMin) – $($P.zoomMaxM)"),
  @('主相机缩放距离（手柄）', '15 – 100', "$($P.zoomMin) – $($P.zoomMaxJ)"),
  @('主相机缩放速度（鼠标/手柄）', '7.5 / 1.0', "$($P.speedM) / $($P.speedJ)"),
  @('主相机到达极限后的等待', '0.75 / 1.0 秒', "$($P.wait) 秒"),
  @('地图相机缩放距离', '500 – 1500', "$($P.mapMin) – $($P.mapMax)"),
  @('地图相机默认缩放（0=最近）', '0.3', "$($P.mapInit)"),
  @('地图相机缩放速度（鼠标/手柄）', '10 / 5', "$($P.mapSpeedM) / $($P.mapSpeedJ)"),
  @('地图相机到达极限后的等待', '1.0 秒', "$($P.mapWait) 秒"),
  @('地图开关淡入淡出', '0.5 秒', "$($P.fade) 秒")
)
Write-Host ("{0,-26} {1,-18} {2}" -f '项目', '原值', '现在')
foreach ($r in $rows) { Write-Host ("{0,-26} {1,-18} {2}" -f $r[0], $r[1], $r[2]) }
Write-Host ""
Write-Host "新文件 SHA256: $newHash"
Write-Host "原版备份: $BackupFile"
Write-Host "请完全退出游戏后重新进入使其生效。" -ForegroundColor Yellow
