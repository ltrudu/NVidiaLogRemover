#Requires -Version 5.1
<#
.SYNOPSIS
    Simple GUI (French or English) that fixes the NVIDIA "nvlog.nvlgstg" log growth problem.

.DESCRIPTION
    - Shows the state of the PC: log file size (live), installed NVIDIA driver,
      whether the replacement driver is already downloaded.
    - Steps: clean the log (stop service / delete / restart), uninstall the faulty
      driver (621.14 / 621.24), download 621.01, install it, delete the download.
    - No "do everything" button on purpose: at start-up and after every action the
      program reads the real state of the PC (log size, installed driver, downloaded
      installer, pending reboot) and highlights the next step in yellow. After a
      reboot, the child just relaunches the program and follows the yellow button.
    All user-facing texts live in messages.<Language>.psd1 (keep this file ASCII-only).
    Must run elevated: launch it through ..\EXECUTE_MOI_Francais.bat (fr) or ..\RUN_ME_English.bat (en).

.PARAMETER Language
    'fr' (default) or 'en': selects messages.fr.psd1 / messages.en.psd1. Also passed to the
    automatic cleanup task so its history lines use the same language.
#>
[CmdletBinding()]
param(
    [ValidateSet('fr', 'en')]
    [string]$Language = 'fr'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$T = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "messages.$Language.psd1")
# Numbers (sizes) are formatted like the chosen language ("11,5 Go" / "11.5 GB"), whatever the Windows locale.
$Culture = [Globalization.CultureInfo]::GetCultureInfo($T.CultureName)

# ============================================================== Configuration
$Config = @{
    ServiceName           = 'NVDisplay.ContainerLocalSystem'
    ServiceDisplayName    = 'NVIDIA Display Container LS'
    ContainerProcess      = 'NVDisplay.Container'
    LogFile               = Join-Path $env:ProgramData 'NVIDIA Corporation\nvtopps\nct\nvlog.nvlgstg'
    BadVersions           = @('621.14', '621.24')
    GoodVersion           = '621.01'
    DownloadUrl           = 'https://us.download.nvidia.com/Windows/621.01/621.01-desktop-win10-win11-64bit-international-dch-whql.exe'
    WorkFolder            = Join-Path $env:ProgramData 'NVidiaLogRemover'
    ExtractFolder         = Join-Path $env:SystemDrive 'NVIDIA\DisplayDriver\621.01'
    NvidiaVendorId        = 'VEN_10DE'
    LogSizeWarningBytes   = 50MB
    ServiceTimeoutSeconds = 30
    TransientErrorSeconds = 60
    SetupStartGraceMs     = 3000
    PollMs                = 500
    LiveRefreshMs         = 2000
    AnimationMs           = 400       # "je vérifie . . ." dots speed
    AnimationDotCount     = 4         # frames: "", " .", " . .", " . . ."
    BackgroundPollMs      = 100
    PaintDelayMs          = 150       # let the window draw the "checking" texts before the checks start
    StartupTaskName       = 'NVidiaLogRemover-NettoyageDemarrage'
    StartupThresholdMB    = 200
    StartupTaskDelay      = 'PT1M'    # wait 1 minute after boot / log-on, so the NVIDIA service is fully started
    StartupRepeatHours    = 3         # 'Every3h' mode: check again every 3 hours while the PC is on
    StartupModes          = @('Off', 'Session', 'Every3h')
    # Windows writes User32 event 1074 when a shutdown or restart is requested.
    ShutdownEventQuery    = '<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name=''User32''] and EventID=1074]]</Select></Query></QueryList>'
    StartupTaskTimeLimit  = 10        # minutes
    # The task runs as SYSTEM: its script must live in an admin-only folder.
    StartupFolder         = Join-Path $env:ProgramFiles 'NVidiaLogRemover'
    StartupFiles          = @('NettoyageJournalDemarrage.ps1', 'messages.fr.psd1', 'messages.en.psd1')
}
$Config.InstallerPath   = Join-Path $Config.WorkFolder 'pilote-nvidia-621.01.exe'
$Config.ActivityLog     = Join-Path $Config.WorkFolder 'journal.txt'
$Config.UninstallMarker = Join-Path $Config.WorkFolder 'desinstallation-faite.txt'

$script:IsBusy          = $false
$script:ActionRunning   = $false   # true only while a button's action runs (not while re-checking)
$script:BackgroundRunspace = $null
$script:CancelRequested = $false
$script:ActiveBitsJob   = $null
$script:SignatureCache  = @{ Stamp = $null; Valid = $false }
$script:Ui              = @{}

# ============================================================== Small helpers
function Wait-Ui([int]$Milliseconds = $Config.PollMs) {
    $deadline = (Get-Date).AddMilliseconds($Milliseconds)
    do {
        [System.Windows.Forms.Application]::DoEvents()
        if ($script:CancelRequested) { throw 'Cancelled by user' }
        Start-Sleep -Milliseconds 50
    } while ((Get-Date) -lt $deadline)
}

function Wait-ProcessUi([System.Diagnostics.Process]$Process) {
    while (-not $Process.HasExited) { Wait-Ui }
}

function Invoke-InBackground([scriptblock]$Script, [object[]]$Arguments = @()) {
    # Slow checks (signature of a 1 GB file, scheduled tasks, WMI) run on a second runspace
    # so the window keeps repainting and its "checking" animation keeps moving.
    if (-not $script:BackgroundRunspace) {
        $script:BackgroundRunspace = [runspacefactory]::CreateRunspace()
        $script:BackgroundRunspace.Open()
    }
    $shell = [powershell]::Create()
    $shell.Runspace = $script:BackgroundRunspace
    [void]$shell.AddScript($Script.ToString())
    foreach ($argument in $Arguments) { [void]$shell.AddArgument($argument) }
    try {
        $handle = $shell.BeginInvoke()
        while (-not $handle.IsCompleted) { Wait-Ui $Config.BackgroundPollMs }
        $output = $shell.EndInvoke($handle)
        if ($shell.Streams.Error.Count -gt 0) { throw $shell.Streams.Error[0].Exception }
        return $output
    } finally { $shell.Dispose() }
}

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) { return [string]::Format($Culture, $T.SizeGB, $Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return [string]::Format($Culture, $T.SizeMB, $Bytes / 1MB) }
    return [string]::Format($Culture, $T.SizeKB, $Bytes / 1KB)
}

function Write-Activity([string]$Message) {
    $now = Get-Date
    Add-Content -LiteralPath $Config.ActivityLog -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f $now, $Message) -Encoding UTF8
    if ($script:Ui.TxtLog -and -not $script:CancelRequested) {
        $script:Ui.TxtLog.AppendText(('{0:HH:mm:ss}  {1}' -f $now, $Message) + [Environment]::NewLine)
    }
}

function Show-Info([string]$Text) {
    [void][System.Windows.Forms.MessageBox]::Show($Text, $T.Title, 'OK', 'Information')
}

function Confirm-Choice([string]$Text) {
    return [System.Windows.Forms.MessageBox]::Show($Text, $T.Title, 'YesNo', 'Question') -eq 'Yes'
}

function Test-IsAdministrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================== State detection
function Get-LogFileSize {
    if (-not (Test-Path -LiteralPath $Config.LogFile)) { return -1 }
    return (Get-Item -LiteralPath $Config.LogFile -Force).Length
}

function ConvertTo-NvidiaVersion([string]$WindowsVersion) {
    # Windows "32.0.16.2114" -> NVIDIA "621.14" (last 5 digits of the last two fields)
    $parts = $WindowsVersion -split '\.'
    if ($parts.Count -lt 4) { return $null }
    $digits = $parts[2] + $parts[3]
    if ($digits.Length -lt 5) { return $null }
    $tail = $digits.Substring($digits.Length - 5)
    return '{0}.{1}' -f $tail.Substring(0, 3), $tail.Substring(3)
}

function Get-DriverState {
    $adapters = Invoke-InBackground { Get-CimInstance -ClassName Win32_VideoController }
    $adapter = $adapters | Where-Object { $_.PNPDeviceID -like "*$($Config.NvidiaVendorId)*" } | Select-Object -First 1
    $state = [pscustomobject]@{ HasNvidiaGpu = [bool]$adapter; Version = $null }
    if ($adapter -and $adapter.AdapterCompatibility -like '*NVIDIA*') {
        $state.Version = ConvertTo-NvidiaVersion $adapter.DriverVersion
    }
    return $state
}

function Get-DriverUninstallEntry {
    $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    foreach ($root in $roots) {
        $key = Get-ChildItem -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like '*_Display.Driver' } | Select-Object -First 1
        if ($key) { return Get-ItemProperty -LiteralPath $key.PSPath }
    }
    return $null
}

function Test-InstallerReady {
    # Checks the Authenticode signature (detects partial or tampered files). Cached: hashing 1 GB is slow.
    if (-not (Test-Path -LiteralPath $Config.InstallerPath)) { return $false }
    $file = Get-Item -LiteralPath $Config.InstallerPath
    $stamp = '{0}|{1}' -f $file.Length, $file.LastWriteTimeUtc.Ticks
    if ($script:SignatureCache.Stamp -ne $stamp) {
        $signature = Invoke-InBackground { param($Path) Get-AuthenticodeSignature -LiteralPath $Path } @($Config.InstallerPath)
        $script:SignatureCache = @{
            Stamp = $stamp
            Valid = ($signature.Status -eq 'Valid' -and $signature.SignerCertificate.Subject -like '*NVIDIA*')
        }
    }
    return $script:SignatureCache.Valid
}

function Test-RebootPendingAfterUninstall {
    if (-not (Test-Path -LiteralPath $Config.UninstallMarker)) { return $false }
    $uninstallTime = (Get-Item -LiteralPath $Config.UninstallMarker).LastWriteTime
    $lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    return $lastBoot -lt $uninstallTime
}

function Get-Snapshot([scriptblock]$OnPartReady = { }) {
    # $OnPartReady is called with 'Driver' then 'Installer' so the window can fill each line as soon as it is known.
    $snapshot = [pscustomobject]@{
        LogSize = Get-LogFileSize; Driver = $null; IsBadDriver = $false; HasUninstallEntry = $false
        RebootPending = $false; InstallerExists = $false; InstallerReady = $false
    }
    $snapshot.Driver = Get-DriverState
    $snapshot.IsBadDriver = ($Config.BadVersions -contains $snapshot.Driver.Version)
    $snapshot.HasUninstallEntry = [bool](Get-DriverUninstallEntry)
    $snapshot.RebootPending = Test-RebootPendingAfterUninstall
    $null = & $OnPartReady 'Driver' $snapshot
    $snapshot.InstallerExists = Test-Path -LiteralPath $Config.InstallerPath
    $snapshot.InstallerReady = Test-InstallerReady
    $null = & $OnPartReady 'Installer' $snapshot
    return $snapshot
}

function Get-NextStep($Snapshot) {
    if ($Snapshot.LogSize -ge $Config.LogSizeWarningBytes) { return 'Log' }
    if (-not $Snapshot.Driver.HasNvidiaGpu) { return 'NoNvidia' }
    if ($Snapshot.IsBadDriver) {
        if ($Snapshot.HasUninstallEntry -or -not $Snapshot.RebootPending) { return 'Uninstall' }
        return 'Reboot'
    }
    if ($Snapshot.Driver.Version -ne $Config.GoodVersion) {
        # A verified download means the good driver is wanted, whatever driver is installed now.
        if ($Snapshot.InstallerReady) { return 'Install' }
        if (-not $Snapshot.Driver.Version) { return 'Download' }
    }
    if ($Snapshot.InstallerExists -or (Test-Path -LiteralPath $Config.ExtractFolder)) { return 'Cleanup' }
    return 'Done'
}

# ============================================================== Step 1: log file
function Get-NvidiaService {
    $service = Get-Service -Name $Config.ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        $service = Get-Service | Where-Object { $_.DisplayName -eq $Config.ServiceDisplayName } | Select-Object -First 1
    }
    return $service
}

function Wait-ServiceStatus($Service, [string]$Status) {
    $deadline = (Get-Date).AddSeconds($Config.ServiceTimeoutSeconds)
    while ($true) {
        $Service.Refresh()
        if ($Service.Status -eq $Status) { return }
        if ((Get-Date) -gt $deadline) { throw ($T.ServiceTimeout -f $Status) }
        Wait-Ui
    }
}

function Remove-LogFile {
    try {
        Remove-Item -LiteralPath $Config.LogFile -Force
    } catch {
        Write-Activity $T.LogLocked
        Get-Process -Name $Config.ContainerProcess -ErrorAction SilentlyContinue | Stop-Process -Force
        Wait-Ui 1000
        Remove-Item -LiteralPath $Config.LogFile -Force
    }
}

function Invoke-CleanLog {
    $size = Get-LogFileSize
    if ($size -lt 0) { Write-Activity $T.LogAlreadyAbsent; return }
    $service = Get-NvidiaService
    if (-not $service) { Write-Activity $T.ServiceNotFound }
    if ($service -and $service.Status -ne 'Stopped') {
        Write-Activity $T.ServiceStopping
        $service.Stop()
        Wait-ServiceStatus $service 'Stopped'
    }
    Remove-LogFile
    Write-Activity ($T.LogRemoved -f (Format-Size $size))
    if ($service) {
        Write-Activity $T.ServiceStarting
        $service.Start()
        Wait-ServiceStatus $service 'Running'
    }
}

# ============================================================== Step 2: uninstall
function Split-CommandLine([string]$CommandLine) {
    $line = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    if ($line.StartsWith('"')) {
        $end = $line.IndexOf('"', 1)
        return @{ File = $line.Substring(1, $end - 1); Arguments = $line.Substring($end + 1).Trim() }
    }
    $space = $line.IndexOf(' ')
    if ($space -lt 0) { return @{ File = $line; Arguments = '' } }
    return @{ File = $line.Substring(0, $space); Arguments = $line.Substring($space + 1).Trim() }
}

function Get-NvidiaSetupProcess {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try {
            $_.Path -like '*\NVIDIA Corporation\Installer2\*' -or
            ($_.ProcessName -eq 'setup' -and $_.Company -like '*NVIDIA*')
        } catch { $false }
    }
}

function Wait-NvidiaSetup {
    Wait-Ui $Config.SetupStartGraceMs
    while (Get-NvidiaSetupProcess) { Wait-Ui 1000 }
}

function Invoke-UninstallDriver {
    $entry = Get-DriverUninstallEntry
    if (-not $entry -or -not $entry.UninstallString) {
        Write-Activity $T.UninstallManual
        Show-Info $T.UninstallManual
        Start-Process -FilePath 'control.exe' -ArgumentList 'appwiz.cpl'
        return
    }
    Show-Info $T.UninstallInstructions
    Write-Activity $T.UninstallStarting
    $command = Split-CommandLine $entry.UninstallString
    $startParams = @{ FilePath = $command.File; PassThru = $true }
    if ($command.Arguments) { $startParams.ArgumentList = $command.Arguments }
    $process = Start-Process @startParams
    Wait-ProcessUi $process
    Wait-NvidiaSetup
    Report-UninstallResult
}

function Report-UninstallResult {
    if (Get-DriverUninstallEntry) { Write-Activity $T.UninstallCancelled; return }
    Set-Content -LiteralPath $Config.UninstallMarker -Value (Get-Date).ToString('o')
    if ((Get-DriverState).Version) { Write-Activity $T.UninstallNeedsReboot }
    else { Write-Activity $T.UninstallDone }
}

# ============================================================== Step 3: download
function Update-DownloadProgress([double]$Done, [double]$Total) {
    $bar = $script:Ui.Progress
    if ($Total -gt 0 -and $Total -lt [UInt64]::MaxValue) {
        $percent = [int][Math]::Min(100, $Done * 100 / $Total)
        $bar.Value = $percent
        $script:Ui.LblProgress.Text = $T.DownloadProgress -f (Format-Size $Done), (Format-Size $Total), $percent
    } else {
        $script:Ui.LblProgress.Text = $T.DownloadProgressShort -f (Format-Size $Done)
    }
}

function Receive-WithBits {
    Import-Module BitsTransfer
    $job = Start-BitsTransfer -Source $Config.DownloadUrl -Destination $Config.InstallerPath `
        -Asynchronous -Priority Foreground -DisplayName 'NVidiaLogRemover'
    $script:ActiveBitsJob = $job
    $transientSince = $null
    try {
        while (@('Transferred', 'Error', 'Cancelled') -notcontains [string]$job.JobState) {
            if ([string]$job.JobState -eq 'TransientError') {
                if (-not $transientSince) { $transientSince = Get-Date }
                if (((Get-Date) - $transientSince).TotalSeconds -gt $Config.TransientErrorSeconds) { throw $T.DownloadNoInternet }
            } else { $transientSince = $null }
            Update-DownloadProgress $job.BytesTransferred $job.BytesTotal
            Wait-Ui
        }
        if ([string]$job.JobState -ne 'Transferred') { throw [string]$job.ErrorDescription }
        Complete-BitsTransfer -BitsJob $job
    } catch {
        Remove-BitsTransfer -BitsJob $job -ErrorAction SilentlyContinue
        throw
    } finally { $script:ActiveBitsJob = $null }
}

function Get-RemoteFileSize {
    try {
        $response = Invoke-WebRequest -Uri $Config.DownloadUrl -Method Head -UseBasicParsing
        return [double]$response.Headers['Content-Length']
    } catch { return 0 }
}

function Receive-WithCurl {
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl)) { throw $T.DownloadNoTool }
    $total = Get-RemoteFileSize
    $arguments = '-L -f -s -o "{0}" "{1}"' -f $Config.InstallerPath, $Config.DownloadUrl
    $process = Start-Process -FilePath $curl -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $null = $process.Handle   # keeps ExitCode readable after exit
    while (-not $process.HasExited) {
        $done = 0
        if (Test-Path -LiteralPath $Config.InstallerPath) { $done = (Get-Item -LiteralPath $Config.InstallerPath).Length }
        Update-DownloadProgress $done $total
        Wait-Ui
    }
    if ($process.ExitCode -ne 0) { throw ($T.DownloadFailed -f $process.ExitCode) }
}

function Invoke-DownloadDriver {
    if (Test-InstallerReady) { Write-Activity $T.DownloadAlready; return }
    Remove-Item -LiteralPath $Config.InstallerPath -Force -ErrorAction SilentlyContinue
    Write-Activity ($T.DownloadStarting -f $Config.GoodVersion)
    Set-ProgressVisible $true
    try {
        try { Receive-WithBits }
        catch {
            if ($script:CancelRequested) { throw }
            Write-Activity ($T.DownloadRetry -f $_.Exception.Message)
            Remove-Item -LiteralPath $Config.InstallerPath -Force -ErrorAction SilentlyContinue
            Receive-WithCurl
        }
    } finally { Set-ProgressVisible $false }
    if (-not (Test-InstallerReady)) { throw $T.DownloadInvalid }
    Write-Activity $T.DownloadDone
}

# ============================================================== Steps 4, 5, reboot
function Invoke-InstallDriver {
    if (-not (Test-InstallerReady)) { Write-Activity $T.InstallNeedDownload; Show-Info $T.InstallNeedDownload; return }
    Show-Info $T.InstallInstructions
    Write-Activity $T.InstallStarting
    $process = Start-Process -FilePath $Config.InstallerPath -PassThru
    Wait-ProcessUi $process
    Wait-NvidiaSetup
    if ((Get-DriverState).Version -eq $Config.GoodVersion) { Write-Activity ($T.InstallDone -f $Config.GoodVersion) }
    else { Write-Activity ($T.InstallNotConfirmed -f $Config.GoodVersion) }
}

function Invoke-Cleanup {
    $removed = $false
    foreach ($path in @($Config.InstallerPath, $Config.ExtractFolder, $Config.UninstallMarker)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
            Write-Activity ($T.CleanupRemoved -f $path)
            $removed = $true
        }
    }
    if (-not $removed) { Write-Activity $T.CleanupNothing }
}

function Invoke-Reboot {
    if (-not (Confirm-Choice $T.RebootConfirm)) { return }
    Write-Activity $T.RebootStarting
    Restart-Computer
}

# ============================================================== Auto cleanup task (two modes)
# 'Session' : at boot, at every log-on (also covers Windows "Fast Startup", which is not a real boot)
#             and when Windows shuts down or restarts. Never in the middle of a game.
# 'Every3h' : at boot then every N hours, even during a game: stopping the NVIDIA service while a game
#             runs can make the game freeze, flicker or crash. The UI asks for confirmation.
function Get-StartupTaskMode {
    $task = Invoke-InBackground { param($Name) Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue } @($Config.StartupTaskName)
    if (-not $task) { return 'Off' }
    if (@($task.Triggers | Where-Object { $_.Repetition.Interval }).Count -gt 0) { return 'Every3h' }
    return 'Session'
}

function New-ShutdownTrigger {
    # No cmdlet exists for event triggers: build the CIM object directly.
    $class = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace 'Root/Microsoft/Windows/TaskScheduler'
    $trigger = New-CimInstance -CimClass $class -ClientOnly
    $trigger.Subscription = $Config.ShutdownEventQuery
    $trigger.Enabled = $true
    return $trigger
}

function New-StartupTaskTriggers([string]$Mode) {
    $boot = New-ScheduledTaskTrigger -AtStartup
    $boot.Delay = $Config.StartupTaskDelay
    if ($Mode -eq 'Every3h') {
        # A boot trigger cannot take -RepetitionInterval directly: borrow the repetition of a -Once trigger
        # (no duration = repeats indefinitely).
        $repeat = New-TimeSpan -Hours $Config.StartupRepeatHours
        $boot.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval $repeat).Repetition
        return $boot
    }
    $logon = New-ScheduledTaskTrigger -AtLogOn
    $logon.Delay = $Config.StartupTaskDelay
    return @($boot, $logon, (New-ShutdownTrigger))
}

function Set-StartupTaskMode([string]$Mode) {
    if ($Mode -ne 'Off') { Install-StartupTask $Mode; return }
    if ((Get-StartupTaskMode) -ne 'Off') { Uninstall-StartupTask }
}

function Copy-StartupFiles {
    New-Item -ItemType Directory -Path $Config.StartupFolder -Force | Out-Null
    foreach ($file in $Config.StartupFiles) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $Config.StartupFolder -Force
    }
}

function Install-StartupTask([string]$Mode) {
    Copy-StartupFiles
    $scriptPath = Join-Path $Config.StartupFolder $Config.StartupFiles[0]
    $arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ThresholdMB {1} -Language {2}' -f $scriptPath, $Config.StartupThresholdMB, $Language
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes $Config.StartupTaskTimeLimit)
    $description = $T["StartupTaskDescription_$Mode"] -f $Config.StartupRepeatHours
    # -Force replaces an existing task, so switching between modes needs no uninstall first.
    Register-ScheduledTask -TaskName $Config.StartupTaskName -Action $action -Trigger @(New-StartupTaskTriggers $Mode) `
        -Principal $principal -Settings $settings -Description $description -Force | Out-Null
    Write-Activity ($T["StartupEnabled_$Mode"] -f $Config.StartupThresholdMB, $Config.StartupRepeatHours)
}

function Uninstall-StartupTask {
    Unregister-ScheduledTask -TaskName $Config.StartupTaskName -Confirm:$false
    Remove-Item -LiteralPath $Config.StartupFolder -Recurse -Force -ErrorAction SilentlyContinue
    Write-Activity $T.StartupDisabled
}

function Request-StartupMode([string]$Mode) {
    if ($Mode -eq $script:Ui.CurrentStartupMode) { return }
    if ($Mode -eq 'Every3h' -and -not (Confirm-Choice ($T.StartupEvery3hWarning -f $Config.StartupRepeatHours))) {
        Show-StartupMode $script:Ui.CurrentStartupMode   # put the radio back on the real mode
        return
    }
    Invoke-UiAction { Set-StartupTaskMode $Mode }
}

$StepActions = @{
    Log       = { Invoke-CleanLog }
    Uninstall = { Invoke-UninstallDriver }
    Download  = { Invoke-DownloadDriver }
    Install   = { Invoke-InstallDriver }
    Cleanup   = { Invoke-Cleanup }
    Reboot    = { Invoke-Reboot }
}

# ============================================================== UI
function New-Label([string]$Text, [int]$Y, [int]$Height, [float]$Size, [string]$Style = 'Regular') {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.SetBounds(20, $Y, 600, $Height)
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $Size, [System.Drawing.FontStyle]$Style)
    return $label
}

function New-Button([string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height, [scriptblock]$OnClick) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.SetBounds($X, $Y, $Width, $Height)
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $button.UseVisualStyleBackColor = $false
    $button.BackColor = [System.Drawing.SystemColors]::Control
    $button.Add_Click($OnClick)
    return $button
}

function Set-StatusLabel($Label, [string]$Text, [System.Drawing.Color]$Color) {
    $script:Ui.Pending.Remove($Label)
    $Label.Text = $Text
    $Label.ForeColor = $Color
}

# --- "je vérifie . . ." placeholders: shown before the checks, animated until each real value arrives
function Set-CheckingLabel($Label, [string]$Format, [System.Drawing.Color]$Color = [System.Drawing.Color]::Gray) {
    $Label.ForeColor = $Color
    $Label.Text = $Format -f ''
    $script:Ui.Pending[$Label] = $Format
}

function Update-CheckingAnimation {
    $script:Ui.AnimationFrame = ($script:Ui.AnimationFrame + 1) % $Config.AnimationDotCount
    $dots = ' .' * $script:Ui.AnimationFrame
    foreach ($entry in @($script:Ui.Pending.GetEnumerator())) { $entry.Key.Text = $entry.Value -f $dots }
}

function Set-CheckingBar([bool]$On) {
    $bar = $script:Ui.Progress
    if ($On) {
        $bar.Style = 'Marquee'
        $bar.MarqueeAnimationSpeed = 30
        $bar.Visible = $true
    } else {
        $bar.Visible = $false
        $bar.Style = 'Blocks'
    }
}

function Show-CheckingDisplay {
    Set-CheckingLabel $script:Ui.LblLog $T.CheckingLog
    Set-CheckingLabel $script:Ui.LblDriver $T.CheckingDriver
    Set-CheckingLabel $script:Ui.LblInstaller ($T.CheckingInstaller -f '{0}', $Config.GoodVersion)
    Set-CheckingLabel $script:Ui.LblStartup $T.CheckingStartup
    Set-CheckingLabel $script:Ui.LblNext $T.CheckingNext ([System.Drawing.Color]::RoyalBlue)
    foreach ($button in $script:Ui.StepButtons.Values) { $button.BackColor = [System.Drawing.SystemColors]::Control }
    Set-CheckingBar $true
}

function Update-LogLabel {
    $size = Get-LogFileSize
    if ($size -lt 0) { Set-StatusLabel $script:Ui.LblLog $T.LogAbsent ([System.Drawing.Color]::ForestGreen); return }
    if ($size -ge $Config.LogSizeWarningBytes) {
        Set-StatusLabel $script:Ui.LblLog ($T.LogPresentBig -f (Format-Size $size)) ([System.Drawing.Color]::Firebrick)
    } else {
        Set-StatusLabel $script:Ui.LblLog ($T.LogPresent -f (Format-Size $size)) ([System.Drawing.Color]::DarkOrange)
    }
}

function Update-DriverLabel($Snapshot) {
    $version = $Snapshot.Driver.Version
    $label = $script:Ui.LblDriver
    if (-not $Snapshot.Driver.HasNvidiaGpu) { Set-StatusLabel $label $T.NoNvidiaGpu ([System.Drawing.Color]::Gray) }
    elseif (-not $version) { Set-StatusLabel $label $T.DriverNone ([System.Drawing.Color]::DarkOrange) }
    elseif ($Snapshot.IsBadDriver) { Set-StatusLabel $label ($T.DriverBad -f $version) ([System.Drawing.Color]::Firebrick) }
    elseif ($version -eq $Config.GoodVersion) { Set-StatusLabel $label ($T.DriverGood -f $version) ([System.Drawing.Color]::ForestGreen) }
    else { Set-StatusLabel $label ($T.DriverOther -f $version) ([System.Drawing.Color]::ForestGreen) }
}

function Update-InstallerLabel($Snapshot) {
    $label = $script:Ui.LblInstaller
    if ($Snapshot.InstallerReady) { Set-StatusLabel $label ($T.InstallerReady -f $Config.GoodVersion) ([System.Drawing.Color]::ForestGreen) }
    elseif ($Snapshot.InstallerExists) { Set-StatusLabel $label ($T.InstallerIncomplete -f $Config.GoodVersion) ([System.Drawing.Color]::DarkOrange) }
    else { Set-StatusLabel $label ($T.InstallerAbsent -f $Config.GoodVersion) ([System.Drawing.Color]::Gray) }
}

function Show-StartupMode([string]$Mode) {
    $color = [System.Drawing.Color]::ForestGreen
    if ($Mode -eq 'Off') { $color = [System.Drawing.Color]::Gray }
    Set-StatusLabel $script:Ui.LblStartup ($T.StartupHeader -f $Config.StartupThresholdMB) $color
    foreach ($key in $script:Ui.StartupRadios.Keys) { $script:Ui.StartupRadios[$key].Checked = ($key -eq $Mode) }
}

function Update-StartupTaskDisplay {
    $script:Ui.CurrentStartupMode = Get-StartupTaskMode
    Show-StartupMode $script:Ui.CurrentStartupMode
}

function Show-SnapshotPart([string]$Part, $Snapshot) {
    if ($Part -eq 'Driver') { Update-DriverLabel $Snapshot } else { Update-InstallerLabel $Snapshot }
}

function Show-NextStep([string]$Step) {
    Set-StatusLabel $script:Ui.LblNext $T["Next_$Step"] ([System.Drawing.Color]::RoyalBlue)
    foreach ($key in $script:Ui.StepButtons.Keys) {
        $color = [System.Drawing.SystemColors]::Control
        if ($key -eq $Step) { $color = [System.Drawing.Color]::Gold }
        $script:Ui.StepButtons[$key].BackColor = $color
    }
}

function Update-StatusDisplay {
    # Lines are filled one by one, fastest checks first; the slow ones animate meanwhile.
    Show-CheckingDisplay
    Wait-Ui $Config.PaintDelayMs
    Update-LogLabel
    Update-StartupTaskDisplay
    $snapshot = Get-Snapshot { param($Part, $Snapshot) Show-SnapshotPart $Part $Snapshot }
    Show-NextStep (Get-NextStep $snapshot)
    Set-CheckingBar $false
}

function Set-ProgressVisible([bool]$Visible) {
    $script:Ui.Progress.Value = 0
    $script:Ui.LblProgress.Text = ''
    $script:Ui.Progress.Visible = $Visible
    $script:Ui.LblProgress.Visible = $Visible
}

function Set-Busy([bool]$Busy) {
    $script:IsBusy = $Busy
    foreach ($button in $script:Ui.ActionButtons) { $button.Enabled = -not $Busy }
    if ($Busy) { Set-StatusLabel $script:Ui.LblNext $T.Next_Busy ([System.Drawing.Color]::RoyalBlue) }
    $script:Ui.Form.Cursor = if ($Busy) { [System.Windows.Forms.Cursors]::WaitCursor } else { [System.Windows.Forms.Cursors]::Default }
}

function Invoke-UiAction([scriptblock]$Action) {
    if ($script:IsBusy) { return }
    Set-Busy $true
    try {
        $script:ActionRunning = $true
        & $Action
    } catch {
        if ($script:CancelRequested) { return }
        Write-Activity ($T.ErrorMessage -f $_.Exception.Message)
        [void][System.Windows.Forms.MessageBox]::Show(($T.ErrorMessage -f $_.Exception.Message) + "`n`n" + $T.ErrorHelp, $T.Title, 'OK', 'Error')
    } finally {
        $script:ActionRunning = $false
        Complete-UiAction
    }
}

function Complete-UiAction {
    # Buttons stay disabled while the state is re-checked, so nothing can be clicked half-way.
    if ($script:CancelRequested) { return }
    try { Update-StatusDisplay }
    catch { if (-not $script:CancelRequested) { Write-Activity ($T.ErrorMessage -f $_.Exception.Message) } }
    if (-not $script:CancelRequested) { Set-Busy $false }
}

function Request-CloseWhileBusy($ClosingArgs) {
    if (-not $script:IsBusy) { return }
    # Only re-checking the PC: close right away, no question.
    if (-not $script:ActionRunning) { $script:CancelRequested = $true; return }
    if (-not (Confirm-Choice $T.CloseWhileBusy)) { $ClosingArgs.Cancel = $true; return }
    $script:CancelRequested = $true
    if ($script:ActiveBitsJob) { Remove-BitsTransfer -BitsJob $script:ActiveBitsJob -ErrorAction SilentlyContinue }
}

function New-MainForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $T.Title
    $form.ClientSize = New-Object System.Drawing.Size(640, 690)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.AutoScroll = $true
    $script:Ui.Form = $form
    $script:Ui.Pending = @{}
    $script:Ui.AnimationFrame = 0
    Add-StatusControls $form
    Add-ActionControls $form
    Show-CheckingDisplay   # texts are already there on the very first paint
    $form.Add_FormClosing({ Request-CloseWhileBusy $_ })
    # Event handlers run after this function returns: use $script:Ui, never local variables.
    $form.Add_Shown({ $script:Ui.Form.Activate(); Write-Activity $T.Welcome; Invoke-UiAction { } })
    return $form
}

function Add-StatusControls($Form) {
    $Form.Controls.Add((New-Label $T.Header 15 40 18 'Bold'))
    $script:Ui.LblLog       = New-Label '' 65 28 12 'Bold'
    $script:Ui.LblDriver    = New-Label '' 95 28 12 'Bold'
    $script:Ui.LblInstaller = New-Label '' 125 28 12 'Bold'
    $script:Ui.LblNext      = New-Label '' 160 50 12 'Italic'
    $script:Ui.LblNext.ForeColor = [System.Drawing.Color]::RoyalBlue
    $Form.Controls.AddRange(@($script:Ui.LblLog, $script:Ui.LblDriver, $script:Ui.LblInstaller, $script:Ui.LblNext))

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $Config.LiveRefreshMs
    $timer.Add_Tick({ if (-not $script:CancelRequested) { Update-LogLabel } })
    $timer.Start()
    $script:Ui.Timer = $timer

    $animation = New-Object System.Windows.Forms.Timer
    $animation.Interval = $Config.AnimationMs
    $animation.Add_Tick({ if (-not $script:CancelRequested) { Update-CheckingAnimation } })
    $animation.Start()
    $script:Ui.AnimationTimer = $animation
}

function Add-ActionControls($Form) {
    $Form.Controls.Add((New-Label $T.StepsLabel 215 25 10 'Bold'))

    $steps = [ordered]@{
        Log       = New-Button $T.BtnLog       20 245 295 46 { Invoke-UiAction $StepActions.Log }
        Uninstall = New-Button $T.BtnUninstall 325 245 295 46 { Invoke-UiAction $StepActions.Uninstall }
        Download  = New-Button $T.BtnDownload  20 297 295 46 { Invoke-UiAction $StepActions.Download }
        Install   = New-Button $T.BtnInstall   325 297 295 46 { Invoke-UiAction $StepActions.Install }
        Cleanup   = New-Button $T.BtnCleanup   20 349 295 46 { Invoke-UiAction $StepActions.Cleanup }
        Reboot    = New-Button $T.BtnReboot    325 349 295 46 { Invoke-UiAction $StepActions.Reboot }
    }
    $script:Ui.StepButtons = $steps
    $refresh = New-Button $T.BtnRefresh 20 640 295 40 { Invoke-UiAction { } }
    $close   = New-Button $T.BtnClose   325 640 295 40 { $script:Ui.Form.Close() }
    $startupRadios = Add-StartupControls $Form
    $script:Ui.ActionButtons = @($steps.Values) + @($refresh) + $startupRadios
    $Form.Controls.AddRange(@($steps.Values) + @($refresh, $close))
    Add-ProgressControls $Form
}

function Add-StartupControls($Form) {
    $script:Ui.LblStartup = New-Label '' 405 24 10 'Bold'
    $radios = [ordered]@{}
    $y = 429
    foreach ($mode in $Config.StartupModes) {
        $radio = New-Object System.Windows.Forms.RadioButton
        $radio.Text = $T["StartupMode_$mode"] -f $Config.StartupRepeatHours
        $radio.SetBounds(30, $y, 590, 23)
        $radio.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $radio.Tag = $mode
        # Click (not CheckedChanged): only real user choices, not the radios set by Show-StartupMode.
        $radio.Add_Click({ Request-StartupMode $this.Tag })
        $radios[$mode] = $radio
        $y += 23
    }
    $script:Ui.StartupRadios = $radios
    $Form.Controls.Add($script:Ui.LblStartup)
    $Form.Controls.AddRange(@($radios.Values))
    return @($radios.Values)
}

function Add-ProgressControls($Form) {
    $script:Ui.Progress = New-Object System.Windows.Forms.ProgressBar
    $script:Ui.Progress.SetBounds(20, 503, 600, 22)
    $script:Ui.LblProgress = New-Label '' 527 22 10
    $script:Ui.TxtLog = New-Object System.Windows.Forms.TextBox
    $script:Ui.TxtLog.Multiline = $true
    $script:Ui.TxtLog.ReadOnly = $true
    $script:Ui.TxtLog.ScrollBars = 'Vertical'
    $script:Ui.TxtLog.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $script:Ui.TxtLog.SetBounds(20, 553, 600, 80)
    $Form.Controls.AddRange(@($script:Ui.Progress, $script:Ui.LblProgress, $script:Ui.TxtLog))
    Set-ProgressVisible $false
}

# ============================================================== Entry point
if (-not (Test-IsAdministrator)) {
    [void][System.Windows.Forms.MessageBox]::Show($T.NotAdmin, $T.Title, 'OK', 'Warning')
    exit 1
}
New-Item -ItemType Directory -Path $Config.WorkFolder -Force | Out-Null
# Any unexpected error in an event handler: simple French message instead of the .NET crash dialog.
[System.Windows.Forms.Application]::SetUnhandledExceptionMode('CatchException')
[System.Windows.Forms.Application]::add_ThreadException({
    $message = $T.ErrorMessage -f $_.Exception.Message
    try { Write-Activity $message } catch { }
    [void][System.Windows.Forms.MessageBox]::Show($message + "`n`n" + $T.ErrorHelp, $T.Title, 'OK', 'Error')
})
$mainForm = New-MainForm
[void]$mainForm.ShowDialog()
$script:Ui.Timer.Stop()
$script:Ui.AnimationTimer.Stop()
$mainForm.Dispose()
if ($script:BackgroundRunspace) { $script:BackgroundRunspace.Dispose() }
