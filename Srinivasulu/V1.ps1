
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile = "config.json"
)

function Get-Config
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile  = "config.json"
    ) 
    try
    {
        if (Test-Path -Path $ConfigFile)
        {
            Write-Verbose "Parsing $ConfigFile"
            $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        }
    }
    catch
    {
        Write-Error "Error Parsing $ConfigFile" 
    }
    Write-Output $config
}

$config = Get-Config -ConfigFile $ConfigFile


$Report = @()
$Report2 = @()
[array]$files = $config.actdxcnbmprdv01_FilePath,$config.basdxcnbmprdv01_FilePath
foreach($file in $files)
{
    $Server6 = Import-Csv $file
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


    $FailedJobs = $Server6 | Where-Object{$_.status -eq "failed"}| sort client -Unique
    $between_3_5=$between_6_8=$between_9_31=$Greaterthan31=0
    foreach($FailedJob in $FailedJobs)
    {
        if($FailedJob.Gap_In_Full -gt 2 -and $FailedJob.Gap_In_Full -le 5)
        {
            $between_3_5++
        }
        elseif($FailedJob.Gap_In_Full -gt 5 -and $FailedJob.Gap_In_Full -le 8)
        {
            $between_6_8++
        }
        elseif($FailedJob.Gap_In_Full -gt 8 -and $FailedJob.Gap_In_Full -le 31)
        {
            $between_9_31++
        }
        elseif($FailedJob.Gap_In_Full -gt 31 -or $FailedJob.Gap_In_Full -eq "Null")
        {
            $Greaterthan31++
        }
    }
    $NonComplaint = $between_3_5+$between_6_8+$between_9_31+$Greaterthan31

    $Report2 += [pscustomobject] @{
    "Host Name" = "actdxcnbmprdv01"
    "Source MgmtIP" = "10.147.3.100"
    "Clients" = $Totl_server6_count
    "Non-Complaint" = $NonComplaint
    "3-5 Days" = $between_3_5
    "6-8 Days" = $between_6_8
    "9-31 Days" = "$between_9_31"
    "Greater Than 31 Days" = "$Greaterthan31"
    }

}
$datetime = Get-Date -Format g
$TZone = [System.TimeZoneInfo]::Local.Id


$css = @"
<style>
h1, h5, th { font-size: 11px;text-align: center; font-family: Segoe UI; }
table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: black; color: #fff; max-width: 200px; padding: 5px 10px; }
td { border: 1px solid black;font-size: 11px;text-align: center; padding: 5px 20px; color: #000; }
tr:nth-child(even) {background: #dae5f4;}
tr:nth-child(odd) {background: #b8d1f3;}
</style>
"@
$precontent1 = "<b> <font size=+1> DSR Status for CMO and TMO for last 24 Hours  | $datetime ($TZone) </font> </b>"
$body=""
$body += $Report | ConvertTo-Html -Head $css -PreContent $precontent1 
$body += "<br></br>"
$body += $Report2 | ConvertTo-Html -Head $css 
$body| Out-File 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile2.html'


$from= "a.chintalapudi@dxc.com"
$to= "a.chintalapudi@dxc.com"
$subject= "DP Service HC"
$SMTPserver="smtp.svcs.hpe.com"
$body = ""
$body += Get-Content 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile2.html'
$attach = 'C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\ofile2.html'
Send-MailMessage -From $from -to $to -Subject $subject -Body "$body" -BodyAsHtml  -SmtpServer $SMTPserver -Attachments $attach
