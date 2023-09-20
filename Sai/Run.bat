@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\HC-DP.ps1 -ConfigFile .\config.json"
