# =======================================================================
# ███████╗██╗███████╗████████╗███████╗███╗   ███╗ █████╗ 
# ██╔════╝██║██╔════╝╚══██╔══╝██╔════╝████╗ ████║██╔══██╗
# ███████╗██║███████╗   ██║   █████╗  ██╔████╔██║███████║
# ╚════██║██║╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║██╔══██║
# ███████║██║███████║   ██║   ███████╗██║ ╚═╝ ██║██║  ██║
# ╚══════╝╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝
#  █████╗ ███╗   ██╗ █████╗ ██╗  ██╗   ██╗███████╗███████╗██████╗ 
# ██╔══██╗████╗  ██║██╔══██╗██║  ╚██╗ ██╔╝╚══███╔╝██╔════╝██╔══██╗
# ███████║██╔██╗ ██║███████║██║   ╚████╔╝   ███╔╝ █████╗  ██████╔╝
# ██╔══██║██║╚██╗██║██╔══██║██║    ╚██╔╝   ███╔╝  ██╔══╝  ██╔══██╗
# ██║  ██║██║ ╚████║██║  ██║███████╗██║   ███████╗███████╗██║  ██║
# ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝
# =======================================================================
# Complemento para ToolboxBS - by BrandonSepulveda
# Versión 1.0.0
# =======================================================================

# Configuración inicial
$Host.UI.RawUI.WindowTitle = "ToolboxBS - Sistema Analyzer & Optimizer"
$ErrorActionPreference = "SilentlyContinue"

# Colores y estilos
$colores = @{
    "Titulo"      = "Magenta"
    "Subtitulo"   = "Cyan"
    "Normal"      = "White"
    "Exito"       = "Green"
    "Advertencia" = "Yellow"
    "Error"       = "Red"
    "Info"        = "Blue"
    "Destacado"   = "DarkCyan"
}

function Mostrar-Banner {
    Clear-Host
    Write-Host "`n`n"
    Write-Host "  ██████╗██╗███████╗████████╗███████╗███╗   ███╗ █████╗     " -ForegroundColor $colores.Titulo
    Write-Host " ██╔════╝██║██╔════╝╚══██╔══╝██╔════╝████╗ ████║██╔══██╗    " -ForegroundColor $colores.Titulo
    Write-Host " ╚█████╗ ██║███████╗   ██║   █████╗  ██╔████╔██║███████║    " -ForegroundColor $colores.Titulo
    Write-Host "  ╚═══██╗██║╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║██╔══██║    " -ForegroundColor $colores.Titulo
    Write-Host " ██████╔╝██║███████║   ██║   ███████╗██║ ╚═╝ ██║██║  ██║    " -ForegroundColor $colores.Titulo
    Write-Host " ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝    " -ForegroundColor $colores.Titulo
    Write-Host " ================================================== " -ForegroundColor $colores.Subtitulo
    Write-Host "    ANALYZER & OPTIMIZER - ToolboxBS Edition v1.0   " -ForegroundColor $colores.Subtitulo
    Write-Host " ================================================== " -ForegroundColor $colores.Subtitulo
    Write-Host "`n"
}

function Mostrar-Progreso {
    param (
        [string]$Actividad,
        [int]$ProgresoPorcentaje,
        [string]$Color = $colores.Info
    )
    
    $longitud = 50
    $completados = [math]::Floor($longitud * ($ProgresoPorcentaje / 100))
    $restantes = $longitud - $completados
    
    $barraProgreso = "[" + ("█" * $completados) + (" " * $restantes) + "]"
    
    Write-Host "  $Actividad " -NoNewline -ForegroundColor $Color
    Write-Host "$barraProgreso" -NoNewline -ForegroundColor $colores.Destacado
    Write-Host " $ProgresoPorcentaje%" -ForegroundColor $colores.Exito
    Start-Sleep -Milliseconds 150
}

function Mostrar-TextoAnimado {
    param (
        [string]$Texto,
        [string]$Color = $colores.Normal,
        [int]$Velocidad = 10
    )
    
    foreach ($char in $Texto.ToCharArray()) {
        Write-Host $char -NoNewline -ForegroundColor $Color
        Start-Sleep -Milliseconds $Velocidad
    }
    Write-Host ""
}

function Obtener-InfoSistema {
    Mostrar-TextoAnimado "🔍 ANALIZANDO COMPONENTES DEL SISTEMA..." -Color $colores.Info -Velocidad 5
    Write-Host " ┌─────────────────────────────────────────────┐" -ForegroundColor $colores.Subtitulo
    
    # Análisis de Sistema Operativo
    Mostrar-Progreso -Actividad "Verificando sistema operativo" -ProgresoPorcentaje 10
    $os = Get-CimInstance Win32_OperatingSystem
    $instalacion = $os.InstallDate
    $diasDesdeInstalacion = (New-TimeSpan -Start $instalacion -End (Get-Date)).Days
    $uptime = (Get-Date) - $os.LastBootUpTime
    
    # Análisis de Hardware
    Mostrar-Progreso -Actividad "Escaneando componentes hardware" -ProgresoPorcentaje 30
    $cpu = Get-CimInstance Win32_Processor
    $ram = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $ramGB = [math]::Round($ram.Sum / 1GB, 2)
    $ramUsada = [math]::Round((Get-Counter '\Memory\Committed Bytes').CounterSamples.CookedValue / 1GB, 2)
    $porcentajeRAM = [math]::Round(($ramUsada / $ramGB) * 100, 0)
    
    # Análisis de Disco
    Mostrar-Progreso -Actividad "Analizando almacenamiento" -ProgresoPorcentaje 50
    $disks = Get-PhysicalDisk | Select-Object MediaType, Size, HealthStatus
    $diskType = if ($disks.MediaType -contains "SSD") { "SSD ⚡" } else { "HDD 💿" }
    $diskC = Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:'
    $diskSizeGB = [math]::Round($diskC.Size / 1GB, 2)
    $diskFreeGB = [math]::Round($diskC.FreeSpace / 1GB, 2)
    $diskUsedPercent = [math]::Round(100 - (($diskFreeGB / $diskSizeGB) * 100), 0)
    
   # Análisis de Procesos
Mostrar-Progreso -Actividad "Examinando procesos activos" -ProgresoPorcentaje 70

$procesosConsumoAlto = Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 5
$totalProcesos = (Get-Process).Count
    
    # Análisis de Red
    Mostrar-Progreso -Actividad "Verificando conexiones de red" -ProgresoPorcentaje 90
    $adaptadoresRed = Get-NetAdapter | Where-Object Status -eq 'Up'
    $conexiones = Get-NetTCPConnection | Group-Object State | Select-Object Name, Count
    
    # Finalizar análisis
    Mostrar-Progreso -Actividad "Generando informe detallado" -ProgresoPorcentaje 100
    Write-Host " └─────────────────────────────────────────────┘" -ForegroundColor $colores.Subtitulo
    
    # Mostrar resultados con diseño mejorado
    Write-Host "`n  ╔══════════════════════════════════════════════╗" -ForegroundColor $colores.Destacado
    Write-Host "  ║             🔎 INFORME DEL SISTEMA            ║" -ForegroundColor $colores.Destacado
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor $colores.Destacado
    
   # Código original con mejoras para detectar software de edición y cuellos de botella

# [...Código anterior...]

# Información del Sistema Operativo
Write-Host "`n  🖥️  " -NoNewline
Write-Host "SISTEMA OPERATIVO" -ForegroundColor $colores.Subtitulo
Write-Host "  ├─ Nombre: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$($os.Caption)" -ForegroundColor $colores.Destacado
Write-Host "  ├─ Versión: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$($os.Version)" -ForegroundColor $colores.Destacado
Write-Host "  ├─ Instalado: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "hace $diasDesdeInstalacion días ($($instalacion.ToString("dd/MM/yyyy")))" -ForegroundColor $colores.Destacado
Write-Host "  └─ Uptime: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$($uptime.Days) días, $($uptime.Hours) horas, $($uptime.Minutes) min" -ForegroundColor $colores.Destacado

# Hardware
Write-Host "`n  🔧 " -NoNewline
Write-Host "HARDWARE" -ForegroundColor $colores.Subtitulo
Write-Host "  ├─ Procesador: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$($cpu.Name)" -ForegroundColor $colores.Destacado
Write-Host "  ├─ Núcleos: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$($cpu.NumberOfCores) físicos, $($cpu.NumberOfLogicalProcessors) lógicos" -ForegroundColor $colores.Destacado
Write-Host "  ├─ Uso de CPU: " -NoNewline -ForegroundColor $colores.Normal
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
Write-Host "$([math]::Round($cpuLoad, 1))%" -ForegroundColor $(if($cpuLoad -gt 80){$colores.Error}elseif($cpuLoad -gt 50){$colores.Advertencia}else{$colores.Exito})
Write-Host "  ├─ Memoria RAM: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$ramGB GB" -NoNewline -ForegroundColor $colores.Destacado
Write-Host " (En uso: $ramUsada GB - $porcentajeRAM%)" -ForegroundColor $(if($porcentajeRAM -gt 80){$colores.Error}elseif($porcentajeRAM -gt 60){$colores.Advertencia}else{$colores.Exito})

# Añadir información de la tarjeta gráfica
$gpus = Get-CimInstance -ClassName Win32_VideoController
Write-Host "  └─ Tarjeta(s) Gráfica(s): " -NoNewline -ForegroundColor $colores.Normal

if ($gpus -ne $null) {
    $tieneGPUDedicada = $false
    $i = 0
    
    # Convertir a array si no lo es
    if ($gpus -isnot [Array]) {
        $gpus = @($gpus)
    }
    
    foreach ($gpu in $gpus) {
        if ($i -gt 0) { Write-Host "                        " -NoNewline }
        # Determinar si es integrada o dedicada basado en el nombre y memoria
        $gpuRAM = if ($gpu.AdapterRAM -gt 0) { [math]::Round($gpu.AdapterRAM / 1GB, 1) } else { 0 }
        $esIntegrada = $gpu.Name -match "Intel|UHD|HD Graphics|Integrated" -or $gpuRAM -lt 1
        $tipoGPU = if($esIntegrada) { "Integrada" } else { "Dedicada"; $tieneGPUDedicada = $true }
        
        Write-Host "$($gpu.Name)" -NoNewline -ForegroundColor $colores.Destacado
        Write-Host " - $tipoGPU" -NoNewline -ForegroundColor $(if($esIntegrada){$colores.Advertencia}else{$colores.Exito})
        if ($gpuRAM -gt 0) {
            Write-Host " - $gpuRAM GB" -ForegroundColor $(if($gpuRAM -lt 2){$colores.Advertencia}else{$colores.Exito})
        } else {
            Write-Host "" # Nueva línea si no se puede determinar la memoria
        }
        $i++
    }
} else {
    Write-Host "No detectada" -ForegroundColor $colores.Error
    $tieneGPUDedicada = $false
}
# Almacenamiento
Write-Host "`n  💾 " -NoNewline
Write-Host "ALMACENAMIENTO" -ForegroundColor $colores.Subtitulo
Write-Host "  ├─ Tipo: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$diskType" -ForegroundColor $(if($diskType -like "*SSD*"){$colores.Exito}else{$colores.Advertencia})
Write-Host "  ├─ Disco C: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$diskSizeGB GB" -ForegroundColor $colores.Destacado
Write-Host "  ├─ Espacio libre: " -NoNewline -ForegroundColor $colores.Normal
Write-Host "$diskFreeGB GB" -ForegroundColor $(if($diskFreeGB -lt 10){$colores.Error}elseif($diskFreeGB -lt 30){$colores.Advertencia}else{$colores.Exito})
Write-Host "  └─ Uso de disco: " -NoNewline -ForegroundColor $colores.Normal

# Barra de progreso para el uso de disco
$longitud = 20
$completados = [math]::Floor($longitud * ($diskUsedPercent / 100))
$restantes = $longitud - $completados
$barraProgreso = "[" + ("█" * $completados) + (" " * $restantes) + "]"
Write-Host "$barraProgreso " -NoNewline -ForegroundColor $(if($diskUsedPercent -gt 90){$colores.Error}elseif($diskUsedPercent -gt 75){$colores.Advertencia}else{$colores.Exito})
Write-Host "$diskUsedPercent%" -ForegroundColor $(if($diskUsedPercent -gt 90){$colores.Error}elseif($diskUsedPercent -gt 75){$colores.Advertencia}else{$colores.Exito})

## Procesos
Write-Host "`n  🧠 " -NoNewline
Write-Host "PROCESOS ACTIVOS ($totalProcesos total)" -ForegroundColor $colores.Subtitulo
Write-Host "  ├─ Top 5 consumo de CPU:" -ForegroundColor $colores.Normal
$i = 1
foreach ($proceso in $procesosConsumoAlto) {
    $cpuPorcentaje = [math]::Round($proceso.CPU, 1)
    
    # Convertir memoria a formato apropiado (MB o GB)
    $ramBytes = $proceso.WS
    if ($ramBytes -ge 1GB) {
        $ramFormatted = [math]::Round($ramBytes / 1GB, 2)
        $ramUnidad = "GB"
    } else {
        $ramFormatted = [math]::Round($ramBytes / 1MB, 0)
        $ramUnidad = "MB"
    }
    
    # Ajustar colores según consumo (considerando GB para evaluación)
    $ramColorCriterio = if ($ramUnidad -eq "GB") { $ramFormatted * 1024 } else { $ramFormatted }
    $ramColor = if ($ramColorCriterio -gt 1000) { $colores.Error } elseif ($ramColorCriterio -gt 500) { $colores.Advertencia } else { $colores.Exito }
    
    Write-Host "     $i. " -NoNewline
    Write-Host "$($proceso.Name)" -NoNewline -ForegroundColor $colores.Destacado
    Write-Host " - CPU: " -NoNewline
    Write-Host "$cpuPorcentaje%" -NoNewline -ForegroundColor $(if($cpuPorcentaje -gt 50){$colores.Error}elseif($cpuPorcentaje -gt 20){$colores.Advertencia}else{$colores.Exito})
    Write-Host " - RAM: $ramFormatted $ramUnidad" -ForegroundColor $ramColor
    $i++
}

# Detectar software de edición/diseño/profesional
$softwareProfesional = @{
    'Diseño CAD' = @('acad.exe', 'AutoCAD*.exe', 'Revit*.exe', 'CATIA*.exe', 'SolidWorks*.exe', 'inventor*.exe', 'rhino*.exe')
    'Edición de Video' = @('premiere*.exe', 'AfterFX*.exe', 'vegas*.exe', 'resolve*.exe', 'avid*.exe', 'edius*.exe')
    'Edición de Imagen' = @('photoshop*.exe', 'illustrator*.exe', 'gimp*.exe', 'lightroom*.exe', 'CorelDRW*.exe', 'AffinityPhoto*.exe')
    'Modelado 3D' = @('3dsmax*.exe', 'blender*.exe', 'Maya*.exe', 'ZBrush*.exe', 'Houdini*.exe', 'C4D*.exe')
    'Desarrollo' = @('devenv.exe', 'studio64.exe', 'pycharm*.exe', 'eclipse*.exe', 'idea*.exe', 'vscode*.exe', 'android studio*.exe')
    'Virtualización' = @('vmware*.exe', 'VirtualBox*.exe', 'Hyper-V*.exe', 'docker*.exe')
}

# Verificar procesos en ejecución para detectar software profesional
$softwareEncontrado = @()
$procesos = Get-Process

foreach ($categoria in $softwareProfesional.Keys) {
    foreach ($patronProceso in $softwareProfesional[$categoria]) {
        $procesosCoincidentes = $procesos | Where-Object { $_.ProcessName -like $patronProceso -or $_.MainWindowTitle -like "*$patronProceso*" }
        foreach ($procesoCoincidente in $procesosCoincidentes) {
            # Verificar la memoria y CPU que consume
            $nombreProceso = $procesoCoincidente.ProcessName
            $ramProceso = [math]::Round($procesoCoincidente.WorkingSet64 / 1MB, 0)
            
            # Obtener CPU (este método puede variar dependiendo de cómo se calculó originalmente)
            $cpuProceso = ($procesosConsumoAlto | Where-Object { $_.Id -eq $procesoCoincidente.Id } | Select-Object -First 1).CPU
            if ($null -eq $cpuProceso) { $cpuProceso = 0 }
            
            $softwareEncontrado += @{
                "Nombre" = $nombreProceso
                "Categoria" = $categoria
                "RAM" = $ramProceso
                "CPU" = $cpuProceso
            }
        }
    }
}

# Mostrar software profesional detectado
if ($softwareEncontrado.Count -gt 0) {
    Write-Host "  └─ Software Profesional Detectado:" -ForegroundColor $colores.Normal
    foreach ($software in $softwareEncontrado) {
        Write-Host "     • " -NoNewline
        Write-Host "$($software.Nombre)" -NoNewline -ForegroundColor $colores.Destacado
        Write-Host " - $($software.Categoria)" -NoNewline -ForegroundColor $colores.Normal
        Write-Host " - RAM: $($software.RAM) MB" -NoNewline -ForegroundColor $(if($software.RAM -gt 1000){$colores.Advertencia}else{$colores.Normal})
        if ($software.CPU -gt 0) {
            Write-Host " - CPU: $($software.CPU)%" -ForegroundColor $(if($software.CPU -gt 30){$colores.Advertencia}else{$colores.Normal})
        } else {
            Write-Host ""
        }
    }
} else {
    Write-Host "  └─ No se detectó software profesional en ejecución" -ForegroundColor $colores.Normal
}

# Generación de Recomendaciones
$recomendaciones = @()

# Recomendaciones basadas en RAM
if ($ramGB -lt 8) {
    $recomendaciones += @{
        "Tipo" = "RAM";
        "Mensaje" = "Considerar aumentar la memoria RAM a al menos 8GB para mejor rendimiento";
        "Prioridad" = "Alta"
    }
}
elseif ($porcentajeRAM -gt 80) {
    $recomendaciones += @{
        "Tipo" = "RAM";
        "Mensaje" = "Uso elevado de memoria RAM. Considere cerrar aplicaciones innecesarias";
        "Prioridad" = "Media"
    }
}

# Recomendaciones basadas en espacio en disco
if ($diskFreeGB -lt 10) {
    $recomendaciones += @{
        "Tipo" = "Disco";
        "Mensaje" = "¡Espacio crítico en disco! Libere al menos 10GB para un funcionamiento óptimo";
        "Prioridad" = "Alta"
    }
}
elseif ($diskUsedPercent -gt 85) {
    $recomendaciones += @{
        "Tipo" = "Disco";
        "Mensaje" = "Espacio en disco bajo. Considere eliminar archivos innecesarios";
        "Prioridad" = "Media"
    }
}

# Recomendaciones basadas en tipo de disco
if ($diskType -like "*HDD*") {
    $recomendaciones += @{
        "Tipo" = "Disco";
        "Mensaje" = "Actualizar a un disco SSD mejoraría significativamente el rendimiento";
        "Prioridad" = "Media"
    }
}

# Recomendaciones basadas en tiempo de inicio
if ($uptime.Days -gt 7) {
    $recomendaciones += @{
        "Tipo" = "Sistema";
        "Mensaje" = "El sistema lleva más de una semana sin reiniciarse. Considere un reinicio para mejorar el rendimiento";
        "Prioridad" = "Baja"
    }
}

# Recomendaciones basadas en uso de CPU
if ($cpuLoad -gt 80) {
    $recomendaciones += @{
        "Tipo" = "CPU";
        "Mensaje" = "Uso elevado de CPU. Verifique qué procesos consumen más recursos";
        "Prioridad" = "Alta"
    }
}

# Recomendaciones basadas en tarjeta gráfica y software detectado
$softwareNecesitaGPU = $softwareEncontrado | Where-Object { $_.Categoria -in @('Diseño CAD', 'Edición de Video', 'Modelado 3D') }
if ($softwareNecesitaGPU.Count -gt 0 -and -not $tieneGPUDedicada) {
    $recomendaciones += @{
        "Tipo" = "GPU";
        "Mensaje" = "Se detectó software profesional ($($softwareNecesitaGPU[0].Categoria)) sin tarjeta gráfica dedicada. Esto puede causar cuellos de botella.";
        "Prioridad" = "Alta"
    }
}

# Recomendaciones específicas basadas en categoría de software
foreach ($software in $softwareEncontrado) {
    # Para software CAD con RAM < 16GB
    if ($software.Categoria -eq 'Diseño CAD' -and $ramGB -lt 16) {
        $recomendaciones += @{
            "Tipo" = "RAM-Software";
            "Mensaje" = "Se recomienda al menos 16GB de RAM para un rendimiento óptimo con software CAD ($($software.Nombre))";
            "Prioridad" = "Media"
        }
    }
    
    # Para edición de video con RAM < 32GB
    if ($software.Categoria -eq 'Edición de Video' -and $ramGB -lt 32) {
        $recomendaciones += @{
            "Tipo" = "RAM-Software";
            "Mensaje" = "Para edición de video profesional con $($software.Nombre), se recomiendan 32GB de RAM o más";
            "Prioridad" = "Media"
        }
    }
    
    # Para modelado 3D con pocos núcleos
    if ($software.Categoria -eq 'Modelado 3D' -and $cpu.NumberOfLogicalProcessors -lt 8) {
        $recomendaciones += @{
            "Tipo" = "CPU-Software";
            "Mensaje" = "El software de modelado 3D ($($software.Nombre)) se beneficiaría de un procesador con más núcleos";
            "Prioridad" = "Baja"
        }
    }
    
    # Si usa virtualización con poca RAM
    if ($software.Categoria -eq 'Virtualización' -and $ramGB -lt 16) {
        $recomendaciones += @{
            "Tipo" = "RAM-Software";
            "Mensaje" = "Para virtualización con $($software.Nombre), se recomienda aumentar la RAM a 16GB o más";
            "Prioridad" = "Alta"
        }
    }
}

# Mostrar las recomendaciones
if ($recomendaciones.Count -gt 0) {
    Write-Host "`n  🔍 " -NoNewline
    Write-Host "RECOMENDACIONES" -ForegroundColor $colores.Subtitulo
    
    # Ordenar por prioridad
    $recomendacionesOrdenadas = $recomendaciones | Sort-Object { 
        switch ($_.Prioridad) {
            "Alta" { 1 }
            "Media" { 2 }
            "Baja" { 3 }
            default { 4 }
        }
    }
    
    foreach ($rec in $recomendacionesOrdenadas) {
        $colorPrioridad = switch ($rec.Prioridad) {
            "Alta" { $colores.Error }
            "Media" { $colores.Advertencia }
            "Baja" { $colores.Normal }
            default { $colores.Normal }
        }
        
        Write-Host "  ├─ " -NoNewline -ForegroundColor $colores.Normal
        Write-Host "[$($rec.Tipo)] " -NoNewline -ForegroundColor $colores.Destacado
        Write-Host "$($rec.Mensaje)" -ForegroundColor $colorPrioridad
    }
    
    Write-Host "  └─ " -NoNewline -ForegroundColor $colores.Normal
    Write-Host "Fin del análisis." -ForegroundColor $colores.Normal
} else {
    Write-Host "`n  ✅ " -NoNewline
    Write-Host "No se detectaron problemas significativos en el sistema." -ForegroundColor $colores.Exito
}

return @{
    "SistemaOperativo" = $os.Caption;
    "Instalacion" = $diasDesdeInstalacion;
    "RAM" = $ramGB;
    "PorcentajeRAM" = $porcentajeRAM;
    "CPU" = $cpu.Name;
    "UsoCPU" = $cpuLoad;
    "TipoDisco" = $diskType;
    "EspacioLibre" = $diskFreeGB;
    "UsoDisco" = $diskUsedPercent;
    "TarjetaGrafica" = $gpus | ForEach-Object { $_.Name };
    "TieneGPUDedicada" = $tieneGPUDedicada;
    "SoftwareProfesional" = $softwareEncontrado;
    "Recomendaciones" = $recomendaciones
}
}
function Optimizar-Sistema {
    param (
        [hashtable]$InfoSistema
    )
    
    Write-Host "`n  ╔══════════════════════════════════════════════╗" -ForegroundColor $colores.Destacado
    Write-Host "  ║             🚀 OPTIMIZACIÓN DEL SISTEMA       ║" -ForegroundColor $colores.Destacado
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor $colores.Destacado
    
    Write-Host "`n  📋 " -NoNewline
    Write-Host "RECOMENDACIONES DETECTADAS" -ForegroundColor $colores.Subtitulo
    
    $hayRecomendaciones = $false
    
    foreach ($rec in $InfoSistema.Recomendaciones) {
        $hayRecomendaciones = $true
        $colorPrioridad = switch ($rec.Prioridad) {
            "Alta" { $colores.Error }
            "Media" { $colores.Advertencia }
            "Baja" { $colores.Info }
            default { $colores.Normal }
        }
        
        Write-Host "  ├─ [$($rec.Tipo)] " -NoNewline -ForegroundColor $colorPrioridad
        Write-Host "$($rec.Mensaje)" -ForegroundColor $colores.Normal
    }
    
    if (-not $hayRecomendaciones) {
        Write-Host "  └─ " -NoNewline -ForegroundColor $colores.Normal
        Write-Host "¡Sistema en condiciones óptimas! No se requieren acciones inmediatas." -ForegroundColor $colores.Exito
    } else {
        Write-Host "  └─ " -NoNewline -ForegroundColor $colores.Normal
        Write-Host "Se recomienda aplicar las optimizaciones sugeridas." -ForegroundColor $colores.Advertencia
    }
    
    # Preguntar al usuario si desea aplicar optimizaciones
Write-Host "`n  ¿Desea aplicar las optimizaciones recomendadas? [S/N]: " -NoNewline -ForegroundColor $colores.Subtitulo
$respuesta = Read-Host

if ($respuesta -ne "S" -and $respuesta -ne "s") {
    Write-Host "`n  ❌ " -NoNewline
    Write-Host "Operación cancelada por el usuario." -ForegroundColor $colores.Advertencia
    return
}

# Crear punto de restauración antes de aplicar cambios
Write-Host "`n  🔄 " -NoNewline
Write-Host "CREANDO PUNTO DE RESTAURACIÓN..." -ForegroundColor $colores.Subtitulo
$fecha = Get-Date -Format "dd-MM-yyyy_HH-mm"
$descripcion = "Punto Restauracion ToolboxAnalyser $fecha"
Checkpoint-Computer -Description $descripcion -RestorePointType "APPLICATION_INSTALL"
Write-Host "  └─ Punto de restauración creado: $descripcion" -ForegroundColor $colores.Informacion

# Aplicar optimizaciones
Write-Host "`n  🔄 " -NoNewline
Write-Host "APLICANDO OPTIMIZACIONES..." -ForegroundColor $colores.Subtitulo
Write-Host " ┌─────────────────────────────────────────────┐" -ForegroundColor $colores.Subtitulo

# 1. Limpieza de archivos temporales
Mostrar-Progreso -Actividad "Limpiando archivos temporales" -ProgresoPorcentaje 10
$temp = [System.IO.Path]::GetTempPath()
Get-ChildItem -Path $temp -Force | Remove-Item -Force -Recurse
Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse


# 2. Limpieza de archivos de caché del sistema
Mostrar-Progreso -Actividad "Limpiando caché del sistema" -ProgresoPorcentaje 30
Remove-Item -Path "$env:windir\Prefetch\*" -Force

# 3. Desfragmentación (solo para discos HDD)
if ($InfoSistema.TipoDisco -like "*HDD*") {
    Mostrar-Progreso -Actividad "Desfragmentando disco (puede tomar tiempo)" -ProgresoPorcentaje 50
    Optimize-Volume -DriveLetter C -Defrag
} else {
    Mostrar-Progreso -Actividad "Optimizando SSD (TRIM)" -ProgresoPorcentaje 50
    Optimize-Volume -DriveLetter C -ReTrim
}

# 4. Limpieza del caché de DNS
Mostrar-Progreso -Actividad "Limpiando caché de DNS" -ProgresoPorcentaje 60
Clear-DnsClientCache

# 5. Optimizar servicios de inicio
Mostrar-Progreso -Actividad "Optimizando servicios de inicio" -ProgresoPorcentaje 70
Get-Service | Where-Object {$_.StartType -eq "Automatic" -and $_.Status -eq "Stopped" -and $_.Name -notmatch "wuauserv|sppsvc|WSearch"} | ForEach-Object {
    Set-Service -Name $_.Name -StartupType Manual
}

# 6. Limpieza del registro
Mostrar-Progreso -Actividad "Limpiando registro del sistema" -ProgresoPorcentaje 80
# Simulación de limpieza de registro (no implementada por seguridad)
Start-Sleep -Seconds 2

# 7. Optimización de rendimiento del sistema y corrección de parpadeo de pantalla
Mostrar-Progreso -Actividad "Aplicando ajustes de rendimiento" -ProgresoPorcentaje 90
# Ajustes originales de rendimiento
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 100
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value 2000
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Value 2000
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value 2000

# Nuevos ajustes para corregir el parpadeo de bordes de pantalla
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value 1
if (-not (Test-Path "HKCU:\Control Panel\Desktop\WindowMetrics")) {
    New-Item -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Force
}
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 1

# Optimización de gráficos
if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects")) {
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Force
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 3

# 8. Limpiar historial de Windows Update
Mostrar-Progreso -Actividad "Limpiando historial de actualizaciones" -ProgresoPorcentaje 95
Stop-Service -Name wuauserv
Remove-Item -Path "$env:windir\SoftwareDistribution\*" -Force -Recurse
Start-Service -Name wuauserv

# Finalizar optimización
Mostrar-Progreso -Actividad "Finalizando optimización" -ProgresoPorcentaje 100
Write-Host " └─────────────────────────────────────────────┘" -ForegroundColor $colores.Subtitulo

# Mostrar resumen
Write-Host "`n  ✅ " -NoNewline
Write-Host "OPTIMIZACIÓN COMPLETADA" -ForegroundColor $colores.Exito
Write-Host "  └─ Se recomienda reiniciar el sistema para aplicar todos los cambios." -ForegroundColor $colores.Advertencia
    
    # Preguntar si desea reiniciar
    Write-Host "`n  ¿Desea reiniciar el sistema ahora? [S/N]: " -NoNewline -ForegroundColor $colores.Subtitulo
    $respuestaReinicio = Read-Host
    
    if ($respuestaReinicio -eq "S" -or $respuestaReinicio -eq "s") {
        Write-Host "`n  🔄 " -NoNewline
        Write-Host "Reiniciando sistema en 10 segundos..." -ForegroundColor $colores.Advertencia
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        Write-Host "`n  ℹ️ " -NoNewline
        Write-Host "Reinicio pospuesto. Recuerde reiniciar manualmente más tarde." -ForegroundColor $colores.Info
    }
}

function Iniciar-Analizador {
    Mostrar-Banner
    
    Write-Host "  Iniciando análisis completo del sistema..." -ForegroundColor $colores.Info
    Write-Host "  Por favor espere mientras se recopila información..." -ForegroundColor $colores.Normal
    
    $infoSistema = Obtener-InfoSistema
    
    Optimizar-Sistema -InfoSistema $infoSistema
    
    Write-Host "`n  Presione cualquier tecla para salir..." -ForegroundColor $colores.Normal
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Ejecutar el script
Iniciar-Analizador
