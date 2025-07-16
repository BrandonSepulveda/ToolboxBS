#Requires -Version 5.1
#Requires -RunAsAdministrator

# --- Comprobación y Elevación de Privilegios de Administrador ---
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        $params = "-NoProfile -File `"$($MyInvocation.MyCommand.Definition)`""
        Start-Process powershell.exe -Verb RunAs -ArgumentList $params -ErrorAction Stop
    }
    catch {
        Write-Host "Error: No se pudo elevar los privilegios." -ForegroundColor Red
        Write-Host "Por favor, haz clic derecho en el script y selecciona 'Ejecutar como administrador'." -ForegroundColor Yellow
        Read-Host "Presiona Enter para salir"
    }
    exit
}

# --- Ensamblados de Windows Forms ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Verificación e Instalación de Gestores de Paquetes ---
Write-Host "Iniciando Asistente de Aplicaciones..." -ForegroundColor DarkGray
$WingetFound = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
$ChocolateyFound = (Get-Command choco -ErrorAction SilentlyContinue) -ne $null

# Función para registrar en consola durante la configuración inicial
function Write-SetupLog { param([string]$Message, [string]$Color = "Gray") Write-Host $Message -ForegroundColor $Color }

if (-not $WingetFound) {
    Write-SetupLog "Winget no encontrado. Intentando instalar..." "Yellow"
    try {
        $wingetDownloadUrl = "https://aka.ms/getwinget"
        $wingetInstallerPath = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName() + ".msixbundle")
        Write-SetupLog "Descargando instalador de Winget..." "Cyan"
        Invoke-WebRequest -Uri $wingetDownloadUrl -OutFile $wingetInstallerPath -UseBasicParsing -ErrorAction Stop
        Write-SetupLog "Instalando Winget..." "Cyan"
        Add-AppxPackage -Path $wingetInstallerPath -ForceApplicationShutdown -ErrorAction Stop
        Start-Sleep -Seconds 2
        $WingetFound = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
        if ($WingetFound) { Write-SetupLog "Winget instalado correctamente." "Green" }
        else { Write-SetupLog "La instalación de Winget parece haber fallado." "Red" }
        Remove-Item $wingetInstallerPath -Force -ErrorAction SilentlyContinue
    } catch {
        Write-SetupLog "ERROR: Falló la instalación automática de Winget: $($_.Exception.Message)" "Red"
    }
} else { Write-SetupLog "Winget encontrado." "Green" }

if (-not $ChocolateyFound) {
    Write-SetupLog "Chocolatey no encontrado. Intentando instalar..." "Yellow"
    try {
        Write-SetupLog "Ejecutando script de instalación de Chocolatey..." "Cyan"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        # Refrescar variables de entorno para la sesión actual
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $ChocolateyFound = (Get-Command choco -ErrorAction SilentlyContinue) -ne $null
        if ($ChocolateyFound) { Write-SetupLog "Chocolatey instalado correctamente." "Green" }
        else { Write-SetupLog "La instalación de Chocolatey parece haber fallado." "Red" }
    } catch {
        Write-SetupLog "ERROR: Falló la instalación automática de Chocolatey: $($_.Exception.Message)" "Red"
    }
} else { Write-SetupLog "Chocolatey encontrado." "Green" }

if (-not $WingetFound -and -not $ChocolateyFound) {
    [System.Windows.Forms.MessageBox]::Show("No se encontró Winget ni Chocolatey. Se necesita al menos uno para usar esta herramienta.", "Error Fatal", "OK", "Error")
    exit
}

# --- Base de Datos de Aplicaciones ---
$apps = @(
    # Utilidades
    [pscustomobject]@{ id = '7zip'; name = '7-Zip'; logo = '🗜️'; description = 'Compresor/descompresor de archivos de código abierto.'; category = 'Utilidades'; wingetId = '7zip.7zip'; chocolateyId = '7zip' }
    [pscustomobject]@{ id = 'nanazip'; name = 'NanaZip'; logo = '📦'; description = 'Un fork moderno de 7-Zip con soporte para Windows 11.'; category = 'Utilidades'; wingetId = 'M2Team.NanaZip'; chocolateyId = 'nanazip' }
    [pscustomobject]@{ id = 'notepadplusplus'; name = 'Notepad++'; logo = '📝'; description = 'Editor de texto y código fuente con resaltado de sintaxis.'; category = 'Utilidades'; wingetId = 'Notepad++.Notepad++'; chocolateyId = 'notepadplusplus' }
    [pscustomobject]@{ id = 'windowsterminal'; name = 'Windows Terminal'; logo = '💻'; description = 'Aplicación de terminal moderna para usuarios de línea de comandos.'; category = 'Utilidades'; wingetId = 'Microsoft.WindowsTerminal'; chocolateyId = 'windowsterminal' }
    [pscustomobject]@{ id = 'powershell'; name = 'PowerShell'; logo = '🔧'; description = 'Shell de línea de comandos y lenguaje de scripting multiplataforma.'; category = 'Utilidades'; wingetId = 'Microsoft.PowerShell'; chocolateyId = 'powershell' }
    [pscustomobject]@{ id = 'vscode'; name = 'Visual Studio Code'; logo = '⌨️'; description = 'Editor de código ligero pero potente de Microsoft.'; category = 'Utilidades'; wingetId = 'Microsoft.VisualStudioCode'; chocolateyId = 'vscode' }
    [pscustomobject]@{ id = 'powertoys'; name = 'Microsoft PowerToys'; logo = '🧰'; description = 'Conjunto de utilidades para usuarios avanzados de Windows.'; category = 'Utilidades'; wingetId = 'Microsoft.PowerToys'; chocolateyId = 'powertoys' }
    [pscustomobject]@{ id = 'cpu-z'; name = 'CPU-Z'; logo = '🔍'; description = 'Software que recopila información sobre el hardware del sistema.'; category = 'Utilidades'; wingetId = 'CPUID.CPU-Z'; chocolateyId = 'cpu-z' }
    [pscustomobject]@{ id = 'crystaldiskinfo'; name = 'CrystalDiskInfo'; logo = '💾'; description = 'Utilidad para monitorear el estado de los discos duros.'; category = 'Utilidades'; wingetId = 'CrystalDewWorld.CrystalDiskInfo'; chocolateyId = 'crystaldiskinfo' }
    [pscustomobject]@{ id = 'aida64extreme'; name = 'AIDA64 Extreme'; logo = '📊'; description = 'Herramienta de diagnóstico y benchmarking del sistema (Trial).'; category = 'Utilidades'; wingetId = 'FinalWire.AIDA64.Extreme'; chocolateyId = '' }
    [pscustomobject]@{ id = 'harddisksentinel'; name = 'Hard Disk Sentinel'; logo = '🔋'; description = 'Software de monitoreo y análisis de HDD/SSD.'; category = 'Utilidades'; wingetId = 'JanosMathe.HardDiskSentinel.Professional'; chocolateyId = '' }
    [pscustomobject]@{ id = 'rufus'; name = 'Rufus'; logo = '📀'; description = 'Utilidad para crear unidades USB de arranque.'; category = 'Utilidades'; wingetId = 'Rufus.Rufus'; chocolateyId = 'rufus' }
    [pscustomobject]@{ id = 'ventoy'; name = 'Ventoy'; logo = '💿'; description = 'Crea unidades USB de arranque para múltiples archivos ISO.'; category = 'Utilidades'; wingetId = 'Ventoy.Ventoy'; chocolateyId = 'ventoy' }
    [pscustomobject]@{ id = 'unigetui'; name = 'UnigetUI'; logo = '📦'; description = 'Interfaz gráfica para gestores de paquetes como winget y choco.'; category = 'Utilidades'; wingetId = 'MartiCliment.UniGetUI'; chocolateyId = 'wingetui' }
    [pscustomobject]@{ id = 'chrome'; name = 'Google Chrome'; logo = '🌐'; description = 'El navegador web más popular del mundo.'; category = 'Navegadores'; wingetId = 'Google.Chrome'; chocolateyId = 'googlechrome' }
    [pscustomobject]@{ id = 'brave'; name = 'Brave Browser'; logo = '�'; description = 'Navegador rápido y centrado en la privacidad con bloqueo de anuncios.'; category = 'Navegadores'; wingetId = 'BraveSoftware.BraveBrowser'; chocolateyId = 'brave' }
    [pscustomobject]@{ id = 'anydesk'; name = 'AnyDesk'; logo = '🖥️'; description = 'Software de escritorio remoto rápido, seguro y ligero.'; category = 'Comunicación'; wingetId = 'AnyDeskSoftwareGmbH.AnyDesk'; chocolateyId = 'anydesk' }
    [pscustomobject]@{ id = 'teamviewer'; name = 'TeamViewer'; logo = '👁️'; description = 'Solución completa para acceso remoto y soporte.'; category = 'Comunicación'; wingetId = 'TeamViewer.TeamViewer'; chocolateyId = 'teamviewer' }
    [pscustomobject]@{ id = 'discord'; name = 'Discord'; logo = '🎮'; description = 'Plataforma de chat de voz, video y texto para comunidades.'; category = 'Comunicación'; wingetId = 'Discord.Discord'; chocolateyId = 'discord' }
    [pscustomobject]@{ id = 'whatsapp'; name = 'WhatsApp Desktop'; logo = '📱'; description = 'Cliente de escritorio oficial para la mensajería de WhatsApp.'; category = 'Comunicación'; wingetId = 'WhatsApp.WhatsApp'; chocolateyId = 'whatsapp' }
    [pscustomobject]@{ id = 'dellcommandupdate'; name = 'Dell Command | Update'; logo = '🔄'; description = 'Actualiza automáticamente los drivers y BIOS en equipos Dell.'; category = 'Herramientas de Fabricante'; wingetId = 'Dell.CommandUpdate'; chocolateyId = '' }
    [pscustomobject]@{ id = 'hppchardware'; name = 'HP PC Hardware Diag.'; logo = '🔎'; description = 'Herramienta de diagnóstico para hardware de PC HP.'; category = 'Herramientas de Fabricante'; wingetId = 'HP.PCHardwareDiagnosticsWindows'; chocolateyId = '' }
    [pscustomobject]@{ id = 'hpimageassistant'; name = 'HP Image Assistant'; logo = '🖼️'; description = 'Asistente para la gestión de imágenes de software en PCs HP.'; category = 'Herramientas de Fabricante'; wingetId = 'HP.ImageAssistant'; chocolateyId = '' }
    [pscustomobject]@{ id = 'hpsmart'; name = 'HP Smart'; logo = '🖨️'; description = 'Aplicación para gestionar impresoras y escaners HP.'; category = 'Herramientas de Fabricante'; wingetId = '9WZDNCRFHWLH'; chocolateyId = '' }
    [pscustomobject]@{ id = 'hpsupportassistant'; name = 'HP Support Assistant'; logo = '🛠️'; description = 'Soporte y solución de problemas para equipos HP.'; category = 'Herramientas de Fabricante'; wingetId = 'HP.SupportAssistant'; chocolateyId = '' }
    [pscustomobject]@{ id = 'inteldriver'; name = 'Intel Driver Assistant'; logo = '📦'; description = 'Identifica y actualiza drivers de hardware Intel.'; category = 'Herramientas de Fabricante'; wingetId = 'Intel.IntelDriverAndSupportAssistant'; chocolateyId = '' }
    [pscustomobject]@{ id = 'lenovovantage'; name = 'Lenovo Vantage'; logo = '📱'; description = 'Centro de control para dispositivos Lenovo.'; category = 'Herramientas de Fabricante'; wingetId = '9WZDNCRFJ4MV'; chocolateyId = '' }
    [pscustomobject]@{ id = 'lenovosystemupdate'; name = 'Lenovo System Update'; logo = '🔄'; description = 'Actualiza drivers, BIOS y aplicaciones en equipos Lenovo.'; category = 'Herramientas de Fabricante'; wingetId = 'Lenovo.SystemUpdate'; chocolateyId = '' }
    [pscustomobject]@{ id = 'myasus'; name = 'MyASUS'; logo = '💻'; description = 'Portal de servicio y soporte para productos ASUS.'; category = 'Herramientas de Fabricante'; wingetId = '9N7R5S6B0ZZH'; chocolateyId = '' }
    [pscustomobject]@{ id = 'nzxtcam'; name = 'NZXT CAM'; logo = '⚙️'; description = 'Software de monitoreo de PC para hardware NZXT.'; category = 'Herramientas de Fabricante'; wingetId = 'NZXT.CAM'; chocolateyId = '' }
)

# --- Definición de la Interfaz Gráfica (GUI) ---
$theme = @{
    bg_dark    = [System.Drawing.Color]::FromArgb(255, 13, 17, 23)
    bg_medium  = [System.Drawing.Color]::FromArgb(255, 22, 27, 34)
    bg_light   = [System.Drawing.Color]::FromArgb(255, 33, 38, 45)
    text_light = [System.Drawing.Color]::FromArgb(255, 240, 246, 252)
    text_sec   = [System.Drawing.Color]::FromArgb(255, 139, 148, 158)
    accent     = [System.Drawing.Color]::FromArgb(255, 47, 129, 247)
    success    = [System.Drawing.Color]::FromArgb(255, 34, 139, 34)
    danger     = [System.Drawing.Color]::FromArgb(255, 220, 53, 69)
    warning    = [System.Drawing.Color]::FromArgb(255, 255, 185, 0)
    border     = [System.Drawing.Color]::FromArgb(255, 48, 54, 61)
    border_accent = [System.Drawing.Color]::FromArgb(255, 88, 166, 255)
}
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Centro de Aplicaciones - JBSV"
$mainForm.Size = New-Object System.Drawing.Size(1000, 800)
$mainForm.MinimumSize = New-Object System.Drawing.Size(800, 600)
$mainForm.StartPosition = 'CenterScreen'
$mainForm.BackColor = $theme.bg_dark
$mainForm.ForeColor = $theme.text_light
$mainForm.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = 'Fill'
$mainForm.Controls.Add($mainPanel)
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Centro de Aplicaciones"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $theme.text_light
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$mainPanel.Controls.Add($titleLabel)
$subTitleLabel = New-Object System.Windows.Forms.Label
$subTitleLabel.Text = "Selecciona las apps que necesitas e instálalas directamente."
$subTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$subTitleLabel.ForeColor = $theme.text_sec
$subTitleLabel.AutoSize = $true
$subTitleLabel.Location = New-Object System.Drawing.Point(20, 60)
$mainPanel.Controls.Add($subTitleLabel)
$filterGroup = New-Object System.Windows.Forms.GroupBox
$filterGroup.Text = "Filtros"
$filterGroup.ForeColor = $theme.text_sec
$filterGroup.Location = New-Object System.Drawing.Point(20, 100)
$filterGroup.Size = New-Object System.Drawing.Size(940, 120)
$filterGroup.Anchor = 'Top, Left, Right'
$mainPanel.Controls.Add($filterGroup)
$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Text = "Buscar:"
$searchLabel.Location = New-Object System.Drawing.Point(15, 25)
$searchLabel.AutoSize = $true
$filterGroup.Controls.Add($searchLabel)
$searchInput = New-Object System.Windows.Forms.TextBox
$searchInput.Location = New-Object System.Drawing.Point(80, 22)
$searchInput.Size = New-Object System.Drawing.Size(300, 20)
$searchInput.BackColor = $theme.bg_light
$searchInput.ForeColor = $theme.text_light
$searchInput.BorderStyle = 'FixedSingle'
$filterGroup.Controls.Add($searchInput)
$categoryLabel = New-Object System.Windows.Forms.Label
$categoryLabel.Text = "Categorías:"
$categoryLabel.Location = New-Object System.Drawing.Point(15, 65)
$categoryLabel.AutoSize = $true
$filterGroup.Controls.Add($categoryLabel)
$categoryPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$categoryPanel.Location = New-Object System.Drawing.Point(90, 60)
$categoryPanel.Size = New-Object System.Drawing.Size(830, 40)
$categoryPanel.Anchor = 'Top, Left, Right'
$categoryPanel.AutoScroll = $true
$filterGroup.Controls.Add($categoryPanel)
$appGridPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$appGridPanel.Location = New-Object System.Drawing.Point(20, 230)
$appGridPanel.Size = New-Object System.Drawing.Size(940, 320)
$appGridPanel.Anchor = 'Top, Bottom, Left, Right'
$appGridPanel.AutoScroll = $true
$appGridPanel.BackColor = $theme.bg_dark
$appGridPanel.Padding = New-Object System.Windows.Forms.Padding(5)
$mainPanel.Controls.Add($appGridPanel)
$actionsPanel = New-Object System.Windows.Forms.Panel
$actionsPanel.Height = 180
$actionsPanel.Dock = 'Bottom'
$actionsPanel.BackColor = $theme.bg_medium
$mainPanel.Controls.Add($actionsPanel)
$selectAllBtn = New-Object System.Windows.Forms.Button
$selectAllBtn.Text = "Seleccionar Visibles"
$selectAllBtn.Location = New-Object System.Drawing.Point(20, 15)
$selectAllBtn.Size = New-Object System.Drawing.Size(150, 30)
$selectAllBtn.BackColor = $theme.bg_light
$selectAllBtn.FlatStyle = 'Flat'
$actionsPanel.Controls.Add($selectAllBtn)
$deselectAllBtn = New-Object System.Windows.Forms.Button
$deselectAllBtn.Text = "Limpiar Selección"
$deselectAllBtn.Location = New-Object System.Drawing.Point(180, 15)
$deselectAllBtn.Size = New-Object System.Drawing.Size(150, 30)
$deselectAllBtn.BackColor = $theme.bg_light
$deselectAllBtn.FlatStyle = 'Flat'
$actionsPanel.Controls.Add($deselectAllBtn)
$packageManagerGroup = New-Object System.Windows.Forms.GroupBox
$packageManagerGroup.Text = "Gestor de Paquetes"
$packageManagerGroup.ForeColor = $theme.text_sec
$packageManagerGroup.Location = New-Object System.Drawing.Point(350, 10)
$packageManagerGroup.Size = New-Object System.Drawing.Size(250, 50)
$actionsPanel.Controls.Add($packageManagerGroup)
$wingetRadio = New-Object System.Windows.Forms.RadioButton
$wingetRadio.Text = "Winget"
$wingetRadio.Location = New-Object System.Drawing.Point(15, 20)
$wingetRadio.Checked = $WingetFound
$wingetRadio.Enabled = $WingetFound
$wingetRadio.AutoSize = $true
$packageManagerGroup.Controls.Add($wingetRadio)
$chocolateyRadio = New-Object System.Windows.Forms.RadioButton
$chocolateyRadio.Text = "Chocolatey"
$chocolateyRadio.Location = New-Object System.Drawing.Point(120, 20)
$chocolateyRadio.Checked = (-not $WingetFound -and $ChocolateyFound)
$chocolateyRadio.Enabled = $ChocolateyFound
$chocolateyRadio.AutoSize = $true
$packageManagerGroup.Controls.Add($chocolateyRadio)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Instalar (0)"
$installButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$installButton.Location = New-Object System.Drawing.Point(620, 15)
$installButton.Size = New-Object System.Drawing.Size(115, 45)
$installButton.Anchor = 'Top, Right'
$installButton.BackColor = $theme.success
$installButton.ForeColor = $theme.text_light
$installButton.FlatStyle = 'Flat'
$installButton.FlatAppearance.BorderSize = 0
$actionsPanel.Controls.Add($installButton)

$uninstallButton = New-Object System.Windows.Forms.Button
$uninstallButton.Text = "Desinstalar (0)"
$uninstallButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$uninstallButton.Location = New-Object System.Drawing.Point(740, 15)
$uninstallButton.Size = New-Object System.Drawing.Size(115, 45)
$uninstallButton.Anchor = 'Top, Right'
$uninstallButton.BackColor = $theme.danger
$uninstallButton.ForeColor = $theme.text_light
$uninstallButton.FlatStyle = 'Flat'
$uninstallButton.FlatAppearance.BorderSize = 0
$actionsPanel.Controls.Add($uninstallButton)

$updateAllButton = New-Object System.Windows.Forms.Button
$updateAllButton.Text = "Actualizar Todo"
$updateAllButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$updateAllButton.Location = New-Object System.Drawing.Point(860, 15)
$updateAllButton.Size = New-Object System.Drawing.Size(115, 45)
$updateAllButton.Anchor = 'Top, Right'
$updateAllButton.BackColor = $theme.accent
$updateAllButton.ForeColor = $theme.text_light
$updateAllButton.FlatStyle = 'Flat'
$updateAllButton.FlatAppearance.BorderSize = 0
$actionsPanel.Controls.Add($updateAllButton)

$outputBox = New-Object System.Windows.Forms.RichTextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$outputBox.ReadOnly = $true
$outputBox.Location = New-Object System.Drawing.Point(20, 70)
$outputBox.Size = New-Object System.Drawing.Size(940, 100)
$outputBox.Anchor = 'Top, Bottom, Left, Right'
$outputBox.BackColor = $theme.bg_dark
$outputBox.ForeColor = $theme.text_light
$outputBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$outputBox.BorderStyle = 'FixedSingle'
$actionsPanel.Controls.Add($outputBox)

# --- Lógica de la Aplicación ---
$activeCategoryButton = $null
function Add-Log {
    param([string]$Message, [System.Drawing.Color]$Color, [bool]$AddSeparator = $false)
    if ($AddSeparator) { Write-OutputToConsole "------------------------------------------------------------" }
    Write-OutputToConsole "$(Get-Date -Format 'HH:mm:ss') - $Message" $Color
}
function Write-OutputToConsole {
    param([string]$Message, [System.Drawing.Color]$Color = $theme.text_light)
    if ($outputBox.InvokeRequired) {
        $outputBox.Invoke([Action[string, object]] { param($m, $c) $outputBox.SelectionColor = $c; $outputBox.AppendText("$m`r`n") }, $Message, $Color)
    } else {
        $outputBox.SelectionColor = $Color
        $outputBox.AppendText("$Message`r`n")
    }
    $outputBox.ScrollToCaret()
}
function Create-AppCard {
    param($app)
    $cardPanel = New-Object System.Windows.Forms.Panel
    $cardPanel.Size = New-Object System.Drawing.Size(290, 160)
    $cardPanel.BackColor = $theme.bg_medium
    $cardPanel.Margin = New-Object System.Windows.Forms.Padding(5)
    $cardPanel.BorderStyle = 'FixedSingle'
    $cardPanel.Tag = $app
    $cardPanel.add_Paint({
        $panel = $this
        $checkBox = $panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }
        $color = if ($checkBox.Checked) { $theme.border_accent } else { $theme.border }
        [System.Windows.Forms.ControlPaint]::DrawBorder($_.Graphics, $panel.ClientRectangle, $color, [System.Windows.Forms.ButtonBorderStyle]::Solid)
    })
    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Location = New-Object System.Drawing.Point(260, 10)
    $checkBox.Size = New-Object System.Drawing.Size(20, 20)
    $checkBox.Tag = $cardPanel
    $cardPanel.Controls.Add($checkBox)
    $logoLabel = New-Object System.Windows.Forms.Label
    $logoLabel.Text = $app.logo
    $logoLabel.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 24)
    $logoLabel.Location = New-Object System.Drawing.Point(15, 15)
    $logoLabel.AutoSize = $true
    $cardPanel.Controls.Add($logoLabel)
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $app.name
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $theme.text_light
    $titleLabel.Location = New-Object System.Drawing.Point(15, 60)
    $titleLabel.AutoSize = $true
    $cardPanel.Controls.Add($titleLabel)
    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = $app.description
    $descLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $descLabel.ForeColor = $theme.text_sec
    $descLabel.Location = New-Object System.Drawing.Point(15, 85)
    $descLabel.MaximumSize = New-Object System.Drawing.Size(260, 40)
    $descLabel.AutoSize = $true
    $cardPanel.Controls.Add($descLabel)
    $tagsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $tagsPanel.Location = New-Object System.Drawing.Point(15, 130)
    $tagsPanel.Size = New-Object System.Drawing.Size(260, 25)
    $tagsPanel.WrapContents = $false
    $cardPanel.Controls.Add($tagsPanel)
    $tags = @($app.category)
    if (-not [string]::IsNullOrEmpty($app.wingetId)) { $tags += "winget" }
    if (-not [string]::IsNullOrEmpty($app.chocolateyId)) { $tags += "choco" }
    foreach ($tagText in $tags) {
        $tagLabel = New-Object System.Windows.Forms.Label
        $tagLabel.Text = $tagText
        $tagLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
        $tagLabel.BackColor = $theme.bg_light
        $tagLabel.ForeColor = $theme.text_sec
        $tagLabel.Padding = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
        $tagLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 5, 0)
        $tagLabel.AutoSize = $true
        $tagsPanel.Controls.Add($tagLabel)
    }
    $clickHandler = {
        $clickedControl = $this
        if ($clickedControl -is [System.Windows.Forms.CheckBox]) { return }
        $panel = if ($clickedControl -is [System.Windows.Forms.Panel]) { $clickedControl } else { $clickedControl.Parent }
        while ($panel -isnot [System.Windows.Forms.Panel] -or $panel.Parent -isnot [System.Windows.Forms.FlowLayoutPanel]) {
             $panel = $panel.Parent
        }
        $cb = $panel.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }
        $cb.Checked = -not $cb.Checked
    }
    $cardPanel.add_Click($clickHandler)
    $logoLabel.add_Click($clickHandler)
    $titleLabel.add_Click($clickHandler)
    $descLabel.add_Click($clickHandler)
    $checkBox.add_CheckedChanged({
        $this.Tag.Invalidate()
        Update-SelectionCount
    })
    return $cardPanel
}
function Render-Apps {
    $appGridPanel.SuspendLayout()
    $appGridPanel.Controls.Clear()
    $searchTerm = $searchInput.Text.ToLower()
    $activeCategory = if ($activeCategoryButton) { $activeCategoryButton.Tag } else { "Todas" }
    $filteredApps = $apps | Where-Object {
        ($_.name.ToLower().Contains($searchTerm) -or $_.description.ToLower().Contains($searchTerm)) -and
        ($activeCategory -eq "Todas" -or $_.category -eq $activeCategory)
    }
    foreach ($app in $filteredApps) {
        $card = Create-AppCard -app $app
        $appGridPanel.Controls.Add($card)
    }
    $appGridPanel.ResumeLayout()
    Update-SelectionCount
}
function Update-SelectionCount {
    $selectedCount = ($appGridPanel.Controls | ForEach-Object { $_.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] -and $_.Checked } }).Count
    $installButton.Text = "Instalar ($selectedCount)"
    $uninstallButton.Text = "Desinstalar ($selectedCount)"
}
function Render-Categories {
    $categoryPanel.Controls.Clear()
    $categories = @("Todas") + ($apps.category | Select-Object -Unique)
    foreach ($category in $categories) {
        $catButton = New-Object System.Windows.Forms.Button
        $catButton.Text = $category
        $catButton.Tag = $category
        $catButton.AutoSize = $true
        $catButton.FlatStyle = 'Flat'
        $catButton.BackColor = $theme.bg_light
        $catButton.ForeColor = $theme.text_sec
        $catButton.Padding = New-Object System.Windows.Forms.Padding(5)
        $catButton.Margin = New-Object System.Windows.Forms.Padding(3)
        $catButton.FlatAppearance.BorderSize = 0
        if ($category -eq "Todas") {
            $catButton.BackColor = $theme.accent
            $catButton.ForeColor = $theme.text_light
            $activeCategoryButton = $catButton
        }
        $catButton.add_Click({
            if ($activeCategoryButton) {
                $activeCategoryButton.BackColor = $theme.bg_light
                $activeCategoryButton.ForeColor = $theme.text_sec
            }
            $this.BackColor = $theme.accent
            $this.ForeColor = $theme.text_light
            $activeCategoryButton = $this
            Render-Apps
        })
        $categoryPanel.Controls.Add($catButton)
    }
}
function Start-Operation {
    param(
        [ValidateSet('install', 'uninstall', 'update-all')]
        [string]$OperationType
    )

    $selectedAppsData = @()
    if ($OperationType -ne 'update-all') {
        $selectedCards = $appGridPanel.Controls | Where-Object { ($_.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }).Checked }
        if ($selectedCards.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Por favor, selecciona al menos una aplicación.", "Sin Selección", "OK", "Warning")
            return
        }
        $selectedAppsData = $selectedCards.Tag
    }
    
    if ($OperationType -eq 'uninstall') {
        $confirmResult = [System.Windows.Forms.MessageBox]::Show(
            "¿Estás seguro de que deseas desinstalar las $($selectedAppsData.Count) aplicaciones seleccionadas?",
            "Confirmar Desinstalación", "YesNo", "Warning")
        if ($confirmResult -ne 'Yes') {
            Add-Log "Desinstalación cancelada por el usuario." $theme.warning
            return
        }
    }

    $installButton.Enabled = $false
    $uninstallButton.Enabled = $false
    $updateAllButton.Enabled = $false
    $outputBox.Clear()

    $packageManager = if ($wingetRadio.Checked) { "winget" } else { "chocolatey" }
    
    $job = Start-Job -ScriptBlock {
        param($selectedAppsData, $packageManager, $OperationType)
        
        function Write-Log { 
            param([string]$Message, [string]$Type = "Info")
            [pscustomobject]@{ Message = $Message; Type = $Type }
        }

        $operationVerb = @{
            'install' = 'Instalando'
            'uninstall' = 'Desinstalando'
            'update-all' = 'Actualizando Todo'
        }[$OperationType]

        Write-Log "Inicio del proceso: $operationVerb con $packageManager..." "Info"

        if ($OperationType -eq 'update-all') {
            $executable = if ($packageManager -eq 'winget') { "winget" } else { "choco" }
            $processArgs = if ($packageManager -eq 'winget') { "upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --verbose-logs" } else { "upgrade all -y --force" }
            
            Write-Log "Ejecutando: $executable $processArgs" "Info"
            try {
                $process = Start-Process $executable -ArgumentList $processArgs -PassThru -Wait -WindowStyle Normal -RedirectStandardOutput "$env:TEMP\out.tmp" -RedirectStandardError "$env:TEMP\err.tmp"
                $output = Get-Content "$env:TEMP\out.tmp" -Raw -ErrorAction SilentlyContinue
                $errors = Get-Content "$env:TEMP\err.tmp" -Raw -ErrorAction SilentlyContinue
                if ($output) { Write-Log $output "Detail" }
                if ($errors) { Write-Log $errors "Error" }

                if ($process.ExitCode -eq 0) { Write-Log "Proceso de actualización completado." "Success" }
                else { Write-Log "Proceso de actualización finalizó con errores. Código: $($process.ExitCode)" "Error" }
            } catch {
                Write-Log "Excepción al ejecutar la actualización: $($_.Exception.Message)" "Error"
            }
        } else {
            foreach ($app in $selectedAppsData) {
                $idToUse = if ($packageManager -eq 'winget') { $app.wingetId } else { $app.chocolateyId }
                if ([string]::IsNullOrEmpty($idToUse)) {
                    Write-Log "Saltando '$($app.name)' - No tiene ID para $packageManager." "Warning"
                    continue
                }

                Write-Log "--- $operationVerb $($app.name) ($idToUse) ---" "Info"
                try {
                    $executable = if ($packageManager -eq 'winget') { "winget" } else { "choco" }
                    
                    # FIX: Correct arguments for each operation
                    $processArgs = ""
                    if ($packageManager -eq 'winget') {
                        if ($OperationType -eq 'install') {
                            $processArgs = "install --id `"$idToUse`" --accept-package-agreements --accept-source-agreements --verbose-logs"
                        } else { # uninstall
                            $processArgs = "uninstall --id `"$idToUse`" --accept-source-agreements --verbose-logs"
                        }
                    } else { # chocolatey
                        $processArgs = "$OperationType `"$idToUse`" -y --force"
                    }

                    $windowStyle = if ($OperationType -eq 'uninstall') { 'Normal' } else { 'Hidden' }
                    
                    $process = Start-Process $executable -ArgumentList $processArgs -PassThru -Wait -WindowStyle $windowStyle -RedirectStandardOutput "$env:TEMP\out.tmp" -RedirectStandardError "$env:TEMP\err.tmp"
                    $output = Get-Content "$env:TEMP\out.tmp" -Raw -ErrorAction SilentlyContinue
                    $errors = Get-Content "$env:TEMP\err.tmp" -Raw -ErrorAction SilentlyContinue
                    if ($output) { Write-Log $output "Detail" }
                    if ($errors) { Write-Log $errors "Error" }
                    
                    $SuccessExitCodes = @(0)
                    if ($OperationType -eq 'install' -and $packageManager -eq 'winget') {
                        $SuccessExitCodes += -1978335189 # 0x8A15002B (Already Installed)
                    }

                    if ($process.ExitCode -in $SuccessExitCodes) { 
                        if ($process.ExitCode -eq -1978335189) {
                             Write-Log "ÉXITO: '$($app.name)' ya estaba instalado." "Success"
                        } else {
                             Write-Log "ÉXITO: '$($app.name)' $($OperationType)do(a)." "Success" 
                        }
                    }
                    else { Write-Log "ERROR: Falló la $($OperationType)ción de '$($app.name)'. Código: $($process.ExitCode)" "Error" }
                } catch {
                    Write-Log "EXCEPCIÓN durante la $($OperationType)ción de '$($app.name)': $($_.Exception.Message)" "Error"
                }
            }
        }
        Write-Log "--- Proceso finalizado. ---" "Info"
    } -ArgumentList @($selectedAppsData, $packageManager, $OperationType)

    while ($job.State -eq 'Running') {
        Receive-Job -Job $job -Keep | ForEach-Object {
            $logColor = switch ($_.Type) {
                "Success" { $theme.success }
                "Error"   { $theme.danger }
                "Warning" { $theme.warning }
                "Detail"  { $theme.text_sec }
                default   { $theme.text_light }
            }
            Add-Log $_.Message $logColor
        }
        Start-Sleep -Milliseconds 200
    }
    Receive-Job -Job $job | ForEach-Object {
        $logColor = switch ($_.Type) {
            "Success" { $theme.success }
            "Error"   { $theme.danger }
            "Warning" { $theme.warning }
            "Detail"  { $theme.text_sec }
            default   { $theme.text_light }
        }
        Add-Log $_.Message $logColor
    }
    Remove-Job -Job $job
    Remove-Item "$env:TEMP\out.tmp", "$env:TEMP\err.tmp" -ErrorAction SilentlyContinue
    
    $installButton.Enabled = $true
    $uninstallButton.Enabled = $true
    $updateAllButton.Enabled = $true
}

# --- Event Handlers ---
$searchInput.add_TextChanged({ Render-Apps })
$selectAllBtn.add_Click({
    $appGridPanel.Controls | ForEach-Object { ($_.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }).Checked = $true }
})
$deselectAllBtn.add_Click({
    $appGridPanel.Controls | ForEach-Object { ($_.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] }).Checked = $false }
})
$installButton.add_Click({ Start-Operation -OperationType 'install' })
$uninstallButton.add_Click({ Start-Operation -OperationType 'uninstall' })
$updateAllButton.add_Click({ Start-Operation -OperationType 'update-all'})

# --- Inicialización de la GUI ---
$mainForm.Add_Shown({
    Add-Log "Asistente de Aplicaciones listo." $theme.accent $true
    if ($WingetFound) { Add-Log "Winget detectado y disponible." $theme.success }
    else { Add-Log "Winget no disponible." $theme.warning }
    if ($ChocolateyFound) { Add-Log "Chocolatey detectado y disponible." $theme.success }
    else { Add-Log "Chocolatey no disponible." $theme.warning }
})
Render-Categories
Render-Apps
[void]$mainForm.ShowDialog()
