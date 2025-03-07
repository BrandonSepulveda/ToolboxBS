# Script para detectar pantallas azules (BSOD) y mostrar resultados en ventana emergente
# Nombre: Check-BSOD-Popup.ps1

# Cargar ensamblados necesarios para Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Función para obtener información sobre los BSODs
function Get-BSODInfo {
    Write-Host "Analizando registros de eventos para pantallas azules (BSOD)..." -ForegroundColor Cyan
    
    # Obtenemos eventos de error crítico del sistema (EventID 41 o 1001)
    $bsodEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        Level = 1,2
        ID = 41, 1001
    } -ErrorAction SilentlyContinue

    # Obtenemos información del registro de minidumps
    $dumpFiles = Get-ChildItem -Path "$env:windir\Minidump\*.dmp" -ErrorAction SilentlyContinue
    
    # Extraer información adicional sobre posibles controladores problemáticos
    $problemDrivers = @()
    
    # Analizar registros de eventos para encontrar controladores problemáticos
    foreach ($event in $bsodEvents) {
        # Buscar nombres de archivos .sys en la descripción del evento
        $sysFiles = [regex]::Matches($event.Message, '(\w+\.sys)')
        
        foreach ($match in $sysFiles) {
            $driverName = $match.Groups[1].Value
            if ($driverName -notin $problemDrivers) {
                $problemDrivers += $driverName
            }
        }
    }
    
    return @{
        Events = $bsodEvents
        DumpFiles = $dumpFiles
        ProblemDrivers = $problemDrivers
    }
}

# Función para interpretar códigos de error comunes
function Get-ErrorSolution {
    param(
        [string]$ErrorCode
    )
    
    $solutions = @{
        "MEMORY_MANAGEMENT" = "Problema con la memoria RAM. Ejecute 'mdsched.exe' para diagnóstico de memoria RAM o considere ejecutar 'sfc /scannow' para reparar archivos del sistema."
        "IRQL_NOT_LESS_OR_EQUAL" = "Problema con controlador de dispositivo. Actualice sus controladores, especialmente de tarjeta gráfica y red. Ejecute 'sfc /scannow'."
        "PAGE_FAULT_IN_NONPAGED_AREA" = "Problema de memoria o controlador. Compruebe la RAM y ejecute 'chkdsk /f /r' para verificar el disco duro."
        "CRITICAL_PROCESS_DIED" = "Un proceso crítico del sistema ha fallado. Ejecute 'sfc /scannow' y 'DISM /Online /Cleanup-Image /RestoreHealth'."
        "SYSTEM_SERVICE_EXCEPTION" = "Error en servicio del sistema. Actualice controladores y Windows, y ejecute 'sfc /scannow'."
        "DRIVER_IRQL_NOT_LESS_OR_EQUAL" = "Controlador intentando acceder memoria protegida. Actualice o reinstale controladores recientes."
        "KERNEL_MODE_EXCEPTION_NOT_HANDLED" = "Excepción no manejada en el kernel. Actualice controladores, verifique hardware, y ejecute diagnósticos."
        "NTFS_FILE_SYSTEM" = "Problema con el sistema de archivos. Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "PFN_LIST_CORRUPT" = "Posible problema de hardware, especialmente memoria RAM. Ejecute diagnóstico de memoria y verifique otros componentes."
    }
    
    foreach ($key in $solutions.Keys) {
        if ($ErrorCode -match $key) {
            return $solutions[$key]
        }
    }
    
    return "Código de error no reconocido específicamente. Recomendaciones generales: Actualizar controladores, ejecutar 'sfc /scannow', verificar hardware y considerar actualizar Windows."
}

# Función para obtener información sobre controladores problemáticos comunes
function Get-DriverInfo {
    param(
        [string]$DriverName
    )
    
    $driverInfo = @{
        "ntoskrnl.exe" = "Kernel de Windows. RELACIONADO A: problemas del sistema o actualizaciones recientes. SOLUCIÓN: Reinstale actualizaciones recientes o revierta a una versión anterior de Windows."
        "hal.dll" = "Capa de abstracción de hardware. RELACIONADO A: incompatibilidad de hardware o BIOS. SOLUCIÓN: Actualice la BIOS y verifique compatibilidad de hardware."
        "ataport.sys" = "Controlador de puertos ATA. RELACIONADO A: problemas con discos duros o SSD. SOLUCIÓN: Compruebe conexiones SATA y ejecute diagnósticos de disco."
        "ntfs.sys" = "Sistema de archivos NTFS. RELACIONADO A: corrupción del sistema de archivos. SOLUCIÓN: Ejecute 'chkdsk /f /r' para reparar el disco."
        "tcpip.sys" = "Controlador TCP/IP. RELACIONADO A: problemas de red o software de seguridad. SOLUCIÓN: Reinicie el adaptador de red y actualice sus controladores."
        "dxgkrnl.sys" = "DirectX Graphics Kernel. RELACIONADO A: problemas con tarjeta gráfica o controladores. SOLUCIÓN: Actualice o reinstale controladores gráficos."
        "nvlddmkm.sys" = "Controlador NVIDIA. RELACIONADO A: sobrecalentamiento o controladores de tarjeta gráfica NVIDIA. SOLUCIÓN: Actualice controladores gráficos y verifique temperatura."
        "atikmpag.sys" = "Controlador AMD. RELACIONADO A: problemas con tarjeta gráfica AMD. SOLUCIÓN: Actualice controladores de la tarjeta gráfica AMD."
        "igdkmd64.sys" = "Controlador Intel Graphics. RELACIONADO A: problemas con gráficos integrados Intel. SOLUCIÓN: Actualice controladores gráficos Intel."
        "storport.sys" = "Sistema de almacenamiento. RELACIONADO A: problemas con controladores de disco. SOLUCIÓN: Actualice firmware de SSD/HDD y controladores de almacenamiento."
        "usbhub.sys" = "Controlador USB. RELACIONADO A: problemas con dispositivos USB. SOLUCIÓN: Desconecte dispositivos USB no esenciales y actualice controladores."
        "bthport.sys" = "Controlador Bluetooth. RELACIONADO A: problemas con dispositivos Bluetooth. SOLUCIÓN: Desactive Bluetooth temporalmente y actualice controladores."
        "ndis.sys" = "Controlador de red. RELACIONADO A: problemas con adaptadores de red. SOLUCIÓN: Reinstale o actualice controladores de red."
        "iaStorA.sys" = "Controlador Intel Rapid Storage. RELACIONADO A: problemas con configuración RAID o SSD. SOLUCIÓN: Actualice Intel RST y controladores SATA."
        "aswsp.sys" = "Controlador Avast. RELACIONADO A: conflicto con antivirus Avast. SOLUCIÓN: Actualice o reinstale Avast, o cambie de antivirus."
        "wdfilter.sys" = "Windows Defender. RELACIONADO A: conflicto con Windows Defender. SOLUCIÓN: Actualice Windows Defender o deshabilite temporalmente."
        "mfewfpk.sys" = "Controlador McAfee. RELACIONADO A: conflicto con antivirus McAfee. SOLUCIÓN: Actualice o reinstale McAfee, o cambie de antivirus."
        "dx.sys" = "DirectX o controlador específico. RELACIONADO A: problemas con controladores gráficos o DirectX. SOLUCIÓN: Reinstale DirectX y actualice controladores gráficos."
    }
    
    if ($driverInfo.ContainsKey($DriverName)) {
        return $driverInfo[$DriverName]
    } else {
        return "Controlador no identificado específicamente. Copie este nombre '$DriverName' y busque en https://copilot.cloud.microsoft/ para obtener más información."
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
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    # Cabecera
    $headerLabel = New-Object System.Windows.Forms.Label
    $headerLabel.Location = New-Object System.Drawing.Point(10, 10)
    $headerLabel.Size = New-Object System.Drawing.Size(780, 30)
    $headerLabel.Text = "Análisis de Pantallas Azules del Sistema"
    $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($headerLabel)

    # SubCabecera
    $subHeaderLabel = New-Object System.Windows.Forms.Label
    $subHeaderLabel.Location = New-Object System.Drawing.Point(10, 40)
    $subHeaderLabel.Size = New-Object System.Drawing.Size(780, 20)
    $subHeaderLabel.Text = "Equipo: $env:COMPUTERNAME - Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $subHeaderLabel.ForeColor = [System.Drawing.Color]::Gray
    $form.Controls.Add($subHeaderLabel)

    # Inicializar TabControl
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 70)
    $tabControl.Size = New-Object System.Drawing.Size(765, 450)
    $form.Controls.Add($tabControl)

    # Tab de Resumen
    $tabResumen = New-Object System.Windows.Forms.TabPage
    $tabResumen.Text = "Resumen"
    $tabControl.Controls.Add($tabResumen)

    # Contenido de la pestaña Resumen
    $resumenText = New-Object System.Windows.Forms.RichTextBox
    $resumenText.Location = New-Object System.Drawing.Point(10, 10)
    $resumenText.Size = New-Object System.Drawing.Size(740, 400)
    $resumenText.ReadOnly = $true
    $resumenText.BackColor = [System.Drawing.Color]::White
    $resumenText.Font = New-Object System.Drawing.Font("Consolas", 10)
    $tabResumen.Controls.Add($resumenText)

    # Preparar texto para resumen
    $resumenContent = "===== DIAGNÓSTICO DE PANTALLAS AZULES (BSOD) =====`r`n`r`n"
    
    if (($Events.Count -eq 0) -and ($DumpFiles.Count -eq 0)) {
        $resumenContent += "✅ No se encontraron registros de pantallas azules (BSOD) en este equipo.`r`n"
        $resumenContent += "✅ Su sistema parece estable en términos de errores críticos.`r`n"
    } else {
        $resumenContent += "⚠️ ¡Se encontraron posibles pantallas azules en su sistema!`r`n`r`n"
        $resumenContent += "• Archivos de volcado encontrados: $($DumpFiles.Count)`r`n"
        $resumenContent += "• Eventos críticos encontrados: $($Events.Count)`r`n`r`n"
        
        # Añadir información sobre controladores problemáticos detectados
        if ($ProblemDrivers.Count -gt 0) {
            $resumenContent += "==== CONTROLADORES PROBLEMÁTICOS DETECTADOS ====`r`n`r`n"
            
            foreach ($driver in $ProblemDrivers) {
                $driverInfo = Get-DriverInfo -DriverName $driver
                $resumenContent += "• $driver - $driverInfo`r`n`r`n"
            }
        } else {
            $resumenContent += "No se detectaron controladores específicos como causa probable.`r`n"
            $resumenContent += "Copie el código de error de la pestaña 'Eventos' y búsquelo en https://copilot.cloud.microsoft/ para obtener más información.`r`n`r`n"
        }
        
        $resumenContent += "==== RECOMENDACIONES GENERALES ====`r`n`r`n"
        $resumenContent += "1. Ejecute 'sfc /scannow' para verificar y reparar archivos del sistema`r`n"
        $resumenContent += "2. Ejecute 'DISM /Online /Cleanup-Image /RestoreHealth' para reparar Windows`r`n"
        $resumenContent += "3. Actualice todos los controladores, especialmente tarjeta gráfica y red`r`n"
        $resumenContent += "4. Verifique la temperatura del sistema con herramientas como HWMonitor`r`n"
        $resumenContent += "5. Compruebe si hay actualizaciones de Windows pendientes`r`n"
        $resumenContent += "6. Ejecute diagnósticos de memoria RAM con 'mdsched.exe'`r`n"
        $resumenContent += "7. Verifique el estado del disco duro con 'chkdsk /f /r'`r`n"
        $resumenContent += "8. Considere usar BlueScreenView para un análisis más detallado`r`n`r`n"
        
        $resumenContent += "Revise las pestañas 'Volcados' y 'Eventos' para ver detalles específicos."
    }

    $resumenText.Text = $resumenContent

    # Tab de Volcados
    $tabVolcados = New-Object System.Windows.Forms.TabPage
    $tabVolcados.Text = "Volcados"
    $tabControl.Controls.Add($tabVolcados)

    # Contenido de la pestaña Volcados
    $volcadosListView = New-Object System.Windows.Forms.ListView
    $volcadosListView.Location = New-Object System.Drawing.Point(10, 10)
    $volcadosListView.Size = New-Object System.Drawing.Size(740, 400)
    $volcadosListView.View = [System.Windows.Forms.View]::Details
    $volcadosListView.FullRowSelect = $true
    $volcadosListView.GridLines = $true
    $volcadosListView.Columns.Add("Nombre", 200)
    $volcadosListView.Columns.Add("Fecha", 150)
    $volcadosListView.Columns.Add("Tamaño (KB)", 90)
    $tabVolcados.Controls.Add($volcadosListView)

    # Llenar datos de volcados
    if ($DumpFiles.Count -gt 0) {
        foreach ($dump in ($DumpFiles | Sort-Object LastWriteTime -Descending)) {
            $item = New-Object System.Windows.Forms.ListViewItem($dump.Name)
            $item.SubItems.Add($dump.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss"))
            $item.SubItems.Add([math]::Round($dump.Length / 1KB, 2))
            $volcadosListView.Items.Add($item)
        }
    } else {
        $item = New-Object System.Windows.Forms.ListViewItem("No se encontraron archivos de volcado")
        $volcadosListView.Items.Add($item)
    }

    # Tab de Eventos
    $tabEventos = New-Object System.Windows.Forms.TabPage
    $tabEventos.Text = "Eventos"
    $tabControl.Controls.Add($tabEventos)

    # Contenido de la pestaña Eventos
    $eventosText = New-Object System.Windows.Forms.RichTextBox
    $eventosText.Location = New-Object System.Drawing.Point(10, 10)
    $eventosText.Size = New-Object System.Drawing.Size(740, 400)
    $eventosText.ReadOnly = $true
    $eventosText.BackColor = [System.Drawing.Color]::White
    $eventosText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $tabEventos.Controls.Add($eventosText)

    # Llenar datos de eventos
    if ($Events.Count -gt 0) {
        $eventosContent = ""
        $recentEvents = $Events | Sort-Object TimeCreated -Descending | Select-Object -First 10
        
        foreach ($event in $recentEvents) {
            $eventosContent += "==== EVENTO $($event.Id) - $($event.TimeCreated) ====`r`n`r`n"
            $eventosContent += "$($event.Message)`r`n`r`n"
            
            # Intentar identificar código de error en el mensaje
            $errorCodeMatches = [regex]::Matches($event.Message, '(0x[0-9A-Fa-f]{8})|(\w+_\w+)')
            if ($errorCodeMatches.Count -gt 0) {
                $errorCode = $errorCodeMatches[0].Value
                $eventosContent += "Código de error detectado: $errorCode`r`n"
                $solution = Get-ErrorSolution -ErrorCode $errorCode
                $eventosContent += "SOLUCIÓN RECOMENDADA: $solution`r`n`r`n"
            } else {
                $eventosContent += "No se detectó código de error específico. Copie parte del mensaje y búsquelo en https://copilot.cloud.microsoft/ para obtener más información.`r`n`r`n"
            }
            
            # Buscar archivos .sys mencionados en el mensaje del evento
            $sysFiles = [regex]::Matches($event.Message, '(\w+\.sys)')
            if ($sysFiles.Count -gt 0) {
                $eventosContent += "Controladores detectados en el evento:`r`n"
                foreach ($match in $sysFiles) {
                    $driverName = $match.Groups[1].Value
                    $driverInfo = Get-DriverInfo -DriverName $driverName
                    $eventosContent += "• $driverName - $driverInfo`r`n"
                }
                $eventosContent += "`r`n"
            }
            
            $eventosContent += "-----------------------------------------------`r`n`r`n"
        }
        
        $eventosText.Text = $eventosContent
    } else {
        $eventosText.Text = "No se encontraron eventos críticos relacionados con pantallas azules."
    }

    # Tab de Soluciones
    $tabSoluciones = New-Object System.Windows.Forms.TabPage
    $tabSoluciones.Text = "Soluciones"
    $tabControl.Controls.Add($tabSoluciones)

    # Contenido de la pestaña Soluciones
    $solucionesText = New-Object System.Windows.Forms.RichTextBox
    $solucionesText.Location = New-Object System.Drawing.Point(10, 10)
    $solucionesText.Size = New-Object System.Drawing.Size(740, 400)
    $solucionesText.ReadOnly = $true
    $solucionesText.BackColor = [System.Drawing.Color]::White
    $solucionesText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $tabSoluciones.Controls.Add($solucionesText)

    # Llenar datos de soluciones comunes
    $solucionesContent = "===== SOLUCIONES PARA ERRORES COMUNES DE PANTALLA AZUL =====`r`n`r`n"
    
    $solutions = @{
        "MEMORY_MANAGEMENT" = "Problema con la memoria RAM. Ejecute 'mdsched.exe' para diagnóstico de memoria RAM o considere ejecutar 'sfc /scannow' para reparar archivos del sistema."
        "IRQL_NOT_LESS_OR_EQUAL" = "Problema con controlador de dispositivo. Actualice sus controladores, especialmente de tarjeta gráfica y red. Ejecute 'sfc /scannow'."
        "PAGE_FAULT_IN_NONPAGED_AREA" = "Problema de memoria o controlador. Compruebe la RAM y ejecute 'chkdsk /f /r' para verificar el disco duro."
        "CRITICAL_PROCESS_DIED" = "Un proceso crítico del sistema ha fallado. Ejecute 'sfc /scannow' y 'DISM /Online /Cleanup-Image /RestoreHealth'."
        "SYSTEM_SERVICE_EXCEPTION" = "Error en servicio del sistema. Actualice controladores y Windows, y ejecute 'sfc /scannow'."
        "DRIVER_IRQL_NOT_LESS_OR_EQUAL" = "Controlador intentando acceder memoria protegida. Actualice o reinstale controladores recientes."
        "KERNEL_MODE_EXCEPTION_NOT_HANDLED" = "Excepción no manejada en el kernel. Actualice controladores, verifique hardware, y ejecute diagnósticos."
        "NTFS_FILE_SYSTEM" = "Problema con el sistema de archivos. Ejecute 'chkdsk /f /r' para verificar y reparar el disco."
        "PFN_LIST_CORRUPT" = "Posible problema de hardware, especialmente memoria RAM. Ejecute diagnóstico de memoria y verifique otros componentes."
    }
    
    foreach ($key in $solutions.Keys) {
        $solucionesContent += "$key`r`n"
        $solucionesContent += "Solución: $($solutions[$key])`r`n`r`n"
    }
    
    $solucionesContent += "`r`n===== CONTROLADORES PROBLEMÁTICOS COMUNES =====`r`n`r`n"
    
    $commonDrivers = @{
        "ntoskrnl.exe" = "Kernel de Windows. Problemas del sistema o actualizaciones recientes."
        "dxgkrnl.sys" = "DirectX Graphics Kernel. Problemas con tarjeta gráfica."
        "nvlddmkm.sys" = "Controlador NVIDIA. Sobrecalentamiento o controladores desactualizados."
        "atikmpag.sys" = "Controlador AMD. Problemas con tarjeta gráfica AMD."
        "igdkmd64.sys" = "Controlador Intel Graphics. Problemas con gráficos integrados."
        "tcpip.sys" = "Controlador TCP/IP. Problemas de red o software de seguridad."
        "ntfs.sys" = "Sistema de archivos NTFS. Corrupción del sistema de archivos."
        "usbhub.sys" = "Controlador USB. Problemas con dispositivos USB."
    }
    
    foreach ($key in $commonDrivers.Keys) {
        $solucionesContent += "$key`r`n"
        $solucionesContent += "Causa común: $($commonDrivers[$key])`r`n`r`n"
    }
    
    $solucionesContent += "`r`n===== COMANDOS ÚTILES =====`r`n`r`n"
    $solucionesContent += "• sfc /scannow`r`nVerifica y repara archivos del sistema Windows.`r`n`r`n"
    $solucionesContent += "• DISM /Online /Cleanup-Image /RestoreHealth`r`nRepara la imagen del sistema operativo Windows.`r`n`r`n"
    $solucionesContent += "• chkdsk /f /r`r`nVerifica y repara errores en el disco duro.`r`n`r`n"
    $solucionesContent += "• mdsched.exe`r`nEjecuta la herramienta de diagnóstico de memoria Windows.`r`n`r`n"
    $solucionesContent += "• powercfg -energy`r`nGenerera un informe de consumo de energía que puede revelar problemas.`r`n`r`n"
    
    $solucionesContent += "`r`n===== BUSCAR AYUDA ADICIONAL =====`r`n`r`n"
    $solucionesContent += "Para errores no reconocidos, copie el código exacto y consulte:`r`n"
    $solucionesContent += "• Microsoft Copilot: https://copilot.cloud.microsoft/`r`n"
    $solucionesContent += "• Foros de Microsoft: https://answers.microsoft.com`r`n"
    $solucionesContent += "• BlueScreenView: Herramienta para analizar archivos de volcado`r`n"
    
    $solucionesText.Text = $solucionesContent

    # Botón exportar
    $exportButton = New-Object System.Windows.Forms.Button
    $exportButton.Location = New-Object System.Drawing.Point(10, 530)
    $exportButton.Size = New-Object System.Drawing.Size(120, 25)
    $exportButton.Text = "Exportar Informe"
    $exportButton.Add_Click({
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "Archivos de texto (*.txt)|*.txt"
        $saveDialog.Title = "Guardar informe BSOD"
        $saveDialog.FileName = "Informe_BSOD_$(Get-Date -Format 'yyyyMMdd').txt"
        
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $exportText = $resumenContent + "`r`n`r`n" + $eventosText.Text + "`r`n`r`n" + $solucionesText.Text
            [System.IO.File]::WriteAllText($saveDialog.FileName, $exportText)
            [System.Windows.Forms.MessageBox]::Show("Informe exportado correctamente a:`r`n$($saveDialog.FileName)", "Exportación Exitosa", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })
    $form.Controls.Add($exportButton)

    # Botón cerrar
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(665, 530)
    $closeButton.Size = New-Object System.Drawing.Size(110, 25)
    $closeButton.Text = "Cerrar"
    $closeButton.Add_Click({ $form.Close() })
    $form.Controls.Add($closeButton)

    # Mostrar el formulario
    $form.ShowDialog()
}

# Función principal
function Main {
    Write-Host "Analizando información de pantallas azules..." -ForegroundColor Cyan
    
    $bsodInfo = Get-BSODInfo
    $events = $bsodInfo.Events
    $dumpFiles = $bsodInfo.DumpFiles
    $problemDrivers = $bsodInfo.ProblemDrivers
    
    # Mostrar la interfaz gráfica con la información
    Show-BSODInfoGUI -Events $events -DumpFiles $dumpFiles -ProblemDrivers $problemDrivers
}

# Ejecutar el script
Main