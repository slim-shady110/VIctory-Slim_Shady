# VIctory-Slim_Shady — Universal RTX 3050 (4 GB VRAM) & NVIDIA DLSS + Frame Generation Launcher
#
# Works out of the box for anyone cloning the repo OR extracting a Release ZIP:
#   1. Finds victory.exe (from -Victory, .\target\release\victory.exe, beside the script, or builds via cargo if installed),
#   2. Auto-fetches NVIDIA Streamline v2.14.16 DLLs (~70 MB once) into nvidia-sdk\ if missing,
#   3. Inspects victory.exe's PE import table and installs the matching DLSSFG-TWEAK SM86 proxy DLL (`winmm.dll`)
#      + `dlssg_sm86\` + 4 GB–tuned `dlssg_sm86.ini` (2X FG, Preset C FG Lite, SM86 INT8 SR) if present or found in Downloads,
#   4. Isolates shader caches per victory.exe SHA-256 build hash (`cache\build-<hash>`), clears stale caches & DXCache,
#      and pre-compiles fresh shaders (`victory.exe shaders`) so old builds' shaders are NEVER reused,
#   5. Tunes VRAM & RAM budgets for 4 GB VRAM (~3.3 GB WDDM) + 24-32 GB RAM (768 MB target reserve instead of 3072 MB,
#      tiled mips on demand, 10s PSO wait so scene draws are never dropped -> no black screen).
#
# Usage (PowerShell, NOT as Administrator):
#   .\PLAY-RTX3050-FG.cmd
#   .\PLAY-RTX3050-FG.cmd -Exe "D:\GTA6\Game\game_scarlett_master.exe"
#   .\PLAY-RTX3050-FG.cmd -Dlss balanced
#   .\PLAY-RTX3050-FG.cmd -FrameGen Off
#   .\PLAY-RTX3050-FG.cmd -SeriesX             # For 8-24 GB GPUs
#   .\PLAY-RTX3050-FG.cmd -Fresh               # Rebuild isolated shader & driver DXCache from scratch
#   .\PLAY-RTX3050-FG.cmd -Check               # Dry-run diagnostics

param(
    [string]$Exe = '',
    [string]$Victory = '',
    [string]$TweakDir = '',
    [string]$CacheRoot = '',
    [ValidateSet('On', 'Ready', 'Off')]
    [string]$FrameGen = 'On',
    [ValidateSet('off', 'dlaa', 'quality', 'balanced', 'performance')]
    [string]$Dlss = 'performance',
    [ValidateRange(20, 1000)]
    [int]$Fps = 30,
    [switch]$SeriesX,
    [switch]$Fresh,
    [switch]$ClearDriverCache,
    [switch]$SkipPrecompile,
    [switch]$Warm,
    [switch]$SkipMovies,
    [switch]$Check,
    [hashtable]$More = @{}
)

$ErrorActionPreference = 'Stop'
$Game = 'game_scarlett_master.exe'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Get-PeImports([string]$pePath) {
    $bytes = [IO.File]::ReadAllBytes($pePath)
    $pe = [BitConverter]::ToInt32($bytes, 0x3C)
    $nSec = [BitConverter]::ToUInt16($bytes, $pe + 6)
    $optSize = [BitConverter]::ToUInt16($bytes, $pe + 20)
    $impRva = [BitConverter]::ToUInt32($bytes, $pe + 24 + 120)
    if ($impRva -eq 0) { return @() }
    $secOff = $pe + 24 + $optSize
    function RvaToOff([uint32]$rva) {
        for ($i = 0; $i -lt $nSec; $i++) {
            $s = $secOff + $i * 40
            $va = [BitConverter]::ToUInt32($bytes, $s + 12)
            $vs = [BitConverter]::ToUInt32($bytes, $s + 8)
            $raw = [BitConverter]::ToUInt32($bytes, $s + 20)
            if ($rva -ge $va -and $rva -lt ($va + $vs)) { return $raw + ($rva - $va) }
        }
        return 0
    }
    $off = RvaToOff $impRva
    $out = @()
    while ($off -gt 0 -and ($off + 20) -le $bytes.Length) {
        $nameRva = [BitConverter]::ToUInt32($bytes, $off + 12)
        if ($nameRva -eq 0) { break }
        $no = RvaToOff $nameRva
        $end = $no
        while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
        $out += [Text.Encoding]::ASCII.GetString($bytes, $no, $end - $no).ToLowerInvariant()
        $off += 20
    }
    return $out
}

if (Get-Process victory -ErrorAction SilentlyContinue) {
    Say "victory.exe is already running. Close it first." Red; exit 1
}

# 1. Locate or build victory.exe
if (-not $Victory) {
    $exeSearch = @(
        (Join-Path $repoRoot 'victory.exe'),
        (Join-Path $repoRoot 'target\release\victory.exe'),
        (Join-Path $repoRoot 'target\diag\victory.exe'),
        (Join-Path $repoRoot 'runtime-fg\victory.exe'),
        (Join-Path (Split-Path $repoRoot) 'VIctory-RTX3050-FG\victory.exe')
    )
    $Victory = ($exeSearch | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
}
if (-not $Victory -and -not $Check) {
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        Say "Building VIctory-Slim_Shady (cargo build --release -p victory)..." Cyan
        Push-Location $repoRoot
        try { cargo build --release --locked -p victory } finally { Pop-Location }
        if (Test-Path -LiteralPath (Join-Path $repoRoot 'target\release\victory.exe')) {
            $Victory = Join-Path $repoRoot 'target\release\victory.exe'
        }
    }
}
if (-not $Victory -or -not (Test-Path -LiteralPath $Victory)) {
    Say "victory.exe not built yet. Download the prebuilt Release ZIP from GitHub Releases or run 'cargo build --release -p victory'." Red
    exit 1
}
$Victory = (Resolve-Path -LiteralPath $Victory).Path
$victoryDir = Split-Path $Victory

# 2. Locate game_scarlett_master.exe
if (-not $Exe) {
    $candidates = @(
        (Join-Path $victoryDir $Game),
        (Join-Path $repoRoot $Game),
        (Join-Path (Get-Location) $Game)
    )
    foreach ($drv in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'C' })) {
        foreach ($sub in @('GTA6\Game', 'GTA6_Xbox\Game', 'Games\GTA6\Game', 'Game')) {
            $candidates += (Join-Path $drv.Root "$sub\$Game")
        }
    }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            $d = Split-Path $c
            if (Get-ChildItem -LiteralPath $d -Recurse -Depth 2 -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.rpf', '.xvd' } | Select-Object -First 1) {
                $Exe = $c; break
            }
        }
    }
    if (-not $Exe) {
        foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { $Exe = $c; break } }
    }
    if (-not $Exe -and -not $Check) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Title = "Select $Game (your GTA VI dump folder)"
            $dlg.Filter = "$Game|$Game|Executable (*.exe)|*.exe"
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $Exe = $dlg.FileName }
        } catch {}
    }
}
if (-not $Exe -or -not (Test-Path -LiteralPath $Exe)) {
    Say "Could not find $Game. Pass -Exe '<your dump>\$Game'." Red; exit 1
}
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$gameDir = Split-Path $Exe
$hasArchives = [bool](Get-ChildItem -LiteralPath $gameDir -Recurse -Depth 2 -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.rpf', '.xvd' } | Select-Object -First 1)

# 3. Inspect PE import table so DLSSFG-TWEAK uses the exact imported DLL (winmm.dll for VIctory)
$imports = Get-PeImports $Victory
$proxyOrder = @('version.dll', 'winmm.dll', 'dbghelp.dll', 'dinput8.dll', 'dxgi.dll', 'd3d12.dll')
$chosenProxy = ($proxyOrder | Where-Object { $imports -contains $_ } | Select-Object -First 1)
if (-not $chosenProxy) { $chosenProxy = 'winmm.dll' }

if (-not $CacheRoot) { $CacheRoot = Join-Path $victoryDir 'cache' }
$build = (Get-FileHash -LiteralPath $Victory -Algorithm SHA256).Hash.Substring(0, 16).ToLower()
$cacheDir = Join-Path $CacheRoot "build-$build"
$dataDir  = Join-Path $victoryDir 'data'
$slRoot   = Join-Path $victoryDir 'nvidia-sdk'
$slDir    = Join-Path $slRoot 'Streamline\bin\x64'
if (-not (Test-Path -LiteralPath (Join-Path $slDir 'sl.interposer.dll')) -and (Test-Path -LiteralPath (Join-Path $repoRoot 'nvidia-sdk\Streamline\bin\x64\sl.interposer.dll'))) {
    $slRoot = Join-Path $repoRoot 'nvidia-sdk'
    $slDir  = Join-Path $slRoot 'Streamline\bin\x64'
}
$shadersOk = Test-Path -LiteralPath (Join-Path $cacheDir '.shaders-built')

Say "== VIctory-Slim_Shady RTX 3050 / NVIDIA FrameGen Launcher ==" Cyan
Say "victory.exe : $Victory (build $build, proxy: $chosenProxy)"
Say "game        : $Exe $(if ($hasArchives) { '(archives found)' } else { '(WARNING: no .rpf/.xvd found in this folder)' })"
Say "Streamline  : $(if (Test-Path -LiteralPath (Join-Path $slDir 'sl.interposer.dll')) { 'present' } else { 'will fetch once (~70 MB)' })"
Say "FG proxy    : $(if (Test-Path -LiteralPath (Join-Path $victoryDir $chosenProxy)) { "$chosenProxy installed beside victory.exe" } else { 'will check TweakDir / Downloads' })"
Say "shader cache: $cacheDir $(if ($shadersOk -and -not $Fresh) { '(ready)' } else { '(fresh compile on start)' })"
Say "mode        : $(if ($SeriesX) { 'Series X' } else { 'Series S (4 GB VRAM sweet spot)' }) | DLSS $Dlss | Base $Fps FPS | FrameGen $FrameGen"
if ($Check) { exit 0 }

# 4. Pin victory.exe to High-Performance NVIDIA GPU (prevents hybrid laptops picking iGPU)
$prefKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
if (-not (Test-Path $prefKey)) { New-Item -Path $prefKey -Force | Out-Null }
Set-ItemProperty -Path $prefKey -Name $Victory -Value 'GpuPreference=2;'

# 5. Fetch NVIDIA Streamline if needed
if ($Dlss -ne 'off' -and -not (Test-Path -LiteralPath (Join-Path $slDir 'sl.interposer.dll'))) {
    $fetcher = Join-Path $PSScriptRoot 'get-nvidia-sdks.ps1'
    if (Test-Path -LiteralPath $fetcher) {
        Say "Fetching official NVIDIA Streamline DLLs (~70 MB, once)..." Cyan
        & $fetcher -To $slRoot
    }
}

# 6. Install DLSSFG-TWEAK beside victory.exe (RTX 20/30 SM75/SM86 FrameGen unlocker)
if ($FrameGen -ne 'Off') {
    foreach ($other in ($proxyOrder | Where-Object { $_ -ne $chosenProxy })) {
        $otherPath = Join-Path $victoryDir $other
        if (Test-Path -LiteralPath $otherPath) { Remove-Item -LiteralPath $otherPath -Force -ErrorAction SilentlyContinue }
    }
    $searchDirs = @()
    if ($TweakDir) { $searchDirs += $TweakDir }
    $dl = Join-Path $env:USERPROFILE 'Downloads'
    $searchDirs += @(
        (Join-Path $dl 'DLSSFG-TWEAK'),
        (Join-Path $dl 'dlssg-release-0.4.0-x64'),
        (Join-Path (Split-Path $repoRoot) 'VIctory-RTX3050-FG')
    )
    $proxyDest = Join-Path $victoryDir $chosenProxy
    if (-not (Test-Path -LiteralPath $proxyDest)) {
        $proxySrc = ($searchDirs | ForEach-Object {
            (Join-Path $_ $chosenProxy), (Join-Path $_ "alternatives\$chosenProxy")
        } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
        if ($proxySrc) {
            Copy-Item -LiteralPath $proxySrc -Destination $proxyDest -Force
            Say "Installed DLSSFG-TWEAK proxy '$chosenProxy' beside victory.exe." Green
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $victoryDir 'dlssg_sm86'))) {
        $bundleSrc = ($searchDirs | ForEach-Object { Join-Path $_ 'dlssg_sm86' } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
        if ($bundleSrc) {
            Copy-Item -LiteralPath $bundleSrc -Destination $victoryDir -Recurse -Force
        }
    }
    $ini = Join-Path $victoryDir 'dlssg_sm86.ini'
    if ((Test-Path -LiteralPath (Join-Path $victoryDir 'dlssg_sm86')) -and -not (Test-Path -LiteralPath $ini)) {
        @"
[General]
Enabled=1

[FrameGeneration]
Engine=DLSS
MaxGeneratedFrames=1

[DLSSG]
Optimized=2
Preset=C

[Logging]
Level=1
Directory=dlssg_sm86\logs

[Runtime]
Mode=Bundled

[SuperResolution]
Mode=On
"@ | Set-Content -LiteralPath $ini -Encoding UTF8
    }
}

# 7. Per-build shader cache isolation + fresh shader compile
New-Item -ItemType Directory -Force -Path $CacheRoot, $dataDir | Out-Null
if ($Fresh -and (Test-Path -LiteralPath $cacheDir)) {
    Remove-Item -LiteralPath $cacheDir -Recurse -Force
    $shadersOk = $false
}
Get-ChildItem -LiteralPath $CacheRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'build-*' -and $_.Name -ne "build-$build" } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}
$home = Join-Path $env:LOCALAPPDATA 'victory'
if (Test-Path -LiteralPath (Join-Path $home 'cache')) {
    Remove-Item -LiteralPath (Join-Path $home 'cache') -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

if ($ClearDriverCache -or -not (Test-Path -LiteralPath (Join-Path $cacheDir '.dxcache-cleared'))) {
    $menuFile = Join-Path $home 'victory-settings.txt'
    if (Test-Path -LiteralPath $menuFile) {
        Move-Item -LiteralPath $menuFile -Destination "$menuFile.$(Get-Date -Format yyyyMMdd-HHmmss).bak" -Force
    }
    $dx = Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'
    if (Test-Path -LiteralPath $dx) {
        Get-ChildItem -LiteralPath $dx -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Set-Content -LiteralPath (Join-Path $cacheDir '.dxcache-cleared') -Value $build -Encoding ASCII
}

Get-ChildItem Env:VICTORY_* -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item "Env:$($_.Name)" -ErrorAction SilentlyContinue }
$env:VICTORY_GAME_DIR  = $gameDir
$env:VICTORY_CACHE_DIR = $cacheDir
$env:VICTORY_DATA_DIR  = $dataDir
if (Test-Path -LiteralPath (Join-Path $slDir 'sl.interposer.dll')) {
    $env:VICTORY_STREAMLINE_DIR = $slDir
}

$jobs = [math]::Max(2, [Environment]::ProcessorCount - 2)
if (-not $shadersOk -and -not $SkipPrecompile -and $hasArchives) {
    $src = Join-Path $gameDir 'shaders.rpf'
    if (-not (Test-Path -LiteralPath $src)) { $src = $gameDir }
    Say "Pre-compiling fresh shaders for build $build..." Cyan
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $Victory shaders $src --jobs $jobs
    if ($LASTEXITCODE -eq 0) {
        Set-Content -LiteralPath (Join-Path $cacheDir '.shaders-built') -Value "$(Get-Date -Format o)" -Encoding ASCII
    }
    $ErrorActionPreference = $prev
}
if ($Warm) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $Victory warm --used --jobs ([math]::Max(2, [int]($jobs / 2)))
    $ErrorActionPreference = $prev
}

# 8. Tuned 4 GB VRAM (~3.3 GB WDDM) + 24-32 GB DDR4 Settings
$room = switch ($FrameGen) { 'On' { '68' } 'Ready' { '76' } default { '84' } }
$set = [ordered]@{
    VICTORY_LEVELS_ON_DEMAND         = '1'
    VICTORY_CARD_ROOM_FOR_TARGETS_MB = if ($SeriesX) { '1024' } else { '768' }
    VICTORY_TEXTURE_ROOM_PERCENT     = $room
    VICTORY_CARD_BUFFERS_MIN_KB      = '1024'
    VICTORY_CARD_BUFFERS_MB          = '320'
    VICTORY_CARD_WINDOWS_MB          = '0'
    VICTORY_FRAMEGEN_HUDLESS         = '0'
    VICTORY_ASYNC_SUBMIT             = '1'
    VICTORY_PIPELINE_WAIT_MS         = '10000'
    VICTORY_PIPELINE_WORKERS         = '6'
    VICTORY_JOIN_PARTS               = '6'
    VICTORY_DYNAMIC_SLOTS            = '524288'
    VICTORY_F16_NEAREST              = '1'
}
if ($SkipMovies) { $set['VICTORY_SKIP_BINK'] = '1' }
foreach ($k in $More.Keys) { $set[$k] = [string]$More[$k] }

$runArgs = @('play', $Exe, '--dlss', $Dlss, '--fps', "$Fps")
if (-not $SeriesX) { $runArgs += '--series-s' }
switch ($FrameGen) {
    'On'  { $runArgs += @('--framegen', '2') }
    'Off' { $runArgs += '--no-framegen-ready' }
}
foreach ($k in $set.Keys) { $runArgs += @('--set', "$k=$($set[$k])") }

Say "Starting VIctory-Slim_Shady [F1 = Settings Menu | F3 = FPS/FrameGen/VRAM Panel]..." Cyan
Push-Location $victoryDir
try {
    $ErrorActionPreference = 'Continue'
    & $Victory @runArgs
} finally {
    Pop-Location
}
