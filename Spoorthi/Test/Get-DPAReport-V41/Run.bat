@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-DPAReport-V5.ps1 -ConfigFile .\config.json"
pause