# ToolboxBS Local Validation Script
# Run this script to validate the project locally before committing

param(
    [switch]$SkipPSScriptAnalyzer,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 ToolboxBS Local Validation Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    
    $color = switch ($Status) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    $icon = switch ($Status) {
        "SUCCESS" { "✓" }
        "WARNING" { "⚠️" }
        "ERROR" { "✗" }
        default { "ℹ️" }
    }
    
    Write-Host "$icon $Message" -ForegroundColor $color
}

# Check if PSScriptAnalyzer is available
if (-not $SkipPSScriptAnalyzer) {
    try {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        $hasPSScriptAnalyzer = $true
    }
    catch {
        Write-Status "PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer" "WARNING"
        $hasPSScriptAnalyzer = $false
    }
}

Write-Host "`n1. Validating PowerShell Scripts..." -ForegroundColor Yellow

# Get all PowerShell scripts
$scripts = Get-ChildItem -Path "." -Filter "*.ps1" -Recurse
$syntaxErrors = 0

foreach ($script in $scripts) {
    if ($Verbose) {
        Write-Host "   Checking: $($script.Name)" -ForegroundColor Gray
    }
    
    try {
        # Check syntax
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script.FullName -Raw), [ref]$null)
        if ($Verbose) {
            Write-Status "$($script.Name) - Syntax OK" "SUCCESS"
        }
    }
    catch {
        Write-Status "$($script.Name) - Syntax Error: $_" "ERROR"
        $syntaxErrors++
    }
}

if ($syntaxErrors -eq 0) {
    Write-Status "All PowerShell scripts have valid syntax ($($scripts.Count) files checked)" "SUCCESS"
} else {
    Write-Status "$syntaxErrors PowerShell syntax errors found" "ERROR"
}

# Run PSScriptAnalyzer if available
if ($hasPSScriptAnalyzer -and -not $SkipPSScriptAnalyzer) {
    Write-Host "`n2. Running PSScriptAnalyzer..." -ForegroundColor Yellow
    
    $analysisResults = Invoke-ScriptAnalyzer -Path "." -Recurse -Severity Warning,Error
    
    if ($analysisResults) {
        $errorCount = ($analysisResults | Where-Object { $_.Severity -eq 'Error' }).Count
        $warningCount = ($analysisResults | Where-Object { $_.Severity -eq 'Warning' }).Count
        
        Write-Host "`n   Issues found:" -ForegroundColor Yellow
        $analysisResults | Format-Table -AutoSize
        
        if ($errorCount -gt 0) {
            Write-Status "Critical issues found: $errorCount errors, $warningCount warnings" "ERROR"
        } else {
            Write-Status "Found $warningCount warnings (no critical errors)" "WARNING"
        }
    } else {
        Write-Status "No issues found by PSScriptAnalyzer" "SUCCESS"
    }
} else {
    Write-Status "Skipping PSScriptAnalyzer check" "WARNING"
}

# Check file encodings
Write-Host "`n3. Checking File Encodings..." -ForegroundColor Yellow

$bomFiles = @()
foreach ($script in $scripts) {
    $content = Get-Content $script.FullName -Encoding Byte -TotalCount 3
    if ($content.Count -ge 3 -and $content[0] -eq 0xEF -and $content[1] -eq 0xBB -and $content[2] -eq 0xBF) {
        $bomFiles += $script.RelativePath
    }
}

if ($bomFiles.Count -gt 0) {
    Write-Status "Files with BOM found: $($bomFiles -join ', ')" "WARNING"
    Write-Status "Consider removing BOM for better PowerShell compatibility" "WARNING"
} else {
    Write-Status "No BOM issues found" "SUCCESS"
}

# Check HTML files
Write-Host "`n4. Basic HTML Validation..." -ForegroundColor Yellow

$htmlFiles = Get-ChildItem -Path "." -Filter "*.html" -Recurse
foreach ($htmlFile in $htmlFiles) {
    $content = Get-Content $htmlFile.FullName -Raw
    
    # Basic HTML structure checks
    if ($content -match '<!DOCTYPE\s+html>') {
        if ($Verbose) {
            Write-Status "$($htmlFile.Name) - Has DOCTYPE declaration" "SUCCESS"
        }
    } else {
        Write-Status "$($htmlFile.Name) - Missing DOCTYPE declaration" "WARNING"
    }
    
    # Check for basic HTML structure
    if ($content -match '<html.*>.*</html>' -and $content -match '<head.*>.*</head>' -and $content -match '<body.*>.*</body>') {
        if ($Verbose) {
            Write-Status "$($htmlFile.Name) - Basic HTML structure OK" "SUCCESS"
        }
    } else {
        Write-Status "$($htmlFile.Name) - Incomplete HTML structure" "WARNING"
    }
}

Write-Status "HTML validation completed ($($htmlFiles.Count) files checked)" "SUCCESS"

# Security checks
Write-Host "`n5. Basic Security Checks..." -ForegroundColor Yellow

$sensitivePatterns = @("password", "secret", "key", "token", "credential")
$sensitiveFound = $false

foreach ($pattern in $sensitivePatterns) {
    $matches = Select-String -Path "*.ps1", "*.html", "*.js" -Pattern $pattern -AllMatches 2>$null
    if ($matches) {
        foreach ($match in $matches) {
            if ($match.Line -notmatch "^\s*#" -and $match.Line -notmatch "<!--.*-->") {
                Write-Status "Potential sensitive data in $($match.Filename):$($match.LineNumber) - '$($match.Line.Trim())'" "WARNING"
                $sensitiveFound = $true
            }
        }
    }
}

if (-not $sensitiveFound) {
    Write-Status "No obvious sensitive data patterns found" "SUCCESS"
}

# Summary
Write-Host "`n🎉 Validation Summary" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan

if ($syntaxErrors -eq 0) {
    Write-Status "PowerShell syntax validation: PASSED" "SUCCESS"
} else {
    Write-Status "PowerShell syntax validation: FAILED" "ERROR"
}

Write-Status "Local validation completed" "SUCCESS"
Write-Host "`nRecommendation: Run this script before committing changes" -ForegroundColor Yellow

if ($syntaxErrors -gt 0) {
    exit 1
}