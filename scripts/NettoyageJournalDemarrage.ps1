#Requires -Version 5.1
<#
.SYNOPSIS
    Automatic check (no window): deletes the NVIDIA log file if it is larger than the limit.

.DESCRIPTION
    Run by the scheduled task created from NettoyageNvidia.ps1 ("Nettoyage auto" choice), as SYSTEM:
    - "Session" mode: at boot, at log-on and when Windows shuts down / restarts;
    - "Every3h" mode: at boot then every 3 hours.
    Steps when the file is too big: stop "NVIDIA Display Container LS", delete
    nvlog.nvlgstg, start the service again. Each run adds one line to
    C:\ProgramData\NVidiaLogRemover\journal.txt.
    This file and messages.fr.psd1 / messages.en.psd1 are copied to C:\Program Files\NVidiaLogRemover
    (admin-only folder, because the task runs with SYSTEM rights).
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 100000)]
    [int]$ThresholdMB = 200,

    # Language of the history lines (messages.fr.psd1 / messages.en.psd1).
    [ValidateSet('fr', 'en')]
    [string]$Language = 'fr'
)

$ErrorActionPreference = 'Stop'
$T = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "messages.$Language.psd1")
$Culture = [Globalization.CultureInfo]::GetCultureInfo($T.CultureName)

$Config = @{
    ServiceName           = 'NVDisplay.ContainerLocalSystem'
    ContainerProcess      = 'NVDisplay.Container'
    LogFile               = Join-Path $env:ProgramData 'NVIDIA Corporation\nvtopps\nct\nvlog.nvlgstg'
    WorkFolder            = Join-Path $env:ProgramData 'NVidiaLogRemover'
    ServiceTimeoutSeconds = 30
    ProcessKillWaitSec    = 2
}
$Config.ActivityLog = Join-Path $Config.WorkFolder 'journal.txt'

function Write-Activity([string]$Message) {
    New-Item -ItemType Directory -Path $Config.WorkFolder -Force | Out-Null
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath $Config.ActivityLog -Value $line -Encoding UTF8
}

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) { return [string]::Format($Culture, $T.SizeGB, $Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return [string]::Format($Culture, $T.SizeMB, $Bytes / 1MB) }
    return [string]::Format($Culture, $T.SizeKB, $Bytes / 1KB)
}

function Wait-ServiceStatus($Service, [System.ServiceProcess.ServiceControllerStatus]$Status) {
    $Service.WaitForStatus($Status, [TimeSpan]::FromSeconds($Config.ServiceTimeoutSeconds))
}

function Stop-NvidiaService($Service) {
    # At boot the service may still be starting: it cannot be stopped before it is running.
    if ($Service.Status -eq 'StartPending') { Wait-ServiceStatus $Service 'Running' }
    # At shutdown Windows may already be stopping it.
    if ($Service.Status -eq 'StopPending') { Wait-ServiceStatus $Service 'Stopped'; return }
    if ($Service.Status -ne 'Stopped') {
        $Service.Stop()
        Wait-ServiceStatus $Service 'Stopped'
    }
}

function Remove-LogFile {
    try {
        Remove-Item -LiteralPath $Config.LogFile -Force
    } catch {
        Get-Process -Name $Config.ContainerProcess -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds $Config.ProcessKillWaitSec
        Remove-Item -LiteralPath $Config.LogFile -Force
    }
}

function Invoke-StartupCheck {
    if (-not (Test-Path -LiteralPath $Config.LogFile)) { Write-Activity $T.StartupCheckAbsent; return }
    $size = (Get-Item -LiteralPath $Config.LogFile -Force).Length
    if ($size -lt ($ThresholdMB * 1MB)) {
        Write-Activity ($T.StartupCheckOk -f (Format-Size $size), $ThresholdMB)
        return
    }
    $service = Get-Service -Name $Config.ServiceName -ErrorAction SilentlyContinue
    if ($service) { Stop-NvidiaService $service }
    Remove-LogFile
    # Logged before the restart: at shutdown Windows may refuse to start the service again.
    Write-Activity ($T.StartupCleaned -f (Format-Size $size), $ThresholdMB)
    if ($service) {
        $service.Start()
        Wait-ServiceStatus $service 'Running'
    }
}

try {
    Invoke-StartupCheck
} catch {
    Write-Activity ($T.StartupError -f $_.Exception.Message)
    exit 1
}
