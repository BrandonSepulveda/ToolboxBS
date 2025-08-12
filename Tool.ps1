<#
.SYNOPSIS
    Downloads and runs the latest version of ToolboxBS from GitHub releases.

.DESCRIPTION
    This script automatically downloads the latest ToolboxBS.exe from GitHub releases,
    runs it, and cleans up temporary files afterward. Includes error handling,
    validation, and security checks.

.PARAMETER Force
    Force re-download even if file already exists

.EXAMPLE
    .\Tool.ps1
    Downloads and runs the latest ToolboxBS version

.EXAMPLE
    .\Tool.ps1 -Force
    Forces re-download and runs the latest ToolboxBS version

.NOTES
    Author: Brandon Sepulveda
    Version: 2.0
    Requires: PowerShell 5.1+, Internet connection
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$apiUrl = "https://api.github.com/repos/BrandonSepulveda/ToolboxBS/releases/latest"
$tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ToolboxBS.exe")
$maxRetries = 3
$retryDelay = 2

# Function to write colored output with timestamp
function Write-TimestampedHost {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $ForegroundColor
}

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        $response = Invoke-WebRequest -Uri "https://api.github.com" -UseBasicParsing -TimeoutSec 10
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

# Function to validate file integrity (basic check)
function Test-FileIntegrity {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $false
    }
    
    try {
        $fileInfo = Get-Item $FilePath
        # Basic checks: file exists, has reasonable size, and is executable
        return ($fileInfo.Length -gt 1MB -and $fileInfo.Length -lt 100MB -and $fileInfo.Extension -eq ".exe")
    }
    catch {
        return $false
    }
}

# Function to download with retry logic
function Invoke-DownloadWithRetry {
    param(
        [string]$Uri,
        [string]$OutFile,
        [int]$MaxRetries = 3
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-TimestampedHost "Download attempt $i of $MaxRetries..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 300
            
            if (Test-FileIntegrity $OutFile) {
                Write-TimestampedHost "Download completed successfully." -ForegroundColor Green
                return $true
            }
            else {
                throw "Downloaded file failed integrity check"
            }
        }
        catch {
            Write-TimestampedHost "Download attempt $i failed: $($_.Exception.Message)" -ForegroundColor Red
            
            if ($i -lt $MaxRetries) {
                Write-TimestampedHost "Retrying in $retryDelay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $retryDelay
                
                # Remove corrupted file if it exists
                if (Test-Path $OutFile) {
                    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    return $false
}

# Main execution
try {
    Write-TimestampedHost "ToolboxBS Launcher v2.0" -ForegroundColor Cyan
    Write-TimestampedHost "========================================" -ForegroundColor Cyan
    
    # Check internet connectivity
    Write-TimestampedHost "Checking internet connectivity..." -ForegroundColor Yellow
    if (-not (Test-InternetConnection)) {
        throw "No internet connection available. Please check your network settings."
    }
    Write-TimestampedHost "Internet connection confirmed." -ForegroundColor Green
    
    # Check if we should remove existing file
    if (Test-Path $tempFile) {
        if ($Force) {
            Write-TimestampedHost "Force parameter specified. Removing existing file..." -ForegroundColor Yellow
            Remove-Item -Path $tempFile -Force
        }
        elseif (Test-FileIntegrity $tempFile) {
            Write-TimestampedHost "Valid ToolboxBS.exe found. Starting existing version..." -ForegroundColor Green
            $process = Start-Process -FilePath $tempFile -PassThru -Wait
            
            if ($process.ExitCode -eq 0) {
                Write-TimestampedHost "ToolboxBS completed successfully." -ForegroundColor Green
                exit 0
            }
            else {
                Write-TimestampedHost "ToolboxBS exited with code $($process.ExitCode). Downloading fresh copy..." -ForegroundColor Yellow
                Remove-Item -Path $tempFile -Force
            }
        }
        else {
            Write-TimestampedHost "Existing file failed integrity check. Removing..." -ForegroundColor Yellow
            Remove-Item -Path $tempFile -Force
        }
    }
    
    # Get latest release info
    Write-TimestampedHost "Fetching latest release information..." -ForegroundColor Yellow
    $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{
        "Accept"     = "application/vnd.github.v3+json"
        "User-Agent" = "ToolboxBS-Launcher/2.0 PowerShell/$($PSVersionTable.PSVersion)"
    } -TimeoutSec 30
    
    # Validate release info
    if (-not $releaseInfo -or -not $releaseInfo.assets) {
        throw "Invalid release information received from GitHub API"
    }
    
    # Get download URL for the exe
    $asset = $releaseInfo.assets | Where-Object { $_.name -eq "ToolboxBS.exe" } | Select-Object -First 1
    
    if (-not $asset -or -not $asset.browser_download_url) {
        throw "Could not find ToolboxBS.exe in the latest release ($($releaseInfo.tag_name))"
    }
    
    $downloadUrl = $asset.browser_download_url
    $fileSize = [math]::Round($asset.size / 1MB, 2)
    
    Write-TimestampedHost "Found ToolboxBS $($releaseInfo.tag_name) (Size: $fileSize MB)" -ForegroundColor Green
    Write-TimestampedHost "Download URL: $downloadUrl" -ForegroundColor Gray
    
    # Download the file with retry logic
    Write-TimestampedHost "Downloading ToolboxBS..." -ForegroundColor Yellow
    if (-not (Invoke-DownloadWithRetry -Uri $downloadUrl -OutFile $tempFile -MaxRetries $maxRetries)) {
        throw "Failed to download ToolboxBS after $maxRetries attempts"
    }
    
    # Final integrity check
    if (-not (Test-FileIntegrity $tempFile)) {
        throw "Downloaded file failed final integrity verification"
    }
    
    # Run the executable
    Write-TimestampedHost "Starting ToolboxBS..." -ForegroundColor Green
    $process = Start-Process -FilePath $tempFile -PassThru -Wait
    
    if ($process.ExitCode -eq 0) {
        Write-TimestampedHost "ToolboxBS completed successfully." -ForegroundColor Green
    }
    else {
        Write-TimestampedHost "ToolboxBS exited with code $($process.ExitCode)." -ForegroundColor Yellow
    }
    
    # Clean up after execution
    Write-TimestampedHost "Cleaning up temporary files..." -ForegroundColor Yellow
    if (Test-Path $tempFile) {
        Remove-Item -Path $tempFile -Force
        Write-TimestampedHost "Temporary file removed successfully." -ForegroundColor Green
    }
    
    Write-TimestampedHost "Operation completed." -ForegroundColor Green
}
catch {
    Write-TimestampedHost "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-TimestampedHost "Failed to download or run ToolboxBS." -ForegroundColor Red
    
    # Clean up any partial downloads
    if (Test-Path $tempFile) {
        try {
            Remove-Item -Path $tempFile -Force
            Write-TimestampedHost "Cleaned up partial download." -ForegroundColor Yellow
        }
        catch {
            Write-TimestampedHost "Warning: Could not clean up partial download at $tempFile" -ForegroundColor Yellow
        }
    }
    
    Write-TimestampedHost "Please check your internet connection and try again." -ForegroundColor Yellow
    exit 1
}
