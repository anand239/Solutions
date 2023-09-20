@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Expand-VMwareCdrive.ps1 -ConfigFile .\config.json"