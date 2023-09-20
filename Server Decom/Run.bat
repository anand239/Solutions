@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\ServerDcom.ps1 -ConfigFile .\config.json"
pause