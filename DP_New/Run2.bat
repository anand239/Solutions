@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Check-Vulnerability_V3.ps1 -ConfigFile .\config.json"
