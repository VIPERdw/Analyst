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
# 2003 = Echtzeitscan deaktiviert
# 2004 = Echtzeitschutz aktiviert/deaktiviert Regel
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
        [switch]$Flagged
    )
    $prefix = if ($Flagged) { "[!!!] " } else { "      " }
    $line = "{0}{1,-20} [{2,-4}] {3,-22} {4}" -f $prefix, $Time, $EventID, $Type, $Message
    Write-Host $line -ForegroundColor $Color
    if ($Flagged) {
        Write-Host ("       >>> VERDÄCHTIG: Möglicher Cheat-Bezug <<<") -ForegroundColor Yellow
    }
}

function Test-CheatMatch {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    foreach ($kw in $CHEAT_KEYWORDS) {
        if ($Text -match $kw) { return $true }
    }
    return $false
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
    # Defender schreibt Pfade als "file:_C:\..." oder direkt als Pfad
    if ($RawPath -match '^file:_(.+)$') { return $matches[1].Trim() }
    if ($RawPath -match '^(.+)$')       { return $matches[1].Trim() }
    return $RawPath.Trim()
}

# ─────────────────────────────────────────────────────────────────────────────
# HAUPTFUNKTION: DEFENDER EVENTS
# ─────────────────────────────────────────────────────────────────────────────

function Get-DefenderEvents {
    param(
        [string]$LogName = $LOG_NAME,
        [int[]]$EventIds = $ALL_EVENT_IDS,
        [string]$ArchivePath = $null   # optional: Pfad zu .evtx-Backup
    )

    Write-Header "WINDOWS DEFENDER EREIGNISPROTOKOLL"

    # XPath-Query für mehrere Event-IDs korrekt aufbauen
    $idCondition = ($EventIds | ForEach-Object { "EventID=$_" }) -join " or "
    $query = @"
<QueryList>
  <Query Id="0" Path="$LogName">
    <Select Path="$LogName">*[System[$idCondition]]</Select>
  </Query>
</QueryList>
"@

    Write-Host "  Lade Events aus: $LogName" -ForegroundColor Cyan
    Write-Host ""

    $events = @()

    # Live-Log versuchen
    try {
        $events += Get-WinEvent -FilterXml $query -ErrorAction Stop
        Write-Host "  $($events.Count) Events gefunden." -ForegroundColor Green
    }
    catch [System.Exception] {
        if ($_.Exception.Message -match 'No events were found') {
            Write-Host "  Keine Events im Live-Log gefunden." -ForegroundColor DarkYellow
        }
        else {
            Write-Host "  Fehler beim Lesen des Live-Logs: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Archiv-Log zusätzlich laden (falls angegeben oder Standard-Archiv vorhanden)
    $archivePaths = @()
    if ($ArchivePath -and (Test-Path $ArchivePath)) {
        $archivePaths += $ArchivePath
    }
    # Windows legt automatisch Archiv-Logs an:
    $defaultArchiveDir = "$env:SystemRoot\System32\winevt\Logs"
    $archiveFiles = Get-ChildItem -Path $defaultArchiveDir -Filter "Microsoft-Windows-Windows Defender*" -ErrorAction SilentlyContinue
    foreach ($f in $archiveFiles) {
        if ($f.FullName -ne $null -and $f.FullName -notin $archivePaths) {
            $archivePaths += $f.FullName
        }
    }

    foreach ($archFile in $archivePaths) {
        try {
            $archiveQuery = $query -replace [regex]::Escape($LogName), $archFile
            # Für Datei-basierte Logs muss Path auf die Datei zeigen
            $archiveEvents = Get-WinEvent -Path $archFile -FilterXPath "*[System[$idCondition]]" -ErrorAction Stop
            if ($archiveEvents) {
                Write-Host "  + $($archiveEvents.Count) Events aus Archiv: $archFile" -ForegroundColor DarkCyan
                $events += $archiveEvents
            }
        }
        catch {
            # Archiv-Fehler stumm ignorieren (oft Read-Only oder kein Zugriff)
        }
    }

    if ($events.Count -eq 0) {
        Write-Host ""
        Write-Host "  KEIN einziger Defender-Event gefunden!" -ForegroundColor DarkYellow
        Write-Host "  Mögliche Ursachen:" -ForegroundColor DarkYellow
        Write-Host "    - Defender-Dienst läuft nicht (auch bei deaktiviertem Echtzeitschutz sollten Events vorhanden sein)" -ForegroundColor DarkYellow
        Write-Host "    - Eventlog wurde manuell geleert (selbst das hinterlässt normalerweise Event 104 im System-Log)" -ForegroundColor DarkYellow
        Write-Host "    - Script läuft ohne Adminrechte" -ForegroundColor DarkYellow
        Write-Host ""
        # Admin-Check
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Host "  [!] Script läuft NICHT als Administrator! Bitte als Admin neu starten." -ForegroundColor Red
        }
        return
    }

    # Events chronologisch sortieren (älteste zuerst)
    $events = $events | Sort-Object TimeCreated

    Write-Host ""
    Write-Host ("{0,-6}{1,-20} {2,-6} {3,-22} {4}" -f "", "Zeitstempel", "ID", "Typ", "Details") -ForegroundColor Gray
    Write-Host ("-" * 90) -ForegroundColor DarkGray

    $flagCount = 0

    foreach ($event in $events) {
        try {
            $eventXml  = [xml]$event.ToXml()
            $timestamp = $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
            $id        = $event.Id

            switch ($id) {

                # ── Dienst-Status ──────────────────────────────────────────
                5000 {
                    Write-Row -Time $timestamp -EventID $id -Type "Defender GESTARTET" -Message "Dienst aktiviert" -Color Green
                }
                5001 {
                    Write-Row -Time $timestamp -EventID $id -Type "Defender GESTOPPT" -Message "Dienst deaktiviert!" -Color Red
                }

                # ── Echtzeitschutz ─────────────────────────────────────────
                { $_ -in @(5004, 2003, 5010, 5012) } {
                    $desc = switch ($id) {
                        5004  { "Echtzeitschutz-Konfiguration geändert" }
                        2003  { "Echtzeitschutz DEAKTIVIERT" }
                        5010  { "Scan deaktiviert" }
                        5012  { "Defender-Komponente deaktiviert" }
                    }
                    $color = if ($id -eq 2003) { 'DarkRed' } else { 'DarkYellow' }
                    Write-Row -Time $timestamp -EventID $id -Type "Schutz-Änderung" -Message $desc -Color $color
                }
                2004 {
                    $detail = Get-XmlData -Xml $eventXml -FieldName 'New Value'
                    if (-not $detail) { $detail = "Konfigurationsänderung" }
                    Write-Row -Time $timestamp -EventID $id -Type "Echtzeitschutz" -Message $detail -Color DarkYellow
                }

                # ── Konfiguration / Exclusions ─────────────────────────────
                5007 {
                    $newVal = Get-XmlData -Xml $eventXml -FieldName 'New Value'
                    $oldVal = Get-XmlData -Xml $eventXml -FieldName 'Old Value'

                    # Exclusion-Pfade, Prozesse und Extensions erkennen
                    $patterns = @{
                        'Path'      = 'Exclusions\\Paths\\(.+?)(?:\s*=|$)'
                        'Process'   = 'Exclusions\\Processes\\(.+?)(?:\s*=|$)'
                        'Extension' = 'Exclusions\\Extensions\\(.+?)(?:\s*=|$)'
                    }

                    $parsedNew = $null; $parsedOld = $null; $exType = "Konfiguration"

                    foreach ($pkey in $patterns.Keys) {
                        if ($newVal -match $patterns[$pkey]) { $parsedNew = $matches[1].Trim(); $exType = "Exclusion $pkey" }
                        if ($oldVal -match $patterns[$pkey]) { $parsedOld = $matches[1].Trim(); $exType = "Exclusion $pkey" }
                    }

                    if ($parsedNew -or $parsedOld) {
                        $msg = if ($parsedNew -and -not $parsedOld)  { "HINZUGEFÜGT: $parsedNew" }
                               elseif ($parsedOld -and -not $parsedNew) { "ENTFERNT: $parsedOld" }
                               else { "GEÄNDERT: $parsedOld → $parsedNew" }

                        $checkText = "$parsedNew $parsedOld"
                        $isFlagged = Test-CheatMatch -Text $checkText
                        if ($isFlagged) { $flagCount++ }
                        Write-Row -Time $timestamp -EventID $id -Type $exType -Message $msg -Color Red -Flagged:$isFlagged
                    }
                    else {
                        # Generische Konfig-Änderung anzeigen (raw, gekürzt)
                        $rawMsg = if ($newVal) { $newVal } elseif ($oldVal) { $oldVal } else { "Unbekannte Änderung" }
                        if ($rawMsg.Length -gt 80) { $rawMsg = $rawMsg.Substring(0,77) + "..." }
                        Write-Row -Time $timestamp -EventID $id -Type "Konfig-Änderung" -Message $rawMsg -Color DarkYellow
                    }
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
                    if ($cleanPath)  { $msg += $cleanPath } else { $msg += "(kein Pfad)" }

                    $isFlagged = Test-CheatMatch -Text "$cleanPath $threatName"
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "THREAT ERKANNT" -Message $msg -Color DarkRed -Flagged:$isFlagged
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
                    if ($cleanPath)  { $msg += $cleanPath } else { $msg += "(kein Pfad)" }

                    $isFlagged = Test-CheatMatch -Text "$cleanPath $threatName"
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "Threat-Aktion" -Message $msg -Color Red -Flagged:$isFlagged
                }

                # ── Bereinigung fehlgeschlagen ─────────────────────────────
                1008 {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $cleanPath  = Extract-ThreatPath -RawPath $rawPath
                    $msg = "BEREINIGUNG FEHLGESCHLAGEN | "
                    if ($threatName) { $msg += "[$threatName] " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }

                    $isFlagged = Test-CheatMatch -Text "$cleanPath $threatName"
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "Berein. FEHLER" -Message $msg -Color DarkRed -Flagged:$isFlagged
                }

                # ── Bereinigung erfolgreich ────────────────────────────────
                1119 {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $cleanPath  = Extract-ThreatPath -RawPath $rawPath
                    $msg = ""
                    if ($threatName) { $msg += "[$threatName] " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }
                    $isFlagged = Test-CheatMatch -Text "$cleanPath $threatName"
                    if ($isFlagged) { $flagCount++ }
                    Write-Row -Time $timestamp -EventID $id -Type "Berein. OK" -Message $msg -Color DarkGreen -Flagged:$isFlagged
                }

                # ── Quarantäne WIEDERHERGESTELLT (sehr verdächtig!) ────────
                1009 {
                    $rawPath    = Get-XmlData -Xml $eventXml -FieldName 'Path'
                    $threatName = Get-XmlData -Xml $eventXml -FieldName 'Threat Name'
                    $cleanPath  = Extract-ThreatPath -RawPath $rawPath
                    $msg = "AUS QUARANTÄNE WIEDERHERGESTELLT | "
                    if ($threatName) { $msg += "[$threatName] " }
                    $msg += if ($cleanPath) { $cleanPath } else { "(kein Pfad)" }
                    $isFlagged = Test-CheatMatch -Text "$cleanPath $threatName"
                    if ($isFlagged) { $flagCount++ }
                    # Immer als flagged markieren – Quarantäne-Restore ist extrem verdächtig
                    Write-Row -Time $timestamp -EventID $id -Type "QUARANT. RESTORE" -Message $msg -Color Yellow -Flagged
                    $flagCount++
                }

                # ── Verlauf gelöscht (1013) – Hinweis auf Verschleierung ──
                1013 {
                    Write-Row -Time $timestamp -EventID $id -Type "VERLAUF GELÖSCHT" -Message "Schutzverlauf-Eintrag wurde manuell entfernt!" -Color Yellow -Flagged
                    $flagCount++
                }

                # ── Fallback: alle anderen geladenen Events ────────────────
                default {
                    $msg = $event.Message
                    if ($msg -and $msg.Length -gt 100) { $msg = $msg.Substring(0,97) + "..." }
                    if (-not $msg) { $msg = "(Kein Nachrichtentext)" }
                    Write-Row -Time $timestamp -EventID $id -Type "Sonstig" -Message $msg -Color DarkGray
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
    }
    else {
        Write-Host "  Keine verdächtigen Einträge gefunden." -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# AKTUELLE EXCLUSIONS AUSLESEN (Registry – zeigt auch manuell eingetragene!)
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
                $values = Get-ItemProperty -Path $regPath -ErrorAction Stop
                $entries = $values.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                if ($entries) {
                    Write-Host ""
                    Write-Host "  [$exType]" -ForegroundColor Cyan
                    foreach ($entry in $entries) {
                        $isSusp = Test-CheatMatch -Text $entry.Name
                        $color  = if ($isSusp) { 'Yellow' } else { 'White' }
                        $prefix = if ($isSusp) { "  [!!!] " } else { "        " }
                        Write-Host "${prefix}$($entry.Name)" -ForegroundColor $color
                        if ($isSusp) {
                            Write-Host "         >>> VERDÄCHTIG: Möglicher Cheat-Pfad <<<" -ForegroundColor Yellow
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
    if (-not (Test-Path $mpCmd)) {
        $mpCmd = "$env:ProgramFiles (x86)\Windows Defender\MpCmdRun.exe"
    }

    if (Test-Path $mpCmd) {
        try {
            $output = & $mpCmd -Scan -ScanType 3 2>&1
            Write-Host "  Quarantäne-Abfrage abgeschlossen." -ForegroundColor Cyan
        }
        catch {
            Write-Host "  Fehler beim Ausführen von MpCmdRun.exe: $_" -ForegroundColor Red
        }

        # Quarantäne-Dateien direkt lesen
        $quarantineDir = "$env:ProgramData\Microsoft\Windows Defender\Quarantine"
        if (Test-Path $quarantineDir) {
            $qFiles = Get-ChildItem -Path $quarantineDir -Recurse -ErrorAction SilentlyContinue
            if ($qFiles) {
                Write-Host "  Quarantäne-Ordner enthält $($qFiles.Count) Dateien/Ordner:" -ForegroundColor DarkYellow
                foreach ($f in $qFiles | Select-Object -First 50) {
                    $isSusp = Test-CheatMatch -Text $f.Name
                    $color  = if ($isSusp) { 'Yellow' } else { 'Gray' }
                    $prefix = if ($isSusp) { "  [!!!] " } else { "        " }
                    Write-Host "${prefix}$($f.FullName) [$($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))]" -ForegroundColor $color
                }
            }
            else {
                Write-Host "  Quarantäne-Ordner ist leer." -ForegroundColor Green
            }
        }
        else {
            Write-Host "  Quarantäne-Verzeichnis nicht zugänglich (Admin?)" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "  MpCmdRun.exe nicht gefunden – Quarantäne-Abfrage nicht möglich." -ForegroundColor DarkGray
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM-EVENTLOG: Wurde Defender-Log geleert? (Event 104)
# ─────────────────────────────────────────────────────────────────────────────

function Check-LogCleared {
    Write-Header "LOG-LÖSCHUNGS-PRÜFUNG (System-Eventlog)"

    try {
        $clearEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Id=104} -ErrorAction Stop
        if ($clearEvents) {
            Write-Host "  [!!!] WARNUNG: Das Ereignisprotokoll wurde $($clearEvents.Count)x geleert!" -ForegroundColor Red
            foreach ($e in $clearEvents | Sort-Object TimeCreated) {
                Write-Host "        $($e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) - $($e.Message.Split("`n")[0])" -ForegroundColor DarkRed
            }
        }
        else {
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

# Admin-Check am Anfang
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