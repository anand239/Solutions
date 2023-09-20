@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\Get-MountPoint_V1.ps1 -ConfigFile .\config.json"
pause