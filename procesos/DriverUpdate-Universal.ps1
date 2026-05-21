#Requires -Version 5.1
#Requires -RunAsAdministrator

# ============================================================
#  ToolboxBS - Driver Update Universal
#  Dell / HP / Lenovo  — instala herramienta si no existe
# ============================================================

$mfg   = (Get-CimInstance Win32_ComputerSystem).Manufacturer
$model = (Get-CimInstance Win32_ComputerSystem).Model
$sku   = (Get-CimInstance Win32_ComputerSystem).SystemSKUNumber

Write-Host ""
Write-Host "  ToolboxBS - Driver Update Universal" -ForegroundColor Cyan
Write-Host "  ==========================================" -ForegroundColor DarkGray
Write-Host "  Fabricante : $mfg" -ForegroundColor White
Write-Host "  Modelo     : $model" -ForegroundColor White
Write-Host ""

# ════════════════════════════════════════════════════════════
#  DELL
# ════════════════════════════════════════════════════════════
if ($mfg -match "Dell") {

    $TempRoot     = "$env:windir\Temp\ToolboxBS\Dell"
    $CabIndexPath = "$TempRoot\CatalogIndexPC.cab"
    $CabModelPath = "$TempRoot\CatalogIndexModel.cab"
    $ExtractPath  = "$TempRoot\Extract"
    $CLI64        = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
    $CLI32        = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"

    if (-not (Test-Path $TempRoot))    { New-Item $TempRoot    -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $ExtractPath)) { New-Item $ExtractPath -ItemType Directory -Force | Out-Null }

    $dcuReg = Get-ItemProperty "HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings" -ErrorAction SilentlyContinue
    $installedVersion = if ($dcuReg -and $dcuReg.ProductVersion) { [Version]$dcuReg.ProductVersion } else { [Version]"0.0.0.0" }
    Write-Host "[DELL] Version instalada: $(if ($installedVersion -eq '0.0.0.0') {'No instalado'} else {$installedVersion})" -ForegroundColor Yellow

    Write-Host "[DELL] Descargando catalogo maestro Dell..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/CatalogIndexPC.cab" -OutFile $CabIndexPath -UseBasicParsing -ErrorAction Stop
    } catch { Write-Host "[DELL] ERROR: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Enter para salir"; exit 1 }

    $xmlMasterPath = "$ExtractPath\DellSDPCatalogPC.xml"
    $null = expand $CabIndexPath $xmlMasterPath 2>$null
    if (-not (Test-Path $xmlMasterPath)) { Write-Host "[DELL] ERROR extrayendo catalogo." -ForegroundColor Red; Read-Host "Enter"; exit 1 }

    Write-Host "[DELL] Buscando catalogo para SKU: $sku..." -ForegroundColor Yellow
    [xml]$xmlMaster = Get-Content $xmlMasterPath
    $modelEntry = $xmlMaster.ManifestIndex.GroupManifest | Where-Object {
        $_.SupportedSystems.Brand.Model.systemID -match $sku
    } | Select-Object -First 1

    $modelCatalogURL = "http://downloads.dell.com/$($modelEntry.ManifestInformation.path)"
    try {
        Invoke-WebRequest -Uri $modelCatalogURL -OutFile $CabModelPath -UseBasicParsing -ErrorAction Stop
    } catch { Write-Host "[DELL] ERROR: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Enter"; exit 1 }

    $xmlModelPath = "$ExtractPath\CatalogModel.xml"
    $null = expand $CabModelPath $xmlModelPath 2>$null

    [xml]$xmlModel = Get-Content $xmlModelPath
    $apps = $xmlModel.Manifest.SoftwareComponent | Where-Object { $_.ComponentType.value -eq "APAC" }
    $dcuLatestVersion = ($apps | Where-Object {
        $_.path -match "command-update" -and $_.SupportedOperatingSystems.OperatingSystem.osArch -match "x64"
    }).vendorVersion | Sort-Object | Select-Object -Last 1

    $dcuApp = $apps | Where-Object {
        $_.path -match "command-update" -and
        $_.SupportedOperatingSystems.OperatingSystem.osArch -match "x64" -and
        $_.vendorVersion -eq $dcuLatestVersion
    } | Select-Object -First 1

    if (-not $dcuApp) { Write-Host "[DELL] ERROR: DCU no encontrado en catalogo." -ForegroundColor Red; Read-Host "Enter"; exit 1 }

    $catalogVersion = [Version]$dcuApp.vendorVersion
    Write-Host "[DELL] Version en catalogo: $catalogVersion" -ForegroundColor Yellow

    if ($catalogVersion -gt $installedVersion) {
        Write-Host "[DELL] Instalando DCU $catalogVersion..." -ForegroundColor Yellow
        $sha256  = ($dcuApp.Cryptography.Hash | Where-Object { $_.algorithm -eq "SHA256" }).'#text'
        $dcuURL  = "http://downloads.dell.com/$($dcuApp.path)"
        $dcuFile = "$ExtractPath\$(($dcuApp.path).Split('/') | Select-Object -Last 1)"
        try {
            Invoke-WebRequest -Uri $dcuURL -OutFile $dcuFile -UseBasicParsing -ErrorAction Stop
        } catch { Write-Host "[DELL] ERROR descargando DCU: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Enter"; exit 1 }

        $localHash = (Get-FileHash -Path $dcuFile -Algorithm SHA256).Hash
        if ($localHash -ne $sha256) { Write-Host "[DELL] ERROR: Hash SHA256 no coincide." -ForegroundColor Red; Read-Host "Enter"; exit 1 }
        Write-Host "[DELL] Hash validado OK." -ForegroundColor Green

        $instLog  = $dcuFile.Replace(".exe", ".log")
        $instProc = Start-Process -FilePath $dcuFile -ArgumentList "/s /l=$instLog" -Wait -PassThru
        if ($instProc.ExitCode -notin @(0, 2)) { Write-Host "[DELL] ERROR instalando DCU. ExitCode: $($instProc.ExitCode)" -ForegroundColor Red; Read-Host "Enter"; exit 1 }
        Write-Host "[DELL] DCU instalado." -ForegroundColor Green
    } else {
        Write-Host "[DELL] DCU ya actualizado ($installedVersion)." -ForegroundColor Green
    }

    $cli = $null
    if (Test-Path $CLI64) { $cli = $CLI64 } elseif (Test-Path $CLI32) { $cli = $CLI32 }
    if (-not $cli) { Write-Host "[DELL] ERROR: dcu-cli.exe no encontrado." -ForegroundColor Red; Read-Host "Enter"; exit 1 }

    Write-Host "[DELL] Ejecutando actualizacion de drivers..." -ForegroundColor Yellow
    $p = Start-Process -FilePath $cli -ArgumentList "/applyUpdates -autoSuspendBitLocker=enable -reboot=disable" -NoNewWindow -Wait -PassThru
    Write-Host "[DELL] ExitCode: $($p.ExitCode)" -ForegroundColor DarkGray
    switch ($p.ExitCode) {
        0       { Write-Host "[DELL] EXITO: Actualizaciones aplicadas." -ForegroundColor Green }
        1       { Write-Host "[DELL] EXITO: Reinicio requerido." -ForegroundColor Yellow }
        500     { Write-Host "[DELL] INFO: Sin actualizaciones pendientes." -ForegroundColor Cyan }
        default { Write-Host "[DELL] AVISO: ExitCode $($p.ExitCode)." -ForegroundColor Yellow }
    }
    Write-Host "[DELL] Logs: C:\ProgramData\dell\UpdateService\Log" -ForegroundColor DarkGray
}

# ════════════════════════════════════════════════════════════
#  HP — descarga version especifica desde hpcloud
# ════════════════════════════════════════════════════════════
elseif ($mfg -match "HP|Hewlett") {

    $TempRoot   = "$env:windir\Temp\ToolboxBS\HP"
    $HPIAFolder = "$TempRoot\HPIA"
    if (-not (Test-Path $TempRoot))   { New-Item $TempRoot   -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $HPIAFolder)) { New-Item $HPIAFolder -ItemType Directory -Force | Out-Null }

    # ── Buscar HPIA ya extraido ──────────────────────────────
    $hpia = $null
    $f = Get-ChildItem $HPIAFolder -Filter "HPImageAssistant.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { $hpia = $f.FullName }

    # ── Si no existe, obtener version actual y descargar ─────
    if (-not $hpia) {
        Write-Host "[HP] HPIA no encontrado. Obteniendo version mas reciente..." -ForegroundColor Yellow

        # Obtener la version mas reciente desde la pagina oficial de HP
        try {
            $hpiaPage = Invoke-WebRequest -Uri "https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html" -UseBasicParsing -ErrorAction Stop
            # Buscar el primer link que tenga hp-hpia-*.exe
            $match = [regex]::Match($hpiaPage.Content, 'href="([^"]*hp-hpia-[\d.]+\.exe)"')
            if ($match.Success) {
                $hpiaURL = $match.Groups[1].Value
                # Si es relativo, completar URL
                if ($hpiaURL -notmatch "^http") {
                    $hpiaURL = "https://hpia.hpcloud.hp.com/downloads/hpia/" + ($hpiaURL -split '/')[-1]
                }
            } else {
                # Fallback a version conocida
                $hpiaURL = "https://hpia.hpcloud.hp.com/downloads/hpia/hp-hpia-5.3.5.exe"
            }
        } catch {
            Write-Host "[HP] No se pudo obtener version — usando 5.3.5 como fallback." -ForegroundColor Yellow
            $hpiaURL = "https://hpia.hpcloud.hp.com/downloads/hpia/hp-hpia-5.3.5.exe"
        }

        $hpiaExeName = ($hpiaURL -split '/')[-1]
        $hpiaInst    = "$TempRoot\$hpiaExeName"

        Write-Host "[HP] Descargando $hpiaExeName..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $hpiaURL -OutFile $hpiaInst -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host "[HP] ERROR descargando HPIA: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Enter para salir"; exit 1
        }

        # ── Extraer con /s /e /f <destino> ──────────────────
        Write-Host "[HP] Extrayendo HPIA en $HPIAFolder..." -ForegroundColor Yellow
        Start-Process -FilePath $hpiaInst -ArgumentList "/s /e /f `"$HPIAFolder`"" -Wait
        Start-Sleep -Seconds 5

        # Buscar el exe extraido
        $f = Get-ChildItem $HPIAFolder -Recurse -Filter "HPImageAssistant.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) {
            $hpia = $f.FullName
            Write-Host "[HP] HPIA listo: $hpia" -ForegroundColor Green
        } else {
            # Algunos SoftPaq extraen a C:\SWSetup\SPxxxxx — buscar ahi
            $f2 = Get-ChildItem "C:\SWSetup" -Recurse -Filter "HPImageAssistant.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($f2) {
                $hpia = $f2.FullName
                Write-Host "[HP] HPIA encontrado en SWSetup: $hpia" -ForegroundColor Green
            } else {
                Write-Host "[HP] ERROR: No se pudo extraer HPImageAssistant.exe." -ForegroundColor Red
                Write-Host "[HP] Descarga manual: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html" -ForegroundColor Gray
                Read-Host "Enter para salir"; exit 1
            }
        }
    } else {
        Write-Host "[HP] HPIA encontrado: $hpia" -ForegroundColor Green
    }

    # ── Ejecutar HPIA ────────────────────────────────────────
    Write-Host "[HP] Ejecutando actualizacion (puede tardar varios minutos)..." -ForegroundColor Yellow
    $logP     = "$env:ProgramData\HP\HP TouchPoint Analytics Client\Logs"
    $softpaqs = "$TempRoot\SoftPaqs"
    if (-not (Test-Path $logP))     { New-Item $logP     -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $softpaqs)) { New-Item $softpaqs -ItemType Directory -Force | Out-Null }

    $p = Start-Process -FilePath $hpia `
         -ArgumentList "/Silent /Operation:Analyze /Action:Install /Category:All /Selection:All /InstallType:AutoInstallable /Debug /LogFolder:`"$logP`" /SoftpaqDownloadFolder:`"$softpaqs`"" `
         -NoNewWindow -Wait -PassThru

    Write-Host "[HP] ExitCode: $($p.ExitCode)" -ForegroundColor DarkGray
    switch ($p.ExitCode) {
        0    { Write-Host "[HP] EXITO: Actualizaciones instaladas." -ForegroundColor Green }
        3010 { Write-Host "[HP] EXITO: Instalado. Reinicio requerido." -ForegroundColor Yellow }
        256  { Write-Host "[HP] INFO: Sin recomendaciones." -ForegroundColor Cyan }
        257  { Write-Host "[HP] INFO: Sin recomendaciones seleccionadas." -ForegroundColor Cyan }
        default { Write-Host "[HP] AVISO: ExitCode $($p.ExitCode)." -ForegroundColor Yellow }
    }
    Write-Host "[HP] Logs: $logP" -ForegroundColor DarkGray
}

# ════════════════════════════════════════════════════════════
#  LENOVO
# ════════════════════════════════════════════════════════════
elseif ($mfg -match "Lenovo") {

    $TempRoot = "$env:windir\Temp\ToolboxBS\Lenovo"
    if (-not (Test-Path $TempRoot)) { New-Item $TempRoot -ItemType Directory -Force | Out-Null }

    $tvsu = $null
    if (Test-Path "C:\Program Files (x86)\Lenovo\System Update\tvsukernel.exe") { $tvsu = "C:\Program Files (x86)\Lenovo\System Update\tvsukernel.exe" }
    elseif (Test-Path "C:\Program Files\Lenovo\System Update\tvsukernel.exe")   { $tvsu = "C:\Program Files\Lenovo\System Update\tvsukernel.exe" }

    if (-not $tvsu) {
        Write-Host "[LENOVO] System Update no encontrado. Descargando..." -ForegroundColor Yellow
        $inst = "$TempRoot\LenovoSystemUpdate.exe"
        try {
            $tvsuURL = "https://download.lenovo.com/pccbbs/thinkvantage_en/system_update_5.08.03.59.exe"
            Write-Host "[LENOVO] Descargando desde: $tvsuURL" -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $tvsuURL -OutFile $inst -UseBasicParsing -ErrorAction Stop
            Start-Process $inst -ArgumentList "/VERYSILENT /NORESTART" -Wait
            Start-Sleep 5
            if (Test-Path "C:\Program Files (x86)\Lenovo\System Update\tvsukernel.exe") { $tvsu = "C:\Program Files (x86)\Lenovo\System Update\tvsukernel.exe" }
            elseif (Test-Path "C:\Program Files\Lenovo\System Update\tvsukernel.exe")   { $tvsu = "C:\Program Files\Lenovo\System Update\tvsukernel.exe" }
            if (-not $tvsu) { Write-Host "[LENOVO] ERROR: Instalacion fallida." -ForegroundColor Red; Read-Host "Enter"; exit 1 }
            Write-Host "[LENOVO] System Update instalado." -ForegroundColor Green
        } catch { Write-Host "[LENOVO] ERROR: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Enter"; exit 1 }
    } else {
        Write-Host "[LENOVO] System Update encontrado: $tvsu" -ForegroundColor Green
    }

    Write-Host "[LENOVO] Ejecutando actualizacion (puede tardar varios minutos)..." -ForegroundColor Yellow
    $p = Start-Process -FilePath $tvsu -ArgumentList "-search A -action INSTALL -includerebootpackages 1,2 -reboot NO -noreboot" -NoNewWindow -Wait -PassThru
    Write-Host "[LENOVO] ExitCode: $($p.ExitCode)" -ForegroundColor DarkGray
    switch ($p.ExitCode) {
        0 { Write-Host "[LENOVO] EXITO: Sin pendientes o todo aplicado." -ForegroundColor Green }
        1 { Write-Host "[LENOVO] EXITO: Reinicio requerido." -ForegroundColor Yellow }
        2 { Write-Host "[LENOVO] FALLO: Algunas actualizaciones fallaron." -ForegroundColor Red }
        default { Write-Host "[LENOVO] AVISO: ExitCode $($p.ExitCode)." -ForegroundColor Yellow }
    }
    Write-Host "[LENOVO] Logs: C:\ProgramData\Lenovo\SystemUpdate\Logs" -ForegroundColor DarkGray
}

# ════════════════════════════════════════════════════════════
#  NO SOPORTADO
# ════════════════════════════════════════════════════════════
else {
    Write-Host "[ERROR] Fabricante no soportado: $mfg" -ForegroundColor Red
    Write-Host "[INFO]  Soportados: Dell, HP, Lenovo" -ForegroundColor Gray
    Read-Host "Enter para salir"; exit 1
}

Write-Host ""
Write-Host "  Proceso completado." -ForegroundColor Cyan
Write-Host ""
Read-Host "Presiona Enter para cerrar"
