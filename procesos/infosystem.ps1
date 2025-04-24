#======================================================================
# SystemInfoPlus.ps1
# Script avanzado para recopilación detallada de información del sistema
# Compatible con PowerShell 5.1 y superior
#======================================================================

Clear-Host
$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

# Función para crear encabezados con estilo
function Write-ColorHeader {
    param (
        [string]$Text,
        [string]$ForegroundColor = "Cyan"
    )
    
    $width = $host.UI.RawUI.WindowSize.Width - 4
    $line = "=" * $width
    Write-Host ""
    Write-Host $line -ForegroundColor $ForegroundColor
    Write-Host "  $Text" -ForegroundColor $ForegroundColor
    Write-Host $line -ForegroundColor $ForegroundColor
}

# Función para mostrar información con formato
function Write-InfoLine {
    param (
        [string]$Label,
        $Value,
        [string]$ValueColor = "White"
    )
    
    $LabelWidth = 30
    $formattedLabel = $Label.PadRight($LabelWidth, ".")
    Write-Host " $formattedLabel" -NoNewline -ForegroundColor "DarkGray"
    Write-Host " $Value" -ForegroundColor $ValueColor
}

# Función para crear una barra de progreso visual
function Write-ProgressBar {
    param (
        [int]$Percentage,
        [int]$BarSize = 25,
        [string]$BarColor = "Green",
        [string]$EmptyColor = "DarkGray"
    )
    
    $completedSize = [math]::Floor(($Percentage / 100) * $BarSize)
    $remainingSize = $BarSize - $completedSize
    
    Write-Host " [" -NoNewline
    Write-Host ("■" * $completedSize) -NoNewline -ForegroundColor $BarColor
    Write-Host ("□" * $remainingSize) -NoNewline -ForegroundColor $EmptyColor
    Write-Host "] $Percentage%" -ForegroundColor "DarkGray"
}

# Función para convertir bytes a formato legible
function Convert-Size {
    param(
        [double]$SizeInBytes
    )
    
    if ($SizeInBytes -lt 1KB) { return "$SizeInBytes B" }
    elseif ($SizeInBytes -lt 1MB) { return "{0:N2} KB" -f ($SizeInBytes / 1KB) }
    elseif ($SizeInBytes -lt 1GB) { return "{0:N2} MB" -f ($SizeInBytes / 1MB) }
    elseif ($SizeInBytes -lt 1TB) { return "{0:N2} GB" -f ($SizeInBytes / 1GB) }
    else { return "{0:N2} TB" -f ($SizeInBytes / 1TB) }
}

# Obtener información detallada de instalación
function Get-WindowsInstallDetails {
    try {
        # Obtener fecha precisa usando el registro (método más confiable)
        $installTime = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallTime
        $installDate = [DateTime]::FromFileTime([Int64]::Parse($installTime))
        
        # Intentar obtener información adicional desde el registro
        $detailedInstallInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
        
        # Devolver objeto con información detallada
        [PSCustomObject]@{
            InstallDate = $installDate
            InstallTime = $installDate.ToString("HH:mm:ss")
            DaysSinceInstall = [math]::Round(((Get-Date) - $installDate).TotalDays, 0)
            ReleaseId = $detailedInstallInfo.ReleaseId
            ProductName = $detailedInstallInfo.ProductName
            EditionID = $detailedInstallInfo.EditionID
            BuildBranch = $detailedInstallInfo.BuildBranch
            CurrentBuild = $detailedInstallInfo.CurrentBuild
        }
    }
    catch {
        # Si falla, intentar el método alternativo con WMI
        try {
            $OS = Get-CimInstance Win32_OperatingSystem
            $installDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($OS.InstallDate)
            
            # Devolver objeto con información básica
            [PSCustomObject]@{
                InstallDate = $installDate
                InstallTime = $installDate.ToString("HH:mm:ss")
                DaysSinceInstall = [math]::Round(((Get-Date) - $installDate).TotalDays, 0)
                ReleaseId = "Desconocido"
                ProductName = $OS.Caption
                EditionID = "Desconocido"
                BuildBranch = "Desconocido"
                CurrentBuild = $OS.BuildNumber
            }
        }
        catch {
            # Si todo falla, usar la fecha actual como fallback
            $installDate = Get-Date
            [PSCustomObject]@{
                InstallDate = $installDate
                InstallTime = $installDate.ToString("HH:mm:ss")
                DaysSinceInstall = 0
                ReleaseId = "Desconocido"
                ProductName = "Desconocido"
                EditionID = "Desconocido"
                BuildBranch = "Desconocido"
                CurrentBuild = "Desconocido"
            }
        }
    }
}
$installInfo = Get-WindowsInstallDetails

# Animación de carga inicial
Write-Host "`n`n" -NoNewline
$progressChars = @("/", "-", "\", "|")
foreach ($i in 1..15) {
    $char = $progressChars[$i % 4]
    Write-Host "`r $char Cargando sistema de diagnóstico avanzado... $($i * 6)%" -NoNewline -ForegroundColor "Yellow"
    Start-Sleep -Milliseconds 100
}
Write-Host "`r √ Sistema de diagnóstico cargado completamente.   " -ForegroundColor "Green"
Start-Sleep -Milliseconds 500
Clear-Host

# Logo y título
$title = @"
================================================================================
 _____           _              _____        __       _____  _           
/  ___|         | |            |_   _|      / _|     |  __ \| |          
\ `--.  _   _ __| |_ ___ _ __ ___| | _ __  | |_ ___  | |  \/| |_   _ ___ 
 `--. \| | | / _` | / _ \ '_ ` _ \| || '_ \ |  _/ _ \ | | __| | | | / __|
/\__/ /| |_| \__,_|  __/ | | | | | || | | || || (_) || |_\ \ | |_| \__ \
\____/  \__, |\__,_|\___|_| |_| |_\___|_| |_||_| \___/  \____/_|\__,_|___/
         __/ |                                                           
        |___/                Diagnóstico Avanzado v2.0 Complemento ToolboxBS by: Brandon Sepulveda
================================================================================
"@

Write-Host $title -ForegroundColor "Cyan"
Write-Host " Ejecutando diagnóstico completo del sistema..." -ForegroundColor "Yellow"
Write-Host " Fecha de ejecución: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')`n" -ForegroundColor "Gray"

#========================================
# INFORMACIÓN DEL SISTEMA OPERATIVO
#========================================
Write-ColorHeader "INFORMACIÓN DEL SISTEMA OPERATIVO"

$OS = Get-CimInstance Win32_OperatingSystem
$computerSystem = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS

# Datos básicos del SO
Write-InfoLine "Nombre del equipo" $env:COMPUTERNAME "Yellow"
Write-InfoLine "Usuario actual" "$env:USERDOMAIN\$env:USERNAME" "Yellow"
Write-InfoLine "Sistema Operativo" $OS.Caption "White"
Write-InfoLine "Versión" $OS.Version "White"
Write-InfoLine "Build" $OS.BuildNumber "White"
Write-InfoLine "Arquitectura" "$($OS.OSArchitecture)" "White"

# Información de instalación y actividad
Write-InfoLine "Fecha de instalación" $installInfo.InstallDate.ToString("dd/MM/yyyy HH:mm:ss") "Magenta"
Write-InfoLine "Días desde instalación" "$($installInfo.DaysSinceInstall) días" "Magenta"

# Intentar obtener información adicional del registro
try {
    $detailedInstallInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
    if ($detailedInstallInfo.ReleaseId) {
        Write-InfoLine "ID de versión" $detailedInstallInfo.ReleaseId "White"
    }
    if ($detailedInstallInfo.BuildBranch) {
        Write-InfoLine "Rama de compilación" $detailedInstallInfo.BuildBranch "White"
    }
} catch {
    # No hacer nada si falla
}

Write-InfoLine "Último arranque" $OS.LastBootUpTime.ToString("dd/MM/yyyy HH:mm:ss") "White"
$upTime = (Get-Date) - $OS.LastBootUpTime
Write-InfoLine "Tiempo activo" "$($upTime.Days) días, $($upTime.Hours) horas, $($upTime.Minutes) minutos" "Green"

# Información del fabricante
Write-InfoLine "Fabricante" $computerSystem.Manufacturer "White"
Write-InfoLine "Modelo" $computerSystem.Model "White"
Write-InfoLine "Número de serie BIOS" $bios.SerialNumber "White"

#========================================
# INFORMACIÓN DEL PROCESADOR
#========================================
Write-ColorHeader "INFORMACIÓN DEL PROCESADOR"

$processor = Get-CimInstance Win32_Processor
$cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

Write-InfoLine "Procesador" $processor.Name "White"
Write-InfoLine "Fabricante" $processor.Manufacturer "White"
Write-InfoLine "Núcleos físicos" $processor.NumberOfCores "White"
Write-InfoLine "Núcleos lógicos" $processor.NumberOfLogicalProcessors "White"
Write-InfoLine "Velocidad actual" "$($processor.CurrentClockSpeed) MHz" "White"
Write-InfoLine "Velocidad máxima" "$($processor.MaxClockSpeed) MHz" "White"
Write-InfoLine "Socket" $processor.SocketDesignation "White"
Write-InfoLine "Arquitectura" $processor.Architecture "White"
Write-InfoLine "Caché L2" "$($processor.L2CacheSize) KB" "White"
Write-InfoLine "Caché L3" "$($processor.L3CacheSize) KB" "White"

Write-Host " Uso actual del CPU" -NoNewline -ForegroundColor "DarkGray"
$cpuColor = if ($cpuLoad -lt 30) { "Green" } elseif ($cpuLoad -lt 70) { "Yellow" } else { "Red" }
Write-ProgressBar -Percentage $cpuLoad -BarColor $cpuColor

#========================================
# INFORMACIÓN DE MEMORIA
#========================================
Write-ColorHeader "INFORMACIÓN DE MEMORIA RAM"

$totalRAM = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
$usedRAM = [math]::Round($totalRAM - $availableRAM, 2)
$ramUsagePercentage = [math]::Round(($usedRAM / $totalRAM) * 100, 0)

Write-InfoLine "Memoria total instalada" "$totalRAM GB" "White"
Write-InfoLine "Memoria disponible" "$availableRAM GB" "White"
Write-InfoLine "Memoria en uso" "$usedRAM GB" "White"

Write-Host " Uso actual de memoria" -NoNewline -ForegroundColor "DarkGray"
$ramColor = if ($ramUsagePercentage -lt 30) { "Green" } elseif ($ramUsagePercentage -lt 70) { "Yellow" } else { "Red" }
Write-ProgressBar -Percentage $ramUsagePercentage -BarColor $ramColor

# Detalles específicos de los módulos de RAM
$physicalMemory = Get-CimInstance Win32_PhysicalMemory

$ramCounter = 1
foreach ($module in $physicalMemory) {
    $moduleCapacity = [math]::Round($module.Capacity / 1GB, 2)
    $moduleSpeed = $module.Speed
    $ramType = switch ($module.SMBIOSMemoryType) {
        22 {"DDR2"}
        24 {"DDR3"}
        26 {"DDR4"}
        default {"Desconocido"}
    }
    
    Write-Host "`n Módulo RAM #$ramCounter" -ForegroundColor "DarkCyan"
    Write-InfoLine "   Fabricante" $module.Manufacturer "White"
    Write-InfoLine "   Capacidad" "$moduleCapacity GB" "White"
    Write-InfoLine "   Velocidad" "$moduleSpeed MHz" "White"
    Write-InfoLine "   Tipo" $ramType "White"
    Write-InfoLine "   Número de serie" $module.SerialNumber "White"
    Write-InfoLine "   Banco" $module.BankLabel "White"
    Write-InfoLine "   Slot" $module.DeviceLocator "White"
    
    $ramCounter++
}

#========================================
# INFORMACIÓN DE ALMACENAMIENTO
#========================================
Write-ColorHeader "INFORMACIÓN DE ALMACENAMIENTO"

$diskdrives = Get-CimInstance Win32_DiskDrive
$diskCounter = 1

foreach ($disk in $diskdrives) {
    $partitions = $disk | Get-CimAssociatedInstance -ResultClassName Win32_DiskPartition
    
    $diskSize = [math]::Round($disk.Size / 1GB, 2)
    $diskModel = $disk.Model
    $diskInterface = $disk.InterfaceType
    
    Write-Host "`n Disco físico #$diskCounter" -ForegroundColor "DarkCyan"
    Write-InfoLine "   Modelo" $diskModel "White"
    Write-InfoLine "   Tamaño" "$diskSize GB" "White"
    Write-InfoLine "   Interfaz" $diskInterface "White"
    Write-InfoLine "   Número de serie" $disk.SerialNumber "White"
    Write-InfoLine "   Particiones" $partitions.Count "White"
    
    $partitionCounter = 1
    foreach ($partition in $partitions) {
        $logicaldisks = $partition | Get-CimAssociatedInstance -ResultClassName Win32_LogicalDisk
        
        foreach ($logicaldisk in $logicaldisks) {
            $freeSpace = [math]::Round($logicaldisk.FreeSpace / 1GB, 2)
            $totalSize = [math]::Round($logicaldisk.Size / 1GB, 2)
            $usedSpace = [math]::Round($totalSize - $freeSpace, 2)
            $percentFree = [math]::Round(($freeSpace / $totalSize) * 100, 0)
            $percentUsed = 100 - $percentFree
            
            Write-Host "`n    Volumen lógico" -ForegroundColor "DarkYellow"
            Write-InfoLine "      Letra de unidad" "$($logicaldisk.DeviceID)" "Yellow"
            Write-InfoLine "      Etiqueta" "$($logicaldisk.VolumeName)" "White"
            Write-InfoLine "      Sistema de archivos" "$($logicaldisk.FileSystem)" "White"
            Write-InfoLine "      Tamaño total" "$totalSize GB" "White"
            Write-InfoLine "      Espacio usado" "$usedSpace GB" "White"
            Write-InfoLine "      Espacio libre" "$freeSpace GB" "White"
            
            Write-Host "      Uso del disco" -NoNewline -ForegroundColor "DarkGray"
            $diskColor = if ($percentUsed -lt 70) { "Green" } elseif ($percentUsed -lt 90) { "Yellow" } else { "Red" }
            Write-ProgressBar -Percentage $percentUsed -BarColor $diskColor
            
            $partitionCounter++
        }
    }
    
    $diskCounter++
}

#========================================
# INFORMACIÓN DE TARJETA GRÁFICA
#========================================
Write-ColorHeader "INFORMACIÓN DE TARJETA GRÁFICA"

$videoControllers = Get-CimInstance Win32_VideoController

$gpuCounter = 1
foreach ($gpu in $videoControllers) {
    Write-Host "`n Tarjeta gráfica #$gpuCounter" -ForegroundColor "DarkCyan"
    Write-InfoLine "   Nombre" $gpu.Name "White"
    Write-InfoLine "   Fabricante" $gpu.VideoProcessor "White"
    Write-InfoLine "   Versión de controlador" $gpu.DriverVersion "White"
    Write-InfoLine "   Fecha del controlador" ([System.Management.ManagementDateTimeConverter]::ToDateTime($gpu.DriverDate).ToString("dd/MM/yyyy")) "White"
    Write-InfoLine "   Resolución actual" "$($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)" "White"
    Write-InfoLine "   Frecuencia de refresco" "$($gpu.CurrentRefreshRate) Hz" "White"
    Write-InfoLine "   Memoria dedicada" "$(Convert-Size $gpu.AdapterRAM)" "White"
    
    $gpuCounter++
}

#========================================
# INFORMACIÓN DE RED
#========================================
Write-ColorHeader "INFORMACIÓN DE RED"

$networkAdapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true -and $_.MACAddress -ne $null }

$adapterCounter = 1
foreach ($adapter in $networkAdapters) {
    $config = $adapter | Get-CimAssociatedInstance -ResultClassName Win32_NetworkAdapterConfiguration
    
    if ($config -ne $null) {
        Write-Host "`n Adaptador de red #$adapterCounter" -ForegroundColor "DarkCyan"
        Write-InfoLine "   Nombre" $adapter.Name "White"
        Write-InfoLine "   Fabricante" $adapter.Manufacturer "White"
        Write-InfoLine "   Tipo de adaptador" $adapter.AdapterType "White"
        Write-InfoLine "   Dirección MAC" $adapter.MACAddress "White"
        Write-InfoLine "   Velocidad" "$([math]::Round($adapter.Speed / 1000000, 0)) Mbps" "White"
        
        if ($config.IPAddress -ne $null) {
            Write-InfoLine "   Dirección IPv4" ($config.IPAddress | Where-Object { $_ -like "*.*" })[0] "White"
            Write-InfoLine "   Máscara de subred" $config.IPSubnet[0] "White"
            
            if ($config.DefaultIPGateway -ne $null) {
                Write-InfoLine "   Puerta de enlace" $config.DefaultIPGateway[0] "White"
            }
            
            if ($config.DNSServerSearchOrder -ne $null) {
                Write-InfoLine "   Servidor DNS primario" $config.DNSServerSearchOrder[0] "White"
                
                if ($config.DNSServerSearchOrder.Count -gt 1) {
                    Write-InfoLine "   Servidor DNS secundario" $config.DNSServerSearchOrder[1] "White"
                }
            }
        }
        
        Write-InfoLine "   Estado" $(if ($adapter.NetEnabled) { "Conectado" } else { "Desconectado" }) $(if ($adapter.NetEnabled) { "Green" } else { "Red" })
        
        $adapterCounter++
    }
}

# Estadísticas de red en tiempo real
$networkStats = Get-NetAdapterStatistics | Where-Object Status -eq "Up"
foreach ($stat in $networkStats) {
    $adapter = Get-NetAdapter | Where-Object InterfaceIndex -eq $stat.InterfaceIndex
    
    Write-Host "`n Estadísticas de red: $($adapter.Name)" -ForegroundColor "DarkCyan"
    Write-InfoLine "   Recibidos" "$(Convert-Size $stat.ReceivedBytes)" "White"
    Write-InfoLine "   Enviados" "$(Convert-Size $stat.SentBytes)" "White"
    Write-InfoLine "   Paquetes recibidos" $stat.ReceivedPackets "White"
    Write-InfoLine "   Paquetes enviados" $stat.SentPackets "White"
    Write-InfoLine "   Errores recibidos" $stat.ReceivedErrors "White"
    Write-InfoLine "   Errores enviados" $stat.SentErrors "White"
}

#========================================
# DISPOSITIVOS DE AUDIO
#========================================
Write-ColorHeader "DISPOSITIVOS DE AUDIO"

$audioDevices = Get-CimInstance Win32_SoundDevice

$audioCounter = 1
foreach ($audio in $audioDevices) {
    Write-Host "`n Dispositivo de audio #$audioCounter" -ForegroundColor "DarkCyan"
    Write-InfoLine "   Nombre" $audio.Name "White"
    Write-InfoLine "   Fabricante" $audio.Manufacturer "White"
    Write-InfoLine "   Estado" $(if ($audio.Status -eq "OK") { "Funcionando correctamente" } else { $audio.Status }) $(if ($audio.Status -eq "OK") { "Green" } else { "Red" })
    
    $audioCounter++
}

#========================================
# SERVICIOS CRÍTICOS
#========================================
Write-ColorHeader "SERVICIOS CRÍTICOS DEL SISTEMA"

$criticalServices = @(
    "wuauserv" # Windows Update
    "windefend" # Windows Defender
    "WSearch" # Windows Search
    "Audiosrv" # Audio
    "bits" # Background Intelligent Transfer
    "EventLog" # Registro de eventos
    "LanmanServer" # Servidor
    "LanmanWorkstation" # Estación de trabajo
    "Dnscache" # Caché DNS
    "Dhcp" # Cliente DHCP
    "TabletInputService" # Servicio de Panel de Escritura
    "ShellHWDetection" # Detección de hardware shell
)

foreach ($service in $criticalServices) {
    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
    
    if ($svc -ne $null) {
        $status = $svc.Status
        $statusColor = if ($status -eq "Running") { "Green" } else { "Red" }
        
        Write-InfoLine "$($svc.DisplayName)" "$status" $statusColor
    }
}

#========================================
# ACTUALIZACIONES INSTALADAS
#========================================
Write-ColorHeader "ÚLTIMAS ACTUALIZACIONES INSTALADAS"

$updates = Get-HotFix | Sort-Object -Property InstalledOn -Descending | Select-Object -First 10

$updateTable = @()
foreach ($update in $updates) {
    Write-InfoLine "$($update.HotFixID)" "$($update.Description) - $($update.InstalledOn.ToString('dd/MM/yyyy'))" "White"
}



#========================================
# RESUMEN Y SALUD DEL SISTEMA
#========================================
Write-ColorHeader "RESUMEN DE SALUD DEL SISTEMA"

# Calcular salud general del sistema (algoritmo mejorado)
try {
    # Salud del CPU
    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    if ($cpuLoad -eq $null) { $cpuLoad = 50 } # Valor por defecto si no se puede obtener
    $cpuHealth = if ($cpuLoad -lt 50) { 100 } elseif ($cpuLoad -lt 80) { 70 } else { 40 }
    
    # Salud de la RAM
    $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $availableRAM = [math]::Round((Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
    $usedRAM = [math]::Round($totalRAM - $availableRAM, 2)
    $ramUsagePercentage = [math]::Round(($usedRAM / $totalRAM) * 100, 0)
    $ramHealth = if ($ramUsagePercentage -lt 70) { 100 } elseif ($ramUsagePercentage -lt 90) { 60 } else { 30 }
    
    # Salud del disco
    $systemDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $diskFreePercent = [math]::Round(($systemDrive.FreeSpace / $systemDrive.Size) * 100, 0)
    $diskHealth = if ($diskFreePercent -gt 25) { 100 } elseif ($diskFreePercent -gt 10) { 60 } else { 20 }
    
    # Verificar el estado de actualización
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
        $pendingUpdates = $searchResult.Updates.Count
        $updateHealth = if ($pendingUpdates -eq 0) { 100 } elseif ($pendingUpdates -lt 5) { 80 } else { 60 }
    } catch {
        $updateHealth = 70  # Valor si no se puede determinar
    }
    
    # Calcular salud general
    $overallHealth = [math]::Round(($cpuHealth + $ramHealth + $diskHealth + $updateHealth) / 4)
    
    # Asignar colores según los valores de salud
    $cpuColor = if ($cpuHealth -gt 75) { "Green" } elseif ($cpuHealth -gt 50) { "Yellow" } else { "Red" }
    $ramColor = if ($ramHealth -gt 75) { "Green" } elseif ($ramHealth -gt 50) { "Yellow" } else { "Red" }
    $diskColor = if ($diskHealth -gt 75) { "Green" } elseif ($diskHealth -gt 50) { "Yellow" } else { "Red" }
    $updateColor = if ($updateHealth -gt 75) { "Green" } elseif ($updateHealth -gt 50) { "Yellow" } else { "Red" }
    $healthColor = if ($overallHealth -gt 75) { "Green" } elseif ($overallHealth -gt 50) { "Yellow" } else { "Red" }
    
    # Mostrar información de salud
    Write-InfoLine "Salud del procesador" "$cpuHealth%" $cpuColor
    Write-InfoLine "Uso actual de CPU" "$cpuLoad%" $cpuColor
    Write-InfoLine "Salud de la memoria" "$ramHealth%" $ramColor
    Write-InfoLine "Uso actual de RAM" "$ramUsagePercentage%" $ramColor
    Write-InfoLine "Salud del almacenamiento" "$diskHealth%" $diskColor
    Write-InfoLine "Espacio libre en disco C:" "$diskFreePercent%" $diskColor
    Write-InfoLine "Estado de actualizaciones" "$updateHealth%" $updateColor
    Write-InfoLine "Actualizaciones pendientes" "$pendingUpdates" $updateColor
} catch {
    Write-Host " Error al calcular la salud del sistema: $_" -ForegroundColor "Red"
    Write-Host " Se mostrarán valores estimados" -ForegroundColor "Yellow"
    
    # Valores por defecto en caso de error
    $cpuHealth = 70
    $ramHealth = 70
    $diskHealth = 70
    $updateHealth = 70
    $overallHealth = 70
    $healthColor = "Yellow"
    
    Write-InfoLine "Salud del procesador" "$cpuHealth% (estimado)" "Yellow"
    Write-InfoLine "Salud de la memoria" "$ramHealth% (estimado)" "Yellow"
    Write-InfoLine "Salud del almacenamiento" "$diskHealth% (estimado)" "Yellow"
    Write-InfoLine "Estado de actualizaciones" "$updateHealth% (estimado)" "Yellow"
}

# Mostrar barra de salud general del sistema
Write-Host "`n SALUD GENERAL DEL SISTEMA" -ForegroundColor "White"
Write-ProgressBar -Percentage $overallHealth -BarColor $healthColor -BarSize 50

# Mostrar reporte de rendimiento
Write-Host "`n INDICADORES DE RENDIMIENTO" -ForegroundColor "Cyan"
Write-InfoLine "Rendimiento del procesador" "$(100 - $cpuLoad)%" $(if ((100 - $cpuLoad) -gt 75) { "Green" } elseif ((100 - $cpuLoad) -gt 50) { "Yellow" } else { "Red" })
Write-InfoLine "Eficiencia de memoria" "$(100 - $ramUsagePercentage)%" $(if ((100 - $ramUsagePercentage) -gt 75) { "Green" } elseif ((100 - $ramUsagePercentage) -gt 50) { "Yellow" } else { "Red" })
Write-InfoLine "Estado general" "$overallHealth%" $healthColor

# Recomendaciones
Write-Host "`n RECOMENDACIONES" -ForegroundColor "Cyan"

if ($cpuHealth -lt 75) {
    Write-Host " • Verifica los procesos que consumen más CPU con el Administrador de tareas" -ForegroundColor "Yellow"
}

if ($ramHealth -lt 75) {
    Write-Host " • Considera cerrar aplicaciones para liberar memoria RAM" -ForegroundColor "Yellow"
}

if ($diskHealth -lt 75) {
    Write-Host " • Ejecuta la herramienta de limpieza de disco para liberar espacio" -ForegroundColor "Yellow"
}

if ($updateHealth -lt 90) {
    Write-Host " • Instala las actualizaciones pendientes del sistema" -ForegroundColor "Yellow"
}

if ($overallHealth -lt 50) {
    Write-Host " • Se recomienda una revisión más detallada del sistema" -ForegroundColor "Red"
}

#========================================
# OPCIÓN PARA GENERAR INFORME
#========================================

Write-ColorHeader "EXPORTAR RESULTADOS"
$generateReport = Read-Host " ¿Desea generar un informe HTML? (S/N)"

if ($generateReport -eq "S" -or $generateReport -eq "s") {
    Write-Host " Generando informe HTML completo..." -ForegroundColor "Yellow"
    
    $exportFolder = "$env:USERPROFILE\Documents"
    $exportFile = "$exportFolder\SystemInfoPlus_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

    # [Aquí va el código existente para generar el HTML]
    # Crear reporte HTML
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Informe SystemInfoPlus - $(Get-Date -Format 'dd/MM/yyyy')</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            color: #333;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            text-align: center;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #2980b9;
            border-left: 4px solid #3498db;
            padding-left: 10px;
            margin-top: 30px;
        }
        .section {
            margin-bottom: 30px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            padding: 12px 15px;
            border-bottom: 1px solid #ddd;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
        .indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 5px;
        }
        .green { background-color: #2ecc71; }
        .yellow { background-color: #f39c12; }
        .red { background-color: #e74c3c; }
        .progress-bar {
            background-color: #ecf0f1;
            border-radius: 13px;
            height: 20px;
            width: 100%;
            position: relative;
        }
        .progress-bar-fill {
            height: 100%;
            border-radius: 13px;
            position: absolute;
            top: 0;
            left: 0;
            transition: width 0.5s ease-in-out;
        }
        .progress-bar-text {
            position: absolute;
            width: 100%;
            text-align: center;
            color: black;
            font-weight: bold;
            font-size: 14px;
            line-height: 20px;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #7f8c8d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Informe de Sistema - SystemInfoPlus</h1>
        <p>Generado el $(Get-Date -Format 'dd/MM/yyyy') a las $(Get-Date -Format 'HH:mm:ss')</p>
        
        <div class="section">
            <h2>Información del Sistema</h2>
            <table>
                <tr>
                    <td>Nombre del equipo</td>
                    <td><strong>$env:COMPUTERNAME</strong></td>
                </tr>
                <tr>
                    <td>Usuario</td>
                    <td>$env:USERDOMAIN\$env:USERNAME</td>
                </tr>
                <tr>
                    <td>Sistema Operativo</td>
                    <td>$($OS.Caption)</td>
                </tr>
                <tr>
                    <td>Versión</td>
                    <td>$($OS.Version) (Build $($OS.BuildNumber))</td>
                </tr>
                <tr>
                    <td>Arquitectura</td>
                    <td>$($OS.OSArchitecture)</td>
                </tr>
                <tr>
                    <td>Último arranque</td>
                    <td>$($OS.LastBootUpTime.ToString("dd/MM/yyyy HH:mm:ss"))</td>
                </tr>
                <tr>
                    <td>Tiempo activo</td>
                    <td>$($upTime.Days) días, $($upTime.Hours) horas, $($upTime.Minutes) minutos</td>
                </tr>
                <tr>
                    <td>Fabricante</td>
                    <td>$($computerSystem.Manufacturer)</td>
                </tr>
                <tr>
                    <td>Modelo</td>
                    <td>$($computerSystem.Model)</td>
                </tr>
            </table>
        </div>
        
        <div class="section">
            <h2>Información de Instalación del Sistema</h2>
            <table>
                <tr>
                    <td>Fecha de instalación</td>
                    <td><strong>$($installInfo.InstallDate.ToString("dd/MM/yyyy HH:mm:ss"))</strong></td>
                </tr>
                <tr>
                    <td>Hora exacta de instalación</td>
                    <td><strong>$($installInfo.InstallTime)</strong></td>
                </tr>
                <tr>
                    <td>Antigüedad del sistema</td>
                    <td><strong>$($installInfo.DaysSinceInstall) días</strong></td>
                </tr>
                <tr>
                    <td>Versión del sistema</td>
                    <td>$($installInfo.ProductName)</td>
                </tr>
                <tr>
                    <td>ID de versión</td>
                    <td>$($installInfo.ReleaseId)</td>
                </tr>
                <tr>
                    <td>Edición</td>
                    <td>$($installInfo.EditionID)</td>
                </tr>
                <tr>
                    <td>Build</td>
                    <td>$($installInfo.CurrentBuild)</td>
                </tr>
                <tr>
                    <td>Rama de compilación</td>
                    <td>$($installInfo.BuildBranch)</td>
                </tr>
            </table>
        </div>
        
        <div class="section">
            <h2>Procesador</h2>
            <table>
                <tr>
                    <td>Nombre</td>
                    <td>$($processor.Name)</td>
                </tr>
                <tr>
                    <td>Núcleos físicos</td>
                    <td>$($processor.NumberOfCores)</td>
                </tr>
                <tr>
                    <td>Núcleos lógicos</td>
                    <td>$($processor.NumberOfLogicalProcessors)</td>
                </tr>
                <tr>
                    <td>Velocidad actual</td>
                    <td>$($processor.CurrentClockSpeed) MHz</td>
                </tr>
                <tr>
                    <td>Velocidad máxima</td>
                    <td>$($processor.MaxClockSpeed) MHz</td>
                </tr>
                <tr>
                    <td>Uso de CPU</td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress-bar-fill" style="width: $($cpuLoad)%; background-color: $(if($cpuLoad -lt 50){"#2ecc71"}elseif($cpuLoad -lt 80){"#f39c12"}else{"#e74c3c"});"></div>
                            <div class="progress-bar-text">$($cpuLoad)%</div>
                        </div>
                    </td>
                </tr>
            </table>
        </div>
        
        <div class="section">
            <h2>Memoria RAM</h2>
            <table>
                <tr>
                    <td>Memoria total</td>
                    <td>$($totalRAM) GB</td>
                </tr>
                <tr>
                    <td>Memoria en uso</td>
                    <td>$($usedRAM) GB</td>
                </tr>
                <tr>
                    <td>Memoria disponible</td>
                    <td>$($availableRAM) GB</td>
                </tr>
                <tr>
                    <td>Uso de memoria</td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress-bar-fill" style="width: $($ramUsagePercentage)%; background-color: $(if($ramUsagePercentage -lt 70){"#2ecc71"}elseif($ramUsagePercentage -lt 90){"#f39c12"}else{"#e74c3c"});"></div>
                            <div class="progress-bar-text">$($ramUsagePercentage)%</div>
                        </div>
                    </td>
                </tr>
            </table>
        </div>
        
        <div class="section">
            <h2>Almacenamiento</h2>
            <table>
                <tr>
                    <th>Unidad</th>
                    <th>Tamaño</th>
                    <th>Espacio libre</th>
                    <th>% Libre</th>
                    <th>Sistema de archivos</th>
                </tr>
                $(
                    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
                    $driveRows = foreach ($drive in $drives) {
                        $freeSpace = [math]::Round($drive.FreeSpace / 1GB, 2)
                        $totalSize = [math]::Round($drive.Size / 1GB, 2)
                        $percentFree = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 0)
                        $percentUsed = 100 - $percentFree
                        $color = if ($percentFree -gt 25) { "#2ecc71" } elseif ($percentFree -gt 10) { "#f39c12" } else { "#e74c3c" }
                        
                        "<tr>
                            <td>$($drive.DeviceID)</td>
                            <td>$totalSize GB</td>
                            <td>$freeSpace GB</td>
                            <td>
                                <div class='progress-bar'>
                                    <div class='progress-bar-fill' style='width: $percentUsed%; background-color: $color;'></div>
                                    <div class='progress-bar-text'>$percentFree%</div>
                                </div>
                            </td>
                            <td>$($drive.FileSystem)</td>
                        </tr>"
                    }
                    $driveRows -join ""
                )
            </table>
        </div>
        
        <div class="section">
            <h2>Tarjeta Gráfica</h2>
            <table>
                <tr>
                    <th>Nombre</th>
                    <th>Memoria</th>
                    <th>Resolución</th>
                    <th>Controlador</th>
                </tr>
                $(
                    $gpuRows = foreach ($gpu in $videoControllers) {
                        "<tr>
                            <td>$($gpu.Name)</td>
                            <td>$(Convert-Size $gpu.AdapterRAM)</td>
                            <td>$($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution) ($($gpu.CurrentRefreshRate) Hz)</td>
                            <td>$($gpu.DriverVersion)</td>
                        </tr>"
                    }
                    $gpuRows -join ""
                )
            </table>
        </div>
        
        <div class="section">
            <h2>Red</h2>
            <table>
                <tr>
                    <th>Adaptador</th>
                    <th>IPv4</th>
                    <th>MAC</th>
                    <th>Velocidad</th>
                    <th>Estado</th>
                </tr>
                $(
                    $netRows = foreach ($adapter in ($networkAdapters | Where-Object { $_.PhysicalAdapter -eq $true })) {
                        $config = $adapter | Get-CimAssociatedInstance -ResultClassName Win32_NetworkAdapterConfiguration
                        $ipAddress = if ($config.IPAddress) { ($config.IPAddress | Where-Object { $_ -like "*.*" })[0] } else { "N/A" }
                        $speed = if ($adapter.Speed) { "$([math]::Round($adapter.Speed / 1000000, 0)) Mbps" } else { "N/A" }
                        $status = if ($adapter.NetEnabled) { "Conectado" } else { "Desconectado" }
                        $statusClass = if ($adapter.NetEnabled) { "green" } else { "red" }
                        
                        "<tr>
                            <td>$($adapter.Name)</td>
                            <td>$ipAddress</td>
                            <td>$($adapter.MACAddress)</td>
                            <td>$speed</td>
                            <td><span class='indicator $statusClass'></span>$status</td>
                        </tr>"
                    }
                    $netRows -join ""
                )
            </table>
        </div>
        
        <div class="section">
            <h2>Salud del Sistema</h2>
            <table>
                <tr>
                    <td>Salud del procesador</td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress-bar-fill" style="width: $($cpuHealth)%; background-color: $(if($cpuHealth -gt 75){"#2ecc71"}elseif($cpuHealth -gt 50){"#f39c12"}else{"#e74c3c"});"></div>
                            <div class="progress-bar-text">$($cpuHealth)%</div>
                        </div>
                    </td>
                </tr>
                <tr>
                    <td>Salud de la memoria</td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress-bar-fill" style="width: $($ramHealth)%; background-color: $(if($ramHealth -gt 75){"#2ecc71"}elseif($ramHealth -gt 50){"#f39c12"}else{"#e74c3c"});"></div>
                            <div class="progress-bar-text">$($ramHealth)%</div>
                        </div>
                    </td>
                </tr>
                <tr>
                    <td>Salud del almacenamiento</td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress-bar-fill" style="width: $($diskHealth)%; background-color: $(if($diskHealth -gt 75){"#2ecc71"}elseif($diskHealth -gt 50){"#f39c12"}else{"#e74c3c"});"></div>
                            <div class="progress-bar-text">$($diskHealth)%</div>
                        </div>
                    </td>
                </tr>
                <tr>
                    <td>Estado de actualizaciones</td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress-bar-fill" style="width: $($updateHealth)%; background-color: $(if($updateHealth -gt 75){"#2ecc71"}elseif($updateHealth -gt 50){"#f39c12"}else{"#e74c3c"});"></div>
                            <div class="progress-bar-text">$($updateHealth)%</div>
                        </div>
                    </td>
                </tr>
                <tr>
                    <td><strong>SALUD GENERAL</strong></td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress-bar-fill" style="width: $($overallHealth)%; background-color: $(if($overallHealth -gt 75){"#2ecc71"}elseif($overallHealth -gt 50){"#f39c12"}else{"#e74c3c"});"></div>
                            <div class="progress-bar-text">$($overallHealth)%</div>
                        </div>
                    </td>
                </tr>
            </table>
        </div>
        
        <div class="footer">
            <p>Generado por SystemInfoPlus v2.0 | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
    </div>
</body>
</html>
"@

    # Guardar el reporte HTML
    try {
        # Asegurarse que la carpeta existe
        if (-not (Test-Path $exportFolder)) {
            New-Item -ItemType Directory -Path $exportFolder -Force | Out-Null
        }
        
        # Guardar el reporte
        $htmlReport | Out-File -FilePath $exportFile -Encoding UTF8 -Force
        
        Write-Host " Informe HTML guardado exitosamente en:" -ForegroundColor "Green"
        Write-Host " $exportFile" -ForegroundColor "White"
        
        # Abrir el reporte automáticamente
        Write-Host " Abriendo informe..." -ForegroundColor "DarkGray"
        Start-Process $exportFile
    } catch {
        Write-Host " Error al guardar el informe HTML: $_" -ForegroundColor "Red"
        Write-Host " Intentando guardar en carpeta alternativa..." -ForegroundColor "Yellow"
        
        # Intentar guardar en escritorio si falló la primera opción
        $alternateFolder = "$env:USERPROFILE\Desktop"
        $alternateFile = "$alternateFolder\SystemInfoPlus_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        
        try {
            $htmlReport | Out-File -FilePath $alternateFile -Encoding UTF8 -Force
            Write-Host " Informe HTML guardado en ubicación alternativa:" -ForegroundColor "Green"
            Write-Host " $alternateFile" -ForegroundColor "White"
            Start-Process $alternateFile
        } catch {
            Write-Host " Error al guardar el informe. Por favor verifique los permisos de escritura." -ForegroundColor "Red"
        }
    }
} else {
    Write-Host " No se generará el informe HTML." -ForegroundColor "Yellow"
}

Write-Host "`n Gracias por utilizar SystemInfoPlus!" -ForegroundColor "Cyan"
Write-Host " Presiona cualquier tecla para salir..." -ForegroundColor "DarkGray"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
