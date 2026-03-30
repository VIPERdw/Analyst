$host.ui.RawUI.WindowTitle = "Analyse Starter - V!PER"
Clear-Host

Write-Host ""
Write-Host -ForegroundColor Magenta @"
██╗   ██╗██╗██████╗ ███████╗██████╗ 
██║   ██║██║██╔══██╗██╔════╝██╔══██╗
██║   ██║██║██████╔╝█████╗  ██████╔╝
╚██╗ ██╔╝██║██╔═══╝ ██╔══╝  ██╔═══╝ 
 ╚████╔╝ ██║██║     ███████╗██║     
  ╚═══╝  ╚═╝╚═╝     ╚══════╝╚═╝     
V!PER
"@


$browserQueries = @(
    "brave.exe","chrome.exe","firefox.exe","msedge.exe","opera.exe",
    "operagx.exe","safari.exe","tor.exe","avastbrowser.exe","vivaldi.exe",
    "maxthon.exe","iexplore.exe","chromium.exe","epicbrowser.exe","yandex.exe",
    "seamonkey.exe","palemoon.exe","waterfox.exe","lunascape.exe",
    "comodo_dragon.exe","slimbrowser.exe","mullvadbrowser.exe"
)

$discordQueries = @("Discord.exe","DiscordPTB.exe","DiscordCanary.exe")

# FIX: Map queries to actual process names to prevent duplicate launches or false negatives
$processNameMap = @{
    "operagx.exe"        = "opera"
    "tor.exe"            = "firefox"
    "mullvadbrowser.exe" = "firefox"
    "avastbrowser.exe"   = "AvastBrowser"
    "epicbrowser.exe"    = "epic"
}

# FIX: Added LocalAppData\Programs (common for new installations) and direct EXE paths
$extraCandidates = @{
  "opera.exe"          = @("$env:LocalAppData\Programs\Opera\opera.exe", "$env:ProgramFiles\Opera\opera.exe")
  "operagx.exe"        = @("$env:LocalAppData\Programs\Opera GX\opera.exe", "$env:ProgramFiles\Opera GX\opera.exe")
  "yandex.exe"         = @("$env:LocalAppData\Yandex\YandexBrowser\Application\browser.exe")
  "epicbrowser.exe"    = @("$env:LocalAppData\Epic Privacy Browser\Application\epic.exe")
  "tor.exe"            = @("$env:Desktop\Tor Browser\Browser\firefox.exe", "$env:LocalAppData\Tor Browser\Browser\firefox.exe")
  "mullvadbrowser.exe" = @("$env:ProgramFiles\Mullvad Browser\Browser\firefox.exe")
}

# -------------------- Helpers --------------------

# FIX: Robustly find the latest Discord version folder instead of using problematic wildcards
function Get-DiscordPath {
    param([string]$BaseDirName, [string]$ExeName)
    $discordPath = Join-Path $env:LocalAppData $BaseDirName
    if (Test-Path $discordPath) {
        $appDirs = Get-ChildItem -Path $discordPath -Filter "app-*" -Directory | Sort-Object Name -Descending
        if ($appDirs.Count -gt 0) {
            $exePath = Join-Path $appDirs[0].FullName $ExeName
            if (Test-Path $exePath) { return $exePath }
        }
    }
    return $null
}

function Get-AppPathFromRegistry {
  param([Parameter(Mandatory=$true)][string]$ExecutableName)
  $regKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExecutableName",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\$ExecutableName",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExecutableName"
  )
  foreach ($key in $regKeys) {
    if (Test-Path -LiteralPath $key) {
      try {
        $item = Get-Item -LiteralPath $key -ErrorAction SilentlyContinue
        $defaultPath = $item.GetValue('')
        if ($defaultPath -and (Test-Path -LiteralPath $defaultPath)) { return $defaultPath }
      } catch { }
    }
  }
  return $null
}

function Resolve-AppPath {
  param([Parameter(Mandatory=$true)][string]$ExecutableName)

  # 1) Try Discord Dynamic Resolution first
  if ($ExecutableName -eq "Discord.exe")       { $d = Get-DiscordPath "Discord" "Discord.exe"; if($d){ return $d } }
  if ($ExecutableName -eq "DiscordPTB.exe")    { $d = Get-DiscordPath "DiscordPTB" "DiscordPTB.exe"; if($d){ return $d } }
  if ($ExecutableName -eq "DiscordCanary.exe") { $d = Get-DiscordPath "DiscordCanary" "DiscordCanary.exe"; if($d){ return $d } }

  # 2) Try Registry (Most reliable for installed browsers)
  $regPath = Get-AppPathFromRegistry -ExecutableName $ExecutableName
  if ($regPath) { return $regPath }

  # 3) Try Fallbacks
  if ($extraCandidates.ContainsKey($ExecutableName)) {
    foreach ($cand in $extraCandidates[$ExecutableName]) {
      $expanded = [Environment]::ExpandEnvironmentVariables($cand)
      if (Test-Path -LiteralPath $expanded) { return $expanded }
    }
  }

  return $null
}

function Is-ProcessRunning {
  param([Parameter(Mandatory=$true)][string]$ExecutableName, [string]$ResolvedPath)
  
  # Determine correct process name
  $procName = [System.IO.Path]::GetFileNameWithoutExtension($ExecutableName)
  if ($processNameMap.ContainsKey($ExecutableName)) {
      $procName = $processNameMap[$ExecutableName]
  }

  try { 
      $runningProcs = Get-Process -Name $procName -ErrorAction SilentlyContinue
      if (-not $runningProcs) { return $false }

      # FIX: For processes like Firefox (used by Tor/Mullvad), check if the running process matches our path
      if ($ResolvedPath) {
          foreach ($p in $runningProcs) {
              if ($p.Path -and $p.Path -eq $ResolvedPath) {
                  return $true
              }
          }
          # Process is running, but from a different path (e.g., normal Firefox is running, but we want to start Tor)
          return $false
      }
      return $true 
  } catch { 
      return $false 
  }
}

function Start-AppIfAvailable {
  param([Parameter(Mandatory=$true)][string]$ExecutableName)

  # Resolve the exact path first so we can check it properly
  $path = Resolve-AppPath -ExecutableName $ExecutableName

  if (-not $path) {
      # We don't print a red fail message for every missing browser to keep the console clean,
      # but you can uncomment the next line if you want to see what's missing.
      # Write-Host "[----] Not installed: $ExecutableName" -ForegroundColor DarkGray
      return $false
  }

  if (Is-ProcessRunning -ExecutableName $ExecutableName -ResolvedPath $path) {
    Write-Host "[SKIP] Already running: $ExecutableName" -ForegroundColor Yellow
    return $true
  }

  # We found the path and it's not running, so start it
  try {
    Start-Process -FilePath $path -ErrorAction Stop | Out-Null
    Write-Host "[ OK ] Launched: $ExecutableName" -ForegroundColor Green
    
    # FIX: Give the system 500ms to breathe so CPU doesn't max out opening 10 browsers
    Start-Sleep -Milliseconds 500 
    return $true
  } catch {
    Write-Host "[FAIL] Couldn't start: $ExecutableName" -ForegroundColor Red
    return $false
  }
}

# -------------------- Main --------------------

Write-Host "=== Launching Browsers ==="
$browserLaunched = 0
foreach ($exe in $browserQueries) {
  if (Start-AppIfAvailable -ExecutableName $exe) { $browserLaunched++ }
}

Write-Host "`n=== Launching Discord Variants ==="
$discordLaunched = 0
foreach ($exe in $discordQueries) {
  if (Start-AppIfAvailable -ExecutableName $exe) { $discordLaunched++ }
}

Write-Host "`n=== Summary ==="
Write-Host ("Browsers launched/running: {0}/{1}" -f $browserLaunched, $browserQueries.Count) -ForegroundColor Cyan
Write-Host ("Discord launched/running:  {0}/{1}"  -f $discordLaunched, $discordQueries.Count) -ForegroundColor Cyan
Write-Host ""
