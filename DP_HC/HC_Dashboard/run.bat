@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\HC_Dashboard.exe -ConfigFile .\config.json"
pause