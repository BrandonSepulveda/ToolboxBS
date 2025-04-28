#Requires -RunAsAdministrator

<#
.SYNOPSIS
Instalador/Desinstalador/Actualizador de aplicaciones con GUI usando Winget o Chocolatey, con buscador.

.DESCRIPTION
Interfaz gráfica moderna para seleccionar aplicaciones de una lista predefinida, con la capacidad de buscar.
Permite Instalar, Desinstalar (las de la lista) o Actualizar Todo
eligiendo entre Winget o Chocolatey (si ambos están instalados).
Si Winget o Chocolatey no están instalados, el script intentará instalarlos.
Muestra logs detallados con colores en un cuadro de estado ubicado abajo.

.NOTES
Autor: Brandon sepulveda
Fecha: 2025-04-24 (Hora Colombia)
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
# Cargar colores y tema principal 
$ThemePrimary = [System.Drawing.Color]::FromArgb(255, 0, 120, 215)     # Azul principal (original)
$ThemeSecondary = [System.Drawing.Color]::FromArgb(255, 16, 124, 16)   # Verde oscuro
$ThemeAccent = [System.Drawing.Color]::FromArgb(255, 243, 242, 241)    # Fondo claro
$ThemeDanger = [System.Drawing.Color]::FromArgb(255, 209, 52, 56)      # Rojo para acciones peligrosas
$ThemeWarning = [System.Drawing.Color]::FromArgb(255, 255, 185, 0)     # Amarillo para advertencias
$ThemeText = [System.Drawing.Color]::FromArgb(255, 32, 31, 30)         # Texto oscuro
$ThemeTextLight = [System.Drawing.Color]::FromArgb(255, 250, 249, 248) # Texto claro
$ThemeTextLight = [System.Drawing.Color]::FromArgb(255, 255, 255, 255) # Blanco

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

# Colores para el Log
$LogColorInfo = $ThemePrimary                                       # Negro
$LogColorSuccess = [System.Drawing.Color]::FromArgb(255, 0, 100, 0) # Verde oscuro
$LogColorWarning = [System.Drawing.Color]::FromArgb(255, 150, 100, 0) # Naranja oscuro
$LogColorError = $ThemeDanger                                       # Rojo oscuro
$LogColorDefault = $ThemeSecondary                                  # Gris oscuro (texto normal)
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
}
#endregion
#endregion

#region Definición de Aplicaciones (Nombre para Mostrar, ID de Winget, ID de Chocolatey)
# Lista de apps estructurada con categorías para mejor organización visual
$appCategories = @(
    @{
        Category = "Utilidades Esenciales";
        Apps = @(
            @{ Nombre = "7-Zip"; WingetID = "7zip.7zip"; ChocolateyID = "7zip"; Description = "Compresor/descompresor de archivos"; Icon = "🗜️" }
            @{ Nombre = "NanaZip"; WingetID = "M2Team.NanaZip"; ChocolateyID = "nanazip"; Description = "Compresor/descompresor moderno para Windows"; Icon = "📦" }
            @{ Nombre = "Notepad++"; WingetID = "Notepad++.Notepad++"; ChocolateyID = "notepadplusplus"; Description = "Editor de texto avanzado"; Icon = "📝" }
            @{ Nombre = "Windows Terminal"; WingetID = "Microsoft.WindowsTerminal"; ChocolateyID = "windowsterminal"; Description = "Terminal moderna para Windows"; Icon = "💻" }
            @{ Nombre = "PowerShell (Latest)"; WingetID = "Microsoft.PowerShell"; ChocolateyID = "powershell"; Description = "Shell y lenguaje de scripting"; Icon = "🔧" }
            @{ Nombre = "Visual Studio Code"; WingetID = "Microsoft.VisualStudioCode"; ChocolateyID = "vscode"; Description = "Editor de código ligero"; Icon = "⌨️" }
            @{ Nombre = "Microsoft PowerToys"; WingetID = "Microsoft.PowerToys"; ChocolateyID = "powertoys"; Description = "Utilidades para potenciar Windows"; Icon = "🧰" }
        )
    },
    @{
        Category = "Navegadores";
        Apps = @(
            @{ Nombre = "Google Chrome"; WingetID = "Google.Chrome"; ChocolateyID = "googlechrome"; Description = "Navegador web de Google"; Icon = "🌐" }
            @{ Nombre = "Brave Browser"; WingetID = "BraveSoftware.BraveBrowser"; ChocolateyID = "brave"; Description = "Navegador centrado en privacidad"; Icon = "🦁" }
        )
    },
    @{
        Category = "Herramientas de Diagnóstico";
        Apps = @(
            @{ Nombre = "CPU-Z"; WingetID = "CPUID.CPU-Z"; ChocolateyID = "cpu-z"; Description = "Información detallada del CPU"; Icon = "🔍" }
            @{ Nombre = "CrystalDiskInfo"; WingetID = "CrystalDewWorld.CrystalDiskInfo"; ChocolateyID = "crystaldiskinfo"; Description = "Monitor de salud de discos"; Icon = "💾" }
            @{ Nombre = "AIDA64 Extreme (Trial)"; WingetID = "FinalWire.AIDA64.Extreme"; ChocolateyID = ""; Description = "Diagnóstico del sistema"; Icon = "📊" }
            @{ Nombre = "Hard Disk Sentinel"; WingetID = "JanosMathe.HardDiskSentinel"; ChocolateyID = ""; Description = "Monitor de salud de discos"; Icon = "🔋" }
        )
    },
    @{
        Category = "Soporte Remoto";
        Apps = @(
            @{ Nombre = "AnyDesk"; WingetID = "AnyDeskSoftwareGmbH.AnyDesk"; ChocolateyID = "anydesk"; Description = "Control remoto rápido"; Icon = "🖥️" }
            @{ Nombre = "TeamViewer"; WingetID = "TeamViewer.TeamViewer"; ChocolateyID = "teamviewer"; Description = "Control remoto profesional"; Icon = "👁️" }
        )
    },
    @{
        Category = "Utilidades de Creación de Medios";
        Apps = @(
            @{ Nombre = "Rufus"; WingetID = "Rufus.Rufus"; ChocolateyID = "rufus"; Description = "Creador de USB booteable"; Icon = "📀" }
            @{ Nombre = "Ventoy"; WingetID = "Ventoy.Ventoy"; ChocolateyID = "ventoy"; Description = "Multiboot USB Tool"; Icon = "💿" }
        )
    },
    @{
        Category = "Comunicación";
        Apps = @(
            @{ Nombre = "Discord"; WingetID = "Discord.Discord"; ChocolateyID = "discord"; Description = "Chat y voz para comunidades"; Icon = "🎮" }
            @{ Nombre = "WhatsApp Desktop"; WingetID = "WhatsApp.WhatsApp"; ChocolateyID = "whatsapp"; Description = "Cliente de WhatsApp"; Icon = "📱" }
        )
    },
    @{
        Category = "Gestores de Actualizaciones";
        Apps = @(
            @{ Nombre = "Dell Command | Update"; WingetID = "Dell.CommandUpdate"; ChocolateyID = ""; Description = "Actualizaciones para Dell"; Icon = "🔄" }
            @{ Nombre = "HP PC Hardware Diagnostics Windows"; WingetID = "HP.PCHardwareDiagnosticsWindows"; ChocolateyID = ""; Description = "Diagnóstico de HP"; Icon = "🔎" }
            @{ Nombre = "HP Image Assistant"; WingetID = "HP.ImageAssistant"; ChocolateyID = ""; Description = "Asistente de imágenes HP"; Icon = "🖼️" }
            @{ Nombre = "HP Smart"; WingetID = "9WZDNCRFHWLH"; ChocolateyID = ""; Description = "App para impresoras HP"; Icon = "🖨️" }
            @{ Nombre = "HP Support Assistant"; WingetID = "HP.SupportAssistant"; ChocolateyID = ""; Description = "Soporte para equipos HP"; Icon = "🛠️" }
            @{ Nombre = "Intel Driver & Support Assistant"; WingetID = "Intel.IntelDriverAndSupportAssistant"; ChocolateyID = ""; Description = "Actualiza drivers Intel"; Icon = "📦" }
            @{ Nombre = "Lenovo Vantage"; WingetID = "9WZDNCRFJ4MV"; ChocolateyID = ""; Description = "Centro de dispositivos Lenovo"; Icon = "📱" }
            @{ Nombre = "Lenovo System Update"; WingetID = "Lenovo.SystemUpdate"; ChocolateyID = ""; Description = "Actualizaciones para Lenovo"; Icon = "🔄" }
            @{ Nombre = "MyASUS"; WingetID = "9N7R5S6B0ZZH"; ChocolateyID = ""; Description = "Centro de dispositivos ASUS"; Icon = "💻" }
            @{ Nombre = "NZXT CAM"; WingetID = "NZXT.CAM"; ChocolateyID = ""; Description = "Monitor para hardware NZXT"; Icon = "⚙️" }
            @{ Nombre = "UnigetUI"; WingetID = "MartiCliment.UniGetU"; ChocolateyID = "wingetui"; Description = "GUI para gestores de paquetes"; Icon = "📦" }
        )
    }
)

# Tabla plana para búsqueda y procesamiento
$appList = @()
foreach ($category in $appCategories) {
    foreach ($app in $category.Apps) {
        $appList += $app
    }
}
#endregion

#region Creación de la Interfaz Gráfica (GUI)
# Definición de la ventana principal
$form = [System.Windows.Forms.Form]::new()
$form.Text = "ToolboxAPPS v2.0"
$form.Size = [System.Drawing.Size]::new(900, 850) # Ventana más grande
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.BackColor = $ThemeAccent
$form.Icon = $null # Aquí podrías cargar un icono personalizado
$form.Font = [System.Drawing.Font]::new("Segoe UI", 9)

$form.SuspendLayout()


# Panel principal con contenido
$mainPanel = [System.Windows.Forms.Panel]::new()
$mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainPanel.Padding = [System.Windows.Forms.Padding]::new(15, 15, 15, 15)
$mainPanel.BackColor = $ThemeAccent
$form.Controls.Add($mainPanel)

# Panel de búsqueda
$searchPanel = [System.Windows.Forms.Panel]::new()
$searchPanel.Size = [System.Drawing.Size]::new(870, 50) # Más ancho
$searchPanel.Location = [System.Drawing.Point]::new(15, 15)
$searchPanel.BackColor = [System.Drawing.Color]::White
$searchPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$searchIcon = [System.Windows.Forms.Label]::new()
$searchIcon.Text = "🔍"
$searchIcon.Location = [System.Drawing.Point]::new(10, 12)
$searchIcon.Size = [System.Drawing.Size]::new(25, 25)
$searchIcon.Font = [System.Drawing.Font]::new("Segoe UI", 12)

$searchLabel = [System.Windows.Forms.Label]::new()
$searchLabel.Text = "Buscar:"
$searchLabel.Location = [System.Drawing.Point]::new(35, 15)
$searchLabel.Size = [System.Drawing.Size]::new(60, 20)
$searchLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9)

$searchTextBox = [System.Windows.Forms.TextBox]::new()
$searchTextBox.Location = [System.Drawing.Point]::new(100, 12)
$searchTextBox.Size = [System.Drawing.Size]::new(750, 25) # Más ancho
$searchTextBox.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$searchTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D

# Agregar texto de placeholder (marcador de posición)
$searchTextBox.Text = "Escribe para filtrar aplicaciones..."
$searchTextBox.ForeColor = [System.Drawing.Color]::Gray

$searchTextBox.Add_GotFocus({
    if ($this.Text -eq "Escribe para filtrar aplicaciones...") {
        $this.Text = ""
        $this.ForeColor = $ThemeText
    }
})

$searchTextBox.Add_LostFocus({
    if ($this.Text -eq "") {
        $this.Text = "Escribe para filtrar aplicaciones..."
        $this.ForeColor = [System.Drawing.Color]::Gray
    }
})

$searchPanel.Controls.Add($searchIcon)
$searchPanel.Controls.Add($searchLabel)
$searchPanel.Controls.Add($searchTextBox)
$mainPanel.Controls.Add($searchPanel)

# Panel de selección de gestor
$managerPanel = [System.Windows.Forms.Panel]::new()
$managerPanel.Size = [System.Drawing.Size]::new(870, 60) # Más ancho
$managerPanel.Location = [System.Drawing.Point]::new(15, 75)
$managerPanel.BackColor = [System.Drawing.Color]::White
$managerPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$managerLabel = [System.Windows.Forms.Label]::new()
$managerLabel.Text = "Selecciona el gestor de paquetes:"
$managerLabel.Location = [System.Drawing.Point]::new(15, 18)
$managerLabel.Size = [System.Drawing.Size]::new(200, 25)
$managerLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$wingetRadioButton = [System.Windows.Forms.RadioButton]::new()
$wingetRadioButton.Text = "Winget"
$wingetRadioButton.Location = [System.Drawing.Point]::new(230, 18)
$wingetRadioButton.Size = [System.Drawing.Size]::new(100, 25)
$wingetRadioButton.Checked = $WingetFound
$wingetRadioButton.Enabled = $WingetFound
$wingetRadioButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

$chocolateyRadioButton = [System.Windows.Forms.RadioButton]::new()
$chocolateyRadioButton.Text = "Chocolatey"
$chocolateyRadioButton.Location = [System.Drawing.Point]::new(340, 18)
$chocolateyRadioButton.Size = [System.Drawing.Size]::new(120, 25)
$chocolateyRadioButton.Checked = (-not $WingetFound -and $ChocolateyFound)
$chocolateyRadioButton.Enabled = $ChocolateyFound
$chocolateyRadioButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

$managerStatusLabel = [System.Windows.Forms.Label]::new()
$managerStatusLabel.Location = [System.Drawing.Point]::new(470, 18)
$managerStatusLabel.Size = [System.Drawing.Size]::new(380, 25) # Más ancho
$managerStatusLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$managerStatusLabel.Text = ""

if ($WingetFound) {
    $managerStatusLabel.Text += "✅ Winget disponible "
    $managerStatusLabel.ForeColor = $LogColorSuccess
}
else {
    $managerStatusLabel.Text += "❌ Winget no instalado "
    $managerStatusLabel.ForeColor = $LogColorError
}

if ($ChocolateyFound) {
    $managerStatusLabel.Text += "✅ Chocolatey disponible"
    $managerStatusLabel.ForeColor = $LogColorSuccess
}
else {
    $managerStatusLabel.Text += "❌ Chocolatey no instalado"
    $managerStatusLabel.ForeColor = $LogColorError
}

$managerPanel.Controls.Add($managerLabel)
$managerPanel.Controls.Add($wingetRadioButton)
$managerPanel.Controls.Add($chocolateyRadioButton)
$managerPanel.Controls.Add($managerStatusLabel)
$mainPanel.Controls.Add($managerPanel)

# Panel de aplicaciones con TabControl para categorías
$appsPanel = [System.Windows.Forms.Panel]::new()
$appsPanel.Size = [System.Drawing.Size]::new(870, 380) # Más ancho y alto
$appsPanel.Location = [System.Drawing.Point]::new(15, 145)
$appsPanel.BackColor = [System.Drawing.Color]::White
$appsPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

# TabControl para organizar aplicaciones por categoría
$tabControl = [System.Windows.Forms.TabControl]::new()
$tabControl.Size = [System.Drawing.Size]::new(866, 376) # Ajustado al panel
$tabControl.Location = [System.Drawing.Point]::new(0, 0)
$tabControl.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$tabControl.Appearance = [System.Windows.Forms.TabAppearance]::Normal
$tabControl.SizeMode = [System.Windows.Forms.TabSizeMode]::FillToRight

# Crear una pestaña "Todas" para mostrar todas las aplicaciones juntas
$allTab = [System.Windows.Forms.TabPage]::new()
$allTab.Text = "Todas las Apps"
$allTab.Padding = [System.Windows.Forms.Padding]::new(3)
$allTab.BackColor = [System.Drawing.Color]::White

$allCheckedListBox = [System.Windows.Forms.CheckedListBox]::new()
$allCheckedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$allCheckedListBox.CheckOnClick = $true
$allCheckedListBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$allCheckedListBox.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$allCheckedListBox.IntegralHeight = $false

# Rellenar el listado con todas las aplicaciones
foreach ($app in $appList) {
    $displayText = "$($app.Icon) $($app.Nombre) - $($app.Description)"
    $allCheckedListBox.Items.Add($displayText, $false) | Out-Null
}

$allTab.Controls.Add($allCheckedListBox)
$tabControl.TabPages.Add($allTab)

# Crear pestañas para cada categoría
foreach ($category in $appCategories) {
    $tabPage = [System.Windows.Forms.TabPage]::new()
    $tabPage.Text = $category.Category
    $tabPage.Padding = [System.Windows.Forms.Padding]::new(3)
    $tabPage.BackColor = [System.Drawing.Color]::White
    
    $categoryCheckedListBox = [System.Windows.Forms.CheckedListBox]::new()
    $categoryCheckedListBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $categoryCheckedListBox.CheckOnClick = $true
    $categoryCheckedListBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $categoryCheckedListBox.Font = [System.Drawing.Font]::new("Segoe UI", 9)
    $categoryCheckedListBox.IntegralHeight = $false
    
    # Rellenar con las aplicaciones de esta categoría
    foreach ($app in $category.Apps) {
        $displayText = "$($app.Icon) $($app.Nombre) - $($app.Description)"
        $categoryCheckedListBox.Items.Add($displayText, $false) | Out-Null
    }
    
    $tabPage.Controls.Add($categoryCheckedListBox)
    $tabControl.TabPages.Add($tabPage)
}

$appsPanel.Controls.Add($tabControl)
$mainPanel.Controls.Add($appsPanel)

# Panel de botones de acción
$actionsPanel = [System.Windows.Forms.Panel]::new()
$actionsPanel.Size = [System.Drawing.Size]::new(870, 60) # Más ancho
$actionsPanel.Location = [System.Drawing.Point]::new(15, 535)
$actionsPanel.BackColor = [System.Drawing.Color]::White
$actionsPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

# Botones de acción - Estilo sencillo en blanco y negro
$buttonWidth = 270 # Más ancho
$buttonHeight = 40
$buttonSpacing = 15
$buttonY = 10

# Botón de instalación
$installButton = [System.Windows.Forms.Button]::new()
$installButton.Text = "🔽 Instalar Seleccionadas"
$installButton.Location = [System.Drawing.Point]::new($buttonSpacing, $buttonY)
$installButton.Size = [System.Drawing.Size]::new($buttonWidth, $buttonHeight)
$installButton.BackColor = [System.Drawing.Color]::FromArgb(255, 16, 124, 16) # Verde
$installButton.ForeColor = [System.Drawing.Color]::White
$installButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$installButton.FlatAppearance.BorderSize = 0
$installButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$installButton.Cursor = [System.Windows.Forms.Cursors]::Hand

# Botón de desinstalación
$uninstallButton = [System.Windows.Forms.Button]::new()
$uninstallButton.Text = "🗑️ Desinstalar Seleccionadas"
$uninstallButton.Location = [System.Drawing.Point]::new($buttonSpacing*2 + $buttonWidth, $buttonY)
$uninstallButton.Size = [System.Drawing.Size]::new($buttonWidth, $buttonHeight)
$uninstallButton.BackColor = [System.Drawing.Color]::FromArgb(255, 209, 52, 56) # Rojo
$uninstallButton.ForeColor = [System.Drawing.Color]::White
$uninstallButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$uninstallButton.FlatAppearance.BorderSize = 0
$uninstallButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$uninstallButton.Cursor = [System.Windows.Forms.Cursors]::Hand

# Botón de actualización
$updateAllButton = [System.Windows.Forms.Button]::new()
$updateAllButton.Text = "🔄 Actualizar Todo"
$updateAllButton.Location = [System.Drawing.Point]::new($buttonSpacing*3 + $buttonWidth*2, $buttonY)
$updateAllButton.Size = [System.Drawing.Size]::new($buttonWidth, $buttonHeight)
$updateAllButton.BackColor = [System.Drawing.Color]::FromArgb(255, 0, 120, 215) # Azul
$updateAllButton.ForeColor = [System.Drawing.Color]::White
$updateAllButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$updateAllButton.FlatAppearance.BorderSize = 0
$updateAllButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$updateAllButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$actionsPanel.Controls.Add($installButton)
$actionsPanel.Controls.Add($uninstallButton)
$actionsPanel.Controls.Add($updateAllButton)
$mainPanel.Controls.Add($actionsPanel)

# Panel de log con estilo
$logPanel = [System.Windows.Forms.Panel]::new()
$logPanel.Size = [System.Drawing.Size]::new(870, 110) # Más ancho
$logPanel.Location = [System.Drawing.Point]::new(15, 605)
$logPanel.BackColor = [System.Drawing.Color]::White
$logPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

$logLabel = [System.Windows.Forms.Label]::new()
$logLabel.Text = "Registro de actividad:"
$logLabel.Location = [System.Drawing.Point]::new(10, 5)
$logLabel.Size = [System.Drawing.Size]::new(150, 20)
$logLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$clearLogButton = [System.Windows.Forms.Button]::new()
$clearLogButton.Text = "Limpiar"
$clearLogButton.Location = [System.Drawing.Point]::new(770, 5)
$clearLogButton.Size = [System.Drawing.Size]::new(80, 20)
$clearLogButton.BackColor = [System.Drawing.Color]::LightGray
$clearLogButton.ForeColor = $ThemeText
$clearLogButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$clearLogButton.FlatAppearance.BorderSize = 1
$clearLogButton.Font = [System.Drawing.Font]::new("Segoe UI", 8)
$clearLogButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$statusBox = [System.Windows.Forms.RichTextBox]::new()
$statusBox.Location = [System.Drawing.Point]::new(10, 30)
$statusBox.Size = [System.Drawing.Size]::new(850, 70) # Más ancho
$statusBox.ReadOnly = $true
$statusBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$statusBox.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 250, 250)
$statusBox.Font = [System.Drawing.Font]::new("Consolas", 9)
$statusBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical

$logPanel.Controls.Add($logLabel)
$logPanel.Controls.Add($clearLogButton)
$logPanel.Controls.Add($statusBox)
$mainPanel.Controls.Add($logPanel)

# Footer informativo
$footerLabel = [System.Windows.Forms.Label]::new()
$footerLabel.Text = "© 2025 ToolboxAPPS - Hecho con ❤️ para la comunidad"
$footerLabel.Location = [System.Drawing.Point]::new(320, 720)
$footerLabel.Size = [System.Drawing.Size]::new(300, 20)
$footerLabel.Font = [System.Drawing.Font]::new("Segoe UI", 8)
$footerLabel.ForeColor = [System.Drawing.Color]::Gray
$mainPanel.Controls.Add($footerLabel)

$form.ResumeLayout()

#region Definición de Funciones
# Función para agregar log con colores
function Add-Log {
    param(
        [string]$Message,
        [System.Drawing.Color]$Color = $LogColorDefault,
        [bool]$AddSeparatorBefore = $false,
        [bool]$AddSeparatorAfter = $false
    )

    if ($AddSeparatorBefore) {
        $statusBox.SelectionStart = $statusBox.TextLength
        $statusBox.SelectionLength = 0
        $statusBox.SelectionColor = [System.Drawing.Color]::Gray
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

    $statusBox.SelectionStart = $statusBox.TextLength
    $statusBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# Función para habilitar/deshabilitar controles durante operaciones
function Set-ControlsEnabled {
    param([bool]$Enabled)
    $installButton.Enabled = $Enabled
    $uninstallButton.Enabled = $Enabled
    $updateAllButton.Enabled = $Enabled
    $wingetRadioButton.Enabled = $Enabled -and $WingetFound
    $chocolateyRadioButton.Enabled = $Enabled -and $ChocolateyFound
    $tabControl.Enabled = $Enabled
    $searchTextBox.Enabled = $Enabled
    [System.Windows.Forms.Application]::DoEvents()
}

# Función para filtrar aplicaciones según búsqueda
# Función para filtrar aplicaciones según búsqueda
function Filter-AppList {
    $searchText = $searchTextBox.Text.Trim().ToLower()
    if ($searchText -eq "escribe para filtrar aplicaciones...") { $searchText = "" }
    
    # Primero, limpiar todas las listas
    $allCheckedListBox.Items.Clear()
    
    # Limpiar todas las pestañas de categorías
    for ($i = 1; $i -lt $tabControl.TabPages.Count; $i++) {
        $categoryTab = $tabControl.TabPages[$i]
        $categoryList = $categoryTab.Controls[0]
        $categoryList.Items.Clear()
    }
    
    # Aplicar filtro
    if ($searchText -eq "") {
        # Sin filtro - mostrar todas
        foreach ($app in $appList) {
            $displayText = "$($app.Icon) $($app.Nombre) - $($app.Description)"
            $allCheckedListBox.Items.Add($displayText, $false) | Out-Null
        }
        
        # Rellenar las pestañas de categorías
        for ($i = 0; $i -lt $appCategories.Count; $i++) {
            $category = $appCategories[$i]
            $categoryTab = $tabControl.TabPages[$i + 1] # +1 porque "Todas" es la primera
            $categoryList = $categoryTab.Controls[0]
            
            foreach ($app in $category.Apps) {
                $displayText = "$($app.Icon) $($app.Nombre) - $($app.Description)"
                $categoryList.Items.Add($displayText, $false) | Out-Null
            }
        }
    }
    else {
        # Filtrado - mostrar solo coincidencias
        $filteredAllApps = $appList | Where-Object { 
            $_.Nombre.ToLower() -like "*$searchText*" -or 
            $_.Description.ToLower() -like "*$searchText*" 
        }
        
        foreach ($app in $filteredAllApps) {
            $displayText = "$($app.Icon) $($app.Nombre) - $($app.Description)"
            $allCheckedListBox.Items.Add($displayText, $false) | Out-Null
        }
        
        # Filtrar por categorías
        for ($i = 0; $i -lt $appCategories.Count; $i++) {
            $category = $appCategories[$i]
            $categoryTab = $tabControl.TabPages[$i + 1] # +1 porque "Todas" es la primera
            $categoryList = $categoryTab.Controls[0]
            
            $filteredCategoryApps = $category.Apps | Where-Object { 
                $_.Nombre.ToLower() -like "*$searchText*" -or 
                $_.Description.ToLower() -like "*$searchText*" 
            }
            
            foreach ($app in $filteredCategoryApps) {
                $displayText = "$($app.Icon) $($app.Nombre) - $($app.Description)"
                $categoryList.Items.Add($displayText, $false) | Out-Null
            }
        }
    }
    
    [System.Windows.Forms.Application]::DoEvents()
}

# Función para obtener aplicaciones seleccionadas de todas las pestañas
function Get-SelectedApps {
    $selectedApps = @()
    
    # Verificar la pestaña activa
    $activeTab = $tabControl.SelectedTab
    $activeList = $activeTab.Controls[0]
    
    foreach ($item in $activeList.CheckedItems) {
        # Extraer el nombre sin el icono y la descripción
        $appName = $item -replace "^.{2}\s+(.+?)\s+-\s+.*$", '$1'
        $selectedApps += $appName
    }
    
    return $selectedApps
}

# Función para limpiar el log
function Clear-Log {
    $statusBox.Clear()
    Add-Log "Log limpiado." -Color $LogColorInfo
}
#endregion

#region Eventos
# Evento de búsqueda
$searchTextBox.Add_TextChanged({
    Filter-AppList
})

# Evento para limpiar el log
$clearLogButton.Add_Click({
    Clear-Log
})

# Evento para instalar aplicaciones seleccionadas
$installButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de INSTALACIÓN..." -Color $LogColorInfo -AddSeparatorBefore $true

    $selectedAppNames = Get-SelectedApps
    
    if ($selectedAppNames.Count -eq 0) {
        Add-Log "No hay aplicaciones seleccionadas para instalar." -Color $LogColorWarning
        Add-Log "Instalación cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
        Set-ControlsEnabled $true
        return
    }

    $useWinget = $wingetRadioButton.Checked
    $useChocolatey = $chocolateyRadioButton.Checked
    $packageManager = if ($useWinget) {"Winget"} elseif ($useChocolatey) {"Chocolatey"} else {"Desconocido"}
    Add-Log "Usando gestor: $packageManager"

    foreach ($appName in $selectedAppNames) {
        $appInfo = $appList | Where-Object { $_.Nombre -eq $appName }
        if ($appInfo) {
            $appID = if ($useWinget) {$appInfo.WingetID} elseif ($useChocolatey) {$appInfo.ChocolateyID} else {$null}

            if (-not $appID) {
                Add-Log "⚠️ ADVERTENCIA: La app '$appName' no tiene ID definido para $packageManager." -Color $LogColorWarning
                continue
            }

            Add-Log "⏳ Instalando $($appInfo.Nombre) (ID: $($appID)) usando $packageManager... Espera." -Color $LogColorDefault

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
                        Add-Log "✅ ÉXITO: $($appInfo.Nombre) instalado." -Color $LogColorSuccess
                    } else {
                        Add-Log "❌ ERROR ($packageManager): Instalando $($appInfo.Nombre). Código: $($process.ExitCode)." -Color $LogColorError
                        if ($errors) { Add-Log "Detalles Error:`n$errors" -Color $LogColorError }
                        elseif ($output) { Add-Log "Salida $packageManager (puede contener error):`n$output" -Color $LogColorWarning }
                        Add-Log "NOTA: Algunas instalaciones pueden requerir interacción manual." -Color $LogColorWarning
                    }
                } catch {
                    Add-Log "⚠️ EXCEPCIÓN ($packageManager) instalando $($appInfo.Nombre): $($_.Exception.Message)" -Color $LogColorError
                }
            }
        } else {
            Add-Log "⚠️ ADVERTENCIA: No se encontró info para '$appName' en la lista original." -Color $LogColorWarning
        }
    }

    Add-Log "✅ Proceso de INSTALACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})

# Evento para desinstalar aplicaciones seleccionadas
$uninstallButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de DESINSTALACIÓN..." -Color $LogColorInfo -AddSeparatorBefore $true

    $selectedAppNames = Get-SelectedApps
    
    if ($selectedAppNames.Count -eq 0) {
        Add-Log "No hay aplicaciones seleccionadas para desinstalar." -Color $LogColorWarning
        Add-Log "Desinstalación cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
        Set-ControlsEnabled $true
        return
    }

    # Confirmación de seguridad
    $confirmResult = [System.Windows.Forms.MessageBox]::Show(
        "¿Estás seguro de que deseas desinstalar las $($selectedAppNames.Count) aplicaciones seleccionadas?",
        "Confirmar Desinstalación",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($confirmResult -eq [System.Windows.Forms.DialogResult]::No) {
        Add-Log "Desinstalación cancelada por el usuario." -Color $LogColorInfo -AddSeparatorAfter $true
        Set-ControlsEnabled $true
        return
    }

    $useWinget = $wingetRadioButton.Checked
    $useChocolatey = $chocolateyRadioButton.Checked
    $packageManager = if ($useWinget) {"Winget"} elseif ($useChocolatey) {"Chocolatey"} else {"Desconocido"}
    Add-Log "Usando gestor: $packageManager"

    foreach ($appName in $selectedAppNames) {
        $appInfo = $appList | Where-Object { $_.Nombre -eq $appName }
        if ($appInfo) {
            $appID = if ($useWinget) {$appInfo.WingetID} elseif ($useChocolatey) {$appInfo.ChocolateyID} else {$null}

            if (-not $appID) {
                Add-Log "⚠️ ADVERTENCIA: La app '$appName' no tiene ID definido para $packageManager." -Color $LogColorWarning
                continue
            }

            Add-Log "⏳ Desinstalando $($appInfo.Nombre) (ID: $($appID)) usando $packageManager... Espera." -Color $LogColorDefault

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
                        Add-Log "✅ ÉXITO: $($appInfo.Nombre) desinstalado (o no estaba instalado)." -Color $LogColorSuccess
                    } else {
                        Add-Log "❌ ERROR ($packageManager): Desinstalando $($appInfo.Nombre). Código: $($process.ExitCode)." -Color $LogColorError
                        if ($errors) { Add-Log "Detalles Error:`n$errors" -Color $LogColorError }
                        elseif ($output) { Add-Log "Salida ${packageManager} (puede contener error):`n$output" -Color $LogColorWarning }
                        Add-Log "NOTA: Algunos desinstaladores ignoran el modo silencioso." -Color $LogColorWarning
                    }
                } catch {
                    Add-Log "⚠️ EXCEPCIÓN ($packageManager) desinstalando $($appInfo.Nombre): $($_.Exception.Message)" -Color $LogColorError
                }
            }
        } else {
            Add-Log "⚠️ ADVERTENCIA: No se encontró info para '$appName' en la lista original." -Color $LogColorWarning
        }
    }

    Add-Log "✅ Proceso de DESINSTALACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})

# Evento para actualizar todas las aplicaciones
$updateAllButton.Add_Click({
    Set-ControlsEnabled $false
    Add-Log "Iniciando proceso de ACTUALIZACIÓN de todo..." -Color $LogColorInfo -AddSeparatorBefore $true

    $useWinget = $wingetRadioButton.Checked
    $useChocolatey = $chocolateyRadioButton.Checked
    $packageManager = if ($useWinget) {"Winget"} elseif ($useChocolatey) {"Chocolatey"} else {"Desconocido"}

    # Re-check if managers are still available before attempting update all
     if ($useWinget -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
         Add-Log "❌ ERROR: Winget no encontrado o no funciona. No se puede actualizar con Winget." -Color $LogColorError
         Add-Log "Actualización cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
         Set-ControlsEnabled $true
         return
     }

     if ($useChocolatey -and -not (Get-Command choco -ErrorAction SilentlyContinue)) {
         Add-Log "❌ ERROR: Chocolatey no encontrado o no funciona. No se puede actualizar con Chocolatey." -Color $LogColorError
         Add-Log "Actualización cancelada." -Color $LogColorInfo -AddSeparatorAfter $true
         Set-ControlsEnabled $true
         return
     }

    Add-Log "Usando gestor para actualizar todo: $packageManager"

    $command = if ($useWinget) {"winget"} elseif ($useChocolatey) {"choco"} else {$null}
    $arguments = if ($useWinget) {"upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements"} elseif ($useChocolatey) {"upgrade all -y --no-progress --confirm"} else {$null}

    if ($command -and $arguments) {
        try {
            Add-Log "⏳ Ejecutando '$command $arguments'... Puede tardar varios minutos." -Color $LogColorDefault
            $outFile = New-TemporaryFile
            $errFile = New-TemporaryFile
            $process = Start-Process -FilePath $command -ArgumentList $arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outFile.FullName -RedirectStandardError $errFile.FullName
            $output = Get-Content $outFile.FullName -Raw -ErrorAction SilentlyContinue
            $errors = Get-Content $errFile.FullName -Raw -ErrorAction SilentlyContinue
            Remove-Item $outFile.FullName, $errFile.FullName -Force -ErrorAction SilentlyContinue

            if ($process.ExitCode -eq 0) {
                Add-Log "✅ ÉXITO: Actualización completada por $packageManager (o no había nada que actualizar)." -Color $LogColorSuccess
                # Check output for signs of actual updates or no updates
                if ($output -and ($output -notmatch "No applicable update found|No se encontraron actualizaciones aplicables|Nothing to upgrade|0 packages upgraded")) { 
                    Add-Log "📋 Salida ${packageManager}:`n$output" -Color $LogColorDefault 
                }
                elseif ($output) { 
                    Add-Log "ℹ️ ${packageManager}: No se encontraron actualizaciones." -Color $LogColorDefault
                }
                # Also check errors stream for non-fatal warnings
                if ($errors -and $errors -notmatch "Nothing to upgrade") { 
                    Add-Log "⚠️ ${packageManager} (Posibles advertencias):`n$errors" -Color $LogColorWarning 
                }

            } else {
                Add-Log "❌ ERROR ($packageManager): Durante la actualización. Código: $($process.ExitCode)." -Color $LogColorError
                if ($errors) { Add-Log "Detalles Error:`n$errors" -Color $LogColorError }
                elseif ($output) { Add-Log "Salida ${packageManager} (puede contener error/advertencia):`n$output" -Color $LogColorWarning }
                Add-Log "NOTA: Algunas actualizaciones pueden requerir interacción manual o fallar silenciosamente." -Color $LogColorWarning
            }
        } catch {
            Add-Log "⚠️ EXCEPCIÓN al ejecutar '$command $arguments': $($_.Exception.Message)" -Color $LogColorError
        }
    } else {
        Add-Log "❌ ERROR: No se pudo determinar el comando para actualizar todo con el gestor seleccionado." -Color $LogColorError
    }

    Add-Log "✅ Proceso de ACTUALIZACIÓN finalizado." -Color $LogColorInfo -AddSeparatorAfter $true
    Set-ControlsEnabled $true
})
#endregion

#region Mostrar la Ventana
$form.Add_Shown({
    # Add an initial message to the status box once it's visible
    Add-Log "ToolboxAPPS v2.0 listo. Selecciona apps de cualquier categoría, elige el gestor y usa los botones de acción." -Color $ThemePrimary
    
    # Ensure radio buttons are correctly enabled/checked based on initial check results
    $wingetRadioButton.Checked = $WingetFound
    $wingetRadioButton.Enabled = $WingetFound
    $chocolateyRadioButton.Checked = (-not $WingetFound -and $ChocolateyFound)
    $chocolateyRadioButton.Enabled = $ChocolateyFound
    
    # Información sobre gestores disponibles
    if ($WingetFound) {
        Add-Log "✅ Winget detectado y disponible." -Color $LogColorSuccess
    } else {
        Add-Log "⚠️ Winget no disponible. Intenta instalarlo desde Microsoft Store." -Color $LogColorWarning
    }
    
    if ($ChocolateyFound) {
        Add-Log "✅ Chocolatey detectado y disponible." -Color $LogColorSuccess
    } else {
        Add-Log "⚠️ Chocolatey no disponible. Puedes instalarlo desde https://chocolatey.org/install" -Color $LogColorWarning
    }
    
    $form.Activate() # Bring form to foreground
})

[void]$form.ShowDialog() # Show the window and wait for it to close
#endregion
