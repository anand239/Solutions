@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\OmniTemp-Cleanup.ps1 -Paths C:\temp"