# Cargar el ensamblado necesario para Windows Forms (GUI)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing # Asegurarse también de cargar System.Drawing para Point, Size, etc.

# Función para obtener información de eventos críticos y archivos de volcado
function Get-BSODInfo {
    param (
        [int]$Days = 90 # Periodo a analizar en días
    )

    $endDate = Get-Date
    $startDate = $endDate.AddDays(-$Days)

    $events = @()
    $dumpFiles = @()
    $problemDrivers = @()

    # --- Recolectar Eventos Críticos ---
    # Buscar eventos de reinicio inesperado (Event ID 41, Fuente Kernel-Power)
    # Buscar eventos de BugCheck (Event ID 1001, Fuente BugCheck) - Estos indican una BSOD
    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            StartTime = $startDate
            EndTime = $endDate
            ID = 41, 1001
            Level = 1, 2 # Crítico (1), Error (2)
        } -ErrorAction SilentlyContinue | Sort-Object TimeCreated -Descending

        # Intentar extraer nombres de drivers (.sys) de los mensajes de evento 1001
        foreach ($event in $events | Where-Object {$_.Id -eq 1001}) {
             $driverMatches = [regex]::Matches($event.Message, '(\w+\.sys)')
             foreach ($match in $driverMatches) {
                 $driverName = $match.Groups[1].Value
                 if ($problemDrivers -notcontains $driverName) {
                     $problemDrivers += $driverName
                 }
             }
        }

    } catch {
        Write-Warning "No se pudieron obtener los eventos del sistema. Asegúrese de ejecutar con permisos de Administrador."
        Write-Warning "Error: $($_.Exception.Message)"
    }

    # --- Recolectar Archivos de Volcado de Memoria (.dmp) ---
    $minidumpPath = "$env:windir\Minidump"
    if (Test-Path $minidumpPath) {
        try {
            $dumpFiles = Get-ChildItem $minidumpPath -Filter *.dmp -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -ge $startDate} | Sort-Object LastWriteTime -Descending
        } catch {
            Write-Warning "No se pudieron obtener los archivos de volcado en $minidumpPath. Asegúrese de tener permisos de acceso."
             Write-Warning "Error: $($_.Exception.Message)"
        }
    } else {
        Write-Host "La carpeta de minivolcados '$minidumpPath' no existe en este sistema."
    }


    # Retornar la información como un objeto personalizado
    [PSCustomObject]@{
        Events = $events
        DumpFiles = $dumpFiles
        ProblemDrivers = $problemDrivers | Sort-Object # Ordenar los drivers
    }
}


# Función para obtener información básica de un controlador
function Get-DriverInfo {
    param (
        [string]$DriverName
    )

    # Diccionario de información común para drivers problemáticos
    $driverSolutions = @{
        "ntoskrnl.exe" = "Kernel de Windows. RELACIONADO A: problemas del sistema, memoria, controladores genéricos o actualizaciones recientes. SOLUCIÓN: Reinstale actualizaciones recientes, ejecute sfc/DISM, verifique RAM y controladores."
        "hal.dll" = "Capa de abstracción de hardware. RELACIONADO A: incompatibilidad de hardware, configuración de BIOS (modo AHCI/IDE) o BIOS desactualizada. SOLUCIÓN: Actualice la BIOS y verifique configuración SATA."
        "ataport.sys" = "Controlador de puertos ATA/SATA. RELACIONADO A: problemas con discos duros o SSD, cableado SATA o controlador AHCI. SOLUCIÓN: Compruebe conexiones físicas, actualice controlador AHCI/SATA (Intel RST, AMD equivalent) y ejecute diagnósticos de disco."
        "ntfs.sys" = "Sistema de archivos NTFS. RELACIONADO A: corrupción del sistema de archivos en el disco duro. SOLUCIÓN: Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "tcpip.sys" = "Controlador TCP/IP. RELACIONADO A: problemas de red, software de seguridad (firewall/antivirus) o controladores de adaptador de red defectuosos. SOLUCIÓN: Reinicie el adaptador de red, actualice sus controladores, revise software de seguridad."
        "dxgkrnl.sys" = "DirectX Graphics Kernel. RELACIONADO A: problemas con tarjeta gráfica, controladores gráficos o DirectX. SOLUCIÓN: Realice una instalación limpia de los controladores gráficos, reinstale DirectX."
        "nvlddmkm.sys" = "Controlador NVIDIA (versión del modo kernel). RELACIONADO A: sobrecalentamiento, controladores de tarjeta gráfica NVIDIA corruptos o desactualizados, o hardware gráfico defectuoso. SOLUCIÓN: Actualice o reinstale *limpiamente* controladores gráficos, verifique temperatura de la GPU, reduzca overclocking si aplica."
        "atikmpag.sys" = "Controlador AMD (versión del modo kernel). RELACIONADO A: problemas con tarjeta gráfica AMD, controladores gráficos corruptos o desactualizados. SOLUCIÓN: Actualice o reinstale *limpiamente* controladores de la tarjeta gráfica AMD."
        "igdkmd64.sys" = "Controlador Intel Graphics (64 bits). RELACIONADO A: problemas con gráficos integrados Intel o sus controladores. SOLUCIÓN: Actualice controladores gráficos Intel desde el sitio de Intel o del fabricante del PC."
        "storport.sys" = "Sistema de almacenamiento (puerto de almacenamiento). RELACIONADO A: problemas con controladores de disco, firmware de SSD/HDD o hardware de almacenamiento. SOLUCIÓN: Actualice firmware de SSD/HDD y controladores de almacenamiento (Intel RST, etc.)."
        "usbhub.sys" = "Controlador del concentrador USB. RELACIONADO A: problemas con dispositivos USB conectados, puertos USB defectuosos o sus controladores. SOLUCIÓN: Desconecte dispositivos USB no esenciales, pruebe puertos diferentes, actualice controladores del controlador USB."
        "bthport.sys" = "Controlador de puerto Bluetooth. RELACIONADO A: problemas con dispositivos Bluetooth o el adaptador Bluetooth. SOLUCIÓN: Desactive Bluetooth temporalmente, actualice controladores Bluetooth."
        "ndis.sys" = "Controlador de interfaz de red (Network Driver Interface Specification). RELACIONADO A: problemas con adaptadores de red (Wi-Fi o Ethernet) o software relacionado. SOLUCIÓN: Reinstale o actualice controladores de red."
        "iaStorA.sys" = "Controlador Intel Rapid Storage Technology (RST). RELACIONADO A: problemas con configuración RAID, SSDs o controladores SATA en sistemas Intel. SOLUCIÓN: Actualice Intel RST y controladores SATA."
        "aswsp.sys" = "Controlador Avast Self Protection. RELACIONADO A: conflicto con antivirus Avast. SOLUCIÓN: Actualice o reinstale Avast, o considere deshabilitarlo temporalmente para probar."
        "wdfilter.sys" = "Filtro de Windows Defender. RELACIONADO A: conflicto con Windows Defender. SOLUCIÓN: Asegúrese de que Windows Defender esté actualizado o deshabilite temporalmente si usa otro antivirus."
        "mfewfpk.sys" = "Controlador McAfee. RELACIONADO A: conflicto con antivirus McAfee. SOLUCIÓN: Actualice o reinstale McAfee, o considere deshabilitarlo temporalmente."
        "dx.sys" = "Controlador relacionado con DirectX. RELACIONADO A: problemas con controladores gráficos o DirectX. SOLUCIÓN: Reinstale DirectX y actualice controladores gráficos."
        "Acpi.sys" = "Driver de Interfaz de Configuración Avanzada y Energía (ACPI). RELACIONADO A: Problemas con la gestión de energía, BIOS o hardware. SOLUCIÓN: Actualice BIOS, revise configuración de energía."
        "Wdf01000.sys" = "Marco de Controladores de Windows (Kernel-Mode Driver Framework). RELACIONADO A: Problemas con varios controladores que usan KMDF. SOLUCIÓN: Asegúrese de que Windows esté actualizado, actualice todos los controladores."
        "win32kbase.sys" = "Subsistema del kernel de Windows relacionado con la interfaz gráfica. RELACIONADO A: Problemas gráficos, controladores de pantalla o software que interactúa con la GUI. SOLUCIÓN: Actualice controladores gráficos, revise software reciente que afecte la interfaz."
    }

    if ($driverSolutions.ContainsKey($DriverName)) {
        return $driverSolutions[$DriverName]
    } else {
        return "Información no disponible. Busque en línea 'qué es $DriverName'."
    }
}

# Función para obtener una solución sugerida basada en un código de error (BugCheckCode)
function Get-ErrorSolution {
    param (
        [string]$ErrorCode
    )

    # Convertir el código de error a mayúsculas y eliminar puntos finales para una comparación consistente
    $cleanedErrorCode = $ErrorCode.ToUpper().TrimEnd('.')

    # Diccionario de soluciones comunes para códigos de error BSOD
    $solutions = @{
        "0X0000001A" = "MEMORY_MANAGEMENT: Problema con la memoria RAM. Ejecute 'mdsched.exe' para diagnóstico de memoria RAM o considere ejecutar 'sfc /scannow' para reparar archivos del sistema."
        "MEMORY_MANAGEMENT" = "Problema con la memoria RAM. Ejecute 'mdsched.exe' para diagnóstico de memoria RAM o considere ejecutar 'sfc /scannow' para reparar archivos del sistema."
        "0X000000D1" = "DRIVER_IRQL_NOT_LESS_OR_EQUAL: Problema con controlador de dispositivo. Actualice sus controladores, especialmente de tarjeta gráfica y red. Ejecute 'sfc /scannow'."
        "IRQL_NOT_LESS_OR_EQUAL" = "Problema con controlador de dispositivo. Actualice sus controladores, especialmente de tarjeta gráfica y red. Ejecute 'sfc /scannow'."
        "DRIVER_IRQL_NOT_LESS_OR_EQUAL" = "Controlador intentando acceder memoria protegida. Actualice o reinstale controladores recientes."
        "0X00000050" = "PAGE_FAULT_IN_NONPAGED_AREA: Problema de memoria o controlador. Compruebe la RAM y ejecute 'chkdsk /f /r' para verificar el disco duro."
        "PAGE_FAULT_IN_NONPAGED_AREA" = "Problema de memoria o controlador. Compruebe la RAM y ejecute 'chkdsk /f /r' para verificar el disco duro."
        "0X000000EF" = "CRITICAL_PROCESS_DIED: Un proceso crítico del sistema ha fallado. Ejecute 'sfc /scannow' y 'DISM /Online /Cleanup-Image /RestoreHealth'."
        "CRITICAL_PROCESS_DIED" = "Un proceso crítico del sistema ha fallado. Ejecute 'sfc /scannow' y 'DISM /Online /Cleanup-Image /RestoreHealth'."
        "0X0000003B" = "SYSTEM_SERVICE_EXCEPTION: Error en servicio del sistema. Actualice controladores y Windows, y ejecute 'sfc /scannow'."
        "SYSTEM_SERVICE_EXCEPTION" = "Error en servicio del sistema. Actualice controladores y Windows, y ejecute 'sfc /scannow'."
        "0X0000007E" = "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED: Similar a KERNEL_MODE_EXCEPTION_NOT_HANDLED. Excepción no manejada en el kernel o controlador. Actualice controladores, verifique hardware, ejecute diagnósticos."
        "KERNEL_MODE_EXCEPTION_NOT_HANDLED" = "Excepción no manejada en el kernel. Actualice controladores, verifique hardware, y ejecute diagnósticos."
        "0X00000024" = "NTFS_FILE_SYSTEM: Problema con el sistema de archivos. Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "NTFS_FILE_SYSTEM" = "Problema con el sistema de archivos. Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "0X0000004A" = "PNP_DETECTED_FATAL_ERROR: Problema con Plug and Play, a menudo relacionado con controladores o hardware. Actualice controladores, verifique hardware."
        "0X000000F4" = "CRITICAL_OBJECT_TERMINATION: Proceso crítico del sistema terminado. Similar a CRITICAL_PROCESS_DIED. Ejecute sfc/DISM, verifique disco."
        "0X00000133" = "DPC_WATCHDOG_VIOLATION: Un DPC (Deferred Procedure Call) se ejecutó por mucho tiempo. A menudo relacionado con firmware SSD, controladores desactualizados (especialmente gráficos, red, almacenamiento) o problemas de hardware. Actualice firmware SSD/NVMe, actualice controladores, verifique temperaturas."
        "0X00000109" = "CRITICAL_STRUCTURE_CORRUPTION: El kernel ha detectado corrupción en una estructura crítica. Puede ser hardware (RAM, CPU, errores de bus) o controladores. Ejecute diagnóstico de memoria y verifique controladores."
        "0X0000004E" = "PFN_LIST_CORRUPT: Posible problema de hardware, especialmente memoria RAM. Ejecute diagnóstico de memoria y verifique otros componentes."
        "PFN_LIST_CORRUPT" = "Posible problema de hardware, especialmente memoria RAM. Ejecute diagnóstico de memoria y verifique otros componentes."
        "0X00000124" = "WHEA_UNCORRECTABLE_ERROR: Error de hardware (CPU, RAM, etc.) reportado por Windows Hardware Error Architecture. Verifique temperaturas, ejecute diagnósticos de hardware, compruebe overclocking."
        "0X00000116" = "VIDEO_TDR_ERROR: Problema con el controlador de pantalla (Timeout Detection and Recovery). Comúnmente relacionado con la tarjeta gráfica o sus controladores. Actualice o revierta controladores gráficos."
         "0X0000001E" = "KMODE_EXCEPTION_NOT_HANDLED: Similar a KERNEL_MODE_EXCEPTION_NOT_HANDLED. Un programa o controlador en modo kernel generó una excepción no manejada. Actualice controladores, verifique software recién instalado."

        # Añadir más códigos de error comunes según se identifiquen...
    }

    if ($solutions.ContainsKey($cleanedErrorCode)) {
        return $solutions[$cleanedErrorCode]
    } else {
        return "Solución no específica encontrada. Busque en línea '$ErrorCode' o 'bugcheck $ErrorCode' para más detalles. Revise el mensaje completo del evento para pistas."
    }
}


# Función para crear la interfaz gráfica
function Show-BSODInfoGUI {
    param (
        [array]$Events,
        [array]$DumpFiles,
        [array]$ProblemDrivers
    )

    # Crear formulario principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Diagnóstico de Pantallas Azules (BSOD)"
    $form.Size = New-Object System.Drawing.Size(850, 650) # Ajustar tamaño para el nuevo label
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.MinimumSize = New-Object System.Drawing.Size(700, 500) # Permitir redimensionar

    # Cabecera
    $headerLabel = New-Object System.Windows.Forms.Label
    $headerLabel.Location = New-Object System.Drawing.Point(10, 10)
    $headerLabel.Size = New-Object System.Drawing.Size(810, 30) # Ajustar tamaño
    $headerLabel.Text = "Análisis de Pantallas Azules del Sistema"
    $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold) # Tamaño de fuente ligeramente mayor
    $headerLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $form.Controls.Add($headerLabel)

    # SubCabecera
    $subHeaderLabel = New-Object System.Windows.Forms.Label
    $subHeaderLabel.Location = New-Object System.Drawing.Point(10, 40)
    $subHeaderLabel.Size = New-Object System.Drawing.Size(810, 20) # Ajustar tamaño
    $subHeaderLabel.Text = "Equipo: $env:COMPUTERNAME - Fecha del informe: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $subHeaderLabel.ForeColor = [System.Drawing.Color]::Gray
    $form.Controls.Add($subHeaderLabel)

    # Inicializar TabControl
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 70)
    $tabControl.Size = New-Object System.Drawing.Size(815, 490) # Ajustar tamaño para el nuevo label
    $tabControl.Anchor = @([System.Windows.Forms.AnchorStyles]::Top, [System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left, [System.Windows.Forms.AnchorStyles]::Right) # Anclar para redimensionamiento
    $form.Controls.Add($tabControl)

    # Tab de Resumen
    $tabResumen = New-Object System.Windows.Forms.TabPage
    $tabResumen.Text = "Resumen"
    $tabControl.Controls.Add($tabResumen)

    # Contenido de la pestaña Resumen
    $resumenText = New-Object System.Windows.Forms.RichTextBox
    $resumenText.Location = New-Object System.Drawing.Point(10, 10)
    $resumenText.Size = New-Object System.Drawing.Size(790, 420) # Ajustar tamaño
    $resumenText.ReadOnly = $true
    $resumenText.BackColor = [System.Drawing.Color]::White
    $resumenText.Font = New-Object System.Drawing.Font("Consolas", 9) # Fuente monoespacio
    $resumenText.Anchor = @([System.Windows.Forms.AnchorStyles]::Top, [System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left, [System.Windows.Forms.AnchorStyles]::Right) # Anclar para redimensionamiento
    $resumenText.WordWrap = $true # Habilitar ajuste de línea
    $resumenText.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both # Habilitar scrollbars
    $tabResumen.Controls.Add($resumenText)

    # Preparar texto para resumen
    $resumenContent = "===== DIAGNÓSTICO DE PANTALLAS AZULES (BSOD) =====`r`n`r`n"
    $resumenContent += "Este informe analiza eventos críticos del sistema (IDs 41 y 1001) "
    $resumenContent += "y la presencia de archivos de volcado de memoria (.dmp) en '$env:windir\Minidump'.`r`n"
    $resumenContent += "Periodo analizado: Últimos 90 días.`r`n`r`n"

    if (($Events.Count -eq 0) -and ($DumpFiles.Count -eq 0)) {
        $resumenContent += "✅ No se encontraron registros de pantallas azules (BSOD) o reinicios inesperados en el periodo analizado.`r`n"
        $resumenContent += "✅ Su sistema parece estable en términos de errores críticos recientes.`r`n"
    } else {
        $resumenContent += "⚠️ ¡Se encontraron posibles pantallas azules o reinicios inesperados en su sistema!`r`n`r`n"
        $resumenContent += "• Archivos de volcado (.dmp) encontrados: $($DumpFiles.Count)`r`n"
        $resumenContent += "• Eventos críticos (IDs 41/1001) encontrados: $($Events.Count)`r`n`r`n"

        # Añadir información sobre controladores problemáticos detectados
        if ($ProblemDrivers.Count -gt 0) {
            $resumenContent += "==== CONTROLADORES PROBLEMÁTICOS DETECTADOS EN MENSAJES DE EVENTO ====`r`n`r`n"

            foreach ($driver in $ProblemDrivers | Sort-Object) { # Ordenar alfabéticamente
                $driverInfo = Get-DriverInfo -DriverName $driver
                $resumenContent += "• $driver`r`n"
                $resumenContent += "  $driverInfo`r`n`r`n"
            }
        } else {
            $resumenContent += "No se detectaron nombres de controladores específicos como causa probable en los mensajes de evento.`r`n"
            $resumenContent += "Revise la pestaña 'Eventos Críticos' para ver los detalles de cada evento y buscar códigos de error o mensajes clave.`r`n`r`n"
        }

        $resumenContent += "==== RECOMENDACIONES GENERALES ====`r`n`r`n"
        $resumenContent += "Las pantallas azules suelen indicar problemas de hardware, controladores o software del sistema. Siga estos pasos:`r`n`r`n"
        $resumenContent += "1. **Actualice Controladores:** Especialmente los de la tarjeta gráfica, red, audio y chipset. Obténgalos del sitio web del fabricante del hardware o del fabricante del PC (HP, Dell, Lenovo, etc.). Use herramientas oficiales si están disponibles.`r`n"
        $resumenContent += "2. **Actualice Windows:** Asegúrese de tener instaladas las últimas actualizaciones de seguridad y calidad.`r`n"
        $resumenContent += "3. **Ejecute SFC y DISM:** Abra el Símbolo del sistema o PowerShell como Administrador y ejecute:`r`n"
        $resumenContent += "    `t- `sfc /scannow` (Verifica y repara archivos del sistema)`r`n"
        $resumenContent += "    `t- `DISM /Online /Cleanup-Image /RestoreHealth` (Repara la imagen de Windows)`r`n"
        $resumenContent += "4. **Diagnóstico de Memoria:** Ejecute 'mdsched.exe' para comprobar si hay problemas con la memoria RAM.`r`n"
        $resumenContent += "5. **Verificación del Disco:** Ejecute 'chkdsk /f /r' (puede requerir reiniciar) para verificar y reparar el disco duro.`r`n"
        $resumenContent += "6. **Verifique Temperaturas:** Un sobrecalentamiento puede causar inestabilidad. Use software como HWMonitor para monitorizar.`r`n"
        $resumenContent += "7. **Revise Hardware Reciente:** Si el problema comenzó después de instalar nuevo hardware, retírelo para probar.`r`n"
        $resumenContent += "8. **Desinstale Software Problemático:** Si la BSOD ocurrió después de instalar un programa, especialmente antivirus o utilidades del sistema, intente desinstalarlo.`r`n`r`n"
        $resumenContent += "Para un análisis más detallado de los archivos .dmp listados en la pestaña 'Archivos de Volcado (.dmp)', use la herramienta gratuita BlueScreenView (de NirSoft) o WinDbg (Debugging Tools for Windows)."

        $resumenContent += "Revise las pestañas 'Archivos de Volcado (.dmp)' y 'Eventos Críticos' para ver detalles específicos de los registros encontrados."
    }

    $resumenText.Text = $resumenContent
      $resumenText.SelectionStart = 0 # Scroll al principio
      $resumenText.ScrollToCaret()


    # Tab de Archivos de Volcado
    $tabVolcados = New-Object System.Windows.Forms.TabPage
    $tabVolcados.Text = "Archivos de Volcado (.dmp)" # Nombre de pestaña actualizado
    $tabControl.Controls.Add($tabVolcados)

    # Contenido de la pestaña Volcados
    $volcadosListView = New-Object System.Windows.Forms.ListView
    $volcadosListView.Location = New-Object System.Drawing.Point(10, 10)
    $volcadosListView.Size = New-Object System.Drawing.Size(790, 390) # Ajustar tamaño para dejar espacio al label
    $volcadosListView.View = [System.Windows.Forms.View]::Details
    $volcadosListView.FullRowSelect = $true
    $volcadosListView.GridLines = $true
    $volcadosListView.Columns.Add("Nombre Archivo", 250) # Ajustar ancho
    $volcadosListView.Columns.Add("Fecha y Hora", 180) # Ajustar ancho
    $volcadosListView.Columns.Add("Tamaño (KB)", 100, "Right") # Ajustar ancho y alineación
    $volcadosListView.Anchor = @([System.Windows.Forms.AnchorStyles]::Top, [System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left, [System.Windows.Forms.AnchorStyles]::Right) # Anclar para redimensionamiento
    $tabVolcados.Controls.Add($volcadosListView)

    # Label de explicación para los archivos de volcado
    $volcadosExplanationLabel = New-Object System.Windows.Forms.Label
    $volcadosExplanationLabel.Location = New-Object System.Drawing.Point(10, 405) # Posición debajo del ListView
    $volcadosExplanationLabel.Size = New-Object System.Drawing.Size(790, 45) # Ajustar tamaño
    $volcadosExplanationLabel.Text = "Los archivos listados son volcados de memoria del sistema. Para analizar su contenido, identificar la causa exacta del fallo (driver, proceso, etc.) y obtener soluciones específicas, necesita usar herramientas dedicadas de análisis de volcados como BlueScreenView (NirSoft) o WinDbg (Debugging Tools for Windows)."
    $volcadosExplanationLabel.ForeColor = [System.Drawing.Color]::DarkOrange # Resaltar como información importante
    $volcadosExplanationLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5) # Fuente ligeramente más pequeña
    $volcadosExplanationLabel.Anchor = @([System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left, [System.Windows.Forms.AnchorStyles]::Right) # Anclar debajo del ListView
    $tabVolcados.Controls.Add($volcadosExplanationLabel)


    # Llenar datos de volcados
    if ($DumpFiles.Count -gt 0) {
        foreach ($dump in ($DumpFiles | Sort-Object LastWriteTime -Descending)) {
            $item = New-Object System.Windows.Forms.ListViewItem($dump.Name)
            $item.SubItems.Add($dump.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss"))
            $item.SubItems.Add([math]::Round($dump.Length / 1KB, 2))
            $volcadosListView.Items.Add($item)
        }
    } else {
        $item = New-Object System.Windows.Forms.ListViewItem("No se encontraron archivos de volcado de memoria (.dmp) en '$env:windir\Minidump'.")
        # Ajustar columnas para que el mensaje quepa
        $volcadosListView.Columns.Clear() # Limpiar columnas existentes
        $volcadosListView.Columns.Add("Estado", 700) # Añadir una columna ancha para el mensaje
        $volcadosListView.Items.Add($item)
    }

    # Tab de Eventos
    $tabEventos = New-Object System.Windows.Forms.TabPage
    $tabEventos.Text = "Eventos Críticos"
    $tabControl.Controls.Add($tabEventos)

    # Contenido de la pestaña Eventos (usando RichTextBox para detalle)
    $eventosText = New-Object System.Windows.Forms.RichTextBox
    $eventosText.Location = New-Object System.Drawing.Point(10, 10)
    $eventosText.Size = New-Object System.Drawing.Size(790, 420) # Ajustar tamaño
    $eventosText.ReadOnly = $true
    $eventosText.BackColor = [System.Drawing.Color]::White
    $eventosText.Font = New-Object System.Drawing.Font("Consolas", 8) # Fuente ligeramente más pequeña para caber más texto
    $eventosText.Anchor = @([System.Windows.Forms.AnchorStyles]::Top, [System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left, [System.Windows.Forms.AnchorStyles]::Right) # Anclar para redimensionamiento
    $eventosText.WordWrap = $true # Habilitar ajuste de línea
    $eventosText.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both # Habilitar scrollbars
    $tabEventos.Controls.Add($eventosText)

    # Llenar datos de eventos
    if ($Events.Count -gt 0) {
        $eventosContent = ""
        # Mostrar los eventos más recientes primero
        $recentEvents = $Events | Sort-Object TimeCreated -Descending # No limitar a 10, mostrar todos los encontrados en el rango de 90 días

        foreach ($event in $recentEvents) {
            $eventosContent += "==== EVENTO $($event.Id) - $($event.ProviderName) ====`r`n"
            $eventosContent += "Fecha y Hora: $($event.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss"))`r`n"
            $eventosContent += "Nivel: $($event.LevelDisplayName)`r`n"

            # Intentar identificar código de error (hex o nombre) y drivers en el mensaje
            $errorCode = $null
            # Buscar código hex o nombre de error (usar \b para coincidencias de palabras completas y capturar el punto final opcional)
            $errorMatches = [regex]::Matches($event.Message, '(0x[0-9A-Fa-f]{8}\.?)|(\b\w+_\w+\b\.?)')
            if ($errorMatches.Count -gt 0) {
                 # Tomar el primer código hex encontrado o el primer nombre de error encontrado
                 $hexCodeMatch = $errorMatches | Where-Object { $_.Value -match '^0x' } | Select-Object -First 1
                 if ($hexCodeMatch) {
                      $errorCode = $hexCodeMatch.Value
                 } else {
                      $nameCodeMatch = $errorMatches | Where-Object { $_.Value -notmatch '^0x' } | Select-Object -First 1
                      if ($nameCodeMatch) {
                           $errorCode = $nameCodeMatch.Value
                      }
                 }
            }

            if ($errorCode) {
                $eventosContent += "Código/Nombre de error detectado: $($errorCode -creplace '\.$' , '')`r`n" # Limpiar punto final para mostrar
                $solution = Get-ErrorSolution -ErrorCode $errorCode # Pasar código/nombre con o sin punto a la función
                $eventosContent += "SOLUCIÓN RECOMENDADA: $solution`r`n`r`n"
            } else {
                 # Si no se detectó un código/nombre específico, buscar información del evento ID
                 if ($event.Id -eq 1001) {
                      $eventosContent += "Evento ID 1001 (BugCheck). Este evento indica que ocurrió una Pantalla Azul (BSOD).`r`n"
                      # Intentar buscar la ruta del archivo dmp en el mensaje del Event ID 1001
                      $dumpFilePathMatch = [regex]::Match($event.Message, '(se guardó en: (.*?\.dmp))') # Buscar "se guardó en: C:\...\.dmp"
                      if ($dumpFilePathMatch.Success) {
                           $dumpFilePath = $dumpFilePathMatch.Groups[2].Value # Capturar solo la ruta del archivo
                           $eventosContent += "Archivo de volcado asociado (mencionado en el mensaje): $($dumpFilePath)`r`n"
                           $eventosContent += "Para obtener la causa exacta de este BSOD, analice este archivo usando una herramienta como BlueScreenView o WinDbg.`r`n"
                      } else {
                           $eventosContent += "El mensaje del evento no especificó el archivo de volcado. Busque archivos .dmp con una fecha/hora cercana en la pestaña 'Archivos de Volcado (.dmp)'.`r`n"
                      }
                      $eventosContent += "SOLUCIÓN: Revise las recomendaciones generales y use una herramienta de análisis de volcados para este evento.`r`n`r`n"

                 } elseif ($event.Id -eq 41) {
                      $eventosContent += "Evento ID 41 (Kernel-Power). Indica que el sistema se reinició inesperadamente (posiblemente debido a BSOD, corte de energía, etc.).`r`n"
                      # Intenta buscar el BugCheckCode en las propiedades si está disponible (puede variar)
                      $bugCheckCodeProp = $event.Properties | Where-Object { $_.Value -is [int] -and $_.Value -ne 0 } | Select-Object -First 1 # Buscar una propiedad int > 0 (puede ser el BugCheckCode)
                      if ($bugCheckCodeProp) {
                           $hexCode = "0x{0:X8}" -f $bugCheckCodeProp.Value # Formatear a hex
                           $eventosContent += "Posible Código BugCheck (detectado en propiedades del evento): $hexCode`r`n"
                           $solution = Get-ErrorSolution -ErrorCode $hexCode
                           $eventosContent += "SOLUCIÓN RECOMENDADA: $solution`r`n`r`n"
                      } else {
                           $eventosContent += "No se detectó un código de error específico ni información de BugCheck en las propiedades.`r`n"
                           $eventosContent += "SOLUCIÓN: Un reinicio inesperado puede ser causado por BSOD, pérdida de energía o problemas de hardware. Revise eventos anteriores/posteriores y recomendaciones generales.`r`n`r`n"
                      }
                 } else {
                     $eventosContent += "No se detectó código/nombre de error específico en el mensaje ni se identificó patrón común para este Event ID.`r`n"
                     $eventosContent += "SOLUCIÓN: Copie parte del mensaje y búsquelo en https://copilot.cloud.microsoft/ o https://answers.microsoft.com para obtener más información.`r`n`r`n"
                 }
            }

            # Buscar archivos .sys mencionados en el mensaje del evento
            $sysFiles = [regex]::Matches($event.Message, '(\w+\.sys)')
            if ($sysFiles.Count -gt 0) {
                $eventosContent += "Controladores detectados en el mensaje del evento:`r`n"
                foreach ($match in $sysFiles) {
                    $driverName = $match.Groups[1].Value
                    $driverInfo = Get-DriverInfo -DriverName $driverName
                    $eventosContent += "• $driverName - $($driverInfo)`r`n" # Usar parentecis para asegurar que se expanda el valor
                }
                $eventosContent += "`r`n"
            }

            $eventosContent += "Mensaje Completo del Evento:`r`n"
            $eventosContent += "$($event.Message)`r`n`r`n" # Mostrar el mensaje completo

            $eventosContent += "--------------------------------------------------------------------------------`r`n`r`n" # Separador más largo
        }

        $eventosText.Text = $eventosContent
        $eventosText.SelectionStart = 0 # Scroll al principio
        $eventosText.ScrollToCaret()

    } else {
        $eventosText.Text = "No se encontraron eventos críticos (IDs 41, 1001) relacionados con pantallas azules en los últimos 90 días."
    }

    # Tab de Soluciones Comunes
    $tabSoluciones = New-Object System.Windows.Forms.TabPage
    $tabSoluciones.Text = "Soluciones Comunes"
    $tabControl.Controls.Add($tabSoluciones)

    # Contenido de la pestaña Soluciones Comunes
    $solucionesText = New-Object System.Windows.Forms.RichTextBox
    $solucionesText.Location = New-Object System.Drawing.Point(10, 10)
    $solucionesText.Size = New-Object System.Drawing.Size(790, 420) # Ajustar tamaño
    $solucionesText.ReadOnly = $true
    $solucionesText.BackColor = [System.Drawing.Color]::White
    $solucionesText.Font = New-Object System.Drawing.Font("Consolas", 9)
      $solucionesText.Anchor = @([System.Windows.Forms.AnchorStyles]::Top, [System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left, [System.Windows.Forms.AnchorStyles]::Right) # Anclar para redimensionamiento
    $solucionesText.WordWrap = $true # Habilitar ajuste de línea
    $solucionesText.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both # Habilitar scrollbars
    $tabSoluciones.Controls.Add($solucionesText)

    # Llenar datos de soluciones comunes
    $solucionesContent = "===== SOLUCIONES PARA ERRORES COMUNES DE PANTALLA AZUL (BSOD) =====`r`n`r`n"
    $solucionesContent += "Aquí se listan algunos de los códigos de error de BSOD más comunes y sus posibles causas/soluciones.`r`n"
    $solucionesContent += "Esta información es una referencia rápida; para su caso específico, revise la pestaña 'Eventos Críticos'.`r`n`r`n"

    # --- INICIO: LÓGICA PARA LISTAR CÓDIGOS DE ERROR COMUNES (Asegúrate que esta parte esté en tu script) ---

    # Usar la misma fuente de verdad que Get-ErrorSolution para los códigos comunes
    # Clonar el diccionario para evitar modificar el original si se llama Get-ErrorSolution de otra forma
    # Dado que no podemos acceder a variables internas de la función, redeclaramos el diccionario aquí
    # para que la pestaña de soluciones muestre la misma información que usa Get-ErrorSolution.
     $solutionsListForTab = @{
        "0x0000001A" = "MEMORY_MANAGEMENT: Problema con la memoria RAM. Ejecute 'mdsched.exe' para diagnóstico de memoria RAM o considere ejecutar 'sfc /scannow' para reparar archivos del sistema."
        "MEMORY_MANAGEMENT" = "Problema con la memoria RAM. Ejecute 'mdsched.exe' para diagnóstico de memoria RAM o considere ejecutar 'sfc /scannow' para reparar archivos del sistema."
        "0x000000D1" = "DRIVER_IRQL_NOT_LESS_OR_EQUAL / DRIVER_IRQL_NOT_LESS_OR_EQUAL: Problema con controlador de dispositivo. Actualice sus controladores, especialmente de tarjeta gráfica y red. Ejecute 'sfc /scannow'."
        "IRQL_NOT_LESS_OR_EQUAL" = "Problema con controlador de dispositivo. Actualice sus controladores, especialmente de tarjeta gráfica y red. Ejecute 'sfc /scannow'."
        "DRIVER_IRQL_NOT_LESS_OR_EQUAL" = "Controlador intentando acceder memoria protegida. Actualice o reinstale controladores recientes."
        "0x00000050" = "PAGE_FAULT_IN_NONPAGED_AREA: Problema de memoria o controlador. Compruebe la RAM y ejecute 'chkdsk /f /r' para verificar el disco duro."
        "PAGE_FAULT_IN_NONPAGED_AREA" = "Problema de memoria o controlador. Compruebe la RAM y ejecute 'chkdsk /f /r' para verificar el disco duro."
        "0x000000EF" = "CRITICAL_PROCESS_DIED: Un proceso crítico del sistema ha fallado. Ejecute 'sfc /scannow' y 'DISM /Online /Cleanup-Image /RestoreHealth'."
        "CRITICAL_PROCESS_DIED" = "Un proceso crítico del sistema ha fallado. Ejecute 'sfc /scannow' y 'DISM /Online /Cleanup-Image /RestoreHealth'."
        "0x0000003B" = "SYSTEM_SERVICE_EXCEPTION: Error en servicio del sistema. Actualice controladores y Windows, y ejecute 'sfc /scannow'."
        "SYSTEM_SERVICE_EXCEPTION" = "Error en servicio del sistema. Actualice controladores y Windows, y ejecute 'sfc /scannow'."
        "0x0000007E" = "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED: Similar a KERNEL_MODE_EXCEPTION_NOT_HANDLED. Excepción no manejada en el kernel o controlador. Actualice controladores, verifique hardware, ejecute diagnósticos."
        "KERNEL_MODE_EXCEPTION_NOT_HANDLED" = "Excepción no manejada en el kernel. Actualice controladores, verifique hardware, y ejecute diagnósticos."
        "0x00000024" = "NTFS_FILE_SYSTEM: Problema con el sistema de archivos. Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "NTFS_FILE_SYSTEM" = "Problema con el sistema de archivos. Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "0x0000004A" = "PNP_DETECTED_FATAL_ERROR: Problema con Plug and Play, a menudo relacionado con controladores o hardware. Actualice controladores, verifique hardware."
        "0x000000F4" = "CRITICAL_OBJECT_TERMINATION: Proceso crítico del sistema terminado. Similar a CRITICAL_PROCESS_DIED. Ejecute sfc/DISM, verifique disco."
        "0x00000133" = "DPC_WATCHDOG_VIOLATION: Un DPC (Deferred Procedure Call) se ejecutó por mucho tiempo. A menudo relacionado con firmware SSD, controladores desactualizados (especialmente gráficos, red, almacenamiento) o problemas de hardware. Actualice firmware SSD/NVMe, actualice controladores, verifique temperaturas."
        "0x00000109" = "CRITICAL_STRUCTURE_CORRUPTION: El kernel ha detectado corrupción en una estructura crítica. Puede ser hardware (RAM, CPU, errores de bus) o controladores. Ejecute diagnóstico de memoria y verifique controladores."
        "0x0000004E" = "PFN_LIST_CORRUPT: Posible problema de hardware, especialmente memoria RAM. Ejecute diagnóstico de memoria y verifique otros componentes."
        "PFN_LIST_CORRUPT" = "Posible problema de hardware, especialmente memoria RAM. Ejecute diagnóstico de memoria y verifique otros componentes."
        "0x00000124" = "WHEA_UNCORRECTABLE_ERROR: Error de hardware (CPU, RAM, etc.) reportado por Windows Hardware Error Architecture. Verifique temperaturas, ejecute diagnósticos de hardware, compruebe overclocking."
        "0x00000116" = "VIDEO_TDR_ERROR: Problema con el controlador de pantalla (Timeout Detection and Recovery). Comúnmente relacionado con la tarjeta gráfica o sus controladores. Actualice o revierta controladores gráficos."
         "0x0000001E" = "KMODE_EXCEPTION_NOT_HANDLED: Similar a KERNEL_MODE_EXCEPTION_NOT_HANDLED. Un programa o controlador en modo kernel generó una excepción no manejada. Actualice controladores, verifique software recién instalado."
    }


    $solucionesContent += "==== CÓDIGOS DE ERROR COMUNES ====`r`n`r`n"
    # Ordenar por clave (código o nombre) para mejor presentación
    foreach ($key in $solutionsListForTab.Keys | Sort-Object) {
        $solucionesContent += "$key`r`n"
        $solucionesContent += "Solución: $($solutionsListForTab[$key])`r`n`r`n"
    }

    # --- FIN: LÓGICA PARA LISTAR CÓDIGOS DE ERROR COMUNES ---


    $solucionesContent += "`r`n===== CONTROLADORES PROBLEMÁTICOS COMUNES DETECTADOS EN BSODs =====`r`n`r`n"
      $solucionesContent += "Estos son algunos controladores que frecuentemente se asocian con BSODs y sus causas típicas.`r`n`r`n"

    # Usar la misma fuente de verdad que Get-DriverInfo para los drivers comunes
    # Clonar el diccionario
    # Igual que antes, redeclaramos el diccionario aquí para listarlo.
    # Esto asegura que la pestaña de soluciones muestre la misma info que Get-DriverInfo usa.
     $driverInfoListForTab = @{
        "ntoskrnl.exe" = "Kernel de Windows. RELACIONADO A: problemas del sistema, memoria, controladores genéricos o actualizaciones recientes. SOLUCIÓN: Reinstale actualizaciones recientes, ejecute sfc/DISM, verifique RAM y controladores."
        "hal.dll" = "Capa de abstracción de hardware. RELACIONADO A: incompatibilidad de hardware, configuración de BIOS (modo AHCI/IDE) o BIOS desactualizada. SOLUCIÓN: Actualice la BIOS y verifique configuración SATA."
        "ataport.sys" = "Controlador de puertos ATA/SATA. RELACIONADO A: problemas con discos duros o SSD, cableado SATA o controlador AHCI. SOLUCIÓN: Compruebe conexiones físicas, actualice controlador AHCI/SATA (Intel RST, AMD equivalent) y ejecute diagnósticos de disco."
        "ntfs.sys" = "Sistema de archivos NTFS. RELACIONADO A: corrupción del sistema de archivos en el disco duro. SOLUCIÓN: Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "tcpip.sys" = "Controlador TCP/IP. RELACIONADO A: problemas de red, software de seguridad (firewall/antivirus) o controladores de adaptador de red defectuosos. SOLUCIÓN: Reinicie el adaptador de red, actualice sus controladores, revise software de seguridad."
        "dxgkrnl.sys" = "DirectX Graphics Kernel. RELACIONADO A: problemas con tarjeta gráfica, controladores gráficos o DirectX. SOLUCIÓN: Realice una instalación limpia de los controladores gráficos, reinstale DirectX."
        "nvlddmkm.sys" = "Controlador NVIDIA (versión del modo kernel). RELACIONADO A: sobrecalentamiento, controladores de tarjeta gráfica NVIDIA corruptos o desactualizados, o hardware gráfico defectuoso. SOLUCIÓN: Actualice o reinstale *limpiamente* controladores gráficos, verifique temperatura de la GPU, reduzca overclocking si aplica."
        "atikmpag.sys" = "Controlador AMD (versión del modo kernel). RELACIONADO A: problemas con tarjeta gráfica AMD, controladores gráficos corruptos o desactualizados. SOLUCIÓN: Actualice o reinstale *limpiamente* controladores de la tarjeta gráfica AMD."
        "igdkmd64.sys" = "Controlador Intel Graphics (64 bits). RELACIONADO A: problemas con gráficos integrados Intel o sus controladores. SOLUCIÓN: Actualice controladores gráficos Intel desde el sitio de Intel o del fabricante del PC."
        "storport.sys" = "Sistema de almacenamiento (puerto de almacenamiento). RELACIONADO A: problemas con controladores de disco, firmware de SSD/HDD o hardware de almacenamiento. SOLUCIÓN: Actualice firmware de SSD/HDD y controladores de almacenamiento (Intel RST, etc.)."
        "usbhub.sys" = "Controlador del concentrador USB. RELACIONADO A: problemas con dispositivos USB conectados, puertos USB defectuosos o sus controladores. SOLUCIÓN: Desconecte dispositivos USB no esenciales, pruebe puertos diferentes, actualice controladores del controlador USB."
        "bthport.sys" = "Controlador de puerto Bluetooth. RELACIONADO A: problemas con dispositivos Bluetooth o el adaptador Bluetooth. SOLUCIÓN: Desactive Bluetooth temporalmente, actualice controladores Bluetooth."
        "ndis.sys" = "Controlador de interfaz de red (Network Driver Interface Specification). RELACIONADO A: problemas con adaptadores de red (Wi-Fi o Ethernet) o software relacionado. SOLUCIÓN: Reinstale o actualice controladores de red."
        "iaStorA.sys" = "Controlador Intel Rapid Storage Technology (RST). RELACIONADO A: problemas con configuración RAID, SSDs o controladores SATA en sistemas Intel. SOLUCIÓN: Actualice Intel RST y controladores SATA."
        "aswsp.sys" = "Controlador Avast Self Protection. RELACIONADO A: conflicto con antivirus Avast. SOLUCIÓN: Actualice o reinstale Avast, o considere deshabilitarlo temporalmente para probar."
        "wdfilter.sys" = "Filtro de Windows Defender. RELACIONADO A: conflicto con Windows Defender. SOLUCIÓN: Asegúrese de que Windows Defender esté actualizado o deshabilite temporalmente si usa otro antivirus."
        "mfewfpk.sys" = "Controlador McAfee. RELACIONADO A: conflicto con antivirus McAfee. SOLUCIÓN: Actualice o reinstale McAfee, o considere deshabilitarlo temporalmente."
        "dx.sys" = "Controlador relacionado con DirectX. RELACIONADO A: problemas con controladores gráficos o DirectX. SOLUCIÓN: Reinstale DirectX y actualice controladores gráficos."
        "Acpi.sys" = "Driver de Interfaz de Configuración Avanzada y Energía (ACPI). RELACIONADO A: Problemas con la gestión de energía, BIOS o hardware. SOLUCIÓN: Actualice BIOS, revise configuración de energía."
        "Wdf01000.sys" = "Marco de Controladores de Windows (Kernel-Mode Driver Framework). RELACIONADO A: Problemas con varios controladores que usan KMDF. SOLUCIÓN: Asegúrese de que Windows esté actualizado, actualice todos los controladores."
        "win32kbase.sys" = "Subsistema del kernel de Windows relacionado con la interfaz gráfica. RELACIONADO A: Problemas gráficos, controladores de pantalla o software que interactúa con la GUI. SOLUCIÓN: Actualice controladores gráficos, revise software reciente que afecte la interfaz."
    }


    # Ordenar por nombre del driver
      foreach ($key in $driverInfoListForTab.Keys | Sort-Object) {
        $solucionesContent += "$key`r`n"
        $solucionesContent += "$($driverInfoListForTab[$key])`r`n`r`n"
    }


    $solucionesContent += "`r`n===== COMANDOS ÚTILES PARA LA SOLUCIÓN DE PROBLEMAS =====`r`n`r`n"
    $solucionesContent += "Ejecute estos comandos en el Símbolo del sistema o PowerShell como Administrador:`r`n`r`n"
    $solucionesContent += "• `sfc /scannow` `r`n  Verifica y repara archivos protegidos del sistema Windows. Muy útil.`r`n`r`n"
    $solucionesContent += "• `DISM /Online /Cleanup-Image /RestoreHealth` `r`n  Repara la imagen de Windows. Útil si sfc /scannow falla.`r`n`r`n"
    $solucionesContent += "• `chkdsk C: /f /r` `r`n  Verifica y repara errores en el disco C: y busca sectores defectuosos. Puede requerir reiniciar.`r`n`r`n"
    $solucionesContent += "• `mdsched.exe` `r`n  Ejecuta la herramienta de diagnóstico de memoria de Windows.`r`n`r`n"
    $solucionesContent += "• `powercfg -energy` `r`n  Genera un informe detallado de eficiencia energética que puede revelar problemas de hardware o configuración.`r`n`r`n"
    $solucionesContent += "• `dxdiag` `r`n  Abre la herramienta de diagnóstico de DirectX, útil para problemas gráficos/sonido.`r`n`r`n"


    $solucionesContent += "`r`n===== HERRAMIENTAS PARA ANALIZAR ARCHIVOS DE VOLCADO (.DMP) =====`r`n`r`n"
    $solucionesContent += "Para analizar a fondo los archivos .dmp listados en la pestaña correspondiente y obtener la causa raíz del fallo, use estas herramientas (requieren descarga):`r`n`r`n"
    $solucionesContent += "• **BlueScreenView (de NirSoft):** Herramienta ligera y fácil de usar. Analiza archivos .dmp y presenta la información de forma clara (código de error, driver/módulo causante, etc.). Busque 'BlueScreenView NirSoft' en su navegador.`r`n`r`n"
    $solucionesContent += "• **WinDbg (Debugging Tools for Windows):** Parte del Windows SDK. Herramienta muy potente para análisis avanzado de volcados, pero con una curva de aprendizaje mayor. Requiere descargar símbolos de depuración. Busque 'Debugging Tools for Windows download'.`r`n`r`n"
    $solucionesContent += "`r`n===== BUSCAR AYUDA ADICIONAL EN LÍNEA =====`r`n`r`n"
    $solucionesContent += "Para errores no reconocidos o asistencia personalizada, copie el código o mensaje exacto de la pestaña 'Eventos Críticos' y consulte:`r`n"
    # Usar LinkLabel para enlaces clickeables
    # No es trivial hacer enlaces clickeables en un RichTextBox llenado con texto plano como aquí.
    # Se mantendrán como texto para simplificar, pero se puede considerar usar LinkLabel por separado si es crucial.
    $solucionesContent += "• Microsoft Copilot (AI): https://copilot.cloud.microsoft/`r`n"
    $solucionesContent += "• Foros de la Comunidad de Microsoft: https://answers.microsoft.com`r`n"
    $solucionesContent += "• Documentación de Microsoft Learn (Códigos de Error): Busque 'Bug Check Code Reference' MSDN`r`n"


    $solucionesText.Text = $solucionesContent
    $solucionesText.SelectionStart = 0 # Scroll al principio
    $solucionesText.ScrollToCaret()


    # Botón exportar
    $exportButton = New-Object System.Windows.Forms.Button
    $exportButton.Location = New-Object System.Drawing.Point(10, 555) # Ajustar posición
    $exportButton.Size = New-Object System.Drawing.Size(120, 25)
    $exportButton.Text = "Exportar Informe"
    $exportButton.Anchor = @([System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left) # Anclar a la parte inferior izquierda
    $exportButton.Add_Click({
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "Archivos de texto (*.txt)|*.txt|Todos los archivos (*.*)|*.*"
        $saveDialog.Title = "Guardar informe de diagnóstico BSOD"
        $saveDialog.FileName = "Informe_BSOD_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt" # Nombre de archivo más específico

        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            # Regenerar el contenido del informe para exportar
            $exportContent = $resumenText.Text + "`r`n`r`n" +
                             "===== CONTENIDO DE 'EVENTOS CRÍTICOS' =====" + "`r`n`r`n" + $eventosText.Text + "`r`n`r`n" +
                             "===== CONTENIDO DE 'SOLUCIONES COMUNES' =====" + "`r`n`r`n" + $solucionesText.Text

            # Exportar también la lista de volcados si hay
            if ($volcadosListView.Items.Count -gt 0 -and $DumpFiles.Count -gt 0) {
                 $exportContent += "`r`n`r`n===== ARCHIVOS DE VOLCADO ENCONTRADOS ($env:windir\Minidump) =====`r`n`r`n"
                 $exportContent += "Nombre Archivo              Fecha y Hora          Tamaño (KB)`r`n"
                 $exportContent += "------------------------------------------------------------`r`n"
                 foreach ($item in $volcadosListView.Items) {
                     # Asegurarse de no exportar el mensaje "No se encontraron..." como si fuera un archivo
                     if ($item.Text -notlike "No se encontraron*") {
                          $exportContent += "{0,-25}{1,-20}{2,-10}`r`n" -f $item.SubItems[0].Text, $item.SubItems[1].Text, $item.SubItems[2].Text
                     }
                 }
                 $exportContent += "`r`n(Nota: El análisis detallado de estos archivos requiere herramientas como BlueScreenView o WinDbg)`r`n" # Añadir nota al final de la sección de volcados
            }


            try {
                [System.IO.File]::WriteAllText($saveDialog.FileName, $exportContent, [System.Text.Encoding]::UTF8) # Especificar codificación UTF8
                [System.Windows.Forms.MessageBox]::Show("Informe exportado correctamente a:`r`n$($saveDialog.FileName)", "Exportación Exitosa", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
            catch {
                 [System.Windows.Forms.MessageBox]::Show("Error al exportar el informe:`r`n$($_.Exception.Message)", "Error de Exportación", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })
    $form.Controls.Add($exportButton)

    # Botón para abrir la carpeta de volcados
    $openDumpFolderButton = New-Object System.Windows.Forms.Button
    $openDumpFolderButton.Location = New-Object System.Drawing.Point(140, 555) # Posicionar
    $openDumpFolderButton.Size = New-Object System.Drawing.Size(160, 25)
    $openDumpFolderButton.Text = "Abrir Carpeta de Volcados"
    $openDumpFolderButton.Anchor = @([System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Left) # Anclar
    $openDumpFolderButton.Add_Click({
        try {
            if (Test-Path "$env:windir\Minidump") {
                 [System.Diagnostics.Process]::Start("explorer.exe", "$env:windir\Minidump")
            } else {
                 [System.Windows.Forms.MessageBox]::Show("La carpeta de volcados ('$env:windir\Minidump') no existe en este sistema.", "Carpeta no Encontrada", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("No se pudo abrir la carpeta de volcados.`r`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $form.Controls.Add($openDumpFolderButton)


    # Botón cerrar
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(725, 555) # Ajustar posición (850 - 100 - 25 = 725 con margen)
    $closeButton.Size = New-Object System.Drawing.Size(100, 25)
    $closeButton.Text = "Cerrar"
      $closeButton.Anchor = @([System.Windows.Forms.AnchorStyles]::Bottom, [System.Windows.Forms.AnchorStyles]::Right) # Anclar a la parte inferior derecha
    $closeButton.Add_Click({ $form.Close() })
    $form.Controls.Add($closeButton)

    # Mostrar el formulario
    [void]$form.ShowDialog() # Usar [void] para evitar que ShowDialog() devuelva un valor en la consola
}

# Función principal
function Main {
    # Verificar si se ejecuta con permisos de administrador
    $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isElevated) {
        [System.Windows.Forms.MessageBox]::Show("Este script debe ejecutarse con permisos de Administrador para acceder a los registros de eventos y archivos de volcado.`r`nEjecute PowerShell como Administrador y luego ejecute el script.", "Permisos Requeridos", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        exit
    }


    # Mensaje informativo mientras se recolecta la información
    $infoForm = New-Object System.Windows.Forms.Form
    $infoForm.Text = "Recolectando Información..."
    $infoForm.Size = New-Object System.Drawing.Size(300, 100)
    $infoForm.StartPosition = "CenterScreen"
    $infoForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $infoForm.ControlBox = $false # Sin botón de cerrar
    $infoForm.ShowInTaskbar = $false # No mostrar en la barra de tareas
    $infoForm.TopMost = $true # Mantener encima de otras ventanas

    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Location = New-Object System.Drawing.Point(20, 20)
    $infoLabel.Size = New-Object System.Drawing.Size(260, 40)
    $infoLabel.Text = "Por favor, espere mientras se analizan los registros y archivos de volcado..."
    $infoForm.Controls.Add($infoLabel)

    $infoForm.Show()
    [System.Windows.Forms.Application]::DoEvents() # Procesar eventos para mostrar el formulario de información

    try {
        $bsodInfo = Get-BSODInfo

        $events = $bsodInfo.Events
        $dumpFiles = $bsodInfo.DumpFiles
        $problemDrivers = $bsodInfo.ProblemDrivers

    }
    finally {
        # Cerrar el formulario informativo
        $infoForm.Close()
        $infoForm.Dispose()
    }


    # Mostrar la interfaz gráfica con la información
    Show-BSODInfoGUI -Events $events -DumpFiles $dumpFiles -ProblemDrivers $problemDrivers
}

# Ejecutar el script
Main
