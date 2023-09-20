@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\RPT_Dashboard.ps1 -ConfigFile .\config.json"