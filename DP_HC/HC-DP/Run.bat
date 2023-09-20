@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\HC-DP.exe -ConfigFile .\config.json"