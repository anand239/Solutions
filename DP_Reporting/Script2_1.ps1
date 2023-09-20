﻿[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile = "config.json"
)

function Get-Config
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile # = "config.json"
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

function Write-Log
{
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] 
        [string] $Path,
        [parameter(Mandatory = $true)] 
        $Entry,
        [parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warning', 'Information', 'Exception')]
        [string] $Type,
        [switch]
        $ShowOnConsole,
        [switch]
        $OverWrite
    )
  
    if ($Type -eq "Error")
    {
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [ERR]  - $Entry"
        if ($ShowOnConsole) { Write-Host "$Entry" -ForegroundColor Red}
    }
    elseif ($Type -eq "Warning")
    { 
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [WARN] - $Entry"
        if ($ShowOnConsole) { Write-Host "$Entry" -ForegroundColor Yellow }
    }
    elseif ($Type -eq "Information")
    { 
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [INFO] - $Entry"
        if ($ShowOnConsole) {  Write-Host "$Entry" -ForegroundColor Green }
    }
    elseif ($Type -eq "Exception")
    { 
        $logEntry = "[$(Get-Date -Format "dd-MMM-yyyy HH:mm:ss")] - [EXP]  - $Entry"
        if ($ShowOnConsole) {  Write-Host "$Entry" -ForegroundColor Red }
    }
    if($OverWrite)
    {
        $logEntry | Out-File $Path
    }
    else
    {
        $logEntry | Out-File $Path -Append
    }
}


Function Get-CalendarReport
{
    [CmdletBinding()]
    Param(
    $InputObject,
    $ReportType,
    $RawData
    )
    $Clients = $InputObject
    foreach($Uniquedate in $Uniquedates)
    {
        foreach($UniqueClient in $Clients)
        {
            $BSRValue = $RawData | Where-Object{$_.BackupServer -eq $UniqueClient.BackupServer -and $_.Specification -eq $UniqueClient.Specification -and $_.ClientName -eq $UniqueClient.Clientname -and $_.Date -eq $Uniquedate -and $_.BkpApp -eq $UniqueClient.BkpApp -and $_.Account -eq $UniqueClient.Account}
            if($BSRValue)
            {
                $Value= $BSRValue[0]."$ReportType"
            }
            else
            {
                $Value = $null
            }
            $UniqueClient."$Uniquedate" = "$Value"
        }
    }
    $Clients
}

Function Get-SummaryReport
{    
    [CmdletBinding()]
    Param(
    $InputObject)

    $UniqueAccApps = @()
    $Summary = @()
    $UniqueAccApps = $InputObject | Select-Object Account,BkpApp -Unique
    foreach($UniqueAccApp in $UniqueAccApps)
    {
        $UnqClientCount = ($InputObject | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp} | Select-Object Clientname -Unique).count
        $UnqJobCount    = ($InputObject | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp} | Select-Object Specification -Unique).count
        $Summary      += [Pscustomobject]@{
        "Account"      = $UniqueAccApp.Account
        "BkpApp"       = $UniqueAccApp.BkpApp
        "Client Count" = $UnqClientCount
        "Job Count"    = $UnqJobCount   
        }
    }

    #########################################################################################################################################

    $SuccessfulObjCount = ""
    $TotalObjCount = ""
    $Summary | Add-Member NoteProperty "Successful Object Count" ""
    $Summary | Add-Member NoteProperty "Total Object Count" ""
    $Summary | Add-Member NoteProperty "Size (TB)" ""
    $Summary | Add-Member NoteProperty "BSR %" ""
    foreach($UniqueAccApp in $Summary)
    {
        $Unq = $InputObject | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp}
        if($unq)
        {
            foreach($Obj in $Unq)
            {
                $BSRObjSplit        = $Obj."BSR Object" -split "\s"
                $SuccessfulObjCount = [int]$BSRObjSplit[1].trim() + [int]$SuccessfulObjCount
                $TotalObjCount      = [int]$BSRObjSplit[3].trim() + [int]$TotalObjCount
            }
            $SumOfSize = ($unq | Measure-Object -Property "size (GB)" -Sum).Sum
            $BSRPercentage = ($unq | Measure-Object -Property "Percentage" -Average).Average
            $UniqueAccApp."Successful Object Count" = $SuccessfulObjCount
            $UniqueAccApp."Total Object Count"      = $TotalObjCount
            $UniqueAccApp."BSR %"                   = [math]::Round($BSRPercentage, 2)
            $UniqueAccApp."Size (TB)"               = [math]::Round($SumOfSize * 0.001,2)
            $SuccessfulObjCount = ""
            $TotalObjCount = ""
        }
        else
        {
            $UniqueAccApp."Successful Object Count" = $Null
            $UniqueAccApp."Total Object Count"      = $Null
            $UniqueAccApp."Size (TB)"               = $Null
            $UniqueAccApp."BSR %"                   = $Null
            $SuccessfulObjCount = ""
            $TotalObjCount = ""
        }
    }
    $Summary
}

Function Get-DetailedSummaryReport
{    
    [CmdletBinding()]
    Param(
    $InputObject
    )

    $UniqueAccApps = @()
    $Summary = @()
    $UniqueAccApps = $InputObject | Select-Object Account,BkpApp,BackupServer -Unique
    foreach($UniqueAccApp in $UniqueAccApps)
    {
        $UnqClientCount = ($InputObject | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp -and $_.BackupServer -eq $UniqueAccApp.BackupServer} | Select-Object Clientname -Unique).count
        $UnqJobCount    = ($InputObject | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp -and $_.BackupServer -eq $UniqueAccApp.BackupServer} | Select-Object Specification -Unique).count
        $Summary      += [Pscustomobject]@{
        "Account"      = $UniqueAccApp.Account
        "BkpApp"       = $UniqueAccApp.BkpApp
        "BackupServer" = $UniqueAccApp.BackupServer
        "Client Count" = $UnqClientCount
        "Job Count"    = $UnqJobCount   
        }
    }

    #########################################################################################################################################

    $SuccessfulObjCount = ""
    $TotalObjCount = ""
    $Summary | Add-Member NoteProperty "Successful Object Count" ""
    $Summary | Add-Member NoteProperty "Total Object Count" ""
    $Summary | Add-Member NoteProperty "Size (TB)" ""
    $Summary | Add-Member NoteProperty "BSR %" ""
    foreach($UniqueAccApp in $Summary)
    {
        $Unq = $InputObject | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp -and $_.BackupServer -eq $UniqueAccApp.BackupServer}
        if($unq)
        {
            foreach($Obj in $Unq)
            {
                $BSRObjSplit        = $Obj."BSR Object" -split "\s"
                $SuccessfulObjCount = [int]$BSRObjSplit[1].trim() + [int]$SuccessfulObjCount
                $TotalObjCount      = [int]$BSRObjSplit[3].trim() + [int]$TotalObjCount
            }
            $SumOfSize = ($unq | Measure-Object -Property "size (GB)" -Sum).Sum
            $BSRPercentage = ($unq | Measure-Object -Property "Percentage" -Average).Average
            $UniqueAccApp."Successful Object Count" = $SuccessfulObjCount
            $UniqueAccApp."Total Object Count"      = $TotalObjCount
            $UniqueAccApp."BSR %"                   = [math]::Round($BSRPercentage, 2)
            $UniqueAccApp."Size (TB)"               = [math]::Round($SumOfSize * 0.001,2)
            $SuccessfulObjCount = ""
            $TotalObjCount = ""
        }
        else
        {
            $UniqueAccApp."Successful Object Count" = $Null
            $UniqueAccApp."Total Object Count"      = $Null
            $UniqueAccApp."Size (TB)"               = $Null
            $UniqueAccApp."BSR %"                   = $Null
            $SuccessfulObjCount = ""
            $TotalObjCount = ""
        }
    }
    $Summary
}


$config = Get-Config -ConfigFile $ConfigFile
#$Reportdate = ([system.datetime]::UtcNow).ToString("dd-MMM-yy")
#$date = ([system.datetime]::UtcNow).ToString("ddMMMyy")
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

if($config)
{
    $BSRRepFiles = Get-ChildItem -Path "$($config.DownloadedFilesPath)\*" -Include "*.csv" | Where-Object{$_.Name -like "*_BSR-Size_*"}
    $BSRRepFilePaths = @()
    foreach($BSRRepFile in $BSRRepFiles)
    {
        $FileName = $BSRRepFile.Name -split "_"
        $FileDate = [datetime]($FileName.GetValue($FileName.Count - 1).split("."))[0]
        $BSRRepFilePaths += [pscustomobject] @{
        "Date"            = $FileDate
        "Month"           = $FileDate.ToString("MM")
        "Year"            = $FileDate.ToString("yyyy")
        "YearMonth"       = $FileDate.ToString("yyyy_MM")
        "FilePath"        = $BSRRepFile.FullName
        }
    }


    if($config.Reportdays)
    {
        if($config.Reportdays -eq "ALL")
        {
            $ReportFiles = $BSRRepFilePaths
        }
        else
        {
            $ReportFiles = $BSRRepFilePaths | where{$_.Date -eq $YearMonth}
        }
    }
    else
    {
        $RequiredDate = (Get-Date).AddDays(-1)
        $ReportFiles = $BSRRepFilePaths | where{$_.Date -le $RequiredDate}
    }

    $ConsolidatedBSRRep = @()

    foreach($ReportFile in $ReportFiles)
    {
        $ConsolidatedBSRRep += Import-Csv -Path $ReportFile.FilePath
    
    }
    #########################################################################################################################################

    $UniqueClientGroups = $ConsolidatedBSRRep | Group-Object Specification,Clientname,Account,BackupServer,mode,BkpApp
    $Uniquedates = ($ConsolidatedBSRRep| Sort-Object date -Descending | Select-Object date -Unique).date
    #########################################################################################################################################

    $UniqueClients = @()
    foreach($UniqueClientGroup in $UniqueClientGroups)
    {
        $UniqueClients += $UniqueClientGroup.Group[0] | select Account,BkpApp,BackupServer,Clientname,Specification,Mode
    }
    foreach($Uniquedate in $Uniquedates)
    {
        $UniqueClients | Add-Member NoteProperty "$Uniquedate" ""
    }
    $SizeReport = @()
    $SizeReport = Get-CalendarReport -InputObject $UniqueClients -RawData $ConsolidatedBSRRep -ReportType "Size (GB)"
    #########################################################################################################################################


    $UniqueClients = @()
    foreach($UniqueClientGroup in $UniqueClientGroups)
    {
        $UniqueClients += $UniqueClientGroup.Group[0] | select Account,BkpApp,BackupServer,Clientname,Specification,Mode
    }
    foreach($Uniquedate in $Uniquedates)
    {
        $UniqueClients | Add-Member NoteProperty "$Uniquedate" ""
    }
    $BSRReport       =@()
    $BSRReport       = Get-CalendarReport -InputObject $UniqueClients -RawData $ConsolidatedBSRRep -ReportType "Percentage"
    #########################################################################################################################################


    $UniqueClients = @()
    foreach($UniqueClientGroup in $UniqueClientGroups)
    {
        $UniqueClients += $UniqueClientGroup.Group[0] | select Account,BkpApp,BackupServer,Clientname,Specification,Mode
    }
    foreach($Uniquedate in $Uniquedates)
    {
        $UniqueClients | Add-Member NoteProperty "$Uniquedate" ""
    }
    $DurationReport  = @()
    $DurationReport  = Get-CalendarReport -InputObject $UniqueClients -RawData $ConsolidatedBSRRep -ReportType "Duration (min)"
    #########################################################################################################################################

    $UniqueClientCount = $ConsolidatedBSRRep | Select-Object Account,BkpApp,Backupserver -Unique
    foreach($Uniquedate in $Uniquedates)
    {
        $UniqueClientCount  | Add-Member NoteProperty "$Uniquedate" ""
    }

    foreach($Uniquedate in $Uniquedates)
    {
            foreach($client in $UniqueClientCount)
            {
                $Count = ($ConsolidatedBSRRep | where{$_.Date -eq $Uniquedate -and $_.Account -eq $client.Account -and $_.BackupServer -eq $client.BackupServer} | select clientname -Unique).count
                if($Count)
                {
                    $client."$Uniquedate" = $Count
                }
                else
                {
                    $client."$Uniquedate" = $null
                }
            }
    }

    #########################################################################################################################################

    $UniqueJobCount = $ConsolidatedBSRRep | Select-Object Account,BkpApp,Backupserver -Unique
    foreach($Uniquedate in $Uniquedates)
    {
        $UniqueJobCount  | Add-Member NoteProperty "$Uniquedate" ""
    }

    foreach($Uniquedate in $Uniquedates)
    {
            Foreach($client in $UniqueJobCount)
            {
                $Count = ($ConsolidatedBSRRep |  where{$_.Date -eq $Uniquedate -and $_.Account -eq $client.Account -and $_.BackupServer -eq $client.BackupServer} | select Specification -Unique).count
                if($Count)
                {
                    $client."$Uniquedate" = $Count
                }
                else
                {
                    $client."$Uniquedate" = $null
                }
            }
    }
    #########################################################################################################################################

    $UniqueClientGroups = $ConsolidatedBSRRep | Group-Object Clientname,Account,BackupServer,BkpApp
    $JobCountEachClient = @()
    foreach($UniqueClientGroup in $UniqueClientGroups)
    {
        $JobCountEachClient += $UniqueClientGroup.Group[0] | select Account,BkpApp,BackupServer,Clientname
    }
    foreach($Uniquedate in $Uniquedates)
    {
        $JobCountEachClient | Add-Member NoteProperty "$Uniquedate" ""
    }

    foreach($Uniquedate in $Uniquedates)
    {
        foreach($UniqueClient in $JobCountEachClient)
        {
            $value = $ConsolidatedBSRRep |  Where-Object{$_.BackupServer -eq $UniqueClient.BackupServer -and $_.ClientName -eq $UniqueClient.Clientname -and $_.Date -eq $Uniquedate -and $_.BkpApp -eq $UniqueClient.BkpApp -and $_.Account -eq $UniqueClient.Account}
            if($value)
            {
                $UniqueClient."$Uniquedate" = @($value).count
            }
            else
            {
                $UniqueClient."$Uniquedate" = $null
            }
        }
    }

    #########################################################################################################################################

    $SummaryReport = Get-SummaryReport -InputObject $ConsolidatedBSRRep

    #########################################################################################################################################

    $DetailedSummaryReport = Get-DetailedSummaryReport -InputObject $ConsolidatedBSRRep

    #########################################################################################################################################

    $ConsolidatedBSRReportName = $config.ReportPath + "\" + "Consolidated_BKP-Rep" + "_" + $Config.Reportdays + ".csv"
    $HTMLReportName = $config.ReportPath + "\" + "HTML" + "_" + $Config.Reportdays + ".html"

    Import-Module ".\PsWriteHTML\0.0.164\PSWriteHTML.psd1"
    $BSRProperties = $BSRReport| Get-member -MemberType 'NoteProperty' | Select-Object -ExpandProperty Name | Sort-Object -Descending | select -Skip 6
    New-HTML -TitleText 'Data Protector Reporting' -FilePath $HTMLReportName -Show {
        New-htmllogo -LeftLogoString "data:image/png;base64,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"
        #New-HTMLLogo -LeftLogoString "https://upload.wikimedia.org/wikipedia/commons/8/88/DXC_Logo_2021_Purple_Black.png"
        New-HTMLTabOptions -SlimTabs -SelectorColor "#5F249F"
        New-HTMLTab -Name 'Summary Report'{
            New-HTMLTab -Name "Account Summary"{
                New-HTMLContent -HeaderText "Summary Report    ( $($BSRProperties | Select -Last 1) to $($BSRProperties | Select -first 1) )" -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                    New-HTMLTable -ArrayOfObjects $SummaryReport -HideFooter  -DisableNewLine -DataTableID "Summary" -DisableSelect -DisableStateSave -FixedHeader
                }
                New-HTMLSection -HeaderText "Charts" -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                    New-HTMLPanel{
                        New-HTMLChart -Title "BSR Chart" -TitleAlignment center -Height 200 {
                            New-ChartLegend -Name 'BSR %'
                            for ($i = 0; $i -lt $SummaryReport.Count; $i++) {
                                New-ChartBar -Name $SummaryReport[$i].Account -Value $SummaryReport[$i]."BSR %"
                            }
                        }
                    }
                    New-HTMLPanel{
                        New-HTMLChart -Title "Size Chart" -TitleAlignment center -Height 200 {
                            New-ChartLegend -Name 'Size (TB)'
                            for ($i = 0; $i -lt $SummaryReport.Count; $i++) {
                                New-ChartBar -Name $SummaryReport[$i].Account -Value $SummaryReport[$i].'Size (TB)'
                            }
                        }
                    }
                }
            }
            New-HTMLTab -Name "Deatiled Summary"{
                New-HTMLContent -HeaderText "Summary Report    ( $($BSRProperties | Select -Last 1) to $($BSRProperties | Select -first 1) )" -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                    New-HTMLTable -ArrayOfObjects $DetailedSummaryReport -HideFooter  -DisableNewLine -DisableSelect -DisableStateSave -FixedHeader
                }
            }
        }
        New-HTMLTab -Name 'Calendar View Report' {
            New-HTMLTab -Name 'BSR' { 
                New-HTMLContent -HeaderText 'BSR Calendar Report ( % )' -HeaderBackGroundColor "#5F249F"{
                    New-HTMLTable -ArrayOfObjects $BSRReport -HideFooter -DisableNewLine -AutoSize{
                        Foreach($BSRProperty in $BSRProperties)
                        {
                            New-HTMLTableCondition -Name  "$BSRProperty" -ComparisonType number -Operator lt -Value 100 -BackgroundColor red -Color white -Inline -Alignment center
                            New-HTMLTableCondition -Name  "$BSRProperty" -ComparisonType number -Operator eq -Value 100 -BackgroundColor Green -Color white -Inline -Alignment center
                            New-HTMLTableCondition -Name  "$BSRProperty" -ComparisonType string -Operator eq -Value "" -BackgroundColor White -Color white -Inline
                        } 
                    } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter -FreezeColumnsLeft 6
                }
            }
            New-HTMLTab -Name 'Size'{
                New-HTMLContent -HeaderText 'Size Calendar Report ( GB )' -HeaderBackGroundColor "#5F249F"{
                    New-HTMLTable -ArrayOfObjects $SizeReport -HideFooter -InvokeHTMLTags {
                    } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 6
                }
            }
            New-HTMLTab -Name 'Duration'{
                New-HTMLContent -HeaderText 'Duration Calendar Report ( min )' -HeaderBackGroundColor "#5F249F" -HeaderTextColor White{
                    New-HTMLTable -ArrayOfObjects $DurationReport -HideFooter -DisableNewLine {
                    } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 6
                }
            }
            New-HTMLTab -Name 'Count'{
                New-HTMLContent -HeaderText 'Client Count Report' -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                    New-HTMLTable -ArrayOfObjects $UniqueClientCount -HideFooter -DisableNewLine {
                    } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 3
                }
                New-HTMLContent -HeaderText 'Job Count Report' -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                    New-HTMLTable -ArrayOfObjects $UniqueJobCount -HideFooter -DisableNewLine {
                    } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 3
                }
                New-HTMLContent -HeaderText 'Job Count Report for each Client' -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                    New-HTMLTable -ArrayOfObjects $JobCountEachClient -HideFooter -DisableNewLine {
                    } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 4
                }
            }
        }
        New-HTMLTab -Name 'Consolidated Report'{
            New-HTMLContent -HeaderText 'BSR Consolidated Report' -HeaderBackGroundColor "#5F249F"{
                New-HTMLTable -ArrayOfObjects $ConsolidatedBSRRep -HideFooter  -DisableNewLine{
                    New-HTMLTableCondition -Name Percentage -ComparisonType number -Operator lt -Value 100 -BackgroundColor red -Color white #-Alignment center
                } -DisableSelect -DisableStateSave -FixedHeader
            }
        }
    } #-FavIcon "C:\Users\achintalapud\Downloads\Untitled design (3).png"

}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole