[CmdletBinding()]
param(
  [string]$GameDir = "",
  [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$script:GameDirFromPrompt = $false
$Root = Split-Path -Parent $PSScriptRoot
$BackupFile = Join-Path $Root 'backup\level2.original'
$ManifestFile = Join-Path $Root 'backup\manifest.json'
$ConfigPath = Join-Path $Root 'config.json'

function Test-GameDir([string]$Dir) {
  if (-not $Dir) { return $false }
  try {
    $lvl = [IO.Path]::Combine($Dir, 'Flotsam_Data', 'level2')
    return (Test-Path -LiteralPath $lvl -ErrorAction SilentlyContinue)
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

  $manifestDir = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'
  if (Test-Path -LiteralPath $manifestDir) {
    foreach ($f in Get-ChildItem -LiteralPath $manifestDir -Filter *.item -ErrorAction SilentlyContinue) {
      try {
        $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
        if ($j.DisplayName -eq 'Flotsam' -and $j.InstallLocation) { $candidates.Add($j.InstallLocation) }
      } catch { }
    }
  }

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
  throw "没有找到 Flotsam 安装目录。请用参数 -GameDir 指定游戏根目录（包含 Flotsam.exe 的文件夹），或在 config.json 的 game_dir 中填写；也可以重新运行后按提示输入路径。"
}

$cfgDir = ''
if (Test-Path -LiteralPath $ConfigPath) {
  try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if ($cfg.game_dir) { $cfgDir = $cfg.game_dir }
  } catch { }
}

if (-not (Test-Path -LiteralPath $BackupFile)) {
  throw "没有找到原版备份（$BackupFile）。如果没有用本工具修改过，可以直接用 Epic 的「验证文件完整性」恢复原版 level2。"
}

$game = Resolve-GameDir $GameDir $cfgDir
$level2 = Join-Path $game 'Flotsam_Data\level2'
Write-Host ""
Write-Host "游戏目录: $game"

$proc = Get-Process -Name Flotsam -ErrorAction SilentlyContinue
if ($proc) { throw "游戏正在运行，请先完全退出 Flotsam 再恢复。" }

Copy-Item -LiteralPath $BackupFile -Destination $level2 -Force
$hash = (Get-FileHash -LiteralPath $level2 -Algorithm SHA256).Hash

if (Test-Path -LiteralPath $ManifestFile) {
  try {
    $manifest = Get-Content -LiteralPath $ManifestFile -Raw | ConvertFrom-Json
    $manifest.game_dir = $game
    $manifest.last_applied_sha256 = $hash
    ($manifest | ConvertTo-Json) | Set-Content -LiteralPath $ManifestFile -Encoding UTF8
  } catch { }
}

Write-Host ""
Write-Host "================ 已恢复原版 ================" -ForegroundColor Green
Write-Host "level2 已还原，SHA256: $hash"
Write-Host "请完全退出游戏后重新进入使其生效。" -ForegroundColor Yellow
