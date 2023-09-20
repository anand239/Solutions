@ECHO ON
CD /d "%~dp0"
Powershell.exe -ExecutionPolicy Bypass ".\DD-HC.exe -ConfigFile .\config.json"