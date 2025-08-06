$pwshPath = "$($env:ProgramFiles)\PowerShell\7\pwsh.exe"

if (Test-Path $pwshPath) {
    Start-Process $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command irm https://cutt.ly/ToolboxBS |iex" -Verb RunAs
} else {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command irm https://cutt.ly/ToolboxBS |iex" -Verb RunAs
}
