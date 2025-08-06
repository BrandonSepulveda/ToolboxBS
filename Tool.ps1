# Downloads the latest version of ToolboxBS, runs it, and cleans up afterward
# Enhanced with improved security and error handling
$apiUrl = "https://api.github.com/repos/BrandonSepulveda/ToolboxBS/releases/latest"
$tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ToolboxBS.exe")

# Security check: Ensure we're running with appropriate permissions
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Warning: Running without administrator privileges. Some features may not work correctly." -ForegroundColor Yellow
}

try {
    # Remove old file if it exists (may sometimes cause issues)
    if (Test-Path $tempFile) {
        try {
            Remove-Item -Path $tempFile -Force
            Write-Host "Old temporary file removed." -ForegroundColor Green
        }
        catch {
            Write-Host "Warning: Could not remove old temporary file: $_" -ForegroundColor Yellow
        }
    }
    
    # Get latest release info with improved error handling
    Write-Host "Fetching latest release information..." -ForegroundColor Cyan
    $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{
        "Accept"     = "application/vnd.github.v3+json"
        "User-Agent" = "ToolboxBS-PowerShell/1.0"
    } -TimeoutSec 30
    
    # Get download URL for the exe
    $downloadUrl = ($releaseInfo.assets | Where-Object { $_.name -eq "ToolboxBS.exe" }).browser_download_url
    
    if (-not $downloadUrl) {
        throw "Could not find ToolboxBS.exe in the latest release. Please check the releases page manually."
    }

    # Verify the download URL is from the expected domain
    $uri = [System.Uri]$downloadUrl
    if ($uri.Host -ne "github.com" -and $uri.Host -ne "objects.githubusercontent.com") {
        throw "Download URL is not from expected GitHub domain: $($uri.Host)"
    }

    Write-Host "Found release: $($releaseInfo.tag_name) - $($releaseInfo.name)" -ForegroundColor Green
    
    if (Test-Path $tempFile) {
        Write-Host "ToolboxBS already downloaded, starting..." -ForegroundColor Green
        # Verify file size is reasonable (not empty, not too large)
        $fileInfo = Get-Item $tempFile
        if ($fileInfo.Length -lt 1KB) {
            throw "Downloaded file appears to be invalid (too small)"
        }
        if ($fileInfo.Length -gt 500MB) {
            throw "Downloaded file appears to be invalid (too large)"
        }
        Start-Process -FilePath $tempFile -Wait
    }
    else {
        # Download the file with progress indication
        Write-Host "Downloading ToolboxBS v$($releaseInfo.tag_name) from GitHub..." -ForegroundColor Green
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "ToolboxBS-PowerShell/1.0")
        
        try {
            $webClient.DownloadFile($downloadUrl, $tempFile)
        }
        finally {
            $webClient.Dispose()
        }
        
        # Verify download was successful
        if (-not (Test-Path $tempFile)) {
            throw "Download failed: File was not created"
        }
        
        $fileInfo = Get-Item $tempFile
        if ($fileInfo.Length -lt 1KB) {
            throw "Download failed: File is too small"
        }
        
        Write-Host "Download completed successfully ($([math]::Round($fileInfo.Length / 1MB, 2)) MB)" -ForegroundColor Green
    
        # Run the executable
        Write-Host "Starting ToolboxBS..." -ForegroundColor Green
        Start-Process -FilePath $tempFile -Wait
    }
    
    # Clean up after execution
    if (Test-Path $tempFile) {
        try {
            Remove-Item -Path $tempFile -Force
            Write-Host "Temporary file removed, done!" -ForegroundColor Green
        }
        catch {
            Write-Host "Warning: Could not remove temporary file: $_" -ForegroundColor Yellow
            Write-Host "Please manually delete: $tempFile" -ForegroundColor Yellow
        }
    }
    
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Failed to download or run ToolboxBS." -ForegroundColor Red
    Write-Host "Please try again or visit https://github.com/BrandonSepulveda/ToolboxBS/releases manually." -ForegroundColor Yellow
    
    # Clean up on error
    if (Test-Path $tempFile) {
        try {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Silent cleanup failure
        }
    }
    
    exit 1
}
