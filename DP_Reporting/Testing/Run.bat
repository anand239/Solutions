@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Script2_ALL.ps1 -ConfigFile .\config.json"
pause