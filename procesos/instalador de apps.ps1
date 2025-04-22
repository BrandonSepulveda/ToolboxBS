#Requires -RunAsAdministrator

<#
.SYNOPSIS
Instalador/Desinstalador/Actualizador de aplicaciones con GUI usando Winget o Chocolatey.

.DESCRIPTION
Interfaz gráfica para seleccionar aplicaciones de una lista predefinida.
Permite Instalar, Desinstalar (las de la lista) o Actualizar Todo
eligiendo entre Winget o Chocolatey (si ambos están instalados).
Muestra logs detallados con colores en un cuadro de estado ubicado abajo.

.NOTES
Autor: Gemini (adaptado de solicitud)
Fecha: 2025-04-22 (Hora Colombia)
Requiere: PowerShell 5.1+, Windows 10/11 con Winget, Ejecución como Administrador.
Opcional: Chocolatey (choco.org).
La interfaz puede congelarse durante operaciones largas de winget/choco.
Desinstalar solo aplica a las apps de esta lista con el ID del gestor seleccionado.
Debes verificar/completar los 'ChocolateyID' en la lista.
#>

#region Pre-requisitos y Configuración Inicial
Write-Host "Iniciando Asistente de Aplicaciones TOOLBOXBS..."

# Cargar Ensamblado de Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Colores para el Log
$LogColorInfo = [System.Drawing.Color]::FromArgb(255, 0, 120, 215) # Azul tipo Windows
$LogColorSuccess = [System.Drawing.Color]::FromArgb(255, 16, 124, 16) # Verde oscuro
$LogColorWarning = [System.Drawing.Color]::FromArgb(255, 196, 128, 10) # Naranja/Ámbar
$LogColorError = [System.Drawing.Color]::FromArgb(255, 190, 30, 45) # Rojo oscuro
$LogColorDefault = [System.Drawing.Color]::FromArgb(255, 50, 50, 50) # Gris oscuro (texto normal)
$LogSeparator = "-------------------------------------------------------------"

# Verificar gestores de paquetes
$WingetFound = $false
$ChocolateyFound = $false

Write-Host "Verificando Winget..."
try {
    winget --version | Out-Null
    Write-Host "Winget encontrado." -ForegroundColor Green
    $WingetFound = $true
}
catch {
    Write-Host "Winget no encontrado o no funciona." -ForegroundColor Red
}

Write-Host "Verificando Chocolatey..."
try {
    choco --version | Out-Null
    Write-Host "Chocolatey encontrado." -ForegroundColor Green
    $ChocolateyFound = $true
}
catch {
    Write-Host "Chocolatey no encontrado o no funciona." -ForegroundColor Red
}

if (-not $WingetFound -and -not $ChocolateyFound) {
    [System.Windows.Forms.MessageBox]::Show("No se encontró Winget ni Chocolatey. Necesitas al menos uno instalado para usar esta herramienta.", "Error: Gestor no encontrado", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    Exit
}

#endregion

#region Definición de Aplicaciones (Nombre para Mostrar, ID de Winget, ID de Chocolatey)
# NOTA: Debes verificar y completar los 'ChocolateyID' según lo necesites.
# Si una app no tiene ID para un gestor, deja la propiedad con valor '' o $null.
$appList = @(
    @{ Nombre = "7-Zip"; WingetID = "7zip.7zip"; ChocolateyID = "7zip" }
    @{ Nombre = "AIDA64 Extreme (Trial)"; WingetID = "FinalWire.AIDA64.Extreme"; ChocolateyID = "" } # Posiblemente no en Choco público
    @{ Nombre = "AnyDesk"; WingetID = "AnyDeskSoftwareGmbH.AnyDesk"; ChocolateyID = "anydesk" }
    @{ Nombre = "Brave Browser"; WingetID = "BraveSoftware.BraveBrowser"; ChocolateyID = "brave" }
    @{ Nombre = "CPU-Z"; WingetID = "CPUID.CPU-Z"; ChocolateyID = "cpu-z" }
    @{ Nombre = "CrystalDiskInfo"; WingetID = "CrystalDewWorld.CrystalDiskInfo"; ChocolateyID = "crystaldiskinfo" }
    @{ Nombre = "Dell Command | Update"; WingetID = "Dell.CommandUpdate"; ChocolateyID = "" } # Específico de Dell
    @{ Nombre = "Discord"; WingetID = "Discord.Discord"; ChocolateyID = "discord" }
    @{ Nombre = "Google Chrome"; WingetID = "Google.Chrome"; ChocolateyID = "googlechrome" }
    @{ Nombre = "Hard Disk Sentinel"; WingetID = "JanosMathe.HardDiskSentinel"; ChocolateyID = "" } # Específico de HP
    @{ Nombre = "HP PC Hardware Diagnostics Windows"; WingetID = "HP.PCHardwareDiagnosticsWindows"; ChocolateyID = "" } # Específico de HP
    @{ Nombre = "HP Image Assistant"; WingetID = "HP.ImageAssistant"; ChocolateyID = "" } # Específico de HP
    @{ Nombre = "HP Smart"; WingetID = "9WZDNCRFHWLH"; ChocolateyID = "" } # App Store (normalmente no en Choco)
    @{ Nombre = "HP Support Assistant"; WingetID = "HP.SupportAssistant"; ChocolateyID = "" } # Específico de HP
    @{ Nombre = "Intel Driver & Support Assistant"; WingetID = "Intel.IntelDriverAndSupportAssistant"; ChocolateyID = "" } # Específico de Intel
    @{ Nombre = "Lenovo Vantage"; WingetID = "9WZDNCRFJ4MV"; ChocolateyID = "" } # App Store (normalmente no en Choco)
    @{ Nombre = "Lenovo System Update"; WingetID = "Lenovo.SystemUpdate"; ChocolateyID = "" } # Específico de Lenovo
    @{ Nombre = "Microsoft PowerToys"; WingetID = "Microsoft.PowerToys"; ChocolateyID = "powertoys" }
    @{ Nombre = "MyASUS"; WingetID = "9N7R5S6B0ZZH"; ChocolateyID = "" } # App Store (normalmente no en Choco)
    @{ Nombre = "Notepad++"; WingetID = "Notepad++.Notepad++"; ChocolateyID = "notepadplusplus" }
    @{ Nombre = "NZXT CAM"; WingetID = "NZXT.CAM"; ChocolateyID = "" } # Menos común en Choco
    @{ Nombre = "PowerShell (Latest)"; WingetID = "Microsoft.PowerShell"; ChocolateyID = "powershell" }
    @{ Nombre = "Rufus"; WingetID = "Rufus.Rufus"; ChocolateyID = "rufus" }
    @{ Nombre = "UnigetUI"; WingetID = "MartiCliment.UniGetU"; ChocolateyID = "wingetui" }
    @{ Nombre = "TeamViewer"; WingetID = "TeamViewer.TeamViewer"; ChocolateyID = "teamviewer" }
    @{ Nombre = "Ventoy"; WingetID = "Ventoy.Ventoy"; ChocolateyID = "ventoy" }
    @{ Nombre = "Visual Studio Code"; WingetID = "Microsoft.VisualStudioCode"; ChocolateyID = "vscode" }
    @{ Nombre = "WhatsApp Desktop"; WingetID = "WhatsApp.WhatsApp"; ChocolateyID = "whatsapp" }
    @{ Nombre = "Windows Terminal"; WingetID = "Microsoft.WindowsTerminal"; ChocolateyID = "windowsterminal" }
)
#endregion

#region Creación de la Interfaz Gráfica (GUI)

$form = New-Object System.Windows.Forms.Form
$form.Text = "ToolboxAPPS"
$form.Size = New-Object System.Drawing.Size(620, 740) # Aumentar altura para el log fijo
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::white

# CORRECCIÓN: Suspender el layout durante la creación de controles
$form.SuspendLayout() # Iniciar suspensión

# Posiciones Y Base
$startY = 15
$spacing = 10 # Espacio entre controles principales

# Label Selección de Apps
$labelApps = New-Object System.Windows.Forms.Label
$labelApps.Location = New-Object System.Drawing.Point(15, $startY)
$labelApps.Size = New-Object System.Drawing.Size(580, 20)
$labelApps.Text = "Selecciona las aplicaciones de la lista:"
$labelApps.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelApps)

$currentY = $labelApps.Bottom + $spacing

# --- Selección del Gestor ---
$labelManager = New-Object System.Windows.Forms.Label
$labelManager.Location = New-Object System.Drawing.Point(15, $currentY)
$labelManager.Size = New-Object System.Drawing.Size(180, 20)
$labelManager.Text = "Selecciona el gestor:"
$labelManager.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelManager)

$wingetRadioButton = New-Object System.Windows.Forms.RadioButton
$wingetRadioButton.Location = New-Object System.Drawing.Point(200, $currentY)
$wingetRadioButton.Size = New-Object System.Drawing.Size(100, 20)
$wingetRadioButton.Text = "Winget"
$wingetRadioButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$wingetRadioButton.Checked = $WingetFound # Seleccionar por defecto si está disponible
$wingetRadioButton.Enabled = $WingetFound # Deshabilitar si no se encontró
$form.Controls.Add($wingetRadioButton)

$chocolateyRadioButton = New-Object System.Windows.Forms.RadioButton
$chocolateyRadioButton.Location = New-Object System.Drawing.Point(300, $currentY)
$chocolateyRadioButton.Size = New-Object System.Drawing.Size(120, 20)
$chocolateyRadioButton.Text = "Chocolatey"
$chocolateyRadioButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$chocolateyRadioButton.Checked = (-not $WingetFound -and $ChocolateyFound) # Seleccionar si Winget no está y Choco sí
$chocolateyRadioButton.Enabled = $ChocolateyFound # Deshabilitar si no se encontró
$form.Controls.Add($chocolateyRadioButton)

# Si ninguno está disponible, el mensaje de error ya salió y el script debería haber terminado.
# Si solo uno está disponible, se selecciona automáticamente y el otro se deshabilita.
# Si ambos están disponibles, Winget es el predeterminado.

$currentY = $labelManager.Bottom + $spacing

# --- Lista de Aplicaciones ---
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(15, $currentY)
$checkedListBox.Size = New-Object System.Drawing.Size(580, 260) # Altura
$checkedListBox.CheckOnClick = $true
$checkedListBox.BorderStyle = 'FixedSingle'
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
# Poblar la lista
$appList.Nombre | ForEach-Object { $checkedListBox.Items.Add($_, $false) } | Out-Null
$form.Controls.Add($checkedListBox)

$currentY = $checkedListBox.Bottom + $spacing

# --- Botones ---
$buttonHeight = 35 # Altura de botones
$buttonWidth = ($form.ClientSize.Width - 30 - $spacing * 2) / 3 # Distribuir horizontalmente
$installButtonX = 15
$uninstallButtonX = $installButtonX + $buttonWidth + $spacing
$updateAllButtonX = $uninstallButtonX + $buttonWidth + $spacing

$installButton = New-Object System.Windows.Forms.Button
$installButton.Location = New-Object System.Drawing.Point($installButtonX, $currentY)
$installButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$installButton.Text = "Instalar Seleccionadas"
$installButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$installButton.BackColor = $LogColorSuccess # Verde
$installButton.ForeColor = [System.Drawing.Color]::White
$installButton.FlatStyle = 'Flat' # Estilo más plano
$installButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($installButton)

$uninstallButton = New-Object System.Windows.Forms.Button
$uninstallButton.Location = New-Object System.Drawing.Point($uninstallButtonX, $currentY)
$uninstallButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$uninstallButton.Text = "Desinstalar Seleccionadas"
$uninstallButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$uninstallButton.BackColor = $LogColorError # Rojo
$uninstallButton.ForeColor = [System.Drawing.Color]::black
$uninstallButton.FlatStyle = 'Flat'
$uninstallButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($uninstallButton)

$updateAllButton = New-Object System.Windows.Forms.Button
$updateAllButton.Location = New-Object System.Drawing.Point($updateAllButtonX, $currentY)
$updateAllButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$updateAllButton.Text = "Actualizar Todo" # Texto genérico
$updateAllButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$updateAllButton.BackColor = $LogColorInfo # Azul
$updateAllButton.ForeColor = [System.Drawing.Color]::White
$updateAllButton.FlatStyle = 'Flat'
$updateAllButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($updateAllButton)

$currentY = $currentY + $buttonHeight + $spacing

# --- Cuadro de Log Mejorado (ABAJO) ---
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(15, $currentY)
$statusLabel.Size = New-Object System.Drawing.Size(150, 20)
$statusLabel.Text = "Registro de actividad:"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusLabel)

$currentY = $statusLabel.Bottom + 5 # Pequeño espacio

$statusBox = New-Object System.Windows.Forms.RichTextBox
$statusBox.Location = New-Object System.Drawing.Point(15, $currentY)

# CORRECCIÓN: Asignar un tamaño fijo en lugar de calcular dinámicamente
# Esto elimina la línea que causaba el error op_Subtraction.
$statusBox.Size = New-Object System.Drawing.Size(580, 200) # Altura fija de 200px

$statusBox.ReadOnly = $true
$statusBox.BorderStyle = 'FixedSingle'
$statusBox.ScrollBars = 'Vertical'
$statusBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$statusBox.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 250, 250) # Fondo ligeramente diferente

# CORRECCIÓN: Añadir Anchoring para que se fije a la parte inferior y los lados (mantiene posición)
$statusBox.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$form.Controls.Add($statusBox)

$form.ResumeLayout() # Finalizar suspensión

# Función para añadir texto al Status Box con colores
function Add-Log {
    param(
        [string]$Message,
        [System.Drawing.Color]$Color = $LogColorDefault,
        [bool]$AddSeparatorBefore = $false,
        [bool]$AddSeparatorAfter = $false
    )

    # Acceso directo a propiedades del Status Box (sin Invoke, ya que estamos en el hilo UI principal)

    if ($AddSeparatorBefore) {
        $statusBox.SelectionStart = $statusBox.TextLength
        $statusBox.SelectionLength = 0
        $statusBox.SelectionColor = [System.Drawing.Color]::Gray # Color del separador
        $statusBox.AppendText("$LogSeparator`n")
    }

    $statusBox.SelectionStart = $statusBox.TextLength
    $statusBox.SelectionLength = 0
    $statusBox.SelectionColor = $Color
    $statusBox.AppendText("$(Get-Date -Format 'HH:mm:ss') - $Message`n")

    if ($AddSeparatorAfter) {
        $statusBox.SelectionStart = $statusBox.TextLength
        $statusBox.SelectionLength = 0
        $statusBox.SelectionColor = [System.Drawing.Color]::Gray
        $statusBox.AppendText("$LogSeparator`n")
    }

    $statusBox.SelectionStart = $statusBox.TextLength # Mover cursor al final
    $statusBox.ScrollToCaret() # Auto-scroll

    # Sigue siendo buena práctica procesar eventos para mantener la UI un poco responsiva
    [System.Windows.Forms.Application]::DoEvents()
}

# Función para habilitar/deshabilitar botones y radios
function Set-ControlsEnabled {
    param([bool]$Enabled)
    $installButton.Enabled = $Enabled
    $uninstallButton.Enabled = $Enabled
    $updateAllButton.Enabled = $Enabled
    $wingetRadioButton.Enabled = $Enabled -and $WingetFound
    $chocolateyRadioButton.Enabled = $Enabled -and $ChocolateyFound
    $checkedListBox.Enabled = $Enabled
}

#endregion

#region Lógica de los Botones

# --- INSTALAR ---
$installButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de INSTALACIÓN..." -Color $LogColorInfo -AddSeparatorBefore $true

    $selectedItems = $checkedListBox.CheckedItems
    if ($selectedItems.Count -eq 0) {
        Add-Log "No hay aplicaciones seleccionadas para instalar." -Color $LogColorWarning
        Add-Log "Instalación cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
        Set-ControlsEnabled $true
        return
    }

    $useWinget = $wingetRadioButton.Checked
    $useChocolatey = $chocolateyRadioButton.Checked
    $packageManager = if ($useWinget) {"Winget"} elseif ($useChocolatey) {"Chocolatey"} else {"Desconocido"}
    Add-Log "Usando gestor: $packageManager"

    foreach ($appName in $selectedItems) {
        $appInfo = $appList | Where-Object { $_.Nombre -eq $appName }
        if ($appInfo) {
            $appID = if ($useWinget) {$appInfo.WingetID} elseif ($useChocolatey) {$appInfo.ChocolateyID} else {$null}

            if (-not $appID) {
                Add-Log "ADVERTENCIA: La app '$appName' no tiene ID definido para $packageManager." -Color $LogColorWarning
                continue
            }

            Add-Log "Instalando $($appInfo.Nombre) (ID: $($appID)) usando $packageManager... Espera." -Color $LogColorDefault

            $command = if ($useWinget) {"winget"} elseif ($useChocolatey) {"choco"} else {$null}
            $arguments = if ($useWinget) {"install --id $($appID) -e --silent --accept-package-agreements --accept-source-agreements"} elseif ($useChocolatey) {"install $($appID) -y --no-progress --confirm"} else {$null} # -y for yes, --no-progress to simplify output

            if ($command -and $arguments) {
                try {
                    $outFile = New-TemporaryFile
                    $errFile = New-TemporaryFile
                    $process = Start-Process -FilePath $command -ArgumentList $arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outFile.FullName -RedirectStandardError $errFile.FullName
                    $output = Get-Content $outFile.FullName -Raw -ErrorAction SilentlyContinue
                    $errors = Get-Content $errFile.FullName -Raw -ErrorAction SilentlyContinue
                    Remove-Item $outFile.FullName, $errFile.FullName -Force -ErrorAction SilentlyContinue

                    if ($process.ExitCode -eq 0) {
                        Add-Log "ÉXITO: $($appInfo.Nombre) instalado." -Color $LogColorSuccess
                        # if ($output) { Add-Log "Salida $packageManager:`n$output" -Color $LogColorDefault } # Opcional: mostrar salida completa si quieres
                    } else {
                        Add-Log "ERROR ($packageManager): Instalando $($appInfo.Nombre). Código: $($process.ExitCode)." -Color $LogColorError
                        if ($errors) { Add-Log "Detalles Error:`n$errors" -Color $LogColorError }
                        elseif ($output) { Add-Log "Salida $packageManager (puede contener error):`n$output" -Color $LogColorWarning }
                        Add-Log "NOTA: Algunas instalaciones pueden requerir interacción manual." -Color $LogColorWarning
                    }
                } catch {
                    Add-Log "EXCEPCIÓN ($packageManager) instalando $($appInfo.Nombre): $($_.Exception.Message)" -Color $LogColorError
                }
            }
        } else {
            Add-Log "ADVERTENCIA: No se encontró info para '$appName' en la lista." -Color $LogColorWarning
        }
    }

    Add-Log "Proceso de INSTALACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})

# --- DESINSTALAR ---
$uninstallButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de DESINSTALACIÓN..." -Color $LogColorInfo -AddSeparatorBefore $true

    $selectedItems = $checkedListBox.CheckedItems
    if ($selectedItems.Count -eq 0) {
        Add-Log "No hay aplicaciones seleccionadas para desinstalar." -Color $LogColorWarning
        Add-Log "Desinstalación cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
        Set-ControlsEnabled $true
        return
    }

    $useWinget = $wingetRadioButton.Checked
    $useChocolatey = $chocolateyRadioButton.Checked
    $packageManager = if ($useWinget) {"Winget"} elseif ($useChocolatey) {"Chocolatey"} else {"Desconocido"}
    Add-Log "Usando gestor: $packageManager"

    foreach ($appName in $selectedItems) {
        $appInfo = $appList | Where-Object { $_.Nombre -eq $appName }
        if ($appInfo) {
            $appID = if ($useWinget) {$appInfo.WingetID} elseif ($useChocolatey) {$appInfo.ChocolateyID} else {$null}

            if (-not $appID) {
                Add-Log "ADVERTENCIA: La app '$appName' no tiene ID definido para $packageManager." -Color $LogColorWarning
                continue
            }

            Add-Log "Desinstalando $($appInfo.Nombre) (ID: $($appID)) usando $packageManager... Espera." -Color $LogColorDefault

            $command = if ($useWinget) {"winget"} elseif ($useChocolatey) {"choco"} else {$null}
            $arguments = if ($useWinget) {"uninstall --id $($appID) -e --silent --accept-source-agreements"} elseif ($useChocolatey) {"uninstall $($appID) -y --no-progress --confirm"} else {$null}

            if ($command -and $arguments) {
                try {
                    $outFile = New-TemporaryFile
                    $errFile = New-TemporaryFile
                    $process = Start-Process -FilePath $command -ArgumentList $arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outFile.FullName -RedirectStandardError $errFile.FullName
                    $output = Get-Content $outFile.FullName -Raw -ErrorAction SilentlyContinue
                    $errors = Get-Content $errFile.FullName -Raw -ErrorAction SilentlyContinue
                    Remove-Item $outFile.FullName, $errFile.FullName -Force -ErrorAction SilentlyContinue

                    if ($process.ExitCode -eq 0) {
                        Add-Log "ÉXITO: $($appInfo.Nombre) desinstalado (o no estaba instalado)." -Color $LogColorSuccess
                        # if ($output) { Add-Log "Salida $packageManager:`n$output" -Color $LogColorDefault }
                    } else {
                        Add-Log "ERROR ($packageManager): Desinstalando $($appInfo.Nombre). Código: $($process.ExitCode)." -Color $LogColorError
                        if ($errors) { Add-Log "Detalles Error:`n$errors" -Color $LogColorError }
                        elseif ($output) { Add-Log "Salida $packageManager (puede contener error):`n$output" -Color $LogColorWarning }
                        Add-Log "NOTA: Algunos desinstaladores ignoran el modo silencioso." -Color $LogColorWarning
                    }
                } catch {
                    Add-Log "EXCEPCIÓN ($packageManager) desinstalando $($appInfo.Nombre): $($_.Exception.Message)" -Color $LogColorError
                }
            }
        } else {
            Add-Log "ADVERTENCIA: No se encontró info para '$appName' en la lista." -Color $LogColorWarning
        }
    }

    Add-Log "Proceso de DESINSTALACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})

# --- ACTUALIZAR TODO ---
$updateAllButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de ACTUALIZACIÓN de todo..." -Color $LogColorInfo -AddSeparatorBefore $true

    $useWinget = $wingetRadioButton.Checked
    $useChocolatey = $chocolateyRadioButton.Checked
    $packageManager = if ($useWinget) {"Winget"} elseif ($useChocolatey) {"Chocolatey"} else {"Desconocido"}

    if ($useWinget -and -not $WingetFound) {
        Add-Log "ERROR: Winget no encontrado. No se puede actualizar con Winget." -Color $LogColorError
        Add-Log "Actualización cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
        Set-ControlsEnabled $true
        return
    }

    if ($useChocolatey -and -not $ChocolateyFound) {
        Add-Log "ERROR: Chocolatey no encontrado. No se puede actualizar con Chocolatey." -Color $LogColorError
        Add-Log "Actualización cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
        Set-ControlsEnabled $true
        return
    }

    Add-Log "Usando gestor para actualizar todo: $packageManager"

    $command = if ($useWinget) {"winget"} elseif ($useChocolatey) {"choco"} else {$null}
    $arguments = if ($useWinget) {"upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements"} elseif ($useChocolatey) {"upgrade all -y --no-progress --confirm"} else {$null}

    if ($command -and $arguments) {
        try {
            Add-Log "Ejecutando '$command $arguments'... Puede tardar." -Color $LogColorDefault
            $outFile = New-TemporaryFile
            $errFile = New-TemporaryFile
            $process = Start-Process -FilePath $command -ArgumentList $arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outFile.FullName -RedirectStandardError $errFile.FullName
            $output = Get-Content $outFile.FullName -Raw -ErrorAction SilentlyContinue
            $errors = Get-Content $errFile.FullName -Raw -ErrorAction SilentlyContinue
            Remove-Item $outFile.FullName, $errFile.FullName -Force -ErrorAction SilentlyContinue

            if ($process.ExitCode -eq 0) {
                Add-Log "ÉXITO: Actualización completada por $packageManager (o no había nada que actualizar)." -Color $LogColorSuccess
                if ($output -and $output -notmatch "No applicable update found|No se encontraron actualizaciones aplicables|Nothing to upgrade") { Add-Log "Salida ${packageManager}`n$output" -Color $LogColorDefault }
                elseif ($output) { Add-Log "${packageManager}: No se encontraron actualizaciones." -Color $LogColorDefault}
            } else {
                Add-Log "ERROR ($packageManager): Durante la actualización. Código: $($process.ExitCode)." -Color $LogColorError
                if ($errors) { Add-Log "Detalles Error:`n$errors" -Color $LogColorError }
                elseif ($output) { Add-Log "Salida ${packageManager} (puede contener error):`n$output" -Color $LogColorWarning }
            }
        } catch {
            Add-Log "EXCEPCIÓN al ejecutar '$command $arguments': $($_.Exception.Message)" -Color $LogColorError
        }
    } else {
        Add-Log "ERROR: No se pudo determinar el comando para actualizar todo con el gestor seleccionado." -Color $LogColorError
    }

    Add-Log "Proceso de ACTUALIZACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})

#endregion

#region Mostrar la Ventana
$form.Add_Shown({ $form.Activate() })
Add-Log "ToolboxAPPS listo. Selecciona apps, elige el gestor y usa los botones." -Color $LogColorDefault
# Limpiar selección inicial
for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) { $checkedListBox.SetItemChecked($i, $false) }
[void]$form.ShowDialog() # Muestra la ventana y espera a que se cierre
#endregion

Write-Host "Cerrando Asistente de Aplicaciones."