cls
$serverlist = Get-Content "Serverlist path"

$path = "Provide any path .txt"

foreach($server in $serverlist)
{
$BckRpt = omnirpt -report host -host $server

$BckRpt >> $path
Write-Output "===========================================================" >> $path
}

#Write-Host "Your Report is Ready" -BackgroundColor Green -ForegroundColor White

