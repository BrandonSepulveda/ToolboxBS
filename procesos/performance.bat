@echo off
setlocal
:: Comprobar si hay permisos de adminn
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Configurando permisos de administrador...
    powershell -Command "Start-Process '%0' -Verb RunAs"
    exit /b
)

:: Aquí es donde el BAT llama a PowerShell para ejecutar todo tu script
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
    "$ProgressPreference = 'SilentlyContinue';" ^
    "$ErrorActionPreference = 'SilentlyContinue';" ^
    "Write-Host '-- Creating a restore point' -ForegroundColor Green;" ^
    "Enable-ComputerRestore -Drive $env:SystemDrive; Checkpoint-Computer -Description 'RestorePoint1' -RestorePointType 'MODIFY_SETTINGS';" ^
    "Write-Host '-- Deleting Temp files' -ForegroundColor Green;" ^
    "Remove-Item -Path 'C:\Windows\Temp\*' -Recurse -Force;" ^
    "Remove-Item -Path 'C:\Windows\Prefetch\*' -Recurse -Force;" ^
    "Write-Host '-- Emptying Recycle Bin' -ForegroundColor Green;" ^
    "$bin = (New-Object -ComObject Shell.Application).NameSpace(10); $bin.items() | ForEach { Write-Host 'Deleting' $_.Name 'from Recycle Bin'; Remove-Item $_.Path -Recurse -Force };" ^
    "Write-Host '-- Disabling Windows Telemetry' -ForegroundColor Green;" ^
    "$tasks = @('\Microsoft\Windows\Customer Experience Improvement Program\Consolidator', '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask', '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip', '\Microsoft\Windows\Autochk\Proxy', '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector', '\Microsoft\Windows\Feedback\Siuf\DmClient', '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload', '\Microsoft\Windows\Windows Error Reporting\QueueReporting', '\Microsoft\Windows\Maps\MapsUpdateTask');" ^
    "foreach ($task in $tasks) { Disable-ScheduledTask -TaskName $task };" ^
    "Set-Service -Name 'diagsvc', 'WerSvc', 'wercplsupport' -StartupType Manual;" ^
    "reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' /v 'AllowTelemetry' /t REG_DWORD /d 0 /f;" ^
    "reg add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' /v 'ContentDeliveryAllowed' /d 0 /t REG_DWORD /f;" ^
    "Write-Host '-- Disabling Fullscreen Optimizations' -ForegroundColor Green;" ^
    "reg add 'HKCU\System\GameConfigStore' /v 'GameDVR_DXGIHonorFSEWindowsCompatible' /t REG_DWORD /d 1 /f;" ^
    "Write-Host '-- Disabling Mouse Acceleration' -ForegroundColor Green;" ^
    "reg add 'HKCU\Control Panel\Mouse' /v 'MouseSpeed' /t REG_SZ /d '0' /f;" ^
    "Write-Host '-- Disabling Manual Services' -ForegroundColor Green;" ^
    "$manual = @('ALG','AppMgmt','AppReadiness','Appinfo','AxInstSV','BDESVC','BTAGService','BcastDVRUserService','BluetoothUserService','Browser','CDPSvc','COMSysApp','CaptureService','CertPropSvc','ConsentUxUserSvc','CscService','DevQueryBroker','DeviceAssociationService','DeviceInstall','DevicePickerUserSvc','DevicesFlowUserSvc','DisplayEnhancementService','DmEnrollmentSvc','DsSvc','DsmSvc','EFS','EapHost','EntAppSvc','FDResPub','FrameServer','FrameServerMonitor','GraphicsPerfSvc','HvHost','IEEtwCollectorService','InstallService','InventorySvc','IpxlatCfgSvc','KtmRm','LicenseManager','LxpSvc','MSDTC','MSiSCSI','McpManagementService','MicrosoftEdgeElevationService','MsKeyboardFilter','NPSMSvc','NaturalAuthentication','NcaSvc','NcbService','NcdAutoSetup','NetSetupSvc','Netman','NgcCtnrSvc','NgcSvc','NlaSvc','PNRPAutoReg','PcaSvc','PeerDistSvc','PenService','PerfHost','PhoneSvc','PimIndexMaintenanceSvc','PlugPlay','PolicyAgent','PrintNotify','PushToInstall','QWAVE','RasAuto','RasMan','RetailDemo','RmSvc','RpcLocator','SCPolicySvc','SCardSvr','SDRSVC','SEMgrSvc','SNMPTRAP','SNMPTrap','SSDPSRV','ScDeviceEnum','SensorDataService','SensorService','SensrSvc','SessionEnv','SharedAccess','SmsRouter','SstpSvc','StiSvc','StorSvc','TapiSrv','TextInputManagementService','TieringEngineService','TokenBroker','TroubleshootingSvc','TrustedInstaller','UdkUserSvc','UmRdpService','UserDataSvc','UsoSvc','VSS','VacSvc','WEPHOSTSVC','WFDSConMgrSvc','WMPNetworkSvc','WManSvc','WPDBusEnum','WalletService','WarpJITSvc','WbioSrvc','WdNisSvc','WdiServiceHost','WdiSystemHost','WebClient','Wecsvc','WerSvc','WiaRpc','WinRM','WpcMonSvc','WpnService','WwanSvc','autotimesvc','bthserv','camsvc','cbdhsvc','cloudidsvc','dcsvc','defragsvc','diagsvc','dmwappushservice','dot3svc','edgeupdate','edgeupdatem','embeddedmode','fdPHost','fhsvc','hidserv','icssvc','lfsvc','lltdsvc','lmhosts','msiserver','netprofm','p2pimsvc','p2psvc','perceptionsimulation','pla','seclogon','smphost','svsvc','swprv','upnphost','vds','vmicguestinterface','vmicheartbeat','vmickvpexchange','vmicrdv','vmicshutdown','vmictimesync','vmicvmsession','vmicvss','vmvss','wbengine','wcncsvc','webthreatdefsvc','wercplsupport','wisvc','wlidsvc','wlpasvc','wmiApSrv','workfolderssvc','wuauserv','wudfsvc');" ^
    "foreach ($s in $manual) { Set-Service -Name $s -StartupType Manual };" ^
    "Write-Host '-- Set Ultimate Performance Power Plan' -ForegroundColor Green;" ^
    "powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61;" ^
    "$guid = (powercfg -list | Select-String 'Ultimate Performance').Line.Split()[3];" ^
    "powercfg -setactive $guid;" ^
    "Write-Host '-- Adding End Task to Right-Click' -ForegroundColor Green;" ^
    "reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' /v 'TaskbarEndTask' /t REG_DWORD /d 1 /f;" ^
    "Write-Host 'Script Finished' -ForegroundColor Cyan;" ^
    "Read-Host 'Press Enter to exit';" ^
    "Stop-Process -Name explorer -Force; Start-Process explorer.exe"

exit /b
