cls
$Report = @()
$Server6 = Import-Csv 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile.csv'
$Totl_server6_count = $Server6.Count
$Failed_server6_count = @($Server6 | Where-Object{$_.status -eq "failed"}).Count  #| sort client -Unique)
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


$Header = @"
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 6px;border-style: solid;border-color: Black;background-color: #47EA6A;foreground-color : #FF0000;}
TD {border-width: 1px;padding: 6px;border-style: solid;border-color: black;}
</style>
<title>
NetApp Controller Disk Status
</title>
"@


$css = @"
<style>
h1, h5, th { text-align: center; font-family: Segoe UI; }
table { margin: auto; text-align: center; font-size: 11px; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { font-size: 11px; padding: 5px 20px; color: #000; }
th { background: #FF0000; }
td { background: #FFFFFF; color: #fff; max-width: 400px; padding: 5px 10px; }
</style>
"@

#th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; }
#tr:nth-child(even) { background: #dae5f4; }
#tr:nth-child(odd) { background: #b8d1f3; }

#th:1st-child { background: #dae5f4; }
#th:2nd-child { background: #b8d1f3; }


$body = $Report | ConvertTo-Html -Head $css

$from= "a.chintalapudi@dxc.com"
$to= "a.chintalapudi@dxc.com"
$subject= "DP Service HC"
$SMTPserver="smtp.svcs.hpe.com"

Send-MailMessage -From $from -to $to -Subject $subject -Body "$body" -BodyAsHtml  -SmtpServer $SMTPserver

