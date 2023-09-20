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
    $BSRRepFiles = Get-ChildItem -Path C:\Users\achintalapud\Downloads\DpReporting_Suresh\* -Include "*.csv" | Where-Object{$_.Name -like "*_BSR-Size_*"}
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

    $UniqueAccApps = @()
    $Summary = @()
    $UniqueAccApps = $ConsolidatedBSRRep | Select-Object Account,BkpApp -Unique
    foreach($UniqueAccApp in $UniqueAccApps)
    {
        $UnqClientCount = ($ConsolidatedBSRRep | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp} | Select-Object Clientname -Unique).count
        $UnqJobCount    = ($ConsolidatedBSRRep | where{$_.Account -eq $UniqueAccApp.Account -and $_.BkpApp -eq $UniqueAccApp.BkpApp} | Select-Object Specification -Unique).count
        $Summary += [Pscustomobject]@{
        "Account"      = $UniqueAccApp.Account
        "BkpApp"       = $UniqueAccApp.BkpApp
        "Client Count" = $UnqClientCount
        "Job Count"    = $UnqJobCount   
        }
    }

    #########################################################################################################################################

    $SuccessfulObjCount = ""
    $TotalObjCount = ""

        foreach($Obj in $ConsolidatedBSRRep)
        {
            $BSRObjSplit        = $Obj."BSR Object" -split "\s"
            $SuccessfulObjCount = [int]$BSRObjSplit[1].trim() + [int]$SuccessfulObjCount
            $TotalObjCount      = [int]$BSRObjSplit[3].trim() + [int]$TotalObjCount
        }


    $ConsolidatedBSRReportName = $config.ReportPath + "\" + "Consolidated_BKP-Rep" + "_" + $Config.Reportdays + ".csv"
    $HTMLReportName = $config.ReportPath + "\" + "HTML" + "_" + $Config.Reportdays + ".html"

}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
