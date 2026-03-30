# ==============================================================================
# PCIEDeviceView v2.0 - Hardware Forensics Tool
# Original by flomkk | Enhanced for DMA/Cheat Detection
# ==============================================================================

#Requires -Version 5.1

# --- Admin-Check ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "`n   [!] FEHLER: Dieses Skript muss als Administrator ausgefuehrt werden!" -ForegroundColor Red
    Write-Host "   [!] Bitte mit Rechtsklick -> 'Als Administrator ausfuehren' starten.`n" -ForegroundColor Red
    Read-Host "   [>] Enter druecken zum Beenden"
    exit 1
}

# --- Fenster-Titel & Konsole vorbereiten ---
$host.ui.RawUI.WindowTitle = "PCIE Device Check v2.0 - Made by flomkk"
try { $host.ui.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(220, 3000) } catch {}
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
Write-Host -ForegroundColor White "                    Made by flomkk  |  v2.0 Enhanced  |  discord.gg/narcocity"
Write-Host ""
Write-Host "   ==========================================================================" -ForegroundColor DarkGray
Write-Host "   [i] Forensik-Scan gestartet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "   [i] Hostname: $($env:COMPUTERNAME)  |  User: $($env:USERNAME)" -ForegroundColor Cyan
Write-Host "   ==========================================================================" -ForegroundColor DarkGray
Write-Host ""

# ==============================================================================
# FUNKTION: Driver-Signer bestimmen
# ==============================================================================
function Get-DriverSignerCategory {
    param([string]$Signer)
    if ([string]::IsNullOrWhiteSpace($Signer)) { return "Unbekannt/Unsigniert" }
    $s = $Signer.ToLower()
    if ($s -match "microsoft") { return "Microsoft" }
    if ($s -match "nvidia")    { return "NVIDIA" }
    if ($s -match "amd|advanced micro") { return "AMD" }
    if ($s -match "intel")     { return "Intel" }
    if ($s -match "realtek")   { return "Realtek" }
    if ($s -match "qualcomm")  { return "Qualcomm" }
    if ($s -match "broadcom")  { return "Broadcom" }
    if ($s -match "marvell")   { return "Marvell" }
    return "Drittanbieter: $Signer"
}

# ==============================================================================
# FUNKTION: Geraetestatus-Code uebersetzen
# ==============================================================================
function Get-DeviceStatusText {
    param([uint32]$ConfigManagerErrorCode)
    $statusMap = @{
        0  = "OK (Aktiv)"
        1  = "Fehler: Kein korrekter Treiber"
        3  = "Fehler: Treiber beschaedigt"
        10 = "FEHLER CODE 10 (Geraet konnte nicht gestartet werden)"
        12 = "Fehler: Konflikt (IRQ/DMA)"
        14 = "Neustart erforderlich"
        18 = "Fehler: Treiber muss neu installiert werden"
        19 = "Fehler: Registrierungsfehler"
        21 = "Fehler: Geraet wird entfernt"
        22 = "Deaktiviert"
        24 = "Fehler: Nicht vorhanden"
        28 = "Fehler: Treiber nicht installiert"
        43 = "FEHLER CODE 43 (Geraet vom Treiber abgewiesen - Spoofing-Hinweis!)"
        45 = "Fehler: Nicht verbunden"
        47 = "Fehler: Vorbereitung fuer sicheres Entfernen"
        52 = "Fehler: Treibersignatur nicht verifiziert"
    }
    if ($statusMap.ContainsKey([int]$ConfigManagerErrorCode)) {
        return $statusMap[[int]$ConfigManagerErrorCode]
    }
    return "Unbekannter Statuscode: $ConfigManagerErrorCode"
}

# ==============================================================================
# SCHRITT 1: Treiberdaten als Hash-Tabelle laden (Performance-Optimierung)
# ==============================================================================
Write-Host "   [-] Lade Treiberdatenbank..." -ForegroundColor Yellow
$driverData = @{}
Get-CimInstance Win32_PnPSignedDriver | ForEach-Object {
    if ($_.DeviceID -and -not $driverData.ContainsKey($_.DeviceID)) {
        $driverData[$_.DeviceID] = $_
    }
}
Write-Host "   [+] $($driverData.Count) Treiber geladen." -ForegroundColor Green

# ==============================================================================
# SCHRITT 2: PCI-Geraete scannen und anreichern
# ==============================================================================
Write-Host "   [-] Scanne PCI-Geraete..." -ForegroundColor Yellow

$results = Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.Caption -match "PCI" -or $_.DeviceID -match "PCI\\|PCI/" } |
    ForEach-Object {
        $deviceID   = $_.DeviceID
        $caption    = if ($_.Caption) { $_.Caption } else { "(Kein Name)" }
        $drvEntry   = $driverData[$deviceID]
        $drvVersion = if ($drvEntry) { $drvEntry.DriverVersion } else { "N/A" }
        $drvSigner  = if ($drvEntry) { Get-DriverSignerCategory $drvEntry.Signer } else { "Kein Treiber" }
        $statusCode = $_.ConfigManagerErrorCode
        $statusText = Get-DeviceStatusText $statusCode

        # --- Robuste ID-Extraktion mit erweiterten Regex-Pattern ---
        $vendorID = "N/A"; $devID = "N/A"; $subSysID = "N/A"; $revID = "N/A"

        # Haupt-Pattern: VEN_xxxx&DEV_xxxx
        if ($deviceID -match 'VEN_([0-9A-Fa-f]{4})') { $vendorID = $matches[1].ToUpper() }
        if ($deviceID -match 'DEV_([0-9A-Fa-f]{4})') { $devID    = $matches[1].ToUpper() }
        # Subsystem ID
        if ($deviceID -match 'SUBSYS_([0-9A-Fa-f]{8})') { $subSysID = $matches[1].ToUpper() }
        # Revision
        if ($deviceID -match 'REV_([0-9A-Fa-f]{2,})') { $revID = $matches[1].ToUpper() }

        # Volle Hardware-ID (erster Eintrag aus dem Array)
        $fullHWID = "N/A"
        try {
            $hwids = (Get-CimInstance -ClassName Win32_PnPEntity -Filter "DeviceID='$($deviceID -replace '\\','\\\\')'" -ErrorAction SilentlyContinue).HardwareID
            if ($hwids -and $hwids.Count -gt 0) { $fullHWID = $hwids[0] }
        } catch { $fullHWID = "Fehler beim Lesen" }

        # --- Verdachts-Flag (DMA/Spoofing-Heuristik) ---
        $suspiciousFlag = ""
        if ($statusCode -eq 43)         { $suspiciousFlag += "[!] Code 43 " }
        if ($drvSigner -match "Unbekannt|Drittanbieter") { $suspiciousFlag += "[?] Unbekannter Signer " }
        if ($caption -match "Xilinx|Altera|Artix|FPGA|Lattice|ECP5|Cyclone") {
            $suspiciousFlag += "[!!!] FPGA-Geraet erkannt! "
        }
        if ($caption -match "USB.*PCI|PCI.*Bridge.*USB|ExpressCard") {
            $suspiciousFlag += "[?] USB-PCI-Bridge "
        }
        if ($vendorID -in @("1172","1C3D","10EE","1A79","0955")) {
            $suspiciousFlag += "[!!!] Bekannte FPGA/DMA-Vendor-ID "
        }
        if ([string]::IsNullOrWhiteSpace($suspiciousFlag)) { $suspiciousFlag = "OK" }

        [PSCustomObject]@{
            "Geraetename"      = $caption
            "Vendor ID"        = $vendorID
            "Device ID"        = $devID
            "SubSystem ID"     = $subSysID
            "Revision"         = $revID
            "Full Hardware ID" = $fullHWID
            "Device Status"    = $statusText
            "Treiber Version"  = $drvVersion
            "Driver Signer"    = $drvSigner
            "Hersteller"       = if ($_.Manufacturer) { $_.Manufacturer } else { "N/A" }
            "Geraetetyp"       = if ($_.PNPClass) { $_.PNPClass } else { "N/A" }
            "Verdacht"         = $suspiciousFlag
            "_DeviceID_Raw"    = $deviceID
        }
    }

Write-Host "   [+] $($results.Count) PCI-Geraete gefunden." -ForegroundColor Green

# ==============================================================================
# SCHRITT 3: Verdaechtige Eintraege hervorheben
# ==============================================================================
$suspicious = $results | Where-Object { $_.Verdacht -ne "OK" }
if ($suspicious.Count -gt 0) {
    Write-Host ""
    Write-Host "   [!!!] WARNUNG: $($suspicious.Count) verdaechtige Geraete gefunden!" -ForegroundColor Red
    foreach ($s in $suspicious) {
        Write-Host "        -> $($s.Geraetename) | $($s.Verdacht)" -ForegroundColor Red
    }
    Write-Host ""
} else {
    Write-Host "   [+] Keine offensichtlich verdaechtigen Geraete." -ForegroundColor Green
}

# ==============================================================================
# SCHRITT 4: Zusaetzliche Forensik-Checks
# ==============================================================================
Write-Host ""
Write-Host "   [-] Fuehre erweiterte Forensik-Checks durch..." -ForegroundColor Yellow

# Check: USB-Geraete (fuer externe DMA-Verbindungen via USB-zu-PCIe-Adapter)
$usbDevices = Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.DeviceID -match "^USB\\" } |
    Select-Object -ExpandProperty Name

# Check: Unbekannte/generische Netzwerkkarten (Spoofing-Indiz)
$genericNics = Get-CimInstance Win32_NetworkAdapter |
    Where-Object { $_.NetEnabled -eq $true -and ($_.Manufacturer -eq $null -or $_.Manufacturer -match "generic|standard|unbekannt") }

# Check: Aktive PCIe-Geraete ohne gueltigen Treiber
$noDriverDevices = $results | Where-Object { $_."Treiber Version" -eq "N/A" -and $_.Verdacht -ne "OK" }

# Check: Mehrfach vorhandene gleiche Vendor/Device-ID-Kombination (Spoofing)
$idGroups = $results | Where-Object { $_."Vendor ID" -ne "N/A" } |
    Group-Object { "$($_.'Vendor ID')_$($_.'Device ID')" } |
    Where-Object { $_.Count -gt 1 }

Write-Host "   [+] Forensik-Checks abgeschlossen." -ForegroundColor Green

# ==============================================================================
# FUNKTION: Ergebnis-Log speichern
# ==============================================================================
function Save-ScanReport {
    param(
        [array]$ScanResults,
        [array]$SuspiciousDevices,
        [string]$SavePath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine("=" * 80)
    $null = $sb.AppendLine("  NARCOCITY - PCIEDeviceView v2.0 - Scan-Protokoll")
    $null = $sb.AppendLine("=" * 80)
    $null = $sb.AppendLine("  Zeitstempel  : $timestamp")
    $null = $sb.AppendLine("  Hostname     : $($env:COMPUTERNAME)")
    $null = $sb.AppendLine("  Benutzer     : $($env:USERNAME)")
    $null = $sb.AppendLine("  OS           : $((Get-CimInstance Win32_OperatingSystem).Caption)")
    $null = $sb.AppendLine("  Gesamtgeraete: $($ScanResults.Count)")
    $null = $sb.AppendLine("  Verdaechtig  : $($SuspiciousDevices.Count)")
    $null = $sb.AppendLine("=" * 80)
    $null = $sb.AppendLine("")

    if ($SuspiciousDevices.Count -gt 0) {
        $null = $sb.AppendLine("!!! VERDAECHTIGE GERAETE !!!")
        $null = $sb.AppendLine("-" * 40)
        foreach ($dev in $SuspiciousDevices) {
            $null = $sb.AppendLine("  Name    : $($dev.Geraetename)")
            $null = $sb.AppendLine("  Vendor  : $($dev.'Vendor ID')  Device: $($dev.'Device ID')")
            $null = $sb.AppendLine("  Status  : $($dev.'Device Status')")
            $null = $sb.AppendLine("  Signer  : $($dev.'Driver Signer')")
            $null = $sb.AppendLine("  Verdacht: $($dev.Verdacht)")
            $null = $sb.AppendLine("  Full HW : $($dev.'Full Hardware ID')")
            $null = $sb.AppendLine("  Raw ID  : $($dev._DeviceID_Raw)")
            $null = $sb.AppendLine("")
        }
    }

    $null = $sb.AppendLine("ALLE PCI-GERAETE")
    $null = $sb.AppendLine("-" * 40)
    foreach ($dev in $ScanResults) {
        $null = $sb.AppendLine("  Name    : $($dev.Geraetename)")
        $null = $sb.AppendLine("  Vendor  : $($dev.'Vendor ID')  Device: $($dev.'Device ID')  SubSys: $($dev.'SubSystem ID')  Rev: $($dev.Revision)")
        $null = $sb.AppendLine("  Status  : $($dev.'Device Status')")
        $null = $sb.AppendLine("  Treiber : $($dev.'Treiber Version')  |  Signer: $($dev.'Driver Signer')")
        $null = $sb.AppendLine("  Typ     : $($dev.Geraetetyp)  |  Hersteller: $($dev.Hersteller)")
        $null = $sb.AppendLine("  Full HW : $($dev.'Full Hardware ID')")
        $null = $sb.AppendLine("  Verdacht: $($dev.Verdacht)")
        $null = $sb.AppendLine("")
    }

    # Duplizierte IDs
    if ($idGroups.Count -gt 0) {
        $null = $sb.AppendLine("WARNUNG: DUPLIZIERTE VENDOR/DEVICE-ID-KOMBINATIONEN")
        $null = $sb.AppendLine("-" * 40)
        foreach ($grp in $idGroups) {
            $null = $sb.AppendLine("  ID: $($grp.Name) - $($grp.Count)x vorhanden")
        }
        $null = $sb.AppendLine("")
    }

    $null = $sb.AppendLine("=" * 80)
    $null = $sb.AppendLine("Ende des Berichts")

    try {
        $sb.ToString() | Out-File -FilePath $SavePath -Encoding UTF8 -Force
        return $true
    } catch {
        return $false
    }
}

# ==============================================================================
# SCHRITT 5: Anzeige (ohne interne Raw-ID-Spalte)
# ==============================================================================
Write-Host "   [!] Scan abgeschlossen. Starte GridView..." -ForegroundColor Green
Write-Host ""

$displayResults = $results | Select-Object "Geraetename","Vendor ID","Device ID","SubSystem ID","Revision",
    "Full Hardware ID","Device Status","Treiber Version","Driver Signer","Hersteller","Geraetetyp","Verdacht"

$displayResults | Out-GridView -Title "PCIEDeviceView v2.0 - PCI Geraete Forensik-Analyse (Rote Eintraege = Verdaechtig)"

# ==============================================================================
# SCHRITT 6: Duplikate-Warnung ausgeben
# ==============================================================================
if ($idGroups.Count -gt 0) {
    Write-Host ""
    Write-Host "   [!!!] WARNUNG: Duplizierte Vendor/Device-IDs gefunden (moegliches Spoofing)!" -ForegroundColor Red
    foreach ($grp in $idGroups) {
        Write-Host "        -> ID: $($grp.Name) kommt $($grp.Count)x vor" -ForegroundColor Red
    }
}

# ==============================================================================
# SCHRITT 7: Speichern-Auswahl
# ==============================================================================
Write-Host ""
Write-Host "   ==========================================================================" -ForegroundColor DarkGray
$saveChoice = Read-Host "   [>] Scan-Ergebnis als TXT speichern? (J/N)"

if ($saveChoice -match "^[JjYy]") {
    $scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = $PWD.Path }
    $timeStamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $outputFile = Join-Path $scriptDir "Scan_Ergebnis_$timeStamp.txt"

    $saved = Save-ScanReport -ScanResults $results -SuspiciousDevices $suspicious -SavePath $outputFile

    if ($saved) {
        Write-Host "   [+] Bericht gespeichert: $outputFile" -ForegroundColor Green
    } else {
        Write-Host "   [!] Fehler beim Speichern. Pfad pruefen oder als Admin ausfuehren." -ForegroundColor Red
    }
} else {
    Write-Host "   [-] Speichern uebersprungen." -ForegroundColor Gray
}

Write-Host ""
Read-Host "   [>] Enter druecken zum Beenden"
