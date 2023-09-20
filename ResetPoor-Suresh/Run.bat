@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Reset-PoorMedia_V2 -ConfigFile .\config.json"
