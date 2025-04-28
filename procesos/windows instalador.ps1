# MSDL Windows ISO Downloader (Con Diagnóstico)
# Este script utiliza la API de MSDL para obtener enlaces directos de descarga de ISO de Windows
# Versión con diagnóstico de errores

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Constantes
$apiUrl = "https://api.gravesoft.dev/msdl/"

# Definición de productos (solo los que tienen corazones)
$products = @{
    "2618" = "Windows 10 22H2 v1 (19045.2965)"
    "3113" = "Windows 11 24H2 (26100.1742)"
}

# Generar UUID v4 similar a JavaScript
function New-UUID {
    return [guid]::NewGuid().ToString()
}

# Función para obtener la información de idiomas disponibles para un producto
function Get-LanguagesInfo {
    param (
        [string]$ProductId
    )
    
    try {
        $url = "${apiUrl}skuinfo?product_id=${ProductId}"
        Write-Host "Accediendo a URL: $url" -ForegroundColor Cyan
        
        # Usar TLS 1.2 para evitar problemas de conexión
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Agregar encabezados HTTP para simular un navegador
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            "Accept" = "*/*"
        }
        
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        Write-Host "Respuesta recibida correctamente" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "Error al obtener información de idiomas: $_" -ForegroundColor Red
        return $null
    }
}

# Función para obtener enlaces de descarga
function Get-DownloadLinks {
    param (
        [string]$ProductId,
        [string]$SkuId
    )
    
    try {
        $url = "${apiUrl}proxy?product_id=${ProductId}&sku_id=${SkuId}"
        Write-Host "Accediendo a URL: $url" -ForegroundColor Cyan
        
        # Usar TLS 1.2 para evitar problemas de conexión
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Agregar encabezados HTTP para simular un navegador
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            "Accept" = "*/*"
        }
        
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        Write-Host "Respuesta recibida correctamente" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "Error al obtener enlaces de descarga: $_" -ForegroundColor Red
        return $null
    }
}

# Prueba directa para diagnosticar
function Test-ApiConnection {
    try {
        Write-Host "Probando conexión a la API..." -ForegroundColor Yellow
        $testUrl = "${apiUrl}skuinfo?product_id=3113" # Windows 11 24H2
        
        # Usar TLS 1.2 para evitar problemas de conexión
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Agregar encabezados HTTP para simular un navegador
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            "Accept" = "*/*"
        }
        
        $response = Invoke-RestMethod -Uri $testUrl -Method Get -Headers $headers -TimeoutSec 30
        Write-Host "Conexión exitosa. Respuesta recibida." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error en prueba de conexión: $_" -ForegroundColor Red
        return $false
    }
}

# XAML para la interfaz gráfica
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="MSDL Windows ISO Downloader" Height="900" Width="1100" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#0078D7"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="15,10"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#106EBE"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#005A9E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Encabezado -->
        <Border Grid.Row="0" Background="#0078D7" Padding="20,15">
            <StackPanel>
                <TextBlock Text="MSDL Windows ISO Downloader" FontSize="24" FontWeight="Bold" Foreground="White"/>
                <TextBlock Text="Descarga directa de archivos ISO de Windows oficiales usando la API de MSDL" FontSize="14" Foreground="White" Margin="0,5,0,0"/>
            </StackPanel>
        </Border>
        
        <!-- Contenido principal -->
        <Grid Grid.Row="1" Margin="20">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2*"/>
                <ColumnDefinition Width="3*"/>
            </Grid.ColumnDefinitions>
            
            <!-- Panel izquierdo - Selección de producto -->
            <DockPanel Grid.Column="0" Margin="0,0,10,0">
                <Border Background="#F0F0F0" CornerRadius="8" Padding="15" DockPanel.Dock="Top">
                    <DockPanel>
                        <TextBlock Text="Selecciona una versión de Windows" FontWeight="SemiBold" FontSize="16" DockPanel.Dock="Top"/>
                        <ListBox x:Name="lstProducts" Margin="0,10,0,0" FontSize="14" SelectionMode="Single" Background="White" BorderThickness="0" Height="150"/>
                    </DockPanel>
                </Border>
                
                <Border Background="#F0F0F0" CornerRadius="8" Padding="15" DockPanel.Dock="Bottom" Margin="0,20,0,0">
                    <StackPanel>
                        <TextBlock Text="Diagnóstico" FontWeight="SemiBold" FontSize="16"/>
                        <TextBox x:Name="txtLog" Height="250" Margin="0,10,0,0" IsReadOnly="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" Background="#FAFAFA"/>
                        <Button x:Name="btnTestApi" Content="Probar Conexión a API" Margin="0,10,0,0" Height="35"/>
                        <Button x:Name="btnDirectDownload" Content="Probar Enlace Directo" Margin="0,10,0,0" Height="35"/>
                    </StackPanel>
                </Border>
            </DockPanel>
            
            <!-- Panel derecho - Panel multifuncional -->
            <Grid Grid.Column="1" Margin="10,0,0,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <!-- Paneles principales -->
                <Border x:Name="pnlProductsList" Background="#F0F0F0" CornerRadius="8" Padding="15" Visibility="Visible" Grid.Row="0">
                    <TextBlock Text="Selecciona una versión de Windows para comenzar" FontSize="16" TextWrapping="Wrap"/>
                </Border>
                
                <Border x:Name="pnlLanguageSelection" Background="#F0F0F0" CornerRadius="8" Padding="15" Visibility="Collapsed" Grid.Row="0">
                    <StackPanel>
                        <TextBlock x:Name="txtSelectedProduct" Text="Producto seleccionado" FontWeight="Bold" FontSize="18" TextWrapping="Wrap"/>
                        <TextBlock Text="Selecciona el idioma:" FontWeight="SemiBold" FontSize="16" Margin="0,20,0,5"/>
                        <TextBlock Text="Necesitarás elegir el mismo idioma cuando instales Windows. Para ver qué idioma estás usando actualmente, ve a Hora e idioma en la configuración de PC o Región en el Panel de control." TextWrapping="Wrap" Margin="0,0,0,10"/>
                        <ComboBox x:Name="cmbLanguages" Height="35" FontSize="14" Margin="0,5"/>
                        
                        <Button x:Name="btnGetDownloadLinks" Content="OBTENER ENLACES DE DESCARGA" Margin="0,20,0,0" Height="45" FontSize="16"/>
                    </StackPanel>
                </Border>
                
                <Border x:Name="pnlDownloadLinks" Background="#F0F0F0" CornerRadius="8" Padding="15" Visibility="Collapsed" Grid.Row="0">
                    <StackPanel>
                        <TextBlock x:Name="txtProductAndLanguage" Text="Producto e idioma" FontWeight="Bold" FontSize="18" TextWrapping="Wrap"/>
                        <TextBlock Text="Enlaces de descarga disponibles:" FontWeight="SemiBold" FontSize="16" Margin="0,20,0,10"/>
                        
                        <ListBox x:Name="lstDownloadLinks" Margin="0,5,0,0" FontSize="14" SelectionMode="Single" Background="White" BorderThickness="0" Height="180"/>
                        
                        <TextBlock Text="Ubicación de descarga:" FontWeight="SemiBold" FontSize="16" Margin="0,20,0,5"/>
                        <DockPanel Margin="0,5">
                            <Button x:Name="btnBrowse" Content="Examinar..." DockPanel.Dock="Right" Width="100" Height="35"/>
                            <TextBox x:Name="txtSavePath" Height="35" FontSize="14" Padding="5" VerticalContentAlignment="Center"/>
                        </DockPanel>
                        
                        <Button x:Name="btnStartDownload" Content="INICIAR DESCARGA" Margin="0,20,0,0" Height="45" FontSize="16" Background="#107C10"/>
                    </StackPanel>
                </Border>
                
                <Border x:Name="pnlPleaseWait" Background="#F0F0F0" CornerRadius="8" Padding="15" Visibility="Collapsed" Grid.Row="0">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                        <TextBlock Text="Por favor espere..." FontSize="20" FontWeight="SemiBold" HorizontalAlignment="Center"/>
                        <ProgressBar x:Name="pbWaiting" IsIndeterminate="True" Height="20" Margin="0,20,0,0" Width="300"/>
                        <TextBlock x:Name="txtWaitingMessage" Text="Procesando solicitud..." FontSize="14" Margin="0,10,0,0" HorizontalAlignment="Center"/>
                    </StackPanel>
                </Border>
                
                <Border x:Name="pnlError" Background="#F0F0F0" CornerRadius="8" Padding="15" Visibility="Collapsed" Grid.Row="0">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                        <TextBlock Text="Error" FontSize="20" FontWeight="SemiBold" Foreground="Red" HorizontalAlignment="Center"/>
                        <TextBlock x:Name="txtErrorMessage" Text="Ha ocurrido un error al procesar la solicitud" FontSize="14" Margin="0,10,0,0" TextWrapping="Wrap" TextAlignment="Center"/>
                        <Button x:Name="btnRetry" Content="Reintentar" Margin="0,20,0,0" Height="40" Width="150"/>
                    </StackPanel>
                </Border>
                
                <!-- Panel de navegación -->
                <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                    <Button x:Name="btnBack" Content="Atrás" Width="100" Visibility="Collapsed"/>
                    <Button x:Name="btnCancel" Content="Cancelar" Width="100" Visibility="Collapsed"/>
                </StackPanel>
            </Grid>
        </Grid>
        
        <!-- Pie de página -->
        <Border Grid.Row="2" Background="#F0F0F0" Padding="20,10">
            <DockPanel>
                <TextBlock Text="© 2025 | Basado en MSDL (Microsoft Software Download Listing)" Foreground="#555555"/>
                <TextBlock x:Name="txtStatus" Text="Listo para comenzar" Foreground="#555555" HorizontalAlignment="Right"/>
            </DockPanel>
        </Border>
    </Grid>
</Window>
"@

# Función para agregar mensajes de log
function Add-Log {
    param (
        [string]$Message,
        [string]$Color = "Black"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $txtLog.Dispatcher.Invoke([Action]{
        $txtLog.AppendText("[$timestamp] $Message`r`n")
        $txtLog.ScrollToEnd()
    })
    
    # También mostrar en consola para depuración
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

# Crear el objeto Window
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Obtener elementos por nombre
$lstProducts = $window.FindName("lstProducts")
$pnlProductsList = $window.FindName("pnlProductsList")
$pnlLanguageSelection = $window.FindName("pnlLanguageSelection")
$pnlDownloadLinks = $window.FindName("pnlDownloadLinks")
$pnlPleaseWait = $window.FindName("pnlPleaseWait")
$pnlError = $window.FindName("pnlError")
$txtSelectedProduct = $window.FindName("txtSelectedProduct")
$txtProductAndLanguage = $window.FindName("txtProductAndLanguage")
$cmbLanguages = $window.FindName("cmbLanguages")
$lstDownloadLinks = $window.FindName("lstDownloadLinks")
$txtSavePath = $window.FindName("txtSavePath")
$btnBrowse = $window.FindName("btnBrowse")
$btnGetDownloadLinks = $window.FindName("btnGetDownloadLinks")
$btnStartDownload = $window.FindName("btnStartDownload")
$btnBack = $window.FindName("btnBack")
$btnCancel = $window.FindName("btnCancel")
$txtStatus = $window.FindName("txtStatus")
$txtWaitingMessage = $window.FindName("txtWaitingMessage")
$txtErrorMessage = $window.FindName("txtErrorMessage")
$btnRetry = $window.FindName("btnRetry")
$txtLog = $window.FindName("txtLog")
$btnTestApi = $window.FindName("btnTestApi")
$btnDirectDownload = $window.FindName("btnDirectDownload")

# Variables globales
$script:sessionId = New-UUID
$script:selectedProductId = $null
$script:selectedProductName = $null
$script:selectedSkuId = $null
$script:selectedLanguage = $null
$script:downloadLinks = $null
$script:currentState = "ProductSelection"

# Establecer ruta de descarga predeterminada
$txtSavePath.Text = "$env:USERPROFILE\Downloads"

# Configurar TLS 1.2 para conexiones seguras
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Función para cargar productos
function Update-ProductsList {
    $lstProducts.Items.Clear()
    
    foreach ($key in $products.Keys) {
        $productName = $products[$key]
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = $productName
        $item.Tag = $key
        $lstProducts.Items.Add($item)
    }
    
    Add-Log "Lista de productos cargada con éxito" "Green"
}

# Función para mostrar/ocultar paneles según el estado
function Set-UIState {
    param (
        [string]$State
    )
    
    $script:currentState = $State
    
    # Ocultar todos los paneles primero
    $pnlProductsList.Visibility = "Collapsed"
    $pnlLanguageSelection.Visibility = "Collapsed"
    $pnlDownloadLinks.Visibility = "Collapsed"
    $pnlPleaseWait.Visibility = "Collapsed"
    $pnlError.Visibility = "Collapsed"
    $btnBack.Visibility = "Collapsed"
    $btnCancel.Visibility = "Collapsed"
    
    # Mostrar el panel correspondiente al estado actual
    switch ($State) {
        "ProductSelection" {
            $pnlProductsList.Visibility = "Visible"
            $txtStatus.Text = "Selecciona un producto"
            Add-Log "Mostrando panel de selección de productos" "Cyan"
        }
        "LanguageSelection" {
            $pnlLanguageSelection.Visibility = "Visible"
            $btnBack.Visibility = "Visible"
            $txtStatus.Text = "Selecciona un idioma para $script:selectedProductName"
            Add-Log "Mostrando panel de selección de idiomas" "Cyan"
        }
        "DownloadLinks" {
            $pnlDownloadLinks.Visibility = "Visible"
            $btnBack.Visibility = "Visible"
            $txtStatus.Text = "Enlaces de descarga disponibles"
            Add-Log "Mostrando panel de enlaces de descarga" "Cyan"
        }
        "PleaseWait" {
            $pnlPleaseWait.Visibility = "Visible"
            $btnCancel.Visibility = "Visible"
            $txtStatus.Text = "Procesando solicitud..."
            Add-Log "Mostrando panel de espera" "Yellow"
        }
        "Error" {
            $pnlError.Visibility = "Visible"
            $btnBack.Visibility = "Visible"
            $txtStatus.Text = "Error"
            Add-Log "Mostrando panel de error" "Red"
        }
    }
}

# Evento para selección de producto
$lstProducts.Add_SelectionChanged({
    if ($lstProducts.SelectedItem -ne $null) {
        $script:selectedProductId = $lstProducts.SelectedItem.Tag
        $script:selectedProductName = $lstProducts.SelectedItem.Content
        
        Add-Log "Producto seleccionado: $script:selectedProductName (ID: $script:selectedProductId)" "Cyan"
        
        # Mostrar panel de espera
        Set-UIState "PleaseWait"
        $txtWaitingMessage.Text = "Obteniendo información de idiomas para $script:selectedProductName..."
        
        # En lugar de usar Job, hacemos la solicitud de forma síncrona para ver los errores
        try {
            Add-Log "Iniciando solicitud para obtener idiomas..." "Yellow"
            
            # Realizar la solicitud HTTP directamente
            $url = "${apiUrl}skuinfo?product_id=${script:selectedProductId}"
            Add-Log "URL de solicitud: $url" "Cyan"
            
            # Agregar encabezados HTTP para simular un navegador
            $headers = @{
                "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
                "Accept" = "*/*"
            }
            
            # Usar TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            Add-Log "Realizando solicitud HTTP..." "Yellow"
            $result = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 30
            
            if ($result -ne $null) {
                Add-Log "Respuesta recibida correctamente" "Green"
                
                # Cargar idiomas en el ComboBox
                $cmbLanguages.Items.Clear()
                
                foreach ($sku in $result.Skus) {
                    $item = New-Object System.Windows.Controls.ComboBoxItem
                    $item.Content = $sku.LocalizedLanguage
                    $item.Tag = $sku.Id
                    $cmbLanguages.Items.Add($item)
                    Add-Log "Idioma añadido: $($sku.LocalizedLanguage) (ID: $($sku.Id))" "Gray"
                }
                
                if ($cmbLanguages.Items.Count -gt 0) {
                    $cmbLanguages.SelectedIndex = 0
                    Add-Log "Seleccionado primer idioma automáticamente" "Green"
                }
                
                # Actualizar UI
                $txtSelectedProduct.Text = "Producto seleccionado: $script:selectedProductName"
                Set-UIState "LanguageSelection"
            }
            else {
                Add-Log "Error: La respuesta es nula" "Red"
                $txtErrorMessage.Text = "No se pudo obtener la información de idiomas para este producto. La respuesta del servidor fue nula."
                Set-UIState "Error"
            }
        }
        catch {
            Add-Log "Error en la solicitud HTTP: $_" "Red"
            $txtErrorMessage.Text = "No se pudo obtener la información de idiomas para este producto: $_"
            Set-UIState "Error"
        }
    }
})

# Evento para obtener enlaces de descarga
$btnGetDownloadLinks.Add_Click({
    if ($cmbLanguages.SelectedItem -ne $null) {
        $script:selectedSkuId = $cmbLanguages.SelectedItem.Tag
        $script:selectedLanguage = $cmbLanguages.SelectedItem.Content
        
        Add-Log "Idioma seleccionado: $script:selectedLanguage (ID: $script:selectedSkuId)" "Cyan"
        
        # Mostrar panel de espera
        Set-UIState "PleaseWait"
        $txtWaitingMessage.Text = "Obteniendo enlaces de descarga para $script:selectedProductName en $script:selectedLanguage..."
        
        # Realizar solicitud de forma síncrona
        try {
            Add-Log "Iniciando solicitud para obtener enlaces de descarga..." "Yellow"
            
            # Realizar la solicitud HTTP directamente
            $url = "${apiUrl}proxy?product_id=${script:selectedProductId}&sku_id=${script:selectedSkuId}"
            Add-Log "URL de solicitud: $url" "Cyan"
            
            # Agregar encabezados HTTP para simular un navegador
            $headers = @{
                "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
                "Accept" = "*/*"
            }
            
            # Usar TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            Add-Log "Realizando solicitud HTTP..." "Yellow"
            $result = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -TimeoutSec 60
            
            if ($result -ne $null -and $result.ProductDownloadOptions -ne $null -and $result.ProductDownloadOptions.Count -gt 0) {
                Add-Log "Respuesta recibida correctamente con enlaces de descarga" "Green"
                
                # Guardar los enlaces de descarga
                $script:downloadLinks = $result.ProductDownloadOptions
                
                # Cargar enlaces en el ListBox
                $lstDownloadLinks.Items.Clear()
                
                foreach ($option in $result.ProductDownloadOptions) {
                    $uri = $option.Uri
                    $filename = $uri.Split('?')[0].Split('/')[-1]
                    
                    $item = New-Object System.Windows.Controls.ListBoxItem
                    $item.Content = $filename
                    $item.Tag = $uri
                    $lstDownloadLinks.Items.Add($item)
                    
                    Add-Log "Enlace añadido: $filename" "Gray"
                    Add-Log "URL: $uri" "Gray"
                }
                
                if ($lstDownloadLinks.Items.Count -gt 0) {
                    $lstDownloadLinks.SelectedIndex = 0
                    Add-Log "Seleccionado primer enlace automáticamente" "Green"
                }
                
                # Actualizar UI
                $txtProductAndLanguage.Text = "$script:selectedProductName - $script:selectedLanguage"
                Set-UIState "DownloadLinks"
            }
            else {
                Add-Log "Error: No se encontraron enlaces de descarga" "Red"
                $txtErrorMessage.Text = "No se pudieron obtener enlaces de descarga para este producto e idioma. No se encontraron opciones de descarga."
                Set-UIState "Error"
            }
        }
        catch {
            Add-Log "Error en la solicitud HTTP: $_" "Red"
            $txtErrorMessage.Text = "No se pudieron obtener enlaces de descarga: $_"
            Set-UIState "Error"
        }
    }
})

# Evento para probar conexión a la API
$btnTestApi.Add_Click({
    Add-Log "Iniciando prueba de conexión a la API..." "Yellow"
    
    # Deshabilitar botón durante la prueba
    $btnTestApi.IsEnabled = $false
    
    $result = Test-ApiConnection
    
    if ($result) {
        Add-Log "Prueba de conexión exitosa" "Green"
        [System.Windows.Forms.MessageBox]::Show(
            "La conexión a la API de MSDL funciona correctamente.",
            "Prueba Exitosa",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    else {
        Add-Log "Prueba de conexión fallida" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "No se pudo conectar a la API de MSDL. Verifica tu conexión a Internet e intenta nuevamente.",
            "Error de Conexión",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    
    # Habilitar botón nuevamente
    $btnTestApi.IsEnabled = $true
})

# Evento para probar enlace directo
$btnDirectDownload.Add_Click({
    Add-Log "Probando descarga directa..." "Yellow"
    
    # URL de prueba (enlace a una imagen pequeña de Microsoft para prueba)
    $testUrl = "https://www.microsoft.com/favicon.ico"
    
    try {
        # Usar TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Agregar encabezados HTTP para simular un navegador
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            "Accept" = "*/*"
        }
        
        # Descargar archivo pequeño para probar
        $tempFile = [System.IO.Path]::GetTempFileName()
        Add-Log "Descargando archivo de prueba a: $tempFile" "Cyan"
        
        $webClient = New-Object System.Net.WebClient
        foreach ($header in $headers.GetEnumerator()) {
            $webClient.Headers.Add($header.Key, $header.Value)
        }
        
        $webClient.DownloadFile($testUrl, $tempFile)
        
        $fileInfo = Get-Item $tempFile
        if ($fileInfo.Length -gt 0) {
            Add-Log "Descarga de prueba exitosa (tamaño: $($fileInfo.Length) bytes)" "Green"
            [System.Windows.Forms.MessageBox]::Show(
                "La descarga de prueba fue exitosa. Tu conexión funciona correctamente.",
                "Prueba Exitosa",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            Add-Log "Archivo descargado, pero está vacío" "Red"
            [System.Windows.Forms.MessageBox]::Show(
                "El archivo se descargó pero está vacío. Puede haber un problema con la conexión.",
                "Advertencia",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
        
        # Eliminar archivo temporal
        Remove-Item $tempFile -Force
    }
    catch {
        Add-Log "Error en la descarga de prueba: $_" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Error al realizar la descarga de prueba: $_",
            "Error de Descarga",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Evento para examinar carpeta de destino
$btnBrowse.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Seleccionar carpeta para guardar el ISO"
    $folderBrowser.SelectedPath = $txtSavePath.Text
    
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $txtSavePath.Text = $folderBrowser.SelectedPath
        Add-Log "Carpeta de destino seleccionada: $($txtSavePath.Text)" "Cyan"
    }
})

# Evento para iniciar descarga con barra de progreso simple

# Función para descargar archivo con descarga optimizada

# Función para abrir enlace de descarga en el navegador
function Start-BrowserDownload {
    param (
        [string]$Url
    )

    try {
        # Intentar abrir el enlace en el navegador predeterminado
        Start-Process $Url
        
        # Mostrar mensaje informativo
        [System.Windows.Forms.MessageBox]::Show(
            "Se ha abierto el enlace de descarga en tu navegador predeterminado.`r`n`r`nSi la descarga no comienza automáticamente, copia y pega el enlace en tu navegador.",
            "Descarga en navegador",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        Add-Log "Enlace de descarga abierto en navegador" "Green"
    }
    catch {
        Write-Host "Error al abrir el enlace: $_" -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show(
            "No se pudo abrir el enlace de descarga.`r`n`r`nError: $_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# Modificar la función de descarga existente
$btnStartDownload.Add_Click({
    if ($lstDownloadLinks.SelectedItem -ne $null) {
        $downloadUrl = $lstDownloadLinks.SelectedItem.Tag
        $filename = $lstDownloadLinks.SelectedItem.Content
        $savePath = Join-Path $txtSavePath.Text $filename
        
        # Preguntar si sobrescribir archivo existente
        if (Test-Path $savePath) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "El archivo ya existe. ¿Deseas sobrescribirlo?",
                "Archivo existente",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -eq "No") {
                Add-Log "Descarga cancelada por el usuario (archivo existente)" "Yellow"
                return
            }
        }

        # Abrir enlace en navegador
        Start-BrowserDownload -Url $downloadUrl
    }
})


# Evento para volver atrás
$btnBack.Add_Click({
    switch ($script:currentState) {
        "LanguageSelection" {
            Set-UIState "ProductSelection"
        }
        "DownloadLinks" {
            Set-UIState "LanguageSelection"
        }
        "Error" {
            if ($script:selectedSkuId -ne $null) {
                Set-UIState "LanguageSelection"
            } else {
                Set-UIState "ProductSelection"
            }
        }
    }
})

# Evento para cancelar
$btnCancel.Add_Click({
    Add-Log "Operación cancelada por el usuario" "Yellow"
    Set-UIState "ProductSelection"
})

# Evento para reintentar
$btnRetry.Add_Click({
    Add-Log "Reintentando operación..." "Yellow"
    if ($script:selectedSkuId -ne $null) {
        Set-UIState "LanguageSelection"
    } 
    elseif ($script:selectedProductId -ne $null) {
        # Simular clic en el producto
        foreach ($item in $lstProducts.Items) {
            if ($item.Tag -eq $script:selectedProductId) {
                $lstProducts.SelectedItem = $item
                break
            }
        }
    } 
    else {
        Set-UIState "ProductSelection"
    }
})

# Agregar mensaje de inicio
Add-Log "Aplicación iniciada" "Green"
Add-Log "Versión de PowerShell: $($PSVersionTable.PSVersion)" "Cyan"
Add-Log "Configuración de TLS: $([Net.ServicePointManager]::SecurityProtocol)" "Cyan"

# Cargar productos iniciales
Update-ProductsList

# Establecer estado inicial
Set-UIState "ProductSelection"

# Verificar conexión a la API al inicio
try {
    Add-Log "Verificando conexión a la API de MSDL..." "Yellow"
    $result = Test-ApiConnection
    if ($result) {
        Add-Log "Conexión a la API verificada correctamente" "Green"
    } else {
        Add-Log "Advertencia: No se pudo verificar la conexión a la API" "Yellow"
    }
} catch {
    Add-Log "Error al verificar la conexión a la API: $_" "Red"
}

# Mostrar ventana
$window.ShowDialog() | Out-Null