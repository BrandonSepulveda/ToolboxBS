<#
.SYNOPSIS
    Crea una partición de arranque con los archivos de instalación de Windows modificando el BCD.

.DESCRIPTION
    Este script crea una nueva partición, copia el contenido del ISO de Windows y añade una
    opción en el menú de arranque para iniciar el Instalador de Windows al reiniciar. Esto permite una
    verdadera instalación limpia, incluyendo el formateo de la unidad principal del sistema.

.NOTES
    Autor: Brandon Sepulveda (Lógica de BCD corregida por Gemini)
    Version: 6.4 (Final Version - Reboot Button Removed)
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
Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinDeploy by: Brandon Sepulveda" Height="540" Width="520"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#FF111827" Foreground="White" FontFamily="Segoe UI">
    <Window.Resources>
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
    </Window.Resources>
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,25">
            <TextBlock Text="WinDeploy" FontSize="28" FontWeight="Bold" Foreground="White"/>
            <TextBlock Text="by: Brandon Sepulveda" FontSize="14" Foreground="#FF9CA3AF" Margin="0,0,0,10"/>
            <TextBlock Text="Crea una partición de arranque para formatear e instalar Windows." TextWrapping="Wrap" Foreground="#FFD1D5DB"/>
        </StackPanel>

        <Grid Grid.Row="1" Margin="0,0,0,15">
            <StackPanel>
                <Label Content="1. Selecciona el Disco Principal a modificar:" Foreground="White"/>
                <ComboBox x:Name="DiskComboBox" Height="30" VerticalContentAlignment="Center"/>
            </StackPanel>
        </Grid>

        <Grid Grid.Row="2" Margin="0,0,0,20">
             <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel>
                <Label Content="2. Selecciona el archivo ISO de Windows:" Foreground="White"/>
                <TextBox x:Name="IsoPathTextBox" Height="30" IsReadOnly="True" VerticalContentAlignment="Center" Background="#FF1F2937" BorderBrush="#FF374151"/>
            </StackPanel>
            <Button x:Name="SelectIsoButton" Content="Buscar ISO..." Grid.Column="1" Height="30" Width="100" Margin="10,24,0,0" VerticalAlignment="Top" Background="#FF3B82F6"/>
        </Grid>
        
        <GroupBox Header="Opciones de Proceso" Grid.Row="3" Foreground="White" BorderBrush="#FF374151">
            <StackPanel Margin="10,5">
                <Button x:Name="CreateButton" Content="Crear Arranque de Instalación" Background="#FF3B82F6"/>
                <Button x:Name="UndoButton" Content="Eliminar Arranque y Partición" Background="#FF374151"/>
            </StackPanel>
        </GroupBox>

        <GroupBox Header="Progreso y Estado" Grid.Row="4" Margin="0,10,0,0" Foreground="White" BorderBrush="#FF374151">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock x:Name="StatusTextBlock" Text="Listo. Esperando instrucciones." TextWrapping="Wrap" VerticalAlignment="Center" HorizontalAlignment="Center" Margin="10" FontSize="14"/>
                <ProgressBar x:Name="ProgressBar" Grid.Row="1" Height="8" Margin="5" Background="#FF1F2937" BorderBrush="#FF374151" BorderThickness="1"/>
            </Grid>
        </GroupBox>
    </Grid>
</Window>
"@
#endregion

#region --- GUI Creation and Variable Initialization ---
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI Elements
$diskComboBox = $window.FindName("DiskComboBox")
$isoPathTextBox = $window.FindName("IsoPathTextBox")
$selectIsoButton = $window.FindName("SelectIsoButton")
$createButton = $window.FindName("CreateButton")
$undoButton = $window.FindName("UndoButton")
$statusTextBlock = $window.FindName("StatusTextBlock")
$progressBar = $window.FindName("ProgressBar")

# Global variables
$Global:PartitionLabel = "WinDeployBS"
$Global:RglFileName = "WinDeploy.log"
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

function Set-UiState {
    param([bool]$isEnabled)
    Sync-Gui -action {
        $diskComboBox.IsEnabled = $isEnabled
        $selectIsoButton.IsEnabled = $isEnabled
        $createButton.IsEnabled = $isEnabled
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
#endregion

#region --- Event Handlers ---

$window.Add_SourceInitialized({
    Load-Disks
    Update-UndoButtonState
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

    $confirmationResult = Show-MessageBox ("ADVERTENCIA: Se va a modificar la estructura de tu disco y el menú de arranque. Asegúrate de tener un respaldo de tus datos importantes. ¿Deseas continuar?" -f $driveLetter, $requiredSpaceGB) "Confirmación Final" "Warning" "YesNo"
    if ($confirmationResult -ne "Yes") {
        Sync-Gui -Action { $statusTextBlock.Text = "Operación cancelada por el usuario." }
        return
    }

    # --- Start Process in Background Job ---
    Set-UiState -isEnabled $false
    Sync-Gui -Action { 
        $progressBar.IsIndeterminate = $true
        $statusTextBlock.Text = "Iniciando proceso..."
    }

    $scriptBlock = {
        param($driveLetter, $isoPath, $requiredSpaceGB, $PartitionLabel, $RglFileName)
        
        $isoDriveLetter = $null
        $newDriveLetter = $null
        $osLoaderGuid = $null
        $ramdiskGuid = $null

        function Get-IsUefiSystem {
            # Comprueba una clave de registro que solo existe en sistemas UEFI.
            # Esto es más compatible que Get-FirmwareType para versiones antiguas de PowerShell.
            return (Test-Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State")
        }

        function Invoke-BcdEdit {
            param([string]$arguments)
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "bcdedit.exe"
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
            
            # Step 3: Create BCD entries (CORRECTED LOGIC)
            $sdiPath = "\boot\boot.sdi" # Standard path for WinPE
            
            # Create RAMDISK device entry
            $ramdiskOutput = Invoke-BcdEdit "/create /d `"WinDeployBS`" /device"
            if ($ramdiskOutput -match '\{[a-fA-F0-9\-]+\}') { $ramdiskGuid = $matches[0] }
            if (!$ramdiskGuid) { throw "No se pudo crear la entrada del dispositivo Ramdisk en BCD." }
            
            Invoke-BcdEdit "/set $ramdiskGuid ramdisksdidevice `"partition=${newDriveLetter}:`""
            Invoke-BcdEdit "/set $ramdiskGuid ramdisksdipath `"$sdiPath`""

            # Create OS Loader entry
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
            Invoke-BcdEdit "/bootsequence $osLoaderGuid" # Set to boot into this entry on next restart
            Invoke-BcdEdit "/timeout 10"

            # Step 4: Create log file for undo
            $rglContent = @{
                OriginalPartitionNumber = $partitionToShrink.PartitionNumber
                DiskNumber = $diskNumber
                OsLoaderGuid = $osLoaderGuid
                RamdiskGuid = $ramdiskGuid # Save the new GUID
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

    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $driveLetter, $isoPath, $requiredSpaceGB, $Global:PartitionLabel, $Global:RglFileName
    
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
    Set-UiState -isEnabled $true
})

$undoButton.Add_Click({
    $windeployPartition = Get-WinDeployPartition
    if (!$windeployPartition) {
        Show-MessageBox "No se encontró ninguna partición '$($Global:PartitionLabel)' para eliminar." "No Encontrado" "Information"
        return
    }

    $confirmationResult = Show-MessageBox ("Se eliminará la partición de instalación y su entrada de arranque. ¿Estás seguro?") "Confirmar Eliminación" "Warning" "YesNo"
    if ($confirmationResult -ne "Yes") { return }

    Set-UiState -isEnabled $false
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
        
        # Delete BCD entries
        if ($rglContent.OsLoaderGuid) { bcdedit /delete $rglContent.OsLoaderGuid /f | Out-Null }
        if ($rglContent.RamdiskGuid) { bcdedit /delete $rglContent.RamdiskGuid /f | Out-Null }
        
        # Delete partition and extend original
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
        Set-UiState -isEnabled $true
        Sync-Gui -Action { $progressBar.IsIndeterminate = $false; $progressBar.Value = 100 }
        Load-Disks
    }
})

#endregion

# --- Show Window ---
$window.ShowDialog() | Out-Null
