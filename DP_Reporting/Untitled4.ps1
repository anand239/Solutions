Function Get-DetailedSummaryReport
{    
    [CmdletBinding()]
    Param(
    $InputObject,
    $OldData
    )

    $Summary = @()
    $UnqClientCount = ($InputObject | Select-Object Clientname -Unique).count
    $UnqJobCount    = ($InputObject | Select-Object Specification -Unique).count
    $Summary       = [Pscustomobject]@{
    "Date"         = (Get-Date).ToString("yyyy-MM-dd")
    "YearMonth"    = (Get-Date).ToString("yyyy-MM")
    "Account"      = $InputObject[0].Account
    "BkpApp"       = $InputObject[0].BkpApp
    "BackupServer" = $InputObject[0].BackupServer
    "Client Count" = $UnqClientCount
    "Job Count"    = $UnqJobCount  
    "Successful Object Count" =  ""
    "Total Object Count" =  ""
    "Size (GB)" =  ""
    "BSR %" =  "" 
    }
    
    $SuccessfulObjCount = ""
    $TotalObjCount = ""
    foreach($Obj in $InputObject)
    {
        $BSRObjSplit        = $Obj."BSR Object" -split "\s"
        $SuccessfulObjCount = [int]$BSRObjSplit[1].trim() + [int]$SuccessfulObjCount
        $TotalObjCount      = [int]$BSRObjSplit[3].trim() + [int]$TotalObjCount
    }
    $SumOfSize = ($InputObject | Measure-Object -Property "size (GB)" -Sum).Sum
    $BSRPercentage = [math]::Round(($SuccessfulObjCount / $TotalObjCount) * 100,2)
    $UniqueAccApp."Successful Object Count" = $SuccessfulObjCount
    $UniqueAccApp."Total Object Count"      = $TotalObjCount
    $UniqueAccApp."BSR %"                   = $BSRPercentage
    $UniqueAccApp."Size (GB)"               = $SumOfSize 
    
    $NewData = $Summary

    if($OldData)
    {
        $NewFinalData = @()
        foreach($NewdataLine in $NewData)
        {
            $Found = $OldData | where{$_.date -eq $NewdataLine.date}
            if($found)
            {
                $found."Successful Object Count" = $NewdataLine."Successful Object Count"
                $found."Total Object Count"      = $NewdataLine."Total Object Count"     
                $found."BSR %"                   = $NewdataLine."BSR %"                  
                $found."Size (GB)"               = $NewdataLine."Size (GB)"      
                $NewFinalData += $Found        
            }
            else
            {
                $NewFinalData += $NewdataLine
            }
        }
        foreach($OldDataLine in $OldData)
        {
            $found = $NewData | where{$_.date -eq $OldDataLine.date}
            if(!($found))
            {
                $NewFinalData += $OldDataLine
            }
        }
    }
    else
    {
        $NewFinalData = $NewData
    }
    $NewFinalData
}


if(Test-Path $AllDataReportName)
{
    $Old_Data = Import-Csv -Path $AllDataReportName
}

$NewFinalData = Get-DetailedSummaryReport -InputObject $BSRReport -OldData $Old_Data


$NewFinalData | Export-Csv $AllDataReportName -NoTypeInformation




Function Get-MonthlySummary
{
    [CmdletBinding()]
    Param(
    $InputObject,
    $OldData
    )
    $YearMonths = $InputObject | select -Property "YearMonth" -Unique
    $MonthlySummary = @()
    foreach($YearMonth in $YearMonths)
    {
        $SuccessfullObject = ($InputObject | where{$_.YearMonth -eq $YearMonth} | Measure-Object "Successful Object Count" -Sum).Sum
        $TotalObject       = ($InputObject | where{$_.YearMonth -eq $YearMonth} | Measure-Object "Total Object Count" -Sum).Sum
        $Percentage = [math]::Round(($SuccessfullObject / $TotalObject ) *100,2)
        $Size = ($InputObject | where{$_.YearMonth -eq $YearMonth} | Measure-Object "Size (GB)" -Sum).Sum
        $MonthlySummary += [pscustomobject] @{
        "YearMonth"      = $YearMonth
        "Account"        = $InputObject[0].Account
        "BkpApp"         = $InputObject[0].BkpApp
        "BackupServer"   = $InputObject[0].BackupServer
        "BSR Object"     = "# $SuccessfullObject / $TotalObject"
        "Percentage"     = "$Percentage"
        "Size (GB)"      = $Size
        }
    }
    $NewMonthlySummaryData = $MonthlySummary
    if($OldMonthlySummaryData)
    {
        $NewMonthlySummaryDataFinal = @()
        foreach($NewMonthlySummaryDataline in $NewMonthlySummaryData)
        {
            $Found = $OldMonthlySummaryData | where{$_.YearMonth -eq $NewMonthlySummaryDataline.YearMonth}
            if($Found)
            {
                $Found."BSR Object" = ($NewMonthlySummaryData | where{$_.YearMonth -eq $YearMonth})."BSR Object"
                $Found."Percentage" = ($NewMonthlySummaryData | where{$_.YearMonth -eq $YearMonth})."Percentage"
                $Found."Size (GB)"  = ($NewMonthlySummaryData | where{$_.YearMonth -eq $YearMonth})."Size (GB)"
                $NewMonthlySummaryDataFinal += $Found
            }
            else
            {
                $NewMonthlySummaryDataFinal += $NewMonthlySummaryDataline
            }
        }
        foreach($OldMonthlySummaryDataline in $OldMonthlySummaryData)
        {
            $Found = $NewMonthlySummaryData | where{$_.yearmonth -eq $OldMonthlySummaryDataline.yearmonth}
            if(!($found))
            {
                $NewMonthlySummaryDataFinal += $OldMonthlySummaryDataline
            }
        }
    }
    else
    {
        $NewMonthlySummaryDataFinal = $NewMonthlySummaryData
    }
    $NewMonthlySummaryDataFinal
}

$CurrentYearMonth = (Get-Date).ToString("yyyy_MM")

if(Test-Path $MonthlySummaryReportName)
{
    $OldMonthlySummaryData = Import-Csv -Path $MonthlySummaryReportName
}

$NewMonthlySummaryDataFinal = Get-MonthlySummary -InputObject $NewFinalData -OldData $OldMonthlySummaryData

$NewMonthlySummaryDataFinal | Export-Csv $MonthlySummaryReportName -NoTypeInformation
