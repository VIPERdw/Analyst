# ==============================================================================
#  ██████╗  ██████╗██╗    ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗
#  ██╔══██╗██╔════╝██║   ██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝
#  ██████╔╝██║     ██║   ██║     ███████║█████╗  ██║     █████╔╝
#  ██╔═══╝ ██║     ██║   ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗
#  ██║     ╚██████╗██║   ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗
#  ╚═╝      ╚═════╝╚═╝    ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝
#
#  PCIe Hardware Forensics Tool  v3.0  |  DMA / Cheat Detection
#  Autor: flomkk  |  Refactor & Extension: v3.0 Professional Edition
#  discord.gg/narcocity
# ==============================================================================
#Requires -Version 5.1

# ==============================================================================
# PARAMETER
# ==============================================================================
param(
    [switch]$Verbose,          # Zeige ALLE Geraete, nicht nur verdaechtige
    [switch]$NoSave,           # Kein Speicher-Dialog am Ende
    [switch]$SkipHID,          # HID-Analyse ueberspringen (schneller)
    [switch]$SkipRegistry      # Registry-Ghost-Scan ueberspringen
)

# ==============================================================================
# ADMIN-CHECK
# ==============================================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "`n   [!] FEHLER: Dieses Skript muss als Administrator ausgefuehrt werden!" -ForegroundColor Red
    Write-Host "   [!] Rechtsklick -> 'Als Administrator ausfuehren'`n" -ForegroundColor Red
    Read-Host "   [>] Enter zum Beenden"; exit 1
}

# ==============================================================================
# KONSOLE EINRICHTEN
# ==============================================================================
$host.ui.RawUI.WindowTitle = "PCICheck v3.0 - DMA Forensics | discord.gg/narcocity"
try { $host.ui.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(240, 9999) } catch {}
try { $host.ui.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size([Math]::Min(240, $host.ui.RawUI.MaxWindowSize.Width), 50) } catch {}
Clear-Host

# ==============================================================================
# GLOBALER RISK-SCORE ZAEHLER
# ==============================================================================
$script:RiskScore     = 0
$script:RiskMax       = 0
$script:FindingsList  = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-RiskPoints {
    param([int]$Points, [int]$MaxPossible)
    $script:RiskScore += $Points
    $script:RiskMax   += $MaxPossible
}

function Add-Finding {
    param([string]$Kategorie, [string]$Schwere, [string]$Beschreibung, [string]$Detail = "")
    $script:FindingsList.Add([PSCustomObject]@{
        Kategorie   = $Kategorie
        Schwere     = $Schwere
        Beschreibung = $Beschreibung
        Detail      = $Detail
    })
}

# ==============================================================================
# BANNER
# ==============================================================================
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   ██████╗  ██████╗██╗    ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗            " -ForegroundColor Cyan -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   ██╔══██╗██╔════╝██║   ██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝            " -ForegroundColor Cyan -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   ██████╔╝██║     ██║   ██║     ███████║█████╗  ██║     █████╔╝             " -ForegroundColor Cyan -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   ██╔═══╝ ██║     ██║   ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗             " -ForegroundColor Cyan -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   ██║     ╚██████╗██║   ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗            " -ForegroundColor Cyan -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   ╚═╝      ╚═════╝╚═╝    ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝            " -ForegroundColor Cyan -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   PCIe Hardware Forensics  v3.0  |  DMA / Spoof Detection  |  narcocity       " -ForegroundColor White -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   Host : $($env:COMPUTERNAME)  |  User: $($env:USERNAME)  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')   " -ForegroundColor Gray -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
if ($Verbose) {
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   Modus: VERBOSE  - alle Geraete werden angezeigt                              " -ForegroundColor Yellow -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
}
Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host ""

# ==============================================================================
# HILFSFUNKTIONEN
# ==============================================================================
function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ┌─── $Title " -ForegroundColor DarkCyan -NoNewline
    Write-Host ("─" * ([Math]::Max(2, 74 - $Title.Length))) -ForegroundColor DarkCyan
}

function Write-Step {
    param([string]$Msg, [string]$Color = "Yellow")
    Write-Host "  │  [-] $Msg" -ForegroundColor $Color
}

function Write-OK {
    param([string]$Msg)
    Write-Host "  │  [+] $Msg" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Msg)
    Write-Host "  │  [!] $Msg" -ForegroundColor Yellow
}

function Write-Crit {
    param([string]$Msg)
    Write-Host "  │  [!!!] $Msg" -ForegroundColor Red
}

function Write-SectionEnd {
    Write-Host "  └" -ForegroundColor DarkCyan -NoNewline
    Write-Host ("─" * 77) -ForegroundColor DarkCyan
}

# ==============================================================================
# LOOKUP-TABELLEN
# ==============================================================================

# Bekannte Vendor IDs -> Name
$KnownVendors = @{
    "10DE" = "NVIDIA"
    "1002" = "AMD/ATI"
    "8086" = "Intel"
    "14E4" = "Broadcom"
    "10EC" = "Realtek"
    "1022" = "AMD (Fusion)"
    "1B21" = "ASMedia"
    "1912" = "Renesas"
    "104C" = "Texas Instruments"
    "1AF4" = "VirtIO/QEMU"
    "15B3" = "Mellanox"
    "1D6A" = "Aquantia"
    # --- DMA / FPGA Verdacht ---
    "1172" = "Altera/Intel FPGA"
    "10EE" = "Xilinx FPGA"
    "1C3D" = "Xillybus (FPGA-Bridge)"
    "1A79" = "Bittware FPGA"
    "0955" = "NVIDIA (Jetson/Debug) - ATYPISCH"
    "1234" = "QEMU/Bochs VGA - VM-Indiz"
    "1B36" = "QEMU/KVM"
    "F1D0" = "DMA Attack Framework (bekannt)"
    "FEED" = "Generische Cheat-Vendor-ID"
    "CAFE" = "Generische Cheat-Vendor-ID"
    "DEAD" = "Generische Cheat-Vendor-ID"
    "BABE" = "Generische Cheat-Vendor-ID"
    "1337" = "Cheat-typische Debug-Vendor-ID"
}

# FPGA/DMA-Vendor-IDs Set
$DmaVendorIDs = @("1172","10EE","1C3D","1A79","0955","F1D0","FEED","CAFE","DEAD","BABE","1337","1234","1B36","1AF4")

# Bekannte Signer-Kategorien
function Get-DriverSignerCategory {
    param([string]$Signer)
    if ([string]::IsNullOrWhiteSpace($Signer)) { return "Unsigniert" }
    $s = $Signer.ToLower()
    if ($s -match "microsoft")           { return "Microsoft" }
    if ($s -match "nvidia")              { return "NVIDIA" }
    if ($s -match "amd|advanced micro")  { return "AMD" }
    if ($s -match "intel")               { return "Intel" }
    if ($s -match "realtek")             { return "Realtek" }
    if ($s -match "qualcomm")            { return "Qualcomm" }
    if ($s -match "broadcom")            { return "Broadcom" }
    if ($s -match "marvell")             { return "Marvell" }
    if ($s -match "asix|asimedia")       { return "ASMedia" }
    if ($s -match "renesas")             { return "Renesas" }
    return "3rd-Party: $Signer"
}

function Get-DeviceStatusText {
    param([uint32]$Code)
    $map = @{
        0="OK (Aktiv)"; 1="Kein Treiber"; 3="Treiber beschaedigt"; 10="FEHLER CODE 10"
        12="Ressourcenkonflikt"; 14="Neustart noetig"; 18="Treiber neu installieren"
        19="Registrierungsfehler"; 21="Geraet wird entfernt"; 22="Deaktiviert"
        24="Nicht vorhanden"; 28="Kein Treiber installiert"
        43="CODE 43 - SPOOF-INDIZ"; 45="Nicht verbunden"; 52="Signaturfehler"
    }
    if ($map.ContainsKey([int]$Code)) { return $map[[int]$Code] }
    return "Unbekannt ($Code)"
}

# ==============================================================================
# MODUL 1: BIOS / SYSTEM-INTEGRITAET
# ==============================================================================
Write-Section "MODUL 1: BIOS / UEFI & System-Integritaet"
Write-Step "Pruefe Secure Boot, IOMMU, DSE, Testsigning..."

$SystemIntegrity = [PSCustomObject]@{
    SecureBoot    = "Unbekannt"
    IOMMU         = "Unbekannt"
    TestSigning   = "Unbekannt"
    DSE_Status    = "Unbekannt"
    Hypervisor    = "Unbekannt"
    KernelPatch   = "Unbekannt"
}

# Secure Boot
try {
    $sb = Confirm-SecureBootUEFI -ErrorAction Stop
    $SystemIntegrity.SecureBoot = if ($sb) { "AKTIV" } else { "DEAKTIVIERT" }
} catch {
    $SystemIntegrity.SecureBoot = "N/A (Legacy BIOS oder Fehler)"
}

# IOMMU / VT-d via WMI DeviceGuard
try {
    $dg = Get-CimInstance -Namespace "root\Microsoft\Windows\DeviceGuard" -ClassName Win32_DeviceGuard -ErrorAction Stop
    $iommuVal = $dg.AvailableSecurityProperties
    # Property 2 = VT-d/IOMMU vorhanden
    if ($iommuVal -contains 2) {
        $SystemIntegrity.IOMMU = "VERFUEGBAR"
        if ($dg.VirtualizationBasedSecurityStatus -ge 2) {
            $SystemIntegrity.IOMMU = "AKTIV (VBS laeuft)"
        }
    } else {
        $SystemIntegrity.IOMMU = "NICHT VERFUEGBAR"
    }
} catch {
    # Fallback: CPUID-Heuristik via Registry
    $vt = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -ErrorAction SilentlyContinue
    $SystemIntegrity.IOMMU = if ($vt) { "Unbekannt (DeviceGuard-Reg. gefunden)" } else { "Nicht pruefbar" }
}

# Hypervisor (VM-Detektion - DMA-Bypass-Methode)
try {
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.HypervisorPresent) {
        $SystemIntegrity.Hypervisor = "HYPERVISOR AKTIV"
    } else {
        $SystemIntegrity.Hypervisor = "Kein Hypervisor"
    }
} catch { $SystemIntegrity.Hypervisor = "Fehler" }

# Testsigning & DSE via BCDEdit
try {
    $bcdOutput = & bcdedit /enum "{current}" 2>&1 | Out-String
    $SystemIntegrity.TestSigning = if ($bcdOutput -match "testsigning\s+Yes") { "AKTIVIERT [!]" } else { "Deaktiviert (OK)" }
    $SystemIntegrity.DSE_Status  = if ($bcdOutput -match "nointegritychecks\s+Yes") { "DEAKTIVIERT [!!!]" } else { "Aktiv (OK)" }
    # KernelPatch Protection
    $SystemIntegrity.KernelPatch = if ($bcdOutput -match "nopae|safeboot|disabledynamictick.*Yes") { "Anomalie erkannt" } else { "Unauffaellig" }
} catch {
    $SystemIntegrity.TestSigning = "BCDEdit Fehler"
    $SystemIntegrity.DSE_Status  = "BCDEdit Fehler"
}

# Anzeige und Risk-Berechnung
Write-Host "  │" -ForegroundColor DarkCyan
$integrityItems = @(
    @{ Label="Secure Boot";           Value=$SystemIntegrity.SecureBoot;  WarnPattern="DEAKTIVIERT|N/A" }
    @{ Label="IOMMU / VT-d";         Value=$SystemIntegrity.IOMMU;       WarnPattern="NICHT VERFUEGBAR|Nicht pruef" }
    @{ Label="Testsigning";           Value=$SystemIntegrity.TestSigning; WarnPattern="\[!\]" }
    @{ Label="Driver Sig. Enforc.";  Value=$SystemIntegrity.DSE_Status;  WarnPattern="\[!!!\]" }
    @{ Label="Hypervisor";           Value=$SystemIntegrity.Hypervisor;  WarnPattern="AKTIV" }
    @{ Label="Kernel-Parameter";     Value=$SystemIntegrity.KernelPatch; WarnPattern="Anomalie" }
)

foreach ($item in $integrityItems) {
    $lbl   = $item.Label.PadRight(25)
    $val   = $item.Value
    $isWarn = $val -match $item.WarnPattern
    Write-Host "  │   $lbl : " -ForegroundColor DarkCyan -NoNewline
    if ($isWarn) {
        Write-Host $val -ForegroundColor Yellow
    } else {
        Write-Host $val -ForegroundColor Green
    }
}

# Risk-Score Beitrag
if ($SystemIntegrity.SecureBoot -match "DEAKTIVIERT")  { Add-RiskPoints 10 10; Add-Finding "BIOS/UEFI" "HOCH"    "Secure Boot deaktiviert"                    $SystemIntegrity.SecureBoot }
if ($SystemIntegrity.TestSigning -match "\[!\]")        { Add-RiskPoints 15 15; Add-Finding "BIOS/UEFI" "HOCH"    "Testsigning aktiviert"                      "Erlaubt unsignierte Treiber" }
if ($SystemIntegrity.DSE_Status  -match "\[!!!\]")      { Add-RiskPoints 25 25; Add-Finding "BIOS/UEFI" "KRITISCH" "Driver Signature Enforcement deaktiviert"  "nointegritychecks=Yes in BCD" }
if ($SystemIntegrity.Hypervisor  -match "HYPERVISOR")   { Add-RiskPoints 10 10; Add-Finding "BIOS/UEFI" "MITTEL"  "Hypervisor aktiv"                          "Moegliche VM-Bypass-Methode" }
if ($SystemIntegrity.IOMMU       -match "NICHT")        { Add-RiskPoints  5 10; Add-Finding "BIOS/UEFI" "NIEDRIG" "IOMMU nicht verfuegbar"                    "Kein DMA-Schutz vorhanden" }

Write-SectionEnd

# ==============================================================================
# MODUL 2: TREIBERDATENBANK LADEN
# ==============================================================================
Write-Section "MODUL 2: Treiber- & Geraetedatenbank"
Write-Step "Lade PnP-Treiberdaten (Win32_PnPSignedDriver)..."

$driverData = @{}
Get-CimInstance Win32_PnPSignedDriver | ForEach-Object {
    if ($_.DeviceID -and -not $driverData.ContainsKey($_.DeviceID)) {
        $driverData[$_.DeviceID] = $_
    }
}
Write-OK "$($driverData.Count) Treiber-Eintraege geladen."
Write-SectionEnd

# ==============================================================================
# MODUL 3: PCIe-GERAETESCAN (Aktive Geraete + Lane-Analyse)
# ==============================================================================
Write-Section "MODUL 3: PCIe Geraetescan & Lane-Analyse"
Write-Step "Scanne aktive PCI-Geraete..."

# Lade PCIe-Controller-Info fuer Lane-Breite (via Win32_PnPAllocatedResource ist begrenzt,
# bessere Quelle ist die Registry PCI-Config-Space-Simulation)
# Lese PCIe Link-Informationen aus der Registry (verfuegbar unter W10/11)
$pciLinkData = @{}
try {
    $pciRegBase = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"
    Get-ChildItem $pciRegBase -ErrorAction SilentlyContinue | ForEach-Object {
        $vendDev = $_.PSChildName
        Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
            $instanceKey = $_.PSPath
            # Lese LogConfig oder BIOS-Konfiguration
            try {
                $linkProps = Get-ItemProperty "$instanceKey\Device Parameters\PciExpressCompatibility" -ErrorAction SilentlyContinue
                if ($linkProps) {
                    $pciLinkData[$vendDev] = $linkProps
                }
            } catch {}
        }
    }
} catch {}

# Geraetescan
$allPciDevices = Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.Caption -match "PCI" -or $_.DeviceID -match "^PCI\\" }

$results = $allPciDevices | ForEach-Object {
    $deviceID   = $_.DeviceID
    $caption    = if ($_.Caption) { $_.Caption } else { "(Kein Name)" }
    $drvEntry   = $driverData[$deviceID]
    $drvVersion = if ($drvEntry) { $drvEntry.DriverVersion } else { "N/A" }
    $drvDate    = if ($drvEntry -and $drvEntry.DriverDate) { $drvEntry.DriverDate } else { $null }
    $drvSigner  = if ($drvEntry) { Get-DriverSignerCategory $drvEntry.Signer } else { "Kein Treiber" }
    $statusCode = $_.ConfigManagerErrorCode
    $statusText = Get-DeviceStatusText $statusCode

    # ID-Extraktion
    $vendorID = "N/A"; $devID = "N/A"; $subSysID = "N/A"; $revID = "N/A"
    if ($deviceID -match 'VEN_([0-9A-Fa-f]{4})')      { $vendorID = $matches[1].ToUpper() }
    if ($deviceID -match 'DEV_([0-9A-Fa-f]{4})')      { $devID    = $matches[1].ToUpper() }
    if ($deviceID -match 'SUBSYS_([0-9A-Fa-f]{8})')   { $subSysID = $matches[1].ToUpper() }
    if ($deviceID -match 'REV_([0-9A-Fa-f]{2,})')     { $revID    = $matches[1].ToUpper() }

    # Vendor-Name ermitteln
    $vendorName = if ($KnownVendors.ContainsKey($vendorID)) { $KnownVendors[$vendorID] } else { "Unbekannt" }

    # Full Hardware ID
    $fullHWID = "N/A"
    try {
        $hwids = (Get-CimInstance -ClassName Win32_PnPEntity -Filter "DeviceID='$($deviceID -replace '\\','\\\\')'" -ErrorAction SilentlyContinue).HardwareID
        if ($hwids -and $hwids.Count -gt 0) { $fullHWID = $hwids[0] }
    } catch { $fullHWID = "Lesefehler" }

    # ---- HEURISTIK & VERDACHTS-SCORING ----
    $flags     = [System.Collections.Generic.List[string]]::new()
    $devScore  = 0

    # 1. Error Code 43 - Treiber-Reject (Spoofing-Klassiker)
    if ($statusCode -eq 43) { $flags.Add("[CODE-43] Treiber abgewiesen"); $devScore += 30 }

    # 2. Bekannte FPGA/DMA Vendor-IDs
    if ($vendorID -in $DmaVendorIDs) { $flags.Add("[FPGA/DMA-VID] $vendorName"); $devScore += 50 }

    # 3. FPGA-Namen im Caption
    if ($caption -match "Xilinx|Altera|Artix|FPGA|Lattice|ECP5|Cyclone|Kintex|Virtex|Spartan|PCILeech|NeTV2") {
        $flags.Add("[FPGA-NAME] $caption"); $devScore += 50
    }

    # 4. Verdaechtige USB-PCI-Bridges
    if ($caption -match "USB.*PCIe|PCIe.*USB.*Bridge|ExpressCard|Thunderbolt.*PCIe" -and
        $caption -notmatch "USB.*Host|USB.*xHCI|USB.*EHCI|USB.*OHCI") {
        $flags.Add("[USB-PCIe-Bridge]"); $devScore += 20
    }

    # 5. Unsignierter / Drittanbieter-Treiber
    if ($drvSigner -match "^Unsigniert$") { $flags.Add("[UNSIGN-DRV]"); $devScore += 25 }
    elseif ($drvSigner -match "^3rd-Party") { $flags.Add("[3RD-PARTY-DRV] $drvSigner"); $devScore += 10 }

    # 6. Kein Treiber bei AKTIVEM Geraet (Status 0 oder 43)
    if ($drvVersion -eq "N/A" -and $statusCode -in @(0, 43)) {
        $flags.Add("[NO-DRV-ACTIVE]"); $devScore += 15
    }

    # 7. Treiber-Datum-Anomalie: Treiber juenger als 1 Tag oder vor Jahr 2010
    if ($drvDate -ne $null) {
        $daysDiff = (Get-Date) - $drvDate
        if ($daysDiff.TotalDays -lt 1) { $flags.Add("[DRV-DATE] Treiber heute erstellt!"); $devScore += 20 }
        if ($drvDate.Year -lt 2010)    { $flags.Add("[DRV-DATE] Suspekt alt ($($drvDate.Year))"); $devScore += 10 }
    }

    # 8. SPOOF-HEURISTIK: Bekannter Vendor, aber Subsystem passt nicht
    if ($vendorID -eq "10DE" -and $subSysID -ne "N/A") {
        # Nvidia-Karten haben typischerweise SubSys-IDs von Board-Partnern (1043=ASUS, 1462=MSI etc.)
        $knownNvSubVendors = @("1043","1462","1458","196E","3842","1682","1B4C","10DE","19DA","1569","7377")
        $subVendor = $subSysID.Substring(4,4)
        if ($subVendor -notin $knownNvSubVendors -and $subVendor -ne "0000") {
            $flags.Add("[SPOOF-SUBSYS] NV-Karte mit unbekanntem Board-Vendor $subVendor"); $devScore += 30
        }
    }

    # 9. Intel-VID aber kein Intel-Signer
    if ($vendorID -eq "8086" -and $drvSigner -notmatch "Intel|Microsoft" -and $drvSigner -ne "Kein Treiber") {
        $flags.Add("[SPOOF-SIGNER] Intel-VID ohne Intel-Treiber"); $devScore += 25
    }

    # 10. AMD-VID aber kein AMD/Microsoft-Signer
    if ($vendorID -in @("1002","1022") -and $drvSigner -notmatch "AMD|Microsoft" -and $drvSigner -ne "Kein Treiber") {
        $flags.Add("[SPOOF-SIGNER] AMD-VID ohne AMD-Treiber"); $devScore += 25
    }

    # Status bestimmen
    $verdacht = if ($flags.Count -eq 0) { "OK" } else { $flags -join " | " }

    [PSCustomObject]@{
        Geraetename      = $caption
        "Vendor ID"      = $vendorID
        "Vendor Name"    = $vendorName
        "Device ID"      = $devID
        "SubSystem ID"   = $subSysID
        "Revision"       = $revID
        "Full HW ID"     = $fullHWID
        "Device Status"  = $statusText
        "Treiber Version"= $drvVersion
        "Treiber Datum"  = if ($drvDate) { $drvDate.ToString("yyyy-MM-dd") } else { "N/A" }
        "Driver Signer"  = $drvSigner
        "Hersteller"     = if ($_.Manufacturer) { $_.Manufacturer } else { "N/A" }
        "Geraetetyp"     = if ($_.PNPClass) { $_.PNPClass } else { "N/A" }
        "Verdacht"       = $verdacht
        "_Score"         = $devScore
        "_StatusCode"    = $statusCode
        "_DeviceID_Raw"  = $deviceID
    }
}

Write-OK "$($results.Count) PCI-Geraete gefunden."

# Verdaechtige Geraete herausfiltern
$suspicious = $results | Where-Object { $_.Verdacht -ne "OK" } | Sort-Object "_Score" -Descending

# Risk aus Geraeten
foreach ($dev in $suspicious) {
    $sc = [int]$dev._Score
    Add-RiskPoints $sc 50
    Add-Finding "PCIe-Geraet" (if ($sc -ge 40) {"KRITISCH"} elseif ($sc -ge 20) {"HOCH"} else {"MITTEL"}) `
        "$($dev.Geraetename) [VEN:$($dev.'Vendor ID') DEV:$($dev.'Device ID')]" $dev.Verdacht
}

Write-OK "$($suspicious.Count) verdaechtige Geraete identifiziert."
Write-SectionEnd

# ==============================================================================
# MODUL 4: REGISTRY GHOST-DEVICE SCAN
# ==============================================================================
if (-not $SkipRegistry) {
    Write-Section "MODUL 4: Registry Ghost-Device Scan"
    Write-Step "Scanne HKLM:\SYSTEM\CurrentControlSet\Enum\PCI nach Geister-Geraeten..."

    $ghostDevices = [System.Collections.Generic.List[PSCustomObject]]::new()
    $activeIDs    = $results | ForEach-Object { $_._DeviceID_Raw }

    try {
        $pciRegBase = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"
        Get-ChildItem $pciRegBase -ErrorAction Stop | ForEach-Object {
            $hwKey = $_
            $vendDevRaw = $hwKey.PSChildName  # z.B. VEN_10EE&DEV_1234&SUBSYS_...&REV_00

            Get-ChildItem $hwKey.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                $instanceKey  = $_.PSPath
                $instanceName = $_.PSChildName

                # Pruefe ob dieses Geraet gerade aktiv ist
                $fullRegID = "PCI\$($hwKey.PSChildName)\$instanceName"
                $isActive  = $activeIDs -contains $fullRegID

                if (-not $isActive) {
                    # Lese Friendly-Name
                    $props = Get-ItemProperty $instanceKey -ErrorAction SilentlyContinue
                    $friendlyName = if ($props.FriendlyName)   { $props.FriendlyName }
                                  elseif ($props.DeviceDesc) { $props.DeviceDesc -replace '@.*','' }
                                  else { "(Kein Name)" }

                    # Extrahiere Vendor/Device
                    $gVendor = "N/A"; $gDev = "N/A"
                    if ($vendDevRaw -match 'VEN_([0-9A-Fa-f]{4})') { $gVendor = $matches[1].ToUpper() }
                    if ($vendDevRaw -match 'DEV_([0-9A-Fa-f]{4})') { $gDev    = $matches[1].ToUpper() }
                    $gVendorName = if ($KnownVendors.ContainsKey($gVendor)) { $KnownVendors[$gVendor] } else { "Unbekannt" }

                    $ghostScore = 0
                    $ghostFlags = [System.Collections.Generic.List[string]]::new()
                    if ($gVendor -in $DmaVendorIDs) { $ghostFlags.Add("[FPGA/DMA-VID]"); $ghostScore += 40 }
                    if ($friendlyName -match "Xilinx|Altera|FPGA|PCILeech|Xillybus") { $ghostFlags.Add("[FPGA-NAME]"); $ghostScore += 40 }

                    $ghostDevices.Add([PSCustomObject]@{
                        "Geraetename"  = $friendlyName
                        "Vendor ID"    = $gVendor
                        "Vendor Name"  = $gVendorName
                        "Device ID"    = $gDev
                        "Status"       = "GETRENNT (Ghost)"
                        "Reg-Key"      = $fullRegID
                        "Flags"        = if ($ghostFlags.Count -gt 0) { $ghostFlags -join " | " } else { "Nur getrennt" }
                        "_Score"       = $ghostScore
                    })
                }
            }
        }
    } catch {
        Write-Warn "Registry-Scan fehlgeschlagen: $_"
    }

    if ($ghostDevices.Count -gt 0) {
        Write-Warn "$($ghostDevices.Count) getrennte/Ghost-Geraete in Registry gefunden."
        $critGhosts = $ghostDevices | Where-Object { $_._Score -gt 0 }
        if ($critGhosts.Count -gt 0) {
            Write-Crit "$($critGhosts.Count) Ghost-Geraete mit FPGA/DMA-Verdacht!"
            foreach ($g in $critGhosts) {
                Write-Crit "  $($g.Geraetename) | VEN:$($g.'Vendor ID') DEV:$($g.'Device ID') | $($g.Flags)"
                Add-RiskPoints $g._Score 40
                Add-Finding "Ghost-Geraet" "KRITISCH" "$($g.Geraetename) [GHOST]" $g.Flags
            }
        }
    } else {
        Write-OK "Keine Ghost-Geraete gefunden."
    }
    Write-SectionEnd
}

# ==============================================================================
# MODUL 5: USB-FORENSIK (DMA-Fokus - nur Hardware-Interfaces)
# ==============================================================================
Write-Section "MODUL 5: USB & Thunderbolt Hardware-Interface Forensik"
Write-Step "Analysiere USB-Controller und externe PCIe-Bridges..."

$usbSuspects = [System.Collections.Generic.List[PSCustomObject]]::new()

# USB-Controller scannen
$usbControllers = Get-CimInstance Win32_USBController -ErrorAction SilentlyContinue
foreach ($ctrl in $usbControllers) {
    $uScore = 0; $uFlags = [System.Collections.Generic.List[string]]::new()

    if ($ctrl.Name -match "Generic|Unknown|unbekannt") { $uFlags.Add("[GENERIC-CTRL]"); $uScore += 15 }
    if ($ctrl.Name -match "PCIe|ExpressCard|Thunderbolt") { $uFlags.Add("[THUNDERBOLT/PCIE-USB]"); $uScore += 20 }
    if ($ctrl.Manufacturer -eq $null -or $ctrl.Manufacturer -match "^$") { $uFlags.Add("[NO-MANUFACTURER]"); $uScore += 10 }

    if ($uScore -gt 0) {
        $usbSuspects.Add([PSCustomObject]@{
            Name         = $ctrl.Name
            Hersteller   = if ($ctrl.Manufacturer) { $ctrl.Manufacturer } else { "N/A" }
            Status       = $ctrl.Status
            Flags        = $uFlags -join " | "
            Score        = $uScore
        })
    }
}

# Thunderbolt-Bridges
$tbDevices = Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.Caption -match "Thunderbolt|TBT|USB4" } |
    Select-Object Caption, Manufacturer, DeviceID

foreach ($tb in $tbDevices) {
    Write-Warn "Thunderbolt/USB4 Interface: $($tb.Caption)"
    Add-RiskPoints 5 10
    Add-Finding "USB/Thunderbolt" "MITTEL" "Thunderbolt-Interface gefunden" $tb.Caption
}

# Externe PCIe-Erweiterungskarten ueber USB
$extPcie = Get-CimInstance Win32_PnPEntity |
    Where-Object { $_.Caption -match "USB.*PCI|PCI.*USB.*Adapter|eGPU|external.*GPU" }

foreach ($ep in $extPcie) {
    Write-Crit "Externer PCIe-Adapter via USB: $($ep.Caption)"
    Add-RiskPoints 20 20
    Add-Finding "USB/Thunderbolt" "HOCH" "Externer PCIe-Adapter (eGPU/DMA-Kandidat)" $ep.Caption
}

if ($usbSuspects.Count -gt 0) {
    Write-Warn "$($usbSuspects.Count) auffaellige USB-Controller:"
    foreach ($u in $usbSuspects) {
        Write-Warn "  $($u.Name) | $($u.Flags)"
        Add-RiskPoints $u.Score 20
        Add-Finding "USB-Controller" "MITTEL" $u.Name $u.Flags
    }
} else {
    Write-OK "Keine auffaelligen USB-Controller-Konfigurationen."
}

if ($tbDevices.Count -eq 0 -and $extPcie.Count -eq 0) {
    Write-OK "Keine Thunderbolt/USB4/eGPU-Interfaces gefunden."
}
Write-SectionEnd

# ==============================================================================
# MODUL 6: HID FILTER-TREIBER ANALYSE
# ==============================================================================
if (-not $SkipHID) {
    Write-Section "MODUL 6: HID Filter-Treiber (Aim-Assist Detection)"
    Write-Step "Pruefe UpperFilters und LowerFilters bei HID-Geraeten..."

    $hidFindings = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Bekannte legitime Filter (Whitelist)
    $knownLegitFilters = @(
        "mouclass","kbdclass","mshidkmdf","hidbth","hidusb","kbdhid","mouhid",
        "hidinterrupt","wdfilter","winhv","dumpsd","dumpata","klif","klkbd","klmouflt",
        "hwpolicy","lfsvc","rdprefmp","rdpdr","tdi","npf"
    )

    $hidRegPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{745a17a0-74d3-11d0-b6fe-00a0c90f57da}",  # HID
        "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96f-e325-11ce-bfc1-08002be10318}",  # Maus
        "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}"   # Tastatur
    )

    foreach ($regPath in $hidRegPaths) {
        if (-not (Test-Path $regPath)) { continue }
        $subKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
        foreach ($sk in $subKeys) {
            $props = Get-ItemProperty $sk.PSPath -ErrorAction SilentlyContinue
            foreach ($filterType in @("UpperFilters","LowerFilters")) {
                $filterVal = $props.$filterType
                if ($filterVal) {
                    foreach ($f in $filterVal) {
                        $fLower = $f.ToLower().Trim()
                        if ($fLower -notin $knownLegitFilters -and -not [string]::IsNullOrWhiteSpace($fLower)) {
                            $hidFindings.Add([PSCustomObject]@{
                                Typ     = $filterType
                                Treiber = $f
                                Pfad    = $sk.PSPath
                            })
                        }
                    }
                }
            }
        }
    }

    # Direkte System-Level Filter (globale HID-Filter)
    $globalHidFilter = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{745a17a0-74d3-11d0-b6fe-00a0c90f57da}" -ErrorAction SilentlyContinue
    foreach ($ft in @("UpperFilters","LowerFilters")) {
        $fv = $globalHidFilter.$ft
        if ($fv) {
            foreach ($f in $fv) {
                $fLower = $f.ToLower().Trim()
                if ($fLower -notin $knownLegitFilters -and -not [string]::IsNullOrWhiteSpace($fLower)) {
                    $hidFindings.Add([PSCustomObject]@{
                        Typ     = "[GLOBAL] $ft"
                        Treiber = $f
                        Pfad    = "Global HID Class"
                    })
                    Add-RiskPoints 30 30
                    Add-Finding "HID-Filter" "KRITISCH" "Globaler HID-Filter-Treiber: $f" $ft
                }
            }
        }
    }

    if ($hidFindings.Count -gt 0) {
        Write-Crit "$($hidFindings.Count) unbekannte HID-Filter-Treiber gefunden!"
        foreach ($hf in $hidFindings) {
            Write-Crit "  [$($hf.Typ)] -> $($hf.Treiber)"
            Add-RiskPoints 20 30
            Add-Finding "HID-Filter" "HOCH" "Ungekannter HID-Filter: $($hf.Treiber)" $hf.Typ
        }
    } else {
        Write-OK "Keine verdaechtigen HID-Filter-Treiber gefunden."
    }
    Write-SectionEnd
}

# ==============================================================================
# MODUL 7: DUPLIZIERTE VENDOR/DEVICE-ID PRUEFUNG
# ==============================================================================
Write-Section "MODUL 7: Duplikat-ID & Spoof-Erkennung"
Write-Step "Pruefe auf geklonte/duplizierte Hardware-IDs..."

$idGroups = $results |
    Where-Object { $_."Vendor ID" -ne "N/A" -and $_."Device ID" -ne "N/A" } |
    Group-Object { "$($_.'Vendor ID')_$($_.'Device ID')" } |
    Where-Object { $_.Count -gt 1 }

if ($idGroups.Count -gt 0) {
    Write-Crit "$($idGroups.Count) duplizierte VEN/DEV-ID-Kombinationen!"
    foreach ($grp in $idGroups) {
        Write-Crit "  ID-Kombi: $($grp.Name) -> $($grp.Count)x vorhanden"
        Add-RiskPoints 30 30
        Add-Finding "ID-Spoofing" "KRITISCH" "Duplizierte Hardware-ID: $($grp.Name)" "$($grp.Count)x im System"
    }
} else {
    Write-OK "Keine duplizierten Hardware-IDs."
}

# Pruefe auf Geraete die bekannte IDs imitieren (z.B. VEN=10DE aber Name passt nicht)
$spoofSuspects = $results | Where-Object {
    ($_."Vendor ID" -eq "10DE" -and $_."Geraetename" -notmatch "NVIDIA|GeForce|Quadro|Tesla|NVS|NForce|nForce") -or
    ($_."Vendor ID" -eq "8086" -and $_."Geraetename" -notmatch "Intel|HD|UHD|Iris|Arc|Ethernet|Audio|USB|SATA|NVM|PCH|SMBus|Thermal|Management|LAN|Wi-Fi|Bluetooth|ME|QST|Platform|Bridge|Root" -and $_."Geraetename" -ne "(Kein Name)") -or
    ($_."Vendor ID" -eq "1002" -and $_."Geraetename" -notmatch "AMD|Radeon|RX|Vega|Navi|Polaris|Ellesmere|Fiji|Hawaii|Audio|USB|HDMI")
}

if ($spoofSuspects.Count -gt 0) {
    Write-Crit "$($spoofSuspects.Count) Geraete mit Vendor-Name-Mismatch (Spoofing-Verdacht)!"
    foreach ($ss in $spoofSuspects) {
        Write-Crit "  VEN:$($ss.'Vendor ID') ($($ss.'Vendor Name')) - Name: '$($ss.Geraetename)'"
        Add-RiskPoints 35 40
        Add-Finding "ID-Spoofing" "KRITISCH" "Vendor-Name-Mismatch: VEN=$($ss.'Vendor ID')" $ss.Geraetename
    }
} else {
    Write-OK "Kein Vendor-Name-Mismatch erkannt."
}
Write-SectionEnd

# ==============================================================================
# ANZEIGE: VERDAECHTIGE GERAETE TABELLE
# ==============================================================================
Write-Section "ERGEBNIS-TABELLE: Verdaechtige PCIe-Geraete"

if ($suspicious.Count -gt 0) {
    Write-Host "  │" -ForegroundColor DarkCyan
    # Tabellenheader
    $hdr = "  │  {0,-35} {1,-6} {2,-6} {3,-8} {4,-8}" -f "Geraetename","VEN","DEV","Score","Status-Kurzinfo"
    Write-Host $hdr -ForegroundColor Cyan
    Write-Host "  │  $('─'*80)" -ForegroundColor DarkGray

    foreach ($dev in $suspicious) {
        $shortName = if ($dev.Geraetename.Length -gt 33) { $dev.Geraetename.Substring(0,30) + "..." } else { $dev.Geraetename }
        $scoreVal  = [int]$dev._Score
        $color     = if ($scoreVal -ge 40) { "Red" } elseif ($scoreVal -ge 20) { "Yellow" } else { "Gray" }
        $line = "  │  {0,-35} {1,-6} {2,-6} {3,-8} {4}" -f $shortName, $dev."Vendor ID", $dev."Device ID", "[$scoreVal]", ($dev.Verdacht -split "\|")[0].Trim()
        Write-Host $line -ForegroundColor $color
    }

    Write-Host "  │  $('─'*80)" -ForegroundColor DarkGray
    Write-Host "  │" -ForegroundColor DarkCyan
    Write-Host "  │  Legende: " -ForegroundColor DarkCyan -NoNewline
    Write-Host "[ROT]" -ForegroundColor Red -NoNewline; Write-Host " Score >= 40 (Kritisch)  " -ForegroundColor Gray -NoNewline
    Write-Host "[GELB]" -ForegroundColor Yellow -NoNewline; Write-Host " Score >= 20 (Hoch)  " -ForegroundColor Gray -NoNewline
    Write-Host "[GRAU]" -ForegroundColor Gray -NoNewline; Write-Host " Score < 20 (Verdacht)" -ForegroundColor Gray
} else {
    Write-Host "  │" -ForegroundColor DarkCyan
    Write-OK "Keine verdaechtigen PCIe-Geraete gefunden."
}

if ($Verbose) {
    Write-Host "  │" -ForegroundColor DarkCyan
    Write-Host "  │  [VERBOSE] Alle $($results.Count) PCI-Geraete:" -ForegroundColor Cyan
    Write-Host "  │  $('─'*80)" -ForegroundColor DarkGray
    foreach ($dev in $results | Sort-Object "Geraetename") {
        $shortName = if ($dev.Geraetename.Length -gt 33) { $dev.Geraetename.Substring(0,30) + "..." } else { $dev.Geraetename }
        $line = "  │  {0,-35} {1,-6} {2,-6} {3}" -f $shortName, $dev."Vendor ID", $dev."Device ID", $dev."Driver Signer"
        $col  = if ($dev.Verdacht -eq "OK") { "DarkGray" } else { "Yellow" }
        Write-Host $line -ForegroundColor $col
    }
}
Write-SectionEnd

# ==============================================================================
# FINDINGS-TABELLE
# ==============================================================================
if ($script:FindingsList.Count -gt 0) {
    Write-Section "ALLE FINDINGS (sortiert nach Schwere)"
    Write-Host "  │" -ForegroundColor DarkCyan

    $schwereOrder = @{ "KRITISCH"=0; "HOCH"=1; "MITTEL"=2; "NIEDRIG"=3 }
    $sortedFindings = $script:FindingsList | Sort-Object { $schwereOrder[$_.Schwere] }

    foreach ($f in $sortedFindings) {
        $col = switch ($f.Schwere) {
            "KRITISCH" { "Red" }
            "HOCH"     { "Yellow" }
            "MITTEL"   { "Cyan" }
            default    { "Gray" }
        }
        $tag = "[$($f.Schwere)]".PadRight(12)
        Write-Host "  │  $tag " -ForegroundColor $col -NoNewline
        Write-Host "[$($f.Kategorie)] " -ForegroundColor DarkCyan -NoNewline
        Write-Host $f.Beschreibung -ForegroundColor White
        if ($f.Detail -and $f.Detail.Length -gt 0) {
            Write-Host "  │           " -ForegroundColor DarkCyan -NoNewline
            Write-Host "-> $($f.Detail)" -ForegroundColor DarkGray
        }
    }
    Write-SectionEnd
}

# ==============================================================================
# RISK-INDEX BERECHNUNG
# ==============================================================================
$riskPct = if ($script:RiskMax -gt 0) {
    [Math]::Round(($script:RiskScore / $script:RiskMax) * 100)
} else { 0 }
$riskPct = [Math]::Min($riskPct, 100)

$verdict = if ($script:FindingsList | Where-Object { $_.Schwere -eq "KRITISCH" }) {
    if ($riskPct -ge 30) { "KRITISCH" } else { "VERDAECHTIG" }
} elseif ($script:FindingsList | Where-Object { $_.Schwere -eq "HOCH" }) {
    "VERDAECHTIG"
} elseif ($riskPct -ge 10) {
    "ERHOEHTES_RISIKO"
} else {
    "SICHER"
}

# Risk-Balken
$barFilled = [Math]::Round($riskPct / 2)
$barEmpty  = 50 - $barFilled
$bar       = ("█" * $barFilled) + ("░" * $barEmpty)
$barColor  = if ($riskPct -ge 60) { "Red" } elseif ($riskPct -ge 30) { "Yellow" } else { "Green" }

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "  ║              ANALYSE-ERGEBNIS & RISK-INDEX                                  ║" -ForegroundColor DarkCyan
Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   Risk-Score    : $($script:RiskScore) / (berechnetes Max: $($script:RiskMax))                                  " -ForegroundColor Gray -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   Risk-Index    : " -ForegroundColor Gray -NoNewline
Write-Host "$bar $riskPct%" -ForegroundColor $barColor -NoNewline
Write-Host "                            ║" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline
Write-Host "   Findings      : $($script:FindingsList.Count) total | " -ForegroundColor Gray -NoNewline
Write-Host "KRITISCH: $(($script:FindingsList | Where-Object {$_.Schwere -eq 'KRITISCH'}).Count)  " -ForegroundColor Red -NoNewline
Write-Host "HOCH: $(($script:FindingsList | Where-Object {$_.Schwere -eq 'HOCH'}).Count)  " -ForegroundColor Yellow -NoNewline
Write-Host "MITTEL: $(($script:FindingsList | Where-Object {$_.Schwere -eq 'MITTEL'}).Count)              " -ForegroundColor Cyan -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor DarkCyan
Write-Host "  ║" -ForegroundColor DarkCyan -NoNewline

$verdictColor = switch ($verdict) {
    "SICHER"           { "Green" }
    "ERHOEHTES_RISIKO" { "Cyan" }
    "VERDAECHTIG"      { "Yellow" }
    "KRITISCH"         { "Red" }
}
$verdictLine = "   ANALYSE-ERGEBNIS :  [ $verdict ]"
Write-Host $verdictLine.PadRight(79) -ForegroundColor $verdictColor -NoNewline
Write-Host "║" -ForegroundColor DarkCyan
Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host ""

# ==============================================================================
# SCHRITT: SPEICHERN
# ==============================================================================
if (-not $NoSave) {
    Write-Host "  ─────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $saveChoice = Read-Host "  [>] Bericht als TXT auf Desktop speichern? (J/N)"

    if ($saveChoice -match "^[JjYy]") {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        if ([string]::IsNullOrWhiteSpace($desktopPath) -or -not (Test-Path $desktopPath -ErrorAction SilentlyContinue)) {
            $desktopPath = $env:TEMP
        }
        $timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $outputFile = Join-Path $desktopPath "PCICheck_v3_$($env:COMPUTERNAME)_$timestamp.txt"

        $sb = [System.Text.StringBuilder]::new()
        $null = $sb.AppendLine("=" * 80)
        $null = $sb.AppendLine("  PCICheck v3.0 - DMA / Cheat Hardware Forensik")
        $null = $sb.AppendLine("=" * 80)
        $null = $sb.AppendLine("  Zeitstempel  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $null = $sb.AppendLine("  Hostname     : $($env:COMPUTERNAME)")
        $null = $sb.AppendLine("  Benutzer     : $($env:USERNAME)")
        $null = $sb.AppendLine("  OS           : $((Get-CimInstance Win32_OperatingSystem).Caption)")
        $null = $sb.AppendLine("  Risk-Index   : $riskPct% | Ergebnis: $verdict")
        $null = $sb.AppendLine("=" * 80)
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("SYSTEM-INTEGRITAET")
        $null = $sb.AppendLine("-" * 40)
        $null = $sb.AppendLine("  Secure Boot  : $($SystemIntegrity.SecureBoot)")
        $null = $sb.AppendLine("  IOMMU/VT-d   : $($SystemIntegrity.IOMMU)")
        $null = $sb.AppendLine("  Testsigning  : $($SystemIntegrity.TestSigning)")
        $null = $sb.AppendLine("  DSE          : $($SystemIntegrity.DSE_Status)")
        $null = $sb.AppendLine("  Hypervisor   : $($SystemIntegrity.Hypervisor)")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("FINDINGS ($($script:FindingsList.Count) gesamt)")
        $null = $sb.AppendLine("-" * 40)
        foreach ($f in ($script:FindingsList | Sort-Object { $schwereOrder[$_.Schwere] })) {
            $null = $sb.AppendLine("  [$($f.Schwere)] [$($f.Kategorie)] $($f.Beschreibung)")
            if ($f.Detail) { $null = $sb.AppendLine("           -> $($f.Detail)") }
        }
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("VERDAECHTIGE PCIe-GERAETE ($($suspicious.Count))")
        $null = $sb.AppendLine("-" * 40)
        foreach ($dev in $suspicious) {
            $null = $sb.AppendLine("  Name    : $($dev.Geraetename)")
            $null = $sb.AppendLine("  IDs     : VEN=$($dev.'Vendor ID') DEV=$($dev.'Device ID') SUBSYS=$($dev.'SubSystem ID') REV=$($dev.Revision)")
            $null = $sb.AppendLine("  Status  : $($dev.'Device Status')")
            $null = $sb.AppendLine("  Treiber : $($dev.'Treiber Version') | Datum: $($dev.'Treiber Datum') | Signer: $($dev.'Driver Signer')")
            $null = $sb.AppendLine("  Score   : $($dev._Score)")
            $null = $sb.AppendLine("  Flags   : $($dev.Verdacht)")
            $null = $sb.AppendLine("  Raw-ID  : $($dev._DeviceID_Raw)")
            $null = $sb.AppendLine("")
        }
        $null = $sb.AppendLine("ALLE PCI-GERAETE ($($results.Count))")
        $null = $sb.AppendLine("-" * 40)
        foreach ($dev in $results) {
            $null = $sb.AppendLine("  $($dev.Geraetename) | VEN:$($dev.'Vendor ID') DEV:$($dev.'Device ID') | $($dev.'Driver Signer') | $($dev.Verdacht)")
        }
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("=" * 80)
        $null = $sb.AppendLine("Ende des Berichts - PCICheck v3.0")

        try {
            $sb.ToString() | Out-File -FilePath $outputFile -Encoding UTF8 -Force
            Write-Host "  [+] Bericht gespeichert: $outputFile" -ForegroundColor Green
        } catch {
            Write-Host "  [!] Speicherfehler: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [-] Speichern uebersprungen." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Read-Host "  [>] Enter druecken zum Beenden"
