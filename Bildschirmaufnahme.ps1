param(
    [string[]]$ProcessNames = @(
        # --- OBS ---
        'obs64', 'obs',

        # --- Medal ---
        'MedalClient', 'MedalEncoder', 'MedalService',

        # --- Streamlabs ---
        'Streamlabs', 'StreamlabsOBS', 'obs-streamlabs',

        # --- Xbox Game Bar / Windows DVR ---
        'XboxGameBar', 'GameBar', 'GameBarFTService',
        'WinGameOverlay', 'GameDVR',

        # --- NVIDIA ShadowPlay / NVIDIA App ---
        'NVIDIA Share', 'nvsphelper64', 'nvcontainer',
        'nvidia-app', 'NgpOverlay', 'NvOAWrapperCache',

        # --- AMD ReLive / Adrenalin ---
        'AMDRSServ', 'RadeonSoftware', 'amdow', 'amdaemon',
        'AMDRSServiceLauncher',

        # --- Intel Arc / Intel GPA ---
        'IntelGPA', 'GamingOverlay', 'igfxEM',

        # --- Outplayed / Overwolf ---
        'Overwolf', 'OutplayedTV', 'OverwolfBrowser',

        # --- FlashBack ---
        'FlashBackAgent', 'FlashBackRecorder',

        # --- Camtasia ---
        'CamtasiaStudio', 'CamRecorder',

        # --- Bandicam ---
        'bandicam', 'bdcam',

        # --- Fraps ---
        'fraps',

        # --- ApowerREC ---
        'ApowerREC',

        # --- Ezvid ---
        'Ezvid',

        # --- XSplit ---
        'XSplitBroadcaster', 'XSplit.Core', 'XSplitGamecaster',

        # --- ScreenRec ---
        'Screenrec',

        # --- LoiLo ---
        'LoiLoGameRecorder',

        # --- Action! (Mirillis) ---
        'Action',

        # --- Gecata by Movavi ---
        'Gecata',

        # --- Nvidia GeForce Experience (legacy) ---
        'GFExperience',

        # --- ShareX ---
        'ShareX',

        # --- Icecream Screen Recorder ---
        'IcecreamScreenRecorder',

        # --- D3DGear ---
        'D3DGear',

        # --- PlaysTV ---
        'PlaysTV', 'PlaysLauncher'
    )
)

$host.ui.RawUI.WindowTitle = "Check Screen Recording - Made by V!PER"
Clear-Host

Write-Host ""
Write-Host -ForegroundColor Magenta @"
  ██╗   ██╗██╗██████╗ ███████╗██████╗
  ██║   ██║██║██╔══██╗██╔════╝██╔══██╗
  ██║   ██║██║██████╔╝█████╗  ██████╔╝
  ╚██╗ ██╔╝██║██╔═══╝ ██╔══╝  ██╔══██╗
   ╚████╔╝ ██║██║     ███████╗██║  ██║
    ╚═══╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝
"@

Write-Host -ForegroundColor White "               Check Screen Recording - Made by " -NoNewLine
Write-Host -ForegroundColor Magenta "V!PER"
Write-Host ""

# ----------------------------------------------------------------
# Beschreibungs-Mapping: Prozessname -> Lesbarer Programmname
# ----------------------------------------------------------------
$ProcessDescriptions = @{
    # OBS
    'obs64'                  = 'OBS Studio (64-bit)'
    'obs'                    = 'OBS Studio'

    # Medal
    'MedalClient'            = 'Medal Screen Recorder'
    'MedalEncoder'           = 'Medal Screen Recorder (Encoder)'
    'MedalService'           = 'Medal Screen Recorder (Service/Hintergrund)'

    # Streamlabs
    'Streamlabs'             = 'Streamlabs'
    'StreamlabsOBS'          = 'Streamlabs OBS'
    'obs-streamlabs'         = 'Streamlabs OBS (intern)'

    # Xbox Game Bar / Windows DVR
    'XboxGameBar'            = 'Xbox Game Bar'
    'GameBar'                = 'Xbox Game Bar'
    'GameBarFTService'       = 'Xbox Game Bar (Hintergrund-Service)'
    'WinGameOverlay'         = 'Windows Game DVR Overlay'
    'GameDVR'                = 'Windows Game DVR (Hintergrundaufnahme)'

    # NVIDIA ShadowPlay / NVIDIA App
    'NVIDIA Share'           = 'NVIDIA ShadowPlay / Share'
    'nvsphelper64'           = 'NVIDIA ShadowPlay (Instant Replay Hintergrund)'
    'nvcontainer'            = 'NVIDIA App / ShadowPlay Container'
    'nvidia-app'             = 'NVIDIA App (Instant Replay)'
    'NgpOverlay'             = 'NVIDIA App Overlay (Instant Replay Hintergrund)'
    'NvOAWrapperCache'       = 'NVIDIA Overlay Wrapper (Hintergrund)'

    # AMD ReLive / Adrenalin
    'AMDRSServ'              = 'AMD ReLive / Adrenalin (Service)'
    'RadeonSoftware'         = 'AMD Radeon Software'
    'amdow'                  = 'AMD Adrenalin Overlay (Instant Replay Hintergrund)'
    'amdaemon'               = 'AMD Adrenalin Daemon (Hintergrundaufnahme)'
    'AMDRSServiceLauncher'   = 'AMD ReLive Service Launcher'

    # Intel Arc / GPA
    'IntelGPA'               = 'Intel Graphics Performance Analyzer'
    'GamingOverlay'          = 'Intel Arc Overlay (Hintergrundaufnahme)'
    'igfxEM'                 = 'Intel Graphics Event Monitor'

    # Outplayed / Overwolf
    'Overwolf'               = 'Overwolf (Plattform fur Outplayed etc.)'
    'OutplayedTV'            = 'Outplayed (Instant Replay Hintergrund)'
    'OverwolfBrowser'        = 'Overwolf Browser (Hintergrund)'

    # FlashBack
    'FlashBackAgent'         = 'FlashBack Recorder (Agent)'
    'FlashBackRecorder'      = 'FlashBack Recorder'

    # Camtasia
    'CamtasiaStudio'         = 'Camtasia Studio'
    'CamRecorder'            = 'Camtasia Recorder'

    # Bandicam
    'bandicam'               = 'Bandicam'
    'bdcam'                  = 'Bandicam (Treiber-Prozess)'

    # Fraps
    'fraps'                  = 'Fraps'

    # ApowerREC
    'ApowerREC'              = 'ApowerREC'

    # Ezvid
    'Ezvid'                  = 'Ezvid'

    # XSplit
    'XSplitBroadcaster'      = 'XSplit Broadcaster'
    'XSplit.Core'            = 'XSplit Core'
    'XSplitGamecaster'       = 'XSplit Gamecaster'

    # ScreenRec
    'Screenrec'              = 'ScreenRec'

    # LoiLo
    'LoiLoGameRecorder'      = 'LoiLo Game Recorder'

    # Action! (Mirillis)
    'Action'                 = 'Action! by Mirillis'

    # Gecata
    'Gecata'                 = 'Gecata by Movavi'

    # GeForce Experience (legacy)
    'GFExperience'           = 'NVIDIA GeForce Experience (Legacy)'

    # ShareX
    'ShareX'                 = 'ShareX'

    # Icecream
    'IcecreamScreenRecorder' = 'Icecream Screen Recorder'

    # D3DGear
    'D3DGear'                = 'D3DGear'

    # PlaysTV
    'PlaysTV'                = 'PlaysTV (Hintergrundaufnahme)'
    'PlaysLauncher'          = 'PlaysTV Launcher'
}

# ----------------------------------------------------------------
# Hilfsfunktion: Aktive Prozesse aus der Liste suchen
# ----------------------------------------------------------------
function Get-ActiveScreenRecordingProcesses {
    param (
        [string[]]$Names
    )
    $found = @()
    foreach ($name in $Names) {
        try {
            $procs = Get-Process -Name $name -ErrorAction Stop
            $found += $procs
        } catch {
            # Prozess nicht gefunden - ignorieren
        }
    }
    return $found
}

# ----------------------------------------------------------------
# Hauptlogik
# ----------------------------------------------------------------
$activeProcs = Get-ActiveScreenRecordingProcesses -Names $ProcessNames

if ($activeProcs) {
    Write-Host -ForegroundColor Red "  [!] Aktive Aufnahme-Prozesse gefunden:"
    Write-Host ""

    $activeProcs | ForEach-Object {
        $procName = $_.Name
        $desc = $ProcessDescriptions[$procName]
        if (-not $desc) { $desc = "Unbekannt / Nicht zugeordnet" }

        [PSCustomObject]@{
            Programm  = $desc
            Prozess   = $procName
            PID       = $_.Id
            # Pfad    = $_.Path   # optional: auskommentieren zum Aktivieren
        }
    } | Format-Table -AutoSize

} else {
    Write-Host -ForegroundColor Green "  [OK] Keine aktiven Bildschirmaufnahme-Prozesse gefunden."
    Write-Host ""
}