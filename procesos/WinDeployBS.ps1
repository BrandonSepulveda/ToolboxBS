<#
.SYNOPSIS
    Crea una partición de arranque a partir de un archivo ISO para instalar Windows, con opciones avanzadas de automatización.

.DESCRIPTION
    Esta herramienta crea una partición de arranque a partir de un archivo ISO de Windows,
    modificando el BCD para permitir una instalación limpia. Incluye opciones para generar 
    un archivo autounattend.xml que automatiza el proceso de instalación, omitiendo 
    requisitos de hardware y configuraciones iniciales.

.NOTES
    Autor: Brandon Sepulveda 
    Version: 1.1
    Requiere: PowerShell 5.1 o superior, ejecutándose como Administrador.
#>

#region --- Admin Rights Check ---
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-ExecutionPolicy Bypass -File `"$($myinvocation.mycommand.definition)`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}
#endregion

#region --- GUI Definition (XAML) ---
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinDeploy Ultimate by: Brandon Sepulveda" Height="680" Width="550"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#FF111827" Foreground="White" FontFamily="Segoe UI">
    <Window.Resources>
        <!-- Colores base para selección para mejorar legibilidad -->
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#FF3B82F6"/>
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="White"/>
        <SolidColorBrush x:Key="{x:Static SystemColors.ControlBrushKey}" Color="#FF3B82F6"/>

        <!-- Estilo General para Botones -->
        <Style TargetType="{x:Type Button}">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Height" Value="40"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Button}">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#FF374151"/>
                    <Setter Property="Foreground" Value="#FF9CA3AF"/>
                    <Setter Property="Cursor" Value="No"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- Estilo para TextBoxes -->
        <Style TargetType="{x:Type TextBox}">
            <Setter Property="Background" Value="#FF1F2937"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#FF374151"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Validation.ErrorTemplate" Value="{x:Null}"/>
        </Style>
        <!-- Estilo para PasswordBox -->
        <Style TargetType="{x:Type PasswordBox}">
            <Setter Property="Background" Value="#FF1F2937"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#FF374151"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <!-- Estilo para ComboBoxes -->
        <Style TargetType="{x:Type ComboBox}">
            <Setter Property="Background" Value="#FF1F2937"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="BorderBrush" Value="#FF374151"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <!-- Estilo para los items del dropdown del ComboBox -->
        <Style TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="Black"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- Estilo para GroupBoxes -->
        <Style TargetType="{x:Type GroupBox}">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#FF374151"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="Margin" Value="0,5,0,5"/>
        </Style>
    </Window.Resources>
    <Grid Margin="15">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <StackPanel Grid.Row="0" Margin="0,0,0,10">
                    <TextBlock Text="WinDeploy Ultimate" FontSize="22" FontWeight="Bold" Foreground="White"/>
                    <TextBlock Text="Crea una partición de arranque para formatear e instalar Windows." TextWrapping="Wrap" Foreground="#FFD1D5DB"/>
                </StackPanel>

                <GroupBox Header="1. Selecciona el Disco Principal a modificar" Grid.Row="1">
                    <ComboBox x:Name="DiskComboBox" Height="35"/>
                </GroupBox>

                <GroupBox Header="2. Selecciona el archivo ISO de Windows" Grid.Row="2">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="IsoPathTextBox" Height="35" IsReadOnly="True"/>
                        <Button x:Name="SelectIsoButton" Content="Buscar ISO..." Grid.Column="1" Width="110" Background="#FF3B82F6"/>
                    </Grid>
                </GroupBox>
                
                <GroupBox Header="3. Opciones de Proceso" Grid.Row="3">
                    <StackPanel>
                        <CheckBox x:Name="AutomateInstallCheckBox" Content="Automatizar y Personalizar Instalación" Margin="5,5,5,10" Foreground="White"/>
                        
                        <Grid x:Name="AutomationDetailsPanel" Visibility="Collapsed" Margin="20,0,5,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <TextBlock Text="Nombre de Usuario:" Grid.Row="0" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,10,5"/>
                            <TextBox x:Name="txtUsername" Grid.Row="0" Grid.Column="1" Margin="0,0,0,5" Text="Usuario"/>

                            <TextBlock Text="Contraseña:" Grid.Row="1" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,10,5"/>
                            <PasswordBox x:Name="pwdPassword" Grid.Row="1" Grid.Column="1" Margin="0,0,0,5"/>
                            
                            <TextBlock Text="Clave de Producto (Opcional):" Grid.Row="2" Grid.Column="0" VerticalAlignment="Center" Margin="0,5,10,5"/>
                            <TextBox x:Name="txtProductKey" Grid.Row="2" Grid.Column="1" Margin="0,5,0,5" />
                            
                            <TextBlock Text="Idioma y Región:" Grid.Row="3" Grid.Column="0" VerticalAlignment="Center" Margin="0,5,10,5"/>
                            <ComboBox x:Name="cmb_Locale" Grid.Row="3" Grid.Column="1" Margin="0,5,0,5" />
                            
                            <CheckBox x:Name="chk_BypassTPM" Content="Omitir revisión de TPM 2.0 y CPU" Grid.Row="4" Grid.ColumnSpan="2" Margin="0,10,0,0" IsChecked="True" Foreground="White"/>
                            <CheckBox x:Name="chk_BypassSecureBoot" Content="Omitir revisión de Secure Boot" Grid.Row="5" Grid.ColumnSpan="2" Margin="0,5,0,0" IsChecked="True" Foreground="White"/>
                            <CheckBox x:Name="chk_SkipWifi" Content="Omitir configuración de Wi-Fi" Grid.Row="6" Grid.ColumnSpan="2" Margin="0,5,0,0" IsChecked="True" Foreground="White"/>
                            <CheckBox x:Name="chk_SkipPostInstallOOBE" Content="Omitir configuración final (OOBE) e ir al escritorio" Grid.Row="7" Grid.ColumnSpan="2" Margin="0,5,0,10" IsChecked="True" Foreground="White"/>

                        </Grid>

                        <TextBlock x:Name="AutomationWarningTextBlock" Text="AVISO: La automatización omitirá las pantallas de configuración. Aún deberás seleccionar el disco de instalación manualmente." Foreground="#FFD1D5DB" FontWeight="Normal" TextWrapping="Wrap" Visibility="Collapsed"/>
                        <Button x:Name="CreateButton" Content="Crear Arranque de Instalación" Background="#FF3B82F6"/>
                        <Button x:Name="UndoButton" Content="Eliminar Arranque y Partición" Background="#FF374151"/>
                    </StackPanel>
                </GroupBox>

                <GroupBox Header="Progreso y Estado" Grid.Row="4" Margin="0,10,0,0">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <TextBlock x:Name="StatusTextBlock" Text="Listo. Esperando instrucciones." TextWrapping="Wrap" VerticalAlignment="Center" HorizontalAlignment="Center" FontSize="14"/>
                        <ProgressBar x:Name="ProgressBar" Grid.Row="1" Height="8" Margin="5" Background="#FF1F2937" BorderBrush="#FF374151" BorderThickness="1"/>
                    </Grid>
                </GroupBox>
            </Grid>
        </ScrollViewer>
    </Grid>
</Window>
"@
#endregion

#region --- GUI Creation and Variable Initialization ---
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- Controles ---
$diskComboBox = $window.FindName("DiskComboBox")
$isoPathTextBox = $window.FindName("IsoPathTextBox")
$selectIsoButton = $window.FindName("SelectIsoButton")
$createButton = $window.FindName("CreateButton")
$undoButton = $window.FindName("UndoButton")
$statusTextBlock = $window.FindName("StatusTextBlock")
$progressBar = $window.FindName("ProgressBar")
$automateInstallCheckBox = $window.FindName("AutomateInstallCheckBox")
$automationWarningTextBlock = $window.FindName("AutomationWarningTextBlock")
$automationDetailsPanel = $window.FindName("AutomationDetailsPanel")
$txtUsername = $window.FindName("txtUsername")
$pwdPassword = $window.FindName("pwdPassword")
$txtProductKey = $window.FindName("txtProductKey")
$chk_BypassTPM = $window.FindName("chk_BypassTPM")
$chk_BypassSecureBoot = $window.FindName("chk_BypassSecureBoot")
$cmb_Locale = $window.FindName("cmb_Locale")
$chk_SkipWifi = $window.FindName("chk_SkipWifi")
$chk_SkipPostInstallOOBE = $window.FindName("chk_SkipPostInstallOOBE")

# --- Global variables & Constantes ---
$Global:PartitionLabel = "WinDeployBS"
$Global:RglFileName = "WinDeploy.log"
$locales = @("es-ES", "en-US", "es-MX", "fr-FR", "de-DE")
#endregion

#region --- Helper Functions ---

function Sync-Gui {
    param($action)
    if ($window.Dispatcher.CheckAccess()) {
        $action.Invoke()
    } else {
        $window.Dispatcher.Invoke($action)
    }
}

function Set-DeployUiState {
    param([bool]$isEnabled)
    Sync-Gui -action {
        $diskComboBox.IsEnabled = $isEnabled
        $selectIsoButton.IsEnabled = $isEnabled
        $createButton.IsEnabled = $isEnabled
        $automateInstallCheckBox.IsEnabled = $isEnabled
        if ($isEnabled) {
            Update-UndoButtonState
        } else {
            $undoButton.IsEnabled = $false
        }
    }
}

function Show-MessageBox {
    param(
        [string]$message,
        [string]$title,
        [string]$icon = "Information",
        [string]$buttons = "OK"
    )
    return [System.Windows.MessageBox]::Show($window, $message, $title, $buttons, $icon)
}

function Load-Disks {
    try {
        $currentSelection = $diskComboBox.SelectedItem
        $diskComboBox.Items.Clear()
        
        $physicalDisks = Get-Disk | Where-Object { $_.BusType -ne 'USB' -and $_.PartitionStyle -ne 'RAW' }
        if (-not $physicalDisks) {
            Show-MessageBox "No se detectaron discos duros internos." "Error Crítico" "Error"
            return
        }

        $partitions = $physicalDisks | Get-Partition | Where-Object { $_.DriveLetter -and $_.Type -ne 'Recovery' }
        if (-not $partitions) {
            Show-MessageBox "No se encontraron particiones con letra de unidad en los discos internos." "No se encontraron particiones" "Warning"
            return
        }

        foreach ($partition in $partitions) {
            $size = "{0:N2} GB" -f ($partition.Size / 1GB)
            $freeSpace = "{0:N2} GB" -f ((Get-Volume -DriveLetter $partition.DriveLetter).SizeRemaining / 1GB)
            $item = "{0}:\ ({1}) - {2} Libres" -f $partition.DriveLetter, $size, $freeSpace
            $diskComboBox.Items.Add($item)
        }

        if ($diskComboBox.Items.Contains($currentSelection)) {
            $diskComboBox.SelectedItem = $currentSelection
        }
    } catch {
        Show-MessageBox "Ocurrió un error al cargar los discos: $($_.Exception.Message)." "Error de Carga" "Error"
    }
}

function Get-WinDeployPartition {
    try {
        return Get-Volume | Where-Object { $_.FileSystemLabel -eq $Global:PartitionLabel }
    } catch {
        return $null
    }
}

function Update-UndoButtonState {
    $windeployPartition = Get-WinDeployPartition
    Sync-Gui -Action {
        if ($windeployPartition) {
            $undoButton.IsEnabled = $true
            $undoButton.ToolTip = "Se encontró una partición de instalación en $($windeployPartition.DriveLetter):\."
        } else {
            $undoButton.IsEnabled = $false
            $undoButton.ToolTip = "No se encontró una partición de instalación existente."
        }
    }
}

function Get-BcdEditPath {
    # On a 32-bit process running on 64-bit Windows, System32 is redirected.
    # We must use the 'Sysnative' virtual folder to access the real 64-bit System32 folder.
    if ([System.Environment]::Is64BitOperatingSystem -and -not [System.Environment]::Is64BitProcess) {
        $sysnativePath = Join-Path $env:SystemRoot "Sysnative\bcdedit.exe"
        if (Test-Path $sysnativePath) {
            return $sysnativePath
        }
    }
    # Default for 64-bit process on 64-bit OS, or any process on 32-bit OS
    return Join-Path $env:SystemRoot "System32\bcdedit.exe"
}
#endregion

#region --- Event Handlers ---

$window.Add_SourceInitialized({
    Load-Disks
    Update-UndoButtonState
    $locales | ForEach-Object { $cmb_Locale.Items.Add($_) }
    $cmb_Locale.SelectedIndex = 0
})

$automateInstallCheckBox.Add_Checked({
    $automationWarningTextBlock.Visibility = "Visible"
    $automationDetailsPanel.Visibility = "Visible"
})

$automateInstallCheckBox.Add_Unchecked({
    $automationWarningTextBlock.Visibility = "Collapsed"
    $automationDetailsPanel.Visibility = "Collapsed"
})

$selectIsoButton.Add_Click({
    $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
    $openFileDialog.Filter = "Archivos ISO (*.iso)|*.iso"
    $openFileDialog.Title = "Seleccionar archivo ISO de Windows"
    if ($openFileDialog.ShowDialog($window) -eq $true) {
        $isoPathTextBox.Text = $openFileDialog.FileName
    }
})

$createButton.Add_Click({
    # --- Validations ---
    if ([string]::IsNullOrWhiteSpace($diskComboBox.SelectedItem)) {
        Show-MessageBox "Por favor, selecciona un disco de la lista." "Selección Requerida" "Warning"
        return
    }
    if ([string]::IsNullOrWhiteSpace($isoPathTextBox.Text) -or -not (Test-Path $isoPathTextBox.Text)) {
        Show-MessageBox "Por favor, selecciona un archivo ISO válido." "Archivo Requerido" "Warning"
        return
    }

    $selectedDiskInfo = $diskComboBox.SelectedItem
    $driveLetter = $selectedDiskInfo.Split(":")[0]
    $isoPath = $isoPathTextBox.Text
    $shouldAutomate = $automateInstallCheckBox.IsChecked

    try {
        $isoSize = (Get-Item $isoPath).Length
        $requiredSpaceGB = [Math]::Ceiling($isoSize / 1GB) + 2 # ISO size + 2GB buffer
        $volumeInfo = Get-Volume -DriveLetter $driveLetter
        $availableSpaceGB = $volumeInfo.SizeRemaining / 1GB

        if ($availableSpaceGB -lt $requiredSpaceGB) {
            Show-MessageBox ("No hay suficiente espacio en la unidad {0}:\. Se necesitan al menos {1} GB." -f $driveLetter, $requiredSpaceGB) "Espacio Insuficiente" "Error"
            return
        }
    } catch {
        Show-MessageBox "Error al verificar el espacio en disco: $($_.Exception.Message)" "Error" "Error"
        return
    }

    $confirmationMessage = "ADVERTENCIA: Se va a modificar la estructura de tu disco y el menú de arranque. Asegúrate de tener un respaldo de tus datos importantes. ¿Deseas continuar?"
    
    $confirmationResult = Show-MessageBox $confirmationMessage "Confirmación Final" "Warning" "YesNo"
    if ($confirmationResult -ne "Yes") {
        Sync-Gui -Action { $statusTextBlock.Text = "Operación cancelada por el usuario." }
        return
    }

    # --- Start Process in Background Job ---
    Set-DeployUiState -isEnabled $false
    Sync-Gui -Action { 
        $progressBar.IsIndeterminate = $true
        $statusTextBlock.Text = "Iniciando proceso..."
    }

    # Recoger valores de los nuevos campos
    $username = $txtUsername.Text
    $password = $pwdPassword.Password
    $productKey = $txtProductKey.Text
    $bypassTPM = $chk_BypassTPM.IsChecked
    $bypassSecureBoot = $chk_BypassSecureBoot.IsChecked
    $locale = $cmb_Locale.SelectedItem
    $skipWifi = $chk_SkipWifi.IsChecked
    $skipPostInstallOOBE = $chk_SkipPostInstallOOBE.IsChecked
    $bcdeditPathForJob = Get-BcdEditPath

    $scriptBlock = {
        param($driveLetter, $isoPath, $requiredSpaceGB, $PartitionLabel, $RglFileName, $shouldAutomate, $username, $password, $productKey, $bypassTPM, $bypassSecureBoot, $locale, $skipWifi, $skipPostInstallOOBE, $bcdeditPath)
        
        $isoDriveLetter = $null
        $newDriveLetter = $null
        $osLoaderGuid = $null
        $ramdiskGuid = $null

        function Get-IsUefiSystem {
            return (Test-Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State")
        }

        function Invoke-BcdEdit {
            param([string]$arguments)
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $bcdeditPath
            $processInfo.Arguments = $arguments
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            $process.WaitForExit()
            
            $output = $process.StandardOutput.ReadToEnd()
            $errorOutput = $process.StandardError.ReadToEnd()

            if ($process.ExitCode -ne 0) {
                throw "bcdedit falló. Comando: '$arguments'. Error: '$errorOutput'"
            }
            return $output
        }

        try {
            # Step 1: Shrink partition and create new one
            $partitionToShrink = Get-Partition | Where-Object { $_.DriveLetter -eq $driveLetter }
            $diskNumber = $partitionToShrink.DiskNumber
            $shrinkSizeInMB = [int]($requiredSpaceGB * 1024)
            
            $usedLetters = (Get-Volume).DriveLetter.ToString()
            $newDriveLetter = ([char[]](68..90) | Where-Object { $usedLetters -notcontains $_ })[0] # D to Z
            if (!$newDriveLetter) { throw "No hay letras de unidad disponibles." }

            $diskpartScript = @"
select disk $diskNumber
select partition $($partitionToShrink.PartitionNumber)
shrink desired=$shrinkSizeInMB
create partition primary
format fs=ntfs label="$PartitionLabel" quick
assign letter=$newDriveLetter
exit
"@
            $tempScriptPath = Join-Path $env:TEMP "diskpart-script.txt"
            $diskpartScript | Out-File -FilePath $tempScriptPath -Encoding ascii -Force
            
            $process = Start-Process diskpart -ArgumentList "/s `"$tempScriptPath`"" -Wait -PassThru -Verb RunAs
            if ($process.ExitCode -ne 0) { throw "DiskPart falló al crear la partición." }

            Start-Sleep -Seconds 3
            if (-not (Test-Path "${newDriveLetter}:\")) { throw "La nueva partición no fue encontrada después de su creación."}

            # Step 2: Mount ISO and copy files
            $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru -ErrorAction Stop
            $isoDriveLetter = ($mountResult | Get-Volume).DriveLetter
            if (!$isoDriveLetter) { throw "No se pudo montar la imagen ISO." }
            
            $sourcePath = "${isoDriveLetter}:\"
            $destinationPath = "${newDriveLetter}:\"
            robocopy $sourcePath $destinationPath /E /R:3 /W:5 | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "Robocopy falló al copiar los archivos." }
            
            # Step 2.5: Create autounattend.xml if requested
            if ($shouldAutomate) {
                
                # --- Construcción de secciones opcionales del XML ---
                $productKeyXml = if (-not [string]::IsNullOrWhiteSpace($productKey)) { "<Key>$($productKey)</Key>" } else { "<Key></Key>" }

                $bypassCommandsXml = ""
                if ($bypassTPM) {
                    $bypassCommandsXml += @"
                    <RunSynchronousCommand wcm:action="add">
                        <Order>1</Order>
                        <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                    </RunSynchronousCommand>
"@
                }
                if ($bypassSecureBoot) {
                    $bypassCommandsXml += @"
                    <RunSynchronousCommand wcm:action="add">
                        <Order>2</Order>
                        <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                    </RunSynchronousCommand>
"@
                }

                $oobeSystemSettingsXml = ""
                if ($skipPostInstallOOBE) {
                    $hideWirelessXml = if($skipWifi) { "<HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>" } else { "" }
                    $oobeSystemSettingsXml = @"
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>$($locale)</InputLocale>
            <SystemLocale>$($locale)</SystemLocale>
            <UILanguage>$($locale)</UILanguage>
            <UserLocale>$($locale)</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                $($hideWirelessXml)
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value><![CDATA[$($password)]]></Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <Description>Cuenta de Administrador Local</Description>
                        <DisplayName>$($username)</DisplayName>
                        <Group>Administrators</Group>
                        <Name>$($username)</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
        </component>
    </settings>
"@
                }

                # --- Ensamblaje del XML Final ---
                $autounattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>$($locale)</UILanguage>
            </SetupUILanguage>
            <InputLocale>$($locale)</InputLocale>
            <SystemLocale>$($locale)</SystemLocale>
            <UILanguage>$($locale)</UILanguage>
            <UserLocale>$($locale)</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserData>
                <AcceptEula>true</AcceptEula>
                <ProductKey>
                    $($productKeyXml)
                </ProductKey>
            </UserData>
            <ImageInstall>
                <OSImage>
                    <WillShowUI>OnError</WillShowUI>
                </OSImage>
            </ImageInstall>
            <DiskConfiguration>
                <WillShowUI>Always</WillShowUI>
            </DiskConfiguration>
            <RunSynchronous>
                $($bypassCommandsXml)
            </RunSynchronous>
        </component>
    </settings>
$($oobeSystemSettingsXml)
</unattend>
"@
                $autounattendPath = Join-Path $destinationPath "autounattend.xml"
                $autounattendXml | Out-File -FilePath $autounattendPath -Encoding utf8
            }

            # Step 3: Create BCD entries
            $sdiPath = "\boot\boot.sdi"
            
            $ramdiskOutput = Invoke-BcdEdit "/create /d `"WinDeployBS`" /device"
            if ($ramdiskOutput -match '\{[a-fA-F0-9\-]+\}') { $ramdiskGuid = $matches[0] }
            if (!$ramdiskGuid) { throw "No se pudo crear la entrada del dispositivo Ramdisk en BCD." }
            
            Invoke-BcdEdit "/set $ramdiskGuid ramdisksdidevice `"partition=${newDriveLetter}:`""
            Invoke-BcdEdit "/set $ramdiskGuid ramdisksdipath `"$sdiPath`""

            $osLoaderOutput = Invoke-BcdEdit "/create /d `"WinDeploy`" /application osloader"
            if ($osLoaderOutput -match '\{[a-fA-F0-9\-]+\}') { $osLoaderGuid = $matches[0] }
            if (!$osLoaderGuid) { throw "No se pudo crear la entrada OSLoader en BCD." }

            $isUefi = Get-IsUefiSystem
            $winloadPath = if ($isUefi) { "\windows\system32\boot\winload.efi" } else { "\windows\system32\winload.exe" }

            Invoke-BcdEdit "/set $osLoaderGuid device `"ramdisk=[${newDriveLetter}:]\sources\boot.wim,$ramdiskGuid`""
            Invoke-BcdEdit "/set $osLoaderGuid path `"$winloadPath`""
            Invoke-BcdEdit "/set $osLoaderGuid osdevice `"ramdisk=[${newDriveLetter}:]\sources\boot.wim,$ramdiskGuid`""
            Invoke-BcdEdit "/set $osLoaderGuid systemroot `"\windows`""
            Invoke-BcdEdit "/set $osLoaderGuid winpe `"yes`""
            
            Invoke-BcdEdit "/displayorder $osLoaderGuid /addlast"
            Invoke-BcdEdit "/bootsequence $osLoaderGuid"
            Invoke-BcdEdit "/timeout 10"

            # Step 4: Create log file for undo
            $rglContent = @{
                OriginalPartitionNumber = $partitionToShrink.PartitionNumber
                DiskNumber = $diskNumber
                OsLoaderGuid = $osLoaderGuid
                RamdiskGuid = $ramdiskGuid
            } | ConvertTo-Json
            
            $rglPath = Join-Path "${newDriveLetter}:\" $RglFileName
            $rglContent | Out-File -FilePath $rglPath -Encoding utf8

            return "¡Arranque creado! Reinicia para acceder al instalador de Windows."
        } catch {
            # Cleanup on failure
            if ($newDriveLetter -and (Test-Path "${newDriveLetter}:\")) {
                $diskpartRevertScript = "select volume $newDriveLetter`ndelete volume override`n"
                $tempRevertPath = Join-Path $env:TEMP "diskpart-revert.txt"
                $diskpartRevertScript | Out-File -FilePath $tempRevertPath -Encoding ascii -Force
                Start-Process diskpart -ArgumentList "/s `"$tempRevertPath`"" -Wait -PassThru -Verb RunAs | Out-Null
            }
            if ($osLoaderGuid) { try { Invoke-BcdEdit "/delete $osLoaderGuid /f" } catch {} }
            if ($ramdiskGuid) { try { Invoke-BcdEdit "/delete $ramdiskGuid /f" } catch {} }

            throw "ERROR: $($_.Exception.Message)"
        } finally {
            if ($isoDriveLetter) {
                Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
            }
        }
    }

    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $driveLetter, $isoPath, $requiredSpaceGB, $Global:PartitionLabel, $Global:RglFileName, $shouldAutomate, $username, $password, $productKey, $bypassTPM, $bypassSecureBoot, $locale, $skipWifi, $skipPostInstallOOBE, $bcdeditPathForJob
    
    $job | Wait-Job
    $result = $job | Receive-Job
    
    if ($job.State -eq 'Failed') {
        $errorMessage = $job.ChildJobs[0].Error.Exception.Message
        Show-MessageBox "Ocurrió un error durante el proceso: $errorMessage" "Error Crítico" "Error"
        Sync-Gui -Action { $statusTextBlock.Text = "El proceso falló. Revisa los detalles del error." }
    } else {
        Show-MessageBox $result "Proceso Finalizado" "Information"
        Sync-Gui -Action { 
            $statusTextBlock.Text = "¡Éxito! Cierra esta ventana y reinicia para comenzar la instalación."
        }
    }
    
    Sync-Gui -Action { $progressBar.IsIndeterminate = $false; $progressBar.Value = 100 }
    $job | Remove-Job
    Set-DeployUiState -isEnabled $true
})

$undoButton.Add_Click({
    $windeployPartition = Get-WinDeployPartition
    if (!$windeployPartition) {
        Show-MessageBox "No se encontró ninguna partición '$($Global:PartitionLabel)' para eliminar." "No Encontrado" "Information"
        return
    }

    $confirmationResult = Show-MessageBox ("Se eliminará la partición de instalación y su entrada de arranque. ¿Estás seguro?") "Confirmar Eliminación" "Warning" "YesNo"
    if ($confirmationResult -ne "Yes") { return }

    Set-DeployUiState -isEnabled $false
    Sync-Gui -Action { 
        $progressBar.IsIndeterminate = $true
        $statusTextBlock.Text = "Eliminando partición y arranque..."
    }

    try {
        $rglPath = Join-Path ($windeployPartition.DriveLetter + ":\") $Global:RglFileName
        if (-not (Test-Path $rglPath)) {
            throw "No se encontró el archivo de registro ($Global:RglFileName). No se puede deshacer automáticamente."
        }
        $rglContent = Get-Content -Path $rglPath | ConvertFrom-Json
        
        $bcdeditPath = Get-BcdEditPath
        if ($rglContent.OsLoaderGuid) { & $bcdeditPath /delete $rglContent.OsLoaderGuid /f | Out-Null }
        if ($rglContent.RamdiskGuid) { & $bcdeditPath /delete $rglContent.RamdiskGuid /f | Out-Null }
        
        $diskNumber = $rglContent.DiskNumber
        $partitionToExtendNumber = $rglContent.OriginalPartitionNumber
        
        $diskpartScript = @"
select volume $($windeployPartition.DriveLetter)
delete volume override
select disk $diskNumber
select partition $partitionToExtendNumber
extend
"@
        $tempScriptPath = Join-Path $env:TEMP "diskpart-undo.txt"
        $diskpartScript | Out-File -FilePath $tempScriptPath -Encoding ascii -Force
        $process = Start-Process diskpart -ArgumentList "/s `"$tempScriptPath`"" -Wait -PassThru -Verb RunAs
        if ($process.ExitCode -ne 0) { throw "DiskPart falló al eliminar la partición." }

        Show-MessageBox "La partición y el arranque han sido eliminados correctamente." "Éxito" "Information"
        Sync-Gui -Action { $statusTextBlock.Text = "Listo. Cambios deshechos." }

    } catch {
        Show-MessageBox "Ocurrió un error: $($_.Exception.Message)" "Error" "Error"
        Sync-Gui -Action { $statusTextBlock.Text = "Falló el proceso de eliminación." }
    } finally {
        Set-DeployUiState -isEnabled $true
        Sync-Gui -Action { $progressBar.IsIndeterminate = $false; $progressBar.Value = 100 }
        Load-Disks
    }
})

#endregion

# --- Show Window ---
$window.ShowDialog() | Out-Null
