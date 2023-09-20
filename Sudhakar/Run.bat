@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-DPHungBackupReport.ps1 -ConfigFile .\config.json"