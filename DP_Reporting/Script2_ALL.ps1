<#
.SYNOPSIS
  Get-ReportingDashboard.ps1
    
.INPUTS
  Configfile
  config.json
   
.NOTES
  Script:         Get-ReportingDashboard.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v5.0 , PswriteHTML Module, Windows 2008 R2 Or Above
  Creation Date:  05/01/2021
  Modified Date:  05/01/2021 

  .History:
        Version Date            Author                       Description        
        1.0     05/01/2021      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-ReportingDashboard.ps1 -ConfigFile .\config.json
#>

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

Function Get-Attachment
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $MailBox,
        [Parameter(Mandatory = $true)]
        $OutLookFolder,
        [Parameter(Mandatory = $true)]
        $SenderMailAddressList,
        [Parameter(Mandatory = $true)]
        $DownloadPath
    )
    Add-Type -assembly "Microsoft.Office.Interop.Outlook"
    Add-Type -assembly "System.Runtime.Interopservices"
    try
    {
        $outlook = [Runtime.Interopservices.Marshal]::GetActiveObject('Outlook.Application')
        $outlookWasAlreadyRunning = $true
    }
    catch
    {
        try
        {
            $Outlook = New-Object -ComObject Outlook.Application
            $outlookWasAlreadyRunning = $false
        }
        catch
        {
            Write-Host "You must exit Outlook first."
            exit
        }
    }
    $namespace = $Outlook.GetNameSpace("MAPI")
    $ReportFolderPath = $OutLookFolder -split "\\"
    try
    {
        $ReportFolder = $namespace.Folders.Item($MailBox)
        if ($ReportFolder)
        {
            foreach ($ReportFolderName in $ReportFolderPath)
            {
                $SubFolders = $ReportFolder.Folders
                $ReportFolder = $SubFolders.item($ReportFolderName)
            }
        }  
    }
    catch
    {
        $ReportFolder = $null
    }
    if ($ReportFolder)
    {
        
        if ($SenderMailAddressList.Count -gt 1)
        {
            foreach ($senderMailAddress in $SenderMailAddressList)
            {
                $senderMail = $senderMailAddress -split "<"
                $todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and $_.UnRead -eq $true}
                #$todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and  $_.SentOn.Date -eq (Get-Date).Date -and $_.UnRead -eq $true} 
                foreach ($todayReport in $todayReports)
                {
                    $todayReport.attachments | ForEach-Object {
                        $path = Join-Path $DownloadPath $_.FileName
                        $_.saveasfile(($path))                      
                    }
                    $todayReport.UnRead = $false
                }
            }
        }
        else
        {
            $senderMail = $SenderMailAddressList[0] -split "<"
  		        $todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and $_.UnRead -eq $true}
  		        #$todayReports = $ReportFolder.Items | Where-Object {$_.SentOnBehalfOfName.trim() -eq $senderMail[0].trim() -and  $_.SentOn.Date -eq (Get-Date).Date -and $_.UnRead -eq $true} 
  		        foreach ($todayReport in $todayReports)
  		        {
                $todayReport.attachments | ForEach-Object {
                    $path = Join-Path $DownloadPath $_.FileName 
                    $_.saveasfile(($path))
                }
                $todayReport.UnRead = $false
  		        }
        }
  
    }
    else
    {
        Write-Warning "Not received any report files"
    }
    if ($outlookWasAlreadyRunning -eq $false)
    {
        Get-Process "*outlook*" | Stop-Process –Force
    }
}

function New-DownloadFolder
{
    Param (
        [Parameter(Mandatory = $True)]
        [String]$Path
    )
    $CheckFlag = $True
    try
    {
            
        if ([System.IO.Path]::IsPathRooted($Path))
        {
            $DownloadPath = $Path 
        }
        else
        {
            $ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
            $DownloadPath = Join-Path $ScriptDir -ChildPath $Path
        }
        
        if (!(Test-Path -Path $DownloadPath))
        { 
            New-Item -ItemType directory -Path $DownloadPath -ErrorAction Stop | Out-Null
        } 
    }
    catch
    {
        Write-Warning $_.Exception.InnerException.Message
        $CheckFlag = $False
    }
    $CheckFlag, $DownloadPath
}
###########################################
Function Get-CalendarReport
{
    [CmdletBinding()]
    Param(
    $InputObject,
    $ReportType,
    $RawData
    )

    $UniqueClients = @()
    foreach($UniqueClientGroup in $InputObject)
    {
        $UniqueClients += $UniqueClientGroup.Group[0] | select Account,BkpApp,BackupServer,Clientname,Specification,Mode
    }
    foreach($Uniquedate in $Uniquedates)
    {
        $UniqueClients | Add-Member NoteProperty "$Uniquedate" ""
    }

    $Clients = $UniqueClients
    foreach($Uniquedate in $Uniquedates)
    {
        foreach($UniqueClient in $UniqueClients)
        {
            $BSRValue = $RawData | Where-Object{$_.Account -eq $UniqueClient.Account -and $_.BkpApp -eq $UniqueClient.BkpApp -and $_.ClientName -eq $UniqueClient.Clientname -and $_.BackupServer -eq $UniqueClient.BackupServer -and $_.Specification -eq $UniqueClient.Specification -and $_.Mode -eq $UniqueClient.Mode -and $_.Date -eq $Uniquedate }
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
    $UniqueClients
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

Function Get-CountReport
{
    [CmdletBinding()]
    Param(
    $RawData,
    $CountReportType
    )

    $CountReport = $RawData | Select-Object Account,BkpApp,Backupserver -Unique
    foreach($Uniquedate in $Uniquedates)
    {
        $CountReport  | Add-Member NoteProperty "$Uniquedate" ""
    }

    foreach($Uniquedate in $Uniquedates)
    {
        foreach($client in $CountReport)
        {
            $Count = ($RawData | where{$_.Date -eq $Uniquedate -and $_.Account -eq $client.Account -and $_.BkpApp -eq $client.BkpApp -and $_.BackupServer -eq $client.BackupServer} | select $CountReportType -Unique).count
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
    $CountReport
}

Function Get-JobCounteachClientReport
{
    [CmdletBinding()]
    Param(
    $RawData
    )

    $UniqueClientGroups = $RawData | Group-Object Account,BkpApp,BackupServer,Clientname
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
            $value = $RawData |  Where-Object{$_.Account -eq $UniqueClient.Account -and $_.BkpApp -eq $UniqueClient.BkpApp -and $_.BackupServer -eq $UniqueClient.BackupServer -and $_.ClientName -eq $UniqueClient.Clientname -and $_.Date -eq $Uniquedate}
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
    $JobCountEachClient
}

Function Get-ContinuousFailures
{
    [CmdletBinding()]
    Param(
    $InputObject,
    $Days
    )
    $LatestDatesProperties = $InputObject| Get-member -MemberType 'NoteProperty' | Select-Object -ExpandProperty Name | Sort-Object -Descending | select -Skip 6 | select -First $Days
    $ContinuousFailures = @()
    foreach($Line in $InputObject)
    {
        $Count = 0
        foreach($LatestDatesProperty in $LatestDatesProperties)
        {
            if(($Line).$LatestDatesProperty -eq 0)
            {
                $Count++
            }
        }
        if($Count -eq $Days)
        {
            $ContinuousFailures += $Line
        }
    }
    $ContinuousFailures
}


$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started"                             -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)"          -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)"              -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

if($config)
{

    $DownloadPathFlag, $DownloadPath = New-DownloadFolder -Path "tmpFiles"
    if($DownloadPathFlag)
    {
        if ($config.DownloadFromOutLook -eq "yes")
        {
            Add-Type -AssemblyName System.Web
            $DownloadAttachmentParameter = @{
                MailBox           = $config.mailbox
                OutLookFolder     = $config.mailLocation
                SenderMailAddress = $config.senderMailAddress
                DownloadPath      = $DownloadPath
            }
            Get-Attachment @DownloadAttachmentParameter
        }
        if (Test-Path  $DownloadPath)
        {
            $BSRRepFiles = Get-ChildItem -Path "$($config.DownloadedFilesfolder)\*" -Include "*.csv" | Where-Object{$_.Name -like "*_BSR-Size_*"}
        }
        if($BSRRepFiles)
        {
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

            $UniqueClientGroups = $ConsolidatedBSRRep | Group-Object Account,BkpApp,Clientname,BackupServer,Specification,mode
            $Uniquedates = ($ConsolidatedBSRRep| Sort-Object date -Descending | Select-Object date -Unique).date
            #########################################################################################################################################

            #$UnqClients = Get-UniqueClients  -InputObject $UniqueClientGroups
            $SizeReport = @()
            $SizeReport = Get-CalendarReport -InputObject $UniqueClientGroups -RawData $ConsolidatedBSRRep -ReportType "Size (GB)"
            #########################################################################################################################################

            #$UnqClients = Get-UniqueClients  -InputObject $UniqueClientGroups
            $BSRReport  = @()
            $BSRReport  = Get-CalendarReport -InputObject $UniqueClientGroups -RawData $ConsolidatedBSRRep -ReportType "Percentage"
            #########################################################################################################################################

            #$UnqClients     = Get-UniqueClients  -InputObject $UniqueClientGroups
            $DurationReport = @()
            $DurationReport = Get-CalendarReport -InputObject $UniqueClientGroups -RawData $ConsolidatedBSRRep -ReportType "Duration (min)"
            #########################################################################################################################################

            $UniqueClientCountReport  = Get-CountReport -RawData $ConsolidatedBSRRep -CountReportType "ClientName"
    
            $UniqueJobCountReport     = Get-CountReport -RawData $ConsolidatedBSRRep -CountReportType "Specification"

            $JobCounteachClientReport = Get-JobCounteachClientReport -RawData  $ConsolidatedBSRRep

            $SummaryReport            = Get-SummaryReport         -InputObject $ConsolidatedBSRRep

            $DetailedSummaryReport    = Get-DetailedSummaryReport -InputObject $ConsolidatedBSRRep

            $ContinuousFailuresReport = Get-ContinuousFailures    -InputObject $BSRReport -Days 3

            #########################################################################################################################################

            $ConsolidatedBSRReportName = $config.ReportPath + "\" + "Consolidated_BKP-Rep" + "_" + $Config.Reportdays + ".csv"
            $ConsolidatedBSRRep | Export-Csv -Path $ConsolidatedBSRReportName -NoTypeInformation
            $HTMLReportName = $config.ReportPath + "\" + "HTML" + "_" + $Config.Reportdays + ".html"

            Import-Module ".\PsWriteHTML\0.0.164\PSWriteHTML.psd1"
            $BSRProperties = $BSRReport| Get-member -MemberType 'NoteProperty' | Select-Object -ExpandProperty Name | Sort-Object -Descending | select -Skip 6
            New-HTML -TitleText 'Reporting' -FilePath $HTMLReportName -Show {
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
                            New-HTMLTable -ArrayOfObjects $UniqueClientCountReport -HideFooter -DisableNewLine {
                            } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 3
                        }
                        New-HTMLContent -HeaderText 'Job Count Report' -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                            New-HTMLTable -ArrayOfObjects $UniqueJobCountReport -HideFooter -DisableNewLine {
                            } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 3
                        }
                        New-HTMLContent -HeaderText 'Job Count Report for each Client' -HeaderBackGroundColor "#5F249F" -CanCollapse -HeaderTextColor White{
                            New-HTMLTable -ArrayOfObjects $JobCounteachClientReport -HideFooter -DisableNewLine {
                            } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 4
                        }
                    }
                    New-HTMLTab -Name 'Continuous Failures'{
                        New-HTMLContent -HeaderText 'Continous Failures' -HeaderBackGroundColor "#5F249F" -HeaderTextColor White{
                            New-HTMLTable -ArrayOfObjects $ContinuousFailuresReport -HideFooter -DisableNewLine {
                                Foreach($BSRProperty in $BSRProperties)
                                {
                                    New-HTMLTableCondition -Name  "$BSRProperty" -ComparisonType number -Operator lt -Value 100 -BackgroundColor red -Color white -Inline -Alignment center
                                    New-HTMLTableCondition -Name  "$BSRProperty" -ComparisonType number -Operator eq -Value 100 -BackgroundColor Green -Color white -Inline -Alignment center
                                    New-HTMLTableCondition -Name  "$BSRProperty" -ComparisonType string -Operator eq -Value "" -BackgroundColor White -Color white -Inline
                                } 
                            } -DisableSelect -DisableStateSave -FixedHeader -ScrollX -ScrollSizeY 300 -FixedFooter  -FreezeColumnsLeft 6
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
            Write-Log -Path $Activitylog -Entry "No report files in $DownloadPath" -Type Warning -ShowOnConsole
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Error in Download Path" -Type Warning -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
