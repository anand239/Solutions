$server = Read-Host "Enter your Servername"
$BckRpt = omnirpt -report host -host $server
$BckRpt > "c:\output.txt"