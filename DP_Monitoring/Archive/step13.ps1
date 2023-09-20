$DP_Mon_Detail = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\DP_Mon_Detail.csv"
$today = Get-Date
$yesterday = [datetime]"$($today.AddDays(-1).ToString("MM/dd/yyyy")) 18:00"
$DP_Mon_Detail_Validation = @()
foreach($line in $DP_Mon_Detail)
{
    $Filedate = [datetime]$line.'End time'
    $timespan = (New-TimeSpan -Start $Filedate -End $today).TotalDays
    if(-not($timespan -gt 35))
    {
        if($Filedate -lt $yesterday)
        {
            $DP_Mon_Detail_Validation += [pscustomobject] @{
            "Sepcification" = $line.Sepcification
            "Session ID"    = $line.'Session ID'
            "Mode"          = $line.Mode
            "HostName"      = $line.HostName
            "Object Status" = $line.'Object Status'
            "End Time"      = $line.'End Time'
            "Validation"    = "Skip"
            }
        }
        else
        {
            $DP_Mon_Detail_Validation += [pscustomobject] @{
            "Sepcification" = $line.Sepcification
            "Session ID"    = $line.'Session ID'
            "Mode"          = $line.Mode
            "HostName"      = $line.HostName
            "Object Status" = $line.'Object Status'
            "End Time"      = $line.'End Time'
            "Validation"    = ""
            }
        }
    }
}

$NoSkip = $DP_Mon_Detail_Validation | Where-Object {$_.validation -ne "Skip"}
$DP_Mon_Detail_Group = $NoSkip | Group-Object Sepcification,Mode,HostName

$DP_Mon_Detail_NoDuplicate = @()

foreach($DetailGroup in $DP_Mon_Detail_Group)
{
    if($DetailGroup.count -gt 1)
    {
        $DP_Mon_Detail_NoDuplicate += $DetailGroup.group | select -First 1
    }
    else
    {
        $DP_Mon_Detail_NoDuplicate += $DetailGroup.group
    }
}

$EventData = Import-Csv "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\Event1.csv" | foreach{$i=0}{$_ | Add-Member Index ($i++) -PassThru}

[System.Collections.ArrayList]$DP_Mon_Detail_Unique = $DP_Mon_Detail_NoDuplicate | foreach{$i=0}{$_ | Add-Member Index ($i++) -PassThru}
foreach($uniqueline in $DP_Mon_Detail_Unique)
{
    $linenumber = ($EventData | Where-Object{$_.Sepcification -eq $uniqueline.Sepcification -and $_.SessionId -eq $uniqueline.SessionId -and $_.hostname -eq $uniqueline.hostname}).index
    if($linenumber)
    {
        $DataMatched = $EventData | Where-Object{$_.index -gt $linenumber}
        $UniqueMatched = $DataMatched | Where-Object{$_.Sepcification -eq $uniqueline.Sepcification -and $_.Mode -eq $uniqueline.Mode -and $_.hostname -eq $uniqueline.hostname}
        if($UniqueMatched)
        {
            $DP_Mon_Detail_NoDuplicate.RemoveAt($uniqueline.index)
        }
    }
}
<#
$EventDataTxt = Get-Content "C:\Users\achintalapud\OneDrive - DXC Production\Documents\UCMS\DP\DP_Monitoring\Files\Event1.csv" | select -Skip 1
foreach($Uniqueline in $DP_Mon_Detail_NoDuplicate)
{
    #$linenumber = $EventData | Where-Object{$_.Sepcification -eq $uniqueline.Sepcification -and $_.Mode -eq $uniqueline.Mode -and $_.hostname -eq $uniqueline.hostname}
    $i = 0
    foreach($line in $EventDataTxt)
    {
        $i++
        $AvailableLineNumber = ($EventDataTxt | Select-String -pattern "$($Uniqueline.Sepcification)","$($Uniqueline.hostname)","$($Uniqueline.mode)").LineNumber
        if($AvailableLineNumber)
        {
            break
        }
    }
    $NextLines = @()
    if($AvailableLineNumber)
    {
        for($i=$AvailableLineNumber; $i -lt $EventDataTxt.count; $i++)
        {
            $NextLines += $EventData[$i]
        }
        $DataMatched = $NextLines | Where-Object{$_.Hostname -eq $Uniqueline.hostname -and $_.Sepcification -eq $Uniqueline.Sepcification -and $_.Mode -eq $Uniqueline.Mode}
        if($DataMatched)
        {
            $DP_Mon_Detail_RemoveLines += $DataMatched
        }
    }

}
#>








