@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\connection_test.ps1 -ConfigFile .\config.json"
pause