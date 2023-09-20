@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-EnvironmentData.ps1 -ConfigFile .\config.json"
