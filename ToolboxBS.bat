@echo off
:: Check for administrative privileges
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run the PowerShell command with administrative privileges
powershell -Command "irm  https://github.com/BrandonSepulveda/ToolboxBS/releases/download/V1.2/ToolboxBS.ps1| iex"
pause
