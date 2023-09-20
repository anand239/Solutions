cls
$Report = @()
$Server6 = Import-Csv 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile.csv'
$Totl_server6_count = $Server6.Count
$Failed_server6_count = @($Server6 | Where-Object{$_.status -eq "failed"}| sort client -Unique).Count 
$Success_server6_count = @($Server6 | Where-Object{$_.status -eq "Successfull"}).Count
$DSR_Percentage = [math]::Round(($Success_server6_count/$Totl_server6_count)*100,0)

$Report += [pscustomobject] @{
"Host Name" = "actdxcnbmprdv01"
"Source MgmtIP" = "10.147.3.100"
"Total Jobs" = $Totl_server6_count
"Successfull Jobs" = $Success_server6_count
"Failed Jobs" = $Failed_server6_count
"DSR" = "$DSR_Percentage%"
}

$css = @"
<style>
h1, h5, th { text-align: center; font-family: Segoe UI; }
table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: black; color: #fff; max-width: 200px; padding: 5px 10px; }
td { font-size: 11px;text-align: center; padding: 5px 20px; color: #000; }
tr:nth-child(even) {background: #dae5f4;}
tr:nth-child(odd) {background: #b8d1f3;}
th:nth-child(1) { background: black; }
th:nth-child(2) { background: black; }
th:nth-child(3) { background: C2fff5; }
th:nth-child(4) { background: c3fff5; }
th:nth-child(5) { background: red; }
th:nth-child(6) { background: red; }
</style>
"@
#tr { background: yellow; }

#$Report| Export-Csv 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\Result.csv' -NoTypeInformation
#$body = Import-Csv 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\Result.csv' | ConvertTo-Html -Head $css | Out-File 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile.html'
$body = $Report | ConvertTo-Html -Head $css | Out-File 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile1.html'


$from= "a.chintalapudi@dxc.com"
$to= "a.chintalapudi@dxc.com"
$subject= "DP Service HC"
$SMTPserver="smtp.svcs.hpe.com"
$body = "hi"
$body += Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile1.html'
$attach = 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile1.html'
Send-MailMessage -From $from -to $to -Subject $subject -Body $body -BodyAsHtml  -SmtpServer $SMTPserver -Attachments $attach
