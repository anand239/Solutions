<#
.SYNOPSIS
  Get-DPService.ps1

.DESCRIPTION
  Operations Performed:
    1. Data Protector Service Status 
    2. DP Services Stop and Start
    
   
.NOTES
  Script:         Get-DPService.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v5.0
  Creation Date:  15/09/2021
  Modified Date:  15/09/2021 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     15/09/2021      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-DPService.ps1
#>

Function Get-DpService
{
    [CmdletBinding()]
    Param(
    #[parameter(Mandatory = $true)]
    $InputObject 
    )
    #omnisv -status
  
    $Service_Input = $InputObject | Select-String -Pattern ": " | Select-String -Pattern "Status:" -NotMatch
    $Dp_Service_Result = @()
    for($i=0;$i -lt $Service_Input.count;$i++)
    {
        $array = $Service_Input[$i] -split ":"
        $Dp_Service_Result += [PSCUSTOMObject] @{
         "ProcName" =$array[0].trim()
         "Status"= $array[1].trim()
         }
    }
    
    $Total_count = ($Dp_Service_Result).Count
    $Active_count = ($Dp_Service_Result | Where-Object{$_.'Status' -like "*Active*"}).count
    $percent = [math]::Round(($Active_Count/$Total_count)*100,2)
    If($percent -lt 100)
    {
        $signal = "R"
    }
    else
    {
        $signal = "G"
    }
    $Dpservice_signal = [PSCUSTOMObject] @{     
    'HC_Name'= "DP Service Status"
    "Value"= "$Active_Count/$Total_count"
    'ValuePercentage' = "$percent%"
    'Status' = "$Signal"
    }
    $Dpservice_signal,$Dp_Service_Result
}
$Dp_Service_Output = omsisv -status
$Dpservice_signal,$Dp_Service_Result = Get-DpService -InputObject $Dp_Service_Output

if($Dpservice_signal.Status -eq "R")
{
    omnisv stop
    Start-Sleep -Seconds 10
    omnisv start
    $Dp_Service_Output = omnisv -status
    $Dpservice_signal,$Dp_Service_Result = Get-DpService -InputObject $Dp_Service_Output
}

$datetime = Get-Date -Format g
$TZone = [System.TimeZoneInfo]::Local.Id
$precontent1 = "<b> <font size=+1> Data Protector Service Healthcheck Report  | $datetime ($TZone) </font> </b>"

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


$Body = "<br>"
$Body += $Dpservice_signal | ConvertTo-Html -PreContent "<br> $precontent1 </br><br></br>" -Head $css
$Body += "<br />"
$Body += $Dp_Service_Result | ConvertTo-Html -Head $css
$Body += "<br></br>"

$Body | Out-File "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\windows\DP_service.html"

$from= "tess@dxc.com"
$to= "test@dxc.com"
$subject= "DP Service HC"
$SMTPserver="smtp.svcs.hpe.com"

Send-MailMessage -From $from -to $to -Subject $subject -Body "$body" -BodyAsHtml  -SmtpServer $SMTPserver

