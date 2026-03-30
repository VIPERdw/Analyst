$host.ui.RawUI.WindowTitle = "CHH Viewer - Made by V!PER"
Clear-Host
Write-Host ""
Write-Host -ForegroundColor Magenta @"
  ██╗   ██╗██╗██████╗ ███████╗██████╗      ██████╗██╗  ██╗██╗  ██╗
  ██║   ██║██║██╔══██╗██╔════╝██╔══██╗    ██╔════╝██║  ██║██║  ██║
  ██║   ██║██║██████╔╝█████╗  ██████╔╝    ██║     ███████║███████║
  ╚██╗ ██╔╝██║██╔═══╝ ██╔══╝  ██╔══██╗    ██║     ██╔══██║██╔══██║
   ╚████╔╝ ██║██║     ███████╗██║  ██║    ╚██████╗██║  ██║██║  ██║
    ╚═══╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝
"@

Write-Host -ForegroundColor White "                         Made by " -NoNewLine
Write-Host -ForegroundColor Magenta "V!PER"
Write-Host -ForegroundColor DarkGray "              ──────────────────────────────────────────"
Write-Host ""

# ──────────────────────────────────────────────────────────────────────────────
# Helper: Alle PSReadLine-History-Dateien einsammeln
# ──────────────────────────────────────────────────────────────────────────────
function Get-AllHistoryFiles {
    $paths = [System.Collections.Generic.List[string]]::new()

    # 1) Aktuell aktiver Pfad laut PSReadLine (zuverlässigster Weg)
    try {
        $livePath = (Get-PSReadLineOption).HistorySavePath
        if ($livePath -and (Test-Path $livePath)) { $paths.Add($livePath) }
    } catch {}

    # 2) Bekannte Standard-Pfade (als Fallback / zusätzliche Hosts)
    $knownPaths = @(
        # Windows PowerShell 5 – ConsoleHost
        [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'),
        # Windows PowerShell 5 – ISE Host
        [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\PowerShell\PSReadLine\Windows Powershell ISE Host_history.txt'),
        # PowerShell 7 / Core
        [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\PowerShell\PSReadLine\Microsoft.PowerShell_profile.ps1_history.txt'),
        [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft\PowerShell\PSReadLine\ConsoleHost_history.txt'),
        # VS Code integriertes Terminal
        [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\PowerShell\PSReadLine\Visual Studio Code Host_history.txt')
    )

    foreach ($p in $knownPaths) {
        if ($p -and (Test-Path $p) -and -not $paths.Contains($p)) {
            $paths.Add($p)
        }
    }

    return $paths
}

# ──────────────────────────────────────────────────────────────────────────────
# History aus einer Datei lesen und als Objekte zurückgeben
# ──────────────────────────────────────────────────────────────────────────────
function Read-HistoryFile {
    param(
        [string]$Path,
        [string]$SourceLabel
    )

    try {
        $lines = Get-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
        if (-not $lines -or $lines.Count -eq 0) {
            Write-Host "  [LEER] $SourceLabel" -ForegroundColor Yellow
            return @()
        }

        $index = 0
        $result = foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -ne '') {
                $index++
                [PSCustomObject]@{
                    '#'      = $index
                    Befehl   = $line
                    Länge    = $line.Length
                    Quelle   = $SourceLabel
                }
            }
        }
        return $result
    } catch {
        Write-Host "  [FEHLER] $SourceLabel – $_" -ForegroundColor Red
        return @()
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Export-Funktion
# ──────────────────────────────────────────────────────────────────────────────
function Export-History {
    param([array]$Data)

    if (-not $Data -or $Data.Count -eq 0) {
        Write-Host "`n  Keine Daten zum Exportieren." -ForegroundColor Yellow
        return
    }

    Write-Host "`n  Export-Format wählen:" -ForegroundColor Cyan
    Write-Host "  [1] CSV   [2] TXT   [3] Abbrechen" -ForegroundColor White
    $choice = Read-Host "  Auswahl"

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $desktop    = [System.Environment]::GetFolderPath('Desktop')

    switch ($choice) {
        '1' {
            $outPath = Join-Path $desktop "PSHistory_$timestamp.csv"
            $Data | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
            Write-Host "  ✔ CSV gespeichert: $outPath" -ForegroundColor Green
        }
        '2' {
            $outPath = Join-Path $desktop "PSHistory_$timestamp.txt"
            $Data | ForEach-Object { $_.Befehl } | Out-File -FilePath $outPath -Encoding UTF8
            Write-Host "  ✔ TXT gespeichert: $outPath" -ForegroundColor Green
        }
        default {
            Write-Host "  Export abgebrochen." -ForegroundColor DarkGray
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────

$historyFiles = Get-AllHistoryFiles

if ($historyFiles.Count -eq 0) {
    Write-Host " Keine History-Dateien gefunden." -ForegroundColor Red
    Start-Sleep 5
    Exit
}

Write-Host " Gefundene History-Dateien:" -ForegroundColor Cyan
foreach ($f in $historyFiles) {
    Write-Host "  → $f" -ForegroundColor DarkGray
}
Write-Host ""

# Alle Einträge einlesen
$allEntries = [System.Collections.Generic.List[object]]::new()

foreach ($file in $historyFiles) {
    $label = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $entries = Read-HistoryFile -Path $file -SourceLabel $label
    if ($entries) {
        Write-Host "  [OK] $label – $($entries.Count) Einträge" -ForegroundColor Green
        foreach ($e in $entries) { $allEntries.Add($e) }
    }
}

Write-Host ""
Write-Host " Gesamt: $($allEntries.Count) Einträge aus $($historyFiles.Count) Datei(en)" -ForegroundColor Cyan

# Duplikate markieren
$cmdCounts = @{}
foreach ($e in $allEntries) { $cmdCounts[$e.Befehl] = ($cmdCounts[$e.Befehl] -as [int]) + 1 }
$allEntries | ForEach-Object {
    $_ | Add-Member -NotePropertyName 'Duplikate' -NotePropertyValue $cmdCounts[$_.Befehl] -Force
}

# Statistik
$uniqueCount    = ($allEntries | Select-Object -ExpandProperty Befehl -Unique).Count
$dupCount       = ($allEntries | Where-Object { $_.Duplikate -gt 1 }).Count
$longestCmd     = $allEntries | Sort-Object Länge -Descending | Select-Object -First 1

Write-Host ""
Write-Host " ┌─ Statistik ────────────────────────────────────────" -ForegroundColor DarkMagenta
Write-Host " │  Einzigartige Befehle : $uniqueCount" -ForegroundColor White
Write-Host " │  Mehrfach ausgeführt  : $dupCount" -ForegroundColor White
if ($longestCmd) {
Write-Host " │  Längster Befehl      : $($longestCmd.Länge) Zeichen – '$($longestCmd.Befehl.Substring(0, [Math]::Min(60,$longestCmd.Länge)))...'" -ForegroundColor White
}
Write-Host " └────────────────────────────────────────────────────" -ForegroundColor DarkMagenta
Write-Host ""

# ── Menü ──────────────────────────────────────────────────────────────────────
Write-Host " Optionen:" -ForegroundColor Cyan
Write-Host "  [1] Gesamte History anzeigen (alle Quellen kombiniert)"
Write-Host "  [2] Pro Quelle einzeln anzeigen"
Write-Host "  [3] Nur Duplikate anzeigen"
Write-Host "  [4] History exportieren (CSV / TXT)"
Write-Host "  [5] Beenden"
Write-Host ""

$choice = Read-Host " Auswahl"

switch ($choice) {
    '1' {
        $allEntries | Out-GridView -Title "Gesamte PowerShell History – $env:USERNAME ($($allEntries.Count) Einträge)"
    }
    '2' {
        foreach ($file in $historyFiles) {
            $label = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $subset = $allEntries | Where-Object { $_.Quelle -eq $label }
            if ($subset) {
                $subset | Out-GridView -Title "$label – $env:USERNAME ($($subset.Count) Einträge)"
            }
        }
    }
    '3' {
        $dups = $allEntries | Where-Object { $_.Duplikate -gt 1 } | Sort-Object Duplikate -Descending
        if ($dups) {
            $dups | Out-GridView -Title "Duplikate – $env:USERNAME ($($dups.Count) Einträge)"
        } else {
            Write-Host " Keine Duplikate gefunden." -ForegroundColor Yellow
        }
    }
    '4' {
        Export-History -Data $allEntries
    }
    default {
        Write-Host " Auf Wiedersehen!" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host " Fertig. Drücke eine Taste zum Beenden..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")