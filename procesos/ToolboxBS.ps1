<#
.NOTES

    ToolboxBS
    -----------------------------------------------------------------------------
    Author         : Jhon Brandon Sepulevda Valdes @brandonsepulveda_66
    GitHub         : https://github.com/BrandonSepulveda/Toolbox
    Version        : 2.0
    page           : https://brandonsepulveda.github.io

    MIT License

Copyright (c) 2023 Jhon Brandon Sepulveda Valdes

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>
# Verificar si se está ejecutando como administrador

$OutputEncoding = [System.Text.Encoding]::UTF8

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "ToolboxBS necesita ser ejecutado como Administrador. Intentando relanzar."
    $argList = @()

    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $argList += if ($_.Value -is [switch] -and $_.Value) {
            "-$($_.Key)"
        } elseif ($_.Value -is [array]) {
            "-$($_.Key) $($_.Value -join ',')"
        } elseif ($_.Value) {
            "-$($_.Key) '$($_.Value)'"
        }
    }

    $script = if ($PSCommandPath) {
        "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
    } else {
        "&([ScriptBlock]::Create((irm https://github.com/BrandonSepulveda/ToolboxBS/releases/latest/download/ToolboxBS.ps1))) $($argList -join ' ')"
    }

    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }

    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    } else {
        Start-Process $processCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    }

    break
}
Clear-Host
# Mostrar logo ASCII al inicio
Write-Host "                                                                                                    " -ForegroundColor Cyan
Write-Host "                                                                                                    " -ForegroundColor Cyan
Write-Host "      ####                                                                                 ###      " -ForegroundColor Cyan
Write-Host "        #######                                                                      #######        " -ForegroundColor Cyan
Write-Host "          #########                                                              #########          " -ForegroundColor Cyan
Write-Host "            ############                                                     ###########            " -ForegroundColor Cyan
Write-Host "              ##############                                             #############              " -ForegroundColor Cyan
Write-Host "               #################                                    #################               " -ForegroundColor Cyan
Write-Host "                 #################                                #################                 " -ForegroundColor Cyan
Write-Host "                  ################                                ################                  " -ForegroundColor Cyan
Write-Host "                   ####### ########          #        #          ######## #######                   " -ForegroundColor Cyan
Write-Host "                    ####### ########         ##      ##         ######## #######                    " -ForegroundColor Cyan
Write-Host "                     #######  #######        ####  ####        #######  #######                     " -ForegroundColor Cyan
Write-Host "                      ######   #########     ####  ####     #########   ######                      " -ForegroundColor Cyan
Write-Host "                       ######    ################  ################    ######                       " -ForegroundColor Cyan
Write-Host "                        ######    ###############  ###############    ######                        " -ForegroundColor Cyan
Write-Host "                         #####      #############  #############      #####                         " -ForegroundColor Cyan
Write-Host "                         ##########   ###########  ###########   ##########                         " -ForegroundColor Cyan
Write-Host "                           ############ #########  ######### ############                           " -ForegroundColor Cyan
Write-Host "                                   ####### ######  ###### #######                                   " -ForegroundColor Cyan
Write-Host "                                       #####  ###  ###  #####                                       " -ForegroundColor Cyan
Write-Host "                                          ###          ###                                          " -ForegroundColor Cyan
Write-Host "                                            ###      ###                                            " -ForegroundColor Cyan
Write-Host "                                              ##    ##                                              " -ForegroundColor Cyan
Write-Host "                                                                                                    " -ForegroundColor Cyan
Start-Sleep -Seconds 1


# =======================================================================
# ████████╗ ██████╗  ██████╗ ██╗     ██████╗  ██████╗ ██╗  ██╗██████╗ ███████╗
# ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔══██╗██╔═══██╗╚██╗██╔╝██╔══██╗██╔════╝
#    ██║   ██║   ██║██║   ██║██║     ██████╔╝██║   ██║ ╚███╔╝ ██████╔╝███████╗
#    ██║   ██║   ██║██║   ██║██║     ██╔══██╗██║   ██║ ██╔██╗ ██╔══██╗╚════██║
#    ██║   ╚██████╔╝╚██████╔╝███████╗██████╔╝╚██████╔╝██╔╝ ██╗██████╔╝███████║
#    ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝
# =======================================================================
# Complemento para ToolboxBS - by BrandonSepulveda
# Versión 1.0.0
# =======================================================================
# Configuración inicial
$Host.UI.RawUI.WindowTitle = "ToolboxBS - Sistema Analyzer & Optimizer"
$ErrorActionPreference = "SilentlyContinue"


# Set PowerShell window title
$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Admin)"


Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms


$transcriptFolder = "$env:USERPROFILE\Temp\ToolboxBS_Logs"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$transcriptFileName = Join-Path $transcriptFolder "ToolboxBS_Session_$timestamp.log"

# Crear carpeta de forma silenciosa
[System.IO.Directory]::CreateDirectory($transcriptFolder) | Out-Null

# Iniciar transcripción 
Start-Transcript -Path $transcriptFileName -Append | Out-Null

# Mostrar solo un mensaje confirmando que el registro está activo
Write-Host "Registro de sesión activo en: $transcriptFileName" -ForegroundColor Cyan

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="ToolboxBS By: Brandon Sepulveda"
    Height="550"
    Width="800"
    WindowStartupLocation="CenterScreen"
    Background="Transparent"
    AllowsTransparency="True"
    WindowStyle="None"
    ResizeMode="CanResizeWithGrip">

    <Window.Resources>
        <!-- Estilo para botones de navegación -->
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#333333"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Estilo para botón de cierre -->
        <Style x:Key="CloseButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="30"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="15">
                            <TextBlock Text="X" FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#E81123"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Estilo para botón de maximizar/restaurar -->
        <Style x:Key="MaxRestoreButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="30"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="15">
                            <TextBlock Name="MaxRestoreIcon" Text="[ ]" FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#666666"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Estilo para botón de minimizar -->
        <Style x:Key="MinimizeButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="30"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="15">
                            <TextBlock Text="_" FontSize="14" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#666666"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Border Name="MainBorder" CornerRadius="10" Background="#121212">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="70"/> <!-- Barra superior -->
                <RowDefinition Height="*"/>  <!-- Contenido principal -->
            </Grid.RowDefinitions>

            <!-- Barra de navegación superior mejorada -->
            <Border Name="TopNavBar" Grid.Row="0" Background="#1e1e1e" CornerRadius="10,10,0,0">
                <Border.Effect>
                    <DropShadowEffect ShadowDepth="2" BlurRadius="5" Color="Black" Opacity="0.5"/>
                </Border.Effect>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/> <!-- Logo y título -->
                        <ColumnDefinition Width="*"/> <!-- Espacio central -->
                        <ColumnDefinition Width="Auto"/> <!-- Botones de navegación -->
                        <ColumnDefinition Width="Auto"/> <!-- Botones de control de ventana -->
                    </Grid.ColumnDefinitions>

                    <!-- Logo y título -->
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
                        <Border CornerRadius="5" Background="#2196F3" Width="45" Height="45">
                            <Image Name="LogoImage" Width="40" Height="40" Margin="0" RenderOptions.BitmapScalingMode="HighQuality"/>
                        </Border>
                        <StackPanel Orientation="Vertical" Margin="15,0,0,0" VerticalAlignment="Center">
                            <TextBlock Text="TOOLBOXBS" 
                                      Foreground="#2196F3"
                                      FontSize="20"
                                      FontWeight="Bold"/>
                            <TextBlock Text="By: Brandon Sepulveda" 
                                      Foreground="#999999"
                                      FontSize="12"
                                      FontStyle="Italic"/>
                        </StackPanel>
                    </StackPanel>

                    <!-- Menú de navegación (MODIFICADO) -->
                    <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,20,0">
                        <Button Name="HomeBtn" Content="Inicio" Style="{StaticResource NavButtonStyle}"/>
                        <Button Name="ToolsBtn" Content="Herramientas" Style="{StaticResource NavButtonStyle}"/>
                        <Button Name="AboutBtn" Content="Sobre" Style="{StaticResource NavButtonStyle}"/>
                        <Button Name="DocumentationBtn" Content="Documentación" Style="{StaticResource NavButtonStyle}"/>
                        <Button Name="ConfigBtn" Content="Configuración" Style="{StaticResource NavButtonStyle}"/>
                    </StackPanel>
                    
                    <!-- Botones de control de ventana -->
                    <StackPanel Grid.Column="3" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,10,0">
                        <Button Name="MinimizeButton" Style="{StaticResource MinimizeButtonStyle}" Margin="0,0,5,0"/>
                        <Button Name="MaxRestoreButton" Style="{StaticResource MaxRestoreButtonStyle}" Margin="0,0,5,0"/>
                        <Button Name="CloseButton" Style="{StaticResource CloseButtonStyle}"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- Contenido con botones principales -->
            <Grid Grid.Row="1" Margin="0,20,0,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <!-- Título de sección -->
                <TextBlock Grid.Row="0" Name="TitleBlock" Text="Herramientas Disponibles" 
          Foreground="White" 
          FontSize="18" 
          FontWeight="Medium" 
          HorizontalAlignment="Center"
          Margin="0,0,0,20"/>
                
                <!-- Panel de botones con mejor estilo -->
                <WrapPanel Grid.Row="1" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <Button Name="Btn1" Width="130" Height="110" Margin="10" Background="#2d2d2d" BorderBrush="#3a3a3a">
                        <StackPanel>
                            <TextBlock Text="&#xE950;" FontFamily="Segoe MDL2 Assets" FontSize="32" Foreground="#2196F3" HorizontalAlignment="Center" Margin="0,10,0,5"/>
                            <TextBlock Text="Info. Sistema" Foreground="White" HorizontalAlignment="Center" Margin="0,5"/>
                            <TextBlock Text="Datos del hardware y software" Foreground="#999999" FontSize="11" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="5"/>
                        </StackPanel>
                    </Button>
                    <Button Name="Btn2" Width="130" Height="110" Margin="10" Background="#2d2d2d" BorderBrush="#3a3a3a">
                        <StackPanel>
                            <TextBlock Text="&#xE896;" FontFamily="Segoe MDL2 Assets" FontSize="32" Foreground="#2196F3" HorizontalAlignment="Center" Margin="0,10,0,5"/>
                            <TextBlock Text="Descargas Apps" Foreground="White" HorizontalAlignment="Center" Margin="0,5"/>
                            <TextBlock Text="Instaladores de aplicaciones populares" Foreground="#999999" FontSize="11" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="5"/>
                        </StackPanel>
                    </Button>
                    <Button Name="Btn3" Width="130" Height="110" Margin="10" Background="#2d2d2d" BorderBrush="#3a3a3a">
                        <StackPanel>
                            <TextBlock Text="&#xE90F;" FontFamily="Segoe MDL2 Assets" FontSize="32" Foreground="#2196F3" HorizontalAlignment="Center" Margin="0,10,0,5"/>
                            <TextBlock Text="Reparacion" Foreground="White" HorizontalAlignment="Center" Margin="0,5"/>
                            <TextBlock Text="Reparacion y verificacion del sistema" Foreground="#999999" FontSize="11" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="5"/>
                        </StackPanel>
                    </Button>
                    <Button Name="Btn4" Width="130" Height="110" Margin="10" Background="#2d2d2d" BorderBrush="#3a3a3a">
                        <StackPanel>
                            <TextBlock Text="&#xE74C;" FontFamily="Segoe MDL2 Assets" FontSize="32" Foreground="#2196F3" HorizontalAlignment="Center" Margin="0,10,0,5"/>
                            <TextBlock Text="Tweaks" Foreground="White" HorizontalAlignment="Center" Margin="0,5"/>
                            <TextBlock Text="Tweaks y utilidades para optimizacion" Foreground="#999999" FontSize="11" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="5"/>
                        </StackPanel>
                    </Button>
                </WrapPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

# Código a añadir para manejar el botón Sobre (About)
$AboutBtn.Add_Click({
    # Crear ventana de Sobre la aplicación
    $aboutWindow = New-Object System.Windows.Window
    $aboutWindow.Title = "Sobre ToolboxBS"
    $aboutWindow.Width = 600
    $aboutWindow.Height = 450
    $aboutWindow.WindowStartupLocation = "CenterOwner"
    $aboutWindow.Owner = $window
    $aboutWindow.Background = "Transparent"
    $aboutWindow.AllowsTransparency = $true
    $aboutWindow.WindowStyle = "None"
    $aboutWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $aboutWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "SOBRE TOOLBOXBS"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $aboutWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
    # Contenido
    $contentGrid = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($contentGrid, 1)
    $mainGrid.Children.Add($contentGrid)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(20)
    $contentGrid.Children.Add($scrollViewer)
    
    # Panel de información
    $infoPanel = New-Object System.Windows.Controls.StackPanel
    $infoPanel.Margin = New-Object System.Windows.Thickness(10)
    $scrollViewer.Content = $infoPanel
    
    # Logo
    $logoImage = New-Object System.Windows.Controls.Image
    $logoImage.Width = 150
    $logoImage.Height = 150
    $logoImage.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $logoImage.HorizontalAlignment = "Center"
    
    # Cargar la imagen
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.UriSource = "https://github.com/BrandonSepulveda/ToolboxBS/blob/main/tool.png?raw=true"
    $bitmap.EndInit()
    $logoImage.Source = $bitmap
    $infoPanel.Children.Add($logoImage)
    
    # Título de la aplicación
    $appTitle = New-Object System.Windows.Controls.TextBlock
    $appTitle.Text = "ToolboxBS"
    $appTitle.FontSize = 24
    $appTitle.FontWeight = "Bold"
    $appTitle.Foreground = "#2196F3"
    $appTitle.HorizontalAlignment = "Center"
    $appTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $infoPanel.Children.Add($appTitle)
    
    # Descripción
    $descriptionBlock = New-Object System.Windows.Controls.TextBlock
    $descriptionBlock.Text = "ToolboxBS es una herramienta de optimización y mantenimiento para sistemas Windows. Proporciona una interfaz amigable para ejecutar tareas comunes de mantenimiento y optimización del sistema."
    $descriptionBlock.Foreground = "White"
    $descriptionBlock.TextWrapping = "Wrap"
    $descriptionBlock.TextAlignment = "Center"
    $descriptionBlock.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $infoPanel.Children.Add($descriptionBlock)
    
    # Información del autor en un borde con estilo
    $authorBorder = New-Object System.Windows.Controls.Border
    $authorBorder.Background = "#1e1e1e"
    $authorBorder.BorderBrush = "#2196F3"
    $authorBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $authorBorder.CornerRadius = New-Object System.Windows.CornerRadius(5)
    $authorBorder.Padding = New-Object System.Windows.Thickness(15)
    $authorBorder.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)
    $infoPanel.Children.Add($authorBorder)
    
    $authorPanel = New-Object System.Windows.Controls.StackPanel
    $authorBorder.Child = $authorPanel
    
    # Autor
    $authorLabel = New-Object System.Windows.Controls.TextBlock
    $authorLabel.Text = "Autor"
    $authorLabel.FontWeight = "Bold"
    $authorLabel.Foreground = "#2196F3"
    $authorLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $authorPanel.Children.Add($authorLabel)
    
    $authorLink = New-Object System.Windows.Controls.TextBlock
    $authorLink.Inlines.Add((New-Object System.Windows.Documents.Run -Property @{
        Text = "Jhon Brandon Sepulveda Valdes"
        Foreground = "White"
    }))
    $authorLink.Cursor = "Hand"
    $authorLink.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $authorLink.Add_MouseLeftButtonDown({
        Start-Process "https://brandonsepulveda.github.io"
    })
    $authorLink.Add_MouseEnter({
        $this.TextDecorations = [System.Windows.TextDecorations]::Underline
        $this.Foreground = "#2196F3"
    })
    $authorLink.Add_MouseLeave({
        $this.TextDecorations = $null
        $this.Foreground = "White"
    })
    $authorPanel.Children.Add($authorLink)
    
    # GitHub
    $githubLabel = New-Object System.Windows.Controls.TextBlock
    $githubLabel.Text = "GitHub"
    $githubLabel.FontWeight = "Bold"
    $githubLabel.Foreground = "#2196F3"
    $githubLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $authorPanel.Children.Add($githubLabel)
    
    $githubLink = New-Object System.Windows.Controls.TextBlock
    $githubLink.Text = "github.com/BrandonSepulveda/ToolboxBS"
    $githubLink.Foreground = "White"
    $githubLink.Cursor = "Hand"
    $githubLink.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $githubLink.Add_MouseLeftButtonDown({
        Start-Process "https://github.com/BrandonSepulveda/ToolboxBS"
    })
    $githubLink.Add_MouseEnter({
        $this.TextDecorations = [System.Windows.TextDecorations]::Underline
        $this.Foreground = "#2196F3"
    })
    $githubLink.Add_MouseLeave({
        $this.TextDecorations = $null
        $this.Foreground = "White"
    })
    $authorPanel.Children.Add($githubLink)
    
    # Versión
    $versionLabel = New-Object System.Windows.Controls.TextBlock
    $versionLabel.Text = "Version"
    $versionLabel.FontWeight = "Bold"
    $versionLabel.Foreground = "#2196F3"
    $versionLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $authorPanel.Children.Add($versionLabel)
    
    $versionLink = New-Object System.Windows.Controls.TextBlock
    $versionLink.Text = "2.0"
    $versionLink.Foreground = "White"
    $versionLink.Cursor = "Hand"
    $versionLink.Add_MouseLeftButtonDown({
        Start-Process "https://github.com/BrandonSepulveda/ToolboxBS/releases/latest"
    })
    $versionLink.Add_MouseEnter({
        $this.TextDecorations = [System.Windows.TextDecorations]::Underline
        $this.Foreground = "#2196F3"
    })
    $versionLink.Add_MouseLeave({
        $this.TextDecorations = $null
        $this.Foreground = "White"
    })
    $authorPanel.Children.Add($versionLink)
    
    # Licencia
    $licenseBorder = New-Object System.Windows.Controls.Border
    $licenseBorder.Background = "#1e1e1e"
    $licenseBorder.BorderBrush = "#2196F3"
    $licenseBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $licenseBorder.CornerRadius = New-Object System.Windows.CornerRadius(5)
    $licenseBorder.Padding = New-Object System.Windows.Thickness(15)
    $infoPanel.Children.Add($licenseBorder)
    
    $licensePanel = New-Object System.Windows.Controls.StackPanel
    $licenseBorder.Child = $licensePanel
    
    $licenseLabel = New-Object System.Windows.Controls.TextBlock
    $licenseLabel.Text = "Licencia"
    $licenseLabel.FontWeight = "Bold"
    $licenseLabel.Foreground = "#2196F3"
    $licenseLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $licensePanel.Children.Add($licenseLabel)
    
    $licenseText = New-Object System.Windows.Controls.TextBlock
    $licenseText.Text = "MIT License - Copyright (c) 2023 Jhon Brandon Sepulveda Valdes"
    $licenseText.Foreground = "White"
    $licenseText.TextWrapping = "Wrap"
    $licensePanel.Children.Add($licenseText)
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $aboutWindow.DragMove()
    })

     # Mostrar ventana
     $aboutWindow.ShowDialog()
    })



# Cargar el XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)

    try {
        $iconPath = "$env:TEMP\toolboxbs_icon.ico"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/images/Logo-30.ico" -OutFile $iconPath

        # Convertir el ícono a ImageSource de WPF
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = New-Object System.Uri($iconPath)
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.EndInit()
        $bitmap.Freeze() # Importante para rendimiento en WPF

        # Intentar establecer el ícono de la ventana
        $window.Icon = $bitmap
    } catch {
        Write-Host "Error al establecer el ícono: $_" -ForegroundColor Yellow
    }
    # Obtener referencias a los botones de navegación
$homeBtn = $window.FindName("HomeBtn")
$toolsBtn = $window.FindName("ToolsBtn")
$configBtn = $window.FindName("ConfigBtn")
$aboutBtn = $window.FindName("AboutBtn")
$documentationBtn = $window.FindName("DocumentationBtn")

$documentationBtn.Add_Click({
    try {
        # Intentar abrir la documentación web directamente
        Start-Process "https://brandonsepulveda.github.io/Documentacion.html"
    } catch {
        # Mostrar mensaje de error si no se puede abrir
        [System.Windows.MessageBox]::Show(
            "No se pudo abrir la documentación web. Verifique su conexión a internet.", 
            "Error", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Error
        )
    }
})
# Manejador para el botón Inicio
$homeBtn.Add_Click({
    # Crear ventana emergente con estilos consistentes
    $homeMenuWindow = New-Object System.Windows.Window
    $homeMenuWindow.Title = "Menu de Inicio"
    $homeMenuWindow.Width = 300
    $homeMenuWindow.Height = 400
    $homeMenuWindow.WindowStartupLocation = "Manual"
    $homeMenuWindow.Owner = $window
    $homeMenuWindow.Background = "Transparent"
    $homeMenuWindow.AllowsTransparency = $true
    $homeMenuWindow.WindowStyle = "None"
    $homeMenuWindow.ResizeMode = "NoResize"
    $homeMenuWindow.Topmost = $true
    
    # Posicionar la ventana debajo del botón
    $btnPos = $homeBtn.PointToScreen([System.Windows.Point]::new(0, 0))
    $homeMenuWindow.Left = $btnPos.X
    $homeMenuWindow.Top = $btnPos.Y + $homeBtn.ActualHeight + 5
    
    # Contenedor principal
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(8)
    $mainBorder.Background = "#1e1e1e"
    $mainBorder.BorderBrush = "#3a3a3a"
    $mainBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    
    # Grid principal para poder tener la barra de título
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    $mainBorder.Child = $mainGrid
    
    # Barra de título con botón de cierre
    $titleBar = New-Object System.Windows.Controls.Grid
    $titleBar.Background = "#2d2d2d"
    $titleBar.Height = 30
    [System.Windows.Controls.Grid]::SetRow($titleBar, 0)
    
    # Título
    $titleText = New-Object System.Windows.Controls.TextBlock
    $titleText.Text = "Menu de Inicio"
    $titleText.Foreground = "White"
    $titleText.VerticalAlignment = "Center"
    $titleText.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
    $titleBar.Children.Add($titleText)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.Width = 25
    $closeBtn.Height = 25
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.VerticalAlignment = "Center"
    $closeBtn.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0)
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $homeMenuWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $titleBar.Children.Add($closeBtn)
    
    # Permitir arrastrar la ventana
    $titleBar.Add_MouseLeftButtonDown({
        $homeMenuWindow.DragMove()
    })
    
    $mainGrid.Children.Add($titleBar)
    
    # Contenido del menú
    $contentPanel = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($contentPanel, 1)
    $mainGrid.Children.Add($contentPanel)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(5)
    $contentPanel.Children.Add($scrollViewer)
    
    # Panel de opciones
    $menuPanel = New-Object System.Windows.Controls.StackPanel
    $scrollViewer.Content = $menuPanel
    
    # Agregar opciones
    $menuItems = @(
        @{
            Text = "Panel de Control"
            
            Action = { Start-Process "control.exe"; $homeMenuWindow.Close() }
        },
        @{
            Text = "Diagnostico Rapido"
            
            Action = { 
                try {
                    # Crear un informe de diagnóstico con elementos críticos del sistema
                    $diagnosticReport = New-Object System.Text.StringBuilder
                    $diagnosticReport.AppendLine("DIAGNÓSTICO RÁPIDO DEL SISTEMA") | Out-Null
                    $diagnosticReport.AppendLine("=============================") | Out-Null
                    $diagnosticReport.AppendLine("") | Out-Null
                    
                    # Verificar espacio en disco
                    $criticalDrives = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | Where-Object { 
                        ($_.FreeSpace / $_.Size) -lt 0.1 
                    }
                    
                    if ($criticalDrives) {
                        $diagnosticReport.AppendLine("⚠️ ALERTA: Poco espacio en disco") | Out-Null
                        foreach ($drive in $criticalDrives) {
                            $freeGB = [Math]::Round($drive.FreeSpace / 1GB, 2)
                            $totalGB = [Math]::Round($drive.Size / 1GB, 2)
                            $percentFree = [Math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
                            $diagnosticReport.AppendLine("   Unidad $($drive.DeviceID): $freeGB GB libres de $totalGB GB ($percentFree% libre)") | Out-Null
                        }
                        $diagnosticReport.AppendLine("") | Out-Null
                    }
                    
                    # Verificar uso de memoria
                    $os = Get-WmiObject -Class Win32_OperatingSystem
                    $memoryUsage = [Math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
                    
                    if ($memoryUsage -gt 80) {
                        $diagnosticReport.AppendLine("⚠️ ALERTA: Alto uso de memoria") | Out-Null
                        $diagnosticReport.AppendLine("   Uso actual: $memoryUsage%") | Out-Null
                        $diagnosticReport.AppendLine("") | Out-Null
                    }
                    
                    # Verificar servicios críticos
                    $criticalServices = @("wuauserv", "WinDefend", "MpsSvc")
                    $serviceStatus = @()
                    
                    foreach ($service in $criticalServices) {
                        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                        if ($svc -and $svc.Status -ne "Running") {
                            $serviceStatus += "$($svc.DisplayName) ($($svc.Status))"
                        }
                    }
                    
                    if ($serviceStatus.Count -gt 0) {
                        $diagnosticReport.AppendLine("⚠️ ALERTA: Servicios críticos detenidos") | Out-Null
                        foreach ($status in $serviceStatus) {
                            $diagnosticReport.AppendLine("   $status") | Out-Null
                        }
                        $diagnosticReport.AppendLine("") | Out-Null
                    }
                    
                    # Verificar actualizaciones pendientes
                    try {
                        $updateSession = New-Object -ComObject Microsoft.Update.Session
                        $updateSearcher = $updateSession.CreateUpdateSearcher()
                        $pendingUpdates = $updateSearcher.Search("IsInstalled=0").Updates.Count
                        
                        if ($pendingUpdates -gt 0) {
                            $diagnosticReport.AppendLine("⚠️ AVISO: Actualizaciones pendientes") | Out-Null
                            $diagnosticReport.AppendLine("   Hay $pendingUpdates actualizaciones pendientes") | Out-Null
                            $diagnosticReport.AppendLine("") | Out-Null
                        }
                    } catch {
                        # Error al buscar actualizaciones - omitir
                    }
                    
                    # Verificar eventos críticos del sistema
                    try {
                        $criticalEvents = Get-WinEvent -LogName System -MaxEvents 50 | 
                            Where-Object { $_.Level -eq 1 -or $_.Level -eq 2 } | 
                            Select-Object -First 5
                        
                        if ($criticalEvents.Count -gt 0) {
                            $diagnosticReport.AppendLine("⚠️ ALERTA: Eventos críticos recientes") | Out-Null
                            foreach ($event in $criticalEvents) {
                                $eventTime = $event.TimeCreated.ToString("dd/MM/yyyy HH:mm")
                                $diagnosticReport.AppendLine("   $eventTime - ID: $($event.Id) - $($event.ProviderName)") | Out-Null
                            }
                            $diagnosticReport.AppendLine("") | Out-Null
                        }
                    } catch {
                        # Error al obtener eventos - omitir
                    }
                    
                    # Si no hay problemas, indicarlo
                    if ($diagnosticReport.Length -eq 81) { # El encabezado tiene 81 caracteres
                        $diagnosticReport.AppendLine("✓ No se encontraron problemas críticos") | Out-Null
                        $diagnosticReport.AppendLine("  El sistema parece estar funcionando correctamente") | Out-Null
                    }
                    
                    # Agregar recomendaciones
                    $diagnosticReport.AppendLine("") | Out-Null
                    $diagnosticReport.AppendLine("RECOMENDACIONES:") | Out-Null
                    $diagnosticReport.AppendLine("- Para un análisis completo, use la función Info. Sistema") | Out-Null
                    $diagnosticReport.AppendLine("- Ejecute regularmente la función Mantenimiento del S.O.") | Out-Null
                    
                    # Mostrar el diagnóstico
                    [System.Windows.MessageBox]::Show(
                        $diagnosticReport.ToString(), 
                        "Diagnóstico del Sistema", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Information
                    )
                }
                catch {
                    [System.Windows.MessageBox]::Show(
                        "Error al realizar el diagnóstico: $_", 
                        "Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error
                    )
                }
                finally {
                    $homeMenuWindow.Close()
                }
            }
        },
        @{
            Text = "Ajustes de Windows"
            Action = { Start-Process "ms-settings:"; $homeMenuWindow.Close() }
        },
        @{
            Text = "Explorador de Archivos"
            Action = { Start-Process "explorer.exe"; $homeMenuWindow.Close() }
        },
        @{
            Text = "PowerShell"
        
            Action = { 
                # Intentar abrir PowerShell 7 primero, si no está disponible, abrir PowerShell 5
                $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
                if ($pwsh7Path) {
                    Start-Process $pwsh7Path
                } else {
                    # Usar PowerShell predeterminado
                    Start-Process "powershell.exe"
                }
                $homeMenuWindow.Close()
            }
        },
        @{
            Text = "Informacion del Sistema"
            
            Action = { Start-Process "msinfo32.exe"; $homeMenuWindow.Close() }
        },
        @{
            Text = "Instalar PowerShell 7"
            
            Action = {
                try {
                    # Cerrar la ventana de manera segura
                    if ($homeMenuWindow -ne $null) {
                        $homeMenuWindow.Dispatcher.Invoke([Action]{
                            if ($homeMenuWindow.IsOpen) {
                                $homeMenuWindow.Close()
                            }
                        })
                    }
                    
                    # Verificación detallada de PowerShell 7
                    $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
                    if ($pwsh7Path) {
                        [System.Windows.MessageBox]::Show(
                            "PowerShell 7 ya está instalado en: $pwsh7Path`n`nVersion: $((Get-Command pwsh).Version)",
                            "Instalación Existente",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Information)
                        return
                    }
                    
                    # Verificar si el usuario tiene permisos de administrador
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                    
                    if (-not $isAdmin) {
                        [System.Windows.MessageBox]::Show(
                            "Se requieren permisos de administrador para instalar PowerShell 7. Por favor, ejecuta la aplicación como administrador.",
                            "Permisos Insuficientes",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning)
                        return
                    }
                    
                    # Verificar Winget
                    $wingetInstalled = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
                    
                    if ($wingetInstalled) {
                        # Método de instalación con Winget
                        Write-Host "Intentando instalar PowerShell 7 con Winget..." -ForegroundColor Cyan
                        
                        $process = Start-Process winget -ArgumentList "install", "Microsoft.PowerShell", "--accept-source-agreements", "--accept-package-agreements", "-h" -PassThru -Wait
                        
                        if ($process.ExitCode -eq 0) {
                            [System.Windows.MessageBox]::Show(
                                "PowerShell 7 instalado correctamente.", 
                                "Instalación Completa", 
                                [System.Windows.MessageBoxButton]::OK, 
                                [System.Windows.MessageBoxImage]::Information)
                        } else {
                            [System.Windows.MessageBox]::Show(
                                "Error al instalar PowerShell 7 con Winget. Código de salida: " + $process.ExitCode, 
                                "Error de Instalación", 
                                [System.Windows.MessageBoxButton]::OK, 
                                [System.Windows.MessageBoxImage]::Error)
                        }
                    } else {
                        # Método de instalación directo con MSI
                        Write-Host "Winget no disponible. Descargando instalador MSI..." -ForegroundColor Yellow
                        
                        $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.9/PowerShell-7.3.9-win-x64.msi"
                        $msiPath = "$env:TEMP\PowerShell-7-win-x64.msi"
                        
                        try {
                            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
                            
                            $process = Start-Process msiexec -ArgumentList "/i `"$msiPath`" /qn /norestart" -PassThru -Wait
                            
                            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                                [System.Windows.MessageBox]::Show(
                                    "PowerShell 7 instalado correctamente.", 
                                    "Instalación Completa", 
                                    [System.Windows.MessageBoxButton]::OK, 
                                    [System.Windows.MessageBoxImage]::Information)
                            } else {
                                [System.Windows.MessageBox]::Show(
                                    "Error al instalar PowerShell 7. Código de salida: " + $process.ExitCode, 
                                    "Error de Instalación", 
                                    [System.Windows.MessageBoxButton]::OK, 
                                    [System.Windows.MessageBoxImage]::Error)
                            }
                        } catch {
                            [System.Windows.MessageBox]::Show(
                                "Error al descargar o instalar PowerShell 7: $_", 
                                "Error de Instalación", 
                                [System.Windows.MessageBoxButton]::OK, 
                                [System.Windows.MessageBoxImage]::Error)
                        }
                    }
                } catch {
                    [System.Windows.MessageBox]::Show(
                        "Error inesperado: $_", 
                        "Error", 
                        [System.Windows.MessageBoxButton]::OK, 
                        [System.Windows.MessageBoxImage]::Error)
                }
            }
        }
        
    )
    
    # Crear botones para cada opción
    foreach ($item in $menuItems) {
        $menuBtn = New-Object System.Windows.Controls.Button
        $menuBtn.Margin = New-Object System.Windows.Thickness(5)
        $menuBtn.Padding = New-Object System.Windows.Thickness(10, 8, 10, 8)
        $menuBtn.Background = "#2d2d2d"
        $menuBtn.BorderThickness = New-Object System.Windows.Thickness(0)
        $menuBtn.HorizontalAlignment = "Stretch"
        $menuBtn.HorizontalContentAlignment = "Left"
        $menuBtn.Cursor = "Hand"
        
        # Contenido del botón con icono
        $btnContent = New-Object System.Windows.Controls.StackPanel
        $btnContent.Orientation = "Horizontal"
        
        if ($item.Icon) {
            $iconBlock = New-Object System.Windows.Controls.TextBlock
            $iconBlock.Text = $item.Icon
            $iconBlock.VerticalAlignment = "Center"
            $iconBlock.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
            $iconBlock.FontSize = 16
            $iconBlock.Foreground = "White"  # Color blanco para los iconos
            $btnContent.Children.Add($iconBlock)
        }
        
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $item.Text
        $textBlock.VerticalAlignment = "Center"
        $textBlock.Foreground = "White"
        $textBlock.FontSize = 14
        $btnContent.Children.Add($textBlock)
        
        $menuBtn.Content = $btnContent
        
        # Evento Click
        $action = $item.Action
        $menuBtn.Add_Click($action)
        
        # Efectos hover
        $menuBtn.Add_MouseEnter({
            $this.Background = "#3a3a3a"
        })
        
        $menuBtn.Add_MouseLeave({
            $this.Background = "#2d2d2d"
        })
        
        $menuPanel.Children.Add($menuBtn)
    }
    
    # Asegurarse de que se cierre cuando pierde el foco
    $homeMenuWindow.Add_Deactivated({
        $this.Close()
    })
    
    # Asignar contenido y mostrar ventana
   # Asignar contenido
   $homeMenuWindow.Content = $mainBorder
    
   # Cambiar Show por ShowDialog
   $homeMenuWindow.ShowDialog()
})
# Manejador para el botón Herramientas
$toolsBtn.Add_Click({
    # Crear ventana emergente con estilos consistentes
    $toolsMenuWindow = New-Object System.Windows.Window
    $toolsMenuWindow.Title = "Menu de Herramientas"
    $toolsMenuWindow.Width = 350
    $toolsMenuWindow.Height = 450
    $toolsMenuWindow.WindowStartupLocation = "Manual"
    $toolsMenuWindow.Owner = $window
    $toolsMenuWindow.Background = "Transparent"
    $toolsMenuWindow.AllowsTransparency = $true
    $toolsMenuWindow.WindowStyle = "None"
    $toolsMenuWindow.ResizeMode = "NoResize"
    $toolsMenuWindow.Topmost = $true
    
    # Posicionar la ventana debajo del botón
    $btnPos = $toolsBtn.PointToScreen([System.Windows.Point]::new(0, 0))
    $toolsMenuWindow.Left = $btnPos.X
    $toolsMenuWindow.Top = $btnPos.Y + $toolsBtn.ActualHeight + 5
    
    # Contenedor principal
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(8)
    $mainBorder.Background = "#1e1e1e"
    $mainBorder.BorderBrush = "#3a3a3a"
    $mainBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    
    # Grid principal para poder tener la barra de título
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    $mainBorder.Child = $mainGrid
    
    # Barra de título con botón de cierre
    $titleBar = New-Object System.Windows.Controls.Grid
    $titleBar.Background = "#2d2d2d"
    $titleBar.Height = 30
    [System.Windows.Controls.Grid]::SetRow($titleBar, 0)
    
    # Título
    $titleText = New-Object System.Windows.Controls.TextBlock
    $titleText.Text = "Menu de Herramientas"
    $titleText.Foreground = "White"
    $titleText.VerticalAlignment = "Center"
    $titleText.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
    $titleBar.Children.Add($titleText)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.Width = 25
    $closeBtn.Height = 25
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.VerticalAlignment = "Center"
    $closeBtn.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0)
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $toolsMenuWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $titleBar.Children.Add($closeBtn)
    
    # Permitir arrastrar la ventana
    $titleBar.Add_MouseLeftButtonDown({
        $toolsMenuWindow.DragMove()
    })
    
    $mainGrid.Children.Add($titleBar)
    
    # Contenido del menú
    $contentPanel = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($contentPanel, 1)
    $mainGrid.Children.Add($contentPanel)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(5)
    $contentPanel.Children.Add($scrollViewer)
    
    # Panel de opciones
    $menuPanel = New-Object System.Windows.Controls.StackPanel
    $scrollViewer.Content = $menuPanel
    
    # Agregar opciones
    $menuItems = @(
        @{
            Text = "Ejecutar ToolboxBS"
            
            Action = {
                # Intentar abrir PowerShell 7 primero, si no está disponible, abrir PowerShell 5
                $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
                $scriptCommand = "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://brandonsepulveda.github.io/Tool | iex`""
                
                if ($pwsh7Path) {
                    Start-Process $pwsh7Path -ArgumentList $scriptCommand
                } else {
                    # Usar PowerShell predeterminado
                    Start-Process "powershell.exe" -ArgumentList $scriptCommand
                }
                
                $toolsMenuWindow.Close()
            }
        },
        @{
            Text = "Descargar Windows"
            
            Action = {
                # Intentar abrir PowerShell 7 primero, si no está disponible, abrir PowerShell 5
                $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
                $scriptCommand = "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/windows%20instalador.ps1 | iex`""
                
                if ($pwsh7Path) {
                    Start-Process $pwsh7Path -ArgumentList $scriptCommand
                } else {
                    # Usar PowerShell predeterminado
                    Start-Process "powershell.exe" -ArgumentList $scriptCommand
                }
                
                $toolsMenuWindow.Close()
            }
        },
        @{
            Text = "Ejecutar WinScript "
            
            Action = {
                # Intentar abrir PowerShell 7 primero, si no está disponible, abrir PowerShell 5
                $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
                $scriptCommand = "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://winscript.cc/irm | iex`""
                
                if ($pwsh7Path) {
                    Start-Process $pwsh7Path -ArgumentList $scriptCommand
                } else {
                    # Usar PowerShell predeterminado
                    Start-Process "powershell.exe" -ArgumentList $scriptCommand
                }
                
                $toolsMenuWindow.Close()
            }
        }, 
        
        @{
            Text = "Instalar Sentinel"
            
            Action = {
                # Definir ruta de descarga y carpetas temporales
                $downloadURL = "https://www.harddisksentinel.com/hdsentinel_pro_portable.zip"
                $downloadPath = [System.IO.Path]::Combine($env:TEMP, "HDSentinel.zip")
                $extractPath = [System.IO.Path]::Combine($env:TEMP, "HDSentinel")
                
                # Crear la carpeta de extracción si no existe
                if (-not (Test-Path -Path $extractPath)) {
                    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
                }
                
                Write-Host "Descargando Hard Disk Sentinel..." -ForegroundColor Yellow
                
                # Descargar el archivo
                try {
                    # Usando Invoke-WebRequest que muestra progreso automáticamente
                    $ProgressPreference = 'Continue'
                    Invoke-WebRequest -Uri $downloadURL -OutFile $downloadPath -UseBasicParsing
                    
                    # Verificar que el archivo se ha descargado correctamente
                    if (Test-Path -Path $downloadPath) {
                        $fileSize = (Get-Item -Path $downloadPath).Length / 1MB
                        Write-Host "Descarga completada exitosamente. Tamaño: $([Math]::Round($fileSize, 2)) MB" -ForegroundColor Green
                    } else {
                        Write-Host "Error: El archivo descargado no existe." -ForegroundColor Red
                        return
                    }
                }
                catch {
                    Write-Host "Error al descargar Hard Disk Sentinel: $_" -ForegroundColor Red
                    return
                }
                
                Write-Host "Extrayendo archivos..." -ForegroundColor Yellow
                
                # Extraer el archivo ZIP
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath)
                    Write-Host "Extracción completada exitosamente." -ForegroundColor Green
                }
                catch {
                    Write-Host "Error al extraer los archivos: $_" -ForegroundColor Red
                    return
                }
                
                # Buscar el ejecutable de HDSentinel
                $hdSentinelExe = Get-ChildItem -Path $extractPath -Recurse -Filter "HDSentinel.exe" | Select-Object -First 1
                
                if ($hdSentinelExe) {
                    Write-Host "Ejecutando Hard Disk Sentinel..." -ForegroundColor Yellow
                    
                    # Ejecutar la aplicación
                    try {
                        # Si no quieres bloquear la terminal, quita el parámetro -Wait
                        Start-Process -FilePath $hdSentinelExe.FullName -Wait
                        Write-Host "Hard Disk Sentinel se ejecutó correctamente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error al ejecutar Hard Disk Sentinel: $_" -ForegroundColor Red
                        return
                    }
                }
                else {
                    Write-Host "No se encontró el ejecutable HDSentinel.exe en los archivos extraídos." -ForegroundColor Red
                    return
                }
                
                # Limpiar archivos temporales
                Write-Host "Limpiando archivos temporales..." -ForegroundColor Yellow
                try {
                    Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "Limpieza completada." -ForegroundColor Green
                }
                catch {
                    Write-Host "Error al eliminar archivos temporales: $_" -ForegroundColor Red
                }
            }
        }
        
        
        @{
            Text = "Optimizar y mejorar el sistema"
            Action = {
                # Crear carpeta temporal si no existe
                if (-not (Test-Path "$env:TEMP\ToolboxBS")) {
                    New-Item -Path "$env:TEMP\ToolboxBS" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }
                
                # Descargar el script de GitHub
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/performance.bat" -OutFile "$env:TEMP\ToolboxBS\performance.bat"
                
                # Ejecutar el script descargado con cmd
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$env:TEMP\ToolboxBS\performance.bat"
                
                # Cerrar la ventana actual si existe
                if ($toolsMenuWindow) {
                    $toolsMenuWindow.Close()
                }
            }
        }
        @{
            Text = "Instalar Intel Driver Support"
            
            Action = {
                Write-Host "Descargando Intel Driver Support Assistant..." -ForegroundColor Yellow
                
                # Descargar el instalador
                $downloadPath = Join-Path $env:TEMP "IntelDriverSupport.exe"
                
                try {
                    Invoke-WebRequest -Uri "https://dsadata.intel.com/installer" -OutFile $downloadPath
                    
                    if (Test-Path $downloadPath) {
                        Write-Host "Iniciando instalación..." -ForegroundColor Green
                        # Usar Start-Process con Wait para que la terminal espere a que la instalación termine
                        Start-Process -FilePath $downloadPath -Wait
                        
                        Write-Host "Eliminando archivos temporales..." -ForegroundColor Yellow
                        Remove-Item -Path $downloadPath -Force
                        Write-Host "Instalación completada y archivos temporales eliminados." -ForegroundColor Green
                    } else {
                        Write-Host "Error: No se pudo descargar el instalador" -ForegroundColor Red
                    }
                }
                catch {
                    Write-Host "Error: $_" -ForegroundColor Red
                }
            }
        }
        @{
            Text = "Reparacion de Windows"
            
            Action = {
                $script = @"
Write-Host 'Iniciando reparación de Windows...' -ForegroundColor Green;
Write-Host 'Verificando integridad del sistema...' -ForegroundColor Cyan;
sfc /scannow;
Write-Host 'Reparando imagen de Windows...' -ForegroundColor Cyan;
DISM.exe /Online /Cleanup-image /Restorehealth;
Write-Host 'Reparación completada. ¡Reinicia tu PC para aplicar los cambios!' -ForegroundColor Green;
pause;
"@
                Start-Process powershell -ArgumentList "-NoExit", "-Command", $script -Verb RunAs
                $toolsMenuWindow.Close()
            }
        },
        @{
            Text = "Administrador de Tareas"
           
            Action = { Start-Process "taskmgr.exe"; $toolsMenuWindow.Close() }
        },
        @{
            Text = "Administrador de Dispositivos"
            
            Action = { Start-Process "devmgmt.msc"; $toolsMenuWindow.Close() }
        },
        @{
            Text = "Servicios"
            
            Action = { Start-Process "services.msc"; $toolsMenuWindow.Close() }
        },
        @{
            Text = "Limpieza de Disco"
            
            Action = { Start-Process "cleanmgr.exe"; $toolsMenuWindow.Close() }
        },
        @{
            Text = "Editor del Registro"
           
            Action = { Start-Process "regedit.exe"; $toolsMenuWindow.Close() }
        },
        @{
            Text = "WinGet"
            
            Action = { 
                Start-Process powershell -ArgumentList "-NoExit", "-Command", "winget"
                $toolsMenuWindow.Close()
            }
        },
        @{
            Text = "Verificar Actualizaciones"
            
            Action = { Start-Process "ms-settings:windowsupdate"; $toolsMenuWindow.Close() }
        }
    )
    
    # Crear botones para cada opción
    foreach ($item in $menuItems) {
        $menuBtn = New-Object System.Windows.Controls.Button
        $menuBtn.Margin = New-Object System.Windows.Thickness(5)
        $menuBtn.Padding = New-Object System.Windows.Thickness(10, 8, 10, 8)
        $menuBtn.Background = "#2d2d2d"
        $menuBtn.BorderThickness = New-Object System.Windows.Thickness(0)
        $menuBtn.HorizontalAlignment = "Stretch"
        $menuBtn.HorizontalContentAlignment = "Left"
        $menuBtn.Cursor = "Hand"
        
        # Contenido del botón con icono
        $btnContent = New-Object System.Windows.Controls.StackPanel
        $btnContent.Orientation = "Horizontal"
        
        if ($item.Icon) {
            $iconBlock = New-Object System.Windows.Controls.TextBlock
            $iconBlock.Text = $item.Icon
            $iconBlock.VerticalAlignment = "Center"
            $iconBlock.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
            $iconBlock.FontSize = 16
            $iconBlock.Foreground = "White"  # Color blanco para los iconos
            $btnContent.Children.Add($iconBlock)
        }
        
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $item.Text
        $textBlock.VerticalAlignment = "Center"
        $textBlock.Foreground = "White"
        $textBlock.FontSize = 14
        $btnContent.Children.Add($textBlock)
        
        $menuBtn.Content = $btnContent
        
        # Evento Click
        $action = $item.Action
        $menuBtn.Add_Click($action)
        
        # Efectos hover
        $menuBtn.Add_MouseEnter({
            $this.Background = "#3a3a3a"
        })
        
        $menuBtn.Add_MouseLeave({
            $this.Background = "#2d2d2d"
        })
        
        $menuPanel.Children.Add($menuBtn)
    }
    
    # Asegurarse de que se cierre cuando pierde el foco
    $toolsMenuWindow.Add_Deactivated({
        $this.Close()
    })
    
    # Asignar contenido y mostrar ventana
    $toolsMenuWindow.Content = $mainBorder
    
    # Cambiar Show por ShowDialog
    $toolsMenuWindow.ShowDialog()
})
# Añadir evento para el botón Configuración
# Cambiar el texto del botón
$configBtn.Content = "Modo Oscuro"

# Variable para seguir el estado actual del tema
$script:isDarkMode = $true # Comenzamos en modo oscuro por defecto

# Definir los colores para cada tema
$darkTheme = @{
    Background = "#121212"
    NavBarBackground = "#1e1e1e"
    ButtonBackground = "#2d2d2d"
    ButtonBorderBrush = "#3a3a3a"
    TextForeground = "White"
    SecondaryText = "#999999"
    AccentColor = "#2196F3"  # Mantener el color azul original
}

$lightTheme = @{
    Background = "#f0f0f0"
    NavBarBackground = "#ffffff"
    ButtonBackground = "#e0e0e0"
    ButtonBorderBrush = "#d0d0d0"
    TextForeground = "#333333"
    SecondaryText = "#666666"
    AccentColor = "#2196F3"  # Mantener el color azul original
}

# Añadir el evento click para el botón de modo oscuro
$configBtn.Add_Click({
    if ($script:isDarkMode) {
        # Cambiar a tema claro
        $configBtn.Content = "Modo Oscuro"
        
        $mainBorder = $window.FindName("MainBorder")
        $mainBorder.Background = $lightTheme.Background
        
        $topNavBar = $window.FindName("TopNavBar")
        $topNavBar.Background = $lightTheme.NavBarBackground
        
        # Cambiar el color de los textos de navegación
        $homeBtn = $window.FindName("HomeBtn")
        $toolsBtn = $window.FindName("ToolsBtn")
        $aboutBtn = $window.FindName("AboutBtn")
        $documentationBtn = $window.FindName("DocumentationBtn")
        
        $homeBtn.Foreground = $lightTheme.TextForeground
        $toolsBtn.Foreground = $lightTheme.TextForeground
        $aboutBtn.Foreground = $lightTheme.TextForeground
        $configBtn.Foreground = $lightTheme.TextForeground
        $documentationBtn.Foreground = $lightTheme.TextForeground
        
        # Actualizar los botones principales
        for ($i = 1; $i -le 5; $i++) {
            $btn = $window.FindName("Btn$i")
            if ($btn -ne $null) {
                $btn.Background = $lightTheme.ButtonBackground
                $btn.BorderBrush = $lightTheme.ButtonBorderBrush
                
                # Cambiar color de textos dentro de los botones
                $stackPanel = [System.Windows.Controls.StackPanel]$btn.Content
                foreach ($child in $stackPanel.Children) {
                    if ($child -is [System.Windows.Controls.TextBlock]) {
                        # Preservar el color azul para los iconos
                        if ($child.FontFamily -and $child.FontFamily.Source -eq "Segoe MDL2 Assets") {
                            $child.Foreground = $lightTheme.AccentColor
                        }
                        # Título del botón
                        elseif ($child.FontSize -ge 14) {
                            $child.Foreground = $lightTheme.TextForeground
                        }
                        # Descripción
                        elseif ($child.Text -notmatch "^[^\w]+$") {
                            $child.Foreground = $lightTheme.SecondaryText
                        }
                    }
                }
            }
        }
        
        # Asegurar que el título de "Herramientas Disponibles" sea visible
        $titleBlock = $window.FindName("TitleBlock")
        if ($titleBlock -eq $null) {
            # Buscar por texto si no tiene nombre específico
            $allTextBlocks = [System.Windows.Controls.TextBlock[]]@($window.FindAll([System.Windows.Controls.TextBlock]))
            foreach ($textBlock in $allTextBlocks) {
                if ($textBlock.Text -eq "Herramientas Disponibles") {
                    $textBlock.Foreground = $lightTheme.TextForeground
                    break
                }
            }
        } else {
            $titleBlock.Foreground = $lightTheme.TextForeground
        }
        
        $script:isDarkMode = $false
    } else {
        # Cambiar a tema oscuro
        $configBtn.Content = "Modo Claro"
        
        $mainBorder = $window.FindName("MainBorder")
        $mainBorder.Background = $darkTheme.Background
        
        $topNavBar = $window.FindName("TopNavBar")
        $topNavBar.Background = $darkTheme.NavBarBackground
        
        # Cambiar el color de los textos de navegación
        $homeBtn = $window.FindName("HomeBtn")
        $toolsBtn = $window.FindName("ToolsBtn")
        $aboutBtn = $window.FindName("AboutBtn")
        $documentationBtn = $window.FindName("DocumentationBtn")
        
        $homeBtn.Foreground = $darkTheme.TextForeground
        $toolsBtn.Foreground = $darkTheme.TextForeground
        $aboutBtn.Foreground = $darkTheme.TextForeground
        $configBtn.Foreground = $darkTheme.TextForeground
        $documentationBtn.Foreground = $darkTheme.TextForeground
        
        # Actualizar los botones principales
        for ($i = 1; $i -le 5; $i++) {
            $btn = $window.FindName("Btn$i")
            if ($btn -ne $null) {
                $btn.Background = $darkTheme.ButtonBackground
                $btn.BorderBrush = $darkTheme.ButtonBorderBrush
                
                # Cambiar color de textos dentro de los botones
                $stackPanel = [System.Windows.Controls.StackPanel]$btn.Content
                foreach ($child in $stackPanel.Children) {
                    if ($child -is [System.Windows.Controls.TextBlock]) {
                        # Preservar el color azul para los iconos
                        if ($child.FontFamily -and $child.FontFamily.Source -eq "Segoe MDL2 Assets") {
                            $child.Foreground = $darkTheme.AccentColor
                        }
                        # Título del botón
                        elseif ($child.FontSize -ge 14) {
                            $child.Foreground = $darkTheme.TextForeground
                        }
                        # Descripción
                        elseif ($child.Text -notmatch "^[^\w]+$") {
                            $child.Foreground = $darkTheme.SecondaryText
                        }
                    }
                }
            }
        }
        
        # Asegurar que el título de "Herramientas Disponibles" sea visible
        $titleBlock = $window.FindName("TitleBlock")
        if ($titleBlock -eq $null) {
            # Buscar por texto si no tiene nombre específico
            $allTextBlocks = [System.Windows.Controls.TextBlock[]]@($window.FindAll([System.Windows.Controls.TextBlock]))
            foreach ($textBlock in $allTextBlocks) {
                if ($textBlock.Text -eq "Herramientas Disponibles") {
                    $textBlock.Foreground = "White"  # Asegurar que sea siempre blanco en modo oscuro
                    break
                }
            }
        } else {
            $titleBlock.Foreground = "White"  # Asegurar que sea siempre blanco en modo oscuro
        }
        
        $script:isDarkMode = $true
    }
})

# Añadir evento para el botón Sobre
$aboutBtn.Add_Click({
    # Crear ventana de Sobre la aplicación
    $aboutWindow = New-Object System.Windows.Window
    $aboutWindow.Title = "Sobre ToolboxBS"
    $aboutWindow.Width = 600
    $aboutWindow.Height = 450
    $aboutWindow.WindowStartupLocation = "CenterOwner"
    $aboutWindow.Owner = $window
    $aboutWindow.Background = "Transparent"
    $aboutWindow.AllowsTransparency = $true
    $aboutWindow.WindowStyle = "None"
    $aboutWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $aboutWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "SOBRE TOOLBOXBS"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $aboutWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
    # Contenido
    $contentGrid = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($contentGrid, 1)
    $mainGrid.Children.Add($contentGrid)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(20)
    $contentGrid.Children.Add($scrollViewer)
    
    # Panel de información
    $infoPanel = New-Object System.Windows.Controls.StackPanel
    $infoPanel.Margin = New-Object System.Windows.Thickness(10)
    $scrollViewer.Content = $infoPanel
    
    # Logo
    $logoImage = New-Object System.Windows.Controls.Image
    $logoImage.Width = 150
    $logoImage.Height = 150
    $logoImage.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $logoImage.HorizontalAlignment = "Center"
    
    # Cargar la imagen
    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = New-Object System.Uri("https://github.com/BrandonSepulveda/BrandonSepulveda.github.io/blob/main/logo/Logo-30.png?raw=true")
        $bitmap.EndInit()
        $logoImage.Source = $bitmap
    } catch {
        # En caso de que no se pueda cargar la imagen
        Write-Host "Error al cargar la imagen: $_"
    }
    $infoPanel.Children.Add($logoImage)
    
    # Título de la aplicación
    $appTitle = New-Object System.Windows.Controls.TextBlock
    $appTitle.Text = "ToolboxBS"
    $appTitle.FontSize = 24
    $appTitle.FontWeight = "Bold"
    $appTitle.Foreground = "#2196F3"
    $appTitle.HorizontalAlignment = "Center"
    $appTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $infoPanel.Children.Add($appTitle)
    
    # Descripción
    $descriptionBlock = New-Object System.Windows.Controls.TextBlock
    $descriptionBlock.Text = "ToolboxBS es una herramienta de optimizacion y mantenimiento para sistemas Windows. Proporciona una interfaz amigable para ejecutar tareas comunes de mantenimiento y optimizacion del sistema."
    $descriptionBlock.Foreground = "White"
    $descriptionBlock.TextWrapping = "Wrap"
    $descriptionBlock.TextAlignment = "Center"
    $descriptionBlock.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $infoPanel.Children.Add($descriptionBlock)
    
    # Información del autor en un borde con estilo
    $authorBorder = New-Object System.Windows.Controls.Border
    $authorBorder.Background = "#1e1e1e"
    $authorBorder.BorderBrush = "#2196F3"
    $authorBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $authorBorder.CornerRadius = New-Object System.Windows.CornerRadius(5)
    $authorBorder.Padding = New-Object System.Windows.Thickness(15)
    $authorBorder.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)
    $infoPanel.Children.Add($authorBorder)
    
    $authorPanel = New-Object System.Windows.Controls.StackPanel
    $authorBorder.Child = $authorPanel
    
    # Autor
    $authorLabel = New-Object System.Windows.Controls.TextBlock
    $authorLabel.Text = "Autor"
    $authorLabel.FontWeight = "Bold"
    $authorLabel.Foreground = "#2196F3"
    $authorLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $authorPanel.Children.Add($authorLabel)
    
    $authorLink = New-Object System.Windows.Controls.TextBlock
    $authorLink.Text = "Jhon Brandon Sepulveda Valdes"
    $authorLink.Foreground = "White"
    $authorLink.Cursor = "Hand"
    $authorLink.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $authorLink.Add_MouseLeftButtonDown({
        Start-Process "https://brandonsepulveda.github.io"
    })
    $authorLink.Add_MouseEnter({
        $this.TextDecorations = [System.Windows.TextDecorations]::Underline
        $this.Foreground = "#2196F3"
    })
    $authorLink.Add_MouseLeave({
        $this.TextDecorations = $null
        $this.Foreground = "White"
    })
    $authorPanel.Children.Add($authorLink)
    
    # GitHub
    $githubLabel = New-Object System.Windows.Controls.TextBlock
    $githubLabel.Text = "GitHub"
    $githubLabel.FontWeight = "Bold"
    $githubLabel.Foreground = "#2196F3"
    $githubLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $authorPanel.Children.Add($githubLabel)
    
    $githubLink = New-Object System.Windows.Controls.TextBlock
    $githubLink.Text = "github.com/BrandonSepulveda/ToolboxBS"
    $githubLink.Foreground = "White"
    $githubLink.Cursor = "Hand"
    $githubLink.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $githubLink.Add_MouseLeftButtonDown({
        Start-Process "https://github.com/BrandonSepulveda/ToolboxBS"
    })
    $githubLink.Add_MouseEnter({
        $this.TextDecorations = [System.Windows.TextDecorations]::Underline
        $this.Foreground = "#2196F3"
    })
    $githubLink.Add_MouseLeave({
        $this.TextDecorations = $null
        $this.Foreground = "White"
    })
    $authorPanel.Children.Add($githubLink)
    
    # Versión
    $versionLabel = New-Object System.Windows.Controls.TextBlock
    $versionLabel.Text = "Version"
    $versionLabel.FontWeight = "Bold"
    $versionLabel.Foreground = "#2196F3"
    $versionLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $authorPanel.Children.Add($versionLabel)
    
    $versionLink = New-Object System.Windows.Controls.TextBlock
    $versionLink.Text = "2.0"
    $versionLink.Foreground = "White"
    $versionLink.Cursor = "Hand"
    $versionLink.Add_MouseLeftButtonDown({
        Start-Process "https://github.com/BrandonSepulveda/ToolboxBS/releases/latest"
    })
    $versionLink.Add_MouseEnter({
        $this.TextDecorations = [System.Windows.TextDecorations]::Underline
        $this.Foreground = "#2196F3"
    })
    $versionLink.Add_MouseLeave({
        $this.TextDecorations = $null
        $this.Foreground = "White"
    })
    $authorPanel.Children.Add($versionLink)
    
    # Licencia
    $licenseBorder = New-Object System.Windows.Controls.Border
    $licenseBorder.Background = "#1e1e1e"
    $licenseBorder.BorderBrush = "#2196F3"
    $licenseBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $licenseBorder.CornerRadius = New-Object System.Windows.CornerRadius(5)
    $licenseBorder.Padding = New-Object System.Windows.Thickness(15)
    $infoPanel.Children.Add($licenseBorder)
    
    $licensePanel = New-Object System.Windows.Controls.StackPanel
    $licenseBorder.Child = $licensePanel
    
    $licenseLabel = New-Object System.Windows.Controls.TextBlock
    $licenseLabel.Text = "Licencia"
    $licenseLabel.FontWeight = "Bold"
    $licenseLabel.Foreground = "#2196F3"
    $licenseLabel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $licensePanel.Children.Add($licenseLabel)
    
    $licenseText = New-Object System.Windows.Controls.TextBlock
    $licenseText.Text = "MIT License - Copyright (c) 2023 Jhon Brandon Sepulveda Valdes"
    $licenseText.Foreground = "White"
    $licenseText.TextWrapping = "Wrap"
    $licensePanel.Children.Add($licenseText)
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $aboutWindow.DragMove()
    })
    
    # Mostrar ventana
    $aboutWindow.ShowDialog()
})
} catch {
    Write-Host "Error cargando XAML: $_" -ForegroundColor Red
    exit
}

# Función para control de movimiento de la ventana
$window.Add_MouseLeftButtonDown({
    $window.DragMove()
})

# Obtener referencias a controles
$topNavBar = $window.FindName("TopNavBar")
$closeButton = $window.FindName("CloseButton")
$minimizeButton = $window.FindName("MinimizeButton")
$maxRestoreButton = $window.FindName("MaxRestoreButton")
$mainBorder = $window.FindName("MainBorder")



# Función para alternar el estado de la ventana
function ToggleWindowState {
    if ($window.WindowState -eq [System.Windows.WindowState]::Normal) {
        $window.WindowState = [System.Windows.WindowState]::Maximized
        $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(0)
    } else {
        $window.WindowState = [System.Windows.WindowState]::Normal
        $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    }
}

# Asignar botones de control de ventana
$closeButton.Add_Click({ 
    $window.Close() 
})

$minimizeButton.Add_Click({
    $window.WindowState = [System.Windows.WindowState]::Minimized
})

$maxRestoreButton.Add_Click({
    ToggleWindowState
})

# Función para asignar logo desde URL
function Set-Logo {
    param ([string]$ImageUrl)
    
    $imageControl = $window.FindName("LogoImage")
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.UriSource = $ImageUrl
    $bitmap.EndInit()
    $imageControl.Source = $bitmap
}

# Asignar logo
Set-Logo -ImageUrl "https://github.com/BrandonSepulveda/BrandonSepulveda.github.io/blob/main/logo/Logo-30.png?raw=true"

# Asignar funciones a botones principales
$window.FindName("Btn1").Add_Click({
    # Intentar abrir PowerShell 7 primero, si no está disponible, abrir PowerShell 5
    $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
    $scriptCommand = "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/infosystem.ps1' | iex`""
    
    if ($pwsh7Path) {
        Start-Process $pwsh7Path -ArgumentList $scriptCommand
    } else {
        # Usar PowerShell predeterminado
        Start-Process "powershell.exe" -ArgumentList $scriptCommand
    }
})
                     
# This implementation should replace the ENTIRE implementation of your Btn2 click handler
$window.FindName("Btn2").Add_Click({
    # Intentar abrir PowerShell 7 primero, si no está disponible, abrir PowerShell 5
    $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
    $scriptCommand = "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/instalador%20de%20apps.ps1' | iex`""
    
    if ($pwsh7Path) {
        Start-Process $pwsh7Path -ArgumentList $scriptCommand
    } else {
        # Usar PowerShell predeterminado
        Start-Process "powershell.exe" -ArgumentList $scriptCommand
    }
}) 

$window.FindName("Btn3").Add_Click({ 
    # Crear ventana de reparación
    $repairWindow = New-Object System.Windows.Window
    $repairWindow.Title = "Herramientas de Reparacion"
    $repairWindow.Width = 650
    $repairWindow.Height = 550
    $repairWindow.WindowStartupLocation = "CenterOwner"
    $repairWindow.Owner = $window
    $repairWindow.Background = "Transparent"
    $repairWindow.AllowsTransparency = $true
    $repairWindow.WindowStyle = "None"
    $repairWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $repairWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "HERRAMIENTAS DE REPARACION Y MANTENIMIENTO"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $repairWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
    # ScrollViewer para asegurar que se muestren todos los botones
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(0)
    $scrollViewer.Padding = New-Object System.Windows.Thickness(0)
    [System.Windows.Controls.Grid]::SetRow($scrollViewer, 1)
    $mainGrid.Children.Add($scrollViewer)
    
    # Panel principal para los botones de herramientas
    $repairPanel = New-Object System.Windows.Controls.StackPanel
    $repairPanel.Margin = New-Object System.Windows.Thickness(20)
    $scrollViewer.Content = $repairPanel
    
    # Título de sección
    $sectionTitle = New-Object System.Windows.Controls.TextBlock
    $sectionTitle.Text = "Selecciona una herramienta"
    $sectionTitle.Foreground = "#2196F3"
    $sectionTitle.FontSize = 16
    $sectionTitle.FontWeight = "Medium"
    $sectionTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $repairPanel.Children.Add($sectionTitle)
    
    # ========== BOTONES DE HERRAMIENTAS ==========
    
    # 1. CREAR PUNTO DE RESTAURACIÓN
    $restoreBtn = New-Object System.Windows.Controls.Button
    $restoreBtn.Content = "1. Crear Punto de Restauracion"
    $restoreBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $restoreBtn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
    $restoreBtn.Background = "#2d2d2d"
    $restoreBtn.Foreground = "White"
    $restoreBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $restoreBtn.HorizontalAlignment = "Stretch"
    $restoreBtn.HorizontalContentAlignment = "Left"
    $restoreBtn.FontSize = 14
        $restoreBtn.Add_Click({
            try {
                # Crear un punto de restauración
                $description = "Punto de restauracion creado por ToolboxBS"
                $restorePointType = "MODIFY_SETTINGS"
                Checkpoint-Computer -Description $description -RestorePointType $restorePointType
        
                # Mostrar un mensaje para informar al usuario
                [System.Windows.MessageBox]::Show("Se ha creado un punto de restauración.", "Punto de Restauración Creado", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
            catch {
                # Mostrar mensaje de error si falla
                [System.Windows.MessageBox]::Show("Error al crear punto de restauración: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
    $restoreBtn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
    $restoreBtn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
    $repairPanel.Children.Add($restoreBtn)
    
    # 2. MANTENIMIENTO DEL S.O.
    $maintenanceBtn = New-Object System.Windows.Controls.Button
    $maintenanceBtn.Content = "2. Mantenimiento del S.O."
    $maintenanceBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $maintenanceBtn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
    $maintenanceBtn.Background = "#2d2d2d"
    $maintenanceBtn.Foreground = "White"
    $maintenanceBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $maintenanceBtn.HorizontalAlignment = "Stretch"
    $maintenanceBtn.HorizontalContentAlignment = "Left"
    $maintenanceBtn.FontSize = 14
    
# Lógica para el botón "2. Mantenimiento del S.O."
$maintenanceBtn.Add_Click({
    try {
        # Verificar si el script se está ejecutando como administrador
        if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            [System.Windows.MessageBox]::Show("Debes ejecutar el script como administrador para verificar y reparar archivos del sistema.", "Error de Permiso", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }
        
        # Crear el script para ejecutar en una nueva ventana de PowerShell
        $script = @"
Write-Host 'Iniciando mantenimiento de Windows...' -ForegroundColor Green;

# Detectar la cantidad de RAM y ajustar memoryusage en consecuencia
Write-Host 'Verificando configuración de memoria...' -ForegroundColor Cyan;
`$totalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum / 1GB;
Write-Host "Memoria RAM detectada: `$totalRAM GB" -ForegroundColor Yellow;

# Consultar valor actual
fsutil behavior query memoryusage;

# Establecer valor según la RAM disponible
if (`$totalRAM -ge 16) {
    Write-Host 'Configurando memoryusage en modo 2 (optimizado para 16GB+ de RAM)' -ForegroundColor Yellow;
    fsutil behavior set memoryusage 2;
} else {
    Write-Host 'Configurando memoryusage en modo 1 (recomendado para equipos con menos de 16GB de RAM)' -ForegroundColor Yellow;
    fsutil behavior set memoryusage 1;
}

Write-Host 'Ajustando temporizadores...' -ForegroundColor Cyan;
bcdedit /set useplatformtick yes;
bcdedit /set disabledynamictick yes;

Write-Host 'Reparando archivos del sistema...' -ForegroundColor Cyan;
sfc /scannow;

Write-Host 'Diagnostico y reparación de la imagen de Windows...' -ForegroundColor Cyan;
DISM.exe /Online /Cleanup-image /CheckHealth;
DISM.exe /Online /Cleanup-image /Restorehealth;

Write-Host 'Reparando archivos del sistema...' -ForegroundColor Cyan;
sfc /scannow;

Write-Host 'Limpiando componentes...' -ForegroundColor Cyan;
Dism.exe /Online /Cleanup-Image /startComponentCleanup;

Write-Host 'Mantenimiento completado. ¡Reinicia tu PC para aplicar los cambios!' -ForegroundColor Green;
pause;
"@
        
        # Iniciar una nueva instancia de PowerShell para ejecutar el script
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $script
        
        # Mostrar un mensaje de confirmación
        [System.Windows.MessageBox]::Show("Mantenimiento de Windows iniciado. Se abrirá una nueva ventana de PowerShell para ejecutar los comandos.", "Proceso Iniciado", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } 
    catch {
        # Mostrar mensaje de error si falla
        [System.Windows.MessageBox]::Show("Error al iniciar el mantenimiento de Windows: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})
    $maintenanceBtn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
    $maintenanceBtn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
    $repairPanel.Children.Add($maintenanceBtn)
    
    # 3. INFORMACIÓN DE PANTALLAZOS AZULES
    $bsodBtn = New-Object System.Windows.Controls.Button
    $bsodBtn.Content = "3. Informacion de Pantallazos Azules"
    $bsodBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $bsodBtn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
    $bsodBtn.Background = "#2d2d2d"
    $bsodBtn.Foreground = "White"
    $bsodBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $bsodBtn.HorizontalAlignment = "Stretch"
    $bsodBtn.HorizontalContentAlignment = "Left"
    $bsodBtn.FontSize = 14
    # 3. INFORMACIÓN DE PANTALLAZOS AZULES
$bsodBtn.Add_Click({
    # Crear ventana de información de pantallazos azules
    $bsodWindow = New-Object System.Windows.Window
    $bsodWindow.Title = "Informacion de Pantallazos Azules"
    $bsodWindow.Width = 650
    $bsodWindow.Height = 550
    $bsodWindow.WindowStartupLocation = "CenterOwner"
    $bsodWindow.Owner = $repairWindow
    $bsodWindow.Background = "Transparent"
    $bsodWindow.AllowsTransparency = $true
    $bsodWindow.WindowStyle = "None"
    $bsodWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $bsodWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "INFORMACION DE PANTALLAZOS AZULES"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $bsodWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
   # Panel de botones
$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.Orientation = "Horizontal"
$buttonPanel.HorizontalAlignment = "Center"
$buttonPanel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 20)

# Botón para descargar y ejecutar BlueScreenView
$blueScreenViewBtn = New-Object System.Windows.Controls.Button
$blueScreenViewBtn.Content = "BlueScreenView"
$blueScreenViewBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$blueScreenViewBtn.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
$blueScreenViewBtn.Background = "#2196F3"
$blueScreenViewBtn.Foreground = "White"
$blueScreenViewBtn.BorderThickness = New-Object System.Windows.Thickness(0)
$blueScreenViewBtn.FontSize = 12
$blueScreenViewBtn.Height = 30
$blueScreenViewBtn.Width = 120

    $blueScreenViewBtn.Add_Click({
        # Define la URL de descarga de BlueScreenView.zip
        $Url = "https://www.nirsoft.net/utils/bluescreenview.zip"
        
        # Define la ruta de destino para la descarga y la extracción
        $ZipPath = Join-Path $env:TEMP "bluescreenview.zip"
        $ExtractPath = Join-Path $env:TEMP "BlueScreenView"
        
        # Descarga el archivo zip
        try {
            Invoke-WebRequest -Uri $Url -OutFile $ZipPath
        } catch {
            [System.Windows.MessageBox]::Show("Error al descargar BlueScreenView: $_", "Error de Descarga", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        
        # Extrae el contenido del archivo zip
        try {
            Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        } catch {
            [System.Windows.MessageBox]::Show("Error al extraer BlueScreenView: $_", "Error de Extracción", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        
        # Ejecuta BlueScreenView.exe
        $ExePath = Join-Path $ExtractPath "BlueScreenView.exe"
        if (Test-Path -Path $ExePath) {
            try {
                Start-Process -FilePath $ExePath
            } catch {
                [System.Windows.MessageBox]::Show("Error al ejecutar BlueScreenView: $_", "Error de Ejecución", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        } else {
            [System.Windows.MessageBox]::Show("No se encontró BlueScreenView.exe en la carpeta extraída.", "Archivo No Encontrado", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    })
    $buttonPanel.Children.Add($blueScreenViewBtn)
    
    # Botón para ejecutar script remoto
$scriptRemotoBtn = New-Object System.Windows.Controls.Button
$scriptRemotoBtn.Content = "Script Remoto"
$scriptRemotoBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$scriptRemotoBtn.Background = "#4CAF50"
$scriptRemotoBtn.Foreground = "White"
$scriptRemotoBtn.BorderThickness = New-Object System.Windows.Thickness(0)
$scriptRemotoBtn.FontSize = 12
$scriptRemotoBtn.Height = 30
$scriptRemotoBtn.Width = 120
    $scriptRemotoBtn.Add_Click({
        try {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command irm 'https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/pantalla%20azul.ps1' | iex"
        } catch {
            [System.Windows.MessageBox]::Show("Error al ejecutar el script remoto: $_", "Error de Ejecución", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $buttonPanel.Children.Add($scriptRemotoBtn)
    
    # Contenido
    $contentGrid = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($contentGrid, 1)
    $mainGrid.Children.Add($contentGrid)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(20)
    $contentGrid.Children.Add($scrollViewer)
    
    # Panel de información
    $infoPanel = New-Object System.Windows.Controls.StackPanel
    $scrollViewer.Content = $infoPanel
    
    # Agregar explicación de pantallazos azules
    $explanationBlock = New-Object System.Windows.Controls.TextBlock
    $explanationBlock.Text = "Los pantallazos azules (Blue Screen of Death o BSOD) son errores críticos del sistema que pueden indicar problemas de hardware o software. 

Herramientas disponibles:
1. BlueScreenView: Herramienta para analizar y ver detalles de pantallazos azules anteriores.
2. Script Remoto: Ejecuta un script adicional para obtener más información sobre los pantallazos azules."
    $explanationBlock.Foreground = "White"
    $explanationBlock.TextWrapping = "Wrap"
    $explanationBlock.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $infoPanel.Children.Add($explanationBlock)
    
    # Agregar botones al grid
    $contentGrid.Children.Add($buttonPanel)
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $bsodWindow.DragMove()
    })
    
    # Mostrar ventana
    $bsodWindow.ShowDialog()
})
    $bsodBtn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
    $bsodBtn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
    $repairPanel.Children.Add($bsodBtn)
    
    # 4. VER ESTADO DE LA BATERÍA
    $batteryBtn = New-Object System.Windows.Controls.Button
    $batteryBtn.Content = "4. Ver Estado de la Batería"
    $batteryBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $batteryBtn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
    $batteryBtn.Background = "#2d2d2d"
    $batteryBtn.Foreground = "White"
    $batteryBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $batteryBtn.HorizontalAlignment = "Stretch"
    $batteryBtn.HorizontalContentAlignment = "Left"
    $batteryBtn.FontSize = 14
    # 4. VER ESTADO DE LA BATERÍA
$batteryBtn.Add_Click({
    # Crear ventana de información de batería
    $batteryWindow = New-Object System.Windows.Window
    $batteryWindow.Title = "Estado de la Batería"
    $batteryWindow.Width = 650
    $batteryWindow.Height = 550
    $batteryWindow.WindowStartupLocation = "CenterOwner"
    $batteryWindow.Owner = $repairWindow
    $batteryWindow.Background = "Transparent"
    $batteryWindow.AllowsTransparency = $true
    $batteryWindow.WindowStyle = "None"
    $batteryWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $batteryWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "ESTADO DE LA BATERÍA"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $batteryWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
    # Panel de botones
    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Center"
    $buttonPanel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 20)

    # Botón para descargar BatteryInfoView
    $batteryInfoViewBtn = New-Object System.Windows.Controls.Button
    $batteryInfoViewBtn.Content = "BatteryInfoView"
    $batteryInfoViewBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
    $batteryInfoViewBtn.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    $batteryInfoViewBtn.Background = "#2196F3"
    $batteryInfoViewBtn.Foreground = "White"
    $batteryInfoViewBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $batteryInfoViewBtn.FontSize = 12
    $batteryInfoViewBtn.Height = 30
    $batteryInfoViewBtn.Width = 120
    $batteryInfoViewBtn.Add_Click({
        try {
            # Descargar BatteryInfoView.zip desde el sitio web
            $url = "https://www.nirsoft.net/utils/batteryinfoview.zip"
            $outputPath = Join-Path $env:TEMP "BatteryInfoView.zip"
            $extractPath = Join-Path $env:TEMP "BatteryInfoView"

            # Descargar archivo
            (New-Object System.Net.WebClient).DownloadFile($url, $outputPath)

            # Extraer el archivo descargado
            Expand-Archive -Path $outputPath -DestinationPath $extractPath -Force

            # Ejecutar BatteryInfoView.exe
            $exePath = Join-Path $extractPath "BatteryInfoView.exe"
            Start-Process -FilePath $exePath

        } catch {
            [System.Windows.MessageBox]::Show("Error al abrir BatteryInfoView: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $buttonPanel.Children.Add($batteryInfoViewBtn)

    # Botón para generar informe de batería
    $batteryReportBtn = New-Object System.Windows.Controls.Button
    $batteryReportBtn.Content = "Informe de Batería"
    $batteryReportBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
    $batteryReportBtn.Background = "#4CAF50"
    $batteryReportBtn.Foreground = "White"
    $batteryReportBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $batteryReportBtn.FontSize = 12
    $batteryReportBtn.Height = 30
    $batteryReportBtn.Width = 120
    $batteryReportBtn.Add_Click({
        try {
            # Generar informe de batería
            $batteryReportPath = "C:\battery_report.html"
            $batteryReportCommand = "powercfg /batteryreport /output `"$batteryReportPath`""
            Invoke-Expression -Command $batteryReportCommand

            # Verificar si el archivo existe
            if (Test-Path $batteryReportPath) {
                # Abrir el informe
                Start-Process $batteryReportPath
                
                [System.Windows.MessageBox]::Show("El informe de la batería se ha generado en $batteryReportPath", "Informe Generado", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            } else {
                [System.Windows.MessageBox]::Show("No se pudo generar el informe de batería.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            }
        } catch {
            [System.Windows.MessageBox]::Show("Error al generar el informe de batería: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $buttonPanel.Children.Add($batteryReportBtn)
    
    # Contenido
    $contentGrid = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($contentGrid, 1)
    $mainGrid.Children.Add($contentGrid)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(20)
    $contentGrid.Children.Add($scrollViewer)
    
    # Panel de información
    $infoPanel = New-Object System.Windows.Controls.StackPanel
    $scrollViewer.Content = $infoPanel
    
    # Agregar explicación sobre el estado de la batería
    $explanationBlock = New-Object System.Windows.Controls.TextBlock
    $explanationBlock.Text = "Herramientas para analizar el estado de la batería:

1. BatteryInfoView: Aplicación que proporciona información detallada sobre la batería de tu dispositivo.

2. Informe de Batería: Genera un informe HTML completo con información sobre el uso, capacidad y estado de la batería.

Consejos para el cuidado de la batería:
- Mantén la batería entre 20% y 80% de carga
- Evita temperaturas extremas
- Actualiza regularmente el controlador de batería
- Usa el modo de ahorro de energía cuando sea posible"
    $explanationBlock.Foreground = "White"
    $explanationBlock.TextWrapping = "Wrap"
    $explanationBlock.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $infoPanel.Children.Add($explanationBlock)
    
    # Agregar botones al grid
    $contentGrid.Children.Add($buttonPanel)
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $batteryWindow.DragMove()
    })
    
    # Mostrar ventana
    $batteryWindow.ShowDialog()
})
    $batteryBtn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
    $batteryBtn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
    $repairPanel.Children.Add($batteryBtn)
    
    # 5. INFORMACIÓN DE DRIVERS
    $driversBtn = New-Object System.Windows.Controls.Button
    $driversBtn.Content = "5. Informacion de Drivers"
    $driversBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $driversBtn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
    $driversBtn.Background = "#2d2d2d"
    $driversBtn.Foreground = "White"
    $driversBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $driversBtn.HorizontalAlignment = "Stretch"
    $driversBtn.HorizontalContentAlignment = "Left"
    $driversBtn.FontSize = 14
    # 5. INFORMACIÓN DE DRIVERS
$driversBtn.Add_Click({
    # Crear ventana de información de drivers
    $driversWindow = New-Object System.Windows.Window
    $driversWindow.Title = "Información de Drivers"
    $driversWindow.Width = 650
    $driversWindow.Height = 550
    $driversWindow.WindowStartupLocation = "CenterOwner"
    $driversWindow.Owner = $repairWindow
    $driversWindow.Background = "Transparent"
    $driversWindow.AllowsTransparency = $true
    $driversWindow.WindowStyle = "None"
    $driversWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $driversWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "INFORMACIÓN DE DRIVERS"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $driversWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
    # Panel de botones
    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Center"
    $buttonPanel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 20)

    # Botón para exportar información de drivers
    $exportDriversBtn = New-Object System.Windows.Controls.Button
    $exportDriversBtn.Content = "Exportar Drivers"
    $exportDriversBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
    $exportDriversBtn.Margin = New-Object System.Windows.Thickness(0, 20, 10, 0)  
    $exportDriversBtn.Background = "#2196F3"
    $exportDriversBtn.Foreground = "White"
    $exportDriversBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $exportDriversBtn.FontSize = 12
    $exportDriversBtn.Height = 30
    $exportDriversBtn.Width = 120
    $exportDriversBtn.Add_Click({
        try {
            # Ruta para guardar el archivo de información de controladores
            $outputPath = "C:\informacion_controladores.txt"
            
            # Obtener información detallada de los controladores
            $driversInfo = Get-WmiObject -Query 'SELECT * FROM Win32_SystemDriver' | 
                Select-Object DisplayName, Description, PathName, StartMode, State, Status | 
                Format-List | 
                Out-String
            
            # Guardar la información en un archivo
            $driversInfo | Out-File -FilePath $outputPath -Encoding UTF8
            
            # Abrir el archivo generado
            Invoke-Item -Path $outputPath
            
            [System.Windows.MessageBox]::Show("Información de controladores exportada a $outputPath", "Exportación Completa", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } catch {
            [System.Windows.MessageBox]::Show("Error al exportar información de drivers: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $buttonPanel.Children.Add($exportDriversBtn)

    # Botón para abrir Administrador de Dispositivos
    $deviceManagerBtn = New-Object System.Windows.Controls.Button
    $deviceManagerBtn.Content = "Admin. Dispositivos"
    $deviceManagerBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
    $deviceManagerBtn.Margin = New-Object System.Windows.Thickness(0, 20, 0, 0)  
    $deviceManagerBtn.Background = "#4CAF50"
    $deviceManagerBtn.Foreground = "White"
    $deviceManagerBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $deviceManagerBtn.FontSize = 12
    $deviceManagerBtn.Height = 30
    $deviceManagerBtn.Width = 120
    $deviceManagerBtn.Add_Click({
        try {
            # Abrir Administrador de Dispositivos
            Start-Process "devmgmt.msc"
        } catch {
            [System.Windows.MessageBox]::Show("Error al abrir Administrador de Dispositivos: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $buttonPanel.Children.Add($deviceManagerBtn)
    
    # Contenido
    $contentGrid = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($contentGrid, 1)
    $mainGrid.Children.Add($contentGrid)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(20)
    $contentGrid.Children.Add($scrollViewer)
    
    # Panel de información
    $infoPanel = New-Object System.Windows.Controls.StackPanel
    $scrollViewer.Content = $infoPanel
    
    # Agregar explicación sobre información de drivers
    $explanationBlock = New-Object System.Windows.Controls.TextBlock
    $explanationBlock.Text = "Herramientas para gestionar controladores:

1. Exportar Drivers: Genera un archivo de texto con información detallada de todos los controladores instalados en tu sistema.

2. Administrador de Dispositivos: Herramienta de Windows para administrar, actualizar y solucionar problemas de hardware.

Consejos para el manejo de controladores:
- Mantén tus controladores actualizados
- Descarga controladores únicamente de fuentes oficiales
- Realiza una copia de seguridad antes de actualizar controladores
- Desinstala controladores antiguos o innecesarios
- Usa las herramientas de actualización de fabricantes como Intel Driver Support Assistant, Hp suport entre otros"
    $explanationBlock.Foreground = "White"
    $explanationBlock.TextWrapping = "Wrap"
    $explanationBlock.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $infoPanel.Children.Add($explanationBlock)
    
    # Agregar botones al grid
    $contentGrid.Children.Add($buttonPanel)
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $driversWindow.DragMove()
    })
    
    # Mostrar ventana
    $driversWindow.ShowDialog()
})
    $driversBtn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
    $driversBtn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
    $repairPanel.Children.Add($driversBtn)
    
    # 6. REPARAR RED
    $networkBtn = New-Object System.Windows.Controls.Button
    $networkBtn.Content = "6. Reparar Red"
    $networkBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $networkBtn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
    $networkBtn.Background = "#2d2d2d"
    $networkBtn.Foreground = "White"
    $networkBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $networkBtn.HorizontalAlignment = "Stretch"
    $networkBtn.HorizontalContentAlignment = "Left"
    $networkBtn.FontSize = 14
    # 6. REPARAR RED
$networkBtn.Add_Click({
    # Crear ventana de reparación de red
    $networkWindow = New-Object System.Windows.Window
    $networkWindow.Title = "Reparación de Red"
    $networkWindow.Width = 650
    $networkWindow.Height = 550
    $networkWindow.WindowStartupLocation = "CenterOwner"
    $networkWindow.Owner = $repairWindow
    $networkWindow.Background = "Transparent"
    $networkWindow.AllowsTransparency = $true
    $networkWindow.WindowStyle = "None"
    $networkWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $networkWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "REPARACIÓN DE RED"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $networkWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(20)
    [System.Windows.Controls.Grid]::SetRow($scrollViewer, 1)
    $mainGrid.Children.Add($scrollViewer)
    
    # Panel de información
    $infoPanel = New-Object System.Windows.Controls.StackPanel
    $scrollViewer.Content = $infoPanel
    
    # Agregar explicación sobre reparación de red
    $explanationBlock = New-Object System.Windows.Controls.TextBlock
    $explanationBlock.Text = "Herramientas para reparar problemas de red:

Comandos de reparación de red:
- Restablecer el socket de Windows (Winsock)
- Restablecer configuración de IP
- Liberar y renovar dirección IP

Estos comandos pueden ayudar a solucionar:
- Problemas de conexión a internet
- Errores de configuración de red
- Conflictos de adaptadores de red

Consejos adicionales:
- Reinicia tu router/módem
- Comprueba los cables de red
- Verifica la configuración de firewall
- Actualiza los controladores de red"
    $explanationBlock.Foreground = "White"
    $explanationBlock.TextWrapping = "Wrap"
    $explanationBlock.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)
    $infoPanel.Children.Add($explanationBlock)
    
    # Panel de botones
    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Center"
    
    # Botón para reparar red
    $repairNetworkBtn = New-Object System.Windows.Controls.Button
    $repairNetworkBtn.Content = "Reparar Red"
    $repairNetworkBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
    $repairNetworkBtn.Margin = New-Object System.Windows.Thickness(0, 20, 10, 0)
    $repairNetworkBtn.Background = "#2196F3"
    $repairNetworkBtn.Foreground = "White"
    $repairNetworkBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $repairNetworkBtn.FontSize = 12
    $repairNetworkBtn.Height = 30
    $repairNetworkBtn.Width = 120
    $repairNetworkBtn.Add_Click({
        try {
            # Verificar si se está ejecutando como administrador
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            if (-not $isAdmin) {
                [System.Windows.MessageBox]::Show("Se requieren permisos de administrador para reparar la red.", "Permisos Insuficientes", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                return
            }
            
            # Comandos de reparación de red
            $commands = @(
                "netsh winsock reset",
                "netsh int ip reset",
                "ipconfig /release",
                "ipconfig /renew",
                "ipconfig /flushdns"
            )
            
            # Crear un script temporal
            $scriptPath = "$env:TEMP\network_repair.bat"
            $commands | Out-File -FilePath $scriptPath -Encoding ASCII
            
            # Ejecutar el script con privilegios de administrador
            Start-Process cmd.exe -ArgumentList "/c $scriptPath" -Verb RunAs -Wait
            
            # Eliminar el script temporal
            Remove-Item $scriptPath -Force
            
            [System.Windows.MessageBox]::Show("Reparación de red completada. Reinicia tu equipo para aplicar los cambios.", "Reparación Exitosa", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } catch {
            [System.Windows.MessageBox]::Show("Error al reparar la red: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $buttonPanel.Children.Add($repairNetworkBtn)
    
    # Botón para diagnosticar red
    $networkDiagnosticsBtn = New-Object System.Windows.Controls.Button
    $networkDiagnosticsBtn.Content = "Diagnóstico"
    $networkDiagnosticsBtn.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
    $networkDiagnosticsBtn.Margin = New-Object System.Windows.Thickness(0, 20, 0, 0)
    $networkDiagnosticsBtn.Background = "#4CAF50"
    $networkDiagnosticsBtn.Foreground = "White"
    $networkDiagnosticsBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $networkDiagnosticsBtn.FontSize = 12
    $networkDiagnosticsBtn.Height = 30
    $networkDiagnosticsBtn.Width = 120
    $networkDiagnosticsBtn.Add_Click({
        try {
            # Abrir diagnóstico de red de Windows
            Start-Process "msdt.exe" -ArgumentList "-id NetworkDiagnostic"
        } catch {
            [System.Windows.MessageBox]::Show("Error al abrir diagnóstico de red: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
    $buttonPanel.Children.Add($networkDiagnosticsBtn)
    
    # Agregar panel de botones
    $infoPanel.Children.Add($buttonPanel)
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $networkWindow.DragMove()
    })
    
    # Mostrar ventana
    $networkWindow.ShowDialog()
})
    $networkBtn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
    $networkBtn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
    $repairPanel.Children.Add($networkBtn)
    
    # 7. LIMPIEZA - Panel con submenú
    $cleanupPanel = New-Object System.Windows.Controls.StackPanel
    $cleanupPanel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $repairPanel.Children.Add($cleanupPanel)
    
    # Botón principal de limpieza
    $cleanupBtn = New-Object System.Windows.Controls.Button
    $cleanupBtn.Content = "7. Limpieza"
    $cleanupBtn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
    $cleanupBtn.Background = "#2d2d2d"
    $cleanupBtn.Foreground = "White"
    $cleanupBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $cleanupBtn.HorizontalAlignment = "Stretch"
    $cleanupBtn.HorizontalContentAlignment = "Left"
    $cleanupBtn.FontSize = 14
    $cleanupBtn.Tag = "collapsed" # Estado inicial
    $cleanupPanel.Children.Add($cleanupBtn)
    
    # Panel para las opciones de limpieza (inicialmente oculto)
    $cleanupOptions = New-Object System.Windows.Controls.StackPanel
    $cleanupOptions.Margin = New-Object System.Windows.Thickness(20, 5, 0, 0)
    $cleanupOptions.Visibility = "Collapsed"
    $cleanupPanel.Children.Add($cleanupOptions)
    
    # Opción 1: Limpiar archivos temporales
    $tempFilesBtn = New-Object System.Windows.Controls.Button
    $tempFilesBtn.Content = "Limpiar Archivos Temporales"
    $tempFilesBtn.Padding = New-Object System.Windows.Thickness(15, 8, 15, 8)
    $tempFilesBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $tempFilesBtn.Background = "#3a3a3a"
    $tempFilesBtn.Foreground = "White"
    $tempFilesBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $tempFilesBtn.HorizontalAlignment = "Stretch"
    $tempFilesBtn.HorizontalContentAlignment = "Left"
    # Opción 1: Limpiar archivos temporales
    $tempFilesBtn.Add_Click({
        try {
            # Rutas de archivos temporales
            $userTempPath = $env:TEMP
            $windowsTempPath = "C:\Windows\Temp"
            $downloadsTempPath = "C:\Users\$env:USERNAME\Downloads\Temp"
    
            # Contador de archivos eliminados
            $script:deletedFiles = 0
            $script:deletedBytes = 0
    
            # Función para eliminar archivos con manejo de errores
            function Remove-TempFiles {
                param(
                    [string]$Path,
                    [bool]$SkipInUse = $true
                )
    
                Write-Host "Limpiando: $Path"
    
                $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    try {
                        # Omitir archivos en uso si es necesario
                        if ($SkipInUse -and ($file.IsReadOnly -or $file.InUse)) {
                            Write-Host "Omitiendo archivo en uso: $($file.FullName)"
                            continue
                        }
    
                        # Intentar eliminar el archivo
                        Remove-Item $file.FullName -Force -ErrorAction Stop
                        $script:deletedFiles++
                        $script:deletedBytes += $file.Length
                        Write-Host "Eliminado: $($file.FullName)"
                    } catch {
                        # Registrar archivos que no se pudieron eliminar
                        Write-Host "No se pudo eliminar: $($file.FullName) - $_"
                    }
                }
    
                # Intentar eliminar carpetas vacías
                $folders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
                foreach ($folder in $folders) {
                    try {
                        if (($folder.GetFiles().Count -eq 0) -and ($folder.GetDirectories().Count -eq 0)) {
                            Remove-Item $folder.FullName -Force -ErrorAction Stop
                            Write-Host "Carpeta eliminada: $($folder.FullName)"
                        }
                    } catch {
                        Write-Host "No se pudo eliminar carpeta: $($folder.FullName) - $_"
                    }
                }
            }
    
            # Verificar si se tienen privilegios de administrador
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
            # Limpiar archivos temporales del usuario
            Remove-TempFiles -Path $userTempPath
    
            # Si es administrador, limpiar archivos temporales del sistema
            if ($isAdmin) {
                Remove-TempFiles -Path $windowsTempPath -SkipInUse $false
                
                # Limpiar carpeta de descargas temporal
                if (Test-Path $downloadsTempPath) {
                    Remove-TempFiles -Path $downloadsTempPath
                }
            }
    
            # Mensaje de resultado
            $resultMessage = "Limpieza completada:`n`n" +
                             "Archivos eliminados: $deletedFiles`n" +
                             "Espacio liberado: $([math]::Round($deletedBytes / 1MB, 2)) MB"
    
            # Mostrar mensaje con detalles
            [System.Windows.MessageBox]::Show(
                $resultMessage, 
                "Limpieza de Archivos Temporales", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Information
            )
    
            # Mensaje de consola adicional
            Write-Host $resultMessage
        } catch {
            # Mensaje de error
            $errorMessage = "Error durante la limpieza de archivos temporales:`n$_"
            
            [System.Windows.MessageBox]::Show(
                $errorMessage, 
                "Error", 
                [System.Windows.MessageBoxButton]::OK, 
                [System.Windows.MessageBoxImage]::Error
            )
    
            # Mensaje de consola para error
            Write-Host $errorMessage -ForegroundColor Red
        }
    })
    $tempFilesBtn.Add_MouseEnter({ $this.Background = "#4a4a4a" })
    $tempFilesBtn.Add_MouseLeave({ $this.Background = "#3a3a3a" })
    $cleanupOptions.Children.Add($tempFilesBtn)
    
    # Opción 2: Optimizar RAM
    $ramBtn = New-Object System.Windows.Controls.Button
    $ramBtn.Content = "Optimizar RAM"
    $ramBtn.Padding = New-Object System.Windows.Thickness(15, 8, 15, 8)
    $ramBtn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 0)
    $ramBtn.Background = "#3a3a3a"
    $ramBtn.Foreground = "White"
    $ramBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $ramBtn.HorizontalAlignment = "Stretch"
    $ramBtn.HorizontalContentAlignment = "Left"
    # Opción 2: Optimizar RAM
$ramBtn.Add_Click({
    try {
        # Descargar el archivo ZIP
        $zipUrl = "https://download.sysinternals.com/files/RAMMap.zip"
        $downloadPath = "$env:TEMP\RAMMap.zip"
        $extractPath = "$env:TEMP\RAMMap"

        Invoke-WebRequest -Uri $zipUrl -OutFile $downloadPath

        # Descomprimir el archivo ZIP
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force

        # Ruta al ejecutable RAMMap.exe
        $executablePath = Join-Path $extractPath "RAMMap.exe"

        # Ejecutar RAMMap.exe
        Start-Process -FilePath $executablePath

        [System.Windows.Forms.MessageBox]::Show("RAMMap ejecutado correctamente", "Completado")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error al limpiar y optimizar la RAM:`n$error", "Error")
    }
})
    $ramBtn.Add_MouseEnter({ $this.Background = "#4a4a4a" })
    $ramBtn.Add_MouseLeave({ $this.Background = "#3a3a3a" })
    $cleanupOptions.Children.Add($ramBtn)
    
    # Evento para expandir/contraer el panel de limpieza
    $cleanupBtn.Add_Click({
        if ($cleanupOptions.Visibility -eq "Collapsed") {
            $cleanupOptions.Visibility = "Visible"
            $this.Tag = "expanded"
            $this.Content = "7. Limpieza ▼"
        } else {
            $cleanupOptions.Visibility = "Collapsed"
            $this.Tag = "collapsed"
            $this.Content = "7. Limpieza"
        }
    })
    
    $cleanupBtn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
    $cleanupBtn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $repairWindow.DragMove()
    })
    
    # Mostrar ventana
    $repairWindow.ShowDialog()
})
$window.FindName("Btn4").Add_Click({ 
    # Crear ventana de Mejoras y Utilidades
    $tweaksWindow = New-Object System.Windows.Window
    $tweaksWindow.Title = "Mejoras y Utilidades"
    $tweaksWindow.Width = 650
    $tweaksWindow.Height = 550
    $tweaksWindow.WindowStartupLocation = "CenterOwner"
    $tweaksWindow.Owner = $window
    $tweaksWindow.Background = "Transparent"
    $tweaksWindow.AllowsTransparency = $true
    $tweaksWindow.WindowStyle = "None"
    $tweaksWindow.ResizeMode = "CanResizeWithGrip"
    
    # Contenedor principal con borde redondeado
    $mainBorder = New-Object System.Windows.Controls.Border
    $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $mainBorder.Background = "#121212"
    $tweaksWindow.Content = $mainBorder
    
    # Grid principal
    $mainGrid = New-Object System.Windows.Controls.Grid
    $mainBorder.Child = $mainGrid
    
    # Definir filas para el grid
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    $mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
    
    # Barra superior
    $topBar = New-Object System.Windows.Controls.Border
    $topBar.Background = "#1e1e1e"
    $topBar.CornerRadius = New-Object System.Windows.CornerRadius(10, 10, 0, 0)
    $topBar.Height = 40
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)
    $mainGrid.Children.Add($topBar)
    
    # Grid para la barra superior
    $topBarGrid = New-Object System.Windows.Controls.Grid
    $topBar.Child = $topBarGrid
    
    # Título de la ventana
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = "MEJORAS Y UTILIDADES"
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = "Bold"
    $titleBlock.Foreground = "White"
    $titleBlock.VerticalAlignment = "Center"
    $titleBlock.Margin = New-Object System.Windows.Thickness(15, 0, 0, 0)
    $topBarGrid.Children.Add($titleBlock)
    
    # Botón de cierre
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "X"
    $closeBtn.FontSize = 14
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.Background = "Transparent"
    $closeBtn.Foreground = "White"
    $closeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    $closeBtn.HorizontalAlignment = "Right"
    $closeBtn.Cursor = "Hand"
    $closeBtn.Add_Click({ $tweaksWindow.Close() })
    $closeBtn.Add_MouseEnter({ $this.Background = "#E81123" })
    $closeBtn.Add_MouseLeave({ $this.Background = "Transparent" })
    $topBarGrid.Children.Add($closeBtn)
    
    # ScrollViewer para el contenido
    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.Margin = New-Object System.Windows.Thickness(0)
    $scrollViewer.Padding = New-Object System.Windows.Thickness(0)
    [System.Windows.Controls.Grid]::SetRow($scrollViewer, 1)
    $mainGrid.Children.Add($scrollViewer)
    
    # Panel principal para los botones
    $tweaksPanel = New-Object System.Windows.Controls.StackPanel
    $tweaksPanel.Margin = New-Object System.Windows.Thickness(20)
    $scrollViewer.Content = $tweaksPanel
    
    # Definir botones con sus textos
    $buttonTexts = @(
        "Ejecutar WinUtil",
        "Instalar Winget",
        "Activar Windows",
        "Ejecutar Optimizer",
        "Buscar Drivers",
        "Actualizar Windows",
        "Analizar y Optimizar S.O.",
        "Propiedades del Sistema",
        "Deshabilitar Transparencia",
        "Apagar y Entrar a BIOS",
        "Ingresar al Entorno de Recuperación",
        "Actualizar Apps"
    )
    
    # Crear botones
    foreach ($text in $buttonTexts) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $text
        $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
        $btn.Padding = New-Object System.Windows.Thickness(15, 10, 15, 10)
        $btn.Background = "#2d2d2d"
        $btn.Foreground = "White"
        $btn.BorderThickness = New-Object System.Windows.Thickness(0)
        $btn.HorizontalAlignment = "Stretch"
        $btn.HorizontalContentAlignment = "Left"
        $btn.FontSize = 14
        
        # Efecto hover
        $btn.Add_MouseEnter({ $this.Background = "#3a3a3a" })
        $btn.Add_MouseLeave({ $this.Background = "#2d2d2d" })
        
        # Lógica específica para cada botón
        if ($text -eq "Ejecutar WinUtil") {
            $btn.Add_Click({
                # Intentar abrir PowerShell 7 primero, si no está disponible, abrir PowerShell 5
                $pwsh7Path = (Get-Command "pwsh" -ErrorAction SilentlyContinue).Source
                $scriptCommand = "-NoExit -NoProfile -ExecutionPolicy Bypass -Command `"irm christitus.com/win | iex`""
                
                if ($pwsh7Path) {
                    Start-Process $pwsh7Path -ArgumentList $scriptCommand -Verb RunAs
                } else {
                    # Usar PowerShell predeterminado
                    Start-Process "powershell.exe" -ArgumentList "-NoExit", "-Command", "irm christitus.com/win | iex" -Verb RunAs
                }
            })
        } elseif ($text -eq "Instalar Winget") {
            $btn.Add_Click({
                Start-Process powershell -ArgumentList "-NoExit -Command `"Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle; Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx; Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile Microsoft.UI.Xaml.2.7.x64.appx; Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx; Add-AppxPackage Microsoft.UI.Xaml.2.7.x64.appx; Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle`""
            })
        } elseif ($text -eq "Activar Windows") {
            $btn.Add_Click({
                # Obtener la clave digital usando PowerShell
                $clave = (Get-WmiObject SoftwareLicensingService | Select-Object -ExpandProperty OA3xOriginalProductKey)

                # Mostrar la clave obtenida
                Write-Host "La clave digital es: $clave"

                # Establecer la clave como predefinida
                slmgr.vbs /ipk $clave

                # Mostrar mensaje de confirmación
                Write-Host "Clave establecida como predefinida correctamente."
            })
        } elseif ($text -eq "Ejecutar Optimizer") {
            $btn.Add_Click({
                $url = "https://github.com/hellzerg/optimizer/releases/download/16.7/Optimizer-16.7.exe"
                $outputFolder = "C:\ToolboxBS"
                $outputPath = Join-Path $outputFolder "Optimizer-16.7.exe"

                # Verifica si la carpeta de destino existe, si no, la crea
                if (-not (Test-Path -Path $outputFolder -PathType Container)) {
                    New-Item -ItemType Directory -Force -Path $outputFolder
                }

                try {
                    Invoke-WebRequest -Uri $url -OutFile $outputPath
                } catch {
                    [System.Windows.MessageBox]::Show("Error al descargar Optimizer: $_", "Error de Descarga")
                    return
                }

                try {
                    Start-Process -FilePath $outputPath
                } catch {
                    [System.Windows.MessageBox]::Show("Error al ejecutar Optimizer: $_", "Error de Ejecucion")
                }
            })
        } elseif ($text -eq "Buscar Drivers") {
            $btn.Add_Click({
                function ObtenerInformacionEquipo {
                    $modelo = (Get-WmiObject -Class:Win32_ComputerSystem).Model
                    $serial = (Get-WmiObject -Class:Win32_BIOS).SerialNumber
                    return $modelo, $serial
                }

                $modelo, $serial = ObtenerInformacionEquipo
                Write-Host "Tu equipo es: $modelo, Numero de serie: $serial"
                # Construir la URL con el modelo y número de serie para buscar drivers
                $url = "https://www.google.com/search?q=$modelo+$serial+drivers"
                Start-Process $url
            })
        } elseif ($text -eq "Actualizar Windows") {
            $btn.Add_Click({
                Write-Output "Iniciando búsqueda de actualizaciones de Windows..."
                Start-Process -FilePath "C:\Windows\System32\UsoClient.exe" -ArgumentList "StartInteractiveScan" -NoNewWindow
                Write-Output "Proceso de actualizaciones iniciado."
            })
        } elseif ($text -eq "Analizar y Optimizar S.O.") {
            $btn.Add_Click({
                Write-Output "Iniciando análisis y optimización del sistema en una nueva ventana..."
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/Analizador.ps1' | iex`""
                Write-Output "Proceso de análisis y optimización iniciado en una nueva ventana."
            })
        } elseif ($text -eq "Propiedades del Sistema") {
            $btn.Add_Click({
                # Abrir la ventana de ajustes de rendimiento de Windows
                control.exe sysdm.cpl
            })
        } elseif ($text -eq "Deshabilitar Transparencia") {
            $btn.Add_Click({
                # Deshabilitar la transparencia en la configuración de Windows de forma automática
                $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                $name = "EnableTransparency"
                $value = 0
                Set-ItemProperty -Path $registryPath -Name $name -Value $value
                [System.Windows.MessageBox]::Show("Transparencia deshabilitada correctamente.", "Configuración Aplicada", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            })
        } elseif ($text -eq "Apagar y Entrar a BIOS") {
            $btn.Add_Click({
                # Apagar y entrar a la BIOS como administrador
                $result = [System.Windows.MessageBox]::Show("Se apagará el sistema y entrará a la BIOS. ¿Desea continuar?", "Confirmar", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    Start-Process -FilePath "shutdown" -ArgumentList "/r /fw /t 1" -Verb RunAs
                }
            })
        } elseif ($text -eq "Ingresar al Entorno de Recuperación") {
            $btn.Add_Click({
                # Ingresar al entorno de recuperación
                $result = [System.Windows.MessageBox]::Show("Se reiniciará el sistema y entrará al entorno de recuperación. ¿Desea continuar?", "Confirmar", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    shutdown /r /o /f /t 00
                }
            })
        } elseif ($text -eq "Actualizar Apps") {
            $btn.Add_Click({
                # Run the winget update command
                Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "winget update --all" -NoNewWindow
            })
        } else {
            # Evento genérico para botones sin lógica específica
            $btn.Add_Click({
                $buttonText = $this.Content
                [System.Windows.MessageBox]::Show("Has seleccionado: $buttonText", "Información", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            })
        }
        
        $tweaksPanel.Children.Add($btn)
    }
    
    # Permitir mover la ventana arrastrando la barra superior
    $topBar.Add_MouseLeftButtonDown({
        $tweaksWindow.DragMove()
    })
    
    # Mostrar ventana
    $tweaksWindow.ShowDialog()
})
# Ajustar esquinas cuando la ventana cambia de estado
$window.Add_StateChanged({
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(0)
    } else {
        $mainBorder.CornerRadius = New-Object System.Windows.CornerRadius(10)
    }
})


# Mostrar ventana
$window.ShowDialog() | Out-Null
Start-Process "https://brandonsepulveda.github.io"
# SIG # Begin signature block
# MIIb2gYJKoZIhvcNAQcCoIIbyzCCG8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD7rSpvF3F/HkMP
# i8AylROS2Wv3MgQq52AxCHH/gSf4z6CCFiEwggMaMIICAqADAgECAhB9gfCQMYHb
# oEtXJstOGle0MA0GCSqGSIb3DQEBCwUAMCUxIzAhBgNVBAMMGkJyYW5kb25TZXB1
# bHZlZGEgVG9vbGJveEJTMB4XDTI1MDQwOTEzMjE1MloXDTI2MDQwOTEzNDE1Mlow
# JTEjMCEGA1UEAwwaQnJhbmRvblNlcHVsdmVkYSBUb29sYm94QlMwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQCy6T+12JfPKTUDcWTj44nDOREZajpL9uuh
# P3dxXkGJsyeZy3QIt4zTglBDwlNKW0PZFmTgqGvOvt+XF9cerOjanz14kxXoCHhF
# +763PnC/xdsCCNzsxtek2uxbSp4fm2Vdoic+UD8dv+k38T0amkeDIXHRRu6bijRP
# G30AzXnQbXA0Sb2aY6ZGx507BIqdVZ5LCWBiTYsZ3n4H6vYFEJ5egX1xTf1MQs7V
# CPYROklArDdevMl+rIKmHdmsv5xpLOLFy+ziF97IFSS9WvESwvZMMRXOJF348Dx8
# TmBpvnmbXCiyYpBxD2aaEe3goZqtmay5MuWDIT1zP+fYt982CW51AgMBAAGjRjBE
# MA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQU
# 8w/CkARHolstnZgUGCab8mdKI9QwDQYJKoZIhvcNAQELBQADggEBAJcTKDxlUJdj
# CKKpSYAuYIecPDb9lCmpimVUBRWHnWoWxHAXu5YdZZwJQPfekbqM1MOgdv10468L
# ObBDBgSrZrd6FeMXN1FsjD4TiRsMrE1nmYc6U5O4z3oBzWps8ZNQj2dKoMbMlRRi
# UtFHN6yBDbzq2L3/AWud6l4eCku7aw9nUuaGnBpgkNGF1Gk1XrSswbxYha2txlix
# ZDJ9N2FOR8t+Sp8QInbyV71fylML+r5iDRdoquPw3H0UvrrFjICRTK6ZHNK/Ix5Y
# du2Y10WV4emD4H+14DrHkuTWMqb6rrk6cS2mME+X7JFSAMWTcg0Ofb+zj+v5DpXm
# b8rqw71uksowggWNMIIEdaADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3
# DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3Vy
# ZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBH
# NDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIw
# aTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLK
# EdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4Tm
# dDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembu
# d8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnD
# eMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1
# XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVld
# QnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTS
# YW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSm
# M9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzT
# QRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6Kx
# fgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/
# MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv
# 9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBr
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUH
# MAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYG
# BFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72a
# rKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFID
# yE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/o
# Wajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv
# 76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30
# fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwggauMIIE
# lqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0y
# MjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBH
# NCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE8pE3qZdRodbSg9GeTKJt
# oLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBMLJnOWbfhXqAJ9/UO0hNoR
# 8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU5ygt69OxtXXnHwZljZQp
# 09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLydkf3YYMZ3V+0VAshaG43
# IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFkdECnwHLFuk4fsbVYTXn+
# 149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUmcJgmf6AaRyBD40NjgHt1bicl
# kJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9abJTyUpURK1h0QCirc0PO
# 30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwYSH8UNM/STKvvmz3+Drhk
# Kvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80VgvCONWPfcYd6T/jnA+bIw
# pUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5FBASA31fI7tk42PgpuE+
# 9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9Rp6103a50g5rmQzSM7TN
# sQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUuhbZ
# bU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4c
# D08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUF
# BwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEG
# CCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAH1ZjsCT
# tm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp+3CKDaopafxpwc8dB+k+
# YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9qVbPFXONASIlzpVpP0d3
# +3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8ZCaHbJK9nXzQcAp876i8
# dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6ZJxurJB4mwbfeKuv2nrF5
# mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnEtp/Nh4cku0+jSbl3ZpHx
# cpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fxZsNBzU+2QJshIUDQtxMk
# zdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV77QpfMzmHQXh6OOmc4d0j
# /R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT1ObyF5lZynDwN7+YAN8g
# Fk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkPCr2B2RP+v6TR81fZvAT6
# gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvmfxqkhQ/8mJb2VVQrH4D6
# wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIGvDCCBKSgAwIBAgIQC65mvFq6
# f5WHxvnpBOMzBDANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQg
# UlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTI0MDkyNjAwMDAwMFoX
# DTM1MTEyNTIzNTk1OVowQjELMAkGA1UEBhMCVVMxETAPBgNVBAoTCERpZ2lDZXJ0
# MSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyNDCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBAL5qc5/2lSGrljC6W23mWaO16P2RHxjEiDtqmeOl
# wf0KMCBDEr4IxHRGd7+L660x5XltSVhhK64zi9CeC9B6lUdXM0s71EOcRe8+CEJp
# +3R2O8oo76EO7o5tLuslxdr9Qq82aKcpA9O//X6QE+AcaU/byaCagLD/GLoUb35S
# fWHh43rOH3bpLEx7pZ7avVnpUVmPvkxT8c2a2yC0WMp8hMu60tZR0ChaV76Nhnj3
# 7DEYTX9ReNZ8hIOYe4jl7/r419CvEYVIrH6sN00yx49boUuumF9i2T8UuKGn9966
# fR5X6kgXj3o5WHhHVO+NBikDO0mlUh902wS/Eeh8F/UFaRp1z5SnROHwSJ+QQRZ1
# fisD8UTVDSupWJNstVkiqLq+ISTdEjJKGjVfIcsgA4l9cbk8Smlzddh4EfvFrpVN
# nes4c16Jidj5XiPVdsn5n10jxmGpxoMc6iPkoaDhi6JjHd5ibfdp5uzIXp4P0wXk
# gNs+CO/CacBqU0R4k+8h6gYldp4FCMgrXdKWfM4N0u25OEAuEa3JyidxW48jwBqI
# JqImd93NRxvd1aepSeNeREXAu2xUDEW8aqzFQDYmr9ZONuc2MhTMizchNULpUEoA
# 6Vva7b1XCB+1rxvbKmLqfY/M/SdV6mwWTyeVy5Z/JkvMFpnQy5wR14GJcv6dQ4aE
# KOX5AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAW
# BgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglg
# hkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2FL3MpdpovdYxqII+eyG8wHQYDVR0O
# BBYEFJ9XLAN3DigVkGalY17uT5IfdqBbMFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEy
# NTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUF
# BzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6
# Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZT
# SEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggIBAD2tHh92
# mVvjOIQSR9lDkfYR25tOCB3RKE/P09x7gUsmXqt40ouRl3lj+8QioVYq3igpwrPv
# BmZdrlWBb0HvqT00nFSXgmUrDKNSQqGTdpjHsPy+LaalTW0qVjvUBhcHzBMutB6H
# zeledbDCzFzUy34VarPnvIWrqVogK0qM8gJhh/+qDEAIdO/KkYesLyTVOoJ4eTq7
# gj9UFAL1UruJKlTnCVaM2UeUUW/8z3fvjxhN6hdT98Vr2FYlCS7Mbb4Hv5swO+aA
# XxWUm3WpByXtgVQxiBlTVYzqfLDbe9PpBKDBfk+rabTFDZXoUke7zPgtd7/fvWTl
# Cs30VAGEsshJmLbJ6ZbQ/xll/HjO9JbNVekBv2Tgem+mLptR7yIrpaidRJXrI+Uz
# B6vAlk/8a1u7cIqV0yef4uaZFORNekUgQHTqddmsPCEIYQP7xGxZBIhdmm4bhYsV
# A6G2WgNFYagLDBzpmk9104WQzYuVNsxyoVLObhx3RugaEGru+SojW4dHPoWrUhft
# NpFC5H7QEY7MhKRyrBe7ucykW7eaCuWBsBb4HOKRFVDcrZgdwaSIqMDiCLg4D+TP
# VgKx2EgEdeoHNHT9l3ZDBD+XgbF+23/zBjeCtxz+dL/9NWR6P2eZRi7zcEO1xwcd
# cqJsyz/JceENc2Sg8h3KeFUCS7tpFk7CrDqkMYIFDzCCBQsCAQEwOTAlMSMwIQYD
# VQQDDBpCcmFuZG9uU2VwdWx2ZWRhIFRvb2xib3hCUwIQfYHwkDGB26BLVybLThpX
# tDANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkG
# CSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEE
# AYI3AgEVMC8GCSqGSIb3DQEJBDEiBCA0VdHkv77j27CxCdnRORaDfZzg7hWcX1g/
# ZLOXkwZ4hjANBgkqhkiG9w0BAQEFAASCAQCu2tayzS5N6TpGVHepacBWiFPJgtzN
# UKUpy1w6GJIzwJFaFRBHZm3DIvKeZ7pC4GrrhT8cCJJ+V54NlpXEMtzDE+JI6C5S
# AfoPLy310HNzxd+dunhjOd1Hu8bvlbsjKzC/20nYBCWaWOoAWCDIbTteQ09oAIB1
# tPVzZmAr6kJsRoLzG5cA1hdbkLS4Rth/WVzF0du2hfQgMrFKSkluZgiZgoj9O3RZ
# l+oe5Pz/1xrd3huS5lMKCYiuw1l6Rc6SvVp7EN6XkrdQVSOm/0IDEThCbSya4rn/
# KzZGQXng75QY8JhtvTm1feuixrKczQiVPZ5tNmywwcIXXvEG6W2ifGG8oYIDIDCC
# AxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAVBgNV
# BAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0
# IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQC65mvFq6f5WHxvnpBOMz
# BDANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTI1MDQwOTEzMzgzMVowLwYJKoZIhvcNAQkEMSIEIEhlTGQ8
# r+IYSxIh9FZneNJbQvKEi8AjPef+YIK1MJhqMA0GCSqGSIb3DQEBAQUABIICAGH8
# uTydSRepde7BX/77IULleAXSzqVjocfRCm++F6OnBMtWSzfa928viMHnpgRSz4WA
# r0xLtjW96xTkAIB5hVrz6Jr0DNquZVvZLhc3kzIKz3bVVzZzeV/qaFH9FUBOjswE
# 8WjGedtbjlgHMILBg2I6vP8CO6cpFUqp+Aof2wihOvF/dZRS+KTyYjYPfrT7bckt
# y3/5wgUEYt2aRDKjwWbSoecxoSw4rDO0yk49lzAHPUzd3ne89uRq28/wE46adABS
# z9A1OMy3OkqxBhXC9tgyU9BZs7DGk5ENicVk4wqdO1U0pHZXrQ7J2sjJyfaKhbdm
# 7uzbZsU/xpCnQss5MsbG8alI7jYWyX2jL2gASJLJjBIh8SDkCpopBLKvTct+CS8N
# L0ydhAdCKykr6cZsEI7xb3pEnQRpLZzA2zG3UEbwA3+uNcPR2PH9zgxkQ/jT8xTQ
# XsUqF1EO7EQ87CVi6CMdesJbDBF7DlR72aGFyZqsHkpUl+5+LKyz4+5SRes0fm6O
# 3ky5BrTVLsWkkFInaVTL7T/I5xmzf0oSUFDwuOK4NZ+gUSMEJRS6IDIArhebqgB/
# 9p1LFlR+DhjII8b3kp26bCQVdG4eI+Sv8UQyVzOFgVVQlZAddALwSWNQyG+HuP4O
# XTqP0piBKKpk/n63J5+DDf0ZIOc4ObhKWH/UXCRK
# SIG # End signature block
