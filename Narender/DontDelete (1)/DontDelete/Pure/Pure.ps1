$datetime = Get-Date -Format g
$TZone = [System.TimeZoneInfo]::Local.Id
$time = Get-Date
$date = $time.ToString("yyyy-MM-dd-HH-mm-ss")

$pw="xxxxxxx"
$usr="xxxxx"

$path = "D:\Storage_automation\DontDelete\Pure\ip.txt"
$path1 = "D:\Storage_automation\DontDelete\Pure"

New-Item -Path "$path1\Pure_HC_Output_$date" -ItemType Directory

$path2 = "$path1\Pure_HC_Output_$date"

foreach($ip in Get-content $path)
{

if ($ip -eq "15.167.148.46"){
$name = "USSWPURE80118"
}
elseif ($ip -eq "15.131.141.90")
{
$name = "USTLPURE8013F"
}
elseif ($ip -eq "15.131.142.52")
{
$name = "USTLPURE1003E"
}
elseif ($ip -eq "155.61.220.33")
{
$name = "USPLPURE00031"
}
elseif ($ip -eq "155.61.220.44")
{
$name = "USPLPURE00130"
}
elseif ($ip -eq "155.61.220.41")
{
$name = "USPLPURE00079"
}

$dot = "=========================================================================================================================================================="
$blank = "																								"
$pl = "                                                                     purearray list"
$pm = "                                                                     purearray monitor"
$vl = "                                                                     purevol list"
$hg = "                                                                     purehgroup list"
$ho = "                                                                     purehost list"
$hw = "                                                                     purehw list"
$nt = "                                                                     purenetwork list"

$nm = "Array Name : $name"
$dt = Get-Date -Format dd/MM/yyyy
$time = Get-Date -Format HH:mm:ss
$ts = "Health Status as of $dt $time CST"

echo $nm > "$path2\$name.txt"
echo $ts >> "$path2\$name.txt"

echo $dot >> "$path2\$name.txt"
echo $pl >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"

Write-Host "`n`n******Running Health Check for $ip******" -ForegroundColor Black -BackgroundColor Green


## 1 Running Pure array list command to display the Storage Details
Write-Host "`n`nRunning 'purearray list' command......." -ForegroundColor Black -BackgroundColor Yellow
echo Return | D:\Storage_automation\DontDelete\Pure\plink -ssh -pw $pw $usr@$ip "purearray list" >> "$path2\$name.txt"

echo $blank >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"
echo $pm >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"

## 2 Running purearray monitor command to get the Storage Subsystem Components Health Check status
Write-Host "`n`nRunning 'purearray monitor' command......." -ForegroundColor Black -BackgroundColor Yellow
echo Return | D:\Storage_automation\DontDelete\Pure\plink -ssh -pw $pw $usr@$ip "purearray monitor" >> "$path2\$name.txt"

echo $blank >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"
echo $vl >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"

## 3 Running purevol list command to view Storage Hard Disk Drive Detail
Write-Host "`n`nRunning 'purevol list' command.......`n" -ForegroundColor Black -BackgroundColor Yellow
echo Return | D:\Storage_automation\DontDelete\Pure\plink -ssh -pw $pw $usr@$ip "purevol list" >> "$path2\$name.txt"

echo $blank >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"
echo $hg >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"

## 4 Running purehgroup list command to view Storage Failed Hard Disk Drive Detail if Any
Write-Host "`n`nRunning 'purehgroup list' command.......`n" -ForegroundColor Black -BackgroundColor Yellow
echo Return | D:\Storage_automation\DontDelete\Pure\plink -ssh -pw $pw $usr@$ip "purehgroup list" >> "$path2\$name.txt"

echo $blank >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"
echo $ho >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"

## 5 Running purehost list command to view Storage environment status
Write-Host "`n`nRunning 'environment status' command.......`n" -ForegroundColor Black -BackgroundColor Yellow
echo Return | D:\Storage_automation\DontDelete\Pure\plink -ssh -pw $pw $usr@$ip "purehost list" >> "$path2\$name.txt"

echo $blank >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"
echo $hw >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"

## 6 Running purehw list command to view Storage Aggregate (Pool) Detail
Write-Host "`n`nRunning 'purehw list' command.......`n" -ForegroundColor Black -BackgroundColor Yellow
echo Return | D:\Storage_automation\DontDelete\Pure\plink -ssh -pw $pw $usr@$ip "purehw list" >> "$path2\$name.txt"

echo $blank >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"
echo $nt >> "$path2\$name.txt"
echo $dot >> "$path2\$name.txt"

## 7 Running purenetwork list command to view Storage Aggregate-Wise Capacity Detail
Write-Host "`n`nRunning 'purenetwork list' command.......`n" -ForegroundColor Black -BackgroundColor Yellow
echo Return | D:\Storage_automation\DontDelete\Pure\plink -ssh -pw $pw $usr@$ip "purenetwork list" >> "$path2\$name.txt"

}

$from = "Pure_health-check@dxc.com"
$to = "amslevstorageteam@dxc.com"
$smtp = "138.35.24.152"
$subject = "Auto Mail | Pure HealthCheck on $datetime - $TZone"

$Body = "Dear Team<br>
<br>
Please find the attached Pure health check report on $datetime - $TZone<br>
<br>
<br>
Regards<br>
ITO Global Delivery Center India  --  Storage<br>
DXC Technology</b><br>
<br>"

$source = "$path1\Pure_HC_Output_$date"
$archive = "$path1\Pure_HC_Output_$date.zip"
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($source, $archive)

Send-MailMessage -From $from -To $to -Subject $subject -Body $Body -BodyAsHtml -Attachments $archive -Smtpserver $smtp

Remove-item -path "$path1\Pure_HC_Output_$date.zip" -force -Recurse -ErrorAction Stop

Remove-item -path "$path1\Pure_HC_Output_$date" -force -Recurse -ErrorAction Stop




