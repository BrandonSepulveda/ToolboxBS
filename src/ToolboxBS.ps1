<#
.SYNOPSIS
    ToolboxBS v4 - Enterprise / La navaja suiza de Windows
.DESCRIPTION
    Suite de mantenimiento, diagnostico, limpieza, rendimiento, seguridad, red y despliegue
    para Windows 10/11. Arquitectura por catalogo: las herramientas son datos y la UI se
    construye sola, asi que agregar una utilidad nueva es agregar un objeto al catalogo.
.NOTES
    Autor: Brandon Sepulveda  |  v4
    Requiere Windows 10/11 y PowerShell 5.1+. Se auto-eleva a Administrador.
#>

[CmdletBinding()]
param(
    [switch]$SelfTest,      # Valida XAML + catalogo y sale (no abre ventana, no eleva)
    [switch]$NoElevate,     # No intenta relanzarse como administrador
    [string[]]$RunTool,     # Modo consola: ejecuta una o varias herramientas por Id y sale
    [switch]$ListTools,     # Imprime el catalogo completo (Id, categoria, nombre) y sale
    [string]$ExportCatalog, # Vuelca el catalogo a JSON (para documentacion o scripts)
    [switch]$WithCode,      # Con -ExportCatalog: incluye codigo, reversion, preludio y rutinas
    [string]$Shot,          # Render de la interfaz a PNG sin abrirla (control de calidad)
    [string]$ShotView = 'dash'
)

# ============================================================================
#  1. ELEVACION
# ============================================================================
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$Global:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $Global:IsAdmin -and -not $SelfTest -and -not $Shot -and -not $ListTools -and -not $ExportCatalog -and -not $NoElevate) {
    Write-Host "ToolboxBS necesita permisos de Administrador. Relanzando..." -ForegroundColor Yellow
    if (-not $PSCommandPath) {
        Write-Error "El script debe guardarse en un archivo para poder relanzarse como administrador."
        Read-Host "ENTER para salir"
        return
    }
    $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    try {
        Start-Process $exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    }
    catch { Write-Warning "Elevacion cancelada por el usuario." }
    return
}

# Las tareas SIEMPRE corren en Windows PowerShell 5.1: es donde existen
# Checkpoint-Computer, Get-ComputerRestorePoint, Get-AppxPackage y los modulos
# de Defender/DISM sin capas de compatibilidad.
$Global:PsExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$Global:HasWT = [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)

# WPF exige un hilo STA. PowerShell 5.1 y pwsh 7 usan STA por defecto en Windows,
# pero si alguien fuerza -MTA relanzamos en lugar de fallar con un error opaco.
if (-not $SelfTest -and -not $Shot -and -not $ListTools -and -not $ExportCatalog -and -not $RunTool -and [System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    if ($PSCommandPath) {
        Start-Process $Global:PsExe -ArgumentList @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        return
    }
    Write-Error "ToolboxBS necesita ejecutarse en modo STA. Relanza con: powershell -STA -File ToolboxBS.ps1"
    return
}

# ============================================================================
#  2. ENSAMBLADOS .NET
# ============================================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ============================================================================
#  3. RUTAS DE TRABAJO
# ============================================================================
$Global:BSRoot = Join-Path $env:USERPROFILE 'Documents\ToolboxBS'
$Global:BSLogs = Join-Path $Global:BSRoot 'logs'
$Global:BSRep  = Join-Path $Global:BSRoot 'reportes'
$Global:BSBak  = Join-Path $Global:BSRoot 'backups'
$Global:BSProf = Join-Path $Global:BSRoot 'perfiles'
$Global:BSTmp  = Join-Path $env:TEMP 'ToolboxBS'
foreach ($d in @($Global:BSRoot, $Global:BSLogs, $Global:BSRep, $Global:BSBak, $Global:BSProf, $Global:BSTmp)) {
    if (-not (Test-Path $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null }
}

# ============================================================================
#  4. PRELUDIO - se inyecta en TODA tarea que corre en proceso hijo.
#     Da a cada herramienta un vocabulario comun: Step/OK/WARN/ERR/ROW,
#     helpers de registro con backup, limpieza medida y descarga de NirSoft.
# ============================================================================
$Global:Prelude = @'
$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Step  ($m) { Write-Host ""; Write-Host ">> $m" }
function OK    ($m) { Write-Host "[OK] $m" }
function INFO  ($m) { Write-Host "[i] $m" }
function WARN  ($m) { Write-Host "[!] $m" }
function ERR   ($m) { Write-Host "[X] $m" }
function ROW   ($k, $v) { Write-Host ("    {0} {1}" -f $k.PadRight(32, "."), $v) }
function HR    ($t) { Write-Host ""; Write-Host ("=== " + $t + " " + ("=" * [Math]::Max(4, 66 - $t.Length))) }

function Human ([double]$b) {
    if ($b -lt 1KB) { return "$([math]::Round($b,0)) B" }
    elseif ($b -lt 1MB) { return "{0:N1} KB" -f ($b / 1KB) }
    elseif ($b -lt 1GB) { return "{0:N1} MB" -f ($b / 1MB) }
    elseif ($b -lt 1TB) { return "{0:N2} GB" -f ($b / 1GB) }
    else { return "{0:N2} TB" -f ($b / 1TB) }
}

function BSDir ($sub) {
    $p = Join-Path $env:USERPROFILE "Documents\ToolboxBS\$sub"
    if (-not (Test-Path $p)) { New-Item $p -ItemType Directory -Force | Out-Null }
    return $p
}

function Stamp { return (Get-Date -Format "yyyyMMdd_HHmmss") }

function Backup-Reg {
    param([string]$HivePath, [string]$Tag)
    $f = Join-Path (BSDir "backups") ("{0}_{1}.reg" -f $Tag, (Stamp))
    $rp = $HivePath -replace "^HKLM:\\?", "HKEY_LOCAL_MACHINE\" -replace "^HKCU:\\?", "HKEY_CURRENT_USER\" -replace "^HKCR:\\?", "HKEY_CLASSES_ROOT\"
    $null = reg.exe export "$rp" "$f" /y 2>$null
    if (Test-Path $f) { OK "Respaldo del registro: $f" } else { INFO "Sin respaldo (la clave aun no existe): $rp" }
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        OK "$Name = $Value"
    }
    catch { ERR "No se pudo escribir $Path :: $Name  ->  $($_.Exception.Message)" }
}

function Remove-Reg {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop; OK "Eliminado: $Name" }
        else { INFO "No existia la clave $Path" }
    }
    catch { INFO "No existia el valor $Name" }
}

function Need-Winget {
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) { return $true }
    ERR "winget no esta disponible. Usa Rendimiento > Instalar Winget."
    return $false
}

function Get-Folder-Size {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try { return [double]((Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) }
    catch { return 0 }
}

function Purge-Folder {
    param([string]$Path, [string]$Label)
    if (-not $Label) { $Label = $Path }
    if (-not (Test-Path $Path)) { INFO "$Label : no existe, omitido"; return [double]0 }
    $before = Get-Folder-Size $Path
    $n = 0
    Get-ChildItem $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop; $n++ } catch { }
    }
    $freed = $before - (Get-Folder-Size $Path)
    if ($freed -lt 0) { $freed = 0 }
    OK ("{0}: {1} elementos, {2} liberados" -f $Label, $n, (Human $freed))
    return [double]$freed
}

function Stop-Svc { param([string[]]$Names) foreach ($s in $Names) { try { Stop-Service $s -Force -ErrorAction Stop; OK "Detenido: $s" } catch { WARN "No se pudo detener: $s" } } }
function Start-Svc { param([string[]]$Names) foreach ($s in $Names) { try { Start-Service $s -ErrorAction Stop; OK "Iniciado: $s" } catch { WARN "No se pudo iniciar: $s" } } }

function Get-NirTool {
    param([string]$Zip, [string]$Exe)
    $url = "https://www.nirsoft.net/utils/$Zip"
    $base = Join-Path $env:TEMP "ToolboxBS"
    if (-not (Test-Path $base)) { New-Item $base -ItemType Directory -Force | Out-Null }
    $dst = Join-Path $base ($Zip -replace "\.zip$", "")
    $tmp = Join-Path $base $Zip
    $p = Join-Path $dst $Exe
    if (Test-Path $p) { return $p }
    try {
        INFO "Descargando $Zip ..."
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $tmp -DestinationPath $dst -Force -ErrorAction Stop
        if (Test-Path $p) { OK "Listo: $p"; return $p }
        ERR "No se encontro $Exe dentro del paquete."
    }
    catch {
        ERR "Fallo la descarga de $Zip : $($_.Exception.Message)"
        WARN "Defender suele marcar las utilidades NirSoft como riesgo. Si la necesitas, agrega una exclusion para %TEMP%\ToolboxBS."
    }
    return $null
}
'@

# ============================================================================
#  5. CATALOGO DE HERRAMIENTAS
#     Cada herramienta es un objeto. La UI se genera a partir de esta lista,
#     asi que agregar una utilidad = agregar una llamada a T.
#
#     Cat  : repair | clean | perf | sec | net | info | tools
#     Risk : safe (verde) | care (amarillo) | danger (rojo, pide confirmacion)
#     Run  : inline (consola integrada de ToolboxBS) | term (ventana propia)
# ============================================================================
function T {
    param(
        [string]$Id, [string]$Name, [string]$Desc, [string]$Icon, [string]$Cat,
        [string]$Risk = 'safe', [string]$Run = 'inline', [string]$Code, [string]$Revert
    )
    [pscustomobject]@{
        Id = $Id; Name = $Name; Desc = $Desc; Icon = $Icon; Cat = $Cat
        Risk = $Risk; Run = $Run; Code = $Code; Revert = $Revert
    }
}

$Global:Catalog = @(

    # ========================= REPARACION =========================
    T -Id 'repair-restore-point' -Cat 'repair' -Icon 'E792' -Risk 'safe' -Run 'inline' `
        -Name 'Crear punto de restauracion' -Desc 'Habilita la proteccion del sistema y crea un punto' -Code @'
HR "PUNTO DE RESTAURACION"
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
    OK "Proteccion del sistema habilitada en $env:SystemDrive"
} catch { WARN "No se pudo habilitar la proteccion: $($_.Exception.Message)" }

Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "SystemRestorePointCreationFrequency" 0
try {
    Checkpoint-Computer -Description "ToolboxBS $(Get-Date -Format 'dd/MM HH:mm')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    OK "Punto de restauracion creado."
} catch { ERR "No se pudo crear el punto: $($_.Exception.Message)" }

Step "Puntos disponibles"
Get-ComputerRestorePoint -ErrorAction SilentlyContinue |
    Select-Object -Last 5 SequenceNumber, Description, @{n='Fecha';e={$_.ConvertToDateTime($_.CreationTime)}} |
    Format-Table -AutoSize | Out-String | Write-Host
'@

    T -Id 'repair-sfc-dism' -Cat 'repair' -Icon 'E898' -Risk 'safe' -Run 'term' `
        -Name 'Reparar Windows (SFC + DISM)' -Desc 'Verifica y repara la integridad del sistema. Tarda 15-40 min' -Code @'
HR "REPARACION DE INTEGRIDAD DEL SISTEMA"
Step "1/4 DISM CheckHealth"
DISM /Online /Cleanup-Image /CheckHealth
Step "2/4 DISM ScanHealth (puede tardar)"
DISM /Online /Cleanup-Image /ScanHealth
Step "3/4 DISM RestoreHealth"
DISM /Online /Cleanup-Image /RestoreHealth
Step "4/4 SFC /scannow"
sfc /scannow
Step "Resultado del ultimo SFC"
$log = "$env:SystemRoot\Logs\CBS\CBS.log"
if (Test-Path $log) {
    $hits = Select-String -Path $log -Pattern "\[SR\].*(Cannot repair|Repaired|corrupt)" -ErrorAction SilentlyContinue | Select-Object -Last 15
    if ($hits) { $hits | ForEach-Object { INFO $_.Line.Trim() } } else { OK "Sin incidencias registradas por SFC." }
}
'@

    T -Id 'repair-chkdsk' -Cat 'repair' -Icon 'E7BA' -Risk 'care' -Run 'inline' `
        -Name 'Programar CHKDSK' -Desc 'Revisa el disco de sistema en el proximo reinicio' -Code @'
HR "CHKDSK"
Step "Estado actual del volumen"
Get-Volume -DriveLetter $env:SystemDrive[0] | Format-List DriveLetter, FileSystemLabel, HealthStatus, SizeRemaining, Size | Out-String | Write-Host
Step "Analisis en solo lectura"
chkdsk $env:SystemDrive
Step "Programando reparacion en el proximo arranque"
echo S | chkdsk $env:SystemDrive /F /R
OK "CHKDSK quedara programado. Reinicia para que se ejecute (puede tardar 1-2 horas en discos mecanicos)."
'@

    T -Id 'repair-wu-reset' -Cat 'repair' -Icon 'E895' -Risk 'care' -Run 'inline' `
        -Name 'Resetear Windows Update' -Desc 'Reconstruye SoftwareDistribution y catroot2, arregla el 90% de errores de update' -Code @'
HR "RESET DE COMPONENTES DE WINDOWS UPDATE"
Stop-Svc @("wuauserv","cryptSvc","bits","msiserver","usosvc","dosvc")
Step "Renombrando caches"
$stamp = Stamp
foreach ($p in @("$env:SystemRoot\SoftwareDistribution","$env:SystemRoot\System32\catroot2")) {
    if (Test-Path $p) {
        try { Rename-Item $p "$p.$stamp.old" -Force -ErrorAction Stop; OK "Renombrado: $p" }
        catch { WARN "En uso, se intenta vaciar: $p"; Purge-Folder $p (Split-Path $p -Leaf) | Out-Null }
    }
}
Step "Re-registrando componentes"
foreach ($d in @("atl.dll","urlmon.dll","mshtml.dll","jscript.dll","vbscript.dll","msxml3.dll","msxml6.dll","actxprxy.dll","softpub.dll","wintrust.dll","dssenh.dll","rsaenh.dll","cryptdlg.dll","oleaut32.dll","ole32.dll","shell32.dll","wuapi.dll","wuaueng.dll","wucltui.dll","wups.dll","wups2.dll","wuwebv.dll")) {
    $null = regsvr32.exe /s $d 2>$null
}
OK "DLLs re-registradas."
Step "Reiniciando pila de red de BITS"
netsh winsock reset | Out-Null
Start-Svc @("cryptSvc","bits","msiserver","wuauserv")
Step "Forzando deteccion de actualizaciones"
$null = usoclient StartScan 2>$null
OK "Listo. Abre Configuracion > Windows Update y busca actualizaciones."
WARN "Se recomienda reiniciar el equipo."
'@

    T -Id 'repair-store' -Cat 'repair' -Icon 'E71D' -Risk 'care' -Run 'inline' `
        -Name 'Reparar Microsoft Store y apps' -Desc 'Limpia la cache de la Store y re-registra las aplicaciones UWP' -Code @'
HR "REPARACION DE MICROSOFT STORE"
Step "Limpiando cache de la Store"
$p = Start-Process wsreset.exe -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 12
if (-not $p.HasExited) { $p.Kill() }
OK "wsreset ejecutado."

Step "Re-registrando aplicaciones del usuario actual"
$n = 0; $e = 0
Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.InstallLocation -and -not $_.IsFramework } | ForEach-Object {
    $m = Join-Path $_.InstallLocation "AppXManifest.xml"
    if (Test-Path $m) {
        try { Add-AppxPackage -DisableDevelopmentMode -Register $m -ErrorAction Stop; $n++ }
        catch { $e++ }
    }
}
OK "$n aplicaciones re-registradas ($e omitidas, normal en apps del sistema)."

Step "Verificando la Store"
$store = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
if ($store) { OK "Microsoft Store presente: $($store.Version)" }
else { WARN "La Store no esta instalada para este usuario. Ejecuta: wsreset -i" }
'@

    T -Id 'repair-explorer' -Cat 'repair' -Icon 'E8B7' -Risk 'safe' -Run 'inline' `
        -Name 'Reparar Explorador e iconos' -Desc 'Reconstruye la cache de iconos y miniaturas, y reinicia el Explorador' -Code @'
HR "EXPLORADOR DE ARCHIVOS"
Step "Cerrando el Explorador"
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Step "Borrando caches"
$loc = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$freed = 0
Get-ChildItem $loc -Filter "iconcache*" -Force -ErrorAction SilentlyContinue | ForEach-Object { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
Get-ChildItem $loc -Filter "thumbcache*" -Force -ErrorAction SilentlyContinue | ForEach-Object { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
OK "Cache de iconos y miniaturas eliminada ($(Human $freed))."

Step "Reiniciando el Explorador"
Start-Process explorer.exe
OK "Explorador reiniciado."
'@

    T -Id 'repair-print' -Cat 'repair' -Icon 'E749' -Risk 'safe' -Run 'inline' `
        -Name 'Reparar cola de impresion' -Desc 'Detiene el spooler, borra trabajos atascados y lo reinicia' -Code @'
HR "COLA DE IMPRESION"
Stop-Svc @("Spooler")
Start-Sleep -Seconds 2
$q = "$env:SystemRoot\System32\spool\PRINTERS"
Purge-Folder $q "Trabajos en cola" | Out-Null
Start-Svc @("Spooler")
Step "Impresoras instaladas"
Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName, PrinterStatus | Format-Table -AutoSize | Out-String | Write-Host
OK "Cola de impresion reiniciada."
'@

    T -Id 'repair-audio' -Cat 'repair' -Icon 'E767' -Risk 'safe' -Run 'inline' `
        -Name 'Reparar audio' -Desc 'Reinicia los servicios de sonido y lista los dispositivos' -Code @'
HR "SUBSISTEMA DE AUDIO"
Stop-Svc @("Audiosrv","AudioEndpointBuilder")
Start-Sleep -Seconds 2
Start-Svc @("AudioEndpointBuilder","Audiosrv")
Step "Dispositivos de sonido detectados"
Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue | ForEach-Object { ROW $_.Name $_.Status }
Step "Controladores con problemas"
$bad = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 -and $_.Name -match "audio|sound|realtek|conexant" }
if ($bad) { $bad | ForEach-Object { ERR "$($_.Name) -> codigo $($_.ConfigManagerErrorCode)" } } else { OK "Sin errores en controladores de audio." }
'@

    T -Id 'repair-search' -Cat 'repair' -Icon 'E721' -Risk 'safe' -Run 'inline' `
        -Name 'Reconstruir busqueda de Windows' -Desc 'Regenera el indice cuando el buscador del menu Inicio deja de responder' -Code @'
HR "INDICE DE BUSQUEDA"
Stop-Svc @("WSearch")
$db = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
if (Test-Path $db) {
    $sz = Get-Folder-Size $db
    Get-ChildItem $db -Filter "Windows.edb" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    OK "Base del indice eliminada ($(Human $sz))."
}
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows Search" "SetupCompletedSuccessfully" 0
Start-Svc @("WSearch")
OK "El indice se reconstruira en segundo plano (puede tardar horas y consumir CPU)."
Step "Reiniciando SearchHost"
Stop-Process -Name SearchHost, SearchApp -Force -ErrorAction SilentlyContinue
OK "Listo."
'@

    T -Id 'repair-network' -Cat 'repair' -Icon 'E774' -Risk 'care' -Run 'inline' `
        -Name 'Restablecer red completa' -Desc 'Winsock, TCP/IP, DNS, firewall y renovacion de IP' -Code @'
HR "RESTABLECIMIENTO DE RED"
Step "Winsock"; netsh winsock reset
Step "TCP/IP v4"; netsh int ip reset
Step "TCP/IP v6"; netsh int ipv6 reset
Step "Proxy WinHTTP"; netsh winhttp reset proxy
Step "Firewall"; netsh advfirewall reset
Step "DHCP y DNS"
ipconfig /release | Out-Null
ipconfig /renew   | Out-Null
ipconfig /flushdns | Out-Null
ipconfig /registerdns | Out-Null
OK "Pila de red restablecida."
Step "Estado actual"
Get-NetIPConfiguration -ErrorAction SilentlyContinue | ForEach-Object {
    ROW "Interfaz" $_.InterfaceAlias
    ROW "  IPv4" ($_.IPv4Address.IPAddress -join ", ")
    ROW "  Gateway" ($_.IPv4DefaultGateway.NextHop -join ", ")
    ROW "  DNS" (($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses -join ", ")
}
WARN "Reinicia el equipo para completar el restablecimiento."
'@

    T -Id 'repair-firewall' -Cat 'repair' -Icon 'E72E' -Risk 'care' -Run 'inline' `
        -Name 'Restaurar firewall por defecto' -Desc 'Elimina reglas rotas y devuelve el firewall a los valores de fabrica' -Code @'
HR "FIREWALL DE WINDOWS"
Step "Reglas personalizadas antes del reset"
$n = (Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { -not $_.Group }).Count
INFO "$n reglas sin grupo (habitualmente creadas por apps de terceros)."
Step "Restableciendo"
netsh advfirewall reset
Step "Habilitando los tres perfiles"
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction SilentlyContinue
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize | Out-String | Write-Host
OK "Firewall restaurado."
'@

    T -Id 'repair-startmenu' -Cat 'repair' -Icon 'E80F' -Risk 'care' -Run 'inline' `
        -Name 'Reparar menu Inicio y barra' -Desc 'Reconstruye el paquete del Shell cuando el menu Inicio no abre' -Code @'
HR "MENU INICIO Y BARRA DE TAREAS"
Step "Re-registrando el Shell Experience"
foreach ($pkg in @("Microsoft.Windows.ShellExperienceHost","Microsoft.Windows.StartMenuExperienceHost","Microsoft.Windows.Search")) {
    $a = Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue
    if ($a -and $a.InstallLocation) {
        try { Add-AppxPackage -DisableDevelopmentMode -Register "$($a.InstallLocation)\AppXManifest.xml" -ErrorAction Stop; OK "Re-registrado: $pkg" }
        catch { WARN "No se pudo re-registrar: $pkg" }
    } else { INFO "No presente: $pkg" }
}
Step "Limpiando cache de TileData / anclajes"
$td = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\TempState"
Purge-Folder $td "TempState del menu Inicio" | Out-Null
Step "Reiniciando procesos del Shell"
Stop-Process -Name StartMenuExperienceHost, ShellExperienceHost, SearchHost -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
OK "Shell reiniciado."
'@

    T -Id 'repair-bsod' -Cat 'repair' -Icon 'E7BA' -Risk 'safe' -Run 'inline' `
        -Name 'Analizar pantallazos azules' -Desc 'Lee los minidumps, resume los codigos de parada y abre BlueScreenView' -Code @'
HR "ANALISIS DE BSOD"
Step "Eventos de apagado inesperado (BugCheck)"
$ev = Get-WinEvent -FilterHashtable @{LogName='System'; Id=1001,41,6008} -MaxEvents 40 -ErrorAction SilentlyContinue
if ($ev) {
    $ev | ForEach-Object { ROW $_.TimeCreated.ToString("dd/MM/yyyy HH:mm") ("Id " + $_.Id + " - " + ($_.Message -split "`n")[0]) }
} else { OK "Sin eventos de caida registrados." }

Step "Archivos de volcado"
$dumps = @()
$dumps += Get-ChildItem "$env:SystemRoot\Minidump" -Filter *.dmp -ErrorAction SilentlyContinue
if (Test-Path "$env:SystemRoot\MEMORY.DMP") { $dumps += Get-Item "$env:SystemRoot\MEMORY.DMP" }
if ($dumps) {
    $dumps | Sort-Object LastWriteTime -Descending | Select-Object -First 15 |
        ForEach-Object { ROW $_.LastWriteTime.ToString("dd/MM/yyyy HH:mm") ("$($_.Name)  " + (Human $_.Length)) }
    INFO "Total: $($dumps.Count) volcados."
} else { OK "No hay volcados de memoria: el equipo no ha tenido BSOD recientes." }

Step "Verificando que los volcados esten habilitados"
$cc = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -ErrorAction SilentlyContinue
if ($cc.CrashDumpEnabled -eq 0) { WARN "Los volcados estan deshabilitados; se activa el minivolcado." ; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "CrashDumpEnabled" 3 }
else { OK "Volcados habilitados (modo $($cc.CrashDumpEnabled))." }

Step "BlueScreenView"
$exe = Get-NirTool "bluescreenview.zip" "BlueScreenView.exe"
if ($exe) { Start-Process $exe }
'@

    T -Id 'repair-events' -Cat 'repair' -Icon 'E8F1' -Risk 'safe' -Run 'inline' `
        -Name 'Triaje de errores del sistema' -Desc 'Agrupa los errores criticos de los ultimos 7 dias por origen' -Code @'
HR "EVENTOS CRITICOS - ULTIMOS 7 DIAS"
$desde = (Get-Date).AddDays(-7)
foreach ($lg in @("System","Application")) {
    Step "Registro: $lg"
    $ev = Get-WinEvent -FilterHashtable @{LogName=$lg; Level=1,2; StartTime=$desde} -ErrorAction SilentlyContinue
    if (-not $ev) { OK "Sin errores en $lg."; continue }
    INFO "$($ev.Count) eventos de error/critico."
    $ev | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
        ROW $_.Name "$($_.Count) eventos"
        $m = ($_.Group[0].Message -split "`n")[0]
        if ($m) { Write-Host ("        -> " + $m.Trim()) }
    }
}
Step "Exportando reporte"
$f = Join-Path (BSDir "reportes") ("eventos_" + (Stamp) + ".csv")
Get-WinEvent -FilterHashtable @{LogName="System","Application"; Level=1,2; StartTime=$desde} -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, LogName, ProviderName, Id, LevelDisplayName, Message |
    Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "Reporte guardado: $f"
'@

    T -Id 'repair-memtest' -Cat 'repair' -Icon 'E964' -Risk 'care' -Run 'inline' `
        -Name 'Diagnostico de memoria RAM' -Desc 'Revisa resultados previos y programa la prueba de memoria de Windows' -Code @'
HR "DIAGNOSTICO DE MEMORIA"
Step "Resultados de pruebas anteriores"
$r = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'} -MaxEvents 5 -ErrorAction SilentlyContinue
if ($r) { $r | ForEach-Object { ROW $_.TimeCreated.ToString("dd/MM/yyyy HH:mm") (($_.Message -split "`n")[0]) } }
else { INFO "No hay resultados previos." }

Step "Modulos instalados"
Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    ROW "$($_.BankLabel) $($_.DeviceLocator)" ("$(Human $_.Capacity)  $($_.Speed)MHz  $($_.Manufacturer)  SN:$($_.SerialNumber)")
}
Step "Programando la prueba para el proximo reinicio"
$null = mdsched.exe /? 2>$null
Start-Process "mdsched.exe"
INFO "Se abrio el Diagnostico de memoria de Windows: elige 'Reiniciar ahora' o 'Comprobar la proxima vez'."
'@

    T -Id 'repair-battery' -Cat 'repair' -Icon 'E83F' -Risk 'safe' -Run 'inline' `
        -Name 'Salud y carga de la bateria' -Desc 'Porcentaje actual, autonomia restante, ciclos y desgaste real frente al de fabrica' -Code @'
HR "BATERIA"

# Se consultan TRES fuentes distintas a proposito. Win32_Battery es WMI y en
# bastantes portatiles devuelve vacio o incompleto; la API GetSystemPowerStatus
# de Windows, en cambio, es la misma que usa el icono de la bandeja y casi
# nunca falla. Si una fuente no responde, se sigue con la siguiente en vez de
# cortar: pase lo que pase, abajo se generan el informe de powercfg y
# BatteryInfoView.
$hayBateria = $false
$pct = $null
$enCorriente = $null

Step "Fuente 1: API de Windows (GetSystemPowerStatus)"
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $ps = [System.Windows.Forms.SystemInformation]::PowerStatus
    ROW "Estado de carga" $ps.BatteryChargeStatus
    ROW "Alimentacion" $(switch ($ps.PowerLineStatus) { "Online" { "conectado a la corriente" } "Offline" { "con bateria" } default { $ps.PowerLineStatus } })

    if ($ps.BatteryChargeStatus -ne "NoSystemBattery") {
        $hayBateria = $true
        $enCorriente = ($ps.PowerLineStatus -eq "Online")
        # BatteryLifePercent va de 0 a 1; Windows manda 255 (-> 2.55) si no lo sabe
        if ($ps.BatteryLifePercent -ge 0 -and $ps.BatteryLifePercent -le 1) {
            $pct = [int][math]::Round($ps.BatteryLifePercent * 100)
        }
        if ($ps.BatteryLifeRemaining -gt 0) {
            $h = [math]::Floor($ps.BatteryLifeRemaining / 3600)
            $m = [math]::Floor(($ps.BatteryLifeRemaining % 3600) / 60)
            ROW "Autonomia restante" $(if ($h -gt 0) { "$h h $m min" } else { "$m min" })
        }
    }
}
catch { WARN "No se pudo consultar la API de energia: $($_.Exception.Message)" }

Step "Fuente 2: WMI (Win32_Battery)"
$bat = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
if ($bat.Count -eq 0) {
    INFO "Win32_Battery no devolvio nada."
}
else {
    $hayBateria = $true
    $i = 0
    foreach ($b in $bat) {
        $i++
        if ($bat.Count -gt 1) { Step "  Bateria $i de $($bat.Count)" }
        if ($null -eq $pct -and $null -ne $b.EstimatedChargeRemaining) { $pct = [int]$b.EstimatedChargeRemaining }
        ROW "Nombre" $b.Name
        $estado = switch ($b.BatteryStatus) {
            1 { "Descargando" } 2 { "Conectada a la corriente" } 3 { "Totalmente cargada" }
            4 { "Baja" } 5 { "Critica" } 6 { "Cargando" } 7 { "Cargando (alta)" }
            8 { "Cargando (baja)" } 9 { "Cargando (critica)" } 10 { "Sin definir" }
            11 { "Parcialmente cargada" } default { "Desconocido ($($b.BatteryStatus))" }
        }
        ROW "Estado" $estado
        if ($null -eq $enCorriente) { $enCorriente = ($b.BatteryStatus -in @(2, 6, 7, 8, 9)) }
        # 71582788 es el centinela de "no lo se" que devuelve Windows
        if ($b.EstimatedRunTime -and $b.EstimatedRunTime -lt 71582788) {
            $h = [math]::Floor($b.EstimatedRunTime / 60); $m = $b.EstimatedRunTime % 60
            ROW "Autonomia (WMI)" $(if ($h -gt 0) { "$h h $m min" } else { "$m min" })
        }
    }
}

# --- Carga actual: lo primero que uno quiere ver ---
if ($null -ne $pct) {
    $barra = ("#" * [math]::Round($pct / 5)).PadRight(20, ".")
    Write-Host ""
    Write-Host "    CARGA ACTUAL:  $pct%   [$barra]"
    Write-Host ""
    if ($enCorriente) { OK "Conectada a la corriente." }
    elseif ($pct -le 15) { ERR "Carga muy baja: conecta el cargador." }
    elseif ($pct -le 35) { WARN "Carga baja." }
}
elseif ($hayBateria) {
    WARN "Hay bateria, pero ni la API ni WMI dieron el porcentaje."
    INFO "El informe de powercfg de abajo lo trae de todas formas."
}
else {
    WARN "No se detecto ninguna bateria: parece un equipo de escritorio."
    INFO "PCSystemType = $((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).PCSystemType)  (1 = escritorio, 2 = portatil)"
    INFO "Aun asi se genera el informe de powercfg, por si el portatil no reporta bien."
}

# --- Desgaste real: lo que de verdad dice si hay que cambiarla ---
Step "Desgaste"
$full = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1).FullChargedCapacity
$est = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
$dsg = $est.DesignedCapacity

if ($est) {
    if ($est.DeviceName) { ROW "Modelo" $est.DeviceName }
    if ($est.ManufactureName) { ROW "Fabricante" $est.ManufactureName }
    if ($est.SerialNumber) { ROW "Numero de serie" $est.SerialNumber }
    if ($est.Chemistry) {
        $quim = switch ($est.Chemistry) { 1 { "Otra" } 2 { "Desconocida" } 3 { "Plomo-acido" } 4 { "NiCd" } 5 { "NiMH" } 6 { "Ion de litio" } 7 { "Zinc-aire" } 8 { "Polimero de litio" } default { $est.Chemistry } }
        ROW "Quimica" $quim
    }
}

$ciclos = (Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction SilentlyContinue | Select-Object -First 1).CycleCount
if ($ciclos -and $ciclos -gt 0) {
    ROW "Ciclos de carga" $ciclos
    if ($ciclos -gt 1000) { WARN "  Por encima de 1000 ciclos: es normal que rinda menos." }
}
else { INFO "El firmware no expone el contador de ciclos (habitual en muchos portatiles)." }

if ($dsg -and $full -and $dsg -gt 0) {
    $salud = [math]::Round(($full / $dsg) * 100, 1)
    ROW "Capacidad de fabrica" "$dsg mWh"
    ROW "Capacidad real hoy" "$full mWh"
    ROW "SALUD" "$salud %  (se perdio $([math]::Round(100 - $salud, 1))%)"
    if ($salud -lt 60) { ERR "Bateria degradada: se recomienda reemplazo." }
    elseif ($salud -lt 80) { WARN "Desgaste notable, aun usable." }
    else { OK "Bateria en buen estado." }
}
else { INFO "El firmware no expone las capacidades de diseno y carga; el informe de powercfg de abajo si las trae." }

Step "Generando informe HTML de powercfg"
$f = Join-Path (BSDir "reportes") ("bateria_" + (Stamp) + ".html")
powercfg /batteryreport /output "$f" | Out-Null
if (Test-Path $f) { OK "Informe: $f"; Start-Process $f } else { ERR "powercfg no pudo generar el informe." }

Step "Informe de eficiencia energetica"
$f2 = Join-Path (BSDir "reportes") ("energia_" + (Stamp) + ".html")
powercfg /energy /output "$f2" /duration 30 | Out-Null
if (Test-Path $f2) { OK "Analisis de energia: $f2" }

Step "BatteryInfoView"
$exe = Get-NirTool "batteryinfoview.zip" "BatteryInfoView.exe"
if ($exe) { Start-Process $exe } else { INFO "Los datos de arriba salen del propio Windows y no dependen de esta utilidad." }
'@

    T -Id 'repair-drivers-list' -Cat 'repair' -Icon 'E7F8' -Risk 'safe' -Run 'inline' `
        -Name 'Inventario de controladores' -Desc 'Exporta todos los drivers y senala los que estan fallando' -Code @'
HR "CONTROLADORES DEL SISTEMA"
Step "Dispositivos con problemas"
$bad = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
if ($bad) {
    $bad | ForEach-Object { ERR "$($_.Name)  [codigo $($_.ConfigManagerErrorCode)]  $($_.DeviceID)" }
    WARN "$($bad.Count) dispositivos con error. Revisa el Administrador de dispositivos."
} else { OK "Ningun dispositivo reporta errores." }

Step "Controladores de terceros instalados"
$drv = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
    Where-Object { $_.DeviceName -and $_.DriverProviderName -notmatch "^Microsoft" } |
    Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate, Manufacturer
INFO "$($drv.Count) controladores de terceros."
$drv | Sort-Object DriverProviderName | Select-Object -First 25 | ForEach-Object { ROW $_.DeviceName "$($_.DriverProviderName) v$($_.DriverVersion)" }

$f = Join-Path (BSDir "reportes") ("drivers_" + (Stamp) + ".csv")
$drv | Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "Inventario completo: $f"
Start-Process "devmgmt.msc"
'@

    T -Id 'repair-drivers-backup' -Cat 'repair' -Icon 'E74E' -Risk 'safe' -Run 'inline' `
        -Name 'Respaldar todos los drivers' -Desc 'Exporta los controladores a una carpeta para reinstalarlos tras formatear' -Code @'
HR "RESPALDO DE CONTROLADORES"
$dst = Join-Path (BSDir "backups") ("drivers_" + $env:COMPUTERNAME + "_" + (Stamp))
New-Item $dst -ItemType Directory -Force | Out-Null
INFO "Destino: $dst"
Step "Exportando (esto tarda varios minutos)"
$out = pnputil.exe /export-driver * "$dst" 2>&1
$out | Select-Object -Last 5 | ForEach-Object { Write-Host "    $_" }
$n = (Get-ChildItem $dst -Directory -ErrorAction SilentlyContinue).Count
$sz = Get-Folder-Size $dst
if ($n -gt 0) {
    OK "$n paquetes de controlador exportados ($(Human $sz))."
    INFO "Para restaurarlos en el equipo nuevo: pnputil /add-driver `"$dst\*.inf`" /subdirs /install"
    Start-Process explorer.exe $dst
} else { ERR "No se exporto ningun controlador. Verifica que estas como Administrador." }
'@

    T -Id 'repair-drivers-restore' -Cat 'repair' -Icon 'E896' -Risk 'care' -Run 'inline' `
        -Name 'Restaurar drivers respaldados' -Desc 'Reinstala los controladores desde la carpeta de respaldo mas reciente' -Code @'
HR "RESTAURACION DE CONTROLADORES"
$base = BSDir "backups"
$carp = Get-ChildItem $base -Directory -Filter "drivers_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if (-not $carp) { ERR "No hay respaldos de drivers en $base. Ejecuta primero 'Respaldar todos los drivers'."; return }
$src = $carp[0].FullName
INFO "Usando el respaldo: $src"
Step "Instalando"
pnputil.exe /add-driver "$src\*.inf" /subdirs /install
OK "Proceso terminado. Reinicia el equipo."
'@

    T -Id 'repair-winsxs' -Cat 'repair' -Icon 'E950' -Risk 'care' -Run 'term' `
        -Name 'Compactar WinSxS' -Desc 'Elimina versiones antiguas de componentes. Libera varios GB pero impide desinstalar updates' -Code @'
HR "LIMPIEZA DE COMPONENTES (WinSxS)"
Step "Tamano actual"
DISM /Online /Cleanup-Image /AnalyzeComponentStore
Step "Limpieza con ResetBase"
WARN "Tras esto no se podran desinstalar las actualizaciones ya aplicadas."
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
Step "Resultado"
DISM /Online /Cleanup-Image /AnalyzeComponentStore
'@

    T -Id 'repair-time' -Cat 'repair' -Icon 'E823' -Risk 'safe' -Run 'inline' `
        -Name 'Sincronizar reloj del sistema' -Desc 'Arregla certificados y accesos que fallan por hora incorrecta' -Code @'
HR "HORA DEL SISTEMA"
ROW "Hora local" (Get-Date).ToString("dd/MM/yyyy HH:mm:ss")
ROW "Zona horaria" (Get-TimeZone).DisplayName
Step "Reconfigurando el servicio de hora"
Set-Service w32time -StartupType Automatic -ErrorAction SilentlyContinue
Start-Svc @("w32time")
w32tm /config /manualpeerlist:"time.windows.com,0x9 pool.ntp.org,0x9" /syncfromflags:manual /reliable:yes /update
Step "Forzando sincronizacion"
w32tm /resync /force
Step "Estado"
w32tm /query /status
OK "Reloj sincronizado."
'@

    T -Id 'repair-netfx' -Cat 'repair' -Icon 'E943' -Risk 'safe' -Run 'inline' `
        -Name 'Verificar .NET y runtimes' -Desc 'Lista versiones de .NET, VC++ y habilita .NET 3.5 si falta' -Code @'
HR ".NET FRAMEWORK Y RUNTIMES"
Step "Versiones de .NET Framework"
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP" -Recurse -ErrorAction SilentlyContinue |
    Get-ItemProperty -Name Version, Release -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match "^(?!S)\p{L}" } |
    Select-Object PSChildName, Version -Unique | ForEach-Object { ROW $_.PSChildName $_.Version }

Step "Runtimes de Visual C++"
Get-CimInstance Win32_Product -Filter "Name LIKE '%Visual C++%'" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Name -Unique | ForEach-Object { INFO $_ }

Step ".NET 3.5 (requerido por software antiguo)"
$f = Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -ErrorAction SilentlyContinue
if ($f.State -eq "Enabled") { OK ".NET 3.5 habilitado." }
else {
    WARN ".NET 3.5 deshabilitado. Habilitando..."
    Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
    OK "Solicitud enviada (puede requerir conexion a Windows Update)."
}
'@

    T -Id 'repair-profile' -Cat 'repair' -Icon 'E77B' -Risk 'safe' -Run 'inline' `
        -Name 'Auditar perfiles de usuario' -Desc 'Detecta perfiles corruptos, temporales o huerfanos y su peso en disco' -Code @'
HR "PERFILES DE USUARIO"
$profs = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special }
foreach ($p in $profs) {
    $name = Split-Path $p.LocalPath -Leaf
    $sz = Get-Folder-Size $p.LocalPath
    $estado = if ($p.Status -band 1) { "TEMPORAL (corrupto)" } elseif ($p.Status -band 8) { "CORRUPTO" } else { "OK" }
    ROW $name "$(Human $sz)  |  $estado  |  $($p.LastUseTime)"
    if ($estado -ne "OK") { ERR "El perfil $name esta danado. Se soluciona renombrando su clave en ProfileList del registro." }
}
Step "Claves .bak en ProfileList (sintoma clasico de perfil temporal)"
$bak = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*.bak" }
if ($bak) { $bak | ForEach-Object { ERR "Clave sospechosa: $($_.PSChildName)" } } else { OK "Sin claves .bak." }
'@

    T -Id 'repair-uwp-core' -Cat 'repair' -Icon 'ECAA' -Risk 'care' -Run 'inline' `
        -Name 'Reinstalar apps esenciales' -Desc 'Recupera Calculadora, Fotos, Camara, Notas y Terminal si fueron borradas' -Code @'
HR "REINSTALACION DE APPS ESENCIALES"
if (-not (Need-Winget)) { return }
$apps = @(
    @{n="Calculadora";      id="9WZDNCRFHVN5"},
    @{n="Fotos";            id="9WZDNCRFJBH4"},
    @{n="Camara";           id="9WZDNCRFJBBG"},
    @{n="Notas rapidas";    id="9NBLGGH4QGHW"},
    @{n="Terminal";         id="Microsoft.WindowsTerminal"},
    @{n="Paint";            id="9PCFS5B6T72H"},
    @{n="Recorte";          id="9MZ95KL8MR0L"}
)
foreach ($a in $apps) {
    Step "Instalando $($a.n)"
    winget install --id $($a.id) -e --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" }
}
OK "Proceso terminado."
'@

    # ========================= LIMPIEZA =========================
    T -Id 'clean-temp' -Cat 'clean' -Icon 'E74D' -Risk 'safe' -Run 'inline' `
        -Name 'Purgar temporales' -Desc 'Temp de usuario y de Windows, Prefetch, informes de errores y cache de entrega' -Code @'
HR "LIMPIEZA DE ARCHIVOS TEMPORALES"
$tot = 0
$tot += Purge-Folder $env:TEMP "Temp del usuario"
$tot += Purge-Folder "$env:SystemRoot\Temp" "Temp de Windows"
$tot += Purge-Folder "$env:SystemRoot\Prefetch" "Prefetch"
$tot += Purge-Folder "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" "Informes de error (cola)"
$tot += Purge-Folder "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" "Informes de error (archivo)"
$tot += Purge-Folder "$env:LOCALAPPDATA\CrashDumps" "Volcados de aplicaciones"
$tot += Purge-Folder "$env:SystemDrive\`$WinREAgent" "Restos de actualizacion"
$tot += Purge-Folder "$env:ProgramData\Microsoft\Network\Downloader" "Cache de entrega BITS"
HR ("TOTAL LIBERADO: " + (Human $tot))
'@

    T -Id 'clean-browsers' -Cat 'clean' -Icon 'E774' -Risk 'care' -Run 'inline' `
        -Name 'Cache de navegadores' -Desc 'Chrome, Edge, Brave, Opera y Firefox. No borra contrasenas ni marcadores' -Code @'
HR "CACHE DE NAVEGADORES"
WARN "Cierra los navegadores para que la limpieza sea completa."
$tot = 0
$chromium = @{
    "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    "Edge"   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    "Brave"  = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    "Opera"  = "$env:APPDATA\Opera Software\Opera Stable"
    "Vivaldi"= "$env:LOCALAPPDATA\Vivaldi\User Data"
}
foreach ($k in $chromium.Keys) {
    $root = $chromium[$k]
    if (-not (Test-Path $root)) { INFO "$k : no instalado"; continue }
    Step $k
    Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile*" -or $_.Name -eq "Opera Stable" } | ForEach-Object {
        foreach ($sub in @("Cache","Code Cache","GPUCache","Service Worker\CacheStorage","DawnCache","ShaderCache")) {
            $p = Join-Path $_.FullName $sub
            if (Test-Path $p) { $tot += Purge-Folder $p "  $k/$($_.Name)/$sub" }
        }
    }
}
Step "Firefox"
$ff = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ff) {
    Get-ChildItem $ff -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($sub in @("cache2","startupCache","thumbnails")) {
            $p = Join-Path $_.FullName $sub
            if (Test-Path $p) { $tot += Purge-Folder $p "  Firefox/$($_.Name)/$sub" }
        }
    }
} else { INFO "Firefox : no instalado" }
Step "Cache de Internet Explorer / WebView"
$tot += Purge-Folder "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" "INetCache"
HR ("TOTAL LIBERADO: " + (Human $tot))
'@

    T -Id 'clean-recycle' -Cat 'clean' -Icon 'E74D' -Risk 'care' -Run 'inline' `
        -Name 'Vaciar papelera' -Desc 'Vacia la papelera de reciclaje de todas las unidades' -Code @'
HR "PAPELERA DE RECICLAJE"
$antes = 0
Get-ChildItem "$env:SystemDrive\`$Recycle.Bin" -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $antes += $_.Length }
INFO ("Contenido estimado: " + (Human $antes))
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    OK "Papelera vaciada."
} catch {
    WARN "Clear-RecycleBin fallo, usando metodo alterno."
    Get-ChildItem "$env:SystemDrive\`$Recycle.Bin" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    OK "Papelera vaciada (metodo alterno)."
}
'@

    T -Id 'clean-winold' -Cat 'clean' -Icon 'E8B7' -Risk 'danger' -Run 'inline' `
        -Name 'Eliminar Windows.old' -Desc 'Borra la instalacion anterior. Libera 10-30 GB pero impide volver a la version previa' -Code @'
HR "INSTALACION ANTERIOR DE WINDOWS"
$wo = "$env:SystemDrive\Windows.old"
if (-not (Test-Path $wo)) { OK "No existe Windows.old, nada que borrar."; return }
$sz = Get-Folder-Size $wo
WARN ("Windows.old ocupa " + (Human $sz) + ". Al borrarlo pierdes la opcion de volver a la version anterior.")
Step "Tomando propiedad"
takeown /F "$wo" /R /A /D S 2>&1 | Out-Null
icacls "$wo" /grant "*S-1-5-32-544:F" /T /C 2>&1 | Out-Null
Step "Eliminando"
Remove-Item $wo -Recurse -Force -ErrorAction SilentlyContinue
if (Test-Path $wo) {
    WARN "Quedaron restos. Usando el limpiador del sistema."
    Start-Process cleanmgr.exe -ArgumentList "/sageset:99"
} else { OK ("Eliminado. " + (Human $sz) + " liberados.") }

Step "Restos de actualizaciones"
Purge-Folder "$env:SystemDrive\`$Windows.~BT" "Windows.~BT" | Out-Null
Purge-Folder "$env:SystemDrive\`$Windows.~WS" "Windows.~WS" | Out-Null
Purge-Folder "$env:SystemDrive\ESD" "ESD" | Out-Null
'@

    T -Id 'clean-thumbs' -Cat 'clean' -Icon 'E91B' -Risk 'safe' -Run 'inline' `
        -Name 'Cache de miniaturas e iconos' -Desc 'Arregla miniaturas en blanco o iconos equivocados' -Code @'
HR "CACHE DE MINIATURAS"
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$loc = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$freed = 0
Get-ChildItem $loc -Include "thumbcache*","iconcache*" -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $freed += $_.Length
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
}
OK ("Cache eliminada: " + (Human $freed))
Start-Process explorer.exe
'@

    T -Id 'clean-logs' -Cat 'clean' -Icon 'E8A5' -Risk 'safe' -Run 'inline' `
        -Name 'Logs y volcados del sistema' -Desc 'CBS, DISM, informes de rendimiento y volcados de memoria antiguos' -Code @'
HR "LOGS Y VOLCADOS"
$tot = 0
$tot += Purge-Folder "$env:SystemRoot\Logs\CBS" "Logs CBS"
$tot += Purge-Folder "$env:SystemRoot\Logs\DISM" "Logs DISM"
$tot += Purge-Folder "$env:SystemRoot\Logs\MoSetup" "Logs de instalacion"
$tot += Purge-Folder "$env:SystemRoot\Panther" "Panther (setup)"
$tot += Purge-Folder "$env:SystemRoot\SoftwareDistribution\Download" "Descargas de Windows Update"
Step "Minivolcados de BSOD"
$md = "$env:SystemRoot\Minidump"
if (Test-Path $md) {
    $old = Get-ChildItem $md -Filter *.dmp -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
    $s = ($old | Measure-Object Length -Sum).Sum
    $old | Remove-Item -Force -ErrorAction SilentlyContinue
    OK ("Minivolcados de mas de 30 dias eliminados: " + (Human $s))
    $tot += $s
}
Step "MEMORY.DMP"
$mem = "$env:SystemRoot\MEMORY.DMP"
if (Test-Path $mem) {
    $s = (Get-Item $mem).Length
    Remove-Item $mem -Force -ErrorAction SilentlyContinue
    OK ("MEMORY.DMP eliminado: " + (Human $s)); $tot += $s
}
HR ("TOTAL LIBERADO: " + (Human $tot))
'@

    T -Id 'clean-apps-cache' -Cat 'clean' -Icon 'ECAA' -Risk 'safe' -Run 'inline' `
        -Name 'Cache de aplicaciones' -Desc 'Teams, Discord, Spotify, Adobe, Zoom, Slack y la Store' -Code @'
HR "CACHE DE APLICACIONES"
$tot = 0
$rutas = @(
    @{p="$env:APPDATA\Microsoft\Teams\Cache";                        n="Teams (clasico)"},
    @{p="$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"; n="Teams (nuevo)"},
    @{p="$env:APPDATA\discord\Cache";                                n="Discord"},
    @{p="$env:APPDATA\discord\Code Cache";                           n="Discord code"},
    @{p="$env:LOCALAPPDATA\Spotify\Storage";                         n="Spotify"},
    @{p="$env:APPDATA\Slack\Cache";                                  n="Slack"},
    @{p="$env:APPDATA\Zoom\data";                                    n="Zoom"},
    @{p="$env:LOCALAPPDATA\Adobe\Common\Media Cache Files";          n="Adobe media"},
    @{p="$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"; n="Microsoft Store"},
    @{p="$env:LOCALAPPDATA\NVIDIA\DXCache";                          n="NVIDIA shader"},
    @{p="$env:LOCALAPPDATA\AMD\DxCache";                             n="AMD shader"},
    @{p="$env:LOCALAPPDATA\D3DSCache";                               n="DirectX shader"},
    @{p="$env:LOCALAPPDATA\pip\cache";                               n="pip"},
    @{p="$env:APPDATA\npm-cache\_cacache";                           n="npm"}
)
foreach ($r in $rutas) { $tot += Purge-Folder $r.p $r.n }
HR ("TOTAL LIBERADO: " + (Human $tot))
'@

    T -Id 'clean-cleanmgr' -Cat 'clean' -Icon 'E74D' -Risk 'safe' -Run 'inline' `
        -Name 'Liberador de espacio automatico' -Desc 'Ejecuta cleanmgr con todas las categorias seguras preseleccionadas' -Code @'
HR "LIBERADOR DE ESPACIO DE WINDOWS"
$base = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$cats = @(
  "Active Setup Temp Folders","BranchCache","Downloaded Program Files","Internet Cache Files",
  "Old ChkDsk Files","Previous Installations","Recycle Bin","RetailDemo Offline Content",
  "Setup Log Files","System error memory dump files","System error minidump files",
  "Temporary Files","Temporary Setup Files","Thumbnail Cache","Update Cleanup",
  "Upgrade Discarded Files","Windows Defender","Windows Error Reporting Files",
  "Delivery Optimization Files","Device Driver Packages","Feedback Hub Archive log files"
)
Step "Marcando categorias en el perfil 77"
$n = 0
foreach ($c in $cats) {
    $k = Join-Path $base $c
    if (Test-Path $k) { Set-ItemProperty -Path $k -Name "StateFlags0077" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue; $n++ }
}
OK "$n categorias activadas."
Step "Ejecutando cleanmgr (sin interfaz, puede tardar)"
$p = Start-Process cleanmgr.exe -ArgumentList "/sagerun:77" -PassThru -WindowStyle Hidden
$p.WaitForExit()
OK "Liberador de espacio finalizado."
'@

    T -Id 'clean-restore-old' -Cat 'clean' -Icon 'E792' -Risk 'danger' -Run 'inline' `
        -Name 'Borrar puntos de restauracion viejos' -Desc 'Conserva unicamente el punto mas reciente y libera espacio de instantaneas' -Code @'
HR "PUNTOS DE RESTAURACION"
Step "Puntos actuales"
$pts = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
if ($pts) { $pts | ForEach-Object { ROW ("#" + $_.SequenceNumber) "$($_.Description)  $($_.ConvertToDateTime($_.CreationTime))" } }
else { INFO "No hay puntos de restauracion." }
Step "Espacio usado por instantaneas"
vssadmin list shadowstorage
Step "Eliminando todos menos el mas reciente"
vssadmin delete shadows /for=$env:SystemDrive /oldest
$null = vssadmin delete shadows /for=$env:SystemDrive /all /quiet 2>$null
Step "Limitando el espacio de instantaneas al 5%"
vssadmin resize shadowstorage /for=$env:SystemDrive /on=$env:SystemDrive /maxsize=5%
OK "Listo. Recuerda crear un punto nuevo."
'@

    T -Id 'clean-downloads-old' -Cat 'clean' -Icon 'E896' -Risk 'danger' -Run 'inline' `
        -Name 'Descargas de mas de 90 dias' -Desc 'Lista primero lo que va a borrar de la carpeta Descargas y luego lo elimina' -Code @'
HR "CARPETA DESCARGAS"
$d = "$env:USERPROFILE\Downloads"
if (-not (Test-Path $d)) { WARN "No existe $d"; return }
$lim = (Get-Date).AddDays(-90)
$old = Get-ChildItem $d -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $lim }
if (-not $old) { OK "No hay archivos con mas de 90 dias."; return }
$sz = ($old | Measure-Object Length -Sum).Sum
WARN "Se eliminaran $($old.Count) archivos ($(Human $sz)):"
$old | Sort-Object Length -Descending | Select-Object -First 30 | ForEach-Object { ROW $_.Name ("$(Human $_.Length)   $($_.LastWriteTime.ToString('dd/MM/yyyy'))") }
$f = Join-Path (BSDir "reportes") ("descargas_borradas_" + (Stamp) + ".csv")
$old | Select-Object Name, Length, LastWriteTime, FullName | Export-Csv $f -NoTypeInformation -Encoding UTF8
INFO "Listado guardado en $f"
$old | Remove-Item -Force -ErrorAction SilentlyContinue
OK ((Human $sz) + " liberados de Descargas.")
'@

    T -Id 'clean-space-report' -Cat 'clean' -Icon 'EB05' -Risk 'safe' -Run 'inline' `
        -Name 'Que se esta comiendo el disco' -Desc 'Ranking de las 30 carpetas y los 30 archivos mas pesados del disco' -Code @'
HR "ANALISIS DE ESPACIO EN DISCO"
Get-Volume | Where-Object DriveLetter | ForEach-Object {
    if ($_.Size -gt 0) {
        $pct = [math]::Round((($_.Size - $_.SizeRemaining) / $_.Size) * 100, 1)
        ROW "$($_.DriveLetter): $($_.FileSystemLabel)" ("$(Human ($_.Size - $_.SizeRemaining)) usados de $(Human $_.Size)  ($pct%)  libre: $(Human $_.SizeRemaining)")
    }
}
Step "Calculando carpetas de primer y segundo nivel (paciencia)"
$res = @()
foreach ($raiz in @("$env:SystemDrive\", "$env:USERPROFILE", "$env:ProgramData", "${env:ProgramFiles}", "${env:ProgramFiles(x86)}", "$env:LOCALAPPDATA", "$env:APPDATA")) {
    if (-not (Test-Path $raiz)) { continue }
    Get-ChildItem $raiz -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $s = Get-Folder-Size $_.FullName
        if ($s -gt 300MB) { $res += [pscustomobject]@{ Ruta = $_.FullName; Bytes = $s } }
    }
}
Step "Top 30 carpetas"
$res | Sort-Object Bytes -Descending | Select-Object -First 30 -Unique | ForEach-Object { ROW $_.Ruta (Human $_.Bytes) }

Step "Top 30 archivos sueltos mas grandes del perfil"
Get-ChildItem $env:USERPROFILE -File -Recurse -Force -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending | Select-Object -First 30 |
    ForEach-Object { ROW $_.Name ("$(Human $_.Length)  ->  $($_.DirectoryName)") }

$f = Join-Path (BSDir "reportes") ("espacio_" + (Stamp) + ".csv")
$res | Sort-Object Bytes -Descending | Select-Object Ruta, @{n="Tamano";e={Human $_.Bytes}}, Bytes | Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "Reporte: $f"
'@

    T -Id 'clean-hiberfil' -Cat 'clean' -Icon 'E945' -Risk 'care' -Run 'inline' `
        -Name 'Desactivar hibernacion' -Desc 'Elimina hiberfil.sys y libera un espacio igual a la RAM instalada' -Code @'
HR "HIBERNACION"
$hf = "$env:SystemDrive\hiberfil.sys"
$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
INFO ("RAM instalada: " + (Human $ram))
powercfg /hibernate off
Start-Sleep -Seconds 2
if (Test-Path $hf) { WARN "hiberfil.sys sigue presente; puede requerir reinicio." }
else { OK ("Hibernacion desactivada. Se liberan aproximadamente " + (Human ($ram * 0.75)) + ".") }
WARN "Al desactivar la hibernacion tambien se desactiva el Inicio rapido."
'@ -Revert @'
powercfg /hibernate on
OK "Hibernacion reactivada."
'@

    T -Id 'clean-eventlogs' -Cat 'clean' -Icon 'E8F1' -Risk 'care' -Run 'inline' `
        -Name 'Vaciar registros de eventos' -Desc 'Limpia el Visor de eventos para partir de cero en un diagnostico' -Code @'
HR "REGISTROS DE EVENTOS"
$logs = wevtutil.exe el
INFO "$($logs.Count) registros encontrados."
$n = 0
foreach ($l in $logs) {
    try { wevtutil.exe cl "$l" 2>$null; $n++ } catch { }
}
OK "$n registros vaciados."
'@

    T -Id 'clean-all-users-temp' -Cat 'clean' -Icon 'E77B' -Risk 'care' -Run 'inline' `
        -Name 'Temporales de todos los perfiles' -Desc 'Recorre cada usuario del equipo y limpia sus temporales y cache' -Code @'
HR "LIMPIEZA MULTIUSUARIO"
$tot = 0
Get-ChildItem "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @("Public","Default","Default User","All Users") } | ForEach-Object {
    Step "Perfil: $($_.Name)"
    $tot += Purge-Folder "$($_.FullName)\AppData\Local\Temp" "  Temp"
    $tot += Purge-Folder "$($_.FullName)\AppData\Local\Microsoft\Windows\INetCache" "  INetCache"
    $tot += Purge-Folder "$($_.FullName)\AppData\Local\Microsoft\Windows\WebCache" "  WebCache"
    $tot += Purge-Folder "$($_.FullName)\AppData\Local\CrashDumps" "  CrashDumps"
}
HR ("TOTAL LIBERADO: " + (Human $tot))
'@

    T -Id 'clean-ram' -Cat 'clean' -Icon 'E964' -Risk 'safe' -Run 'inline' `
        -Name 'Liberar RAM en espera' -Desc 'Vacia la standby list con RAMMap de Sysinternals y muestra el antes/despues' -Code @'
HR "MEMORIA RAM"
$os = Get-CimInstance Win32_OperatingSystem
$antes = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
ROW "RAM total" (Human ($os.TotalVisibleMemorySize * 1KB))
ROW "En uso (antes)" (Human $antes)

Step "Descargando RAMMap"
$base = Join-Path $env:TEMP "ToolboxBS"
$zip = Join-Path $base "RAMMap.zip"
$dir = Join-Path $base "RAMMap"
try {
    Invoke-WebRequest "https://download.sysinternals.com/files/RAMMap.zip" -OutFile $zip -UseBasicParsing -ErrorAction Stop
    Expand-Archive $zip -DestinationPath $dir -Force
    $exe = Get-ChildItem $dir -Filter "RAMMap*.exe" | Select-Object -First 1
    if ($exe) {
        Step "Vaciando listas de memoria"
        foreach ($sw in @("-Ew","-Et","-Em","-E0")) {
            Start-Process $exe.FullName -ArgumentList $sw -Wait -ErrorAction SilentlyContinue
        }
        OK "Standby list, working sets y memoria modificada liberados."
    } else { ERR "No se encontro RAMMap.exe" }
} catch { ERR "Fallo la descarga: $($_.Exception.Message)" }

Start-Sleep -Seconds 2
$os = Get-CimInstance Win32_OperatingSystem
$despues = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
ROW "En uso (despues)" (Human $despues)
$dif = $antes - $despues
if ($dif -gt 0) { OK ("Liberados " + (Human $dif)) } else { INFO "Sin cambio significativo (el sistema ya estaba optimo)." }

Step "Top 15 procesos por memoria"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 |
    ForEach-Object { ROW $_.ProcessName (Human $_.WorkingSet64) }
'@

    T -Id 'clean-dupes' -Cat 'clean' -Icon 'E8C8' -Risk 'safe' -Run 'inline' `
        -Name 'Buscar archivos duplicados' -Desc 'Reporta duplicados grandes en el perfil de usuario. Solo informa, no borra nada' -Code @'
HR "BUSQUEDA DE DUPLICADOS"
INFO "Analizando archivos de mas de 10 MB en $env:USERPROFILE ..."
$files = Get-ChildItem $env:USERPROFILE -File -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 10MB -and $_.FullName -notmatch "\\AppData\\" }
INFO "$($files.Count) archivos candidatos."

$porTam = $files | Group-Object Length | Where-Object Count -gt 1
INFO "$($porTam.Count) grupos con el mismo tamano. Calculando hashes..."

$dup = @()
foreach ($g in $porTam) {
    $h = $g.Group | ForEach-Object {
        try { [pscustomobject]@{ F = $_; H = (Get-FileHash $_.FullName -Algorithm MD5 -ErrorAction Stop).Hash } } catch { }
    }
    $h | Group-Object H | Where-Object Count -gt 1 | ForEach-Object { $dup += , $_.Group }
}

if (-not $dup) { OK "No se encontraron duplicados."; return }
$desperdicio = 0
foreach ($grupo in $dup) {
    Step ("Duplicado (" + (Human $grupo[0].F.Length) + " x " + $grupo.Count + ")")
    $grupo | ForEach-Object { Write-Host ("    " + $_.F.FullName) }
    $desperdicio += $grupo[0].F.Length * ($grupo.Count - 1)
}
HR ("ESPACIO RECUPERABLE: " + (Human $desperdicio))
$f = Join-Path (BSDir "reportes") ("duplicados_" + (Stamp) + ".csv")
$dup | ForEach-Object { $_ } | Select-Object @{n="Hash";e={$_.H}}, @{n="Ruta";e={$_.F.FullName}}, @{n="Bytes";e={$_.F.Length}} | Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "Reporte: $f  (revisa antes de borrar nada)"
'@
)

# ------------------------- RENDIMIENTO Y SEGURIDAD -------------------------
$Global:Catalog += @(

    T -Id 'perf-ultimate' -Cat 'perf' -Icon 'E945' -Risk 'safe' -Run 'inline' `
        -Name 'Plan de energia maximo' -Desc 'Activa Rendimiento maximo y desactiva el ahorro que frena la CPU' -Code @'
HR "PLAN DE ENERGIA"
Step "Planes disponibles"
powercfg /list
Step "Creando el plan Rendimiento maximo"
$out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
$guid = ([regex]::Match(($out -join " "), "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})")).Value
if (-not $guid) {
    WARN "No se pudo duplicar el plan oculto; se usara Alto rendimiento."
    $guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    powercfg -duplicatescheme $guid | Out-Null
}
powercfg /setactive $guid
OK "Plan activo: $guid"
Step "Quitando limites de CPU y suspension de disco"
powercfg /setacvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setacvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg /setacvalueindex $guid SUB_DISK DISKIDLE 0
powercfg /setacvalueindex $guid SUB_SLEEP STANDBYIDLE 0
powercfg /setacvalueindex $guid SUB_VIDEO VIDEOIDLE 0
powercfg /setactive $guid
OK "Energia optimizada para rendimiento (en portatiles reduce la autonomia)."
powercfg /getactivescheme
'@ -Revert @'
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
OK "Plan Equilibrado restaurado."
'@

    T -Id 'perf-visual' -Cat 'perf' -Icon 'E790' -Risk 'safe' -Run 'inline' `
        -Name 'Efectos visuales a rendimiento' -Desc 'Quita animaciones, sombras y transparencias manteniendo las fuentes suavizadas' -Code @'
HR "EFECTOS VISUALES"
Backup-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "visualfx"
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
Set-Reg "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"
Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
OK "Efectos reducidos. Cierra sesion para verlos aplicados por completo."
'@ -Revert @'
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1
Set-Reg "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 1
OK "Efectos visuales devueltos al valor automatico."
'@

    T -Id 'perf-startup' -Cat 'perf' -Icon 'E945' -Risk 'safe' -Run 'inline' `
        -Name 'Auditar programas de inicio' -Desc 'Muestra todo lo que arranca con Windows y su impacto medido' -Code @'
HR "PROGRAMAS DE INICIO"
Step "Entradas del registro"
$claves = @(
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)
foreach ($k in $claves) {
    if (-not (Test-Path $k)) { continue }
    Step $k
    $p = Get-ItemProperty $k
    $p.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object { ROW $_.Name $_.Value }
}
Step "Carpetas de Inicio"
foreach ($c in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
    Get-ChildItem $c -ErrorAction SilentlyContinue | ForEach-Object { ROW $_.Name $c }
}
Step "Estado y coste medido por Windows"
$sa = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
if (Test-Path $sa) {
    (Get-ItemProperty $sa).PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
        $estado = if ($_.Value[0] -band 1) { "DESACTIVADO" } else { "activo" }
        ROW $_.Name $estado
    }
}
Step "Tareas programadas que corren al iniciar sesion"
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Ready" -and $_.Triggers.CimClass.CimClassName -match "Logon|Boot" } |
    Select-Object -First 25 | ForEach-Object { ROW $_.TaskName $_.TaskPath }
INFO "Para desactivar entradas: Administrador de tareas > pestana Inicio."
Start-Process "taskmgr.exe" -ArgumentList "/7"
'@

    T -Id 'perf-services' -Cat 'perf' -Icon 'E713' -Risk 'danger' -Run 'inline' `
        -Name 'Optimizar servicios' -Desc 'Pasa a manual los servicios prescindibles. Respalda antes y es reversible' -Code @'
HR "OPTIMIZACION DE SERVICIOS"
$svc = @{
  "DiagTrack"                = "Telemetria de experiencia del usuario"
  "dmwappushservice"         = "Enrutamiento de mensajes WAP"
  "MapsBroker"               = "Descarga de mapas sin conexion"
  "RetailDemo"               = "Modo demostracion de tienda"
  "RemoteRegistry"           = "Registro remoto (riesgo de seguridad)"
  "PcaSvc"                   = "Asistente de compatibilidad"
  "WMPNetworkSvc"            = "Uso compartido de Windows Media"
  "XblAuthManager"           = "Xbox Live autenticacion"
  "XblGameSave"              = "Xbox Live guardado"
  "XboxNetApiSvc"            = "Xbox Live red"
  "XboxGipSvc"               = "Accesorios Xbox"
  "Fax"                      = "Fax"
  "WerSvc"                   = "Informe de errores de Windows"
  "SharedAccess"             = "Conexion compartida a Internet"
  "lfsvc"                    = "Servicio de geolocalizacion"
}
$respaldo = @{}
foreach ($n in $svc.Keys) {
    $s = Get-Service $n -ErrorAction SilentlyContinue
    if (-not $s) { INFO "No existe: $n"; continue }
    $modo = (Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue).StartMode
    $respaldo[$n] = $modo
    try {
        Stop-Service $n -Force -ErrorAction SilentlyContinue
        Set-Service $n -StartupType Manual -ErrorAction Stop
        OK "$n -> Manual  ($($svc[$n]))  [antes: $modo]"
    } catch { WARN "No se pudo cambiar $n : $($_.Exception.Message)" }
}
$f = Join-Path (BSDir "backups") ("servicios_" + (Stamp) + ".json")
$respaldo | ConvertTo-Json | Set-Content $f -Encoding UTF8
OK "Estado anterior respaldado en $f"
WARN "Si usas Xbox Game Pass o mapas sin conexion, revierte esta optimizacion."
'@ -Revert @'
HR "RESTAURAR SERVICIOS"
$f = Get-ChildItem (BSDir "backups") -Filter "servicios_*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $f) { ERR "No hay respaldo de servicios."; return }
$m = Get-Content $f.FullName -Raw | ConvertFrom-Json
$m.PSObject.Properties | ForEach-Object {
    $tipo = switch ($_.Value) { "Auto" { "Automatic" } "Manual" { "Manual" } "Disabled" { "Disabled" } default { "Manual" } }
    try { Set-Service $_.Name -StartupType $tipo -ErrorAction Stop; OK "$($_.Name) -> $tipo" } catch { WARN $_.Name }
}
'@

    T -Id 'perf-sysmain' -Cat 'perf' -Icon 'E964' -Risk 'care' -Run 'inline' `
        -Name 'Ajustar SysMain y Prefetch' -Desc 'Los desactiva solo si el disco de sistema es SSD, donde no aportan nada' -Code @'
HR "SYSMAIN / SUPERFETCH"
$disco = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq 0 -or $_.IsBoot }
$tipo = if ($disco) { ($disco | Select-Object -First 1).MediaType } else { "Desconocido" }
ROW "Disco de sistema" $tipo
if ($tipo -eq "HDD") {
    WARN "El disco es mecanico: SysMain SI ayuda. No se desactiva nada."
    return
}
Step "SSD detectado, desactivando precarga innecesaria"
try { Stop-Service SysMain -Force -ErrorAction SilentlyContinue; Set-Service SysMain -StartupType Disabled -ErrorAction Stop; OK "SysMain desactivado." } catch { WARN "SysMain: $($_.Exception.Message)" }
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0
OK "Prefetch y Superfetch desactivados (correcto en SSD)."
'@ -Revert @'
Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service SysMain -ErrorAction SilentlyContinue
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 3
OK "SysMain y Prefetch restaurados."
'@

    T -Id 'perf-trim' -Cat 'perf' -Icon 'E958' -Risk 'safe' -Run 'inline' `
        -Name 'Optimizar unidades (TRIM)' -Desc 'Lanza TRIM en SSD y desfragmentacion en discos mecanicos' -Code @'
HR "OPTIMIZACION DE UNIDADES"
Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
    ROW $_.FriendlyName "$($_.MediaType)  $(Human $_.Size)  salud: $($_.HealthStatus)"
}
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" } | ForEach-Object {
    $l = $_.DriveLetter
    Step "Unidad ${l}:"
    try {
        Optimize-Volume -DriveLetter $l -ReTrim -Verbose -ErrorAction Stop 4>&1 | ForEach-Object { Write-Host "    $_" }
        OK "Unidad ${l}: optimizada."
    } catch {
        try { Optimize-Volume -DriveLetter $l -Defrag -ErrorAction Stop; OK "Unidad ${l}: desfragmentada." }
        catch { WARN "Unidad ${l}: $($_.Exception.Message)" }
    }
}
'@

    T -Id 'perf-telemetry' -Cat 'perf' -Icon 'E72E' -Risk 'care' -Run 'inline' `
        -Name 'Reducir telemetria' -Desc 'Desactiva el envio de diagnosticos, publicidad y sugerencias' -Code @'
HR "TELEMETRIA Y PUBLICIDAD"
Backup-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "telemetria"
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

Step "Servicios y tareas de telemetria"
foreach ($s in @("DiagTrack","dmwappushservice")) {
    try { Stop-Service $s -Force -ErrorAction SilentlyContinue; Set-Service $s -StartupType Disabled -ErrorAction Stop; OK "$s desactivado" } catch { WARN $s }
}
foreach ($t in @("\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                 "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
                 "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                 "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                 "\Microsoft\Windows\Feedback\Siuf\DmClient")) {
    try { Disable-ScheduledTask -TaskPath (Split-Path $t) -TaskName (Split-Path $t -Leaf) -ErrorAction Stop | Out-Null; OK "Tarea desactivada: $(Split-Path $t -Leaf)" }
    catch { INFO "No presente: $(Split-Path $t -Leaf)" }
}
OK "Telemetria reducida."
'@ -Revert @'
Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 1
Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue
OK "Telemetria devuelta a los valores de Windows."
'@

    T -Id 'perf-bloat' -Cat 'perf' -Icon 'E74D' -Risk 'danger' -Run 'inline' `
        -Name 'Quitar apps preinstaladas' -Desc 'Elimina bloatware de fabrica. No toca la Store, Terminal, Calculadora ni Fotos' -Code @'
HR "ELIMINACION DE BLOATWARE"
$quitar = @(
  "Microsoft.3DBuilder","Microsoft.BingFinance","Microsoft.BingNews","Microsoft.BingSports",
  "Microsoft.BingWeather","Microsoft.GetHelp","Microsoft.Getstarted","Microsoft.Messaging",
  "Microsoft.Microsoft3DViewer","Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftSolitaireCollection",
  "Microsoft.MixedReality.Portal","Microsoft.NetworkSpeedTest","Microsoft.Office.OneNote",
  "Microsoft.OneConnect","Microsoft.People","Microsoft.Print3D","Microsoft.SkypeApp",
  "Microsoft.Wallet","Microsoft.WindowsAlarms","Microsoft.WindowsFeedbackHub",
  "Microsoft.WindowsMaps","Microsoft.WindowsSoundRecorder","Microsoft.Xbox.TCUI",
  "Microsoft.XboxApp","Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay",
  "Microsoft.XboxIdentityProvider","Microsoft.XboxSpeechToTextOverlay","Microsoft.YourPhone",
  "Microsoft.ZuneMusic","Microsoft.ZuneVideo","MicrosoftTeams","Clipchamp.Clipchamp",
  "Microsoft.Todos","Microsoft.PowerAutomateDesktop","MicrosoftCorporationII.QuickAssist"
)
$proteger = @("Microsoft.WindowsStore","Microsoft.WindowsTerminal","Microsoft.WindowsCalculator",
              "Microsoft.Windows.Photos","Microsoft.WindowsNotepad","Microsoft.Paint",
              "Microsoft.ScreenSketch","Microsoft.WindowsCamera","Microsoft.SecHealthUI",
              "Microsoft.DesktopAppInstaller","Microsoft.UI.Xaml","Microsoft.VCLibs","Microsoft.NET")
$n = 0
foreach ($a in $quitar) {
    if ($proteger -contains $a) { continue }
    $pk = Get-AppxPackage -Name $a -AllUsers -ErrorAction SilentlyContinue
    if ($pk) {
        try { $pk | Remove-AppxPackage -AllUsers -ErrorAction Stop; OK "Eliminada: $a"; $n++ }
        catch { WARN "No se pudo eliminar $a" }
    }
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -eq $a
    if ($prov) {
        try { Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null; OK "Desaprovisionada: $a" }
        catch { }
    }
}
OK "$n aplicaciones eliminadas. Se pueden reinstalar desde la Microsoft Store."
'@

    T -Id 'perf-widgets' -Cat 'perf' -Icon 'E8EF' -Risk 'care' -Run 'inline' `
        -Name 'Quitar Widgets, Chat y Copilot' -Desc 'Limpia la barra de tareas de Windows 11 y libera memoria en segundo plano' -Code @'
HR "BARRA DE TAREAS DE WINDOWS 11"
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-Reg $adv "TaskbarDa" 0        # Widgets
Set-Reg $adv "TaskbarMn" 0        # Chat
Set-Reg $adv "ShowCopilotButton" 0
Set-Reg $adv "TaskbarAl" 0        # Iconos a la izquierda
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" "ShellFeedsTaskbarViewMode" 2
Step "Desinstalando el paquete de Widgets"
Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
OK "Barra de tareas simplificada."
'@ -Revert @'
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-Reg $adv "TaskbarDa" 1
Set-Reg $adv "TaskbarMn" 1
Set-Reg $adv "ShowCopilotButton" 1
Set-Reg $adv "TaskbarAl" 1
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
OK "Barra de tareas restaurada."
'@

    T -Id 'perf-context' -Cat 'perf' -Icon 'E70F' -Risk 'safe' -Run 'inline' `
        -Name 'Menu contextual clasico' -Desc 'Devuelve el clic derecho completo de Windows 10 en Windows 11' -Code @'
HR "MENU CONTEXTUAL CLASICO"
$k = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
New-Item -Path $k -Force | Out-Null
Set-ItemProperty -Path $k -Name "(Default)" -Value "" -Force
OK "Menu clasico activado."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
'@ -Revert @'
Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
OK "Menu contextual de Windows 11 restaurado."
'@

    T -Id 'perf-explorer-tweaks' -Cat 'perf' -Icon 'E8B7' -Risk 'safe' -Run 'inline' `
        -Name 'Explorador para tecnicos' -Desc 'Extensiones visibles, archivos ocultos, ruta completa y abrir en Este equipo' -Code @'
HR "AJUSTES DEL EXPLORADOR"
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-Reg $adv "HideFileExt" 0
Set-Reg $adv "Hidden" 1
Set-Reg $adv "ShowSuperHidden" 0
Set-Reg $adv "LaunchTo" 1
Set-Reg $adv "SeparateProcess" 1
Set-Reg $adv "NavPaneExpandToCurrentFolder" 1
Set-Reg $adv "NavPaneShowAllFolders" 1
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" "FullPath" 1
OK "Explorador configurado para trabajo tecnico."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
'@

    T -Id 'perf-gaming' -Cat 'perf' -Icon 'E7FC' -Risk 'care' -Run 'inline' `
        -Name 'Optimizacion para juegos' -Desc 'Desactiva GameDVR, activa GPU scheduling y prioriza tareas graficas' -Code @'
HR "OPTIMIZACION DE JUEGOS"
Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
Set-Reg "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 0
Step "Planificacion de GPU acelerada por hardware"
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
Step "Prioridad de tareas multimedia"
$mm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-Reg $mm "SystemResponsiveness" 10
Set-Reg $mm "NetworkThrottlingIndex" 4294967295
Set-Reg "$mm\Tasks\Games" "GPU Priority" 8
Set-Reg "$mm\Tasks\Games" "Priority" 6
Set-Reg "$mm\Tasks\Games" "Scheduling Category" "High" "String"
OK "Ajustes de juego aplicados. Reinicia para que la planificacion de GPU tome efecto."
'@ -Revert @'
Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 1
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 20
OK "Ajustes de juego revertidos."
'@

    T -Id 'perf-net-tweaks' -Cat 'perf' -Icon 'E839' -Risk 'care' -Run 'inline' `
        -Name 'Afinar pila de red' -Desc 'Quita el throttling, aplica CTCP y reduce latencia de Nagle' -Code @'
HR "AJUSTES DE RED"
Backup-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "red_throttling"
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295
Step "Proveedor de congestion y auto-tuning"
netsh int tcp set supplemental template=internet congestionprovider=ctcp
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global ecncapability=enabled
netsh int tcp set global rss=enabled
Step "Desactivando el algoritmo de Nagle en cada interfaz"
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
    Set-ItemProperty $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
}
OK "Nagle desactivado en todas las interfaces."
Step "Estado global de TCP"
netsh int tcp show global
'@ -Revert @'
netsh int tcp set global autotuninglevel=normal
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-ItemProperty $_.PSPath -Name "TcpAckFrequency","TCPNoDelay" -Force -ErrorAction SilentlyContinue
}
OK "Pila de red devuelta a los valores por defecto."
'@

    T -Id 'perf-boot' -Cat 'perf' -Icon 'E7E8' -Risk 'care' -Run 'inline' `
        -Name 'Acelerar el arranque' -Desc 'Reduce el tiempo de espera del gestor y quita retardos de inicio de sesion' -Code @'
HR "ARRANQUE"
Step "Configuracion actual"
bcdedit /enum "{current}" | Select-String "timeout|bootmenupolicy|description"
Step "Aplicando"
bcdedit /timeout 3
bcdedit /set "{current}" bootmenupolicy Standard
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" 0
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown" 0
Step "Inicio rapido"
$hib = powercfg /a
if ($hib -match "Hibernaci|Hibernat") {
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1
    OK "Inicio rapido habilitado."
} else { INFO "La hibernacion esta desactivada; el Inicio rapido no aplica." }
OK "Arranque optimizado."
'@

    T -Id 'perf-winutil' -Cat 'perf' -Icon 'E7B8' -Risk 'care' -Run 'term' `
        -Name 'Chris Titus WinUtil' -Desc 'Lanza la utilidad de la comunidad para tweaks avanzados' -Code @'
HR "CHRIS TITUS WINUTIL"
INFO "Descargando y ejecutando christitus.com/win ..."
Invoke-Expression (Invoke-RestMethod -Uri "https://christitus.com/win")
'@

    T -Id 'perf-perfbat' -Cat 'perf' -Icon 'E9E9' -Risk 'care' -Run 'term' `
        -Name 'Performance.bat (BS)' -Desc 'Script propio de optimizacion de rendimiento del repositorio ToolboxBS' -Code @'
HR "PERFORMANCE BAT"
$dst = Join-Path $env:TEMP "ToolboxBS"
if (-not (Test-Path $dst)) { New-Item $dst -ItemType Directory -Force | Out-Null }
$f = Join-Path $dst "performance.bat"
try {
    Invoke-WebRequest "https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/performance.bat" -OutFile $f -UseBasicParsing -ErrorAction Stop
    OK "Descargado: $f"
    Start-Process cmd.exe -ArgumentList "/c", "`"$f`"" -Wait
    OK "Ejecucion finalizada."
} catch { ERR "No se pudo descargar: $($_.Exception.Message)" }
'@

    T -Id 'perf-update-apps' -Cat 'perf' -Icon 'E895' -Risk 'safe' -Run 'term' `
        -Name 'Actualizar todo el software' -Desc 'winget upgrade --all, incluyendo paquetes de version desconocida' -Code @'
HR "ACTUALIZACION DE SOFTWARE"
if (-not (Need-Winget)) { return }
Step "Paquetes con actualizacion disponible"
winget upgrade --include-unknown
Step "Actualizando"
winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements
OK "Proceso terminado."
'@

    T -Id 'perf-install-winget' -Cat 'perf' -Icon 'E710' -Risk 'safe' -Run 'inline' `
        -Name 'Instalar o reparar Winget' -Desc 'Instala el Instalador de aplicaciones y sus dependencias sin pasar por la Store' -Code @'
HR "WINGET"
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    OK "winget ya esta instalado: $(winget --version)"
    Step "Reparando fuentes"
    winget source reset --force
    winget source update
    return
}
Step "Descargando el paquete oficial"
$tmp = Join-Path $env:TEMP "ToolboxBS"
if (-not (Test-Path $tmp)) { New-Item $tmp -ItemType Directory -Force | Out-Null }
try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
    $url = ($rel.assets | Where-Object { $_.name -like "*.msixbundle" }).browser_download_url
    $f = Join-Path $tmp "winget.msixbundle"
    Invoke-WebRequest $url -OutFile $f -UseBasicParsing
    OK "Descargado."
    Step "Instalando dependencias VCLibs y UI.Xaml"
    Add-AppxPackage -Path "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -ErrorAction SilentlyContinue
    Step "Instalando winget"
    Add-AppxPackage -Path $f -ErrorAction Stop
    OK "winget instalado. Cierra y vuelve a abrir ToolboxBS."
} catch {
    ERR "Fallo la instalacion automatica: $($_.Exception.Message)"
    INFO "Abriendo la Microsoft Store como alternativa."
    Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
}
'@

    T -Id 'perf-activate' -Cat 'perf' -Icon 'E8D7' -Risk 'care' -Run 'inline' `
        -Name 'Activar con licencia OEM' -Desc 'Recupera la clave grabada en el BIOS y reactiva Windows con ella' -Code @'
HR "ACTIVACION CON CLAVE OEM"
Step "Estado actual"
$lic = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction SilentlyContinue
foreach ($l in $lic) {
    $estado = switch ($l.LicenseStatus) { 0 {"Sin licencia"} 1 {"ACTIVADO"} 2 {"Periodo de gracia"} 3 {"Gracia extra"} 4 {"Gracia por no genuino"} 5 {"Notificacion"} default {"Desconocido"} }
    ROW $l.Name $estado
    ROW "  Canal" $l.ProductKeyChannel
}
Step "Clave OEM del firmware"
$key = (Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey
if (-not $key) {
    WARN "Este equipo no tiene clave OEM grabada en el BIOS (habitual en equipos ensamblados o con licencia por cuenta Microsoft)."
    return
}
OK "Clave encontrada: $key"
Step "Instalando y activando"
cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ipk $key
Start-Sleep -Seconds 3
cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ato
Start-Sleep -Seconds 3
cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr
'@

    T -Id 'perf-reboot-bios' -Cat 'perf' -Icon 'E7E8' -Risk 'danger' -Run 'inline' `
        -Name 'Reiniciar a la BIOS/UEFI' -Desc 'Reinicia el equipo directamente en la configuracion de firmware' -Code @'
HR "REINICIO A FIRMWARE"
WARN "El equipo se reiniciara en 10 segundos. Guarda tu trabajo."
for ($i = 10; $i -gt 0; $i--) { Write-Host "    $i..."; Start-Sleep -Seconds 1 }
shutdown /r /fw /t 0
'@

    T -Id 'perf-drivers-oem' -Cat 'perf' -Icon 'E896' -Risk 'safe' -Run 'term' `
        -Name 'Actualizador de drivers OEM' -Desc 'Detecta el fabricante y descarga su utilidad oficial de drivers' -Code @'
HR "DRIVERS DEL FABRICANTE"
$cs = Get-CimInstance Win32_ComputerSystem
ROW "Fabricante" $cs.Manufacturer
ROW "Modelo" $cs.Model
ROW "Serial" (Get-CimInstance Win32_BIOS).SerialNumber
INFO "Ejecutando el actualizador universal de ToolboxBS..."
Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/DriverUpdate-Universal.ps1")
'@

    # ========================= SEGURIDAD =========================
    T -Id 'sec-defender-status' -Cat 'sec' -Icon 'EA18' -Risk 'safe' -Run 'inline' `
        -Name 'Estado de Microsoft Defender' -Desc 'Protecciones activas, firmas, exclusiones y amenazas detectadas' -Code @'
HR "MICROSOFT DEFENDER"
$s = Get-MpComputerStatus -ErrorAction SilentlyContinue
if (-not $s) { ERR "No se pudo consultar Defender (puede estar reemplazado por otro antivirus)."; }
else {
    ROW "Antivirus habilitado" $s.AntivirusEnabled
    ROW "Proteccion en tiempo real" $s.RealTimeProtectionEnabled
    ROW "Proteccion en la nube" $s.AMServiceEnabled
    ROW "Antispyware" $s.AntispywareEnabled
    ROW "Proteccion contra manipulaciones" $s.IsTamperProtected
    ROW "Version de firmas" $s.AntivirusSignatureVersion
    ROW "Firmas actualizadas" $s.AntivirusSignatureLastUpdated
    ROW "Antiguedad de firmas" "$($s.AntivirusSignatureAge) dias"
    ROW "Ultimo examen rapido" $s.QuickScanEndTime
    ROW "Ultimo examen completo" $s.FullScanEndTime
    if ($s.AntivirusSignatureAge -gt 3) { WARN "Las firmas tienen mas de 3 dias." }
    if (-not $s.RealTimeProtectionEnabled) { ERR "LA PROTECCION EN TIEMPO REAL ESTA APAGADA." }
}
Step "Antivirus registrados en el Centro de seguridad"
Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue |
    ForEach-Object { ROW $_.displayName $_.pathToSignedProductExe }

Step "Exclusiones configuradas"
$pref = Get-MpPreference -ErrorAction SilentlyContinue
if ($pref) {
    if ($pref.ExclusionPath) { $pref.ExclusionPath | ForEach-Object { WARN "Ruta excluida: $_" } } else { OK "Sin rutas excluidas." }
    if ($pref.ExclusionProcess) { $pref.ExclusionProcess | ForEach-Object { WARN "Proceso excluido: $_" } }
}
Step "Amenazas detectadas historicamente"
$th = Get-MpThreatDetection -ErrorAction SilentlyContinue | Sort-Object InitialDetectionTime -Descending | Select-Object -First 15
if ($th) { $th | ForEach-Object { ERR "$($_.InitialDetectionTime)  $($_.ThreatID)  accion: $($_.ActionSuccess)" } }
else { OK "Sin amenazas registradas." }
'@

    T -Id 'sec-defender-scan' -Cat 'sec' -Icon 'E721' -Risk 'safe' -Run 'inline' `
        -Name 'Examen rapido de Defender' -Desc 'Actualiza firmas y ejecuta un analisis rapido de las zonas criticas' -Code @'
HR "EXAMEN RAPIDO"
Step "Actualizando firmas"
Update-MpSignature -ErrorAction SilentlyContinue
OK "Firmas: $((Get-MpComputerStatus).AntivirusSignatureVersion)"
Step "Analizando"
Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue
OK "Examen rapido finalizado."
Step "Resultado"
$th = Get-MpThreat -ErrorAction SilentlyContinue | Where-Object { $_.IsActive }
if ($th) { $th | ForEach-Object { ERR "AMENAZA ACTIVA: $($_.ThreatName)  severidad $($_.SeverityID)" } }
else { OK "Sin amenazas activas." }
'@

    T -Id 'sec-defender-full' -Cat 'sec' -Icon 'EA18' -Risk 'safe' -Run 'term' `
        -Name 'Examen completo de Defender' -Desc 'Analisis exhaustivo de todo el disco. Puede tardar horas' -Code @'
HR "EXAMEN COMPLETO"
Update-MpSignature -ErrorAction SilentlyContinue
INFO "Iniciando analisis completo. Puedes seguir usando el equipo."
Start-MpScan -ScanType FullScan
OK "Analisis completo finalizado."
Get-MpThreat -ErrorAction SilentlyContinue | Format-Table ThreatName, SeverityID, IsActive -AutoSize | Out-String | Write-Host
'@

    T -Id 'sec-malware-tools' -Cat 'sec' -Icon 'E730' -Risk 'care' -Run 'inline' `
        -Name 'Herramientas antimalware' -Desc 'Descarga ADWCleaner de Malwarebytes y el escaner KVRT de Kaspersky' -Code @'
HR "HERRAMIENTAS ANTIMALWARE DE SEGUNDA OPINION"
$dst = BSDir "herramientas"
$tools = @(
    @{n="ADWCleaner"; u="https://downloads.malwarebytes.com/file/adwcleaner"; f="adwcleaner.exe"},
    @{n="KVRT (Kaspersky)"; u="https://devbuilds.s.kaspersky-labs.com/devbuilds/KVRT/latest/full/KVRT.exe"; f="KVRT.exe"}
)
foreach ($t in $tools) {
    Step $t.n
    $p = Join-Path $dst $t.f
    try {
        Invoke-WebRequest $t.u -OutFile $p -UseBasicParsing -ErrorAction Stop
        OK "Descargado: $p"
    } catch { ERR "$($t.n): $($_.Exception.Message)" }
}
INFO "Ejecuta las herramientas manualmente desde: $dst"
Start-Process explorer.exe $dst
'@

    T -Id 'sec-bitlocker' -Cat 'sec' -Icon 'E72E' -Risk 'safe' -Run 'inline' `
        -Name 'BitLocker y claves de recuperacion' -Desc 'Estado del cifrado y exporta las claves antes de que sea tarde' -Code @'
HR "BITLOCKER"
$vols = Get-BitLockerVolume -ErrorAction SilentlyContinue
if (-not $vols) { WARN "BitLocker no disponible en esta edicion de Windows."; return }
$lineas = @()
foreach ($v in $vols) {
    ROW "$($v.MountPoint)" "$($v.VolumeStatus)  |  proteccion: $($v.ProtectionStatus)  |  $($v.EncryptionPercentage)%  |  $($v.EncryptionMethod)"
    foreach ($p in $v.KeyProtector) {
        if ($p.RecoveryPassword) {
            OK "  Clave de recuperacion ($($p.KeyProtectorId)):"
            Write-Host "      $($p.RecoveryPassword)"
            $lineas += "Unidad $($v.MountPoint)  Id $($p.KeyProtectorId)  Clave: $($p.RecoveryPassword)"
        }
    }
}
if ($lineas) {
    $f = Join-Path (BSDir "backups") ("bitlocker_" + $env:COMPUTERNAME + "_" + (Stamp) + ".txt")
    $lineas | Set-Content $f -Encoding UTF8
    OK "Claves guardadas en $f"
    WARN "Ese archivo abre tu disco cifrado. Guardalo fuera del equipo."
} else { INFO "No hay claves de recuperacion (los volumenes no estan cifrados)." }
Step "TPM"
$tpm = Get-Tpm -ErrorAction SilentlyContinue
if ($tpm) { ROW "TPM presente" $tpm.TpmPresent; ROW "TPM listo" $tpm.TpmReady; ROW "TPM habilitado" $tpm.TpmEnabled }
else { INFO "Sin TPM o sin acceso." }
'@

    T -Id 'sec-accounts' -Cat 'sec' -Icon 'E77B' -Risk 'safe' -Run 'inline' `
        -Name 'Auditar cuentas de usuario' -Desc 'Cuentas locales, quien es administrador y contrasenas que nunca expiran' -Code @'
HR "CUENTAS LOCALES"
Get-LocalUser -ErrorAction SilentlyContinue | ForEach-Object {
    $flags = @()
    if (-not $_.Enabled) { $flags += "deshabilitada" }
    if ($_.PasswordRequired -eq $false) { $flags += "SIN CONTRASENA" }
    if ($_.PasswordExpires -eq $null -and $_.Enabled) { $flags += "no expira" }
    ROW $_.Name ("$($_.Description)  [" + ($flags -join ", ") + "]")
    if ($_.PasswordRequired -eq $false -and $_.Enabled) { ERR "  La cuenta $($_.Name) esta activa y sin contrasena." }
}
Step "Miembros del grupo Administradores"
Get-LocalGroupMember -Group "Administradores" -ErrorAction SilentlyContinue | ForEach-Object { ROW $_.Name $_.ObjectClass }
Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | ForEach-Object { ROW $_.Name $_.ObjectClass }
Step "Cuenta Administrador integrada"
$a = Get-LocalUser -Name "Administrador","Administrator" -ErrorAction SilentlyContinue
foreach ($u in $a) { if ($u.Enabled) { WARN "La cuenta integrada $($u.Name) esta HABILITADA." } else { OK "$($u.Name) deshabilitada (correcto)." } }
Step "Politica de contrasenas"
net accounts
'@

    T -Id 'sec-logons' -Cat 'sec' -Icon 'E8A1' -Risk 'safe' -Run 'inline' `
        -Name 'Historial de inicios de sesion' -Desc 'Quien entro, cuando, y cuantos intentos fallidos hubo' -Code @'
HR "INICIOS DE SESION - ULTIMOS 14 DIAS"
$desde = (Get-Date).AddDays(-14)
Step "Sesiones correctas (evento 4624, tipo interactivo)"
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624; StartTime=$desde} -MaxEvents 400 -ErrorAction SilentlyContinue |
    ForEach-Object {
        $x = [xml]$_.ToXml()
        $u = ($x.Event.EventData.Data | Where-Object Name -eq "TargetUserName")."#text"
        $t = ($x.Event.EventData.Data | Where-Object Name -eq "LogonType")."#text"
        if ($t -in @("2","10","11") -and $u -notmatch "\$$|SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-|UMFD-") {
            [pscustomobject]@{ Fecha = $_.TimeCreated; Usuario = $u; Tipo = $t }
        }
    } | Group-Object Usuario | ForEach-Object {
        ROW $_.Name "$($_.Count) inicios  |  ultimo: $(($_.Group | Sort-Object Fecha -Descending)[0].Fecha)"
    }

Step "Intentos fallidos (evento 4625)"
$fail = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=$desde} -MaxEvents 200 -ErrorAction SilentlyContinue
if ($fail) {
    ERR "$($fail.Count) intentos fallidos de inicio de sesion."
    $fail | Select-Object -First 15 | ForEach-Object {
        $x = [xml]$_.ToXml()
        $u = ($x.Event.EventData.Data | Where-Object Name -eq "TargetUserName")."#text"
        $ip = ($x.Event.EventData.Data | Where-Object Name -eq "IpAddress")."#text"
        ROW $_.TimeCreated.ToString("dd/MM HH:mm") "usuario: $u  origen: $ip"
    }
} else { OK "Sin intentos fallidos." }

Step "Bloqueos de cuenta (evento 4740)"
$lock = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740; StartTime=$desde} -ErrorAction SilentlyContinue
if ($lock) { $lock | ForEach-Object { WARN "$($_.TimeCreated) - cuenta bloqueada" } } else { OK "Sin cuentas bloqueadas." }
'@

    T -Id 'sec-autoruns' -Cat 'sec' -Icon 'E7BA' -Risk 'safe' -Run 'inline' `
        -Name 'Cazar persistencias sospechosas' -Desc 'Revisa autoarranques, tareas y servicios con binarios sin firmar o en rutas raras' -Code @'
HR "BUSQUEDA DE PERSISTENCIAS"
function Rara($p) {
    if (-not $p) { return $false }
    return ($p -match "\\AppData\\|\\Temp\\|\\Users\\Public\\|\\ProgramData\\.{0,12}\\[a-z0-9]{6,}\\|\\Downloads\\")
}
Step "Autoarranques en rutas inusuales"
$claves = @(
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)
$hall = 0
foreach ($k in $claves) {
    if (-not (Test-Path $k)) { continue }
    (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
        if (Rara $_.Value) { ERR "SOSPECHOSO  $($_.Name) -> $($_.Value)"; $hall++ }
        else { INFO "$($_.Name)" }
    }
}
Step "Tareas programadas creadas por terceros"
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notmatch "^\\Microsoft\\" -and $_.State -ne "Disabled" } | ForEach-Object {
    $acc = ($_.Actions | Where-Object { $_.Execute }).Execute -join "; "
    if (Rara $acc) { ERR "TAREA SOSPECHOSA  $($_.TaskPath)$($_.TaskName) -> $acc"; $hall++ }
    else { ROW "$($_.TaskPath)$($_.TaskName)" $acc }
}
Step "Servicios con binario en ruta de usuario"
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
    if (Rara $_.PathName) { ERR "SERVICIO SOSPECHOSO  $($_.Name) -> $($_.PathName)"; $hall++ }
}
Step "Binarios de arranque sin firma digital valida"
foreach ($k in $claves) {
    if (-not (Test-Path $k)) { continue }
    (Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
        $exe = ([regex]::Match($_.Value, '^"?([^"]+\.exe)')).Groups[1].Value
        if ($exe -and (Test-Path $exe)) {
            $sig = Get-AuthenticodeSignature $exe -ErrorAction SilentlyContinue
            if ($sig.Status -ne "Valid") { WARN "Sin firma valida: $exe  [$($sig.Status)]"; $hall++ }
        }
    }
}
if ($hall -eq 0) { OK "No se encontraron persistencias sospechosas." }
else { WARN "$hall hallazgos. Revisa con Autoruns de Sysinternals antes de eliminar nada." }
'@

    T -Id 'sec-ports' -Cat 'sec' -Icon 'E839' -Risk 'safe' -Run 'inline' `
        -Name 'Puertos y conexiones activas' -Desc 'Que esta escuchando, con que proceso y hacia donde sale el trafico' -Code @'
HR "PUERTOS EN ESCUCHA"
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Sort-Object LocalPort | ForEach-Object {
    $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    ROW "$($_.LocalAddress):$($_.LocalPort)" "$($p.ProcessName) (PID $($_.OwningProcess))  $($p.Path)"
}
Step "Conexiones establecidas hacia el exterior"
Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
    Where-Object { $_.RemoteAddress -notmatch "^(127\.|0\.0\.0\.0|::1|::)" } | ForEach-Object {
    $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    ROW "$($_.RemoteAddress):$($_.RemotePort)" "$($p.ProcessName) (PID $($_.OwningProcess))"
}
Step "Puertos de riesgo abiertos"
$riesgo = @{ 23 = "Telnet"; 445 = "SMB"; 3389 = "Escritorio remoto"; 5900 = "VNC"; 21 = "FTP"; 135 = "RPC" }
foreach ($pt in $riesgo.Keys) {
    $c = Get-NetTCPConnection -State Listen -LocalPort $pt -ErrorAction SilentlyContinue
    if ($c) { WARN "Puerto $pt abierto ($($riesgo[$pt])). Confirma que sea intencional." }
}
'@

    T -Id 'sec-hosts' -Cat 'sec' -Icon 'E8A5' -Risk 'safe' -Run 'inline' `
        -Name 'Revisar archivo hosts' -Desc 'Detecta redirecciones inyectadas por malware o cracks' -Code @'
HR "ARCHIVO HOSTS"
$h = "$env:SystemRoot\System32\drivers\etc\hosts"
$lineas = Get-Content $h -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -and $_ -notmatch "^\s*#" }
if (-not $lineas) { OK "El archivo hosts esta limpio (solo comentarios)."; }
else {
    WARN "$($lineas.Count) entradas activas:"
    $lineas | ForEach-Object {
        if ($_ -match "microsoft|windowsupdate|adobe|kaspersky|avast|defender") { ERR "  $_   <-- bloqueo tipico de crack/malware" }
        else { Write-Host "    $_" }
    }
    $f = Join-Path (BSDir "backups") ("hosts_" + (Stamp) + ".txt")
    Copy-Item $h $f -Force
    INFO "Copia de seguridad en $f"
}
INFO "Ruta: $h"
'@

    T -Id 'sec-updates' -Cat 'sec' -Icon 'E895' -Risk 'safe' -Run 'inline' `
        -Name 'Parches instalados y pendientes' -Desc 'Historial de actualizaciones y busqueda de las que faltan' -Code @'
HR "ACTUALIZACIONES DE SEGURIDAD"
Step "Ultimos parches instalados"
Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 15 |
    ForEach-Object { ROW $_.HotFixID "$($_.Description)  $($_.InstalledOn)" }
$ult = (Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
if ($ult) {
    $dias = ((Get-Date) - $ult).Days
    ROW "Ultimo parche" "$ult  ($dias dias)"
    if ($dias -gt 60) { ERR "El equipo lleva $dias dias sin parches de seguridad." }
    elseif ($dias -gt 35) { WARN "Conviene actualizar." }
    else { OK "El equipo esta al dia." }
}
Step "Buscando actualizaciones pendientes"
try {
    $ses = New-Object -ComObject Microsoft.Update.Session
    $bus = $ses.CreateUpdateSearcher()
    $res = $bus.Search("IsInstalled=0 and Type='Software'")
    if ($res.Updates.Count -eq 0) { OK "No hay actualizaciones pendientes." }
    else {
        WARN "$($res.Updates.Count) actualizaciones pendientes:"
        foreach ($u in $res.Updates) { ROW $u.Title ("$([math]::Round($u.MaxDownloadSize/1MB,1)) MB") }
    }
} catch { WARN "No se pudo consultar el agente de Windows Update: $($_.Exception.Message)" }
'@

    T -Id 'sec-rdp' -Cat 'sec' -Icon 'E8AF' -Risk 'care' -Run 'inline' `
        -Name 'Escritorio remoto y SMBv1' -Desc 'Revisa RDP, NLA y desactiva el protocolo SMBv1 vulnerable' -Code @'
HR "SUPERFICIE DE ATAQUE REMOTA"
Step "Escritorio remoto"
$rdp = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
if ($rdp -eq 0) {
    WARN "RDP HABILITADO."
    $nla = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication
    if ($nla -eq 1) { OK "  Autenticacion a nivel de red (NLA) activa." }
    else { ERR "  NLA DESACTIVADA: cualquiera puede llegar a la pantalla de login. Activando..."; Set-Reg "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" "UserAuthentication" 1 }
} else { OK "RDP deshabilitado." }

Step "SMBv1"
$smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
if ($smb1.State -eq "Enabled") {
    ERR "SMBv1 habilitado (vector de WannaCry). Desactivando..."
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
    OK "SMBv1 desactivado. Reinicia para completarlo."
} else { OK "SMBv1 no esta habilitado." }

Step "Recursos compartidos"
Get-SmbShare -ErrorAction SilentlyContinue | ForEach-Object { ROW $_.Name "$($_.Path)  [$($_.Description)]" }
Step "Control de cuentas de usuario (UAC)"
$u = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue
ROW "EnableLUA" $u.EnableLUA
ROW "ConsentPromptBehaviorAdmin" $u.ConsentPromptBehaviorAdmin
if ($u.EnableLUA -ne 1) { ERR "UAC DESACTIVADO. Reactivando..."; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA" 1 }
'@

    T -Id 'sec-secureboot' -Cat 'sec' -Icon 'E72E' -Risk 'safe' -Run 'inline' `
        -Name 'Arranque seguro y TPM' -Desc 'Verifica Secure Boot, TPM, virtualizacion y requisitos de Windows 11' -Code @'
HR "SEGURIDAD DE PLATAFORMA"
try { $sb = Confirm-SecureBootUEFI -ErrorAction Stop; if ($sb) { OK "Secure Boot ACTIVO." } else { WARN "Secure Boot desactivado." } }
catch { INFO "Secure Boot no aplica (BIOS legacy) o no se pudo consultar." }

$fw = (Get-CimInstance Win32_ComputerSystem).PCSystemType
$bios = Get-CimInstance Win32_BIOS
ROW "BIOS" "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)  $($bios.ReleaseDate)"
ROW "Modo de firmware" $(if ($env:firmware_type) { $env:firmware_type } else { "Desconocido" })

Step "TPM"
$t = Get-Tpm -ErrorAction SilentlyContinue
if ($t) {
    ROW "Presente" $t.TpmPresent; ROW "Listo" $t.TpmReady; ROW "Habilitado" $t.TpmEnabled
    ROW "Version" (Get-CimInstance -Namespace root\cimv2\security\microsofttpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue).SpecVersion
} else { WARN "Sin TPM detectado (requisito de Windows 11)." }

Step "Seguridad basada en virtualizacion"
$dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
if ($dg) {
    ROW "VBS en ejecucion" ($dg.VirtualizationBasedSecurityStatus -eq 2)
    ROW "Integridad de memoria (HVCI)" ($dg.SecurityServicesRunning -contains 2)
}
Step "Compatibilidad con Windows 11"
$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
$cpu = Get-CimInstance Win32_Processor
ROW "RAM" ((Human $ram) + $(if ($ram -ge 4GB) { "  OK" } else { "  INSUFICIENTE" }))
ROW "Nucleos" ($cpu.NumberOfCores.ToString() + $(if ($cpu.NumberOfCores -ge 2) { "  OK" } else { "  INSUFICIENTE" }))
ROW "Disco de sistema" (Human (Get-Volume -DriveLetter $env:SystemDrive[0]).Size)
'@

    T -Id 'sec-uac-max' -Cat 'sec' -Icon 'E72E' -Risk 'care' -Run 'inline' `
        -Name 'Endurecer el sistema' -Desc 'Sube UAC al maximo, activa SmartScreen y bloquea macros de Office' -Code @'
HR "ENDURECIMIENTO BASICO"
$pol = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Backup-Reg $pol "politicas_sistema"
Set-Reg $pol "EnableLUA" 1
Set-Reg $pol "ConsentPromptBehaviorAdmin" 2
Set-Reg $pol "PromptOnSecureDesktop" 1
Set-Reg $pol "EnableInstallerDetection" 1
Step "SmartScreen"
Set-Reg $pol "EnableSmartScreen" 1
Set-Reg $pol "ShellSmartScreenLevel" "Block" "String"
Set-Reg "HKCU:\Software\Microsoft\Edge\SmartScreenEnabled" "(Default)" 1
Step "Proteccion de red y ransomware de Defender"
Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction SilentlyContinue
Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
Set-MpPreference -SubmitSamplesConsent 1 -ErrorAction SilentlyContinue
OK "Proteccion de red y contra PUA habilitadas."
Step "Macros de Office bloqueadas desde Internet"
foreach ($v in @("16.0","15.0")) {
    foreach ($app in @("Word","Excel","PowerPoint")) {
        Set-Reg "HKCU:\Software\Microsoft\Office\$v\$app\Security" "blockcontentexecutionfrominternet" 1
    }
}
OK "Sistema endurecido."
WARN "UAC ahora pedira confirmacion mas seguido: es intencional."
'@
)

# ------------------------- RED, INFORMACION Y HERRAMIENTAS -------------------------
$Global:Catalog += @(

    T -Id 'net-info' -Cat 'net' -Icon 'E839' -Risk 'safe' -Run 'inline' `
        -Name 'Diagnostico de red completo' -Desc 'IP publica y privada, gateway, DNS, MAC, latencia y perdida de paquetes' -Code @'
HR "DIAGNOSTICO DE RED"
Step "Adaptadores activos"
Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq "Up" | ForEach-Object {
    ROW $_.Name "$($_.InterfaceDescription)  |  $($_.LinkSpeed)  |  MAC $($_.MacAddress)"
}
Step "Configuracion IP"
Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address } | ForEach-Object {
    ROW "Interfaz" $_.InterfaceAlias
    ROW "  IPv4" ($_.IPv4Address.IPAddress -join ", ")
    ROW "  Mascara" ("/" + ($_.IPv4Address.PrefixLength -join ", "))
    ROW "  Gateway" ($_.IPv4DefaultGateway.NextHop -join ", ")
    ROW "  DNS" ($_.DNSServer.ServerAddresses -join ", ")
}
Step "IP publica"
try {
    $ip = (Invoke-RestMethod "https://api.ipify.org?format=json" -TimeoutSec 8).ip
    ROW "IP publica" $ip
    try {
        $g = Invoke-RestMethod "http://ip-api.com/json/$ip" -TimeoutSec 8
        ROW "Proveedor" $g.isp
        ROW "Ubicacion" "$($g.city), $($g.regionName), $($g.country)"
    } catch { }
} catch { WARN "Sin salida a Internet o el servicio no respondio." }

Step "Latencia y perdida"
foreach ($d in @("1.1.1.1","8.8.8.8","google.com")) {
    $r = Test-Connection $d -Count 6 -ErrorAction SilentlyContinue
    if ($r) {
        $ms = ($r | Measure-Object -Property ResponseTime -Average -Maximum -Minimum -ErrorAction SilentlyContinue)
        if (-not $ms.Average) { $ms = ($r | Measure-Object -Property Latency -Average -Maximum -Minimum -ErrorAction SilentlyContinue) }
        $perd = [math]::Round((1 - ($r.Count / 6)) * 100, 0)
        ROW $d ("media $([math]::Round($ms.Average,0)) ms  |  min $($ms.Minimum)  max $($ms.Maximum)  |  perdida $perd%")
        if ($ms.Average -gt 120) { WARN "  Latencia alta hacia $d" }
    } else { ERR "$d : sin respuesta" }
}
Step "Resolucion DNS"
foreach ($d in @("google.com","microsoft.com")) {
    try { $r = Resolve-DnsName $d -ErrorAction Stop | Select-Object -First 1; OK "$d -> $($r.IPAddress)$($r.NameHost)" }
    catch { ERR "No resuelve: $d" }
}
Step "Tabla de rutas"
Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | ForEach-Object { ROW "Ruta por defecto" "$($_.NextHop) via $($_.InterfaceAlias) metrica $($_.RouteMetric)" }
'@

    T -Id 'net-speed' -Cat 'net' -Icon 'E945' -Risk 'safe' -Run 'inline' `
        -Name 'Test de velocidad' -Desc 'Mide la velocidad real de bajada descargando un archivo de prueba' -Code @'
HR "TEST DE VELOCIDAD"
if (Get-Command speedtest.exe -ErrorAction SilentlyContinue) {
    Step "Usando Ookla Speedtest CLI"
    speedtest.exe --accept-license --accept-gdpr
    return
}
INFO "Ookla CLI no instalado (winget install Ookla.Speedtest.CLI). Se usa la prueba integrada."
Step "Descargando archivo de prueba de Cloudflare"
$urls = @(
  @{n="10 MB"; u="https://speed.cloudflare.com/__down?bytes=10000000"; b=10000000},
  @{n="50 MB"; u="https://speed.cloudflare.com/__down?bytes=50000000"; b=50000000}
)
foreach ($t in $urls) {
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Invoke-WebRequest $t.u -OutFile "$env:TEMP\bsspeed.tmp" -UseBasicParsing -ErrorAction Stop
        $sw.Stop()
        $mbps = [math]::Round(($t.b * 8 / 1000000) / $sw.Elapsed.TotalSeconds, 2)
        ROW "Bajada ($($t.n))" "$mbps Mbps   en $([math]::Round($sw.Elapsed.TotalSeconds,1)) s"
    } catch { ERR "$($t.n): $($_.Exception.Message)" }
}
Remove-Item "$env:TEMP\bsspeed.tmp" -Force -ErrorAction SilentlyContinue
Step "Latencia a servidores cercanos"
foreach ($h in @("1.1.1.1","8.8.8.8","cloudflare.com")) {
    $r = Test-Connection $h -Count 4 -ErrorAction SilentlyContinue
    if ($r) {
        $m = ($r | Measure-Object -Property ResponseTime -Average).Average
        if (-not $m) { $m = ($r | Measure-Object -Property Latency -Average).Average }
        ROW $h "$([math]::Round($m,0)) ms"
    }
}
Step "Velocidad negociada del enlace"
Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object { ROW $_.Name $_.LinkSpeed }
'@

    T -Id 'net-wifi-pass' -Cat 'net' -Icon 'E701' -Risk 'care' -Run 'inline' `
        -Name 'Contrasenas WiFi guardadas' -Desc 'Recupera las claves de todas las redes memorizadas por el equipo' -Code @'
HR "REDES WIFI GUARDADAS"
$perfiles = (netsh wlan show profiles) | Select-String "Perfil de todos los usuarios|All User Profile" | ForEach-Object {
    ($_ -split ":", 2)[1].Trim()
}
if (-not $perfiles) { WARN "No hay perfiles WiFi (equipo sin adaptador inalambrico o sin redes guardadas)."; return }
$lista = @()
foreach ($p in $perfiles) {
    $det = netsh wlan show profile name="$p" key=clear
    $clave = ($det | Select-String "Contenido de la clave|Key Content" | ForEach-Object { ($_ -split ":", 2)[1].Trim() })
    $auth = ($det | Select-String "Autenticaci|Authentication" | Select-Object -First 1 | ForEach-Object { ($_ -split ":", 2)[1].Trim() })
    if (-not $clave) { $clave = "(sin clave / abierta o guardada por perfil de sistema)" }
    ROW $p "$clave   [$auth]"
    $lista += [pscustomobject]@{ Red = $p; Clave = $clave; Seguridad = $auth }
}
$f = Join-Path (BSDir "reportes") ("wifi_" + $env:COMPUTERNAME + "_" + (Stamp) + ".csv")
$lista | Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "$($lista.Count) redes exportadas a $f"
WARN "Ese archivo contiene contrasenas en texto plano. Guardalo con cuidado."
'@

    T -Id 'net-scan-lan' -Cat 'net' -Icon 'E968' -Risk 'safe' -Run 'inline' `
        -Name 'Escanear la red local' -Desc 'Descubre los dispositivos conectados, su IP, MAC y fabricante' -Code @'
HR "ESCANEO DE RED LOCAL"
$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
if (-not $cfg) { ERR "Sin conexion de red activa."; return }
$ip = $cfg.IPv4Address.IPAddress
$gw = $cfg.IPv4DefaultGateway.NextHop
$base = ($ip -split "\.")[0..2] -join "."
ROW "Mi IP" $ip
ROW "Gateway" $gw
ROW "Rango" "$base.1 - $base.254"

Step "Barrido de la red (unos 30 segundos)"
$jobs = 1..254 | ForEach-Object {
    $t = "$base.$_"
    Test-Connection -ComputerName $t -Count 1 -Quiet -ErrorAction SilentlyContinue -AsJob
}
$null = Wait-Job $jobs -Timeout 40
$vivos = @()
for ($i = 0; $i -lt $jobs.Count; $i++) {
    if ((Receive-Job $jobs[$i] -ErrorAction SilentlyContinue) -eq $true) { $vivos += "$base.$($i+1)" }
}
Remove-Job $jobs -Force -ErrorAction SilentlyContinue

Step "Dispositivos encontrados: $($vivos.Count)"
$arp = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.State -in @("Reachable","Stale","Permanent") }
foreach ($v in $vivos) {
    $mac = ($arp | Where-Object IPAddress -eq $v | Select-Object -First 1).LinkLayerAddress
    $nom = try { [System.Net.Dns]::GetHostEntry($v).HostName } catch { "" }
    $et = if ($v -eq $ip) { "  <- este equipo" } elseif ($v -eq $gw) { "  <- router" } else { "" }
    ROW $v "$mac  $nom$et"
}
Step "Tabla ARP completa"
$arp | Sort-Object IPAddress | ForEach-Object { ROW $_.IPAddress "$($_.LinkLayerAddress)  [$($_.State)]" }
'@

    T -Id 'net-dns-set' -Cat 'net' -Icon 'E774' -Risk 'care' -Run 'inline' `
        -Name 'DNS rapidos (Cloudflare)' -Desc 'Aplica 1.1.1.1 y 8.8.8.8 en todos los adaptadores activos' -Code @'
HR "CONFIGURACION DE DNS"
Step "DNS actuales"
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.ServerAddresses } | ForEach-Object { ROW $_.InterfaceAlias ($_.ServerAddresses -join ", ") }
Step "Aplicando 1.1.1.1 / 1.0.0.1 / 8.8.8.8"
Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object {
    try {
        Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1","8.8.8.8") -ErrorAction Stop
        OK "$($_.Name) actualizado."
    } catch { WARN "$($_.Name): $($_.Exception.Message)" }
}
Clear-DnsClientCache
Step "Comprobacion"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
Resolve-DnsName "microsoft.com" -ErrorAction SilentlyContinue | Out-Null
$sw.Stop()
OK "Resolucion en $($sw.ElapsedMilliseconds) ms"
'@ -Revert @'
Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
    OK "$($_.Name) vuelve a DNS automatico (DHCP)."
}
Clear-DnsClientCache
'@

    T -Id 'net-dns-flush' -Cat 'net' -Icon 'E72C' -Risk 'safe' -Run 'inline' `
        -Name 'Vaciar cache DNS' -Desc 'Soluciona paginas que cargan mal tras un cambio de servidor' -Code @'
HR "CACHE DNS"
Step "Entradas en cache antes"
$n = (Get-DnsClientCache -ErrorAction SilentlyContinue).Count
INFO "$n entradas."
Clear-DnsClientCache
ipconfig /flushdns | Out-Null
ipconfig /registerdns | Out-Null
OK "Cache DNS vaciada y registro renovado."
'@

    T -Id 'net-trace' -Cat 'net' -Icon 'E81E' -Risk 'safe' -Run 'inline' `
        -Name 'Trazado de ruta y estabilidad' -Desc 'Traza el camino hasta Internet y detecta en que salto se pierde el paquete' -Code @'
HR "TRAZADO DE RUTA"
$destino = "1.1.1.1"
Step "Ruta hacia $destino"
tracert -d -h 15 -w 800 $destino
Step "Prueba de estabilidad al gateway (30 paquetes)"
$gw = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).IPv4DefaultGateway.NextHop
if ($gw) {
    $r = Test-Connection $gw -Count 30 -ErrorAction SilentlyContinue
    $perd = [math]::Round((1 - ($r.Count / 30)) * 100, 1)
    $m = ($r | Measure-Object -Property ResponseTime -Average -Maximum).Average
    if (-not $m) { $m = ($r | Measure-Object -Property Latency -Average).Average }
    ROW "Gateway $gw" "media $([math]::Round($m,1)) ms  |  perdida $perd%"
    if ($perd -gt 2) { ERR "Hay perdida de paquetes hacia tu propio router: revisa cable o WiFi." }
    else { OK "Enlace local estable." }
}
Step "Estabilidad hacia Internet (30 paquetes)"
$r2 = Test-Connection "8.8.8.8" -Count 30 -ErrorAction SilentlyContinue
$perd2 = [math]::Round((1 - ($r2.Count / 30)) * 100, 1)
ROW "Internet" "perdida $perd2%"
if ($perd2 -gt 2) { ERR "Perdida hacia Internet: problema del proveedor o del router." }
'@

    T -Id 'net-adapters' -Cat 'net' -Icon 'E839' -Risk 'safe' -Run 'inline' `
        -Name 'Gestionar adaptadores de red' -Desc 'Estado de cada tarjeta y reinicio del adaptador principal' -Code @'
HR "ADAPTADORES DE RED"
Get-NetAdapter -ErrorAction SilentlyContinue | Sort-Object Status | ForEach-Object {
    ROW $_.Name "$($_.Status)  |  $($_.InterfaceDescription)  |  $($_.LinkSpeed)  |  MAC $($_.MacAddress)"
}
Step "Reiniciando los adaptadores activos"
Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object {
    try {
        Restart-NetAdapter -Name $_.Name -ErrorAction Stop
        OK "Reiniciado: $($_.Name)"
    } catch { WARN "$($_.Name): $($_.Exception.Message)" }
}
Start-Sleep -Seconds 5
Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object { ROW $_.Name $_.Status }
Start-Process "ncpa.cpl"
'@

    T -Id 'net-proxy' -Cat 'net' -Icon 'E774' -Risk 'care' -Run 'inline' `
        -Name 'Revisar y limpiar proxy' -Desc 'Detecta proxies inyectados que rompen la navegacion y los elimina' -Code @'
HR "CONFIGURACION DE PROXY"
$k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$p = Get-ItemProperty $k -ErrorAction SilentlyContinue
ROW "ProxyEnable" $p.ProxyEnable
ROW "ProxyServer" $p.ProxyServer
ROW "AutoConfigURL" $p.AutoConfigURL
Step "Proxy de WinHTTP"
netsh winhttp show proxy
if ($p.ProxyEnable -eq 1 -or $p.AutoConfigURL) {
    WARN "Hay un proxy configurado. Si no lo pusiste tu, es tipico de adware."
    Set-Reg $k "ProxyEnable" 0
    Remove-Reg $k "ProxyServer"
    Remove-Reg $k "AutoConfigURL"
    netsh winhttp reset proxy
    OK "Proxy eliminado."
} else { OK "Sin proxy configurado (conexion directa)." }
'@

    T -Id 'net-shares' -Cat 'net' -Icon 'E8B7' -Risk 'safe' -Run 'inline' `
        -Name 'Recursos y unidades de red' -Desc 'Que comparte este equipo y a que unidades de red esta conectado' -Code @'
HR "RECURSOS COMPARTIDOS"
Step "Compartidos por este equipo"
Get-SmbShare -ErrorAction SilentlyContinue | ForEach-Object {
    ROW $_.Name "$($_.Path)   [$($_.Description)]"
    Get-SmbShareAccess -Name $_.Name -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("        " + $_.AccountName + " -> " + $_.AccessRight) }
}
Step "Sesiones abiertas contra este equipo"
$s = Get-SmbSession -ErrorAction SilentlyContinue
if ($s) { $s | ForEach-Object { ROW $_.ClientComputerName "$($_.ClientUserName)  archivos abiertos: $($_.NumOpens)" } }
else { OK "Nadie conectado." }
Step "Unidades de red mapeadas"
Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.DisplayRoot } |
    ForEach-Object { ROW "$($_.Name):" $_.DisplayRoot }
net use
'@

    # ========================= INFORMACION =========================
    T -Id 'info-report-html' -Cat 'info' -Icon 'EB05' -Risk 'safe' -Run 'inline' `
        -Name 'Reporte HTML del equipo' -Desc 'Informe completo con marca para entregar al cliente. Se abre al terminar' -Code @'
HR "GENERANDO REPORTE HTML"
$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$mb   = Get-CimInstance Win32_BaseBoard
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpus = Get-CimInstance Win32_VideoController
$rams = Get-CimInstance Win32_PhysicalMemory
$vols = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" }
$pds  = Get-PhysicalDisk -ErrorAction SilentlyContinue
$net  = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq "Up"
$up   = (Get-Date) - $os.LastBootUpTime
$def  = Get-MpComputerStatus -ErrorAction SilentlyContinue
$lic  = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction SilentlyContinue | Select-Object -First 1
$act  = if ($lic.LicenseStatus -eq 1) { "Activado" } else { "NO ACTIVADO" }
$sw   = @()
foreach ($rk in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
    $sw += Get-ItemProperty $rk -ErrorAction SilentlyContinue | Where-Object DisplayName | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
}
$sw = $sw | Sort-Object DisplayName -Unique

function Row2 ($k, $v) { "<tr><td class=k>$k</td><td>$v</td></tr>" }
$sb = [System.Text.StringBuilder]::new()
$null = $sb.Append(@"
<!doctype html><html lang=es><head><meta charset=utf-8>
<title>Reporte ToolboxBS - $env:COMPUTERNAME</title>
<style>
:root{--bg:#09090b;--card:#18181b;--bd:#27272a;--tx:#e4e4e7;--mu:#a1a1aa;--ac:#3b82f6;--ok:#10b981;--wr:#eab308;--er:#ef4444}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:14px/1.6 "Segoe UI",system-ui,sans-serif;padding:32px}
h1{font-size:28px;margin:0 0 4px}h2{font-size:15px;text-transform:uppercase;letter-spacing:.08em;color:var(--mu);margin:32px 0 12px;border-bottom:1px solid var(--bd);padding-bottom:8px}
.sub{color:var(--mu);margin-bottom:24px}
.card{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:18px 22px;margin-bottom:14px}
table{width:100%;border-collapse:collapse}td,th{padding:7px 10px;border-bottom:1px solid var(--bd);vertical-align:top;text-align:left}
td.k{color:var(--mu);width:270px;font-weight:500}th{color:var(--mu);font-size:12px;text-transform:uppercase;letter-spacing:.05em}
.badge{display:inline-block;padding:2px 10px;border-radius:999px;font-size:12px;font-weight:600}
.ok{background:rgba(16,185,129,.15);color:var(--ok)}.wr{background:rgba(234,179,8,.15);color:var(--wr)}.er{background:rgba(239,68,68,.15);color:var(--er)}
.bar{height:8px;background:#27272a;border-radius:99px;overflow:hidden;margin-top:6px}.bar i{display:block;height:100%;background:var(--ac)}
.foot{margin-top:40px;color:var(--mu);font-size:12px;border-top:1px solid var(--bd);padding-top:16px}
.logo{color:var(--ac);font-weight:800}
</style></head><body>
<h1>Reporte de equipo <span class=logo>ToolboxBS</span></h1>
<div class=sub>$($cs.Name) &middot; generado el $(Get-Date -Format "dd/MM/yyyy HH:mm") &middot; por $env:USERNAME</div>
"@)

$null = $sb.Append("<h2>Sistema</h2><div class=card><table>")
$null = $sb.Append((Row2 "Equipo" $env:COMPUTERNAME))
$null = $sb.Append((Row2 "Sistema operativo" "$($os.Caption) $($os.OSArchitecture)"))
$null = $sb.Append((Row2 "Version / compilacion" "$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion) &middot; build $($os.BuildNumber)"))
$null = $sb.Append((Row2 "Instalado el" $os.InstallDate))
$null = $sb.Append((Row2 "Ultimo arranque" "$($os.LastBootUpTime)  (encendido hace $($up.Days)d $($up.Hours)h $($up.Minutes)m)"))
$null = $sb.Append((Row2 "Activacion" "<span class='badge $(if($act -eq 'Activado'){'ok'}else{'er'})'>$act</span>"))
$null = $sb.Append((Row2 "Usuario" "$env:USERDOMAIN\$env:USERNAME"))
$null = $sb.Append("</table></div>")

$null = $sb.Append("<h2>Hardware</h2><div class=card><table>")
$null = $sb.Append((Row2 "Fabricante / modelo" "$($cs.Manufacturer) $($cs.Model)"))
$null = $sb.Append((Row2 "Numero de serie" $bios.SerialNumber))
$null = $sb.Append((Row2 "Placa base" "$($mb.Manufacturer) $($mb.Product)"))
$null = $sb.Append((Row2 "BIOS" "$($bios.SMBIOSBIOSVersion)  ($($bios.ReleaseDate))"))
$null = $sb.Append((Row2 "Procesador" "$($cpu.Name)"))
$null = $sb.Append((Row2 "Nucleos / hilos" "$($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors) &middot; $([math]::Round($cpu.MaxClockSpeed/1000,2)) GHz"))
$null = $sb.Append((Row2 "Memoria RAM" "$(Human $cs.TotalPhysicalMemory) en $($rams.Count) modulo(s)"))
foreach ($r in $rams) {
    $tipo = switch ($r.SMBIOSMemoryType) { 20 {"DDR"} 21 {"DDR2"} 24 {"DDR3"} 26 {"DDR4"} 34 {"DDR5"} 30 {"DDR5"} default {"Tipo $($r.SMBIOSMemoryType)"} }
    $null = $sb.Append((Row2 "&nbsp;&nbsp;$($r.DeviceLocator)" "$(Human $r.Capacity) $tipo @ $($r.Speed) MHz &middot; $($r.Manufacturer) &middot; SN $($r.SerialNumber)"))
}
foreach ($g in $gpus) { $null = $sb.Append((Row2 "Grafica" "$($g.Name) &middot; driver $($g.DriverVersion) &middot; $(Human $g.AdapterRAM)")) }
$null = $sb.Append("</table></div>")

$null = $sb.Append("<h2>Almacenamiento</h2><div class=card><table><tr><th>Unidad</th><th>Capacidad</th><th>Uso</th></tr>")
foreach ($v in $vols) {
    $usado = $v.Size - $v.SizeRemaining
    $pct = if ($v.Size) { [math]::Round($usado / $v.Size * 100, 1) } else { 0 }
    $cls = if ($pct -gt 90) { "er" } elseif ($pct -gt 75) { "wr" } else { "ok" }
    $null = $sb.Append("<tr><td class=k>$($v.DriveLetter): $($v.FileSystemLabel)</td><td>$(Human $v.Size)</td><td><span class='badge $cls'>$pct% usado</span> &middot; libre $(Human $v.SizeRemaining)<div class=bar><i style='width:$pct%'></i></div></td></tr>")
}
foreach ($d in $pds) {
    $cls = if ($d.HealthStatus -eq "Healthy") { "ok" } else { "er" }
    $null = $sb.Append("<tr><td class=k>$($d.FriendlyName)</td><td>$(Human $d.Size) &middot; $($d.MediaType) &middot; $($d.BusType)</td><td><span class='badge $cls'>$($d.HealthStatus)</span></td></tr>")
}
$null = $sb.Append("</table></div>")

$null = $sb.Append("<h2>Red</h2><div class=card><table>")
foreach ($n in $net) {
    $ipc = Get-NetIPConfiguration -InterfaceIndex $n.ifIndex -ErrorAction SilentlyContinue
    $null = $sb.Append((Row2 $n.Name "$($n.InterfaceDescription)<br>IP $($ipc.IPv4Address.IPAddress) &middot; GW $($ipc.IPv4DefaultGateway.NextHop) &middot; DNS $($ipc.DNSServer.ServerAddresses -join ', ')<br>MAC $($n.MacAddress) &middot; $($n.LinkSpeed)"))
}
$null = $sb.Append("</table></div>")

$null = $sb.Append("<h2>Seguridad</h2><div class=card><table>")
if ($def) {
    $null = $sb.Append((Row2 "Antivirus" "<span class='badge $(if($def.AntivirusEnabled){'ok'}else{'er'})'>$(if($def.AntivirusEnabled){'Activo'}else{'Inactivo'})</span>"))
    $null = $sb.Append((Row2 "Tiempo real" "<span class='badge $(if($def.RealTimeProtectionEnabled){'ok'}else{'er'})'>$(if($def.RealTimeProtectionEnabled){'Activa'}else{'APAGADA'})</span>"))
    $null = $sb.Append((Row2 "Firmas" "$($def.AntivirusSignatureVersion) &middot; hace $($def.AntivirusSignatureAge) dia(s)"))
}
$fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue
foreach ($p in $fw) { $null = $sb.Append((Row2 "Firewall $($p.Name)" "<span class='badge $(if($p.Enabled){'ok'}else{'er'})'>$(if($p.Enabled){'Activo'}else{'Inactivo'})</span>")) }
$bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
if ($bl) { $null = $sb.Append((Row2 "BitLocker $env:SystemDrive" $bl.VolumeStatus)) }
$hf = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 1
$null = $sb.Append((Row2 "Ultimo parche" "$($hf.HotFixID) &middot; $($hf.InstalledOn)"))
$null = $sb.Append("</table></div>")

$null = $sb.Append("<h2>Software instalado ($($sw.Count) programas)</h2><div class=card><table><tr><th>Programa</th><th>Version</th><th>Editor</th></tr>")
foreach ($s in $sw) { $null = $sb.Append("<tr><td class=k>$($s.DisplayName)</td><td>$($s.DisplayVersion)</td><td>$($s.Publisher)</td></tr>") }
$null = $sb.Append("</table></div>")

$null = $sb.Append("<div class=foot>Generado por <span class=logo>ToolboxBS v4</span> &middot; Brandon Sepulveda &middot; $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</div></body></html>")

$f = Join-Path (BSDir "reportes") ("reporte_" + $env:COMPUTERNAME + "_" + (Stamp) + ".html")
$sb.ToString() | Set-Content $f -Encoding UTF8
OK "Reporte generado: $f"
Start-Process $f
'@

    T -Id 'info-software' -Cat 'info' -Icon 'E8F1' -Risk 'safe' -Run 'inline' `
        -Name 'Inventario de software' -Desc 'Todo lo instalado con version y editor, exportado a CSV' -Code @'
HR "SOFTWARE INSTALADO"
$sw = @()
foreach ($rk in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
    $sw += Get-ItemProperty $rk -ErrorAction SilentlyContinue | Where-Object DisplayName |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, EstimatedSize, UninstallString
}
$sw = $sw | Sort-Object DisplayName -Unique
INFO "$($sw.Count) programas encontrados (registro clasico)."
$sw | ForEach-Object { ROW $_.DisplayName "$($_.DisplayVersion)   $($_.Publisher)" }

Step "Aplicaciones de la Store"
$appx = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { -not $_.IsFramework } | Select-Object Name, Version
INFO "$($appx.Count) paquetes UWP."

$f = Join-Path (BSDir "reportes") ("software_" + $env:COMPUTERNAME + "_" + (Stamp) + ".csv")
$sw | Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "Inventario: $f"
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Step "Listado de winget (util para reinstalar en otro equipo)"
    $f2 = Join-Path (BSDir "reportes") ("winget_export_" + (Stamp) + ".json")
    winget export -o "$f2" --accept-source-agreements 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Host "    $_" }
    if (Test-Path $f2) { OK "Exportacion winget: $f2  (restaurar con: winget import -i archivo.json)" }
}
'@

    T -Id 'info-keys' -Cat 'info' -Icon 'E8D7' -Risk 'safe' -Run 'inline' `
        -Name 'Claves de producto' -Desc 'Recupera la clave de Windows del BIOS y del registro antes de formatear' -Code @'
HR "CLAVES DE PRODUCTO"
Step "Clave OEM grabada en el firmware"
$oem = (Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey
if ($oem) { OK "Clave OEM (BIOS): $oem" } else { INFO "Sin clave OEM en el firmware." }

Step "Clave instalada actualmente"
$svc = Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue
ROW "Ultimos 5 digitos" $svc.OA3xOriginalProductKeyDescription
$lic = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction SilentlyContinue
foreach ($l in $lic) {
    ROW $l.Name "clave parcial: $($l.PartialProductKey)  |  canal: $($l.ProductKeyChannel)  |  estado: $(if($l.LicenseStatus -eq 1){'ACTIVADO'}else{'no activado'})"
}

Step "Clave del registro (DigitalProductId)"
try {
    $id = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DigitalProductId -ErrorAction Stop).DigitalProductId
    $mapa = "BCDFGHJKMPQRTVWXY2346789"
    $clave = ""
    for ($i = 24; $i -ge 0; $i--) {
        $r = 0
        for ($j = 14; $j -ge 0; $j--) {
            $r = ($r * 256) -bxor $id[$j + 52]
            $id[$j + 52] = [math]::Floor($r / 24)
            $r = $r % 24
        }
        $clave = $mapa[$r] + $clave
        if (($i % 5) -eq 0 -and $i -ne 0) { $clave = "-" + $clave }
    }
    OK "Clave del registro: $clave"
} catch { INFO "No se pudo decodificar la clave del registro (normal en licencias digitales)." }

Step "Office"
foreach ($v in @("16.0","15.0","14.0")) {
    $p = "HKLM:\SOFTWARE\Microsoft\Office\$v\Registration"
    if (Test-Path $p) { Get-ChildItem $p | ForEach-Object { $d = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue; if ($d.ProductName) { ROW $d.ProductName $d.DigitalProductID.Length } } }
}

$f = Join-Path (BSDir "backups") ("claves_" + $env:COMPUTERNAME + "_" + (Stamp) + ".txt")
@("Equipo: $env:COMPUTERNAME", "Fecha: $(Get-Date)", "Clave OEM/BIOS: $oem", "Edicion: $((Get-CimInstance Win32_OperatingSystem).Caption)") | Set-Content $f -Encoding UTF8
OK "Guardado en $f"
'@

    T -Id 'info-disks' -Cat 'info' -Icon 'EDA2' -Risk 'safe' -Run 'inline' `
        -Name 'Salud de discos (SMART)' -Desc 'Horas de uso, reasignaciones, temperatura y vida util restante' -Code @'
HR "SALUD DE DISCOS"
Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
    $d = $_
    HR "$($d.FriendlyName)"
    ROW "Modelo" $d.Model
    ROW "Serial" $d.SerialNumber
    ROW "Tipo" "$($d.MediaType)  bus $($d.BusType)"
    ROW "Capacidad" (Human $d.Size)
    ROW "Estado" $d.HealthStatus
    ROW "Uso" $d.Usage
    if ($d.HealthStatus -ne "Healthy") { ERR "  DISCO EN RIESGO: respalda los datos cuanto antes." }

    $rel = $d | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if ($rel) {
        if ($rel.PowerOnHours) { ROW "  Horas encendido" "$($rel.PowerOnHours) h  (~$([math]::Round($rel.PowerOnHours/8760,1)) anios)" }
        if ($rel.Temperature) { ROW "  Temperatura" "$($rel.Temperature) C" ; if ($rel.Temperature -gt 55) { WARN "  Temperatura alta." } }
        if ($rel.Wear -ne $null) { ROW "  Desgaste" "$($rel.Wear)%  (vida restante $([math]::Max(0,100-$rel.Wear))%)" }
        if ($rel.ReadErrorsTotal) { ROW "  Errores de lectura" $rel.ReadErrorsTotal }
        if ($rel.WriteErrorsTotal) { ROW "  Errores de escritura" $rel.WriteErrorsTotal }
        if ($rel.Wear -gt 80) { ERR "  El SSD supera el 80% de desgaste." }
    }
}
Step "Predicion de fallo SMART del firmware"
Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PredictFailure) { ERR "$($_.InstanceName): EL DISCO PREDICE FALLO INMINENTE." }
    else { OK "$($_.InstanceName): sin prediccion de fallo." }
}
Step "Volumenes"
Get-Volume | Where-Object DriveLetter | ForEach-Object {
    ROW "$($_.DriveLetter): $($_.FileSystemLabel)" "$($_.HealthStatus)  |  $(Human $_.SizeRemaining) libres de $(Human $_.Size)"
}
'@

    T -Id 'info-temps' -Cat 'info' -Icon 'E9CA' -Risk 'safe' -Run 'inline' `
        -Name 'Temperaturas y sensores' -Desc 'Lee los sensores termicos disponibles via WMI y ACPI' -Code @'
HR "TEMPERATURAS"
$ok = $false
try {
    Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop | ForEach-Object {
        $c = [math]::Round(($_.CurrentTemperature / 10) - 273.15, 1)
        ROW $_.InstanceName "$c C"
        if ($c -gt 85) { ERR "  Temperatura critica." } elseif ($c -gt 70) { WARN "  Temperatura alta." }
        $ok = $true
    }
} catch { }
if (-not $ok) { WARN "El firmware no expone zonas termicas ACPI (muy comun). Usa HWiNFO o CrystalDiskInfo desde el repositorio de apps." }

Step "Temperatura de discos"
Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
    $r = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if ($r.Temperature) { ROW $_.FriendlyName "$($r.Temperature) C  (maxima registrada: $($r.TemperatureMax) C)" }
}
Step "Carga y velocidad de CPU"
$cpu = Get-CimInstance Win32_Processor
ROW "Modelo" $cpu.Name
ROW "Carga actual" "$($cpu.LoadPercentage)%"
ROW "Velocidad actual" "$($cpu.CurrentClockSpeed) MHz de $($cpu.MaxClockSpeed) MHz"
if ($cpu.CurrentClockSpeed -lt ($cpu.MaxClockSpeed * 0.4)) { WARN "La CPU esta funcionando muy por debajo de su frecuencia: revisa el plan de energia o throttling termico." }
Step "Ventiladores"
Get-CimInstance Win32_Fan -ErrorAction SilentlyContinue | ForEach-Object { ROW $_.Name "$($_.DesiredSpeed) rpm  estado: $($_.Status)" }
'@

    T -Id 'info-bench' -Cat 'info' -Icon 'E945' -Risk 'safe' -Run 'inline' `
        -Name 'Benchmark rapido' -Desc 'Mide CPU, memoria y velocidad de disco en menos de un minuto' -Code @'
HR "BENCHMARK RAPIDO"
Step "CPU - calculo intensivo"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$acc = 0.0
for ($i = 1; $i -le 4000000; $i++) { $acc += [math]::Sqrt($i) }
$sw.Stop()
$pts = [math]::Round(4000000 / $sw.Elapsed.TotalSeconds / 1000, 0)
ROW "CPU (1 hilo)" "$([math]::Round($sw.Elapsed.TotalSeconds,2)) s   ->   $pts kOps/s"

Step "CPU - multihilo"
$n = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$jobs = 1..$n | ForEach-Object { Start-Job { $a = 0.0; for ($i = 1; $i -le 2000000; $i++) { $a += [math]::Sqrt($i) }; $a } }
$null = Wait-Job $jobs
Remove-Job $jobs -Force
$sw.Stop()
ROW "CPU ($n hilos)" "$([math]::Round($sw.Elapsed.TotalSeconds,2)) s"

Step "Disco - escritura secuencial (256 MB)"
$f = Join-Path $env:TEMP "bsbench.bin"
$buf = New-Object byte[] (8MB)
(New-Object Random).NextBytes($buf)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$fs = [System.IO.File]::Create($f)
for ($i = 0; $i -lt 32; $i++) { $fs.Write($buf, 0, $buf.Length) }
$fs.Flush($true); $fs.Close()
$sw.Stop()
ROW "Escritura" "$([math]::Round(256 / $sw.Elapsed.TotalSeconds, 1)) MB/s"

Step "Disco - lectura secuencial"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$fs = [System.IO.File]::OpenRead($f)
$tmp = New-Object byte[] (8MB)
while ($fs.Read($tmp, 0, $tmp.Length) -gt 0) { }
$fs.Close()
$sw.Stop()
ROW "Lectura" "$([math]::Round(256 / $sw.Elapsed.TotalSeconds, 1)) MB/s"
Remove-Item $f -Force -ErrorAction SilentlyContinue

Step "Memoria"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$a = New-Object byte[] (200MB)
for ($i = 0; $i -lt $a.Length; $i += 4096) { $a[$i] = 1 }
$sw.Stop()
ROW "Asignacion RAM" "200 MB en $([math]::Round($sw.Elapsed.TotalMilliseconds,0)) ms"
$a = $null
[GC]::Collect()

Step "Indice de experiencia de Windows (si existe)"
Get-CimInstance Win32_WinSAT -ErrorAction SilentlyContinue | Format-List CPUScore, D3DScore, DiskScore, GraphicsScore, MemoryScore, WinSPRLevel | Out-String | Write-Host
'@

    T -Id 'info-warranty' -Cat 'info' -Icon 'E8FD' -Risk 'safe' -Run 'inline' `
        -Name 'Consultar garantia' -Desc 'Detecta el serial y abre el portal de garantia del fabricante ya rellenado' -Code @'
HR "GARANTIA DEL EQUIPO"
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$sn = $bios.SerialNumber
ROW "Fabricante" $cs.Manufacturer
ROW "Modelo" $cs.Model
ROW "Serial / Service Tag" $sn
ROW "Fecha de BIOS" $bios.ReleaseDate
if (-not $sn -or $sn -match "System Serial|To be filled|Default string") {
    WARN "El equipo no tiene serial valido en el BIOS (ensamblado o clon)."
    return
}
$m = $cs.Manufacturer
$url = switch -Regex ($m) {
    "Dell"    { "https://www.dell.com/support/home/es-co/product-support/servicetag/$sn/overview" }
    "HP|Hewlett" { "https://support.hp.com/co-es/checkwarranty/result?serialNumber=$sn" }
    "Lenovo"  { "https://pcsupport.lenovo.com/co/es/warrantylookup?serialNumber=$sn" }
    "ASUS"    { "https://www.asus.com/support/warranty-status-inquiry/" }
    "Acer"    { "https://www.acer.com/es-es/support/warranty-info" }
    "Apple"   { "https://checkcoverage.apple.com/" }
    "Micro-Star|MSI" { "https://account.msi.com/login" }
    default   { "https://www.google.com/search?q=" + [uri]::EscapeDataString("garantia $m $($cs.Model) serial $sn") }
}
OK "Abriendo: $url"
Start-Process $url
'@

    T -Id 'info-hardware' -Cat 'info' -Icon 'E9F9' -Risk 'safe' -Run 'inline' `
        -Name 'Diagnostico profundo del sistema' -Desc 'SystemInfoPlus: recorrido completo de OS, CPU, RAM, discos, red y GPU' -Code @'
$host.UI.RawUI.WindowTitle = "SystemInfoPlus - ToolboxBS"
HR "SISTEMA OPERATIVO Y PLACA BASE"
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$mb = Get-CimInstance Win32_BaseBoard
$cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
ROW "Nombre del equipo" $env:COMPUTERNAME
ROW "Usuario actual" "$env:USERDOMAIN\$env:USERNAME"
ROW "Sistema operativo" $os.Caption
ROW "Edicion / version" "$($cv.EditionID)  $($cv.DisplayVersion)"
ROW "Build" "$($os.BuildNumber).$($cv.UBR)"
ROW "Arquitectura" $os.OSArchitecture
ROW "Instalado el" $os.InstallDate
ROW "Dias desde la instalacion" ([math]::Round(((Get-Date) - $os.InstallDate).TotalDays, 0))
ROW "Ultimo arranque" $os.LastBootUpTime
$up = (Get-Date) - $os.LastBootUpTime
ROW "Tiempo encendido" "$($up.Days) dias, $($up.Hours) h, $($up.Minutes) min"
ROW "Fabricante" $cs.Manufacturer
ROW "Modelo" $cs.Model
ROW "Tipo de sistema" $cs.SystemType
ROW "Dominio / grupo" $cs.Domain
ROW "Placa base" "$($mb.Manufacturer) $($mb.Product)"
ROW "BIOS" "$($bios.SMBIOSBIOSVersion)  ($($bios.ReleaseDate))"
ROW "Serial del equipo" $bios.SerialNumber

HR "PROCESADOR"
foreach ($c in Get-CimInstance Win32_Processor) {
    ROW "Procesador" $c.Name
    ROW "  Fabricante" $c.Manufacturer
    ROW "  Socket" $c.SocketDesignation
    ROW "  Nucleos fisicos" $c.NumberOfCores
    ROW "  Hilos" $c.NumberOfLogicalProcessors
    ROW "  Frecuencia base" "$($c.MaxClockSpeed) MHz"
    ROW "  Frecuencia actual" "$($c.CurrentClockSpeed) MHz"
    ROW "  Cache L2 / L3" "$($c.L2CacheSize) KB / $($c.L3CacheSize) KB"
    ROW "  Carga" "$($c.LoadPercentage)%"
    ROW "  Virtualizacion" $c.VirtualizationFirmwareEnabled
}

HR "MEMORIA RAM"
$tot = $cs.TotalPhysicalMemory
$libre = $os.FreePhysicalMemory * 1KB
$uso = [math]::Round((($tot - $libre) / $tot) * 100, 1)
ROW "Total instalada" (Human $tot)
ROW "En uso" "$(Human ($tot - $libre))   ($uso%)"
ROW "Disponible" (Human $libre)
ROW "Ranuras usadas" "$((Get-CimInstance Win32_PhysicalMemory).Count) de $((Get-CimInstance Win32_PhysicalMemoryArray).MemoryDevices)"
foreach ($r in Get-CimInstance Win32_PhysicalMemory) {
    $tipo = switch ($r.SMBIOSMemoryType) { 20 {"DDR"} 21 {"DDR2"} 24 {"DDR3"} 26 {"DDR4"} 34 {"DDR5"} 30 {"DDR5"} default {"Tipo $($r.SMBIOSMemoryType)"} }
    ROW "  $($r.DeviceLocator)" "$(Human $r.Capacity)  $tipo  $($r.Speed) MHz  $($r.Manufacturer)  P/N $($r.PartNumber)"
}

HR "ALMACENAMIENTO"
foreach ($d in Get-PhysicalDisk -ErrorAction SilentlyContinue) {
    ROW $d.FriendlyName "$(Human $d.Size)  $($d.MediaType)  $($d.BusType)  salud: $($d.HealthStatus)"
    $rel = $d | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if ($rel.PowerOnHours) { ROW "  Horas de uso" "$($rel.PowerOnHours) h" }
    if ($rel.Wear -ne $null) { ROW "  Desgaste" "$($rel.Wear)%" }
}
foreach ($v in Get-Volume | Where-Object DriveLetter) {
    if ($v.Size -gt 0) {
        $p = [math]::Round((($v.Size - $v.SizeRemaining) / $v.Size) * 100, 1)
        ROW "  $($v.DriveLetter): $($v.FileSystemLabel)" "$(Human ($v.Size - $v.SizeRemaining)) de $(Human $v.Size)  ($p% usado)  $($v.FileSystem)"
    }
}

HR "GRAFICOS Y PANTALLAS"
foreach ($g in Get-CimInstance Win32_VideoController) {
    ROW $g.Name "driver $($g.DriverVersion)  ($($g.DriverDate))"
    ROW "  Memoria" (Human $g.AdapterRAM)
    ROW "  Resolucion" "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate) Hz"
}
Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | ForEach-Object {
    $n = ($_.UserFriendlyName | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ }) -join ""
    $m = ($_.ManufacturerName | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ }) -join ""
    ROW "  Monitor" "$m $n"
}

HR "RED"
foreach ($a in Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq "Up") {
    $c = Get-NetIPConfiguration -InterfaceIndex $a.ifIndex -ErrorAction SilentlyContinue
    ROW $a.Name "$($a.InterfaceDescription)"
    ROW "  Velocidad / MAC" "$($a.LinkSpeed)  |  $($a.MacAddress)"
    ROW "  IPv4 / Gateway" "$($c.IPv4Address.IPAddress)  |  $($c.IPv4DefaultGateway.NextHop)"
    ROW "  DNS" ($c.DNSServer.ServerAddresses -join ", ")
}

HR "ENERGIA"
$bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
if ($bat) { ROW "Bateria" "$($bat.Name)  carga: $($bat.EstimatedChargeRemaining)%" } else { ROW "Bateria" "No aplica (equipo de escritorio)" }
ROW "Plan de energia" ((powercfg /getactivescheme) -replace ".*\(", "" -replace "\)", "")

HR "TOP 10 PROCESOS POR MEMORIA"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
    ROW $_.ProcessName "$(Human $_.WorkingSet64)   PID $($_.Id)"
}
HR "DIAGNOSTICO COMPLETADO"
'@

    # ========================= HERRAMIENTAS =========================
    T -Id 'tools-godmode' -Cat 'tools' -Icon 'E8D7' -Risk 'safe' -Run 'inline' `
        -Name 'Crear God Mode' -Desc 'Carpeta en el escritorio con las 260 opciones del Panel de control' -Code @'
HR "GOD MODE"
$p = Join-Path ([Environment]::GetFolderPath("Desktop")) "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
if (Test-Path $p) { OK "Ya existe en el escritorio." }
else { New-Item -Path $p -ItemType Directory -Force | Out-Null; OK "Creado: $p" }
Start-Process explorer.exe $p
'@

    T -Id 'tools-sysinternals' -Cat 'tools' -Icon 'EC7A' -Risk 'safe' -Run 'inline' `
        -Name 'Suite Sysinternals' -Desc 'Descarga Autoruns, Process Explorer, TCPView y el resto de la suite' -Code @'
HR "SYSINTERNALS SUITE"
$dst = BSDir "herramientas\Sysinternals"
$zip = Join-Path $env:TEMP "SysinternalsSuite.zip"
try {
    INFO "Descargando (unos 50 MB)..."
    Invoke-WebRequest "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile $zip -UseBasicParsing -ErrorAction Stop
    Expand-Archive $zip -DestinationPath $dst -Force
    $n = (Get-ChildItem $dst -Filter *.exe).Count
    OK "$n utilidades disponibles en $dst"
    INFO "Las mas usadas: Autoruns64, procexp64, procmon64, tcpview64, RAMMap64, Bginfo64."
    Start-Process explorer.exe $dst
} catch { ERR "Fallo la descarga: $($_.Exception.Message)"; INFO "Alternativa en vivo: \\live.sysinternals.com\tools" }
'@

    T -Id 'tools-uninstaller' -Cat 'tools' -Icon 'E74D' -Risk 'safe' -Run 'term' `
        -Name 'Desinstalador de programas' -Desc 'Lista todo lo instalado por winget y permite desinstalar en lote' -Code @'
HR "DESINSTALADOR"
if (-not (Need-Winget)) { Start-Process "appwiz.cpl"; return }
Step "Programas gestionables por winget"
winget list --accept-source-agreements
Write-Host ""
INFO "Para desinstalar:  winget uninstall --id <IdDelPaquete>"
INFO "Panel clasico de Programas y caracteristicas abierto en paralelo."
Start-Process "appwiz.cpl"
Start-Process "ms-settings:appsfeatures"
'@

    T -Id 'tools-backup-profile' -Cat 'tools' -Icon 'E74E' -Risk 'safe' -Run 'inline' `
        -Name 'Respaldar datos del usuario' -Desc 'Copia Escritorio, Documentos, Imagenes, Videos y Favoritos a la ruta que elijas' -Code @'
HR "RESPALDO DEL PERFIL"
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.FolderBrowserDialog
$dlg.Description = "Elige el destino del respaldo (USB o disco externo)"
$dlg.ShowNewFolderButton = $true
if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { WARN "Cancelado."; return }
$dst = Join-Path $dlg.SelectedPath ("Respaldo_" + $env:USERNAME + "_" + (Stamp))
New-Item $dst -ItemType Directory -Force | Out-Null
INFO "Destino: $dst"

$carpetas = @("Desktop","Documents","Pictures","Videos","Music","Downloads","Favorites")
$total = 0
foreach ($c in $carpetas) {
    $src = Join-Path $env:USERPROFILE $c
    if (-not (Test-Path $src)) { continue }
    $sz = Get-Folder-Size $src
    Step "$c  ($(Human $sz))"
    $out = Join-Path $dst $c
    robocopy $src $out /E /R:1 /W:1 /NFL /NDL /NJH /NJS /MT:16 | Out-Null
    $total += $sz
    OK "$c copiado."
}
Step "Exportando favoritos de navegadores"
foreach ($b in @(@{n="Chrome";p="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks"},
                 @{n="Edge";p="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"},
                 @{n="Brave";p="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Bookmarks"})) {
    if (Test-Path $b.p) { Copy-Item $b.p (Join-Path $dst "Marcadores_$($b.n).json") -Force; OK "Marcadores de $($b.n)" }
}
HR ("RESPALDO COMPLETADO: " + (Human $total) + " en " + $dst)
Start-Process explorer.exe $dst
'@

    T -Id 'tools-maint-task' -Cat 'tools' -Icon 'E823' -Risk 'care' -Run 'inline' `
        -Name 'Mantenimiento automatico semanal' -Desc 'Crea una tarea programada que limpia temporales y actualiza software cada domingo' -Code @'
HR "MANTENIMIENTO PROGRAMADO"
$dir = BSDir "auto"
$script = Join-Path $dir "mantenimiento.ps1"
$cuerpo = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$log = Join-Path `$env:USERPROFILE 'Documents\ToolboxBS\logs\auto_' + (Get-Date -Format 'yyyyMMdd') + '.log'
Start-Transcript -Path `$log -Append
Write-Output "Mantenimiento ToolboxBS - `$(Get-Date)"
Get-ChildItem `$env:TEMP -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem "`$env:SystemRoot\Temp" -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Clear-DnsClientCache
Update-MpSignature -ErrorAction SilentlyContinue
Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue
if (Get-Command winget.exe -ErrorAction SilentlyContinue) { winget upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements }
Optimize-Volume -DriveLetter `$env:SystemDrive[0] -ReTrim -ErrorAction SilentlyContinue
Checkpoint-Computer -Description "Mantenimiento semanal ToolboxBS" -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue
Stop-Transcript
"@
$cuerpo | Set-Content $script -Encoding UTF8
OK "Script creado: $script"

$acc = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$dis = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 11:00AM
$cfg = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 2)
$prc = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
try {
    Register-ScheduledTask -TaskName "ToolboxBS - Mantenimiento semanal" -Action $acc -Trigger $dis -Settings $cfg -Principal $prc -Force -ErrorAction Stop | Out-Null
    OK "Tarea registrada: se ejecuta los domingos a las 11:00."
    INFO "Para quitarla: Unregister-ScheduledTask -TaskName 'ToolboxBS - Mantenimiento semanal'"
} catch { ERR "No se pudo registrar la tarea: $($_.Exception.Message)" }
'@ -Revert @'
Unregister-ScheduledTask -TaskName "ToolboxBS - Mantenimiento semanal" -Confirm:$false -ErrorAction SilentlyContinue
OK "Mantenimiento automatico desactivado."
'@

    T -Id 'tools-restore-manager' -Cat 'tools' -Icon 'E792' -Risk 'safe' -Run 'inline' `
        -Name 'Gestor de puntos de restauracion' -Desc 'Lista los puntos existentes, el espacio que ocupan y abre el asistente' -Code @'
HR "PUNTOS DE RESTAURACION"
$pts = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
if ($pts) {
    $pts | ForEach-Object { ROW ("#" + $_.SequenceNumber) "$($_.ConvertToDateTime($_.CreationTime))  |  $($_.Description)" }
} else { WARN "No hay puntos de restauracion." }
Step "Configuracion de proteccion"
vssadmin list shadowstorage
Step "Estado por unidad"
Get-CimInstance -Namespace root\default -ClassName SystemRestoreConfig -ErrorAction SilentlyContinue | Format-List | Out-String | Write-Host
INFO "Abriendo el asistente de restauracion del sistema."
Start-Process "rstrui.exe"
'@

    T -Id 'tools-hosts-edit' -Cat 'tools' -Icon 'E70F' -Risk 'safe' -Run 'inline' `
        -Name 'Editar archivo hosts' -Desc 'Abre hosts en Notepad con permisos y crea copia de seguridad antes' -Code @'
$h = "$env:SystemRoot\System32\drivers\etc\hosts"
$b = Join-Path (BSDir "backups") ("hosts_" + (Stamp) + ".txt")
Copy-Item $h $b -Force
OK "Copia de seguridad: $b"
Start-Process notepad.exe -ArgumentList "`"$h`""
INFO "Tras editar, ejecuta 'Vaciar cache DNS' para que los cambios apliquen."
'@

    T -Id 'tools-admin-account' -Cat 'tools' -Icon 'E77B' -Risk 'danger' -Run 'inline' `
        -Name 'Cuenta Administrador integrada' -Desc 'Activa la cuenta oculta de Administrador para rescatar un equipo bloqueado' -Code @'
HR "CUENTA ADMINISTRADOR INTEGRADA"
$u = Get-LocalUser | Where-Object { $_.SID -like "*-500" }
if (-not $u) { ERR "No se encontro la cuenta integrada."; return }
ROW "Cuenta" $u.Name
ROW "Estado actual" $(if ($u.Enabled) { "HABILITADA" } else { "deshabilitada" })
if ($u.Enabled) {
    WARN "Ya esta habilitada. Se deshabilitara por seguridad."
    Disable-LocalUser -Name $u.Name
    OK "$($u.Name) deshabilitada."
} else {
    Enable-LocalUser -Name $u.Name
    OK "$($u.Name) habilitada. Aparecera en la pantalla de inicio de sesion."
    WARN "Asignale una contrasena y vuelve a deshabilitarla cuando termines."
}
net user $u.Name
'@

    T -Id 'tools-env' -Cat 'tools' -Icon 'E713' -Risk 'safe' -Run 'inline' `
        -Name 'Variables de entorno y PATH' -Desc 'Revisa el PATH, detecta rutas rotas y abre el editor del sistema' -Code @'
HR "VARIABLES DE ENTORNO"
Step "PATH del sistema"
$sys = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" | Where-Object { $_ }
foreach ($p in $sys) { if (Test-Path $p) { ROW "OK" $p } else { ERR "ROTA  $p" } }
Step "PATH del usuario"
$usr = [Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Where-Object { $_ }
foreach ($p in $usr) { if (Test-Path $p) { ROW "OK" $p } else { ERR "ROTA  $p" } }
Step "Variables destacadas"
foreach ($v in @("TEMP","TMP","USERPROFILE","ProgramFiles","SystemRoot","COMPUTERNAME","NUMBER_OF_PROCESSORS","PROCESSOR_ARCHITECTURE")) {
    ROW $v ([Environment]::GetEnvironmentVariable($v))
}
Start-Process "rundll32.exe" -ArgumentList "sysdm.cpl,EditEnvironmentVariables"
'@

    T -Id 'tools-shell-folders' -Cat 'tools' -Icon 'E838' -Risk 'safe' -Run 'inline' `
        -Name 'Carpetas del sistema' -Desc 'Abre de golpe Inicio, Enviar a, Plantillas y otras carpetas ocultas utiles' -Code @'
HR "CARPETAS ESPECIALES"
$c = @("shell:startup","shell:common startup","shell:sendto","shell:appsFolder","shell:RecycleBinFolder")
foreach ($x in $c) { INFO "Abriendo $x"; Start-Process explorer.exe $x; Start-Sleep -Milliseconds 400 }
OK "Carpetas abiertas."
INFO "shell:startup = programas que arrancan con tu usuario."
INFO "shell:appsFolder = todas las apps instaladas, incluidas las de la Store."
'@

    T -Id 'tools-download-windows' -Cat 'tools' -Icon 'E896' -Risk 'safe' -Run 'inline' `
        -Name 'Descargar Windows ISO' -Desc 'Abre el portal de descargas de imagenes de ToolboxBS' -Code @'
Start-Process "https://brandonsepulveda.github.io/descargawindows.html"
OK "Portal de descargas abierto."
'@

    T -Id 'tools-windeploy' -Cat 'tools' -Icon 'E90F' -Risk 'care' -Run 'term' `
        -Name 'WinDeploy' -Desc 'Despliegue post-formateo desde la nube' -Code @'
HR "WINDEPLOY"
Invoke-Expression (Invoke-RestMethod "https://cutt.ly/Windeploy")
'@

    T -Id 'tools-open-logs' -Cat 'tools' -Icon 'E838' -Risk 'safe' -Run 'inline' `
        -Name 'Abrir carpeta de ToolboxBS' -Desc 'Reportes, logs, respaldos y perfiles generados por la herramienta' -Code @'
$p = Join-Path $env:USERPROFILE "Documents\ToolboxBS"
OK "Carpeta: $p"
Get-ChildItem $p -Directory | ForEach-Object {
    $n = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
    ROW $_.Name "$n archivos  ($(Human (Get-Folder-Size $_.FullName)))"
}
Start-Process explorer.exe $p
'@
)

# --- Consolas y paneles nativos: se generan en bloque ---
$Global:Consolas = @(
    @{ id = 'taskmgr';    n = 'Administrador de tareas';   d = 'Procesos, rendimiento e inicio'; i = 'E9D9'; c = 'taskmgr.exe' }
    @{ id = 'devmgmt';    n = 'Administrador de dispositivos'; d = 'Drivers y hardware'; i = 'E7F8'; c = 'devmgmt.msc' }
    @{ id = 'services';   n = 'Servicios';                 d = 'Arranque y estado de servicios'; i = 'E713'; c = 'services.msc' }
    @{ id = 'diskmgmt';   n = 'Administracion de discos';  d = 'Particiones y volumenes'; i = 'EDA2'; c = 'diskmgmt.msc' }
    @{ id = 'eventvwr';   n = 'Visor de eventos';          d = 'Registros del sistema'; i = 'E8F1'; c = 'eventvwr.msc' }
    @{ id = 'regedit';    n = 'Editor del registro';       d = 'Claves y valores'; i = 'E70F'; c = 'regedit.exe' }
    @{ id = 'compmgmt';   n = 'Administracion del equipo'; d = 'Consola unificada'; i = 'EC7A'; c = 'compmgmt.msc' }
    @{ id = 'taskschd';   n = 'Programador de tareas';     d = 'Tareas automaticas'; i = 'E823'; c = 'taskschd.msc' }
    @{ id = 'lusrmgr';    n = 'Usuarios y grupos locales'; d = 'Cuentas del equipo'; i = 'E77B'; c = 'lusrmgr.msc' }
    @{ id = 'gpedit';     n = 'Directivas de grupo';       d = 'Politicas locales (solo Pro)'; i = 'E8A5'; c = 'gpedit.msc' }
    @{ id = 'perfmon';    n = 'Monitor de rendimiento';    d = 'Contadores en detalle'; i = 'EB05'; c = 'perfmon.msc' }
    @{ id = 'resmon';     n = 'Monitor de recursos';       d = 'CPU, disco, red y memoria en vivo'; i = 'E9D9'; c = 'resmon.exe' }
    @{ id = 'msconfig';   n = 'Configuracion del sistema'; d = 'Arranque y servicios'; i = 'E713'; c = 'msconfig.exe' }
    @{ id = 'sysdm';      n = 'Propiedades del sistema';   d = 'Nombre, restauracion y rendimiento'; i = 'E770'; c = 'sysdm.cpl' }
    @{ id = 'appwiz';     n = 'Programas y caracteristicas'; d = 'Desinstalar software'; i = 'E74D'; c = 'appwiz.cpl' }
    @{ id = 'ncpa';       n = 'Conexiones de red';         d = 'Adaptadores'; i = 'E839'; c = 'ncpa.cpl' }
    @{ id = 'powercfg';   n = 'Opciones de energia';       d = 'Planes de energia'; i = 'E945'; c = 'powercfg.cpl' }
    @{ id = 'optional';   n = 'Caracteristicas de Windows'; d = 'Activar o desactivar componentes'; i = 'E950'; c = 'optionalfeatures.exe' }
    @{ id = 'cleanmgr';   n = 'Liberador de espacio';      d = 'Limpieza clasica'; i = 'E74D'; c = 'cleanmgr.exe' }
    @{ id = 'control';    n = 'Panel de control';          d = 'Panel clasico completo'; i = 'E74C'; c = 'control.exe' }
    @{ id = 'settings';   n = 'Configuracion de Windows';  d = 'App moderna de ajustes'; i = 'E713'; c = 'ms-settings:' }
    @{ id = 'winupdate';  n = 'Windows Update';            d = 'Buscar actualizaciones'; i = 'E895'; c = 'ms-settings:windowsupdate' }
    @{ id = 'defenderui'; n = 'Seguridad de Windows';      d = 'Centro de seguridad'; i = 'EA18'; c = 'windowsdefender:' }
    @{ id = 'mstsc';      n = 'Escritorio remoto';         d = 'Conectar a otro equipo'; i = 'E8AF'; c = 'mstsc.exe' }
    @{ id = 'msinfo';     n = 'Informacion del sistema';   d = 'msinfo32 completo'; i = 'E946'; c = 'msinfo32.exe' }
    @{ id = 'dxdiag';     n = 'Diagnostico DirectX';       d = 'GPU, sonido y entrada'; i = 'E7FC'; c = 'dxdiag.exe' }
    @{ id = 'psconsole';  n = 'Consola PowerShell';        d = 'Terminal elevada'; i = 'E756'; c = 'powershell.exe' }
    @{ id = 'wingetcli';  n = 'Consola Winget';            d = 'Gestor de paquetes'; i = 'E710'; c = 'winget-console' }
)

foreach ($c in $Global:Consolas) {
    $cmd = $c.c
    $code = if ($cmd -eq 'winget-console') {
        'Start-Process $env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe -ArgumentList "-NoExit","-Command","winget --info"' + "`nOK 'Consola winget abierta.'"
    } elseif ($cmd -like "*:*") {
        "Start-Process '$cmd'`nOK 'Abierto: $($c.n)'"
    } else {
        "Start-Process '$cmd'`nOK 'Abierto: $($c.n)'"
    }
    $Global:Catalog += (T -Id "abrir-$($c.id)" -Name $c.n -Desc $c.d -Icon $c.i -Cat 'tools' -Risk 'safe' -Run 'inline' -Code $code)
}

# ============================================================================
#  6. REPOSITORIO DE APLICACIONES
#     Cada app se convierte en una herramienta de la categoria 'apps', asi
#     reutiliza busqueda, seleccion multiple, perfiles y consola integrada.
# ============================================================================
$Global:Apps = @(
    # --- Navegadores ---
    @{ n = 'Google Chrome';        g = 'Navegadores'; w = 'Google.Chrome';                   c = 'googlechrome';     d = 'El navegador mas usado del mundo' }
    @{ n = 'Brave';                g = 'Navegadores'; w = 'Brave.Brave';                     c = 'brave';            d = 'Rapido y con bloqueo de anuncios integrado' }
    @{ n = 'Mozilla Firefox';      g = 'Navegadores'; w = 'Mozilla.Firefox';                 c = 'firefox';          d = 'Navegador independiente centrado en privacidad' }
    @{ n = 'Opera GX';             g = 'Navegadores'; w = 'Opera.OperaGX';                   c = 'operagx';          d = 'Navegador para gamers con limitador de recursos' }

    # --- Utilidades esenciales ---
    @{ n = '7-Zip';                g = 'Esenciales';  w = '7zip.7zip';                       c = '7zip';             d = 'Compresor de archivos open source' }
    @{ n = 'NanaZip';              g = 'Esenciales';  w = 'M2Team.NanaZip';                  c = 'nanazip';          d = 'Fork moderno de 7-Zip integrado en Windows 11' }
    @{ n = 'WinRAR';               g = 'Esenciales';  w = 'RARLab.WinRAR';                   c = 'winrar';           d = 'Compresor clasico con soporte RAR' }
    @{ n = 'Adobe Acrobat Reader'; g = 'Esenciales';  w = 'Adobe.Acrobat.Reader.64-bit';     c = 'adobereader';      d = 'Lector de PDF de referencia' }
    @{ n = 'SumatraPDF';           g = 'Esenciales';  w = 'SumatraPDF.SumatraPDF';           c = 'sumatrapdf';       d = 'Lector de PDF ultraligero' }
    @{ n = 'Notepad++';            g = 'Esenciales';  w = 'Notepad++.Notepad++';             c = 'notepadplusplus';  d = 'Editor de texto con resaltado de sintaxis' }
    @{ n = 'VLC Media Player';     g = 'Esenciales';  w = 'VideoLAN.VLC';                    c = 'vlc';              d = 'Reproduce cualquier formato de video y audio' }
    @{ n = 'K-Lite Codec Pack';    g = 'Esenciales';  w = 'CodecGuide.K-LiteCodecPack.Standard'; c = 'k-litecodecpackstandard'; d = 'Codecs para reproducir todo en Windows' }
    @{ n = 'Microsoft PowerToys';  g = 'Esenciales';  w = 'Microsoft.PowerToys';             c = 'powertoys';        d = 'Utilidades avanzadas: FancyZones, PowerRename, Peek' }
    @{ n = 'Everything';           g = 'Esenciales';  w = 'voidtools.Everything';            c = 'everything';       d = 'Busca cualquier archivo del disco al instante' }
    @{ n = 'Windows Terminal';     g = 'Esenciales';  w = 'Microsoft.WindowsTerminal';       c = 'microsoft-windows-terminal'; d = 'Terminal moderna con pestanas' }
    @{ n = 'PowerShell 7';         g = 'Esenciales';  w = 'Microsoft.PowerShell';            c = 'powershell-core';  d = 'PowerShell multiplataforma actualizado' }
    @{ n = 'Greenshot';            g = 'Esenciales';  w = 'Greenshot.Greenshot';             c = 'greenshot';        d = 'Capturas de pantalla con anotaciones' }
    @{ n = 'ShareX';               g = 'Esenciales';  w = 'ShareX.ShareX';                   c = 'sharex';           d = 'Capturas, grabacion y subida automatica' }

    # --- Ofimatica ---
    @{ n = 'LibreOffice';          g = 'Ofimatica';   w = 'TheDocumentFoundation.LibreOffice'; c = 'libreoffice-fresh'; d = 'Suite ofimatica libre compatible con Office' }
    @{ n = 'Microsoft 365';        g = 'Ofimatica';   w = 'Microsoft.Office';                c = 'office365business'; d = 'Instalador de Office / Microsoft 365' }
    @{ n = 'OnlyOffice';           g = 'Ofimatica';   w = 'ONLYOFFICE.DesktopEditors';       c = 'onlyoffice';       d = 'Suite con maxima compatibilidad con formatos de Office' }
    @{ n = 'Obsidian';             g = 'Ofimatica';   w = 'Obsidian.Obsidian';               c = 'obsidian';         d = 'Notas en Markdown enlazadas' }
    @{ n = 'Notion';               g = 'Ofimatica';   w = 'Notion.Notion';                   c = 'notion';           d = 'Espacio de trabajo todo en uno' }

    # --- Diagnostico y hardware ---
    @{ n = 'CPU-Z';                g = 'Diagnostico'; w = 'CPUID.CPU-Z';                     c = 'cpu-z';            d = 'Identifica CPU, placa base y memoria' }
    @{ n = 'GPU-Z';                g = 'Diagnostico'; w = 'TechPowerUp.GPU-Z';               c = 'gpu-z';            d = 'Detalle completo de la tarjeta grafica' }
    @{ n = 'HWiNFO';               g = 'Diagnostico'; w = 'REALiX.HWiNFO';                   c = 'hwinfo';           d = 'Sensores y temperaturas de todo el equipo' }
    @{ n = 'CrystalDiskInfo';      g = 'Diagnostico'; w = 'CrystalDewWorld.CrystalDiskInfo'; c = 'crystaldiskinfo';  d = 'Salud SMART de discos duros y SSD' }
    @{ n = 'CrystalDiskMark';      g = 'Diagnostico'; w = 'CrystalDewWorld.CrystalDiskMark'; c = 'crystaldiskmark';  d = 'Mide la velocidad real del disco' }
    @{ n = 'HD Sentinel';          g = 'Diagnostico'; w = 'JanosMathe.HardDiskSentinel.Professional'; c = '';        d = 'Monitorea y predice fallos de disco' }
    @{ n = 'AIDA64 Extreme';       g = 'Diagnostico'; w = 'FinalWire.AIDA64.Extreme';        c = '';                 d = 'Diagnostico y benchmark profesional (trial)' }
    @{ n = 'OCCT';                 g = 'Diagnostico'; w = 'OCBase.OCCT.Personal';            c = '';                 d = 'Prueba de estres de CPU, GPU y fuente' }
    @{ n = 'MemTest86';            g = 'Diagnostico'; w = 'PassMark.MemTest86';              c = '';                 d = 'Prueba exhaustiva de memoria RAM arrancable' }
    @{ n = 'WizTree';              g = 'Diagnostico'; w = 'AntibodySoftware.WizTree';        c = 'wiztree';          d = 'Analiza que ocupa el disco en segundos' }
    @{ n = 'WinDirStat';           g = 'Diagnostico'; w = 'WinDirStat.WinDirStat';           c = 'windirstat';       d = 'Mapa visual del uso de disco' }

    # --- Mantenimiento y limpieza ---
    @{ n = 'Revo Uninstaller';     g = 'Mantenimiento'; w = 'RevoUninstaller.RevoUninstaller'; c = 'revo-uninstaller'; d = 'Desinstala dejando el registro limpio' }
    @{ n = 'BCUninstaller';        g = 'Mantenimiento'; w = 'Klocman.BulkCrapUninstaller';   c = 'bulk-crap-uninstaller'; d = 'Desinstalacion masiva de programas' }
    @{ n = 'BleachBit';            g = 'Mantenimiento'; w = 'BleachBit.BleachBit';           c = 'bleachbit';        d = 'Limpieza profunda open source' }
    @{ n = 'TreeSize Free';        g = 'Mantenimiento'; w = 'JAMSoftware.TreeSize.Free';     c = 'treesizefree';     d = 'Encuentra las carpetas que llenan el disco' }
    @{ n = 'Autoruns';             g = 'Mantenimiento'; w = 'Microsoft.Sysinternals.Autoruns'; c = 'autoruns';       d = 'Control total de lo que arranca con Windows' }
    @{ n = 'Process Explorer';     g = 'Mantenimiento'; w = 'Microsoft.Sysinternals.ProcessExplorer'; c = 'procexp'; d = 'Administrador de tareas con esteroides' }
    @{ n = 'Sysinternals Suite';   g = 'Mantenimiento'; w = 'Microsoft.Sysinternals.Suite';  c = 'sysinternals';     d = 'Toda la suite de utilidades de Microsoft' }
    @{ n = 'UniGetUI';             g = 'Mantenimiento'; w = 'MartiCliment.UniGetUI';         c = 'wingetui';         d = 'Interfaz grafica para winget, choco y scoop' }
    @{ n = 'Chocolatey';           g = 'Mantenimiento'; w = 'Chocolatey.Chocolatey';         c = '';                 d = 'Gestor de paquetes alternativo' }

    # --- Arranque e instalacion ---
    @{ n = 'Rufus';                g = 'Instalacion'; w = 'Rufus.Rufus';                     c = 'rufus';            d = 'Crea USB de arranque desde una ISO' }
    @{ n = 'Ventoy';               g = 'Instalacion'; w = 'Ventoy.Ventoy';                   c = 'ventoy';           d = 'Un USB con multiples ISO arrancables' }
    @{ n = 'balenaEtcher';         g = 'Instalacion'; w = 'Balena.Etcher';                   c = 'etcher';           d = 'Graba imagenes en USB y tarjetas SD' }
    @{ n = 'Macrium Reflect Free'; g = 'Instalacion'; w = 'Macrium.ReflectFree';             c = '';                 d = 'Clonado y respaldo completo de disco' }
    @{ n = 'Veeam Agent';          g = 'Instalacion'; w = 'Veeam.VeeamAgent';                c = '';                 d = 'Respaldo de imagen del sistema' }

    # --- Remoto y comunicacion ---
    @{ n = 'AnyDesk';              g = 'Remoto';      w = 'AnyDeskSoftwareGmbH.AnyDesk';     c = 'anydesk';          d = 'Escritorio remoto rapido y ligero' }
    @{ n = 'TeamViewer';           g = 'Remoto';      w = 'TeamViewer.TeamViewer';           c = 'teamviewer';       d = 'Soporte remoto empresarial' }
    @{ n = 'RustDesk';             g = 'Remoto';      w = 'RustDesk.RustDesk';               c = 'rustdesk';         d = 'Alternativa open source y autoalojable' }
    @{ n = 'Zoom';                 g = 'Remoto';      w = 'Zoom.Zoom';                       c = 'zoom';             d = 'Videollamadas y reuniones' }
    @{ n = 'Microsoft Teams';      g = 'Remoto';      w = 'Microsoft.Teams';                 c = 'microsoft-teams';  d = 'Colaboracion y reuniones de Microsoft' }
    @{ n = 'Discord';              g = 'Remoto';      w = 'Discord.Discord';                 c = 'discord';          d = 'Chat de voz, video y texto' }
    @{ n = 'WhatsApp';             g = 'Remoto';      w = '9NKSQGP7F2NH';                    c = '';                 d = 'Cliente de escritorio de WhatsApp' }
    @{ n = 'Telegram';             g = 'Remoto';      w = 'Telegram.TelegramDesktop';        c = 'telegram';         d = 'Mensajeria rapida y multiplataforma' }

    # --- Desarrollo ---
    @{ n = 'Visual Studio Code';   g = 'Desarrollo';  w = 'Microsoft.VisualStudioCode';      c = 'vscode';           d = 'Editor de codigo de Microsoft' }
    @{ n = 'Git';                  g = 'Desarrollo';  w = 'Git.Git';                         c = 'git';              d = 'Control de versiones' }
    @{ n = 'Node.js LTS';          g = 'Desarrollo';  w = 'OpenJS.NodeJS.LTS';               c = 'nodejs-lts';       d = 'Entorno de ejecucion JavaScript' }
    @{ n = 'Python 3';             g = 'Desarrollo';  w = 'Python.Python.3.12';              c = 'python';           d = 'Lenguaje Python con pip' }
    @{ n = 'Docker Desktop';       g = 'Desarrollo';  w = 'Docker.DockerDesktop';            c = 'docker-desktop';   d = 'Contenedores en Windows' }
    @{ n = 'WinSCP';               g = 'Desarrollo';  w = 'WinSCP.WinSCP';                   c = 'winscp';           d = 'Cliente SFTP y FTP grafico' }
    @{ n = 'PuTTY';                g = 'Desarrollo';  w = 'PuTTY.PuTTY';                     c = 'putty';            d = 'Cliente SSH clasico' }
    @{ n = 'FileZilla';            g = 'Desarrollo';  w = 'TimKosse.FileZilla.Client';       c = 'filezilla';        d = 'Cliente FTP multiplataforma' }

    # --- Seguridad ---
    @{ n = 'Malwarebytes';         g = 'Seguridad';   w = 'Malwarebytes.Malwarebytes';       c = 'malwarebytes';     d = 'Segunda opinion contra malware' }
    @{ n = 'Bitwarden';            g = 'Seguridad';   w = 'Bitwarden.Bitwarden';             c = 'bitwarden';        d = 'Gestor de contrasenas open source' }
    @{ n = 'KeePassXC';            g = 'Seguridad';   w = 'KeePassXCTeam.KeePassXC';         c = 'keepassxc';        d = 'Boveda de contrasenas local' }
    @{ n = 'VeraCrypt';            g = 'Seguridad';   w = 'IDRIX.VeraCrypt';                 c = 'veracrypt';        d = 'Cifrado de discos y contenedores' }
    @{ n = 'Wireshark';            g = 'Seguridad';   w = 'WiresharkFoundation.Wireshark';   c = 'wireshark';        d = 'Analizador de trafico de red' }
    @{ n = 'Advanced IP Scanner';  g = 'Seguridad';   w = 'Famatech.AdvancedIPScanner';      c = 'advanced-ip-scanner'; d = 'Escanea equipos de la red local' }

    # --- Multimedia y diseno ---
    @{ n = 'GIMP';                 g = 'Multimedia';  w = 'GIMP.GIMP';                       c = 'gimp';             d = 'Edicion de imagen profesional y libre' }
    @{ n = 'Paint.NET';            g = 'Multimedia';  w = 'dotPDNLLC.paintdotnet';           c = 'paint.net';        d = 'Editor de imagen sencillo y potente' }
    @{ n = 'Inkscape';             g = 'Multimedia';  w = 'Inkscape.Inkscape';               c = 'inkscape';         d = 'Diseno vectorial' }
    @{ n = 'OBS Studio';           g = 'Multimedia';  w = 'OBSProject.OBSStudio';            c = 'obs-studio';       d = 'Grabacion y transmision en vivo' }
    @{ n = 'HandBrake';            g = 'Multimedia';  w = 'HandBrake.HandBrake';             c = 'handbrake';        d = 'Conversor de video' }
    @{ n = 'Audacity';             g = 'Multimedia';  w = 'Audacity.Audacity';               c = 'audacity';         d = 'Edicion de audio multipista' }
    @{ n = 'Spotify';              g = 'Multimedia';  w = 'Spotify.Spotify';                 c = 'spotify';          d = 'Musica en streaming' }

    # --- Fabricantes ---
    @{ n = 'Dell Command Update';  g = 'Fabricantes'; w = 'Dell.CommandUpdate';              c = '';                 d = 'Drivers y BIOS oficiales de Dell' }
    @{ n = 'HP Support Assistant'; g = 'Fabricantes'; w = 'HP.SupportAssistant';             c = '';                 d = 'Soporte y drivers de HP' }
    @{ n = 'HP Image Assistant';   g = 'Fabricantes'; w = 'HP.ImageAssistant';               c = '';                 d = 'Gestion de imagenes y drivers HP' }
    @{ n = 'Lenovo System Update'; g = 'Fabricantes'; w = 'Lenovo.SystemUpdate';             c = '';                 d = 'Drivers y BIOS de Lenovo' }
    @{ n = 'Lenovo Vantage';       g = 'Fabricantes'; w = '9WZDNCRFJ4MV';                    c = '';                 d = 'Centro de control Lenovo' }
    @{ n = 'MyASUS';               g = 'Fabricantes'; w = '9N7R5S6B0ZZH';                    c = '';                 d = 'Soporte y diagnostico ASUS' }
    @{ n = 'Intel DSA';            g = 'Fabricantes'; w = 'Intel.IntelDriverAndSupportAssistant'; c = '';            d = 'Actualiza drivers Intel' }
    @{ n = 'NVIDIA App';           g = 'Fabricantes'; w = 'Nvidia.app';                      c = '';                 d = 'Drivers y optimizacion NVIDIA' }
    @{ n = 'AMD Adrenalin';        g = 'Fabricantes'; w = 'AMD.AMDSoftwareAdrenalinEdition'; c = '';                 d = 'Drivers y control Radeon' }
    @{ n = 'NZXT CAM';             g = 'Fabricantes'; w = 'NZXT.CAM';                        c = '';                 d = 'Monitorizacion de hardware NZXT' }
)

foreach ($a in $Global:Apps) {
    $id = "app-" + (($a.n -replace '[^a-zA-Z0-9]', '').ToLower())
    $wid = $a.w
    $cid = $a.c
    $nombre = $a.n
    $codigo = @"
HR "INSTALACION: $nombre"
if (-not (Need-Winget)) {
    if ('$cid') { INFO "Intentando con Chocolatey..."; choco install $cid -y }
    return
}
INFO "Paquete: $wid"
winget install --id "$wid" -e --accept-package-agreements --accept-source-agreements --disable-interactivity
if (`$LASTEXITCODE -eq 0) { OK "$nombre instalado correctamente." }
elseif (`$LASTEXITCODE -eq -1978335189) { OK "$nombre ya esta instalado y actualizado." }
else { WARN "winget devolvio el codigo `$LASTEXITCODE para $nombre." }
"@
    $Global:Catalog += (T -Id $id -Name $nombre -Desc "$($a.g) - $($a.d)" -Icon 'E896' -Cat 'apps' -Risk 'safe' -Run 'inline' -Code $codigo)
}

# ------------------------- AMPLIACION DEL CATALOGO -------------------------
$Global:Catalog += @(

    # ---------- REPARACION ----------
    T -Id 'repair-wmi' -Cat 'repair' -Icon 'E950' -Risk 'danger' -Run 'inline' `
        -Name 'Reparar repositorio WMI' -Desc 'Arregla el origen de mil errores raros: informes vacios, Defender mudo, GPO que no aplican' -Code @'
HR "REPOSITORIO WMI"
Step "Comprobando consistencia"
$chk = winmgmt /verifyrepository 2>&1
Write-Host "    $chk"
if ($chk -match "coherente|consistent") {
    OK "El repositorio esta sano. No hace falta reconstruirlo."
    Step "Prueba de consulta"
    try { $null = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; OK "WMI responde correctamente." }
    catch { ERR "WMI no responde pese a estar coherente: $($_.Exception.Message)" }
    return
}
WARN "Repositorio inconsistente. Se procede a repararlo."
Step "Intento 1: salvage (no destructivo)"
winmgmt /salvagerepository
Start-Sleep -Seconds 3
$chk = winmgmt /verifyrepository 2>&1
if ($chk -match "coherente|consistent") { OK "Reparado con salvage."; return }
Step "Intento 2: reconstruccion completa"
Stop-Svc @("Winmgmt")
$repo = "$env:SystemRoot\System32\wbem\Repository"
if (Test-Path $repo) { Rename-Item $repo "$repo.$(Stamp).old" -Force -ErrorAction SilentlyContinue; OK "Repositorio antiguo renombrado." }
Start-Svc @("Winmgmt")
Step "Re-registrando proveedores MOF"
Push-Location "$env:SystemRoot\System32\wbem"
Get-ChildItem *.mof, *.mfl -ErrorAction SilentlyContinue | ForEach-Object { $null = mofcomp.exe $_.Name 2>$null }
Pop-Location
OK "Proveedores recompilados. Reinicia el equipo."
'@

    T -Id 'repair-usb' -Cat 'repair' -Icon 'ECF0' -Risk 'care' -Run 'inline' `
        -Name 'Reparar puertos USB' -Desc 'Quita los controladores USB para que Windows los reinstale limpios al reiniciar' -Code @'
HR "CONTROLADORES USB"
Step "Dispositivos USB con error"
$bad = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 -and ($_.PNPDeviceID -like "USB*" -or $_.Name -match "USB") }
if ($bad) { $bad | ForEach-Object { ERR "$($_.Name)  [codigo $($_.ConfigManagerErrorCode)]" } }
else { OK "Ningun dispositivo USB reporta error." }

Step "Desactivando el ahorro de energia de los concentradores USB"
Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue | ForEach-Object {
    try { $_ | Set-CimInstance -Property @{ Enable = $false } -ErrorAction Stop } catch { }
}
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USB" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
    Set-ItemProperty $_.PSPath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}
OK "Suspension selectiva de USB desactivada (evita que se desconecten solos)."
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 1

Step "Dispositivos USB conectados ahora"
Get-PnpDevice -Class USB -ErrorAction SilentlyContinue | Where-Object Status -eq "OK" |
    Select-Object -First 25 | ForEach-Object { ROW $_.FriendlyName $_.InstanceId }
INFO "Si algun puerto sigue muerto: Administrador de dispositivos > desinstalar los 'Controladores de host' USB y reiniciar."
Start-Process "devmgmt.msc"
'@

    T -Id 'repair-bluetooth' -Cat 'repair' -Icon 'E702' -Risk 'safe' -Run 'inline' `
        -Name 'Reparar Bluetooth' -Desc 'Reinicia la pila de Bluetooth y lista los dispositivos emparejados' -Code @'
HR "BLUETOOTH"
$ad = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue
if (-not $ad) { WARN "Este equipo no tiene adaptador Bluetooth."; return }
Step "Servicios"
Stop-Svc @("BTAGService", "bthserv")
Start-Sleep -Seconds 2
Set-Service bthserv -StartupType Automatic -ErrorAction SilentlyContinue
Start-Svc @("bthserv", "BTAGService")
Step "Reiniciando el adaptador"
$ad | Where-Object { $_.Class -eq "Bluetooth" -and $_.FriendlyName -notmatch "Enumerador|Enumerator" } | Select-Object -First 1 | ForEach-Object {
    try {
        Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 2
        Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop
        OK "Adaptador reiniciado: $($_.FriendlyName)"
    }
    catch { WARN "No se pudo reiniciar: $($_.Exception.Message)" }
}
Step "Dispositivos Bluetooth"
$ad | ForEach-Object { ROW $_.FriendlyName $_.Status }
Start-Process "ms-settings:bluetooth"
'@

    T -Id 'repair-camera' -Cat 'repair' -Icon 'E722' -Risk 'safe' -Run 'inline' `
        -Name 'Reparar camara y microfono' -Desc 'Revisa permisos de privacidad, drivers y que ninguna app los tenga secuestrados' -Code @'
HR "CAMARA Y MICROFONO"
Step "Dispositivos detectados"
Get-PnpDevice -Class Camera, Image, Media -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match "cam|micro|audio|webcam" } |
    ForEach-Object { ROW $_.FriendlyName $_.Status }
Step "Permisos de privacidad del sistema"
foreach ($d in @(@{k = "webcam"; n = "Camara" }, @{k = "microphone"; n = "Microfono" })) {
    $p = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$($d.k)"
    $v = (Get-ItemProperty $p -ErrorAction SilentlyContinue).Value
    ROW $d.n $(if ($v) { $v } else { "no definido" })
    if ($v -eq "Deny") {
        WARN "  $($d.n) bloqueado a nivel de sistema. Habilitando..."
        Set-Reg $p "Value" "Allow" "String"
    }
}
Step "Aplicaciones que estan usando la camara ahora"
$k = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\NonPackaged"
if (Test-Path $k) {
    Get-ChildItem $k | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($p.LastUsedTimeStop -eq 0) { WARN "EN USO: $($_.PSChildName -replace '#','\')" }
    }
}
Step "Procesos que suelen retener la camara"
Get-Process -Name Teams, Zoom, Skype, chrome, msedge, Discord, obs64 -ErrorAction SilentlyContinue |
    ForEach-Object { ROW $_.ProcessName "PID $($_.Id)" }
Start-Process "ms-settings:privacy-webcam"
'@

    T -Id 'repair-fileassoc' -Cat 'repair' -Icon 'E8A5' -Risk 'care' -Run 'inline' `
        -Name 'Restaurar asociaciones de archivo' -Desc 'Arregla los .exe, .lnk o extensiones que abren con el programa equivocado' -Code @'
HR "ASOCIACIONES DE ARCHIVO"
Backup-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts" "asociaciones"
Step "Restaurando las asociaciones criticas del sistema"
$criticas = @{
    ".exe" = "exefile"; ".lnk" = "lnkfile"; ".bat" = "batfile"; ".cmd" = "cmdfile"
    ".com" = "comfile"; ".reg" = "regfile"; ".msi" = "Msi.Package"; ".ps1" = "Microsoft.PowerShellScript.1"
}
foreach ($e in $criticas.Keys) {
    $k = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$e\UserChoice"
    if (Test-Path $k) {
        try { Remove-Item $k -Recurse -Force -ErrorAction Stop; OK "Eliminada la eleccion de usuario para $e" }
        catch { WARN "$e esta protegido por Windows; usa Configuracion > Aplicaciones predeterminadas." }
    }
    Set-Reg "HKCU:\Software\Classes\$e" "(Default)" $criticas[$e] "String"
}
Step "Refrescando el Shell"
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
OK "Asociaciones restauradas."
Start-Process "ms-settings:defaultapps"
'@

    T -Id 'repair-winre' -Cat 'repair' -Icon 'E777' -Risk 'safe' -Run 'inline' `
        -Name 'Verificar entorno de recuperacion' -Desc 'Comprueba que WinRE existe y funciona: sin el no hay reinicio avanzado ni restablecer PC' -Code @'
HR "ENTORNO DE RECUPERACION (WinRE)"
Step "Estado"
$info = reagentc /info 2>&1
$info | ForEach-Object { Write-Host "    $_" }
if ($info -match "Disabled|Deshabilitado") {
    WARN "WinRE esta deshabilitado. Intentando habilitarlo..."
    reagentc /enable
    Start-Sleep -Seconds 2
    reagentc /info
}
else { OK "WinRE habilitado." }
Step "Particiones del disco de sistema"
Get-Partition -ErrorAction SilentlyContinue | Where-Object { $_.DiskNumber -eq 0 } |
    ForEach-Object { ROW "Particion $($_.PartitionNumber)" "$($_.Type)  $(Human $_.Size)  letra: $($_.DriveLetter)" }
Step "Configuracion de arranque"
bcdedit /enum "{current}" | Select-String "recoveryenabled|recoverysequence|device|description"
INFO "Para entrar a WinRE manualmente: shutdown /r /o /t 0"
'@

    T -Id 'repair-defender-reset' -Cat 'repair' -Icon 'EA18' -Risk 'care' -Run 'inline' `
        -Name 'Reactivar Microsoft Defender' -Desc 'Recupera Defender cuando un antivirus desinstalado o un crack lo dejo apagado' -Code @'
HR "REACTIVAR DEFENDER"
Step "Quitando politicas que lo bloquean"
foreach ($k in @("HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection")) {
    if (Test-Path $k) {
        Backup-Reg $k "defender_policy"
        Remove-Reg $k "DisableAntiSpyware"
        Remove-Reg $k "DisableAntiVirus"
        Remove-Reg $k "DisableRealtimeMonitoring"
        Remove-Reg $k "DisableBehaviorMonitoring"
        Remove-Reg $k "DisableOnAccessProtection"
        Remove-Reg $k "DisableScanOnRealtimeEnable"
    }
}
Step "Reactivando servicios"
foreach ($s in @("WinDefend", "WdNisSvc", "SecurityHealthService", "wscsvc", "Sense")) {
    try { Set-Service $s -StartupType Automatic -ErrorAction Stop; Start-Service $s -ErrorAction SilentlyContinue; OK "$s activo" }
    catch { WARN "$s : $($_.Exception.Message)" }
}
Step "Preferencias"
try {
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
    Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
    OK "Proteccion en tiempo real reactivada."
}
catch { ERR "No se pudo: $($_.Exception.Message). Si hay otro antivirus instalado, desinstalalo primero." }
Step "Actualizando firmas"
Update-MpSignature -ErrorAction SilentlyContinue
Get-MpComputerStatus -ErrorAction SilentlyContinue | Format-List AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureVersion | Out-String | Write-Host
'@

    # ---------- LIMPIEZA ----------
    T -Id 'clean-driverstore' -Cat 'clean' -Icon 'E7F8' -Risk 'danger' -Run 'inline' `
        -Name 'Eliminar drivers huerfanos' -Desc 'Borra versiones antiguas de controladores del DriverStore. Suele liberar 2-8 GB' -Code @'
HR "LIMPIEZA DEL ALMACEN DE CONTROLADORES"
$ds = "$env:SystemRoot\System32\DriverStore\FileRepository"
INFO ("DriverStore ocupa " + (Human (Get-Folder-Size $ds)))
Step "Paquetes de terceros instalados"
$sal = pnputil.exe /enum-drivers
$paquetes = @()
$act = $null
foreach ($l in $sal) {
    if ($l -match "^\s*(?:Nombre publicado|Published Name)\s*:\s*(oem\d+\.inf)") { $act = @{ inf = $Matches[1]; orig = ""; ver = "" } }
    elseif ($act -and $l -match "^\s*(?:Nombre original|Original Name)\s*:\s*(.+)") { $act.orig = $Matches[1].Trim() }
    elseif ($act -and $l -match "^\s*(?:Versi.n del controlador|Driver Version)\s*:\s*(.+)") {
        $act.ver = $Matches[1].Trim()
        $paquetes += [pscustomobject]$act
        $act = $null
    }
}
INFO "$($paquetes.Count) paquetes de terceros."
$grupos = $paquetes | Group-Object orig | Where-Object Count -gt 1
if (-not $grupos) { OK "No hay versiones duplicadas que eliminar."; return }
Step "Duplicados encontrados"
$borrados = 0
foreach ($g in $grupos) {
    # La version viene como "dd/MM/yyyy 1.2.3.4"; ordenamos por la parte numerica.
    $orden = $g.Group | Sort-Object @{ e = { $v = ($_.ver -split '\s+')[-1]; try { [version]$v } catch { [version]"0.0" } } }
    $viejos = @($orden | Select-Object -First ([Math]::Max(0, $orden.Count - 1)))
    ROW $g.Name "$($g.Count) versiones, se conservan la mas nueva"
    foreach ($v in $viejos) {
        $r = pnputil.exe /delete-driver $v.inf 2>&1
        if ($LASTEXITCODE -eq 0) { OK "  Eliminado $($v.inf) ($($v.ver))"; $borrados++ }
        else { INFO "  En uso, se conserva: $($v.inf)" }
    }
}
OK "$borrados paquetes antiguos eliminados."
INFO ("DriverStore ahora ocupa " + (Human (Get-Folder-Size $ds)))
'@

    T -Id 'clean-old-profiles' -Cat 'clean' -Icon 'E77B' -Risk 'danger' -Run 'inline' `
        -Name 'Perfiles sin usar hace 6 meses' -Desc 'Lista los perfiles abandonados y su peso. Solo informa: el borrado se confirma aparte' -Code @'
HR "PERFILES ABANDONADOS"
$lim = (Get-Date).AddDays(-180)
$cands = @()
Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and -not $_.Loaded } | ForEach-Object {
    $n = Split-Path $_.LocalPath -Leaf
    $u = $_.LastUseTime
    $sz = Get-Folder-Size $_.LocalPath
    if ($u -and $u -lt $lim) {
        WARN "$n : sin usar desde $($u.ToString('dd/MM/yyyy'))  -  $(Human $sz)"
        $cands += [pscustomobject]@{ Perfil = $n; Ruta = $_.LocalPath; Ultimo = $u; Bytes = $sz; SID = $_.SID }
    }
    else { ROW $n "activo  -  $(Human $sz)  -  ultimo uso $($u)" }
}
if (-not $cands) { OK "No hay perfiles abandonados."; return }
$tot = ($cands | Measure-Object Bytes -Sum).Sum
HR ("RECUPERABLE: " + (Human $tot) + " en " + $cands.Count + " perfil(es)")
$f = Join-Path (BSDir "reportes") ("perfiles_abandonados_" + (Stamp) + ".csv")
$cands | Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "Listado: $f"
WARN "Para eliminarlos: Propiedades del sistema > Perfiles de usuario > Eliminar. Asi Windows limpia tambien el registro."
Start-Process "systempropertiesadvanced.exe"
'@

    T -Id 'clean-storage-sense' -Cat 'clean' -Icon 'E74D' -Risk 'safe' -Run 'inline' `
        -Name 'Configurar Sensor de almacenamiento' -Desc 'Deja Windows limpiando temporales y papelera solo, cada mes' -Code @'
HR "SENSOR DE ALMACENAMIENTO"
$k = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
Set-Reg $k "01" 1          # activado
Set-Reg $k "2048" 1        # limpiar temporales de apps
Set-Reg $k "04" 1          # papelera
Set-Reg $k "08" 1          # descargas
Set-Reg $k "32" 30         # papelera: 30 dias
Set-Reg $k "256" 0         # descargas: nunca por antiguedad (seguro)
Set-Reg $k "2048" 1
Set-Reg $k "StoragePoliciesNotified" 1
Set-Reg $k "512" 30        # frecuencia: mensual
OK "Sensor de almacenamiento activo: limpia temporales y papelera de mas de 30 dias, una vez al mes."
INFO "No borra tus Descargas por antiguedad (queda desactivado a proposito)."
Start-Process "ms-settings:storagesense"
'@ -Revert @'
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0
OK "Sensor de almacenamiento desactivado."
'@

    # ---------- RENDIMIENTO ----------
    T -Id 'perf-background-apps' -Cat 'perf' -Icon 'E7C4' -Risk 'care' -Run 'inline' `
        -Name 'Cortar apps en segundo plano' -Desc 'Impide que las apps de la Store consuman CPU y red sin estar abiertas' -Code @'
HR "APLICACIONES EN SEGUNDO PLANO"
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
Step "Desactivando por aplicacion"
$base = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
if (Test-Path $base) {
    Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty $_.PSPath -Name "Disabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    OK "Todas las apps de la Store bloqueadas en segundo plano."
}
Step "Sincronizacion y sugerencias"
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled" 0
OK "Listo."
'@ -Revert @'
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 0
Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground"
OK "Apps en segundo plano permitidas de nuevo."
'@

    T -Id 'perf-onedrive' -Cat 'perf' -Icon 'E753' -Risk 'danger' -Run 'inline' `
        -Name 'Quitar OneDrive' -Desc 'Desinstala OneDrive y devuelve las carpetas del usuario al disco local' -Code @'
HR "ONEDRIVE"
Step "Estado actual"
$od = Get-Process OneDrive -ErrorAction SilentlyContinue
if ($od) { INFO "OneDrive esta en ejecucion (PID $($od.Id))." } else { INFO "OneDrive no esta corriendo." }
$carp = "$env:USERPROFILE\OneDrive"
if (Test-Path $carp) { WARN ("La carpeta OneDrive ocupa " + (Human (Get-Folder-Size $carp)) + ". NO se borrara: tus archivos se quedan ahi.") }

Step "Cerrando OneDrive"
Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Step "Desinstalando"
foreach ($p in @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe")) {
    if (Test-Path $p) { Start-Process $p -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue; OK "Desinstalado con $p" }
}
Step "Quitandolo del Explorador y del inicio"
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
Remove-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "OneDrive"
Remove-Item "Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Force -ErrorAction SilentlyContinue
Set-Reg "HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" "System.IsPinnedToNameSpaceTree" 0
Step "Limpiando restos"
Purge-Folder "$env:LOCALAPPDATA\Microsoft\OneDrive" "Cache de OneDrive" | Out-Null
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
OK ("OneDrive desinstalado. Tus archivos siguen en " + $carp)
'@ -Revert @'
Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC"
if (Get-Command winget.exe -ErrorAction SilentlyContinue) { winget install --id Microsoft.OneDrive -e --accept-package-agreements --accept-source-agreements }
OK "OneDrive restaurado."
'@

    T -Id 'perf-bing-search' -Cat 'perf' -Icon 'E721' -Risk 'safe' -Run 'inline' `
        -Name 'Quitar Bing del menu Inicio' -Desc 'La busqueda deja de consultar internet y responde al instante' -Code @'
HR "BUSQUEDA LOCAL"
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
Stop-Process -Name SearchHost, SearchApp -Force -ErrorAction SilentlyContinue
OK "La busqueda ya no consulta Bing."
'@ -Revert @'
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1
Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch"
Remove-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"
OK "Busqueda web restaurada."
'@

    T -Id 'perf-mouse' -Cat 'perf' -Icon 'E962' -Risk 'safe' -Run 'inline' `
        -Name 'Quitar aceleracion del mouse' -Desc 'Movimiento 1:1 del raton, como lo quieren los jugadores y disenadores' -Code @'
HR "PRECISION DEL MOUSE"
Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
Set-Reg "HKCU:\Control Panel\Mouse" "MouseSensitivity" "10" "String"
Step "Extras de comodidad"
Set-Reg "HKCU:\Control Panel\Desktop" "MouseWheelRouting" 2
Set-Reg "HKCU:\Control Panel\Accessibility\MouseKeys" "Flags" "58" "String"
OK "Aceleracion desactivada y sensibilidad al valor neutro (6/11 en la interfaz)."
INFO "Cierra sesion o reinicia para que aplique del todo."
'@ -Revert @'
Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "1" "String"
Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "6" "String"
Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "10" "String"
OK "Aceleracion del mouse restaurada."
'@

    T -Id 'perf-notifications' -Cat 'perf' -Icon 'E7E7' -Risk 'safe' -Run 'inline' `
        -Name 'Silenciar notificaciones' -Desc 'Quita avisos, consejos y la pantalla de bienvenida tras cada actualizacion' -Code @'
HR "NOTIFICACIONES Y AVISOS"
$cdm = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-Reg $cdm "SubscribedContent-310093Enabled" 0     # sugerencias de bienvenida
Set-Reg $cdm "SubscribedContent-338393Enabled" 0
Set-Reg $cdm "SubscribedContent-353696Enabled" 0
Set-Reg $cdm "RotatingLockScreenOverlayEnabled" 0
Set-Reg $cdm "SoftLandingEnabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_TOASTS_ENABLED" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0
OK "Notificaciones y sugerencias desactivadas."
'@ -Revert @'
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 1
Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_TOASTS_ENABLED" 1
OK "Notificaciones reactivadas."
'@

    # ---------- SEGURIDAD ----------
    T -Id 'sec-ransomware' -Cat 'sec' -Icon 'E72E' -Risk 'care' -Run 'inline' `
        -Name 'Proteccion contra ransomware' -Desc 'Activa el acceso controlado a carpetas de Defender sobre Documentos, Fotos y Escritorio' -Code @'
HR "ACCESO CONTROLADO A CARPETAS"
$s = Get-MpPreference -ErrorAction SilentlyContinue
if (-not $s) { ERR "Defender no responde."; return }
ROW "Estado actual" $s.EnableControlledFolderAccess
Step "Activando en modo auditoria primero"
try {
    Set-MpPreference -EnableControlledFolderAccess AuditMode -ErrorAction Stop
    OK "Modo auditoria activo: Defender registra los bloqueos sin impedirlos."
    INFO "Usa el equipo unos dias, revisa Seguridad de Windows > Proteccion contra ransomware > Bloqueo, agrega las apps legitimas y luego cambia a Enabled."
}
catch { ERR "No se pudo activar: $($_.Exception.Message)" }
Step "Carpetas protegidas"
$s = Get-MpPreference
if ($s.ControlledFolderAccessProtectedFolders) { $s.ControlledFolderAccessProtectedFolders | ForEach-Object { ROW "Protegida" $_ } }
else { INFO "Se protegen por defecto Documentos, Imagenes, Videos, Musica, Escritorio y Favoritos." }
Step "Reglas de reduccion de superficie de ataque"
$reglas = @{
    "56a863a9-875e-4185-98a7-b882c64b5ce5" = "Bloquear abuso de drivers vulnerables"
    "d4f940ab-401b-4efc-aadc-ad5f3c50688a" = "Bloquear procesos hijo de Office"
    "3b576869-a4ec-4529-8536-b80a7769e899" = "Bloquear contenido ejecutable en Office"
    "be9ba2d9-53ea-4cdc-84e5-9b1eeee46550" = "Bloquear descargas de correo"
    "d3e037e1-3eb8-44c8-a917-57927947596d" = "Bloquear JS/VBS que descargan ejecutables"
}
foreach ($r in $reglas.Keys) {
    try { Add-MpPreference -AttackSurfaceReductionRules_Ids $r -AttackSurfaceReductionRules_Actions Enabled -ErrorAction Stop; OK $reglas[$r] }
    catch { WARN "$($reglas[$r]): $($_.Exception.Message)" }
}
Start-Process "windowsdefender://RansomwareProtection"
'@ -Revert @'
Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction SilentlyContinue
OK "Acceso controlado a carpetas desactivado."
'@

    T -Id 'sec-audit' -Cat 'sec' -Icon 'E8F1' -Risk 'care' -Run 'inline' `
        -Name 'Activar auditoria de seguridad' -Desc 'Registra inicios de sesion, cambios de cuentas y uso de privilegios para poder investigar despues' -Code @'
HR "DIRECTIVAS DE AUDITORIA"
Step "Estado actual"
auditpol /get /category:* | Select-String "Inicio|Logon|Cuenta|Account|Directiva|Policy" | ForEach-Object { Write-Host "    $_" }
Step "Activando las auditorias utiles"
$cats = @(
    @{ c = "Logon/Logoff"; n = "Inicio y cierre de sesion" },
    @{ c = "Account Logon"; n = "Autenticacion de credenciales" },
    @{ c = "Account Management"; n = "Gestion de cuentas" },
    @{ c = "Policy Change"; n = "Cambios de directiva" },
    @{ c = "Privilege Use"; n = "Uso de privilegios" }
)
foreach ($x in $cats) {
    $r = auditpol /set /category:"$($x.c)" /success:enable /failure:enable 2>&1
    if ($LASTEXITCODE -eq 0) { OK $x.n } else { WARN "$($x.n): $r" }
}
Step "Ampliando el registro de seguridad a 128 MB"
wevtutil sl Security /ms:134217728
OK "Auditoria activa. Los eventos quedan en Visor de eventos > Registros de Windows > Seguridad."
INFO "Usa 'Historial de inicios de sesion' para leerlos de forma comoda."
'@ -Revert @'
foreach ($c in @("Logon/Logoff", "Account Logon", "Account Management", "Policy Change", "Privilege Use")) {
    auditpol /set /category:"$c" /success:disable /failure:disable 2>&1 | Out-Null
}
OK "Auditoria devuelta a los valores por defecto."
'@

    T -Id 'sec-app-permissions' -Cat 'sec' -Icon 'E72E' -Risk 'safe' -Run 'inline' `
        -Name 'Auditar permisos de aplicaciones' -Desc 'Que apps tienen acceso a camara, microfono, ubicacion y contactos' -Code @'
HR "PERMISOS DE PRIVACIDAD"
$store = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"
$caps = @{
    webcam         = "Camara"; microphone = "Microfono"; location = "Ubicacion"
    contacts       = "Contactos"; appointments = "Calendario"; email = "Correo"
    phoneCallHistory = "Historial de llamadas"; userAccountInformation = "Datos de cuenta"
}
foreach ($c in $caps.Keys) {
    $p = Join-Path $store $c
    if (-not (Test-Path $p)) { continue }
    $glob = (Get-ItemProperty $p -ErrorAction SilentlyContinue).Value
    HR "$($caps[$c])  [global: $glob]"
    foreach ($sub in @("", "NonPackaged")) {
        $pp = if ($sub) { Join-Path $p $sub } else { $p }
        Get-ChildItem $pp -ErrorAction SilentlyContinue | ForEach-Object {
            $v = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).Value
            $nom = $_.PSChildName -replace '#', '\'
            if ($v -eq "Allow") { WARN "  PERMITIDO: $nom" } else { ROW "  denegado" $nom }
        }
    }
}
Start-Process "ms-settings:privacy"
'@

    T -Id 'sec-certs' -Cat 'sec' -Icon 'E8D7' -Risk 'safe' -Run 'inline' `
        -Name 'Revisar certificados raiz' -Desc 'Detecta autoridades de certificacion instaladas por adware o proxies de interceptacion' -Code @'
HR "CERTIFICADOS RAIZ DE CONFIANZA"
$conocidos = "Microsoft|DigiCert|VeriSign|Thawte|GlobalSign|Baltimore|Entrust|GeoTrust|COMODO|Sectigo|USERTrust|Go Daddy|Starfield|AddTrust|Certum|QuoVadis|SecureTrust|AAA Certificate|ISRG|Amazon|Google Trust|Symantec|Actalis|Buypass|D-TRUST|E-Tugra|HARICA|Hongkong|IdenTrust|Network Solutions|OISTE|SSL.com|SwissSign|T-TeleSec|TWCA|TeliaSonera|UCA|emSign|vTrus|Certigna|Autoridad de Certificacion|ANF|AC RAIZ|Camerfirma|EC-ACC|Firmaprofesional|Izenpe|NetLock|SZAFIR|TUBITAK|Trustwave|XRamp|Security Communication|Staat der|Hellenic|Chambers of Commerce"
$raros = @()
Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Subject -notmatch $conocidos) { $raros += $_ }
}
if ($raros) {
    WARN "$($raros.Count) certificados raiz no habituales:"
    $raros | ForEach-Object {
        ERR "  $($_.Subject)"
        Write-Host "      emitido por: $($_.Issuer)"
        Write-Host "      valido hasta: $($_.NotAfter)   huella: $($_.Thumbprint)"
    }
    INFO "Los proxies corporativos, antivirus y algunas VPN instalan certificados legitimos aqui. Verifica antes de eliminar ninguno."
}
else { OK "Todos los certificados raiz son de autoridades conocidas." }

Step "Certificados caducados en el almacen"
$venc = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.NotAfter -lt (Get-Date) }
if ($venc) { $venc | ForEach-Object { ROW "caducado" "$($_.Subject.Substring(0,[Math]::Min(70,$_.Subject.Length)))  ($($_.NotAfter.ToString('dd/MM/yyyy')))" } }
else { OK "Sin certificados caducados." }

Step "Certificados personales del equipo"
Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue | ForEach-Object { ROW $_.Subject "hasta $($_.NotAfter.ToString('dd/MM/yyyy'))" }
'@

    # ---------- RED ----------
    T -Id 'net-wifi-report' -Cat 'net' -Icon 'E701' -Risk 'safe' -Run 'inline' `
        -Name 'Informe de WiFi de Windows' -Desc 'Genera el reporte oficial con el historial de conexiones, cortes y errores' -Code @'
HR "INFORME DE RED INALAMBRICA"
Step "Interfaces WLAN"
netsh wlan show interfaces
Step "Redes al alcance y su senal"
$vis = netsh wlan show networks mode=bssid
$vis | Select-String "SSID|Se" | Select-Object -First 40 | ForEach-Object { Write-Host "    $_" }
Step "Generando el informe oficial (tarda ~30 s)"
$dst = Join-Path (BSDir "reportes") ("wlan_" + (Stamp) + ".html")
netsh wlan show wlanreport | Out-Null
$orig = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
if (Test-Path $orig) {
    Copy-Item $orig $dst -Force
    OK "Informe: $dst"
    Start-Process $dst
}
else { ERR "Windows no genero el informe (equipo sin adaptador WiFi?)." }
Step "Calidad de la conexion actual"
$i = netsh wlan show interfaces | Select-String "Se|Signal|Radio|Canal|Channel|Velocidad|Rate"
$i | ForEach-Object { Write-Host "    $_" }
'@

    T -Id 'net-firewall-rules' -Cat 'net' -Icon 'E72E' -Risk 'safe' -Run 'inline' `
        -Name 'Auditar reglas de firewall' -Desc 'Que programas tienen permitido entrar, y exporta todas las reglas a CSV' -Code @'
HR "REGLAS DE FIREWALL"
Step "Perfiles"
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize | Out-String | Write-Host
Step "Reglas de entrada permitidas creadas por programas"
$reglas = Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True -ErrorAction SilentlyContinue | Where-Object { -not $_.Group }
INFO "$($reglas.Count) reglas de entrada sin grupo (tipicamente creadas por apps de terceros)."
$reglas | Select-Object -First 30 | ForEach-Object {
    $app = ($_ | Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue).Program
    $prt = ($_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue)
    ROW $_.DisplayName "$app  puertos: $($prt.LocalPort)"
}
Step "Exportando"
$f = Join-Path (BSDir "reportes") ("firewall_" + (Stamp) + ".csv")
Get-NetFirewallRule -ErrorAction SilentlyContinue | Select-Object DisplayName, Direction, Action, Enabled, Profile, Group | Export-Csv $f -NoTypeInformation -Encoding UTF8
OK "Reglas exportadas: $f"
Start-Process "wf.msc"
'@

    T -Id 'net-usage' -Cat 'net' -Icon 'EB05' -Risk 'safe' -Run 'inline' `
        -Name 'Consumo de red por adaptador' -Desc 'Cuantos datos ha movido cada tarjeta y que procesos tienen conexiones abiertas' -Code @'
HR "CONSUMO DE RED"
Step "Estadisticas por adaptador desde el ultimo arranque"
Get-NetAdapterStatistics -ErrorAction SilentlyContinue | ForEach-Object {
    ROW $_.Name "recibido $(Human $_.ReceivedBytes)  |  enviado $(Human $_.SentBytes)"
}
Step "Procesos con mas conexiones abiertas"
$con = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Established" }
$con | Group-Object OwningProcess | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object {
    $p = Get-Process -Id $_.Name -ErrorAction SilentlyContinue
    ROW $p.ProcessName "$($_.Count) conexiones  |  PID $($_.Name)"
}
Step "Destinos mas frecuentes"
$con | Group-Object RemoteAddress | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object {
    $nombre = try { [System.Net.Dns]::GetHostEntry($_.Name).HostName } catch { "" }
    ROW $_.Name "$($_.Count) conexiones  $nombre"
}
Step "Uso de datos que registra Windows"
$db = "$env:SystemRoot\System32\SRU\SRUDB.dat"
if (Test-Path $db) { INFO ("Base de uso de red: " + (Human (Get-Item $db).Length) + " - detalle por app en Configuracion > Red > Uso de datos") }
Start-Process "ms-settings:datausage"
'@

    T -Id 'net-vpn' -Cat 'net' -Icon 'E8CE' -Risk 'safe' -Run 'inline' `
        -Name 'VPN y adaptadores virtuales' -Desc 'Detecta VPN, tuneles y adaptadores virtuales que pueden estar rompiendo la red' -Code @'
HR "VPN Y ADAPTADORES VIRTUALES"
Step "Conexiones VPN configuradas"
$v = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
$v += Get-VpnConnection -ErrorAction SilentlyContinue
if ($v) { $v | ForEach-Object { ROW $_.Name "$($_.ServerAddress)  |  $($_.ConnectionStatus)  |  $($_.TunnelType)" } }
else { INFO "Sin conexiones VPN nativas configuradas." }

Step "Adaptadores virtuales presentes"
Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match "VPN|TAP|Tunnel|Virtual|Hyper-V|VMware|VirtualBox|Tailscale|WireGuard|ZeroTier|Hamachi|Nord|Express|Proton" } |
    ForEach-Object { ROW $_.Name "$($_.InterfaceDescription)  |  $($_.Status)" }

Step "Metricas de las rutas por defecto"
Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric |
    ForEach-Object { ROW $_.InterfaceAlias "gateway $($_.NextHop)  metrica $($_.RouteMetric)" }
INFO "Si una VPN desconectada dejo su ruta con metrica baja, la red no sale. Desinstalar el adaptador o subirle la metrica lo arregla."

Step "Servicios de VPN en ejecucion"
Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" -and $_.DisplayName -match "VPN|Tailscale|WireGuard|OpenVPN|Nord|Proton|Express|ZeroTier" } |
    ForEach-Object { ROW $_.DisplayName $_.Status }
'@

    # ---------- INFORMACION ----------
    T -Id 'info-monitors' -Cat 'info' -Icon 'E7F4' -Risk 'safe' -Run 'inline' `
        -Name 'Monitores y pantallas' -Desc 'Marca, modelo, serial, anio de fabricacion y resolucion de cada pantalla' -Code @'
HR "MONITORES CONECTADOS"
$ids = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue
$par = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
if (-not $ids) { WARN "El controlador no expone datos EDID."; }
$i = 0
foreach ($m in $ids) {
    $dec = { param($a) if ($a) { (($a | Where-Object { $_ -gt 0 }) | ForEach-Object { [char]$_ }) -join "" } }
    HR ("Pantalla " + (++$i))
    ROW "Fabricante" (& $dec $m.ManufacturerName)
    ROW "Modelo" (& $dec $m.UserFriendlyName)
    ROW "Codigo de producto" (& $dec $m.ProductCodeID)
    ROW "Numero de serie" (& $dec $m.SerialNumberID)
    ROW "Anio de fabricacion" "$($m.YearOfManufacture) (semana $($m.WeekOfManufacture))"
    $p = $par | Where-Object InstanceName -eq $m.InstanceName
    if ($p) {
        $pulg = [math]::Round([math]::Sqrt([math]::Pow($p.MaxHorizontalImageSize, 2) + [math]::Pow($p.MaxVerticalImageSize, 2)) / 2.54, 1)
        ROW "Tamano fisico" "$($p.MaxHorizontalImageSize) x $($p.MaxVerticalImageSize) cm  (~$pulg pulgadas)"
    }
}
Step "Modos de video activos"
Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {
    ROW $_.Name "$($_.CurrentHorizontalResolution) x $($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate) Hz  ($($_.CurrentBitsPerPixel) bits)"
    if ($_.CurrentRefreshRate -le 60 -and $_.MaxRefreshRate -gt 60) { WARN "  La pantalla admite $($_.MaxRefreshRate) Hz pero esta a $($_.CurrentRefreshRate) Hz." }
}
Start-Process "ms-settings:display-advanced"
'@

    T -Id 'info-gpu' -Cat 'info' -Icon 'E7FC' -Risk 'safe' -Run 'inline' `
        -Name 'Tarjetas graficas' -Desc 'GPU, memoria, version y antiguedad del driver, y estado de DirectX' -Code @'
HR "GRAFICOS"
foreach ($g in Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue) {
    HR $g.Name
    ROW "Fabricante" $g.AdapterCompatibility
    ROW "Memoria dedicada" (Human $g.AdapterRAM)
    ROW "Procesador de video" $g.VideoProcessor
    ROW "Version del driver" $g.DriverVersion
    ROW "Fecha del driver" $g.DriverDate
    if ($g.DriverDate) {
        $d = ((Get-Date) - $g.DriverDate).Days
        if ($d -gt 365) { WARN "  El driver tiene $d dias. Conviene actualizarlo." } else { OK "  Driver de hace $d dias." }
    }
    ROW "Resolucion actual" "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate) Hz"
    ROW "Estado" $g.Status
    if ($g.ConfigManagerErrorCode -ne 0) { ERR "  Codigo de error: $($g.ConfigManagerErrorCode)" }
}
Step "Memoria de video segun el registro"
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match "^\d{4}$" } | ForEach-Object {
    $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
    if ($p.DriverDesc -and $p."HardwareInformation.qwMemorySize") {
        ROW $p.DriverDesc (Human $p."HardwareInformation.qwMemorySize")
    }
}
Step "Planificacion de GPU acelerada por hardware"
$h = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue).HwSchMode
ROW "HAGS" $(if ($h -eq 2) { "activada" } else { "desactivada" })
Step "Generando informe DirectX"
$f = Join-Path (BSDir "reportes") ("dxdiag_" + (Stamp) + ".txt")
Start-Process dxdiag.exe -ArgumentList "/t", "`"$f`"" -Wait -ErrorAction SilentlyContinue
if (Test-Path $f) { OK "Informe DirectX: $f" }
'@

    T -Id 'info-updates-history' -Cat 'info' -Icon 'E895' -Risk 'safe' -Run 'inline' `
        -Name 'Historial de actualizaciones' -Desc 'Que se instalo, cuando, y cuales fallaron. Clave para culpar al parche correcto' -Code @'
HR "HISTORIAL DE WINDOWS UPDATE"
try {
    $ses = New-Object -ComObject Microsoft.Update.Session
    $bus = $ses.CreateUpdateSearcher()
    $n = $bus.GetTotalHistoryCount()
    if ($n -eq 0) { WARN "Sin historial disponible."; }
    else {
        $h = $bus.QueryHistory(0, [Math]::Min(60, $n))
        Step "Ultimas $($h.Count) operaciones"
        foreach ($u in $h) {
            $res = switch ($u.ResultCode) { 1 { "en curso" } 2 { "CORRECTO" } 3 { "con avisos" } 4 { "FALLO" } 5 { "cancelado" } default { "?" } }
            $l = "{0}  {1,-10} {2}" -f $u.Date.ToString("dd/MM/yyyy HH:mm"), $res, $u.Title
            if ($u.ResultCode -eq 4) { ERR $l } elseif ($u.ResultCode -eq 2) { Write-Host "    $l" } else { WARN $l }
        }
        $fallos = @($h | Where-Object { $_.ResultCode -eq 4 })
        if ($fallos) { WARN "$($fallos.Count) actualizaciones fallidas. Prueba 'Resetear Windows Update'." }
    }
}
catch { ERR "No se pudo leer el historial: $($_.Exception.Message)" }
Step "Parches instalados (Get-HotFix)"
Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 20 |
    ForEach-Object { ROW $_.HotFixID "$($_.Description)  $($_.InstalledOn)  por $($_.InstalledBy)" }
Step "Version de Windows"
$cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
ROW "Edicion" $cv.ProductName
ROW "Version" $cv.DisplayVersion
ROW "Build" "$($cv.CurrentBuild).$($cv.UBR)"
'@

    T -Id 'info-boot-history' -Cat 'info' -Icon 'E823' -Risk 'safe' -Run 'inline' `
        -Name 'Historial de encendidos' -Desc 'Cuando se enciende y apaga el equipo, cuanto tarda en arrancar y si hubo apagones' -Code @'
HR "HISTORIAL DE ARRANQUES"
Step "Rendimiento de arranque (ultimos 15)"
$b = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -MaxEvents 15 -ErrorAction SilentlyContinue
if ($b) {
    $tiempos = @()
    foreach ($e in $b) {
        $x = [xml]$e.ToXml()
        $ms = ($x.Event.EventData.Data | Where-Object Name -eq "BootTime")."#text"
        if ($ms) {
            $s = [math]::Round([int]$ms / 1000, 1)
            $tiempos += $s
            $marca = if ($s -gt 60) { "LENTO" } elseif ($s -gt 30) { "regular" } else { "bien" }
            ROW $e.TimeCreated.ToString("dd/MM/yyyy HH:mm") "$s segundos  ($marca)"
        }
    }
    if ($tiempos) {
        $prom = [math]::Round(($tiempos | Measure-Object -Average).Average, 1)
        HR "PROMEDIO DE ARRANQUE: $prom segundos"
        if ($prom -gt 45) { WARN "Arranque lento: revisa 'Auditar programas de inicio'." }
    }
}
else { INFO "Sin datos de diagnostico de arranque." }

Step "Encendidos y apagados (ultimos 30 dias)"
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 6005, 6006, 6008, 41; StartTime = (Get-Date).AddDays(-30) } -ErrorAction SilentlyContinue |
    Select-Object -First 40 | ForEach-Object {
    $t = switch ($_.Id) { 6005 { "ENCENDIDO" } 6006 { "apagado normal" } 6008 { "APAGADO INESPERADO" } 41 { "CORTE / KERNEL POWER" } }
    $l = "$($_.TimeCreated.ToString('dd/MM/yyyy HH:mm'))  $t"
    if ($_.Id -in @(6008, 41)) { ERR $l } else { Write-Host "    $l" }
}
Step "Resumen"
$mal = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 6008, 41; StartTime = (Get-Date).AddDays(-30) } -ErrorAction SilentlyContinue)
if ($mal.Count -gt 3) { ERR "$($mal.Count) apagados inesperados en 30 dias: sospecha de fuente de poder, sobrecalentamiento o RAM." }
elseif ($mal.Count -gt 0) { WARN "$($mal.Count) apagado(s) inesperado(s) en 30 dias." }
else { OK "Sin apagados inesperados." }
'@

    T -Id 'info-usb-history' -Cat 'info' -Icon 'ECF0' -Risk 'safe' -Run 'inline' `
        -Name 'Dispositivos USB conectados' -Desc 'Todo lo que se ha conectado alguna vez por USB, util en auditorias y peritajes' -Code @'
HR "DISPOSITIVOS USB"
Step "Conectados ahora"
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like "USB*" } |
    ForEach-Object { ROW $_.FriendlyName "$($_.Class)  $($_.Status)" }
Step "Historial de dispositivos de almacenamiento USB"
$k = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
if (Test-Path $k) {
    Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
        $desc = $_.PSChildName
        Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            ROW ($p.FriendlyName) "$desc   serial: $($_.PSChildName)"
        }
    }
}
else { INFO "Sin historial de almacenamiento USB." }
Step "Todos los USB vistos alguna vez"
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USB" -ErrorAction SilentlyContinue | ForEach-Object {
    $vid = $_.PSChildName
    Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($p.DeviceDesc) {
            $n = ($p.DeviceDesc -split ";")[-1]
            ROW $n $vid
        }
    }
} | Select-Object -First 40
'@

    T -Id 'info-office' -Cat 'info' -Icon 'E8A5' -Risk 'safe' -Run 'inline' `
        -Name 'Estado de Office' -Desc 'Version, canal de actualizacion, activacion y cuenta asociada' -Code @'
HR "MICROSOFT OFFICE"
$found = $false
foreach ($v in @("16.0", "15.0", "14.0")) {
    $k = "HKLM:\SOFTWARE\Microsoft\Office\$v\Common\InstallRoot"
    if (Test-Path $k) {
        $found = $true
        $p = (Get-ItemProperty $k).Path
        ROW "Office $v" $p
        $w = Join-Path $p "WINWORD.EXE"
        if (Test-Path $w) { ROW "  Version de Word" (Get-Item $w).VersionInfo.ProductVersion }
    }
}
$c2r = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
if (Test-Path $c2r) {
    $found = $true
    $p = Get-ItemProperty $c2r
    HR "OFFICE CLICK-TO-RUN"
    ROW "Producto" $p.ProductReleaseIds
    ROW "Version" $p.VersionToReport
    ROW "Canal" $p.CDNBaseUrl
    ROW "Plataforma" $p.Platform
    ROW "Idioma" $p.ClientCulture
}
if (-not $found) { WARN "No se detecto Microsoft Office instalado."; }
Step "Activacion de Office"
$ospp = Get-ChildItem "$env:ProgramFiles\Microsoft Office*\Office1*\ospp.vbs", "${env:ProgramFiles(x86)}\Microsoft Office*\Office1*\ospp.vbs" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ospp) { cscript.exe //nologo $ospp.FullName /dstatus }
else {
    Get-CimInstance SoftwareLicensingProduct -Filter "Name LIKE 'Office%' AND PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue |
        ForEach-Object { ROW $_.Name $(if ($_.LicenseStatus -eq 1) { "ACTIVADO" } else { "no activado" }) }
}
Step "Aplicaciones de Office instaladas"
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue |
    ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue } |
    Where-Object { $_.DisplayName -match "Office|Microsoft 365|Word|Excel|Outlook" } |
    Select-Object -Unique DisplayName, DisplayVersion | ForEach-Object { ROW $_.DisplayName $_.DisplayVersion }
'@

    # ---------- HERRAMIENTAS ----------
    T -Id 'tools-safe-mode' -Cat 'tools' -Icon 'E7BA' -Risk 'danger' -Run 'inline' `
        -Name 'Reiniciar en modo seguro' -Desc 'Programa el arranque en modo seguro con red. Se revierte desde la misma tarjeta' -Code @'
HR "MODO SEGURO"
Step "Configuracion de arranque actual"
bcdedit /enum "{current}" | Select-String "safeboot|description|identifier"
WARN "El equipo arrancara en MODO SEGURO CON RED en el proximo reinicio."
WARN "Para volver a la normalidad usa la opcion 'Revertir este cambio' de esta misma tarjeta, o ejecuta: bcdedit /deletevalue {current} safeboot"
bcdedit /set "{current}" safeboot network
if ($LASTEXITCODE -eq 0) {
    OK "Modo seguro programado."
    INFO "Reinicia cuando quieras: shutdown /r /t 0"
}
else { ERR "No se pudo configurar el arranque." }
'@ -Revert @'
HR "SALIR DEL MODO SEGURO"
bcdedit /deletevalue "{current}" safeboot
if ($LASTEXITCODE -eq 0) { OK "El proximo arranque sera normal." } else { WARN "No habia modo seguro configurado." }
bcdedit /enum "{current}" | Select-String "safeboot|description"
'@

    T -Id 'tools-recovery-usb' -Cat 'tools' -Icon 'E88E' -Risk 'safe' -Run 'inline' `
        -Name 'Crear unidad de recuperacion' -Desc 'Abre el asistente para hacer un USB de rescate de este equipo' -Code @'
HR "UNIDAD DE RECUPERACION"
Step "Estado de WinRE"
reagentc /info 2>&1 | ForEach-Object { Write-Host "    $_" }
Step "Unidades USB disponibles"
Get-Disk -ErrorAction SilentlyContinue | Where-Object BusType -eq "USB" | ForEach-Object {
    ROW $_.FriendlyName "$(Human $_.Size)  numero $($_.Number)"
}
WARN "El asistente BORRA por completo el USB que elijas. Necesita al menos 16 GB."
Start-Process "RecoveryDrive.exe"
OK "Asistente abierto."
INFO "Alternativa mas versatil: instalar Ventoy o Rufus desde el repositorio de aplicaciones."
'@

    T -Id 'tools-shutdown-timer' -Cat 'tools' -Icon 'E7E8' -Risk 'care' -Run 'inline' `
        -Name 'Programar apagado' -Desc 'Apaga el equipo dentro de una hora. Se cancela desde la misma tarjeta' -Code @'
HR "APAGADO PROGRAMADO"
$seg = 3600
shutdown /a 2>$null
shutdown /s /t $seg /c "Apagado programado por ToolboxBS"
if ($LASTEXITCODE -eq 0) {
    OK "El equipo se apagara a las $((Get-Date).AddSeconds($seg).ToString('HH:mm'))."
    INFO "Para cancelar: usa 'Revertir este cambio' o ejecuta  shutdown /a"
}
else { ERR "No se pudo programar el apagado." }
'@ -Revert @'
shutdown /a
OK "Apagado programado cancelado."
'@

    T -Id 'tools-rdp-enable' -Cat 'tools' -Icon 'E8AF' -Risk 'danger' -Run 'inline' `
        -Name 'Habilitar escritorio remoto' -Desc 'Activa RDP con autenticacion de red y abre el puerto solo en la red privada' -Code @'
HR "ESCRITORIO REMOTO"
Set-Reg "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0
Set-Reg "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" "UserAuthentication" 1
Step "Regla de firewall (solo perfil privado)"
try {
    Enable-NetFirewallRule -DisplayGroup "Escritorio remoto" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Set-NetFirewallRule -DisplayGroup "Escritorio remoto" -Profile Private -ErrorAction SilentlyContinue
    Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Profile Private -ErrorAction SilentlyContinue
    OK "Puerto 3389 abierto unicamente en redes privadas."
}
catch { WARN "No se pudo ajustar el firewall: $($_.Exception.Message)" }
Start-Svc @("TermService")
Step "Datos de conexion"
ROW "Equipo" $env:COMPUTERNAME
Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address } | ForEach-Object { ROW "  IP" $_.IPv4Address.IPAddress }
ROW "Usuario" "$env:COMPUTERNAME\$env:USERNAME"
WARN "Nunca expongas el puerto 3389 a Internet directamente. Usa VPN o Tailscale."
'@ -Revert @'
Set-Reg "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 1
Disable-NetFirewallRule -DisplayGroup "Escritorio remoto" -ErrorAction SilentlyContinue
Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
OK "Escritorio remoto deshabilitado."
'@

    T -Id 'tools-clipboard' -Cat 'tools' -Icon 'E8C8' -Risk 'safe' -Run 'inline' `
        -Name 'Historial del portapapeles' -Desc 'Activa Win+V para recuperar lo ultimo que copiaste' -Code @'
HR "PORTAPAPELES"
Set-Reg "HKCU:\Software\Microsoft\Clipboard" "EnableClipboardHistory" 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 1
OK "Historial del portapapeles activo: pulsa Win+V."
INFO "Guarda hasta 25 elementos y se borra al reiniciar salvo que ancles alguno."
'@ -Revert @'
Set-Reg "HKCU:\Software\Microsoft\Clipboard" "EnableClipboardHistory" 0
OK "Historial del portapapeles desactivado."
'@

    T -Id 'tools-winget-restore' -Cat 'tools' -Icon 'E896' -Risk 'care' -Run 'term' `
        -Name 'Restaurar software desde export' -Desc 'Reinstala de golpe todo el software del archivo winget_export generado antes de formatear' -Code @'
HR "RESTAURAR SOFTWARE"
if (-not (Need-Winget)) { return }
$dir = BSDir "reportes"
$f = Get-ChildItem $dir -Filter "winget_export_*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $f) {
    ERR "No hay ningun winget_export_*.json en $dir"
    INFO "Generalo antes de formatear con: Informacion > Inventario de software"
    return
}
INFO "Usando: $($f.FullName)"
Step "Instalando (esto tarda bastante)"
winget import -i "$($f.FullName)" --accept-package-agreements --accept-source-agreements --ignore-unavailable --ignore-versions
OK "Restauracion finalizada."
'@

    T -Id 'tools-context-menu' -Cat 'tools' -Icon 'E70F' -Risk 'safe' -Run 'inline' `
        -Name 'Menu contextual de tecnico' -Desc 'Agrega Abrir PowerShell aqui, Tomar propiedad y Copiar ruta al clic derecho' -Code @'
HR "MENU CONTEXTUAL AVANZADO"
Step "Abrir PowerShell como administrador aqui"
foreach ($base in @("HKCU:\Software\Classes\Directory\Background\shell", "HKCU:\Software\Classes\Directory\shell")) {
    $k = "$base\BS_PowerShellAdmin"
    New-Item $k -Force | Out-Null
    Set-ItemProperty $k -Name "(Default)" -Value "Abrir PowerShell aqui (Admin)" -Force
    Set-ItemProperty $k -Name "Icon" -Value "powershell.exe" -Force
    New-Item "$k\command" -Force | Out-Null
    $cmd = if ($base -like "*Background*") {
        'powershell.exe -NoExit -Command "Start-Process powershell -Verb RunAs -ArgumentList ''-NoExit'',''-Command'',''Set-Location -LiteralPath \"%V\"''"'
    }
    else {
        'powershell.exe -NoExit -Command "Start-Process powershell -Verb RunAs -ArgumentList ''-NoExit'',''-Command'',''Set-Location -LiteralPath \"%1\"''"'
    }
    Set-ItemProperty "$k\command" -Name "(Default)" -Value $cmd -Force
}
OK "Anadido: Abrir PowerShell aqui (Admin)"

Step "Tomar propiedad de archivos y carpetas"
foreach ($tipo in @("*", "Directory")) {
    $k = "HKCU:\Software\Classes\$tipo\shell\BS_TomarPropiedad"
    New-Item $k -Force | Out-Null
    Set-ItemProperty $k -Name "(Default)" -Value "Tomar propiedad" -Force
    Set-ItemProperty $k -Name "Icon" -Value "imageres.dll,-78" -Force
    New-Item "$k\command" -Force | Out-Null
    $c = if ($tipo -eq "Directory") {
        'cmd.exe /c takeown /f "%1" /r /d s && icacls "%1" /grant *S-1-5-32-544:F /t /c /l & pause'
    }
    else {
        'cmd.exe /c takeown /f "%1" && icacls "%1" /grant *S-1-5-32-544:F /c /l & pause'
    }
    Set-ItemProperty "$k\command" -Name "(Default)" -Value $c -Force
}
OK "Anadido: Tomar propiedad"

Step "Abrir ToolboxBS aqui"
$k = "HKCU:\Software\Classes\Directory\Background\shell\BS_Toolbox"
New-Item $k -Force | Out-Null
Set-ItemProperty $k -Name "(Default)" -Value "ToolboxBS" -Force
New-Item "$k\command" -Force | Out-Null
Set-ItemProperty "$k\command" -Name "(Default)" -Value "powershell.exe -NoProfile -Command `"iwr -useb https://brandonsepulveda.github.io/ToolboxBS | iex`"" -Force
OK "Anadido: ToolboxBS"

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe
OK "Menu contextual actualizado. Recuerda que en Windows 11 estan bajo 'Mostrar mas opciones' salvo que actives el menu clasico."
'@ -Revert @'
foreach ($k in @("HKCU:\Software\Classes\Directory\Background\shell\BS_PowerShellAdmin",
        "HKCU:\Software\Classes\Directory\shell\BS_PowerShellAdmin",
        "HKCU:\Software\Classes\*\shell\BS_TomarPropiedad",
        "HKCU:\Software\Classes\Directory\shell\BS_TomarPropiedad",
        "HKCU:\Software\Classes\Directory\Background\shell\BS_Toolbox")) {
    if (Test-Path $k) { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue; OK "Eliminado $k" }
}
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
'@
)

# --- Rutinas de un clic: son datos, no interfaz. Se definen junto al catalogo
#     para que -ExportCatalog pueda volcarlas sin construir la ventana. ---
$Global:Recetas = @(
    [pscustomobject]@{
        Nombre = 'Mantenimiento express'; Icon = 'E74D'; Color = 'AccentGreen'
        Desc   = 'Limpieza + DNS + TRIM'
        Ids    = @('clean-temp', 'clean-browsers', 'clean-recycle', 'clean-thumbs', 'net-dns-flush', 'perf-trim')
    }
    [pscustomobject]@{
        Nombre = 'El equipo va lento'; Icon = 'E945'; Color = 'AccentYellow'
        Desc   = 'Diagnostico + limpieza + tweaks'
        Ids    = @('clean-temp', 'clean-space-report', 'perf-startup', 'perf-background-apps', 'clean-ram', 'perf-visual', 'info-boot-history', 'info-disks', 'repair-events')
    }
    [pscustomobject]@{
        Nombre = 'Recien formateado'; Icon = 'E90F'; Color = 'AccentBlue'
        Desc   = 'Winget, debloat, tweaks base'
        Ids    = @('repair-restore-point', 'perf-install-winget', 'perf-explorer-tweaks', 'perf-context', 'perf-widgets', 'perf-bloat', 'perf-bing-search', 'perf-notifications', 'tools-clipboard', 'tools-context-menu', 'perf-ultimate', 'repair-time')
    }
    [pscustomobject]@{
        Nombre = 'Revision de seguridad'; Icon = 'EA18'; Color = 'AccentPurple'
        Desc   = 'Defender, cuentas, persistencias'
        Ids    = @('sec-defender-status', 'sec-defender-scan', 'sec-autoruns', 'sec-accounts', 'sec-logons', 'sec-ports', 'sec-hosts', 'sec-certs', 'sec-app-permissions', 'sec-updates')
    }
    [pscustomobject]@{
        Nombre = 'Antes de formatear'; Icon = 'E74E'; Color = 'AccentOrange'
        Desc   = 'Respalda drivers, claves y datos'
        Ids    = @('repair-drivers-backup', 'info-keys', 'net-wifi-pass', 'info-software', 'info-office', 'tools-backup-profile')
    }
    [pscustomobject]@{
        Nombre = 'Reporte para el cliente'; Icon = 'EB05'; Color = 'AccentCyan'
        Desc   = 'HTML completo + inventario'
        Ids    = @('info-report-html', 'info-disks', 'info-software')
    }
    [pscustomobject]@{
        Nombre = 'No hay internet'; Icon = 'E839'; Color = 'AccentRed'
        Desc   = 'Diagnostico y reset de red'
        Ids    = @('net-info', 'net-trace', 'net-vpn', 'net-proxy', 'net-dns-flush', 'repair-network')
    }
    [pscustomobject]@{
        Nombre = 'Windows no actualiza'; Icon = 'E895'; Color = 'AccentGreen'
        Desc   = 'Reset de update + SFC'
        Ids    = @('repair-wu-reset', 'clean-logs', 'repair-sfc-dism')
    }
    [pscustomobject]@{
        Nombre = 'Despues de un virus'; Icon = 'E730'; Color = 'AccentRed'
        Desc   = 'Reactiva Defender y limpia rastros'
        Ids    = @('repair-defender-reset', 'net-proxy', 'sec-hosts', 'sec-certs', 'sec-autoruns', 'sec-defender-scan', 'clean-browsers', 'clean-temp')
    }
    [pscustomobject]@{
        Nombre = 'Liberar espacio a fondo'; Icon = 'E74D'; Color = 'AccentGreen'
        Desc   = 'Todo lo que se puede borrar sin riesgo'
        Ids    = @('clean-space-report', 'clean-temp', 'clean-browsers', 'clean-apps-cache', 'clean-logs', 'clean-thumbs', 'clean-recycle', 'clean-cleanmgr', 'clean-all-users-temp')
    }
    [pscustomobject]@{
        Nombre = 'Perifericos que fallan'; Icon = 'E7F8'; Color = 'AccentYellow'
        Desc   = 'USB, audio, camara, Bluetooth'
        Ids    = @('repair-drivers-list', 'repair-usb', 'repair-audio', 'repair-camera', 'repair-bluetooth', 'info-usb-history')
    }
)

# --- Indice y metadatos de categorias ---
$Global:ToolIndex = @{}
foreach ($t in $Global:Catalog) { $Global:ToolIndex[$t.Id] = $t }

$Global:Cats = @(
    [pscustomobject]@{ Key = 'repair'; Nombre = 'Reparacion';   Sub = 'Arreglar lo que esta roto';        Icon = 'E90F'; Color = 'AccentRed' }
    [pscustomobject]@{ Key = 'clean';  Nombre = 'Limpieza';     Sub = 'Recuperar espacio y rendimiento';  Icon = 'E74D'; Color = 'AccentGreen' }
    [pscustomobject]@{ Key = 'perf';   Nombre = 'Rendimiento';  Sub = 'Tweaks y optimizacion';            Icon = 'E945'; Color = 'AccentYellow' }
    [pscustomobject]@{ Key = 'sec';    Nombre = 'Seguridad';    Sub = 'Defender, cuentas y hardening';    Icon = 'EA18'; Color = 'AccentPurple' }
    [pscustomobject]@{ Key = 'net';    Nombre = 'Red';          Sub = 'Conectividad y diagnostico';       Icon = 'E839'; Color = 'AccentCyan' }
    [pscustomobject]@{ Key = 'info';   Nombre = 'Informacion';  Sub = 'Reportes y diagnostico profundo';  Icon = 'E946'; Color = 'AccentBlue' }
    [pscustomobject]@{ Key = 'tools';  Nombre = 'Herramientas'; Sub = 'Consolas nativas y utilidades';    Icon = 'EC7A'; Color = 'AccentOrange' }
    [pscustomobject]@{ Key = 'apps';   Nombre = 'Aplicaciones'; Sub = 'Instalar software desatendido';    Icon = 'E896'; Color = 'AccentBlue' }
)

if ($SelfTest) {
    Write-Host "[selftest] catalogo: $($Global:Catalog.Count) herramientas" -ForegroundColor Green
    foreach ($c in $Global:Cats) {
        $n = ($Global:Catalog | Where-Object Cat -eq $c.Key).Count
        Write-Host ("           {0,-14} {1}" -f $c.Nombre, $n)
    }
    $dup = $Global:Catalog | Group-Object Id | Where-Object Count -gt 1
    if ($dup) { Write-Host "[selftest] IDS DUPLICADOS: $($dup.Name -join ', ')" -ForegroundColor Red }
    else { Write-Host "[selftest] sin ids duplicados" -ForegroundColor Green }
    $sinCode = $Global:Catalog | Where-Object { -not $_.Code }
    if ($sinCode) { Write-Host "[selftest] SIN CODIGO: $($sinCode.Id -join ', ')" -ForegroundColor Red }
    else { Write-Host "[selftest] todas las herramientas tienen codigo" -ForegroundColor Green }
    $malCat = $Global:Catalog | Where-Object { $_.Cat -notin $Global:Cats.Key }
    if ($malCat) { Write-Host "[selftest] CATEGORIA INVALIDA: $($malCat.Id -join ', ')" -ForegroundColor Red }

    $malSint = @()
    foreach ($t in $Global:Catalog) {
        foreach ($par in @(@{ n = 'Code'; v = $t.Code }, @{ n = 'Revert'; v = $t.Revert })) {
            if (-not $par.v) { continue }
            $errs = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput(($Global:Prelude + "`n" + $par.v), [ref]$null, [ref]$errs)
            if ($errs.Count) { $malSint += "$($t.Id) [$($par.n)] linea $($errs[0].Extent.StartLineNumber): $($errs[0].Message)" }
        }
    }
    if ($malSint) {
        Write-Host "[selftest] CODIGO CON ERRORES DE SINTAXIS ($($malSint.Count)):" -ForegroundColor Red
        $malSint | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    }
    else { Write-Host "[selftest] las $($Global:Catalog.Count) herramientas compilan sin errores" -ForegroundColor Green }
}

# ============================================================================
#  6.b MODO CONSOLA  (sin interfaz grafica)
#      ToolboxBS.ps1 -ListTools
#      ToolboxBS.ps1 -RunTool clean-temp,net-info
# ============================================================================
if ($ExportCatalog) {
    # Sin -WithCode sale solo la metadata (documentacion, indices, scripts).
    # Con -WithCode salen ademas el codigo, la reversion, el preludio, las
    # categorias y las rutinas: todo lo necesario para que otro producto
    # (la version web) se genere sin volver a escribir el PowerShell a mano.
    if ($WithCode) {
        [pscustomobject]@{
            Version    = '4.0'
            Generado   = (Get-Date).ToString('s')
            Preludio   = $Global:Prelude
            Categorias = $Global:Cats
            Rutinas    = $Global:Recetas
            Total      = $Global:Catalog.Count
            Tools      = @($Global:Catalog | Select-Object Id, Name, Desc, Icon, Cat, Risk, Run, Code, Revert)
        } | ConvertTo-Json -Depth 6 | Set-Content $ExportCatalog -Encoding UTF8
    }
    else {
        $Global:Catalog |
            Select-Object Id, Name, Desc, Cat, Risk, Run, @{ n = 'Reversible'; e = { [bool]$_.Revert } } |
            ConvertTo-Json -Depth 3 | Set-Content $ExportCatalog -Encoding UTF8
    }
    Write-Host "Catalogo exportado: $ExportCatalog  ($($Global:Catalog.Count) herramientas)"
    return
}

if ($ListTools) {
    foreach ($c in $Global:Cats) {
        Write-Host ""
        Write-Host ("== {0} ==" -f $c.Nombre.ToUpper()) -ForegroundColor Cyan
        $Global:Catalog | Where-Object Cat -eq $c.Key | ForEach-Object {
            $marca = if ($_.Risk -eq 'danger') { '!' } elseif ($_.Revert) { '~' } else { ' ' }
            Write-Host ("  {0} {1,-28} {2}" -f $marca, $_.Id, $_.Name)
        }
    }
    Write-Host ""
    Write-Host "  ! = cambio dificil de deshacer     ~ = reversible" -ForegroundColor DarkGray
    Write-Host "  Uso: .\ToolboxBS.ps1 -RunTool <id> [,<id2>...]" -ForegroundColor DarkGray
    return
}

if ($RunTool) {
    # Con -File, PowerShell entrega "a,b" como una sola cadena: lo normalizamos.
    $ids = @($RunTool | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($id in $ids) {
        $t = $Global:ToolIndex[$id]
        if (-not $t) { Write-Host "[X] No existe la herramienta '$id'. Usa -ListTools para ver el catalogo." -ForegroundColor Red; continue }
        Write-Host ""
        Write-Host ("=" * 78) -ForegroundColor Cyan
        Write-Host "  $($t.Name)" -ForegroundColor Cyan
        Write-Host ("=" * 78) -ForegroundColor Cyan
        $f = Join-Path $Global:BSTmp ("cli_" + $t.Id + ".ps1")
        ($Global:Prelude + "`r`n`r`n" + $t.Code) | Set-Content $f -Encoding UTF8
        & $Global:PsExe -NoProfile -ExecutionPolicy Bypass -File $f
        Remove-Item $f -Force -ErrorAction SilentlyContinue
    }
    return
}

# ============================================================================
#  7. INTERFAZ (XAML)
# ============================================================================
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="MainWindow" Title="ToolboxBS v4" Height="820" Width="1340" MinHeight="640" MinWidth="1080"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip" FontFamily="Segoe UI">

  <Window.Resources>
    <SolidColorBrush x:Key="Zinc950" Color="#09090b"/>
    <SolidColorBrush x:Key="Zinc900" Color="#18181b"/>
    <SolidColorBrush x:Key="Zinc850" Color="#1f1f22"/>
    <SolidColorBrush x:Key="Zinc800" Color="#27272a"/>
    <SolidColorBrush x:Key="Zinc700" Color="#3f3f46"/>
    <SolidColorBrush x:Key="Zinc500" Color="#71717a"/>
    <SolidColorBrush x:Key="Zinc400" Color="#a1a1aa"/>
    <SolidColorBrush x:Key="Zinc200" Color="#e4e4e7"/>
    <SolidColorBrush x:Key="AccentBlue" Color="#3b82f6"/>
    <SolidColorBrush x:Key="AccentBlueHover" Color="#2563eb"/>
    <SolidColorBrush x:Key="AccentRed" Color="#ef4444"/>
    <SolidColorBrush x:Key="AccentYellow" Color="#eab308"/>
    <SolidColorBrush x:Key="AccentGreen" Color="#10b981"/>
    <SolidColorBrush x:Key="AccentPurple" Color="#a855f7"/>
    <SolidColorBrush x:Key="AccentOrange" Color="#f97316"/>
    <SolidColorBrush x:Key="AccentCyan" Color="#06b6d4"/>

    <Style x:Key="SidebarBtn" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{StaticResource Zinc400}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Height" Value="42"/>
      <Setter Property="Margin" Value="0,1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="10,0"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource Zinc850}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="GhostBtn" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Foreground" Value="{StaticResource Zinc400}"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Padding" Value="14,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{StaticResource Zinc900}" BorderBrush="{StaticResource Zinc800}" BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="{StaticResource Zinc850}"/>
                <Setter TargetName="b" Property="BorderBrush" Value="{StaticResource Zinc500}"/>
                <Setter Property="Foreground" Value="{StaticResource Zinc200}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="Width" Value="42"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Foreground" Value="{StaticResource Zinc500}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="{StaticResource Zinc800}"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- TARJETA DE HERRAMIENTA -->
    <Style x:Key="ToolCard" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,11,11"/>
      <Setter Property="Width" Value="318"/>
      <Setter Property="Height" Value="84"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="bd" Background="{StaticResource Zinc900}" BorderBrush="{StaticResource Zinc800}" BorderThickness="1" CornerRadius="12" Padding="14,12">
              <Grid VerticalAlignment="Center">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Grid Grid.Column="0" Width="38" Height="38" Margin="0,0,12,0">
                  <Border CornerRadius="9" Background="{TemplateBinding Foreground}" Opacity="0.13"/>
                  <TextBlock Text="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}" FontFamily="Segoe MDL2 Assets" FontSize="17"
                             Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                </Grid>
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                  <TextBlock Text="{TemplateBinding Content}" FontSize="13.5" FontWeight="SemiBold" Foreground="{StaticResource Zinc200}" TextTrimming="CharacterEllipsis"/>
                  <TextBlock Text="{Binding ToolTip, RelativeSource={RelativeSource TemplatedParent}}" FontSize="11" Foreground="{StaticResource Zinc500}"
                             Margin="0,3,0,0" TextWrapping="Wrap" MaxHeight="30" TextTrimming="CharacterEllipsis"/>
                </StackPanel>
                <Border Grid.Column="2" x:Name="tr" Width="38" Height="21" CornerRadius="11" Background="{StaticResource Zinc800}"
                        BorderBrush="{StaticResource Zinc700}" BorderThickness="1" VerticalAlignment="Center" Margin="8,0,0,0">
                  <Ellipse x:Name="dot" Width="13" Height="13" Fill="{StaticResource Zinc500}" HorizontalAlignment="Left" Margin="3,0,0,0">
                    <Ellipse.RenderTransform><TranslateTransform X="0"/></Ellipse.RenderTransform>
                  </Ellipse>
                </Border>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource Zinc850}"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource Zinc700}"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource AccentBlue}"/>
                <Setter TargetName="bd" Property="Background" Value="#142563eb"/>
                <Setter TargetName="tr" Property="Background" Value="{StaticResource AccentBlue}"/>
                <Setter TargetName="tr" Property="BorderThickness" Value="0"/>
                <Setter TargetName="dot" Property="Fill" Value="White"/>
                <Setter TargetName="dot" Property="RenderTransform">
                  <Setter.Value><TranslateTransform X="17"/></Setter.Value>
                </Setter>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="StatCard" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource Zinc900}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Zinc800}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="12"/>
      <Setter Property="Padding" Value="18,15"/>
      <Setter Property="Margin" Value="0,0,12,12"/>
    </Style>

    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Background" Value="Transparent"/>
    </Style>
  </Window.Resources>

  <Border Background="{StaticResource Zinc950}" CornerRadius="12" BorderBrush="{StaticResource Zinc800}" BorderThickness="1">
    <Grid>
      <Border CornerRadius="12" Opacity="0.45">
        <Border.Background>
          <DrawingBrush Viewport="0,0,34,34" ViewportUnits="Absolute" TileMode="Tile">
            <DrawingBrush.Drawing>
              <GeometryDrawing>
                <GeometryDrawing.Pen><Pen Brush="#0AFFFFFF" Thickness="1"/></GeometryDrawing.Pen>
                <GeometryDrawing.Geometry>
                  <GeometryGroup>
                    <LineGeometry StartPoint="0,0" EndPoint="34,0"/>
                    <LineGeometry StartPoint="0,0" EndPoint="0,34"/>
                  </GeometryGroup>
                </GeometryDrawing.Geometry>
              </GeometryDrawing>
            </DrawingBrush.Drawing>
          </DrawingBrush>
        </Border.Background>
      </Border>

      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="252"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- SIDEBAR -->
        <Border Grid.Column="0" Background="#F218181b" CornerRadius="12,0,0,12" BorderBrush="{StaticResource Zinc800}" BorderThickness="0,0,1,0">
          <Grid Margin="0,18,0,16">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="20,0,20,20">
              <Border Width="38" Height="38" Background="{StaticResource Zinc950}" BorderBrush="{StaticResource Zinc800}" BorderThickness="1" CornerRadius="9" Margin="0,0,11,0">
                <TextBlock Text="BS" Foreground="{StaticResource AccentBlue}" FontWeight="Bold" FontSize="15" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <StackPanel VerticalAlignment="Center">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="TOOLBOX" Foreground="White" FontSize="17" FontWeight="Bold"/>
                  <TextBlock Text="BS" Foreground="{StaticResource AccentBlue}" FontSize="17" FontWeight="Bold"/>
                </StackPanel>
                <TextBlock x:Name="LblVersion" Text="v4.0 ENTERPRISE" Foreground="{StaticResource Zinc500}" FontSize="9.5" FontWeight="Bold"/>
              </StackPanel>
            </StackPanel>

            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="10,0">
              <StackPanel x:Name="NavPanel"/>
            </ScrollViewer>

            <StackPanel Grid.Row="2" Margin="14,10,14,0">
              <Border x:Name="AdminBadge" Background="#1410b981" CornerRadius="8" Padding="10,7" Margin="0,0,0,8">
                <StackPanel Orientation="Horizontal">
                  <TextBlock x:Name="AdminIcon" Text="&#xE72E;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="{StaticResource AccentGreen}" Margin="0,0,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="AdminTxt" Text="Modo administrador" Foreground="{StaticResource Zinc400}" FontSize="11" VerticalAlignment="Center"/>
                </StackPanel>
              </Border>
              <Button x:Name="BtnDocs" Style="{StaticResource SidebarBtn}" Height="36">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE82D;" FontFamily="Segoe MDL2 Assets" FontSize="14" Foreground="{StaticResource Zinc500}" Width="28" TextAlignment="Center"/>
                  <TextBlock Text="Documentacion" VerticalAlignment="Center" FontSize="12.5"/>
                </StackPanel>
              </Button>
            </StackPanel>
          </Grid>
        </Border>

        <!-- CONTENIDO -->
        <Grid Grid.Column="1">
          <Grid.RowDefinitions>
            <RowDefinition Height="62"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="76"/>
          </Grid.RowDefinitions>

          <Border Grid.Row="0" x:Name="TitleBar" Background="#E609090b" BorderBrush="{StaticResource Zinc800}" BorderThickness="0,0,0,1">
            <Grid Margin="26,0,14,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                <TextBlock x:Name="LblTitle" Text="Dashboard" FontSize="19" FontWeight="Bold" Foreground="White"/>
                <TextBlock x:Name="LblSub" Text="Centro de comando" FontSize="12.5" Foreground="{StaticResource Zinc500}" VerticalAlignment="Bottom" Margin="10,0,0,3"/>
              </StackPanel>

              <Border Grid.Column="1" x:Name="SearchBox" Background="{StaticResource Zinc900}" BorderBrush="{StaticResource Zinc800}" BorderThickness="1"
                      CornerRadius="8" Height="34" Margin="28,0,16,0" MaxWidth="420" HorizontalAlignment="Right" Visibility="Collapsed">
                <Grid Margin="10,0">
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                  </Grid.ColumnDefinitions>
                  <TextBlock Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="{StaticResource Zinc500}" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <Grid Grid.Column="1">
                    <TextBlock x:Name="SearchHint" Text="Buscar en todas las herramientas... (Ctrl+F)" Foreground="{StaticResource Zinc700}" FontSize="12.5" VerticalAlignment="Center" IsHitTestVisible="False"/>
                    <TextBox x:Name="SearchInput" Background="Transparent" Foreground="{StaticResource Zinc200}" BorderThickness="0" FontSize="12.5"
                             VerticalContentAlignment="Center" CaretBrush="{StaticResource AccentBlue}"/>
                  </Grid>
                  <Button Grid.Column="2" x:Name="BtnSearchClear" Style="{StaticResource WinBtn}" Width="24" Height="24" Content="&#xE711;" Visibility="Collapsed"/>
                </Grid>
              </Border>

              <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                <Button x:Name="BtnMin" Style="{StaticResource WinBtn}" Content="&#xE921;"/>
                <Button x:Name="BtnMax" Style="{StaticResource WinBtn}" Content="&#xE922;"/>
                <Button x:Name="BtnClose" Style="{StaticResource WinBtn}" Content="&#xE8BB;"/>
              </StackPanel>
            </Grid>
          </Border>

          <Grid Grid.Row="1">

            <!-- VISTA: DASHBOARD -->
            <ScrollViewer x:Name="ViewDash" VerticalScrollBarVisibility="Auto" Padding="26,20,20,10">
              <StackPanel Margin="0,0,8,20">
                <TextBlock x:Name="DashHello" Text="Bienvenido" FontSize="30" FontWeight="Bold" Foreground="White"/>
                <TextBlock x:Name="DashSub" Text="Estado del equipo en tiempo real" FontSize="13" Foreground="{StaticResource Zinc400}" Margin="0,4,0,22"/>

                <TextBlock Text="ESTADO EN VIVO" FontSize="10.5" FontWeight="Bold" Foreground="{StaticResource Zinc500}" Margin="0,0,0,10"/>
                <UniformGrid x:Name="StatGrid" Columns="4">
                  <Border Style="{StaticResource StatCard}">
                    <StackPanel>
                      <TextBlock Text="PROCESADOR" FontSize="10" FontWeight="Bold" Foreground="{StaticResource Zinc500}"/>
                      <TextBlock x:Name="StCpu" Text="--%" FontSize="26" FontWeight="Bold" Foreground="{StaticResource AccentBlue}" Margin="0,4,0,0"/>
                      <ProgressBar x:Name="BarCpu" Height="4" Maximum="100" Value="0" Foreground="{StaticResource AccentBlue}" Background="{StaticResource Zinc800}" BorderThickness="0" Margin="0,6,0,0"/>
                      <TextBlock x:Name="StCpuName" Text="" FontSize="10" Foreground="{StaticResource Zinc500}" Margin="0,6,0,0" TextTrimming="CharacterEllipsis"/>
                    </StackPanel>
                  </Border>
                  <Border Style="{StaticResource StatCard}">
                    <StackPanel>
                      <TextBlock Text="MEMORIA" FontSize="10" FontWeight="Bold" Foreground="{StaticResource Zinc500}"/>
                      <TextBlock x:Name="StRam" Text="--%" FontSize="26" FontWeight="Bold" Foreground="{StaticResource AccentPurple}" Margin="0,4,0,0"/>
                      <ProgressBar x:Name="BarRam" Height="4" Maximum="100" Value="0" Foreground="{StaticResource AccentPurple}" Background="{StaticResource Zinc800}" BorderThickness="0" Margin="0,6,0,0"/>
                      <TextBlock x:Name="StRamTxt" Text="" FontSize="10" Foreground="{StaticResource Zinc500}" Margin="0,6,0,0"/>
                    </StackPanel>
                  </Border>
                  <Border Style="{StaticResource StatCard}">
                    <StackPanel>
                      <TextBlock Text="DISCO DE SISTEMA" FontSize="10" FontWeight="Bold" Foreground="{StaticResource Zinc500}"/>
                      <TextBlock x:Name="StDisk" Text="--%" FontSize="26" FontWeight="Bold" Foreground="{StaticResource AccentGreen}" Margin="0,4,0,0"/>
                      <ProgressBar x:Name="BarDisk" Height="4" Maximum="100" Value="0" Foreground="{StaticResource AccentGreen}" Background="{StaticResource Zinc800}" BorderThickness="0" Margin="0,6,0,0"/>
                      <TextBlock x:Name="StDiskTxt" Text="" FontSize="10" Foreground="{StaticResource Zinc500}" Margin="0,6,0,0"/>
                    </StackPanel>
                  </Border>
                  <Border Style="{StaticResource StatCard}">
                    <StackPanel>
                      <TextBlock Text="ENCENDIDO" FontSize="10" FontWeight="Bold" Foreground="{StaticResource Zinc500}"/>
                      <TextBlock x:Name="StUp" Text="--" FontSize="26" FontWeight="Bold" Foreground="{StaticResource AccentOrange}" Margin="0,4,0,0"/>
                      <TextBlock x:Name="StUpTxt" Text="" FontSize="10" Foreground="{StaticResource Zinc500}" Margin="0,12,0,0"/>
                    </StackPanel>
                  </Border>
                  <!-- Solo se muestra en portatiles: en escritorio queda oculta y
                       la cuadricula vuelve a 4 columnas. -->
                  <Border x:Name="CardBat" Style="{StaticResource StatCard}" Visibility="Collapsed">
                    <StackPanel>
                      <TextBlock x:Name="StBatLbl" Text="BATERIA" FontSize="10" FontWeight="Bold" Foreground="{StaticResource Zinc500}"/>
                      <TextBlock x:Name="StBat" Text="--%" FontSize="26" FontWeight="Bold" Foreground="{StaticResource AccentGreen}" Margin="0,4,0,0"/>
                      <ProgressBar x:Name="BarBat" Height="4" Maximum="100" Value="0" Foreground="{StaticResource AccentGreen}" Background="{StaticResource Zinc800}" BorderThickness="0" Margin="0,6,0,0"/>
                      <TextBlock x:Name="StBatTxt" Text="" FontSize="10" Foreground="{StaticResource Zinc500}" Margin="0,6,0,0" TextTrimming="CharacterEllipsis"/>
                    </StackPanel>
                  </Border>
                </UniformGrid>

                <TextBlock Text="SALUD DEL SISTEMA" FontSize="10.5" FontWeight="Bold" Foreground="{StaticResource Zinc500}" Margin="0,10,0,10"/>
                <Border Style="{StaticResource StatCard}" Margin="0,0,12,18">
                  <StackPanel x:Name="HealthPanel"/>
                </Border>

                <TextBlock Text="ACCESOS DIRECTOS" FontSize="10.5" FontWeight="Bold" Foreground="{StaticResource Zinc500}" Margin="0,0,0,10"/>
                <WrapPanel x:Name="QuickPanel"/>

                <TextBlock Text="RUTINAS DE UN CLIC" FontSize="10.5" FontWeight="Bold" Foreground="{StaticResource Zinc500}" Margin="0,16,0,10"/>
                <WrapPanel x:Name="RecipePanel"/>
                <TextBlock Text="Ctrl+F buscar &#183; Ctrl+Enter ejecutar &#183; F5 refrescar &#183; F1 ayuda &#183; clic derecho en una tarjeta para ejecutarla sola o ver su codigo"
                           FontSize="11" Foreground="{StaticResource Zinc700}" Margin="2,14,0,0" TextWrapping="Wrap"/>
              </StackPanel>
            </ScrollViewer>

            <!-- VISTA: CUADRICULA DE HERRAMIENTAS -->
            <Grid x:Name="ViewGrid" Visibility="Collapsed">
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
              </Grid.RowDefinitions>
              <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="26,14,26,10">
                <Button x:Name="BtnSelAll" Style="{StaticResource GhostBtn}" Content="Seleccionar todo" Margin="0,0,8,0"/>
                <Button x:Name="BtnSelNone" Style="{StaticResource GhostBtn}" Content="Limpiar seleccion" Margin="0,0,8,0"/>
                <Button x:Name="BtnRevert" Style="{StaticResource GhostBtn}" Content="Revertir seleccionados" Margin="0,0,8,0"/>
                <TextBlock x:Name="LblCount" Text="" Foreground="{StaticResource Zinc500}" FontSize="11.5" VerticalAlignment="Center" Margin="6,0,0,0"/>
              </StackPanel>
              <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="26,0,18,10">
                <WrapPanel x:Name="CardPanel" Margin="0,0,0,20"/>
              </ScrollViewer>
            </Grid>

            <!-- VISTA: CONSOLA -->
            <Grid x:Name="ViewConsole" Visibility="Collapsed" Margin="26,14,20,10">
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
              </Grid.RowDefinitions>

              <Border Grid.Row="0" Background="{StaticResource Zinc900}" BorderBrush="{StaticResource Zinc800}" BorderThickness="1" CornerRadius="10" Padding="16,12" Margin="0,0,0,12">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                  </Grid.ColumnDefinitions>
                  <StackPanel Grid.Column="0">
                    <TextBlock x:Name="ConTask" Text="Sin tareas en ejecucion" Foreground="White" FontWeight="SemiBold" FontSize="14"/>
                    <TextBlock x:Name="ConStatus" Text="La consola muestra la salida de cada herramienta en vivo." Foreground="{StaticResource Zinc500}" FontSize="11.5" Margin="0,3,0,0"/>
                    <ProgressBar x:Name="ConBar" Height="4" Maximum="100" Value="0" Foreground="{StaticResource AccentBlue}" Background="{StaticResource Zinc800}" BorderThickness="0" Margin="0,10,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                    <Button x:Name="BtnConCancel" Style="{StaticResource GhostBtn}" Content="Detener" Margin="0,0,8,0" IsEnabled="False"/>
                    <Button x:Name="BtnConLog" Style="{StaticResource GhostBtn}" Content="Abrir registro" Margin="0,0,8,0"/>
                    <Button x:Name="BtnConClear" Style="{StaticResource GhostBtn}" Content="Limpiar"/>
                  </StackPanel>
                </Grid>
              </Border>

              <Border Grid.Row="1" Background="#0B0B0E" BorderBrush="{StaticResource Zinc800}" BorderThickness="1" CornerRadius="10" Padding="4">
                <RichTextBox x:Name="Con" IsReadOnly="True" Background="Transparent" Foreground="#d4d4d8" BorderThickness="0"
                             FontFamily="Cascadia Mono, Consolas, monospace" FontSize="12" VerticalScrollBarVisibility="Auto"
                             HorizontalScrollBarVisibility="Disabled" Padding="12,10"/>
              </Border>

              <TextBlock Grid.Row="2" x:Name="ConFoot" Text="" Foreground="{StaticResource Zinc500}" FontSize="11" Margin="4,10,0,0"/>
            </Grid>
          </Grid>

          <!-- DOCK INFERIOR -->
          <Border Grid.Row="2" Background="#E609090b" BorderBrush="{StaticResource Zinc800}" BorderThickness="0,1,0,0" Padding="26,0">
            <Grid>
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
                <TextBlock Text="SELECCIONADAS" Foreground="{StaticResource Zinc500}" FontSize="10.5" FontWeight="Bold" Margin="0,0,10,0" VerticalAlignment="Center"/>
                <Border x:Name="CounterBadge" Background="{StaticResource Zinc800}" CornerRadius="12" Width="26" Height="24" Margin="0,0,18,0">
                  <TextBlock x:Name="TxtCounter" Text="0" Foreground="{StaticResource Zinc200}" FontWeight="Bold" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <Button x:Name="BtnProfSave" Style="{StaticResource GhostBtn}" Content="Guardar perfil" Margin="0,0,8,0"/>
                <Button x:Name="BtnProfLoad" Style="{StaticResource GhostBtn}" Content="Cargar perfil"/>
              </StackPanel>

              <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                <CheckBox x:Name="ChkRestore" Content="Punto de restauracion antes" Foreground="{StaticResource Zinc400}" FontSize="11.5" VerticalAlignment="Center" Margin="0,0,18,0"/>
                <Button x:Name="BtnExecute" Width="196" Height="44" IsEnabled="False" Cursor="Hand">
                  <Button.Template>
                    <ControlTemplate TargetType="Button">
                      <Border x:Name="eb" Background="{StaticResource AccentBlue}" CornerRadius="11">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                          <TextBlock Text="&#xE768;" FontFamily="Segoe MDL2 Assets" Margin="0,0,10,0" Foreground="White" FontSize="15"/>
                          <TextBlock x:Name="et" Text="Ejecutar" FontWeight="Bold" Foreground="White" FontSize="14"/>
                        </StackPanel>
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="eb" Property="Background" Value="{StaticResource AccentBlueHover}"/>
                        </Trigger>
                        <Trigger Property="IsEnabled" Value="False">
                          <Setter TargetName="eb" Property="Background" Value="{StaticResource Zinc800}"/>
                          <Setter TargetName="et" Property="Foreground" Value="{StaticResource Zinc500}"/>
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Button.Template>
                </Button>
              </StackPanel>
            </Grid>
          </Border>
        </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

try {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    if ($SelfTest) { Write-Host "[selftest] XAML cargado correctamente" -ForegroundColor Green }
}
catch {
    Write-Error "Error al cargar la interfaz: $($_.Exception.Message)"
    if (-not $SelfTest) { Read-Host "ENTER para salir" }
    return
}

# ============================================================================
#  8. REFERENCIAS A CONTROLES
# ============================================================================
function UI($n) { return $window.FindName($n) }

$NavPanel = UI 'NavPanel';        $CardPanel = UI 'CardPanel'
$ViewDash = UI 'ViewDash';        $ViewGrid = UI 'ViewGrid';       $ViewConsole = UI 'ViewConsole'
$LblTitle = UI 'LblTitle';        $LblSub = UI 'LblSub';           $LblCount = UI 'LblCount'
$SearchBox = UI 'SearchBox';      $SearchInput = UI 'SearchInput'; $SearchHint = UI 'SearchHint'
$BtnSearchClear = UI 'BtnSearchClear'
$TxtCounter = UI 'TxtCounter';    $CounterBadge = UI 'CounterBadge'
$BtnExecute = UI 'BtnExecute';    $ChkRestore = UI 'ChkRestore'
$Con = UI 'Con';                  $ConTask = UI 'ConTask';         $ConStatus = UI 'ConStatus'
$ConBar = UI 'ConBar';            $ConFoot = UI 'ConFoot'
$HealthPanel = UI 'HealthPanel';  $QuickPanel = UI 'QuickPanel';   $RecipePanel = UI 'RecipePanel'
$DashHello = UI 'DashHello';      $DashSub = UI 'DashSub'

$Global:Cards = @()
$Global:CurCat = 'dash'
$Global:NavBtns = @{}

function Brush($n) { return $window.Resources[$n] }
function Glyph($hex) { try { return [string][char][Convert]::ToInt32($hex, 16) } catch { return [string][char]0xE946 } }

# ============================================================================
#  9. NAVEGACION LATERAL
# ============================================================================
function New-NavButton($key, $texto, $sub, $iconHex, $colorKey) {
    $b = New-Object System.Windows.Controls.Button
    $b.Style = $window.Resources['SidebarBtn']
    $b.Uid = $key
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $ic = New-Object System.Windows.Controls.TextBlock
    $ic.Text = Glyph $iconHex
    $ic.FontFamily = 'Segoe MDL2 Assets'
    $ic.FontSize = 15
    $ic.Width = 28
    $ic.TextAlignment = 'Center'
    $ic.Foreground = Brush $colorKey
    $ic.VerticalAlignment = 'Center'
    $tx = New-Object System.Windows.Controls.TextBlock
    $tx.Text = $texto
    $tx.FontSize = 13
    $tx.FontWeight = 'Medium'
    $tx.VerticalAlignment = 'Center'
    $tx.Foreground = Brush 'Zinc400'
    $cnt = New-Object System.Windows.Controls.TextBlock
    $cnt.FontSize = 10.5
    $cnt.Margin = '8,0,0,0'
    $cnt.VerticalAlignment = 'Center'
    $cnt.Foreground = Brush 'Zinc700'
    if ($sub) { $cnt.Text = $sub }
    $sp.Children.Add($ic) | Out-Null
    $sp.Children.Add($tx) | Out-Null
    $sp.Children.Add($cnt) | Out-Null
    $b.Content = $sp
    $destino = $key
    $b.Add_Click({ Show-View $destino }.GetNewClosure())
    $Global:NavBtns[$key] = $b
    return $b
}

function New-NavLabel($t) {
    $l = New-Object System.Windows.Controls.TextBlock
    $l.Text = $t
    $l.FontSize = 9.5
    $l.FontWeight = 'Bold'
    $l.Foreground = Brush 'Zinc700'
    $l.Margin = '14,16,0,6'
    return $l
}

$NavPanel.Children.Add((New-NavLabel 'PRINCIPAL')) | Out-Null
$NavPanel.Children.Add((New-NavButton 'dash' 'Dashboard' '' 'E80F' 'AccentBlue')) | Out-Null
$NavPanel.Children.Add((New-NavButton 'console' 'Consola' '' 'E756' 'AccentGreen')) | Out-Null
$NavPanel.Children.Add((New-NavLabel 'MODULOS')) | Out-Null
foreach ($c in $Global:Cats) {
    $n = @($Global:Catalog | Where-Object Cat -eq $c.Key).Count
    $NavPanel.Children.Add((New-NavButton $c.Key $c.Nombre "$n" $c.Icon $c.Color)) | Out-Null
}

# ============================================================================
# 10. TARJETAS DE HERRAMIENTAS
# ============================================================================
$Global:CatColor = @{}
foreach ($c in $Global:Cats) { $Global:CatColor[$c.Key] = $c.Color }

function New-ToolCard($t) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Style = $window.Resources['ToolCard']
    $cb.Content = $t.Name
    $cb.Tag = Glyph $t.Icon
    $cb.Uid = $t.Id
    $cb.Foreground = Brush $Global:CatColor[$t.Cat]
    $desc = $t.Desc
    if ($t.Risk -eq 'danger') { $desc = "[!] $desc" }
    elseif ($t.Revert) { $desc = "$desc  (reversible)" }
    $cb.ToolTip = $desc

    $tid = $t.Id
    $menu = New-Object System.Windows.Controls.ContextMenu
    $m1 = New-Object System.Windows.Controls.MenuItem
    $m1.Header = 'Ejecutar solo esta'
    $m1.Add_Click({ Start-BSRun @($Global:ToolIndex[$tid]) $false }.GetNewClosure())
    $menu.Items.Add($m1) | Out-Null
    if ($t.Revert) {
        $m2 = New-Object System.Windows.Controls.MenuItem
        $m2.Header = 'Revertir este cambio'
        $m2.Add_Click({ Start-BSRun @($Global:ToolIndex[$tid]) $true }.GetNewClosure())
        $menu.Items.Add($m2) | Out-Null
    }
    $m3 = New-Object System.Windows.Controls.MenuItem
    $m3.Header = 'Ver el codigo que ejecuta'
    $m3.Add_Click({
            $tt = $Global:ToolIndex[$tid]
            $f = Join-Path $Global:BSTmp ("ver_" + $tt.Id + ".ps1")
            ($Global:Prelude + "`r`n`r`n# ===== " + $tt.Name + " =====`r`n" + $tt.Code) | Set-Content $f -Encoding UTF8
            Start-Process notepad.exe $f
        }.GetNewClosure())
    $menu.Items.Add($m3) | Out-Null
    $cb.ContextMenu = $menu

    $cb.Add_Checked({ Update-Counter })
    $cb.Add_Unchecked({ Update-Counter })
    return $cb
}

foreach ($t in $Global:Catalog) {
    $card = New-ToolCard $t
    $CardPanel.Children.Add($card) | Out-Null
    $Global:Cards += $card
}

# ============================================================================
# 11. FILTRO Y CONTADOR
# ============================================================================
function Apply-Filter {
    $q = $SearchInput.Text
    if ($q) { $q = $q.Trim().ToLower() }
    $SearchHint.Visibility = if ($q) { 'Collapsed' } else { 'Visible' }
    $BtnSearchClear.Visibility = if ($q) { 'Visible' } else { 'Collapsed' }
    $vis = 0
    foreach ($c in $Global:Cards) {
        $t = $Global:ToolIndex[$c.Uid]
        $okCat = ($q -and $q.Length -ge 2) -or ($t.Cat -eq $Global:CurCat)
        $okTxt = $true
        if ($q -and $q.Length -ge 1) {
            $okTxt = ($t.Name.ToLower().Contains($q)) -or ($t.Desc.ToLower().Contains($q)) -or ($t.Id.ToLower().Contains($q))
        }
        if ($okCat -and $okTxt) { $c.Visibility = 'Visible'; $vis++ } else { $c.Visibility = 'Collapsed' }
    }
    if ($q -and $q.Length -ge 2) { $LblCount.Text = "$vis resultados en todo el catalogo" }
    else { $LblCount.Text = "$vis herramientas" }
}

function Update-Counter {
    $n = @($Global:Cards | Where-Object { $_.IsChecked }).Count
    $TxtCounter.Text = "$n"
    if ($n -gt 0) {
        $BtnExecute.IsEnabled = -not $Global:Running
        $CounterBadge.Background = Brush 'AccentBlue'
        $TxtCounter.Foreground = [System.Windows.Media.Brushes]::White
    }
    else {
        $BtnExecute.IsEnabled = $false
        $CounterBadge.Background = Brush 'Zinc800'
        $TxtCounter.Foreground = Brush 'Zinc200'
    }
}

function Show-View($key) {
    $Global:CurCat = $key
    foreach ($k in $Global:NavBtns.Keys) { $Global:NavBtns[$k].ClearValue([System.Windows.Controls.Control]::BackgroundProperty) }
    if ($Global:NavBtns.ContainsKey($key)) { $Global:NavBtns[$key].Background = Brush 'Zinc850' }

    $ViewDash.Visibility = 'Collapsed'; $ViewGrid.Visibility = 'Collapsed'; $ViewConsole.Visibility = 'Collapsed'
    $SearchBox.Visibility = 'Collapsed'

    switch ($key) {
        'dash' {
            $ViewDash.Visibility = 'Visible'
            $LblTitle.Text = 'Dashboard'; $LblSub.Text = 'Centro de comando'
        }
        'console' {
            $ViewConsole.Visibility = 'Visible'
            $LblTitle.Text = 'Consola'; $LblSub.Text = 'Salida en vivo y registro de la sesion'
        }
        default {
            $c = $Global:Cats | Where-Object Key -eq $key
            $ViewGrid.Visibility = 'Visible'
            $SearchBox.Visibility = 'Visible'
            $LblTitle.Text = $c.Nombre; $LblSub.Text = $c.Sub
            Apply-Filter
        }
    }
}

$SearchInput.Add_TextChanged({
        if ($Global:CurCat -in @('dash', 'console')) { return }
        Apply-Filter
    })
$BtnSearchClear.Add_Click({ $SearchInput.Text = '' })

(UI 'BtnSelAll').Add_Click({
        foreach ($c in $Global:Cards) { if ($c.Visibility -eq 'Visible') { $c.IsChecked = $true } }
    })
(UI 'BtnSelNone').Add_Click({ foreach ($c in $Global:Cards) { $c.IsChecked = $false } })
(UI 'BtnRevert').Add_Click({
        $sel = @($Global:Cards | Where-Object { $_.IsChecked } | ForEach-Object { $Global:ToolIndex[$_.Uid] } | Where-Object { $_.Revert })
        if ($sel.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Ninguna de las herramientas seleccionadas tiene accion de reversion.`n`nLas reversibles muestran '(reversible)' en su descripcion.", "ToolboxBS", 'OK', 'Information') | Out-Null
            return
        }
        Start-BSRun $sel $true
    })

# ============================================================================
# 12. CONSOLA INTEGRADA
# ============================================================================
$Global:ConPara = New-Object System.Windows.Documents.Paragraph
$Global:ConPara.Margin = New-Object System.Windows.Thickness 0
$Global:ConPara.LineHeight = 15
$doc = New-Object System.Windows.Documents.FlowDocument
$doc.Blocks.Add($Global:ConPara)
$Con.Document = $doc

$Global:ConBrushes = @{
    ok   = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(16, 185, 129)))
    err  = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(239, 68, 68)))
    warn = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(234, 179, 8)))
    info = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(6, 182, 212)))
    step = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(244, 244, 245)))
    head = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(59, 130, 246)))
    dim  = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(113, 113, 122)))
    norm = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(212, 212, 216)))
}

function Write-Con($texto, $tipo) {
    if ($null -eq $texto) { return }
    if (-not $tipo) {
        $tipo = 'norm'
        $tt = $texto.TrimStart()
        if ($tt.StartsWith('[OK]')) { $tipo = 'ok' }
        elseif ($tt.StartsWith('[X]')) { $tipo = 'err' }
        elseif ($tt.StartsWith('[!]')) { $tipo = 'warn' }
        elseif ($tt.StartsWith('[i]')) { $tipo = 'info' }
        elseif ($tt.StartsWith('>>')) { $tipo = 'step' }
        elseif ($tt.StartsWith('===')) { $tipo = 'head' }
        elseif ($tt.StartsWith('    ')) { $tipo = 'dim' }
    }
    $r = New-Object System.Windows.Documents.Run $texto
    $r.Foreground = $Global:ConBrushes[$tipo]
    if ($tipo -in @('head', 'step')) { $r.FontWeight = 'Bold' }
    $Global:ConPara.Inlines.Add($r)
    $Global:ConPara.Inlines.Add((New-Object System.Windows.Documents.LineBreak))
    if ($Global:ConPara.Inlines.Count -gt 14000) {
        $viejos = @($Global:ConPara.Inlines | Select-Object -First 6000)
        foreach ($v in $viejos) { $Global:ConPara.Inlines.Remove($v) | Out-Null }
    }
    $Con.ScrollToEnd()
}

(UI 'BtnConClear').Add_Click({ $Global:ConPara.Inlines.Clear() })
(UI 'BtnConLog').Add_Click({
        if ($Global:SesionLog -and (Test-Path $Global:SesionLog)) { Start-Process notepad.exe $Global:SesionLog }
        else { Start-Process explorer.exe $Global:BSLogs }
    })

# ============================================================================
# 13. MOTOR DE EJECUCION
# ============================================================================
$Global:Cola = New-Object System.Collections.Generic.Queue[object]
$Global:Proc = $null
$Global:OutFile = $null
$Global:TailPos = 0
$Global:Pending = ''
$Global:Running = $false
$Global:TotalTareas = 0
$Global:HechasTareas = 0
$Global:TareaActual = $null
$Global:SesionLog = $null
$Global:ModoRevert = $false
$Global:Inicio = $null

function Log-Sesion($linea) {
    if ($Global:SesionLog) {
        try { Add-Content -Path $Global:SesionLog -Value $linea -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
    }
}

function Emit($texto, $tipo) {
    Write-Con $texto $tipo
    Log-Sesion $texto
}

function Start-BSRun($tools, $revert) {
    if ($Global:Running) {
        [System.Windows.MessageBox]::Show("Ya hay una ejecucion en curso. Espera a que termine o pulsa Detener.", "ToolboxBS", 'OK', 'Warning') | Out-Null
        return
    }
    $tools = @($tools | Where-Object { $_ })
    if ($tools.Count -eq 0) { return }

    if ($revert) {
        $tools = @($tools | Where-Object { $_.Revert })
        if ($tools.Count -eq 0) { return }
    }

    # Confirmacion para herramientas de riesgo
    $peligrosas = @($tools | Where-Object { $_.Risk -eq 'danger' -and -not $revert })
    if ($peligrosas.Count -gt 0) {
        $lista = ($peligrosas | ForEach-Object { "   - " + $_.Name }) -join "`n"
        $r = [System.Windows.MessageBox]::Show(
            "Las siguientes acciones hacen cambios dificiles de deshacer:`n`n$lista`n`nSe recomienda crear un punto de restauracion antes.`n`nContinuar?",
            "Confirmar acciones de riesgo", 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }

    $Global:ModoRevert = [bool]$revert
    $Global:SesionLog = Join-Path $Global:BSLogs ("sesion_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    $Global:Inicio = Get-Date
    $Global:Cola.Clear()

    if ($ChkRestore.IsChecked -and -not $revert) {
        $Global:Cola.Enqueue($Global:ToolIndex['repair-restore-point'])
    }
    foreach ($t in $tools) { $Global:Cola.Enqueue($t) }

    $Global:TotalTareas = $Global:Cola.Count
    $Global:HechasTareas = 0
    $Global:Running = $true
    $BtnExecute.IsEnabled = $false
    (UI 'BtnConCancel').IsEnabled = $true

    Show-View 'console'
    $modo = if ($revert) { "REVERSION" } else { "EJECUCION" }
    Emit ""
    Emit ("=" * 78) 'head'
    Emit "  ToolboxBS v4 - $modo de $($Global:TotalTareas) tarea(s)" 'head'
    Emit "  $(Get-Date -Format 'dddd dd/MM/yyyy HH:mm:ss')  |  $env:COMPUTERNAME  |  $env:USERNAME" 'dim'
    Emit "  Registro: $($Global:SesionLog)" 'dim'
    Emit ("=" * 78) 'head'
    Next-BSTask
}

function Next-BSTask {
    if ($Global:Cola.Count -eq 0) { Finish-BSRun; return }

    $t = $Global:Cola.Dequeue()
    $Global:TareaActual = $t
    $Global:HechasTareas++
    $pct = [math]::Round(($Global:HechasTareas - 1) / $Global:TotalTareas * 100, 0)
    $ConBar.Value = $pct
    $ConTask.Text = "$($Global:HechasTareas)/$($Global:TotalTareas)  -  $($t.Name)"
    $ConStatus.Text = $t.Desc

    $codigo = if ($Global:ModoRevert -and $t.Revert) { $t.Revert } else { $t.Code }
    Emit ""
    Emit ("-" * 78) 'dim'
    Emit ">> [$($Global:HechasTareas)/$($Global:TotalTareas)] $($t.Name)" 'step'
    Emit ("-" * 78) 'dim'

    $script = $Global:Prelude + "`r`n`r`n" + $codigo
    $sf = Join-Path $Global:BSTmp ("task_" + $t.Id + "_" + [Guid]::NewGuid().ToString("N").Substring(0, 6) + ".ps1")
    Set-Content -Path $sf -Value $script -Encoding UTF8

    if ($t.Run -eq 'term') {
        Emit "[i] Esta herramienta necesita su propia ventana (es interactiva o muy larga). Se abrio aparte." 'info'
        $tail = "`r`nWrite-Host ''`r`nWrite-Host '--- Tarea finalizada. Pulsa ENTER para cerrar. ---'`r`nRead-Host | Out-Null"
        Add-Content -Path $sf -Value $tail -Encoding UTF8
        try {
            if ($Global:HasWT) {
                Start-Process "wt.exe" -ArgumentList "`"$Global:PsExe`" -NoProfile -ExecutionPolicy Bypass -File `"$sf`""
            }
            else {
                Start-Process $Global:PsExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$sf`""
            }
            Emit "[OK] Ventana lanzada." 'ok'
        }
        catch { Emit "[X] No se pudo abrir la ventana: $($_.Exception.Message)" 'err' }
        $window.Dispatcher.BeginInvoke([Action] { Next-BSTask }, 'Background') | Out-Null
        return
    }

    $Global:OutFile = Join-Path $Global:BSTmp ("out_" + [Guid]::NewGuid().ToString("N").Substring(0, 8) + ".log")
    Set-Content -Path $Global:OutFile -Value "" -Encoding UTF8
    $Global:TailPos = 0
    $Global:Pending = ''

    try {
        $Global:Proc = Start-Process -FilePath $Global:PsExe `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-NonInteractive", "-File", "`"$sf`"" `
            -RedirectStandardOutput $Global:OutFile `
            -RedirectStandardError ($Global:OutFile + ".err") `
            -NoNewWindow -PassThru -ErrorAction Stop
    }
    catch {
        Emit "[X] No se pudo iniciar la tarea: $($_.Exception.Message)" 'err'
        $Global:Proc = $null
        $window.Dispatcher.BeginInvoke([Action] { Next-BSTask }, 'Background') | Out-Null
    }
}

function Read-Tail {
    if (-not $Global:OutFile -or -not (Test-Path $Global:OutFile)) { return '' }
    try {
        $fs = [System.IO.File]::Open($Global:OutFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        if ($fs.Length -le $Global:TailPos) { $fs.Close(); return '' }
        $len = [int]([Math]::Min(262144, $fs.Length - $Global:TailPos))
        $null = $fs.Seek($Global:TailPos, [System.IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] $len
        $n = $fs.Read($buf, 0, $len)
        $fs.Close()
        $Global:TailPos += $n
        return [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
    }
    catch { return '' }
}

function Drain-Output {
    $txt = Read-Tail
    if (-not $txt) { return }
    $Global:Pending += $txt
    $partes = $Global:Pending -split "`r?`n"
    $Global:Pending = $partes[-1]
    for ($i = 0; $i -lt $partes.Count - 1; $i++) { Emit $partes[$i] }
}

function Flush-Errors {
    $ef = $Global:OutFile + ".err"
    if ($ef -and (Test-Path $ef)) {
        $c = Get-Content $ef -Raw -ErrorAction SilentlyContinue
        if ($c -and $c.Trim()) {
            foreach ($l in ($c -split "`r?`n")) { if ($l.Trim()) { Emit "[X] $l" 'err' } }
        }
        Remove-Item $ef -Force -ErrorAction SilentlyContinue
    }
}

function Finish-BSRun {
    $Global:Running = $false
    $Global:Proc = $null
    $ConBar.Value = 100
    (UI 'BtnConCancel').IsEnabled = $false
    $dur = if ($Global:Inicio) { (Get-Date) - $Global:Inicio } else { New-TimeSpan }
    Emit ""
    Emit ("=" * 78) 'head'
    Emit "  PROCESO COMPLETADO  -  $($Global:HechasTareas) tarea(s) en $([math]::Round($dur.TotalMinutes,1)) min" 'head'
    Emit "  Registro guardado en: $($Global:SesionLog)" 'dim'
    Emit ("=" * 78) 'head'
    $ConTask.Text = "Completado: $($Global:HechasTareas) tarea(s)"
    $ConStatus.Text = "Duracion $([math]::Round($dur.TotalMinutes,1)) minutos. Registro en $($Global:SesionLog)"
    $ConFoot.Text = "Ultima ejecucion: $(Get-Date -Format 'HH:mm:ss')  -  los reportes quedan en Documentos\ToolboxBS"
    foreach ($c in $Global:Cards) { $c.IsChecked = $false }
    Update-Counter
    Update-Health
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch { }
}

(UI 'BtnConCancel').Add_Click({
        if ($Global:Proc -and -not $Global:Proc.HasExited) {
            try {
                Start-Process taskkill.exe -ArgumentList "/PID", $Global:Proc.Id, "/T", "/F" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Emit "[!] Tarea detenida por el usuario." 'warn'
            }
            catch { }
        }
        $Global:Cola.Clear()
    })

# --- Temporizador que alimenta la consola ---
$Global:TimerRun = New-Object System.Windows.Threading.DispatcherTimer
$Global:TimerRun.Interval = [TimeSpan]::FromMilliseconds(180)
$Global:TimerRun.Add_Tick({
        if (-not $Global:Running) { return }
        if ($null -eq $Global:Proc) { return }
        Drain-Output
        if ($Global:Proc.HasExited) {
            Start-Sleep -Milliseconds 60
            Drain-Output
            if ($Global:Pending) { Emit $Global:Pending; $Global:Pending = '' }
            Flush-Errors
            $ec = $Global:Proc.ExitCode
            if ($ec -eq 0) { Emit "[OK] $($Global:TareaActual.Name): finalizada." 'ok' }
            else { Emit "[!] $($Global:TareaActual.Name): finalizo con codigo $ec." 'warn' }
            $Global:Proc = $null
            if ($Global:OutFile) { Remove-Item $Global:OutFile -Force -ErrorAction SilentlyContinue }
            Next-BSTask
        }
    })
$Global:TimerRun.Start()

$BtnExecute.Add_Click({
        $sel = @($Global:Cards | Where-Object { $_.IsChecked } | ForEach-Object { $Global:ToolIndex[$_.Uid] })
        Start-BSRun $sel $false
    })

# ============================================================================
# 14. DASHBOARD: ESTADO EN VIVO, SALUD, ATAJOS Y RUTINAS
# ============================================================================
function HumanUI([double]$b) {
    if ($b -lt 1KB) { return "$([math]::Round($b,0)) B" }
    elseif ($b -lt 1MB) { return "{0:N1} KB" -f ($b / 1KB) }
    elseif ($b -lt 1GB) { return "{0:N1} MB" -f ($b / 1MB) }
    elseif ($b -lt 1TB) { return "{0:N2} GB" -f ($b / 1GB) }
    else { return "{0:N2} TB" -f ($b / 1TB) }
}

$DashHello.Text = "Hola, $env:USERNAME"
$DashSub.Text = "$((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer) $((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Model)  -  $env:COMPUTERNAME  -  $($Global:Catalog.Count) herramientas disponibles"
(UI 'StCpuName').Text = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name

$Global:CpuCounter = $null
try { $Global:CpuCounter = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total"); $null = $Global:CpuCounter.NextValue() } catch { }

function Update-Stats {
    try {
        $cpu = if ($Global:CpuCounter) { [math]::Round($Global:CpuCounter.NextValue(), 0) }
        else { (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object LoadPercentage -Average).Average }
        if ($null -eq $cpu) { $cpu = 0 }
        if ($cpu -gt 100) { $cpu = 100 }
        (UI 'StCpu').Text = "$cpu%"
        (UI 'BarCpu').Value = $cpu

        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $tot = $os.TotalVisibleMemorySize * 1KB
            $lib = $os.FreePhysicalMemory * 1KB
            $pc = [math]::Round((($tot - $lib) / $tot) * 100, 0)
            (UI 'StRam').Text = "$pc%"
            (UI 'BarRam').Value = $pc
            (UI 'StRamTxt').Text = "$(HumanUI ($tot-$lib)) de $(HumanUI $tot)"

            $up = (Get-Date) - $os.LastBootUpTime
            (UI 'StUp').Text = if ($up.TotalDays -ge 1) { "$([int]$up.TotalDays)d $($up.Hours)h" } else { "$($up.Hours)h $($up.Minutes)m" }
            (UI 'StUpTxt').Text = "Desde $($os.LastBootUpTime.ToString('dd/MM HH:mm'))"
        }

        $v = Get-Volume -DriveLetter $env:SystemDrive[0] -ErrorAction SilentlyContinue
        if ($v -and $v.Size -gt 0) {
            $pd = [math]::Round((($v.Size - $v.SizeRemaining) / $v.Size) * 100, 0)
            (UI 'StDisk').Text = "$pd%"
            (UI 'BarDisk').Value = $pd
            (UI 'StDiskTxt').Text = "$(HumanUI $v.SizeRemaining) libres de $(HumanUI $v.Size)"
            $col = if ($pd -gt 90) { 'AccentRed' } elseif ($pd -gt 78) { 'AccentYellow' } else { 'AccentGreen' }
            (UI 'StDisk').Foreground = Brush $col
            (UI 'BarDisk').Foreground = Brush $col
        }

        Update-Bateria
    }
    catch { }
}

# Solo tiene sentido en portatiles. En escritorio la tarjeta queda oculta y la
# cuadricula se queda en 4 columnas.
function Update-Bateria {
    try {
        # La API de Windows es la misma que alimenta el icono de la bandeja y
        # responde en portatiles donde Win32_Battery viene vacio. WMI se usa
        # solo como respaldo.
        $ps = [System.Windows.Forms.SystemInformation]::PowerStatus
        $pct = $null
        $cargando = $null

        if ($ps.BatteryChargeStatus -ne 'NoSystemBattery') {
            if ($ps.BatteryLifePercent -ge 0 -and $ps.BatteryLifePercent -le 1) {
                $pct = [int][math]::Round($ps.BatteryLifePercent * 100)
            }
            $cargando = ($ps.PowerLineStatus -eq 'Online')
        }

        if ($null -eq $pct) {
            $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($bat) {
                $pct = [int]$bat.EstimatedChargeRemaining
                # 1 descargando, 2 en corriente, 6-9 cargando
                if ($null -eq $cargando) { $cargando = $bat.BatteryStatus -in @(2, 6, 7, 8, 9) }
            }
        }

        if ($null -eq $pct) {
            (UI 'CardBat').Visibility = 'Collapsed'
            (UI 'StatGrid').Columns = 4
            return
        }
        (UI 'CardBat').Visibility = 'Visible'
        (UI 'StatGrid').Columns = 5

        (UI 'StBat').Text = "$pct%"
        (UI 'BarBat').Value = $pct
        (UI 'StBatLbl').Text = if ($cargando) { "BATERIA - CARGANDO" } else { "BATERIA" }

        $col = if ($pct -le 15 -and -not $cargando) { 'AccentRed' }
        elseif ($pct -le 35 -and -not $cargando) { 'AccentYellow' }
        elseif ($cargando) { 'AccentCyan' }
        else { 'AccentGreen' }
        (UI 'StBat').Foreground = Brush $col
        (UI 'BarBat').Foreground = Brush $col

        # Salud real: capacidad a plena carga frente a la de diseno
        $detalle = @()
        $full = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1).FullChargedCapacity
        $dsg = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1).DesignedCapacity
        if ($full -and $dsg -and $dsg -gt 0) {
            $detalle += "salud $([math]::Round(($full / $dsg) * 100, 0))%"
        }
        if ($cargando) { $detalle += "conectada" }
        elseif ($ps.BatteryLifeRemaining -gt 0) {
            # la API lo da en segundos
            $h = [math]::Floor($ps.BatteryLifeRemaining / 3600)
            $m = [math]::Floor(($ps.BatteryLifeRemaining % 3600) / 60)
            $detalle += if ($h -gt 0) { "quedan ${h}h ${m}m" } else { "quedan ${m}m" }
        }
        elseif ($bat -and $bat.EstimatedRunTime -and $bat.EstimatedRunTime -lt 71582788) {
            # WMI lo da en minutos; 71582788 es su centinela de "no lo se"
            $h = [math]::Floor($bat.EstimatedRunTime / 60)
            $m = $bat.EstimatedRunTime % 60
            $detalle += if ($h -gt 0) { "quedan ${h}h ${m}m" } else { "quedan ${m}m" }
        }
        (UI 'StBatTxt').Text = ($detalle -join "  |  ")
    }
    catch { }
}

function Add-HealthRow($estado, $titulo, $detalle) {
    $g = New-Object System.Windows.Controls.Grid
    $g.Margin = '0,0,0,9'
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = 'Auto'
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = '210'
    $c3 = New-Object System.Windows.Controls.ColumnDefinition
    $g.ColumnDefinitions.Add($c1); $g.ColumnDefinitions.Add($c2); $g.ColumnDefinitions.Add($c3)

    $col = switch ($estado) { 'ok' { 'AccentGreen' } 'warn' { 'AccentYellow' } 'err' { 'AccentRed' } default { 'Zinc500' } }
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 8; $dot.Height = 8; $dot.Margin = '0,0,12,0'
    $dot.VerticalAlignment = 'Center'
    $dot.Fill = Brush $col
    [System.Windows.Controls.Grid]::SetColumn($dot, 0)

    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $titulo; $t1.FontSize = 12.5; $t1.Foreground = Brush 'Zinc200'; $t1.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($t1, 1)

    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = $detalle; $t2.FontSize = 12; $t2.Foreground = Brush 'Zinc500'
    $t2.TextTrimming = 'CharacterEllipsis'; $t2.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($t2, 2)

    $g.Children.Add($dot) | Out-Null
    $g.Children.Add($t1) | Out-Null
    $g.Children.Add($t2) | Out-Null
    $HealthPanel.Children.Add($g) | Out-Null
}

function Update-Health {
    $HealthPanel.Children.Clear()

    # Activacion
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($lic.LicenseStatus -eq 1) { Add-HealthRow 'ok' 'Licencia de Windows' "Activado  -  $($lic.ProductKeyChannel)" }
        else { Add-HealthRow 'err' 'Licencia de Windows' 'No activado  -  usa Rendimiento > Activar con licencia OEM' }
    }
    catch { Add-HealthRow 'na' 'Licencia de Windows' 'No se pudo consultar' }

    # Defender
    try {
        $d = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($d) {
            if ($d.RealTimeProtectionEnabled) { Add-HealthRow 'ok' 'Proteccion en tiempo real' "Activa  -  firmas de hace $($d.AntivirusSignatureAge) dia(s)" }
            else { Add-HealthRow 'err' 'Proteccion en tiempo real' 'APAGADA' }
        }
        else { Add-HealthRow 'na' 'Antivirus' 'Defender no responde (puede haber otro antivirus)' }
    }
    catch { Add-HealthRow 'na' 'Antivirus' 'No se pudo consultar' }

    # Firewall
    try {
        $fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue
        $off = @($fw | Where-Object { -not $_.Enabled })
        if ($off.Count -eq 0) { Add-HealthRow 'ok' 'Firewall' 'Los tres perfiles activos' }
        else { Add-HealthRow 'err' 'Firewall' "Desactivado en: $(($off.Name) -join ', ')" }
    }
    catch { }

    # Parches
    try {
        $hf = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($hf.InstalledOn) {
            $dias = ((Get-Date) - $hf.InstalledOn).Days
            $e = if ($dias -gt 60) { 'err' } elseif ($dias -gt 35) { 'warn' } else { 'ok' }
            Add-HealthRow $e 'Actualizaciones' "$($hf.HotFixID) instalado hace $dias dia(s)"
        }
    }
    catch { }

    # Espacio
    try {
        $v = Get-Volume -DriveLetter $env:SystemDrive[0] -ErrorAction SilentlyContinue
        $pd = [math]::Round((($v.Size - $v.SizeRemaining) / $v.Size) * 100, 0)
        $e = if ($pd -gt 90) { 'err' } elseif ($pd -gt 78) { 'warn' } else { 'ok' }
        Add-HealthRow $e "Espacio en $env:SystemDrive" "$(HumanUI $v.SizeRemaining) libres  -  $pd% ocupado"
    }
    catch { }

    # Salud de discos
    try {
        $mal = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.HealthStatus -ne 'Healthy' })
        if ($mal.Count -gt 0) { Add-HealthRow 'err' 'Salud de discos' "En riesgo: $(($mal.FriendlyName) -join ', ')" }
        else { Add-HealthRow 'ok' 'Salud de discos' "$(@(Get-PhysicalDisk -ErrorAction SilentlyContinue).Count) disco(s) en buen estado" }
    }
    catch { }

    # Punto de restauracion
    try {
        $p = Get-CimInstance -Namespace root/default -ClassName SystemRestore -ErrorAction Stop | Sort-Object CreationTime | Select-Object -Last 1
        if ($p) {
            $f = [System.Management.ManagementDateTimeConverter]::ToDateTime($p.CreationTime)
            $dias = ((Get-Date) - $f).Days
            $e = if ($dias -gt 30) { 'warn' } else { 'ok' }
            Add-HealthRow $e 'Punto de restauracion' "El mas reciente es de hace $dias dia(s)"
        }
        else { Add-HealthRow 'warn' 'Punto de restauracion' 'No hay ninguno: crea uno antes de tocar el sistema' }
    }
    catch { Add-HealthRow 'warn' 'Punto de restauracion' 'Proteccion del sistema desactivada' }

    # Reinicio pendiente
    $pend = $false
    foreach ($k in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")) {
        if (Test-Path $k) { $pend = $true }
    }
    if ($pend) { Add-HealthRow 'warn' 'Reinicio pendiente' 'Hay cambios que requieren reiniciar el equipo' }
    else { Add-HealthRow 'ok' 'Reinicio pendiente' 'Ninguno' }
}

# --- Accesos directos del dashboard ---
function New-QuickButton($texto, $iconHex, $colorKey, $accion) {
    $b = New-Object System.Windows.Controls.Button
    $b.Cursor = 'Hand'
    $b.Width = 168; $b.Height = 56; $b.Margin = '0,0,12,12'
    $b.Tag = $accion
    $tpl = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
  <Border x:Name="b" Background="#18181b" BorderBrush="#27272a" BorderThickness="1" CornerRadius="10">
    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
  </Border>
  <ControlTemplate.Triggers>
    <Trigger Property="IsMouseOver" Value="True">
      <Setter TargetName="b" Property="Background" Value="#1f1f22"/>
      <Setter TargetName="b" Property="BorderBrush" Value="#71717a"/>
    </Trigger>
  </ControlTemplate.Triggers>
</ControlTemplate>
'@)
    $b.Template = $tpl
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $sp.HorizontalAlignment = 'Center'
    $ic = New-Object System.Windows.Controls.TextBlock
    $ic.Text = Glyph $iconHex; $ic.FontFamily = 'Segoe MDL2 Assets'; $ic.FontSize = 16
    $ic.Foreground = Brush $colorKey; $ic.VerticalAlignment = 'Center'; $ic.Margin = '0,0,10,0'
    $tx = New-Object System.Windows.Controls.TextBlock
    $tx.Text = $texto; $tx.FontSize = 12.5; $tx.FontWeight = 'SemiBold'
    $tx.Foreground = Brush 'Zinc200'; $tx.VerticalAlignment = 'Center'
    $sp.Children.Add($ic) | Out-Null
    $sp.Children.Add($tx) | Out-Null
    $b.Content = $sp
    $cmd = $accion
    $b.Add_Click({ try { Start-Process $cmd } catch { [System.Windows.MessageBox]::Show("No se pudo abrir: $cmd", "ToolboxBS", 'OK', 'Warning') | Out-Null } }.GetNewClosure())
    return $b
}

$quicks = @(
    @{ t = 'Admin. tareas'; i = 'E9D9'; c = 'AccentBlue'; a = 'taskmgr.exe' }
    @{ t = 'Dispositivos'; i = 'E7F8'; c = 'AccentYellow'; a = 'devmgmt.msc' }
    @{ t = 'Servicios'; i = 'E713'; c = 'AccentPurple'; a = 'services.msc' }
    @{ t = 'Configuracion'; i = 'E713'; c = 'AccentGreen'; a = 'ms-settings:' }
    @{ t = 'Registro'; i = 'E70F'; c = 'AccentRed'; a = 'regedit.exe' }
    @{ t = 'PowerShell'; i = 'E756'; c = 'AccentBlue'; a = 'powershell.exe' }
    @{ t = 'Windows Update'; i = 'E895'; c = 'AccentGreen'; a = 'ms-settings:windowsupdate' }
    @{ t = 'Panel de control'; i = 'E74C'; c = 'AccentOrange'; a = 'control.exe' }
    @{ t = 'Discos'; i = 'EDA2'; c = 'AccentCyan'; a = 'diskmgmt.msc' }
    @{ t = 'Eventos'; i = 'E8F1'; c = 'AccentYellow'; a = 'eventvwr.msc' }
    @{ t = 'Seguridad'; i = 'EA18'; c = 'AccentPurple'; a = 'windowsdefender:' }
    @{ t = 'Info. sistema'; i = 'E946'; c = 'AccentBlue'; a = 'msinfo32.exe' }
)
foreach ($q in $quicks) { $QuickPanel.Children.Add((New-QuickButton $q.t $q.i $q.c $q.a)) | Out-Null }

function New-RecipeButton($r) {
    $b = New-Object System.Windows.Controls.Button
    $b.Cursor = 'Hand'; $b.Width = 250; $b.Height = 76; $b.Margin = '0,0,12,12'
    $b.Tag = $r.Nombre
    $tpl = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
  <Border x:Name="b" Background="#18181b" BorderBrush="#27272a" BorderThickness="1" CornerRadius="12" Padding="14,10">
    <ContentPresenter VerticalAlignment="Center"/>
  </Border>
  <ControlTemplate.Triggers>
    <Trigger Property="IsMouseOver" Value="True">
      <Setter TargetName="b" Property="Background" Value="#1f1f22"/>
      <Setter TargetName="b" Property="BorderBrush" Value="#3b82f6"/>
    </Trigger>
  </ControlTemplate.Triggers>
</ControlTemplate>
'@)
    $b.Template = $tpl
    $g = New-Object System.Windows.Controls.StackPanel
    $g.Orientation = 'Horizontal'
    $ic = New-Object System.Windows.Controls.TextBlock
    $ic.Text = Glyph $r.Icon; $ic.FontFamily = 'Segoe MDL2 Assets'; $ic.FontSize = 19
    $ic.Foreground = Brush $r.Color; $ic.VerticalAlignment = 'Center'; $ic.Margin = '2,0,14,0'
    $st = New-Object System.Windows.Controls.StackPanel
    $st.VerticalAlignment = 'Center'
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $r.Nombre; $t1.FontSize = 13; $t1.FontWeight = 'SemiBold'; $t1.Foreground = Brush 'Zinc200'
    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = "$($r.Desc)  -  $($r.Ids.Count) pasos"; $t2.FontSize = 10.5; $t2.Foreground = Brush 'Zinc500'; $t2.Margin = '0,3,0,0'
    $st.Children.Add($t1) | Out-Null
    $st.Children.Add($t2) | Out-Null
    $g.Children.Add($ic) | Out-Null
    $g.Children.Add($st) | Out-Null
    $b.Content = $g
    $nombreReceta = $r.Nombre
    $b.Add_Click({
            $r = $Global:Recetas | Where-Object Nombre -eq $nombreReceta
            foreach ($c in $Global:Cards) { $c.IsChecked = ($r.Ids -contains $c.Uid) }
            $faltan = @($r.Ids | Where-Object { -not $Global:ToolIndex.ContainsKey($_) })
            $primera = $Global:ToolIndex[$r.Ids[0]]
            if ($primera) { Show-View $primera.Cat }
            Update-Counter
            $msg = "Rutina '$($r.Nombre)': $(@($Global:Cards | Where-Object IsChecked).Count) herramientas seleccionadas.`n`nRevisa la seleccion y pulsa Ejecutar."
            if ($faltan.Count) { $msg += "`n`n(No encontradas: $($faltan -join ', '))" }
            [System.Windows.MessageBox]::Show($msg, "ToolboxBS", 'OK', 'Information') | Out-Null
        }.GetNewClosure())
    return $b
}
foreach ($r in $Global:Recetas) { $RecipePanel.Children.Add((New-RecipeButton $r)) | Out-Null }

# ============================================================================
# 15. PERFILES
# ============================================================================
(UI 'BtnProfSave').Add_Click({
        $sel = @($Global:Cards | Where-Object { $_.IsChecked } | ForEach-Object { $_.Uid })
        if ($sel.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Selecciona al menos una herramienta antes de guardar el perfil.", "ToolboxBS", 'OK', 'Information') | Out-Null
            return
        }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.InitialDirectory = $Global:BSProf
        $dlg.Filter = "Perfil ToolboxBS (*.json)|*.json"
        $dlg.FileName = "perfil_$(Get-Date -Format 'yyyyMMdd_HHmm').json"
        if ($dlg.ShowDialog()) {
            [pscustomobject]@{
                Nombre  = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
                Creado  = (Get-Date).ToString('s')
                Equipo  = $env:COMPUTERNAME
                Version = '4.0'
                Ids     = $sel
            } | ConvertTo-Json -Depth 4 | Set-Content $dlg.FileName -Encoding UTF8
            [System.Windows.MessageBox]::Show("Perfil guardado con $($sel.Count) herramientas:`n$($dlg.FileName)", "ToolboxBS", 'OK', 'Information') | Out-Null
        }
    })

(UI 'BtnProfLoad').Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.InitialDirectory = $Global:BSProf
        $dlg.Filter = "Perfil ToolboxBS (*.json)|*.json"
        if ($dlg.ShowDialog()) {
            try {
                $p = Get-Content $dlg.FileName -Raw | ConvertFrom-Json
                foreach ($c in $Global:Cards) { $c.IsChecked = ($p.Ids -contains $c.Uid) }
                Update-Counter
                $n = @($Global:Cards | Where-Object IsChecked).Count
                $falt = @($p.Ids | Where-Object { -not $Global:ToolIndex.ContainsKey($_) })
                $m = "Perfil cargado: $n de $($p.Ids.Count) herramientas."
                if ($falt.Count) { $m += "`n`nNo existen en esta version: $($falt -join ', ')" }
                [System.Windows.MessageBox]::Show($m, "ToolboxBS", 'OK', 'Information') | Out-Null
            }
            catch { [System.Windows.MessageBox]::Show("No se pudo leer el perfil: $($_.Exception.Message)", "ToolboxBS", 'OK', 'Error') | Out-Null }
        }
    })

# ============================================================================
# 16. VENTANA, ATAJOS Y ARRANQUE
# ============================================================================
(UI 'BtnClose').Add_Click({ $window.Close() })
(UI 'BtnMin').Add_Click({ $window.WindowState = 'Minimized' })
(UI 'BtnMax').Add_Click({
        if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' } else { $window.WindowState = 'Maximized' }
    })
(UI 'TitleBar').Add_MouseLeftButtonDown({
        if ($_.ClickCount -eq 2) {
            if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' } else { $window.WindowState = 'Maximized' }
        }
        else { $window.DragMove() }
    })
(UI 'BtnDocs').Add_Click({ Start-Process "https://brandonsepulveda.github.io/Documentacion.html" })

if (-not $Global:IsAdmin) {
    (UI 'AdminTxt').Text = 'Sin privilegios de administrador'
    (UI 'AdminIcon').Foreground = Brush 'AccentRed'
    (UI 'AdminBadge').Background = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(20, 239, 68, 68)))
}

$window.Add_KeyDown({
        if ($_.Key -eq 'F' -and [System.Windows.Input.Keyboard]::Modifiers -eq 'Control') {
            if ($Global:CurCat -in @('dash', 'console')) { Show-View 'repair' }
            $SearchInput.Focus() | Out-Null
            $_.Handled = $true
        }
        elseif ($_.Key -eq 'Escape') {
            if ($SearchInput.Text) { $SearchInput.Text = ''; $_.Handled = $true }
        }
        elseif ($_.Key -eq 'F5') { Update-Health; Update-Stats; $_.Handled = $true }
        elseif ($_.Key -eq 'F1') {
            [System.Windows.MessageBox]::Show(@"
ATAJOS DE TECLADO

  Ctrl + F        Buscar en las $($Global:Catalog.Count) herramientas
  Escape          Limpiar la busqueda
  Ctrl + Enter    Ejecutar la seleccion
  F5              Refrescar el estado del equipo
  F1              Esta ayuda

RATON

  Clic en la tarjeta       Seleccionar / quitar
  Clic derecho             Ejecutar solo esa, revertirla
                           o ver el codigo que corre

MODO CONSOLA (sin ventana)

  ToolboxBS.ps1 -ListTools
  ToolboxBS.ps1 -RunTool clean-temp,net-info
  ToolboxBS.ps1 -SelfTest

Los reportes, registros y respaldos quedan en
$($Global:BSRoot)
"@, "Ayuda de ToolboxBS", 'OK', 'Information') | Out-Null
            $_.Handled = $true
        }
        elseif ($_.Key -eq 'Return' -and [System.Windows.Input.Keyboard]::Modifiers -eq 'Control') {
            if ($BtnExecute.IsEnabled) { $BtnExecute.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) }
            $_.Handled = $true
        }
    })

$Global:TimerStats = New-Object System.Windows.Threading.DispatcherTimer
$Global:TimerStats.Interval = [TimeSpan]::FromSeconds(2)
$Global:TimerStats.Add_Tick({ if ($ViewDash.Visibility -eq 'Visible') { Update-Stats } })
$Global:TimerStats.Start()

$window.Add_Closing({
        try { $Global:TimerRun.Stop(); $Global:TimerStats.Stop() } catch { }
        if ($Global:Running -and $Global:Proc -and -not $Global:Proc.HasExited) {
            try { Start-Process taskkill.exe -ArgumentList "/PID", $Global:Proc.Id, "/T", "/F" -NoNewWindow -ErrorAction SilentlyContinue } catch { }
        }
        Get-ChildItem $Global:BSTmp -Filter "task_*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem $Global:BSTmp -Filter "out_*.log*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    })

Update-Stats
Update-Health
Show-View 'dash'
Write-Con "ToolboxBS v4 listo. $($Global:Catalog.Count) herramientas cargadas." 'head'
Write-Con "La salida de cada tarea aparece aqui en vivo y se guarda en Documentos\ToolboxBS\logs." 'dim'

if ($Shot) {
    Show-View $ShotView
    $w = 1340; $h = 820
    $root = $window.Content
    $root.Width = $w; $root.Height = $h
    $root.Measure((New-Object System.Windows.Size($w, $h)))
    $root.Arrange((New-Object System.Windows.Rect(0, 0, $w, $h)))
    $root.UpdateLayout()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    $root.UpdateLayout()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($root)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [System.IO.File]::Create($Shot)
    $enc.Save($fs); $fs.Close()
    Write-Host "[shot] $Shot"
    return
}

if ($SelfTest) {
    Write-Host "[selftest] interfaz construida: $($Global:Cards.Count) tarjetas, $($Global:NavBtns.Count) botones de navegacion" -ForegroundColor Green
    Write-Host "[selftest] rutinas: $($Global:Recetas.Count)" -ForegroundColor Green
    foreach ($r in $Global:Recetas) {
        $falt = @($r.Ids | Where-Object { -not $Global:ToolIndex.ContainsKey($_) })
        if ($falt) { Write-Host "[selftest] RUTINA '$($r.Nombre)' referencia ids inexistentes: $($falt -join ', ')" -ForegroundColor Red }
    }
    # --- Prueba funcional: simula los clics reales ---
    $fallos = @()
    $clickEvt = { New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent) }

    foreach ($k in @('clean', 'sec', 'dash', 'console', 'repair')) {
        $Global:NavBtns[$k].RaiseEvent((& $clickEvt))
        if ($Global:CurCat -ne $k) { $fallos += "la navegacion a '$k' no cambio de vista" }
    }
    if ($ViewGrid.Visibility -ne 'Visible') { $fallos += "la cuadricula no quedo visible tras navegar a 'repair'" }

    $SearchInput.Text = 'defender'
    $vis = @($Global:Cards | Where-Object { $_.Visibility -eq 'Visible' }).Count
    if ($vis -lt 1) { $fallos += "la busqueda 'defender' no devolvio resultados" }
    $SearchInput.Text = ''

    $Global:Cards[0].IsChecked = $true
    if ($TxtCounter.Text -ne '1') { $fallos += "el contador no reacciono al marcar una tarjeta" }
    if (-not $BtnExecute.IsEnabled) { $fallos += "el boton Ejecutar sigue deshabilitado con 1 seleccion" }
    $Global:Cards[0].IsChecked = $false
    if ($TxtCounter.Text -ne '0') { $fallos += "el contador no volvio a cero" }

    $r = $Global:Recetas[0]
    (UI 'RecipePanel').Children[0] | Out-Null
    foreach ($c in $Global:Cards) { $c.IsChecked = ($r.Ids -contains $c.Uid) }
    Update-Counter
    if ([int]$TxtCounter.Text -ne $r.Ids.Count) { $fallos += "la rutina '$($r.Nombre)' selecciono $($TxtCounter.Text) de $($r.Ids.Count)" }
    foreach ($c in $Global:Cards) { $c.IsChecked = $false }
    Update-Counter

    if ($fallos) {
        Write-Host "[selftest] FALLOS FUNCIONALES:" -ForegroundColor Red
        $fallos | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    }
    else { Write-Host "[selftest] navegacion, busqueda, contador y rutinas responden" -ForegroundColor Green }

    Write-Host "[selftest] OK" -ForegroundColor Green
    return
}

$null = $window.ShowDialog()
