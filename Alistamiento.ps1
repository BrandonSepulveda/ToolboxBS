Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Custom checkbox names
$checkboxNames = @(
    "Revisar estado físico del equipo (Humedad)",
    "Iniciar alistamiento en Aluna Java",
    "Revisar requisitos del pedido",
    "Realizar mantenimiento al portátil",
    "Ensamblar y ajustar partes",
    "Conectar a la red eléctrica",
    "Restaurar configuración del SETUP",
    "Instalar sistema",
    "Revisar Hardware desde Winpe (Disco, batería, USB, Und. opticas, mouse, teclado)",
    "Configuración gpedit y P. Sistema Con.",
    "Windows Update (Si lo requiere)",
    "Instalar aplicativos del fabricante (TechPulse validar serial original v/s Tapa v/s Aluna)",
    "Instalar y activar todo",
    "Solicitar licenciamiento (Si lo requiere)",
    "Revisar todos los puertos y sensor de huella",
    "Configurar dispositivos externos",
    "Realizar tres reinicios de seguridad y verificar presentación final",
    "Formatear equipo (Pedido sin sistema)",
    "Liberar en Aluna, revisar tornillos y cauchos"
)

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Alistamiento Milenio PC 2"
$form.Size = New-Object System.Drawing.Size(500, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ControlBox = $false

# Create an array to hold checkboxes
$checkBoxes = @()

# Create checkboxes with custom names
for ($i = 0; $i -lt $checkboxNames.Length; $i++) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $checkboxNames[$i]
    $checkbox.Location = New-Object System.Drawing.Point(20, (30 + $i * 25))
    $checkbox.AutoSize = $true
    $checkbox.Tag = $i

    $checkbox.Add_CheckStateChanged({
        param($sender, $e)
        $currentIndex = $sender.Tag

        if ($currentIndex -gt 0 -and -not $checkBoxes[$currentIndex - 1].Checked) {
            $sender.Checked = $false
            [System.Windows.Forms.MessageBox]::Show("Debe marcar '$($checkboxNames[$currentIndex - 1])' antes de marcar esta casilla.", "Atención", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    
    $form.Controls.Add($checkbox)
    $checkBoxes += $checkbox
}

# Create close button
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Cerrar"
$closeButton.Location = New-Object System.Drawing.Point(20, (30 + $checkboxNames.Length * 25))
$closeButton.Add_Click({
    $allChecked = $true
    foreach ($cb in $checkBoxes) {
        if (-not $cb.Checked) {
            $allChecked = $false
            break
        }
    }
    
    if (-not $allChecked) {
        [System.Windows.Forms.MessageBox]::Show("Debe marcar todas las casillas antes de cerrar.", "Atención", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
    else {
        $form.Close()
    }
})
$form.Controls.Add($closeButton)

# Create label for Brandon Sepulveda
$brandoLabel = New-Object System.Windows.Forms.Label
$brandoLabel.Text = "Desarrollado por Brandon Sepulveda"
$brandoLabel.AutoSize = $true
$brandoLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Italic)
$brandoLabel.ForeColor = [System.Drawing.Color]::Gray
$brandoLabel.Location = New-Object System.Drawing.Point(20, (60 + $checkboxNames.Length * 25))
$form.Controls.Add($brandoLabel)

# Show the form
$form.ShowDialog() | Out-Null