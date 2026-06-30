@echo off
setlocal EnableExtensions
title Optimizador Windows BS v2.0
color 0A

:: =====================================================
::  OPTIMIZADOR WINDOWS BS v2.0
:: =====================================================

:: --- Verificacion de permisos de administrador ---
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cls
echo ======================================================
echo   OPTIMIZADOR WINDOWS BS v2.0
echo ======================================================
echo.

:: --- Log file ---
set "LOG_FILE=%USERPROFILE%\Desktop\OptimizadorBS_log.txt"
echo Log de optimizacion - %DATE% %TIME% > "%LOG_FILE%"

:: --- Extraer script PowerShell embebido ---
set "PS1_FILE=%TEMP%\OptimizeWinBS_%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-Content -LiteralPath '%~f0' | Where-Object { $_ -match '^:::' } | ForEach-Object { $_ -replace '^:::\s?','' } | Set-Content -LiteralPath '%PS1_FILE%' -Encoding UTF8"

if not exist "%PS1_FILE%" (
    echo [X] Error: no se pudo extraer el script PowerShell.
    exit /b 1
)

:: --- Ejecutar PowerShell con logging ---
powershell -ExecutionPolicy Bypass -NoProfile -File "%PS1_FILE%" 2>&1 | powershell -NoProfile -Command "$input | Tee-Object -FilePath '%LOG_FILE%' -Append"

:: --- Flush DNS ---
echo.
echo == Flush DNS ==
ipconfig /flushdns >nul
echo   -^> Cache DNS limpiada

:: --- Limpieza ---
del "%PS1_FILE%" >nul 2>&1

echo.
echo ======================================================
echo   Optimizacion completada
echo   Log guardado en: %LOG_FILE%
echo ======================================================
echo.
echo Reiniciando explorer en 3 segundos...
timeout /t 3 /nobreak >nul
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

exit /b

::: # ============================================================
::: # Script PowerShell embebido - Optimizador Windows BS v2.0
::: # ============================================================
::: $ProgressPreference = 'SilentlyContinue'
::: $ErrorActionPreference = 'SilentlyContinue'
:::
::: function Write-Section($text) {
:::     Write-Host ''
:::     Write-Host "== $text ==" -ForegroundColor Cyan
::: }
:::
::: function Write-Step($text) {
:::     Write-Host "  -> $text" -ForegroundColor Green
::: }
:::
::: function Write-Warn($text) {
:::     Write-Host "  [!] $text" -ForegroundColor Yellow
::: }
:::
::: # ---------- PUNTO DE RESTAURACION ----------
::: Write-Section 'Creando punto de restauracion'
::: try {
:::     Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction Stop
:::     New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null
:::     Checkpoint-Computer -Description 'OptimizadorBS_v2' -RestorePointType 'MODIFY_SETTINGS'
:::     Write-Step 'Punto de restauracion creado'
::: } catch {
:::     Write-Warn 'No se pudo crear punto de restauracion'
::: }
:::
::: # ---------- LIMPIEZA ----------
::: Write-Section 'Limpieza de archivos temporales'
::: Remove-Item -Path 'C:\Windows\Temp\*' -Recurse -Force -ErrorAction SilentlyContinue
::: Remove-Item -Path 'C:\Windows\Prefetch\*' -Recurse -Force -ErrorAction SilentlyContinue
::: Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
::: Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
::: Write-Step 'Temporales eliminados (Windows\Temp, Prefetch, %TEMP%, INetCache)'
:::
::: Write-Section 'Vaciando papelera de reciclaje'
::: try {
:::     $bin = (New-Object -ComObject Shell.Application).NameSpace(10)
:::     $count = 0
:::     $bin.Items() | ForEach-Object {
:::         Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue
:::         $count++
:::     }
:::     Write-Step "Papelera vaciada ($count items)"
::: } catch {
:::     Write-Warn 'No se pudo vaciar la papelera'
::: }
:::
::: # ---------- TELEMETRIA WINDOWS ----------
::: Write-Section 'Deshabilitando telemetria de Windows'
::: $telemetryTasks = @(
:::     '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
:::     '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
:::     '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
:::     '\Microsoft\Windows\Autochk\Proxy',
:::     '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
:::     '\Microsoft\Windows\Feedback\Siuf\DmClient',
:::     '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
:::     '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
:::     '\Microsoft\Windows\Maps\MapsUpdateTask'
::: )
::: foreach ($t in $telemetryTasks) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
::: Write-Step 'Tareas programadas de telemetria deshabilitadas'
:::
::: 'DiagTrack','diagsvc','WerSvc','wercplsupport','dmwappushservice' | ForEach-Object {
:::     Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue
::: }
:::
::: $telemetryRegs = @(
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowDesktopAnalyticsProcessing'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowDeviceNameInTelemetry'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'MicrosoftEdgeDataOptIn'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowWUfBCloudProcessing'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowUpdateComplianceProcessing'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowCommercialDataPipeline'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DisableOneSettingsDownloads'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Name = 'CEIPEnable'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'DontSendAdditionalData'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'LoggingDisabled'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent'; Name = 'DefaultConsent'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent'; Name = 'DefaultOverrideBehavior'; Value = 1 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContentEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEverEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'FeatureManagementEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\EdgeUI'; Name = 'DisableMFUTracking'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI'; Name = 'DisableMFUTracking'; Value = 1 },
:::     @{ Path = 'HKCU:\Control Panel\International\User Profile'; Name = 'HttpAcceptLanguageOptOut'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0 },
:::     @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackProgs'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'; Name = 'EnableAccountNotifications'; Value = 0 },
:::     @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'; Name = 'EnableAccountNotifications'; Value = 0 }
::: )
::: foreach ($r in $telemetryRegs) {
:::     if (-not (Test-Path $r.Path)) { New-Item -Path $r.Path -Force | Out-Null }
:::     New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Value -PropertyType DWord -Force | Out-Null
::: }
::: Write-Step 'Registry de telemetria configurado'
:::
::: # ---------- WINDOWS UPDATE / SEARCH ----------
::: Write-Section 'Deshabilitando telemetria de Windows Update y Search'
::: $updateSearchRegs = @(
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'; Name = 'SearchOrderConfig'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 99 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'ConnectedSearchPrivacy'; Value = 3 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowSearchToUseLocation'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'EnableDynamicContentInWSB'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'ConnectedSearchUseWeb'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'DisableWebSearch'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'PreventRemoteQueries'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AlwaysUseAutoLangDetection'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowIndexingEncryptedStoresOrItems'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'ConnectedSearchUseWebOverMeteredConnections'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCloudSearch'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCortana'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1 },
:::     @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchHistory'; Value = 1 },
:::     @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDynamicSearchBoxEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsMSACloudSearchEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsAADCloudSearchEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDeviceSearchHistoryEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'VoiceShortcut'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'DeviceHistoryEnabled'; Value = 0 },
:::     @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'HistoryViewEnabled'; Value = 0 },
:::     @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'CortanaEnabled'; Value = 0 }
::: )
::: foreach ($r in $updateSearchRegs) {
:::     if (-not (Test-Path $r.Path)) { New-Item -Path $r.Path -Force | Out-Null }
:::     New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Value -PropertyType DWord -Force | Out-Null
::: }
::: Write-Step 'Telemetria de Update/Search bloqueada'
:::
::: # ---------- OFFICE TELEMETRY ----------
::: Write-Section 'Deshabilitando telemetria de Office'
::: $officeRegs = @(
:::     'HKCU:\SOFTWARE\Microsoft\Office\15.0\Outlook\Options\Mail|EnableLogging|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Options\Mail|EnableLogging|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\15.0\Outlook\Options\Calendar|EnableCalendarLogging|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Options\Calendar|EnableCalendarLogging|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\15.0\Word\Options|EnableLogging|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\16.0\Word\Options|EnableLogging|0',
:::     'HKCU:\SOFTWARE\Policies\Microsoft\Office\15.0\OSM|EnableLogging|0',
:::     'HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\OSM|EnableLogging|0',
:::     'HKCU:\SOFTWARE\Policies\Microsoft\Office\15.0\OSM|EnableUpload|0',
:::     'HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\OSM|EnableUpload|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\Common\ClientTelemetry|DisableTelemetry|1',
:::     'HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\ClientTelemetry|DisableTelemetry|1',
:::     'HKCU:\SOFTWARE\Microsoft\Office\15.0\Common|QMEnable|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\16.0\Common|QMEnable|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\15.0\Common\Feedback|Enabled|0',
:::     'HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\Feedback|Enabled|0'
::: )
::: foreach ($r in $officeRegs) {
:::     $parts = $r -split '\|'
:::     if (-not (Test-Path $parts[0])) { New-Item -Path $parts[0] -Force | Out-Null }
:::     New-ItemProperty -Path $parts[0] -Name $parts[1] -Value ([int]$parts[2]) -PropertyType DWord -Force | Out-Null
::: }
:::
::: 'OfficeTelemetryAgentFallBack','OfficeTelemetryAgentLogOn','OfficeTelemetryAgentFallBack2016','OfficeTelemetryAgentLogOn2016','Office 15 Subscription Heartbeat','Office 16 Subscription Heartbeat' | ForEach-Object {
:::     Disable-ScheduledTask -TaskName "\Microsoft\Office\$_" -ErrorAction SilentlyContinue | Out-Null
::: }
::: Write-Step 'Telemetria de Office deshabilitada'
:::
::: # ---------- OPTIMIZACIONES PARA JUEGOS ----------
::: Write-Section 'Optimizaciones para juegos'
::: New-Item -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Force | Out-Null
::: Set-ItemProperty -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -Value 'SwapEffectUpgradeEnable=0;' -Type String -Force
::: New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null
::: Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_DXGIHonorFSEWindowsCompatible' -Value 1 -Type DWord -Force
::: Write-Step 'Optimizaciones DirectX / Fullscreen aplicadas'
:::
::: Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value '0' -Force
::: Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value '0' -Force
::: Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value '0' -Force
::: Write-Step 'Aceleracion del mouse deshabilitada'
:::
::: # ---------- SERVICIOS ----------
::: Write-Section 'Configurando servicios (Manual)'
::: $manualServices = @(
:::     'ALG','AppMgmt','AppReadiness','Appinfo','AxInstSV','BDESVC','BTAGService','BcastDVRUserService',
:::     'BluetoothUserService','Browser','CDPSvc','COMSysApp','CaptureService','CertPropSvc','ConsentUxUserSvc',
:::     'CscService','DevQueryBroker','DeviceAssociationService','DeviceInstall','DevicePickerUserSvc',
:::     'DevicesFlowUserSvc','DisplayEnhancementService','DmEnrollmentSvc','DsSvc','DsmSvc','EFS','EapHost',
:::     'EntAppSvc','FDResPub','FrameServer','FrameServerMonitor','GraphicsPerfSvc','HvHost','IEEtwCollectorService',
:::     'InstallService','InventorySvc','IpxlatCfgSvc','KtmRm','LicenseManager','LxpSvc','MSDTC','MSiSCSI',
:::     'McpManagementService','MicrosoftEdgeElevationService','MsKeyboardFilter','NPSMSvc','NaturalAuthentication',
:::     'NcaSvc','NcbService','NcdAutoSetup','NetSetupSvc','Netman','NgcCtnrSvc','NgcSvc','NlaSvc','PNRPAutoReg',
:::     'PcaSvc','PeerDistSvc','PenService','PerfHost','PhoneSvc','PimIndexMaintenanceSvc','PlugPlay','PolicyAgent',
:::     'PrintNotify','PushToInstall','QWAVE','RasAuto','RasMan','RetailDemo','RmSvc','RpcLocator','SCPolicySvc',
:::     'SCardSvr','SDRSVC','SEMgrSvc','SNMPTRAP','SNMPTrap','SSDPSRV','ScDeviceEnum','SensorDataService',
:::     'SensorService','SensrSvc','SessionEnv','SharedAccess','SmsRouter','SstpSvc','StiSvc','StorSvc','TapiSrv',
:::     'TextInputManagementService','TieringEngineService','TokenBroker','TroubleshootingSvc','TrustedInstaller',
:::     'UdkUserSvc','UmRdpService','UserDataSvc','UsoSvc','VSS','VacSvc','WEPHOSTSVC','WFDSConMgrSvc',
:::     'WMPNetworkSvc','WManSvc','WPDBusEnum','WalletService','WarpJITSvc','WbioSrvc','WdNisSvc','WdiServiceHost',
:::     'WdiSystemHost','WebClient','Wecsvc','WerSvc','WiaRpc','WinRM','WpcMonSvc','WpnService','WwanSvc',
:::     'autotimesvc','bthserv','camsvc','cbdhsvc','cloudidsvc','dcsvc','defragsvc','diagsvc','dmwappushservice',
:::     'dot3svc','edgeupdate','edgeupdatem','embeddedmode','fdPHost','fhsvc','hidserv','icssvc','lfsvc','lltdsvc',
:::     'lmhosts','msiserver','netprofm','p2pimsvc','p2psvc','perceptionsimulation','pla','seclogon','smphost',
:::     'svsvc','swprv','upnphost','vds','vmicguestinterface','vmicheartbeat','vmickvpexchange','vmicrdv',
:::     'vmicshutdown','vmictimesync','vmicvmsession','vmicvss','vmvss','wbengine','wcncsvc','webthreatdefsvc',
:::     'wercplsupport','wisvc','wlidsvc','wlpasvc','wmiApSrv','workfolderssvc','wuauserv','wudfsvc'
::: )
::: $disabledServices = @(
:::     'AppVClient','AssignedAccessManagerSvc','DiagTrack','DialogBlockingService','NetTcpPortSharing',
:::     'RemoteAccess','RemoteRegistry','shpamsvc','ssh-agent','tzautoupdate'
::: )
::: $manualServices | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }
::: Write-Step "$($manualServices.Count) servicios configurados como Manual"
::: $disabledServices | ForEach-Object { Set-Service -Name $_ -StartupType Disabled -ErrorAction SilentlyContinue }
::: Write-Step "$($disabledServices.Count) servicios deshabilitados (incluye DiagTrack)"
:::
::: # ---------- ULTIMATE PERFORMANCE ----------
::: Write-Section 'Plan de energia Ultimate Performance'
::: $existing = powercfg -list | Select-String -Pattern 'Ultimate Performance'
::: if (-not $existing) {
:::     $output = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
:::     if ($output -match 'Unable to create' -or $output -match 'does not exist') {
:::         powercfg -RestoreDefaultSchemes
:::         powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
:::     }
:::     Write-Step 'Plan Ultimate Performance creado'
::: } else {
:::     Write-Step 'Plan Ultimate Performance ya existia'
::: }
::: $guid = (powercfg -list | Select-String 'Ultimate Performance').Line.Split()[3]
::: powercfg -setactive $guid
::: Write-Step "Plan activado (GUID: $guid)"
:::
::: # ---------- VISUAL / SISTEMA ----------
::: Write-Section 'Optimizaciones visuales y de sistema'
::: Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Type DWord -Force
::: Write-Step 'Transparencia deshabilitada'
:::
::: Stop-Service -Name 'sysmain' -ErrorAction SilentlyContinue
::: Set-Service -Name 'sysmain' -StartupType Disabled -ErrorAction SilentlyContinue
::: Write-Step 'SysMain (SuperFetch) deshabilitado'
:::
::: if (-not (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm')) { New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Force | Out-Null }
::: Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Name 'OverlayTestMode' -Value 5 -Type DWord -Force
::: Write-Step 'Multiplane Overlay (MPO) deshabilitado'
:::
::: if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings')) {
:::     New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Force | Out-Null
::: }
::: Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1 -Type DWord -Force
::: Write-Step 'End Task agregado al click derecho'
:::
::: Write-Host ''
::: Write-Host '== Script PowerShell finalizado ==' -ForegroundColor Cyan
