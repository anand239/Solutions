@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Create-Credential.ps1 -ConfigFile .\config.json"
pause