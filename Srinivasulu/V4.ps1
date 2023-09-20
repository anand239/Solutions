﻿
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
$Servers = Import-Csv $config.InputFilePath
foreach($Server in $Servers)
{
    $InputObject = Import-Csv $Server.filepath
    $Client = $InputObject | Where-Object{$_.client_name -ne "None"}
    $Totl_Client_count = $Client.Count
    $Failed_Client_count = @($Client | Where-Object{$_.status -eq "failed"}).Count 
    $Success_Client_count = @($Client | Where-Object{$_.status -eq "Successfull"}).Count
    $DSR_Percentage = [math]::Round(($Success_Client_count/$Totl_Client_count)*100,0)

    $Report += [pscustomobject] @{
    "Host Name" = $Server.Hostname
    "Source MgmtIP" = $Server.Ip
    "Total Jobs" = $Totl_Client_count
    "Successfull Jobs" = $Success_Client_count
    "Failed Jobs" = $Failed_Client_count
    "DSR" = "$DSR_Percentage%"
    }


    $FailedJobs = $Client | Where-Object{$_.status -eq "failed"}| sort client_name -Unique
    $between_3_5=$between_6_8=$between_9_31=$Greaterthan31=0
    foreach($FailedJob in $FailedJobs)
    {
        $Incr = [int]$FailedJob.Incr_gap
        if($incr -gt 2 -or $incr -eq "NA")
        {
            if($incr -gt 2 -and $incr -le 5)
            {
                $between_3_5++
            }
            elseif($incr -gt 5 -and $incr -le 8)
            {
                $between_6_8++
            }
            elseif($incr -gt 8 -and $incr -le 31)
            {
                $between_9_31++
            }
            elseif($incr -gt 31 -or $incr -eq "NA")
            {
                $Greaterthan31++
            }
        }
        else
        {
            $Full = [int]$FailedJob.Gap_In_Full
            if($Full -gt 2 -and $Full -le 5)
            {
                $between_3_5++
            }
            elseif($Full -gt 5 -and $Full -le 8)
            {
                $between_6_8++
            }
            elseif($Full -gt 8 -and $Full -le 31)
            {
                $between_9_31++
            }
            elseif($Full -gt 31 -or $Full -eq "NA")
            {
                $Greaterthan31++
            }
        }
    }
    $NonComplaint = $between_3_5+$between_6_8+$between_9_31+$Greaterthan31

    $Report2 += [pscustomobject] @{
    "Host Name" = $Server.Hostname
    "Source MgmtIP" = $Server.Ip
    "Clients" = $Totl_Client_count
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
th { background: black; color: #fff; max-width: 50px; padding: 2px 5px; }
td { border: 1px solid black;font-size: 11px;text-align: center; padding: 2px 15px; color: #000; }
tr:nth-child(even) {background: #dae5f4;}
tr:nth-child(odd) {background: #b8d1f3;}
</style>
"@
$precontent1 = "<b> <font size=+1> DSR Status for CMO and TMO for last 24 Hours  | $datetime ($TZone) </font> </b>"
$body=""
$body += $Report | ConvertTo-Html -Head $css -PreContent $precontent1 
$body += "<br>"
$body += $Report2 | ConvertTo-Html -Head $css 

#$body | Out-File "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\Srinivasulu\newreport.html"


$from= $config.Mail.From
$to= $config.Mail.To
$subject= $config.Mail.Subject
$SMTPserver=$config.Mail.SmtpServer
Send-MailMessage -From $from -to $to -Subject $subject -Body "$body" -BodyAsHtml  -SmtpServer $SMTPserver
