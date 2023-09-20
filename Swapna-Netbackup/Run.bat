@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-NetBackupError-V2.ps1 -ConfigFile .\config.json"
pause