# Texts shown by NettoyageNvidia.ps1 (English).
# {0}, {1}... are replaced by values (size, version...).
# Keep the same keys as messages.fr.psd1.
@{
    CultureName           = 'en-US'   # number format (11.5 GB)
    Title                 = 'NVIDIA Repair'
    Header                = 'NVIDIA driver repair'

    # --- State of the computer ---
    LogPresent            = 'NVIDIA log file: present - current size {0}'
    LogPresentBig         = 'NVIDIA log file: HUGE - current size {0}'
    LogAbsent             = 'NVIDIA log file: absent (size 0)'
    NoNvidiaGpu           = 'NVIDIA graphics card: not found on this computer'
    DriverNone            = 'NVIDIA driver: no driver installed at the moment'
    DriverBad             = 'NVIDIA driver: {0} - this is the WRONG driver'
    DriverGood            = 'NVIDIA driver: {0} - this is the right driver'
    DriverOther           = 'NVIDIA driver: {0} - not affected by the problem'
    InstallerReady        = 'Right driver {0}: already downloaded'
    InstallerIncomplete   = 'Right driver {0}: download incomplete'
    InstallerAbsent       = 'Right driver {0}: not downloaded yet'
    SizeGB                = '{0:N1} GB'
    SizeMB                = '{0:N0} MB'
    SizeKB                = '{0:N0} KB'

    # --- While checking ({0} = animated dots) ---
    CheckingLog           = 'NVIDIA log file: checking{0}'
    CheckingDriver        = 'NVIDIA driver: checking{0}'
    CheckingInstaller     = 'Right driver {1}: checking{0}'
    CheckingStartup       = 'Automatic log cleanup: checking{0}'
    CheckingNext          = 'I''m looking at the computer{0}   Please wait a little, it can take a few seconds!'

    # --- Suggested next step ---
    Next_Log              = 'Next step: click the yellow button to empty the huge log file.'
    Next_Uninstall        = 'Next step: click the yellow button to remove the wrong driver.'
    Next_Reboot           = 'Next step: restart the computer (yellow button), then run this program again.'
    Next_Download         = 'Next step: click the yellow button to download the right driver (about 1 GB).'
    Next_Install          = 'Next step: click the yellow button to install the right driver.'
    Next_Cleanup          = 'Next step: click the yellow button to delete the downloaded file.'
    Next_Done             = 'Everything is fixed! You can close this program.'
    Next_NoNvidia         = 'No NVIDIA card: there is nothing else to do.'
    Next_Busy             = 'Please wait... I''m working. Don''t close this window.'

    # --- Buttons ---
    StepsLabel            = 'Click the YELLOW button: it is the next step.'
    BtnLog                = '1. Empty the log file'
    BtnUninstall          = '2. Remove the wrong driver'
    BtnDownload           = '3. Download the right driver'
    BtnInstall            = '4. Install the right driver'
    BtnCleanup            = '5. Delete the downloaded file'
    BtnReboot             = 'Restart the computer'
    BtnRefresh            = 'Check again'
    BtnClose              = 'Close'

    # --- Messages while working ---
    Welcome               = 'Hello! I''m looking at the computer...'
    NotAdmin              = 'This program must be started with the RUN_ME_English.bat file (it asks for administrator rights).'
    ServiceStopping       = 'Stopping the NVIDIA service...'
    ServiceStarting       = 'Starting the NVIDIA service again...'
    ServiceNotFound       = 'NVIDIA service not found: I only delete the file.'
    ServiceTimeout        = 'The NVIDIA service does not respond (expected state: {0}).'
    LogRemoved            = 'Log file deleted: {0} freed.'
    LogAlreadyAbsent      = 'The log file does not exist: nothing to empty.'
    LogLocked             = 'The file is locked, I''m closing the NVIDIA programs and trying again...'
    UninstallStarting     = 'Starting the uninstall of the wrong driver...'
    UninstallInstructions = @'
An NVIDIA window is going to open.

Click "Uninstall" and wait until it is finished.
If it asks you to restart, choose "later", then come back here.
'@
    UninstallManual       = 'I could not find the NVIDIA uninstaller. In the list that opens, choose "NVIDIA Graphics Driver" then "Uninstall".'
    UninstallCancelled    = 'The wrong driver is still there (uninstall cancelled?).'
    UninstallDone         = 'Wrong driver uninstalled.'
    UninstallNeedsReboot  = 'Wrong driver uninstalled. You need to restart the computer, then run this program again.'
    DownloadStarting      = 'Downloading the right driver {0}... about 1 GB, it can take several minutes.'
    DownloadProgress      = 'Download: {0} of {1} ({2} %)'
    DownloadProgressShort = 'Download: {0}'
    DownloadAlready       = 'The right driver is already downloaded.'
    DownloadRetry         = 'First download method failed ({0}), trying another method...'
    DownloadNoInternet    = 'No Internet connection? The download is stuck.'
    DownloadFailed        = 'The download failed (code {0}).'
    DownloadInvalid       = 'The downloaded file is damaged or not signed by NVIDIA. Download it again.'
    DownloadNoTool        = 'No download tool available on this computer.'
    DownloadDone          = 'Download finished, file checked (signed by NVIDIA).'
    InstallNeedDownload   = 'You must download the right driver first (step 3).'
    InstallInstructions   = @'
The NVIDIA installer is going to open.

1. Click "OK" for the folder.
2. Accept, then click "Next" each time.
3. Wait until it is finished, then click "Close".

The screen may go black for a few seconds: that's normal!
'@
    InstallStarting       = 'Starting the installation of the right driver...'
    InstallDone           = 'Right driver {0} installed!'
    InstallNotConfirmed   = 'Installation finished, but I can''t see driver {0} yet. Restart the computer, then run this program again to check.'
    CleanupRemoved        = 'Deleted: {0}'
    CleanupNothing        = 'Nothing to delete.'
    RebootConfirm         = @'
The computer is going to restart.

Did you save your games and close your programs?
After the restart, run "RUN_ME_English.bat" again.
'@
    RebootStarting        = 'Restarting the computer...'
    ErrorMessage          = 'Oops, a problem: {0}'
    ErrorHelp             = 'Ask an adult for help and show them this window.'
    CloseWhileBusy        = 'I''m working right now. Close anyway?'

    # --- Automatic cleanup (scheduled task, 2 modes) ---
    StartupHeader          = 'Automatic log cleanup (if larger than {0} MB):'
    StartupMode_Off        = 'Off'
    StartupMode_Session    = 'When Windows starts and shuts down (recommended)'
    StartupMode_Every3h    = 'Every {0} hours (careful: can crash a running game)'
    StartupEnabled_Session = 'Automatic cleanup on: when Windows starts and shuts down, the log file will be deleted if it is larger than {0} MB.'
    StartupEnabled_Every3h = 'Automatic cleanup on: at start-up then every {1} hours, the log file will be deleted if it is larger than {0} MB.'
    StartupDisabled        = 'Automatic cleanup off.'
    StartupTaskDescription_Session = 'Deletes the NVIDIA log file (nvlog.nvlgstg) if it is larger than the limit: at start-up, at log-on and when Windows shuts down or restarts. Created by NVidiaLogRemover.'
    StartupTaskDescription_Every3h = 'Deletes the NVIDIA log file (nvlog.nvlgstg) if it is larger than the limit: at start-up then every {0} hours. Created by NVidiaLogRemover.'
    StartupEvery3hWarning  = @'
Careful: every {0} hours, the cleanup can happen DURING a game.

To empty the log, the NVIDIA service is stopped and started again.
If a game is running at that moment, it can freeze, flicker or even crash.

The "When Windows starts and shuts down" choice is safer.

Choose "every {0} hours" anyway?
'@
    StartupCheckAbsent     = 'Automatic check: log file absent, nothing to do.'
    StartupCheckOk         = 'Automatic check: log file of {0} (limit {1} MB), nothing to do.'
    StartupCleaned         = 'Automatic check: log file of {0} deleted (limit {1} MB).'
    StartupError           = 'Automatic check: error during cleanup: {0}'
}
