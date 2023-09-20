@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Reset-PoorMedia.ps1 -ConfigFile .\config.json"
