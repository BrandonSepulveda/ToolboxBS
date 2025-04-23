#Requires -RunAsAdministrator

<#
.SYNOPSIS
Instalador/Desinstalador/Actualizador de aplicaciones con GUI usando Winget o Chocolatey, con buscador.

.DESCRIPTION
Interfaz gráfica para seleccionar aplicaciones de una lista predefinida, con la capacidad de buscar.
Permite Instalar, Desinstalar (las de la lista) o Actualizar Todo
eligiendo entre Winget o Chocolatey (si ambos están instalados).
Si Winget o Chocolatey no están instalados, el script intentará instalarlos.
Muestra logs detallados con colores en un cuadro de estado ubicado abajo.

.NOTES
Autor: Gemini (adaptado de solicitud)
Fecha: 2025-04-22 (Hora Colombia)
Requiere: PowerShell 5.1+, Windows 10/11. Ejecución como Administrador.
Intenta instalar Winget (si no está) desde aka.ms/getwinget.
Intenta instalar Chocolatey (si no está) desde chocolatey.org.
La interfaz puede congelarse durante operaciones largas de winget/choco.
Desinstalar solo aplica a las apps de esta lista con el ID del gestor seleccionado.
Debes verificar/completar los 'ChocolateyID' en la lista.
El buscador filtra la lista visible, pero no mantiene el estado de selección de las apps ocultas.
Corregido error "Cannot find an overload for Point/Size" usando el método ::new().
#>

#region Pre-requisitos y Configuración Inicial
Write-Host "Iniciando Asistente de Aplicaciones TOOLBOXBS..." -ForegroundColor DarkGray

# Cargar Ensamblado de Windows Forms
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Write-Host "Ensamblados de GUI cargados correctamente." -ForegroundColor Green
}
catch {
    Write-Host "ERROR FATAL: No se pudieron cargar los ensamblados de System.Windows.Forms o System.Drawing. Asegúrate de ejecutar esto en una versión de PowerShell con soporte para GUI (no PowerShell Core sin módulos de compatibilidad)." -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show("Error fatal: No se pudieron cargar los componentes de la interfaz gráfica. Asegúrate de ejecutar este script en un entorno de PowerShell que soporte Windows Forms.", "Error de Carga de GUI", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    Exit
}


# Colores para el Log (Estos se usarán después de que la GUI esté lista)
$LogColorInfo = [System.Drawing.Color]::FromArgb(255, 0, 120, 215) # Azul tipo Windows
$LogColorSuccess = [System.Drawing.Color]::FromArgb(255, 16, 124, 16) # Verde oscuro
$LogColorWarning = [System.Drawing.Color]::FromArgb(255, 196, 128, 10) # Naranja/Ámbar
$LogColorError = [System.Drawing.Color]::FromArgb(255, 190, 30, 45) # Rojo oscuro
$LogColorDefault = [System.Drawing.Color]::FromArgb(255, 50, 50, 50) # Gris oscuro (texto normal)
$LogSeparator = "-------------------------------------------------------------"


Write-Host "Verificando y/o instalando gestores de paquetes..." -ForegroundColor DarkGray

# --- Initial Check ---
$WingetFound = $false
$ChocolateyFound = $false

Write-Host "Verificando Winget..." -ForegroundColor Gray
try {
    winget --version | Out-Null
    Write-Host "Winget encontrado." -ForegroundColor Green
    $WingetFound = $true
}
catch {
    Write-Host "Winget no encontrado o no funciona." -ForegroundColor Yellow
}

Write-Host "Verificando Chocolatey..." -ForegroundColor Gray
try {
    choco --version | Out-Null
    Write-Host "Chocolatey encontrado." -ForegroundColor Green
    $ChocolateyFound = $true
}
catch {
    Write-Host "Chocolatey no encontrado o no funciona." -ForegroundColor Yellow
}

# --- Installation Logic if not found ---

# Winget Installation Attempt
if (-not $WingetFound) {
    Write-Host "Intentando instalar Winget..." -ForegroundColor Cyan
    try {
        # Using the standard aka.ms link to the latest MSIX bundle
        $wingetDownloadUrl = "https://aka.ms/getwinget"
        $wingetInstallerPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"

        Write-Host "Descargando instalador de Winget..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $wingetDownloadUrl -OutFile $wingetInstallerPath -UseBasicParsing -ErrorAction Stop

        Write-Host "Instalando Winget (puede no mostrar progreso)..." -ForegroundColor Cyan
        # Add-AppxPackage can be silent and doesn't need Start-Process
        Add-AppxPackage -Path $wingetInstallerPath -ForceApplicationShutdown -ErrorAction Stop

        Write-Host "Instalación de Winget completada. Verificando de nuevo..." -ForegroundColor Green
        # Re-check
        Start-Sleep -Seconds 2 # Give it a moment
        try {
            winget --version | Out-Null
            Write-Host "Winget encontrado después de la instalación." -ForegroundColor Green
            $WingetFound = $true
        }
        catch {
            Write-Host "Winget NO encontrado después de la instalación." -ForegroundColor Red
        }
        Remove-Item $wingetInstallerPath -Force -ErrorAction SilentlyContinue # Clean up

    }
    catch {
        Write-Host "ERROR: Falló la instalación automática de Winget: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Por favor, instala Winget manualmente desde la Microsoft Store ('Instalador de Aplicaciones') o https://aka.ms/getwinget si no continuas." -ForegroundColor Yellow
    }
}

# Chocolatey Installation Attempt
if (-not $ChocolateyFound) {
    Write-Host "Intentando instalar Chocolatey..." -ForegroundColor Cyan
    try {
        # Standard Chocolatey installation command
        # Use Process scope for Execution Policy change - temporary for this session
        $originalExecutionPolicy = Get-ExecutionPolicy -Scope Process
        $needsPolicyChange = $false
        if ($originalExecutionPolicy -ne 'Bypass' -and $originalExecutionPolicy -ne 'Unrestricted') {
             Write-Host "Configurando Execution Policy a Bypass para la instalación de Chocolatey (temporalmente)..." -ForegroundColor Cyan
             Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
             $needsPolicyChange = $true
        }

        Write-Host "Ejecutando script de instalación de Chocolatey..." -ForegroundColor Cyan
        # Use Invoke-Expression (iex) which runs in the current scope
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 # For TLS 1.2
        $chocoInstallScript = ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        iex $chocoInstallScript # Execute the downloaded script

        Write-Host "Instalación de Chocolatey completada (verifica la salida de choco.org arriba si hubo errores)." -ForegroundColor Green
        # Re-check
        Start-Sleep -Seconds 2 # Give it a moment
        try {
            choco --version | Out-Null
            Write-Host "Chocolatey encontrado después de la instalación." -ForegroundColor Green
            $ChocolateyFound = $true
        }
        catch {
            Write-Host "Chocolatey NO encontrado después de la instalación." -ForegroundColor Red
        }

    }
    catch {
        Write-Host "ERROR: Falló la instalación automática de Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Por favor, instala Chocolatey manualmente siguiendo las instrucciones en https://chocolatey.org/install si no continuas." -ForegroundColor Yellow
    }
    finally {
         # Restore Execution Policy if it was changed, even on error
        if ($needsPolicyChange) {
             Write-Host "Restaurando Execution Policy a $originalExecutionPolicy..." -ForegroundColor Cyan
             Set-ExecutionPolicy $originalExecutionPolicy -Scope Process -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Final Check after installation attempts ---
if (-not $WingetFound -and -not $ChocolateyFound) {
    Write-Host "FATAL: No se encontró Winget ni Chocolatey después de intentar instalarlos. Necesitas al menos uno para usar esta herramienta." -ForegroundColor Red
    # GUI is not fully set up, use MessageBox
    [System.Windows.Forms.MessageBox]::Show("No se encontró Winget ni Chocolatey después de intentar instalarlos. Necesitas al menos uno para usar esta herramienta.", "Error Fatal: Gestor no encontrado", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    Exit
}

Write-Host "Continuando con la interfaz gráfica..." -ForegroundColor DarkGray

#region Compatibilidad - New-TemporaryFile
# Define New-TemporaryFile for compatibility with Windows PowerShell 5.1
if (-not (Get-Command New-TemporaryFile -ErrorAction SilentlyContinue)) {
    function New-TemporaryFile {
        [CmdletBinding()]
        param()
        begin {
            $tempPath = [System.IO.Path]::GetTempPath()
        }
        process {
            $tempFileName = [System.IO.Path]::GetRandomFileName()
            $tempFilePath = Join-Path $tempPath $tempFileName
            try {
                # Ensure the file exists and return a FileInfo object
                New-Item -Path $tempFilePath -ItemType File -Force -ErrorAction Stop | Out-Null
                Get-Item -Path $tempFilePath
            } catch {
                Write-Error ("Failed to create temporary file at {0}: {1}" -f $tempFilePath, ${_}.Exception.Message)
                $null
            }
        }
    }
    Add-Log "Función 'New-TemporaryFile' definida para compatibilidad." -Color $LogColorInfo
}
#endregion
#endregion

#region Definición de Aplicaciones (Nombre para Mostrar, ID de Winget, ID de Chocolatey)
# ... (Keep the existing appList definition)
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
# ... (Keep the existing GUI definition)
$form = [System.Windows.Forms.Form]::new()
$form.Text = "ToolboxAPPS"
$form.Size = [System.Drawing.Size]::new(620, 740)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::white

$form.SuspendLayout()

$startY = 15
$spacing = 10
$controlHeight = 25

$labelApps = [System.Windows.Forms.Label]::new()
$labelApps.Location = [System.Drawing.Point]::new(15, $startY)
$labelApps.Size = [System.Drawing.Size]::new(580, $controlHeight)
$labelApps.Text = "Selecciona las aplicaciones de la lista:"
$labelApps.Font = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelApps)

$currentY = $labelApps.Bottom + $spacing

$labelSearch = [System.Windows.Forms.Label]::new()
$labelSearch.Location = [System.Drawing.Point]::new(15, $currentY + 5)
$labelSearch.Size = [System.Drawing.Size]::new(60, $controlHeight)
$labelSearch.Text = "Buscar:"
$labelSearch.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($labelSearch)

$searchTextBox = [System.Windows.Forms.TextBox]::new()
$searchTextBox.Location = [System.Drawing.Point]::new(80, $currentY)
$searchTextBox.Size = [System.Drawing.Size]::new(515, $controlHeight)
$searchTextBox.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$form.Controls.Add($searchTextBox)

$currentY = $searchTextBox.Bottom + $spacing

$labelManager = [System.Windows.Forms.Label]::new()
$labelManager.Location = [System.Drawing.Point]::new(15, $currentY)
$labelManager.Size = [System.Drawing.Size]::new(180, $controlHeight)
$labelManager.Text = "Selecciona el gestor:"
$labelManager.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelManager)

$wingetRadioButton = [System.Windows.Forms.RadioButton]::new()
$wingetRadioButton.Location = [System.Drawing.Point]::new(200, $currentY)
$wingetRadioButton.Size = [System.Drawing.Size]::new(100, $controlHeight)
$wingetRadioButton.Text = "Winget"
$wingetRadioButton.Font = [System.Drawing.Font]::new("Segoe UI", 9)
# Set Checked and Enabled based on the FINAL check results
$wingetRadioButton.Checked = $WingetFound # Select if available
$wingetRadioButton.Enabled = $WingetFound # Disable if not found
$form.Controls.Add($wingetRadioButton)

$chocolateyRadioButton = [System.Windows.Forms.RadioButton]::new()
$chocolateyRadioButton.Location = [System.Drawing.Point]::new(300, $currentY)
$chocolateyRadioButton.Size = [System.Drawing.Size]::new(120, $controlHeight)
$chocolateyRadioButton.Text = "Chocolatey"
$chocolateyRadioButton.Font = [System.Drawing.Font]::new("Segoe UI", 9)
# Set Checked and Enabled based on the FINAL check results
# If Winget is not found but Chocolatey is, default to Choco
$chocolateyRadioButton.Checked = (-not $WingetFound -and $ChocolateyFound)
$chocolateyRadioButton.Enabled = $ChocolateyFound # Disable if not found
$form.Controls.Add($chocolateyRadioButton)

# If both are found, Winget is checked by default due to the order. If only one is found, it will be checked and enabled, the other disabled.

$currentY = $labelManager.Bottom + $spacing

$checkedListBox = [System.Windows.Forms.CheckedListBox]::new()
$checkedListBox.Location = [System.Drawing.Point]::new(15, $currentY)
$checkedListBox.Size = [System.Drawing.Size]::new(580, 220)
$checkedListBox.CheckOnClick = $true
$checkedListBox.BorderStyle = 'FixedSingle'
$checkedListBox.Font = [System.Drawing.Font]::new("Segoe UI", 9)
# Populate the list (before filter)
$appList.Nombre | ForEach-Object { $checkedListBox.Items.Add($_, $false) } | Out-Null
$form.Controls.Add($checkedListBox)

$currentY = $checkedListBox.Bottom + $spacing

$buttonHeight = 35
$buttonWidth = ($form.ClientSize.Width - 30 - $spacing * 2) / 3
$installButtonX = 15
$uninstallButtonX = $installButtonX + $buttonWidth + $spacing
$updateAllButtonX = $uninstallButtonX + $buttonWidth + $spacing

$installButton = [System.Windows.Forms.Button]::new()
$installButton.Location = [System.Drawing.Point]::new($installButtonX, $currentY)
$installButton.Size = [System.Drawing.Size]::new($buttonWidth, $buttonHeight)
$installButton.Text = "Instalar Seleccionadas"
$installButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$installButton.BackColor = $LogColorSuccess # Verde
$installButton.ForeColor = [System.Drawing.Color]::White
$installButton.FlatStyle = 'Flat'
$installButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($installButton)

$uninstallButton = [System.Windows.Forms.Button]::new()
$uninstallButton.Location = [System.Drawing.Point]::new($uninstallButtonX, $currentY)
$uninstallButton.Size = [System.Drawing.Size]::new($buttonWidth, $buttonHeight)
$uninstallButton.Text = "Desinstalar Seleccionadas"
$uninstallButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$uninstallButton.BackColor = $LogColorError # Rojo
$uninstallButton.ForeColor = [System.Drawing.Color]::black # Texto negro para contraste
$uninstallButton.FlatStyle = 'Flat'
$uninstallButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($uninstallButton)

$updateAllButton = [System.Windows.Forms.Button]::new()
$updateAllButton.Location = [System.Drawing.Point]::new($updateAllButtonX, $currentY)
$updateAllButton.Size = [System.Drawing.Size]::new($buttonWidth, $buttonHeight)
$updateAllButton.Text = "Actualizar Todo"
$updateAllButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$updateAllButton.BackColor = $LogColorInfo # Azul
$updateAllButton.ForeColor = [System.Drawing.Color]::White
$updateAllButton.FlatStyle = 'Flat'
$updateAllButton.FlatAppearance.BorderSize = 0
$form.Controls.Add($updateAllButton)

$currentY = $currentY + $buttonHeight + $spacing

$statusLabel = [System.Windows.Forms.Label]::new()
$statusLabel.Location = [System.Drawing.Point]::new(15, $currentY)
$statusLabel.Size = [System.Drawing.Size]::new(150, $controlHeight)
$statusLabel.Text = "Registro de actividad:"
$statusLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusLabel)

$currentY = $statusLabel.Bottom + 5

$statusBox = [System.Windows.Forms.RichTextBox]::new()
$statusBox.Location = [System.Drawing.Point]::new(15, $currentY)
$statusBox.Size = [System.Drawing.Size]::new(580, 200)
$statusBox.ReadOnly = $true
$statusBox.BorderStyle = 'FixedSingle'
$statusBox.ScrollBars = 'Vertical'
$statusBox.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$statusBox.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 250, 250)

$statusBox.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$form.Controls.Add($statusBox)

$form.ResumeLayout() # Finalizar suspensión

# --- Function Definitions (Now that GUI controls exist) ---

# Function for adding text to Status Box with colors
function Add-Log {
    param(
        [string]$Message,
        [System.Drawing.Color]$Color = $LogColorDefault,
        [bool]$AddSeparatorBefore = $false,
        [bool]$AddSeparatorAfter = $false
    )

    # Access properties of the Status Box (defined in GUI region)

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

    # Process events to keep the UI somewhat responsive
    [System.Windows.Forms.Application]::DoEvents()
}

# Function to enable/disable controls
function Set-ControlsEnabled {
    param([bool]$Enabled)
    # Only enable radio buttons if the manager was actually found/installed
    $installButton.Enabled = $Enabled
    $uninstallButton.Enabled = $Enabled
    $updateAllButton.Enabled = $Enabled
    $wingetRadioButton.Enabled = $Enabled -and $WingetFound
    $chocolateyRadioButton.Enabled = $Enabled -and $ChocolateyFound
    $checkedListBox.Enabled = $Enabled
    $searchTextBox.Enabled = $Enabled
    [System.Windows.Forms.Application]::DoEvents() # Update UI
}

# Function to filter the list of applications
function Filter-AppList {
    $searchText = $searchTextBox.Text.Trim().ToLower()

    $checkedListBox.Items.Clear()

    $filteredList = $appList | Where-Object {
        if ($searchText -eq "") {
            $true
        }
        else {
            "$($_.Nombre.ToLower())" -like "*$searchText*"
        }
    }

    $filteredList | ForEach-Object {
        $checkedListBox.Items.Add($_.Nombre, $false) | Out-Null
    }

    [System.Windows.Forms.Application]::DoEvents()
}

#endregion

#region Lógica de los Botones y Eventos
# ... (Keep the existing event handlers, they call functions defined above)

# Connect the TextChanged event of the search box to the filter function
$searchTextBox.Add_TextChanged({
    Filter-AppList
})

# --- INSTALL ---
$installButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de INSTALACIÓN..." -Color $LogColorInfo -AddSeparatorBefore $true

    $selectedItems = $checkedListBox.CheckedItems | ForEach-Object { $_ }

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
            $arguments = if ($useWinget) {"install --id $($appID) -e --silent --accept-package-agreements --accept-source-agreements"} elseif ($useChocolatey) {"install $($appID) -y --no-progress --confirm"} else {$null}

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
            Add-Log "ADVERTENCIA: No se encontró info para '$appName' en la lista original (esto no debería pasar si se seleccionó de la lista)." -Color $LogColorWarning
        }
    }

    Add-Log "Proceso de INSTALACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})

# --- UNINSTALL ---
$uninstallButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de DESINSTALACIÓN..." -Color $LogColorInfo -AddSeparatorBefore $true

    $selectedItems = $checkedListBox.CheckedItems | ForEach-Object { $_ }

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
            Add-Log "ADVERTENCIA: No se encontró info para '$appName' en la lista original (esto no debería pasar si se seleccionó de la lista)." -Color $LogColorWarning
        }
    }

    Add-Log "Proceso de DESINSTALACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})

# --- UPDATE ALL ---
$updateAllButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de ACTUALIZACIÓN de todo..." -Color $LogColorInfo -AddSeparatorBefore $true

    $useWinget = $wingetRadioButton.Checked
    $useChocolatey = $chocolateyRadioButton.Checked
    $packageManager = if ($useWinget) {"Winget"} elseif ($useChocolatey) {"Chocolatey"} else {"Desconocido"}

    # Re-check if managers are still available before attempting update all
     if ($useWinget -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
         Add-Log "ERROR: Winget no encontrado o no funciona. No se puede actualizar con Winget." -Color $LogColorError
         Add-Log "Actualización cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
         Set-ControlsEnabled $true
         return
     }

     if ($useChocolatey -and -not (Get-Command choco -ErrorAction SilentlyContinue)) {
         Add-Log "ERROR: Chocolatey no encontrado o no funciona. No se puede actualizar con Chocolatey." -Color $LogColorError
         Add-Log "Actualización cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
         Set-ControlsEnabled $true
         return
     }

    Add-Log "Usando gestor para actualizar todo: $packageManager"

    $command = if ($useWinget) {"winget"} elseif ($useChocolatey) {"choco"} else {$null}
    $arguments = if ($useWinget) {"upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements"} elseif ($useChocolatey) {"upgrade all -y --no-progress --confirm"} else {$null}

    if ($command -and $arguments) {
        try {
            Add-Log "Ejecutando '$command $arguments'... Puede tardar varios minutos." -Color $LogColorDefault
            $outFile = New-TemporaryFile
            $errFile = New-TemporaryFile
            $process = Start-Process -FilePath $command -ArgumentList $arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outFile.FullName -RedirectStandardError $errFile.FullName
            $output = Get-Content $outFile.FullName -Raw -ErrorAction SilentlyContinue
            $errors = Get-Content $errFile.FullName -Raw -ErrorAction SilentlyContinue
            Remove-Item $outFile.FullName, $errFile.FullName -Force -ErrorAction SilentlyContinue

            if ($process.ExitCode -eq 0) {
                Add-Log "ÉXITO: Actualización completada por $packageManager (o no había nada que actualizar)." -Color $LogColorSuccess
                # Check output for signs of actual updates or no updates
                if ($output -and ($output -notmatch "No applicable update found|No se encontraron actualizaciones aplicables|Nothing to upgrade|0 packages upgraded")) { Add-Log "Salida ${packageManager}:`n$output" -Color $LogColorDefault }
                elseif ($output) { Add-Log "${packageManager}: No se encontraron actualizaciones." -Color $LogColorDefault}
                # Also check errors stream for non-fatal warnings
                if ($errors -and $errors -notmatch "Nothing to upgrade") { Add-Log "${packageManager} (Posibles advertencias):`n$errors" -Color $LogColorWarning }

            } else {
                Add-Log "ERROR ($packageManager): Durante la actualización. Código: $($process.ExitCode)." -Color $LogColorError
                if ($errors) { Add-Log "Detalles Error:`n$errors" -Color $LogColorError }
                elseif ($output) { Add-Log "Salida ${packageManager} (puede contener error/advertencia):`n$output" -Color $LogColorWarning }
                Add-Log "NOTA: Algunas actualizaciones pueden requerir interacción manual o fallar silenciosamente." -Color $LogColorWarning
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
$form.Add_Shown({
    # Add an initial message to the status box once it's visible
    Add-Log "ToolboxAPPS listo. Selecciona apps, elige el gestor y usa los botones." -Color $LogColorDefault
    # Ensure radio buttons are correctly enabled/checked based on initial check results
    $wingetRadioButton.Checked = $WingetFound
    $wingetRadioButton.Enabled = $WingetFound
    $chocolateyRadioButton.Checked = (-not $WingetFound -and $ChocolateyFound)
    $chocolateyRadioButton.Enabled = $ChocolateyFound
    # If both are found, Winget stays checked from initial setting.
    # If only one is found, that one is checked and enabled.
    # If none are found, script would have exited earlier.

    # Clean initial selection
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) { $checkedListBox.SetItemChecked($i, $false) }

    $form.Activate() # Bring form to foreground
})

[void]$form.ShowDialog() # Show the window and wait for it to close
#endregion

Write-Host "Cerrando Asistente de Aplicaciones." -ForegroundColor DarkGray
