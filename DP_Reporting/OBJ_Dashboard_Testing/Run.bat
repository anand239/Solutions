@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\RPT_OBJ_Dashboard.ps1 -ConfigFile .\config.json"
