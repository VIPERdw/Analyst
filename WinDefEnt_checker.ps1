#Requires -Version 5.1
$host.ui.RawUI.WindowTitle = "Windows Defender Event Viewer - Made by flomkk"
Clear-Host
Write-Host ""
Write-Host -ForegroundColor Magenta @"
   ███╗   ██╗ █████╗ ██████╗  ██████╗ ██████╗      ██████╗██╗████████╗██╗   ██╗
   ████╗  ██║██╔══██╗██╔══██╗██╔════╝██╔═══██╗    ██╔════╝██║╚══██╔══╝╚██╗ ██╔╝
   ██╔██╗ ██║███████║██████╔╝██║     ██║   ██║    ██║     ██║   ██║    ╚████╔╝
   ██║╚██╗██║██╔══██║██╔══██╗██║     ██║   ██║    ██║     ██║   ██║     ╚██╔╝
   ██║ ╚████║██║  ██║██║  ██║╚██████╗╚██████╔╝    ╚██████╗██║   ██║      ██║
   ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝      ╚═════╝╚═╝   ╚═╝      ╚═╝
"@
Write-Host -ForegroundColor White "                    Made by flomkk - " -NoNewLine
Write-Host -ForegroundColor Cyan "discord.gg/narcocity"
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# KONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

# [NEU #4] Wenn $true: Nur kritische/verdächtige Events werden angezeigt.
# Standard-Events wie Dienst gestartet (5000), normale Signatur-Updates werden ausgeblendet.
$ShowOnlySuspicious = $true

# Zeitfenster (Minuten) für Korrelation um Event 2003 (Schutz deaktiviert)
$CorrelationWindowMinutes = 2

# Bekannte Cheat-/Inject-Keywords für FiveM (Pfade, Namen, Signaturen)
$CHEAT_KEYWORDS = @(
    # Generische Injector / Cheat-Begriffe
    'inject','injector','loader','trainer','hack','cheat','exploit','bypass',
    'eulen','aimbot','esp','wallhack','spinbot','triggerbot','norecoil',
    'bhop','bunnyhop','speedhack','teleport','godmode','noclip','moneyspam',
    'lua executor','executor','luaexec','autoclicker',
    # Bekannte FiveM-Cheat-Namen / Familien
    'eulen','redengine','celestial','force','euphoria','cherax','lynx',
    'modest menu','kiddions','stand','paragon','impulse','midnight',
    'prodigy','mango','phantom-x','2take1','brutan','reign','rp_cheat',
    # Injektions-Tools
    'xenos','extreme injector','process hacker','cheatengine','cheat engine',
    'x64dbg','ollydbg','ida pro','ce.exe','processhacker',
    # Verdächtige Endungen / Muster
    '\.asi$','\.dinput8\.dll$','ScriptHookV','ScriptHookVDotNet',
    'CitizenFX_BYPASS','fivem_bypass','fivem-bypass',
    # Temp / obfuskierte Pfade die Cheats nutzen
    '\\AppData\\Local\\Temp\\[a-f0-9]{8,}',
    '\\AppData\\Roaming\\[a-f0-9]{8,}',
    '\\ProgramData\\[a-f0-9]{8,}'
)

# [NEU #4] Event-IDs, die als "harmlos" grundsätzlich ausgeblendet werden (wenn $ShowOnlySuspicious = $true)
# 5000 = Dienst gestartet (normaler Betrieb)
# 2001 = Echtzeitscan-Update (normaler Betrieb)
$NOISE_EVENT_IDS = @(5000, 2001)

# Event-IDs mit Beschreibung
# 1006 = Malware-Scan abgeschlossen (Fund)
# 1007 = Aktion nach Erkennung
# 1008 = Aktion fehlgeschlagen
# 1009 = Quarantäne wiederhergestellt (!)
# 1013 = Verlaufselement gelöscht (!)
# 1015 = Verdächtiges Verhalten erkannt
# 1116 = Threat erkannt
# 1117 = Threat-Aktion ausgeführt
# 1118 = Threat-Bereinigung fehlgeschlagen
# 1119 = Threat-Bereinigung erfolgreich
# 2001 = Echtzeitscan-Update Start
# 2003 = Echtzeitscan deaktiviert  ← KRITISCH
# 2004 = Echtzeitschutz Regel-Änderung
# 5000 = Defender-Dienst gestartet
# 5001 = Defender-Dienst gestoppt
# 5004 = Echtzeitscan Konfiguration geändert
# 5007 = Konfigurationsänderung (Exclusions!)
# 5010 = Scan nach Malware deaktiviert
# 5012 = Defender-Komponente deaktiviert
$ALL_EVENT_IDS = @(1006,1007,1008,1009,1013,1015,1116,1117,1118,1119,2001,2003,2004,5000,5001,5004,5007,5010,5012)

$LOG_NAME = 'Microsoft-Windows-Windows Defender/Operational'

# ─────────────────────────────────────────────────────────────────────────────
# HILFSFUNKTIONEN
# ─────────────────────────────────────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor DarkMagenta
    Write-Host "  $Text" -ForegroundColor Magenta
    Write-Host ("=" * 80) -ForegroundColor DarkMagenta
}

function Write-Row {
    param(
        [string]$Time,
        [string]$EventID,
        [string]$Type,
        [string]$Message,
        [ConsoleColor]$Color = 'White',
        [switch]$Flagged,
        [string]$MatchKeyword = ""   # [NEU #5] Zeigt das gematchte Keyword an
    )
    $prefix = if ($Flagged) { "[!!!] " } else { "      " }
    $line = "{0}{1,-20} [{2,-4}] {3,-22} {4}" -f $prefix, $Time, $EventID, $Type, $Message
    Write-Host $line -ForegroundColor $Color
    if ($Flagged) {
        $susLine = "       >>> VERDÄCHTIG: Möglicher Cheat-Bezug"
        if ($MatchKeyword) { $susLine += " | Match: `"$MatchKeyword`"" }
        $susLine += " <<<"
        Write-Host $susLine -ForegroundColor Yellow
    }
}

# [NEU #5] Gibt das erste matchende Keyword zurück (statt nur $true/$false)
function Get-CheatMatch {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    foreach ($kw in $CHEAT_KEYWORDS) {
        if ($Text -match $kw) { return $kw }
    }
    return $null
}

function Test-CheatMatch {
    param([string]$Text)
    return ($null -ne (Get-CheatMatch -Text $Text))
}

function Get-XmlData {
    param([xml]$Xml, [string]$FieldName)
    $node = $Xml.Event.EventData.Data | Where-Object { $_.Name -eq $FieldName }
    if ($node) { return $node.'#text' }
    return $null
}

function Extract-ThreatPath {
    param([string]$RawPath)
    if ([string]::IsNullOrWhiteSpace($RawPath)) { return $null }
    if ($RawPath -match '^file:_(.+)$') { return $matches[1].Trim() }
    if ($RawPath -match '^(.+)$')       { return $matches[1].Trim() }
    return $RawPath.Trim()
}

# ─────────────────────────────────────────────────────────────────────────────
# [NEU #1] EXECUTIVE SUMMARY – Vorab-Datensammlung
# Berechnet alle Kennzahlen BEVOR irgendetwas angezeigt wird.
# ─────────────────────────────────────────────────────────────────────────────

function Get-ExecutiveSummary {
    param([System.Diagnostics.Eventing.Reader.EventLogRecord[]]$Events)

    $summary = [PSCustomObject]@{
        LogsCleared           = $false
        LogClearCount         = 0
        ActiveExclusions      = 0
        SuspExclusions        = 0
        DisableEvents24h      = 0
        FlaggedFinds          = 0
        QuarantineRestores    = 0
        Disable2003Count      = 0
        # AV & Echtzeitschutz-Status
        InstalledAVProducts   = @()        # Liste aller SecurityCenter2-AV-Produkte
        ThirdPartyAVFound     = $false     # true wenn Nicht-Defender-AV registriert
        RealTimeProtection    = 'Unbekannt' # 'Aktiv', 'Deaktiviert', 'Unbekannt'
    }

    # ── Aktuellen Echtzeit-Schutz-Status ermitteln (MpPreference) ──────────────
    # Primär: Get-MpComputerStatus (liefert RealTimeProtectionEnabled direkt)
    try {
        $mpStatus = Get-MpComputerStatus -ErrorAction Stop
        $summary.RealTimeProtection = if ($mpStatus.RealTimeProtectionEnabled) { 'Aktiv' } else { 'Deaktiviert' }
    }
    catch {
        # Fallback: letztes 2003/5004-Event auswerten
        try {
            $lastProtEvt = $Events | Where-Object { $_.Id -in @(2003, 5004) } |
                           Sort-Object TimeCreated | Select-Object -Last 1
            if ($lastProtEvt) {
                $summary.RealTimeProtection = if ($lastProtEvt.Id -eq 2003) { 'Deaktiviert (lt. letztem Event)' } else { 'Unbekannt (kein direkter Status)' }
            }
        } catch {}
    }

    # ── Installierte Antiviren-Programme (SecurityCenter2 via WMI/CIM) ─────────
    try {
        $avProducts = Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntivirusProduct' -ErrorAction Stop
        foreach ($av in $avProducts) {
            $summary.InstalledAVProducts += $av.displayName
            # Alles außer Windows Defender / Security Center selbst gilt als Drittanbieter
            if ($av.displayName -notmatch 'Windows Defender|Microsoft Defender|Windows Security') {
                $summary.ThirdPartyAVFound = $true
            }
        }
    }
    catch {
        # CIM nicht verfügbar → WMI-Fallback
        try {
            $avProducts = Get-WmiObject -Namespace 'root/SecurityCenter2' -Class 'AntivirusProduct' -ErrorAction Stop
            foreach ($av in $avProducts) {
                $summary.InstalledAVProducts += $av.displayName
                if ($av.displayName -notmatch 'Windows Defender|Microsoft Defender|Windows Security') {
                    $summary.ThirdPartyAVFound = $true
                }
            }
        }
        catch {
            $summary.InstalledAVProducts += '(WMI-Zugriff verweigert oder nicht verfügbar)'
        }
    }

    # ── Log gelöscht? ──────────────────────────────────────────────────────────
    try {
        $clearEvts = Get-WinEvent -FilterHashtable @{LogName='System'; Id=104} -ErrorAction Stop
        if ($clearEvts) {
            $summary.LogsCleared   = $true
            $summary.LogClearCount = $clearEvts.Count
        }
    } catch {}

    # Aktuelle Exclusions aus Registry
    $excPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths',
        'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes',
        'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Extensions'
    )
    foreach ($rp in $excPaths) {
        try {
            if (Test-Path $rp) {
                $vals = Get-ItemProperty -Path $rp -ErrorAction Stop
                $entries = $vals.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                $summary.ActiveExclusions += ($entries | Measure-Object).Count
                $summary.SuspExclusions   += ($entries | Where-Object { Test-CheatMatch -Text $_.Name } | Measure-Object).Count
            }
        } catch {}
    }

    # Deaktivierungen letzte 24h (ID 2003, 5010, 5012)
    $cutoff24h = (Get-Date).AddHours(-24)
    $summary.DisableEvents24h = ($Events | Where-Object {
        $_.Id -in @(2003, 5010, 5012) -and $_.TimeCreated -ge $cutoff24h
    } | Measure-Object).Count

    $summary.Disable2003Count = ($Events | Where-Object { $_.Id -eq 2003 } | Measure-Object).Count

    # Geflaggte Funde (Threats mit Cheat-Keyword)
    $threatEvents = $Events | Where-Object { $_.Id -in @(1006,1007,1008,1009,1015,1116,1117,1118,1119) }
    foreach ($te in $threatEvents) {
        try {
            $xml  = [xml]$te.ToXml()
            $path = Extract-ThreatPath -RawPath (Get-XmlData -Xml $xml -FieldName 'Path')
            $name = Get-XmlData -Xml $xml -FieldName 'Threat Name'
            if (Test-CheatMatch -Text "$path $name") { $summary.FlaggedFinds++ }
        } catch {}
    }

    # Quarantäne-Restores (immer kritisch)
    $summary.QuarantineRestores = ($Events | Where-Object { $_.Id -eq 1009 } | Measure-Object).Count

    return $summary
}

function Show-ExecutiveSummary {
    param([PSCustomObject]$Summary)

    Write-Host ""
    Write-Host ("█" * 80) -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  ██  EXECUTIVE SUMMARY – SCHNELLÜBERSICHT  ██" -ForegroundColor Cyan
    Write-Host "  ██  Analysezeitpunkt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  ██" -ForegroundColor DarkCyan
    Write-Host ""

    # ══════════════════════════════════════════════════════════════════════════
    # BLOCK 1 – AKTUELLER ECHTZEIT-SCHUTZ-STATUS (zum Ausführungszeitpunkt)
    # ══════════════════════════════════════════════════════════════════════════
    Write-Host ("  ┌─ ECHTZEIT-SCHUTZ (JETZT) " + "─" * 52 + "┐") -ForegroundColor DarkCyan
    switch -Wildcard ($Summary.RealTimeProtection) {
        'Aktiv' {
            Write-Host ("  │  ✓  Echtzeitschutz aktuell  : AKTIV") -ForegroundColor Green
        }
        'Deaktiviert*' {
            Write-Host ("  │  ✗  Echtzeitschutz aktuell  : DEAKTIVIERT  ◄── ACHTUNG!") -ForegroundColor Red
        }
        default {
            Write-Host ("  │  ?  Echtzeitschutz aktuell  : $($Summary.RealTimeProtection)") -ForegroundColor DarkYellow
        }
    }

    # ── Installierte AV-Software ──────────────────────────────────────────────
    if ($Summary.InstalledAVProducts.Count -gt 0) {
        $avLine = $Summary.InstalledAVProducts -join ', '
        Write-Host ("  │  AV-Software erkannt        : $avLine") -ForegroundColor Cyan
    } else {
        Write-Host ("  │  AV-Software erkannt        : Keine / nicht abfragbar") -ForegroundColor DarkGray
    }

    # ── Drittanbieter-AV-Hinweis ─────────────────────────────────────────────
    if ($Summary.ThirdPartyAVFound) {
        $thirdPartyNames = ($Summary.InstalledAVProducts |
            Where-Object { $_ -notmatch 'Windows Defender|Microsoft Defender|Windows Security' }) -join ', '
        Write-Host ("  │") -ForegroundColor DarkYellow
        Write-Host ("  │  ⚠  DRITTANBIETER-AV AKTIV: $thirdPartyNames") -ForegroundColor Yellow
        Write-Host ("  │     Hinweis: Wenn ein Drittanbieter-AV installiert ist, deaktiviert") -ForegroundColor DarkYellow
        Write-Host ("  │     Windows automatisch den Defender-Echtzeitschutz. Ein deaktivierter") -ForegroundColor DarkYellow
        Write-Host ("  │     Defender ist in diesem Fall NORMAL und kein Cheat-Indikator.") -ForegroundColor DarkYellow
        Write-Host ("  │     Die Defender-Log-Auswertung ist hier möglicherweise nicht") -ForegroundColor DarkYellow
        Write-Host ("  │     aussagekräftig – Deaktivierungs-Events bitte ignorieren.") -ForegroundColor DarkYellow
    }
    Write-Host ("  └" + "─" * 78 + "┘") -ForegroundColor DarkCyan
    Write-Host ""

    # ══════════════════════════════════════════════════════════════════════════
    # BLOCK 2 – LOG-ANALYSE KENNZAHLEN
    # ══════════════════════════════════════════════════════════════════════════
    Write-Host ("  ┌─ LOG-ANALYSE " + "─" * 64 + "┐") -ForegroundColor DarkMagenta

    # ── Log gelöscht? ──
    if ($Summary.LogsCleared) {
        Write-Host ("  │  [!!!]  Logs gelöscht         : JA – $($Summary.LogClearCount)x geleert!") -ForegroundColor Red
    } else {
        Write-Host ("  │  [ OK ]  Logs gelöscht        : Nein") -ForegroundColor Green
    }

    # ── Aktive Exclusions ──
    $excColor = if ($Summary.SuspExclusions -gt 0) { 'Yellow' } elseif ($Summary.ActiveExclusions -gt 0) { 'White' } else { 'Green' }
    $excSusp  = if ($Summary.SuspExclusions -gt 0) { "  ← $($Summary.SuspExclusions) VERDÄCHTIG!" } else { "" }
    Write-Host ("  │  [INF]  Aktive Exclusions     : $($Summary.ActiveExclusions)$excSusp") -ForegroundColor $excColor

    # ── Deaktivierungen ──
    # Wenn Drittanbieter-AV gefunden → Deaktivierungen als normales Verhalten markieren
    if ($Summary.ThirdPartyAVFound -and $Summary.DisableEvents24h -gt 0) {
        Write-Host ("  │  [INF]  Schutz-Deaktiv. (24h) : $($Summary.DisableEvents24h)x  (wahrscheinlich durch Drittanbieter-AV)") -ForegroundColor DarkGray
    } else {
        $disColor = if ($Summary.DisableEvents24h -gt 0) { 'Red' } else { 'Green' }
        Write-Host ("  │  [INF]  Schutz-Deaktiv. (24h) : $($Summary.DisableEvents24h)x (davon $($Summary.Disable2003Count)x Echtzeit AUS)") -ForegroundColor $disColor
    }

    # ── Geflaggte Funde ──
    $findColor = if ($Summary.FlaggedFinds -gt 0) { 'Yellow' } else { 'Green' }
    Write-Host ("  │  [INF]  Geflaggte Cheat-Funde : $($Summary.FlaggedFinds)") -ForegroundColor $findColor

    # ── Quarantäne-Restores ──
    $qColor = if ($Summary.QuarantineRestores -gt 0) { 'Red' } else { 'Green' }
    Write-Host ("  │  [INF]  Quarantäne-Restores   : $($Summary.QuarantineRestores)") -ForegroundColor $qColor

    Write-Host ("  └" + "─" * 78 + "┘") -ForegroundColor DarkMagenta
    Write-Host ""

    # ══════════════════════════════════════════════════════════════════════════
    # BLOCK 3 – GESAMTBEWERTUNG
    # Wenn Drittanbieter-AV vorhanden: Deaktivierungen fließen NICHT in Risiko ein
    # ══════════════════════════════════════════════════════════════════════════
    $risk = 0
    if ($Summary.LogsCleared)              { $risk += 3 }
    if ($Summary.FlaggedFinds -gt 0)       { $risk += 2 }
    if ($Summary.SuspExclusions -gt 0)     { $risk += 2 }
    if ($Summary.QuarantineRestores -gt 0) { $risk += 2 }
    # Deaktivierungen nur werten wenn KEIN Drittanbieter-AV vorhanden
    if (-not $Summary.ThirdPartyAVFound -and $Summary.DisableEvents24h -gt 0) { $risk += 3 }

    if ($risk -ge 5) {
        Write-Host ("  ┌─────────────────────────────────────────────────────────────────────────┐") -ForegroundColor Red
        Write-Host ("  │  ⚠  RISIKO-BEWERTUNG: HOCH – Mehrere kritische Indikatoren vorhanden!  │") -ForegroundColor Red
        Write-Host ("  └─────────────────────────────────────────────────────────────────────────┘") -ForegroundColor Red
    } elseif ($risk -ge 2) {
        Write-Host ("  ┌──────────────────────────────────────────────────────────────────────────┐") -ForegroundColor Yellow
        Write-Host ("  │  ~  RISIKO-BEWERTUNG: MITTEL – Einzelne verdächtige Indikatoren.         │") -ForegroundColor Yellow
        Write-Host ("  └──────────────────────────────────────────────────────────────────────────┘") -ForegroundColor Yellow
    } else {
        Write-Host ("  ┌──────────────────────────────────────────────────────────────────────────┐") -ForegroundColor Green
        Write-Host ("  │  ✓  RISIKO-BEWERTUNG: NIEDRIG – Keine offensichtlichen Anomalien.        │") -ForegroundColor Green
        Write-Host ("  └──────────────────────────────────────────────────────────────────────────┘") -ForegroundColor Green
    }

    if ($Summary.ThirdPartyAVFound) {
        Write-Host ("        ↳ Drittanbieter-AV erkannt: Deaktivierungen wurden aus Risiko-Score HERAUSGERECHNET.") -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host ("█" * 80) -ForegroundColor DarkCyan
    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
# HAUPTFUNKTION: DEFENDER EVENTS
# ─────────────────────────────────────────────────────────────────────────────

function Get-DefenderEvents {
    param(
        [string]$LogName    = $LOG_NAME,
        [int[]]$EventIds    = $ALL_EVENT_IDS,
        [string]$ArchivePath = $null
    )

    Write-Header "WINDOWS DEFENDER EREIGNISPROTOKOLL"

    Write-Host "  Lade Events aus: $LogName" -ForegroundColor Cyan
    if ($ShowOnlySuspicious) {
        Write-Host "  [Modus: NUR VERDÄCHTIGE/KRITISCHE EVENTS] – harmlose Events ausgeblendet." -ForegroundColor DarkYellow
    }
    Write-Host ""

    $events = [System.Collections.Generic.List[object]]::new()

    # [NEU #2] Performance: FilterHashtable statt Laden aller Events in Variable
    # Nur die letzten 7 Tage laden (für Live-Log) – spart massiv RAM/Zeit
    try {
        $filterHT = @{
            LogName = $LogName
            Id      = $EventIds
        }
        $liveEvents = Get-WinEvent -FilterHashtable $filterHT -ErrorAction Stop
        foreach ($e in $liveEvents) { $events.Add($e) }
        Write-Host "  $($liveEvents.Count) Events aus Live-Log geladen." -ForegroundColor Green
    }
    catch [System.Exception] {
        if ($_.Exception.Message -match 'No events were found') {
            Write-Host "  Keine Events im Live-Log gefunden." -ForegroundColor DarkYellow
        } else {
            Write-Host "  Fehler beim Lesen des Live-Logs: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Archiv-Logs zusätzlich laden
    $archivePaths = [System.Collections.Generic.List[string]]::new()
    if ($ArchivePath -and (Test-Path $ArchivePath)) { $archivePaths.Add($ArchivePath) }
    $defaultArchiveDir = "$env:SystemRoot\System32\winevt\Logs"
    $archiveFiles = Get-ChildItem -Path $defaultArchiveDir -Filter "Microsoft-Windows-Windows Defender*" -ErrorAction SilentlyContinue
    foreach ($f in $archiveFiles) {
        if ($f.FullName -and $f.FullName -notin $archivePaths) { $archivePaths.Add($f.FullName) }
    }

    foreach ($archFile in $archivePaths) {
        try {
            # [NEU #2] Auch hier FilterHashtable für Archiv-Dateien
            $archiveEvents = Get-WinEvent -Path $archFile -FilterXPath "*[System[$(($EventIds | ForEach-Object {"EventID=$_"}) -join ' or ')]]" -ErrorAction Stop
            if ($archiveEvents) {
                Write-Host "  + $($archiveEvents.Count) Events aus Archiv: $(Split-Path $archFile -Leaf)" -ForegroundColor DarkCyan
                foreach ($e in $archiveEvents) { $events.Add($e) }
            }
        }
        catch { }
    }

    if ($events.Count -eq 0) {
        Write-Host ""
        Write-Host "  KEIN einziger Defender-Event gefunden!" -ForegroundColor DarkYellow
        Write-Host "    - Eventlog manuell geleert?" -ForegroundColor DarkYellow
        Write-Host "    - Script ohne Adminrechte?" -ForegroundColor DarkYellow
        return $null
    }

    # Chronologisch sortieren (älteste zuerst)
    $eventsSorted = $events | Sort-Object TimeCreated

    # [NEU #1] Executive Summary ZUERST berechnen und anzeigen
    $summary = Get-ExecutiveSummary -Events $eventsSorted
    Show-ExecutiveSummary -Summary $summary

    # ── Event-Liste ────────────────────────────────────────────────────────────

    Write-Host ("{0,-6}{1,-20} {2,-6} {3,-22} {4}" -f "", "Zeitstempel", "ID", "Typ", "Details") -ForegroundColor Gray
    Write-Host ("-" * 90) -ForegroundColor DarkGray

    $flagCount = 0

    # [NEU #3] IDs aller 2003-Events vorsammeln – für Korrelationsblöcke
    $disable2003Events = $eventsSorted | Where-Object { $_.Id -eq 2003 }
    $shownCorrelationBlocks = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($event in $eventsSorted) {
        try {
            $eventXml  = [xml]$event.ToXml()
            $timestamp = $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
            $id        = $event.Id

            # [NEU #4] Rauschunterdrückung: Noise-Events ausblenden
            if ($ShowOnlySuspicious -and $id -in $NOISE_EVENT_IDS) { continue }

            switch ($id) {

                # ── Dienst-Status ──────────────────────────────────────────
                5000 {
                    # Nur anzeigen wenn $ShowOnlySuspicious = $false (sonst oben bereits gefiltert)
                    Write-Row -Time $timestamp -EventID $id -Type "Defender GESTARTET" -Message "Dienst aktiviert" -Color Green
                }
                5001 {
                    Write-Row -Time $timestamp -EventID $id -Type "Defender GESTOPPT" -Message "Dienst deaktiviert!" -Color Red
                }

                # ── Echtzeitschutz deaktiviert (2003) – SMOKING GUN ────────
                # [NEU #3] Korrelationsblock: Schutz AUS → Aktionen → Schutz AN
                2003 {
                    $tMin = $event.TimeCreated.AddMinutes(-$CorrelationWindowMinutes)
                    $tMax = $event.TimeCreated.AddMinutes($CorrelationWindowMinutes)

                    # Kritische Events im Zeitfenster suchen
                    $correlated = $eventsSorted | Where-Object {
                        $_.TimeCreated -ge $tMin -and
                        $_.TimeCreated -le $tMax -and
                        $_.Id -ne 2003 -and
                        $_.Id -in @(1006,1007,1008,1009,1015,1116,1117,1118,1119,5007,5004)
                    }

                    # [NEU #6] Visueller Block – Schutz-Deaktivierungsphase
                    Write-Host ""
                    Write-Host ("  " + "▓" * 76) -ForegroundColor DarkRed
                    Write-Host ("  ▓▓  KRITISCH: ECHTZEITSCHUTZ DEAKTIVIERT [ID 2003]") -ForegroundColor Red
                    Write-Host ("  ▓▓  Zeitpunkt: $timestamp") -ForegroundColor Red
                    if ($correlated) {
                        Write-Host ("  ▓▓  ⚠  $($correlated.Count) kritische Event(s) im ±${CorrelationWindowMinutes}-Minuten-Fenster!") -ForegroundColor Yellow
                    } else {
                        Write-Host ("  ▓▓  Keine korrelierten Aktionen im Zeitfenster gefunden.") -ForegroundColor DarkYellow
                    }
                    Write-Host ("  " + "▓" * 76) -ForegroundColor DarkRed
                    Write-Host ""

                    # Korrelierte Events anzeigen
                    if ($correlated) {
                        Write-Host ("  ┌── AKTIONEN IM DEAKTIVIERUNGSFENSTER (±${CorrelationWindowMinutes} Min) ──────────────────────────") -ForegroundColor DarkRed

                        # Nächstes 2003-Ende suchen (wann wurde Schutz wieder aktiviert?)
                        $nextActive = $eventsSorted | Where-Object {
                            $_.Id -in @(5000, 5004) -and $_.TimeCreated -gt $event.TimeCreated
                        } | Select-Object -First 1
                        if ($nextActive) {
                            $offDuration = [int]($nextActive.TimeCreated - $event.TimeCreated).TotalMinutes
                            Write-Host ("  │  Schutz wieder aktiv: $($nextActive.TimeCreated.ToString('HH:mm:ss')) (nach ca. ${offDuration} Minuten)") -ForegroundColor DarkYellow
                            Write-Host ("  │") -ForegroundColor DarkRed
                        }

                        foreach ($ce in $correlated | Sort-Object TimeCreated) {
                            try {
                                $ceXml      = [xml]$ce.ToXml()
                                $ceTime     = $ce.TimeCreated.ToString('HH:mm:ss')
                                $ceThreat   = Get-XmlData -Xml $ceXml -FieldName 'Threat Name'
                                $cePath     = Extract-ThreatPath -RawPath (Get-XmlData -Xml $ceXml -FieldName 'Path')
                                $ceAction   = Get-XmlData -Xml $ceXml -FieldName 'Action Name'
                                $ceNewVal   = Get-XmlData -Xml $ceXml -FieldName 'New Value'
                                $ceSeverity = Get-XmlData -Xml $ceXml -FieldName 'Severity Name'

                                $ceDetail = "ID=$($ce.Id)"
                                if ($ceThreat)   { $ceDetail += " | Threat: $ceThreat" }
                                if ($ceSeverity)  { $ceDetail += " [$ceSeverity]" }
                                if ($ceAction)   { $ceDetail += " → $ceAction" }
                                if ($cePath)     { $ceDetail += " | $cePath" }
                                if ($ceNewVal -and $ceNewVal -match 'Exclusions\\') {
                                    $ceDetail += " | EXCLUSION: $ceNewVal"
                                }

                                $ceMatch = Get-CheatMatch -Text "$ceThreat $cePath $ceNewVal"
                                $ceColor = if ($ceMatch) { 'Yellow' } else { 'Gray' }
                                Write-Host ("  │  $ceTime  $ceDetail") -ForegroundColor $ceColor
                                if ($ceMatch) {
                                    Write-Host ("  │  >>> CHEAT-KEYWORD MATCH: `"$ceMatch`" <<<") -ForegroundColor Yellow
                                }
                            } catch {}
                        }

                        Write-Host ("  └────────────────────────────────────────────────────────────────────────────") -ForegroundColor DarkRed
                    }
                    Write-Host ""
                    $flagCount++
                }

                # ── Weitere Schutz-Deaktivierungen ────────────────────────
                { $_ -in @(5004, 5010, 5012) } {
                    if ($ShowOnlySuspicious) { continue }
                    $desc = switch ($id) {
                        5004 { "Echtzeitschutz-Konfiguration geändert" }
                        5010 { "Scan deaktiviert" }
                        5012 { "Defender-Komponente deaktiviert" }
                    }
                    Write-Row -Time $timestamp -EventID $id -Type "Schutz-Änderung" -Message $desc -Color DarkYellow
                }

                # ── Signatur-Updates (2004) – nur mit Pfad-Bezug zeigen ────
                # [NEU #4] 2004 ohne erkennbaren Pfad/Exclusion-Bezug = Rauschen, ausblenden
                2004 {
                    $detail = Get-XmlData -Xml $eventXml -FieldName 'New Value'
                    if ($ShowOnlySuspicious -and ($detail -notmatch 'Exclusions\\' -and $detail -notmatch '\\')) { continue }
                    Write-Row -Time $timestamp -EventID $id -Type "Echtzeitschutz" -Message $detail -Color DarkYellow
                }

                # ── Konfiguration / Exclusions (5007) ─────────────────────
                5007 {
                    $newVal = Get-XmlData -Xml $eventXml -FieldName 'New Value'
                    $oldVal = Get-XmlData -Xml $eventXml -FieldName 'Old Value'

                    $isExclusionEvent = ($newVal -match 'Exclusions\\' -or $oldVal -match 'Exclusions\\')
                    if (-not $isExclusionEvent) { continue }

                    $patterns = @{
                        'Path'      = 'Exclusions\\Paths\\(.+?)(?:\s*=|$)'
                        'Process'   = 'Exclusions\\Processes\\(.+?)(?:\s*=|$)'
                        'Extension' = 'Exclusions\\Extensions\\(.+?)(?:\s*=|$)'
                    }

                    $parsedNew = $null; $parsedOld = $null; $exType = "Exclusion"

                    foreach ($pkey in $patterns.Keys) {
                        if ($newVal -match $patterns[$pkey]) { $parsedNew = $matches[1].Trim(); $exType = "Exclusion $pkey" }
                        if ($oldVal -match $patterns[$pkey]) { $parsedOld = $matches[1].Trim(); $exType = "Exclusion $pkey" }
                    }

                    $value    = if ($parsedNew) { $parsedNew } else { $parsedOld }
                    $changeOp = if ($parsedNew -and -not $parsedOld)     { "HINZUGEFÜGT" }
                                elseif ($parsedOld -and -not $parsedNew) { "ENTFERNT" }
                                else                                      { "GEÄNDERT" }

                    $msg       = "${changeOp}: $value"
                    $kwMatch   = Get-CheatMatch -Text "$parsedNew $parsedOld"
                    $isFlagged = $null -ne $kwMatch
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type $exType -Message $msg -Color Red -Flagged:$isFlagged -MatchKeyword:$kwMatch
                }

                # ── Threat-Erkennung ───────────────────────────────────────
                { $_ -in @(1006, 1015, 1116) } {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $severity   = Get-XmlData -Xml $eventXml -FieldName 'Severity Name'
                    if (-not $severity) { $severity = Get-XmlData -Xml $eventXml -FieldName 'Severity ID' }

                    $cleanPath = Extract-ThreatPath -RawPath $rawPath
                    $msg = ""
                    if ($threatName) { $msg += "[$threatName] " }
                    if ($severity)   { $msg += "Schwere: $severity | " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }

                    $kwMatch   = Get-CheatMatch -Text "$cleanPath $threatName"
                    $isFlagged = $null -ne $kwMatch
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "THREAT ERKANNT" -Message $msg -Color DarkRed -Flagged:$isFlagged -MatchKeyword:$kwMatch
                }

                # ── Threat-Aktion ──────────────────────────────────────────
                { $_ -in @(1007, 1117) } {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $action     = Get-XmlData -Xml $eventXml -FieldName 'Action Name'
                    if (-not $action) { $action = Get-XmlData -Xml $eventXml -FieldName 'Action ID' }

                    $cleanPath = Extract-ThreatPath -RawPath $rawPath
                    $msg = ""
                    if ($action)     { $msg += "Aktion: $action | " }
                    if ($threatName) { $msg += "[$threatName] " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }

                    $kwMatch   = Get-CheatMatch -Text "$cleanPath $threatName"
                    $isFlagged = $null -ne $kwMatch
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "Threat-Aktion" -Message $msg -Color Red -Flagged:$isFlagged -MatchKeyword:$kwMatch
                }

                # ── Bereinigung fehlgeschlagen ─────────────────────────────
                1008 {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $cleanPath  = Extract-ThreatPath -RawPath $rawPath
                    $msg = "BEREINIGUNG FEHLGESCHLAGEN | "
                    if ($threatName) { $msg += "[$threatName] " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }

                    $kwMatch   = Get-CheatMatch -Text "$cleanPath $threatName"
                    $isFlagged = $null -ne $kwMatch
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "Berein. FEHLER" -Message $msg -Color DarkRed -Flagged:$isFlagged -MatchKeyword:$kwMatch
                }

                # ── Bereinigung erfolgreich ────────────────────────────────
                1119 {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $cleanPath  = Extract-ThreatPath -RawPath $rawPath
                    $msg = ""
                    if ($threatName) { $msg += "[$threatName] " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }

                    $kwMatch   = Get-CheatMatch -Text "$cleanPath $threatName"
                    $isFlagged = $null -ne $kwMatch
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "Berein. OK" -Message $msg -Color DarkGreen -Flagged:$isFlagged -MatchKeyword:$kwMatch
                }

                # ── Quarantäne WIEDERHERGESTELLT ──────────────────────────
                1009 {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $cleanPath  = Extract-ThreatPath -RawPath $rawPath
                    $msg = "AUS QUARANTÄNE WIEDERHERGESTELLT | "
                    if ($threatName) { $msg += "[$threatName] " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }

                    $kwMatch   = Get-CheatMatch -Text "$cleanPath $threatName"
                    # Quarantäne-Restore ist IMMER verdächtig – Keyword-Match optional
                    Write-Row -Time $timestamp -EventID $id -Type "QUARANT. RESTORE" -Message $msg -Color Yellow -Flagged -MatchKeyword:$kwMatch
                    $flagCount++
                }

                # ── Verlauf gelöscht (1013) – nur wenn Threats in der Nähe ──
                1013 {
                    $tMin   = $event.TimeCreated.AddMinutes(-5)
                    $tMax   = $event.TimeCreated.AddMinutes(5)
                    $nearby = $eventsSorted | Where-Object {
                        $_.TimeCreated -ge $tMin -and $_.TimeCreated -le $tMax -and
                        $_.Id -in @(1006,1007,1008,1009,1015,1116,1117,1118,1119)
                    }
                    if (-not $nearby) { continue }

                    $flagCount++
                    Write-Host ""
                    Write-Host ("  " + "─" * 76) -ForegroundColor DarkRed
                    Write-Host ("  [!!!] $timestamp  [1013]  SCHUTZVERLAUF-EINTRAG GELÖSCHT") -ForegroundColor Red
                    Write-Host ("        Threats im Zeitfenster ±5 Min:") -ForegroundColor Cyan

                    foreach ($nb in $nearby | Sort-Object TimeCreated) {
                        try {
                            $nbXml      = [xml]$nb.ToXml()
                            $nbTime     = $nb.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                            $nbThreat   = Get-XmlData -Xml $nbXml -FieldName 'Threat Name'
                            $nbPath     = Extract-ThreatPath -RawPath (Get-XmlData -Xml $nbXml -FieldName 'Path')
                            $nbAction   = Get-XmlData -Xml $nbXml -FieldName 'Action Name'
                            $nbSeverity = Get-XmlData -Xml $nbXml -FieldName 'Severity Name'

                            $detail = "ID=$($nb.Id)"
                            if ($nbThreat)   { $detail += " | $nbThreat" }
                            if ($nbSeverity) { $detail += " [$nbSeverity]" }
                            if ($nbAction)   { $detail += " → $nbAction" }
                            if ($nbPath)     { $detail += " | $nbPath" }

                            $nbMatch = Get-CheatMatch -Text "$nbThreat $nbPath"
                            $col     = if ($nbMatch) { 'Yellow' } else { 'Gray' }
                            Write-Host ("          $nbTime  $detail") -ForegroundColor $col
                            if ($nbMatch) {
                                Write-Host ("          >>> CHEAT-KEYWORD MATCH: `"$nbMatch`" <<<") -ForegroundColor Yellow
                            }
                        } catch {}
                    }
                    Write-Host ("  " + "─" * 76) -ForegroundColor DarkRed
                    Write-Host ""
                }
            }
        }
        catch {
            Write-Host "  [Fehler bei Event $($event.Id)]: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }

    Write-Host ("-" * 90) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Gesamt Events verarbeitet : $($events.Count)" -ForegroundColor Cyan
    if ($flagCount -gt 0) {
        Write-Host "  [!!!] VERDÄCHTIGE Events    : $flagCount" -ForegroundColor Yellow
        Write-Host "        Hinweis: Geflaggte Einträge deuten auf mögliche Cheat-Aktivität hin!" -ForegroundColor Yellow
    } else {
        Write-Host "  Keine verdächtigen Einträge gefunden." -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# AKTUELLE EXCLUSIONS AUSLESEN (Registry)
# ─────────────────────────────────────────────────────────────────────────────

function Show-CurrentExclusions {
    Write-Header "AKTUELLE DEFENDER-EXCLUSIONS (Registry)"

    $exclusionTypes = @{
        'Paths'      = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths'
        'Processes'  = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes'
        'Extensions' = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Extensions'
    }

    $anyFound = $false

    foreach ($exType in $exclusionTypes.Keys) {
        try {
            $regPath = $exclusionTypes[$exType]
            if (Test-Path $regPath) {
                $values  = Get-ItemProperty -Path $regPath -ErrorAction Stop
                $entries = $values.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                if ($entries) {
                    Write-Host ""
                    Write-Host "  [$exType]" -ForegroundColor Cyan
                    foreach ($entry in $entries) {
                        $kwMatch = Get-CheatMatch -Text $entry.Name
                        $color   = if ($kwMatch) { 'Yellow' } else { 'White' }
                        $prefix  = if ($kwMatch) { "  [!!!] " } else { "        " }
                        Write-Host "${prefix}$($entry.Name)" -ForegroundColor $color
                        if ($kwMatch) {
                            Write-Host "         >>> VERDÄCHTIG: Möglicher Cheat-Pfad | Match: `"$kwMatch`"" -ForegroundColor Yellow
                        }
                    }
                    $anyFound = $true
                }
            }
        }
        catch {
            Write-Host "  Kein Zugriff auf $exType (Admin erforderlich?)" -ForegroundColor DarkGray
        }
    }

    if (-not $anyFound) {
        Write-Host "  Keine Exclusions in der Registry gefunden." -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# QUARANTÄNE-LISTE (MpCmdRun)
# ─────────────────────────────────────────────────────────────────────────────

function Show-Quarantine {
    Write-Header "QUARANTÄNE-EINTRÄGE"

    $mpCmd = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (-not (Test-Path $mpCmd)) { $mpCmd = "$env:ProgramFiles (x86)\Windows Defender\MpCmdRun.exe" }

    if (-not (Test-Path $mpCmd)) {
        Write-Host "  MpCmdRun.exe nicht gefunden." -ForegroundColor DarkGray
        return
    }

    try {
        $lines = & $mpCmd -Restore -ListAll 2>&1 | Where-Object { $_ -match '\S' }
    }
    catch {
        Write-Host "  Fehler: $_" -ForegroundColor Red
        return
    }

    $meaningful = $lines | Where-Object {
        $_ -notmatch '^\s*$' -and $_ -notmatch 'CmdTool' -and
        $_ -notmatch 'Copyright' -and $_ -notmatch '^\-+$'
    }

    if (-not $meaningful -or ($meaningful -join '') -match 'No items|keine Elemente') {
        Write-Host "  Quarantäne ist leer." -ForegroundColor Green
        return
    }

    Write-Host ""
    foreach ($line in $meaningful) {
        $kwMatch = Get-CheatMatch -Text $line
        $color   = if ($kwMatch) { 'Yellow' } else { 'Gray' }
        $prefix  = if ($kwMatch) { "  [!!!] " } else { "        " }
        Write-Host "${prefix}$line" -ForegroundColor $color
        if ($kwMatch) {
            Write-Host "         >>> CHEAT-KEYWORD MATCH: `"$kwMatch`" <<<" -ForegroundColor Yellow
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# LOG-LÖSCHUNGS-PRÜFUNG (Event 104)
# ─────────────────────────────────────────────────────────────────────────────

function Check-LogCleared {
    Write-Header "LOG-LÖSCHUNGS-PRÜFUNG (System-Eventlog)"

    try {
        # [NEU #2] FilterHashtable direkt – kein Zwischenspeichern aller Events
        $clearEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Id=104} -ErrorAction Stop
        if ($clearEvents) {
            Write-Host "  [!!!] WARNUNG: Das Ereignisprotokoll wurde $($clearEvents.Count)x geleert!" -ForegroundColor Red
            foreach ($e in $clearEvents | Sort-Object TimeCreated) {
                Write-Host "        $($e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) - $($e.Message.Split("`n")[0])" -ForegroundColor DarkRed
            }
        } else {
            Write-Host "  Kein Hinweis auf manuelles Löschen des Eventlogs." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Keine Log-Lösch-Events gefunden oder kein Zugriff." -ForegroundColor DarkGray
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

# Admin-Check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [WARNUNG] Script läuft NICHT als Administrator!" -ForegroundColor Red
    Write-Host "  Einige Daten (Registry-Exclusions, Quarantäne) sind möglicherweise nicht lesbar." -ForegroundColor DarkYellow
    Write-Host "  Bitte mit Rechtsklick > 'Als Administrator ausführen' neu starten." -ForegroundColor DarkYellow
    Write-Host ""
}

Check-LogCleared
Get-DefenderEvents
Show-CurrentExclusions
Show-Quarantine

Write-Host ""
Write-Host ("=" * 80) -ForegroundColor DarkMagenta
Write-Host "  Analyse abgeschlossen." -ForegroundColor Magenta
Write-Host ("=" * 80) -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "  Enter drücken zum Beenden..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
