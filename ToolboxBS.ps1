<#
.SYNOPSIS
    ToolboxBS Launcher - Executes ToolboxBS with appropriate PowerShell version and admin privileges.

.DESCRIPTION
    This script detects the best available PowerShell version (PowerShell 7 or Windows PowerShell 5.1)
    and launches ToolboxBS with proper administrative privileges and security settings.

.NOTES
    Author: Brandon Sepulveda
    Version: 2.0
    Requires: Windows PowerShell 5.1+ or PowerShell 7+, Admin privileges
#>

[CmdletBinding()]
param()

# Configuration
$ErrorActionPreference = "Stop"
$toolboxUrl = "https://cutt.ly/ToolboxBS"
$fallbackUrl = "https://brandonsepulveda.github.io/Tool"

# Function to write colored output
function Write-ColoredHost {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to test if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to test URL connectivity
function Test-UrlConnectivity {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10 -Method Head
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

try {
    Write-ColoredHost "ToolboxBS Launcher v2.0" -ForegroundColor Cyan
    Write-ColoredHost "========================" -ForegroundColor Cyan
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-ColoredHost "Administrator privileges required. Requesting elevation..." -ForegroundColor Yellow
        
        # Self-elevate the script
        $scriptPath = $MyInvocation.MyCommand.Path
        if ($scriptPath) {
            Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
            exit 0
        }
    }
    
    Write-ColoredHost "Running with administrator privileges." -ForegroundColor Green
    
    # Determine the best PowerShell version to use
    $pwsh7Path = "$($env:ProgramFiles)\PowerShell\7\pwsh.exe"
    $pwsh7PathX86 = "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe"
    
    $powershellPath = $null
    $powershellVersion = $null
    
    # Check for PowerShell 7 (preferred)
    if (Test-Path $pwsh7Path) {
        $powershellPath = $pwsh7Path
        $powershellVersion = "PowerShell 7"
    }
    elseif (Test-Path $pwsh7PathX86) {
        $powershellPath = $pwsh7PathX86
        $powershellVersion = "PowerShell 7 (x86)"
    }
    else {
        # Fallback to Windows PowerShell 5.1
        $powershellPath = "powershell"
        $powershellVersion = "Windows PowerShell 5.1"
    }
    
    Write-ColoredHost "Using: $powershellVersion" -ForegroundColor Green
    
    # Test connectivity to primary URL
    Write-ColoredHost "Testing connectivity to ToolboxBS..." -ForegroundColor Yellow
    $targetUrl = $toolboxUrl
    
    if (-not (Test-UrlConnectivity $toolboxUrl)) {
        Write-ColoredHost "Primary URL not accessible, trying fallback..." -ForegroundColor Yellow
        if (Test-UrlConnectivity $fallbackUrl) {
            $targetUrl = $fallbackUrl
            Write-ColoredHost "Using fallback URL." -ForegroundColor Green
        }
        else {
            throw "Unable to connect to ToolboxBS. Please check your internet connection."
        }
    }
    else {
        Write-ColoredHost "Connection successful." -ForegroundColor Green
    }
    
    # Prepare the command to execute
    $command = "irm '$targetUrl' | iex"
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", $command
    )
    
    Write-ColoredHost "Launching ToolboxBS..." -ForegroundColor Yellow
    Write-ColoredHost "Command: $powershellVersion -NoProfile -ExecutionPolicy Bypass -Command irm '$targetUrl' | iex" -ForegroundColor Gray
    
    # Start the process
    $processInfo = @{
        FilePath = $powershellPath
        ArgumentList = $arguments
        Wait = $true
        NoNewWindow = $true
    }
    
    if ($powershellVersion -eq "Windows PowerShell 5.1") {
        # For Windows PowerShell, we need to use Start-Process with -Verb RunAs if not already elevated
        Start-Process -FilePath $powershellPath -ArgumentList $arguments -Wait
    }
    else {
        # For PowerShell 7, we can use Start-Process directly
        Start-Process @processInfo
    }
    
    Write-ColoredHost "ToolboxBS execution completed." -ForegroundColor Green
}
catch {
    Write-ColoredHost "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-ColoredHost "Please try the following:" -ForegroundColor Yellow
    Write-ColoredHost "1. Ensure you have internet connectivity" -ForegroundColor Yellow
    Write-ColoredHost "2. Run this script as Administrator" -ForegroundColor Yellow
    Write-ColoredHost "3. Check Windows Firewall settings" -ForegroundColor Yellow
    Write-ColoredHost "4. Temporarily disable antivirus software" -ForegroundColor Yellow
    
    Write-ColoredHost "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
