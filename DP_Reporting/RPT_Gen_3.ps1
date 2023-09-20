﻿<#
.SYNOPSIS
  RPT_Gen.ps1
    
.INPUTS
  Configfile
  config.json
   
.NOTES
  Script:         RPT_Gen.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0 , Posh-SSH Module, Windows 2008 R2 Or Above
  Creation Date:  22/07/2021
  Modified Date:  22/07/2021 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     22/07/2021      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\RPT_Gen.ps1 -ConfigFile .\config.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ConfigFile = "config.json"
)

function Remove-File()
{
    [CmdletBinding()]
    param($Day, $DirectoryPath, $FileType)
    if (!(Test-Path $DirectoryPath))
    {
        Return
    }
    $CurrentDate = Get-Date;
    $DateToDelete = $CurrentDate.AddDays(-$Day);
    $DirectoryPath = $DirectoryPath + "\*"
    Get-ChildItem $DirectoryPath -Include $FileTypepe | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
}

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

Function Send-Mail
{
    [CmdletBinding()]
    Param(
    $attachments,
    $MailMessage
    )
    $sendMailMessageParameters = @{
            To          = $config.mail.To.Split(";")
            from        = $config.mail.From 
            Subject     = "$($config.mail.Subject) at $(Get-Date -Format 'dd-MMM-yyyy - HH:mm:ss')"      
            BodyAsHtml  = $true
            SMTPServer  = $config.mail.smtpServer             
            ErrorAction = 'Stop'
        } 

    if ($config.mail.Cc) 
    { 
        $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";")) 
    }
    if ($attachments.Count -gt 0)
    {
        $sendMailMessageParameters.Add("Attachments", $attachments )
    }
    $body = ""
    $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbsp$MailMessage<br><br>Thanks,<br>Automation Team<br></p>"
    $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
             
    $sendMailMessageParameters.Add("Body", $body)
    try
    {
        Send-MailMessage @sendMailMessageParameters
    }
    catch
    {
        $comment = $_ | Format-List -Force 
        Write-Log -Path $Activitylog -Entry  "Failed to send the mail" -Type Error -ShowOnConsole
        Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
    }
}

function Invoke-PlinkCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$IpAddress,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        [Parameter(Mandatory = $true)]
        [String]$PlinkPath,
        [Parameter(Mandatory = $true)]
        [String]$command,
        [Parameter(Mandatory = $false)]
        [Switch]$FirstTime

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $Result = ""

        $decrypted = $Credential.GetNetworkCredential().password
        $plink = Join-Path $PlinkPath -ChildPath "plink.exe"
        if ($FirstTime -eq $true)
        {
            $result = Write-Output "y" | &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1 | Out-String
        }
        else
        {
            $result = &$plink -ssh $IpAddress -l $Credential.UserName -pw $decrypted $command 2>&1 | Out-String
        }

        $result | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $result
    }
    catch
    {
        Write-Output $null
    }
}

Function New-PoshSession
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$IpAddress,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )
    try
    {
        $SessionId = New-SSHSession -ComputerName $IpAddress -Credential $Credential -AcceptKey:$true
        write-output $SessionId
    }
    catch
    {
        Write-Output $null
    }

}

function Invoke-BackupReportingCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SshSessionId,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        [Parameter(Mandatory = $true)]
        [String]$command,
        [Switch] $UseSSHStream

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $result = ""
        $result = Invoke-SSHCommand -Command $command -SessionId $SshSessionId -EnsureConnection -TimeOut 300 
        $output = $result.output
        if ($result.error)
        {
         "Error Occured"  | Out-File -FilePath $logFile -Append  
         '============================' |  Out-File -FilePath $logFile -Append  
         $result.error | Out-File -FilePath $logFile -Append  
         '============================' |  Out-File -FilePath $logFile -Append  
        }
        $output | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $output
    }
    catch
    {
        Write-Output $null
    }
}

function Invoke-BackupReportingCommand_Windows
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ComputerName,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        #[Parameter(Mandatory = $true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [String]$command

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $Result = ""

        if($config.Backupserver -ne "LocalHost")
        {
            $Result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {Invoke-Expression $using:Command}
        }
        else
        {
            $Result = Invoke-Expression $Command
        }
        $result | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $result
    }
    catch
    {
        $comment = $_ | fl | Out-String
        Write-Log -Path $Activitylog -Type Exception -Entry $comment -ShowOnConsole
        Write-Output $null
    }
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

Function Get-OperatingSystemType
{
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] 
        $computername 
    )
    try
    {
        $ResponseTime = Test-Connection -ComputerName $computername -Count 1 -ErrorAction Stop | Select-Object -ExpandProperty ResponseTimeToLive
        if($ResponseTime )
        {

            if(($ResponseTime -ge 110) -and ($ResponseTime -le 255))
            {
                $operatingsystemtype = "Windows"
            }
            else
            {
                $operatingsystemtype = "NonWindows"
            }
        }
        else
        {
            $operatingsystemtype = $null
        }
    }

    Catch
    {
        $operatingsystemtype = $null
    }
    Write-Output $operatingsystemtype
}

Function Check-Access
{
    [cmdletbinding()]
    Param(
    $Key
    )
    if(Test-Path "key.exe")
    {
        try
        {
            $Scriptarg = "DXC_$((Get-Date).ToString("yyyyMMdd"))"
            $outkey = .\Key.exe $Scriptarg
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Unable to Run Key File." -Type warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please run again or Please Unblock the file." -Type warning -ShowOnConsole
            exit
        }
        if($outkey)
        {
            $Split = $outkey -split ","
            $KeyDomain = $Split[0].Trim()
            $KeyYear   = $Split[1].Trim()
            $KeyMonth  = $Split[2].Trim()
            $Alloweddate = ([datetime]"$keyyear, $KeyMonth").ToString("yyyyMM")
            $Scriptdate = (Get-Date).ToString("yyyyMM")
            $Whoami = systeminfo | findstr /B "Domain"
            $ScriptDomain = ($Whoami -split ":")[1].Trim()
            if($KeyDomain -and $KeyYear -and $KeyMonth -and $Alloweddate -and $ScriptDomain)
            {
                if($ScriptDomain -eq $KeyDomain)
                {
                    if($Scriptdate -le $Alloweddate)
                    {
                        Write-Log -Path $Activitylog -Entry "Permission granted, Running the script" -Type Information -ShowOnConsole
                    }
                    else
                    {
                        Write-Log -Path $Activitylog -Entry "Your key got Expired, please contact Automation team!" -Type warning -ShowOnConsole
                        exit
                    }
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "You do not have permission to run the script" -Type warning -ShowOnConsole
                    Write-Log -Path $Activitylog -Entry "Please contact Automation team for the key!" -Type warning -ShowOnConsole
                    exit
                }
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "Something went wrong, please try again!" -Type warning -ShowOnConsole
                exit
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "Failed to Run Key File." -Type warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please try again." -Type warning -ShowOnConsole
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Unable to find Key File." -Type warning -ShowOnConsole
        exit
    }
}

#######  DP Functions  #######
Function Get-ListOfSessions
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    #omnirpt -report list_sessions -timeframe $previous 18:00 $current 17:59 -tab -no_copylist -no_verificationlist -no_conslist
    $CellManager = (($InputObject | Select-String -Pattern "Cell Manager") -split ": ")[1].trim()
    $ListOfSessions_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
    $ListOfSessions_Result = $ListOfSessions_converted|select 'Session Type','Specification','Session ID'
    $ListOfSessions_Result,$CellManager
}

Function Get-SessionList
{
    [CmdletBinding()]
    Param(
    $InputObject, 
    $CellManager,
    $SessionType,
    $Specification,
    $SessionId
    )
    $InputObject = $InputObject -replace ","
    $SessionList_converted = $InputObject.replace("`t",",")| Convertfrom-Csv -Header 'Object Type','Client','Mountpoint','Description','Object Name','Status',Mode,'Start Time','Start Time_t','End Time','End Time_t','Duration (hh:mm)','Size (kB)','Files','Performance (MB/min)','Protection','Errors',Warnings,Device
    $SessionList_Output = $SessionList_converted | select 'Object Type','Client','Mountpoint','Status',Mode,'Start Time','End Time','Duration (hh:mm)','Size (kB)','Performance (MB/min)','Protection',Device
    $SessionList_Result = @()
    foreach($line in $SessionList_Output)
    {
        $SessionList_Result   += [PSCustomObject] @{
        "Account"              = $config.account
        "BackupApplication"    = $config.BackupApplication
        "BackupServer"         = $BackupDevice
        "Date"                 = $ReportEndDate
        "Cell Manager"         = $CellManager
        "Session Type"         = $SessionType
        "Specification"        = $Specification
        "SessionId"            = $SessionId
        'Object Type'          = $line.'Object Type'
        'Client'               = $line.Client
        'Mountpoint'           = $line.Mountpoint
        'Status'               = $line.Status
        "Mode"                 = $line.Mode
        'Start Time'           = $line.'Start Time'
        'End Time'             = $line.'End Time'
        'Duration (hh:mm)'     = $line.'Duration (hh:mm)'
        'Size (kB)'            = $line.'Size (kB)'
        'Performance (MB/min)' = $line.'Performance (MB/min)'
        'Protection'           = $line.Protection
        "Device"               = $line.Device
        }
    }
    $SessionList_Result
}

Function Get-BSRReport
{
    [CmdletBinding()]
    Param(
    $InputObject = $SessionList
    )
    $BSRReport = @()
    $AllGroups = $InputObject | Where-Object {$_."Session Type" -eq "Backup" -and $_."Object Type" -ne "BAR"} | Group-Object 'session type',Specification,Client,mode
    foreach($Group in $AllGroups)
    {
        $ClientGroups = $Group.group | Group-Object Mountpoint
        $MountPoints = @()
        foreach($ClientGroup in $ClientGroups)
        {
            $CompletedMountPointsCount = @($ClientGroup.Group | where{$_.status -eq "Completed"}).count
            if($CompletedMountPointsCount -gt 0)
            {
                $MountPoints +=($ClientGroup.Group | where{$_.status -eq "Completed"})[0]
            }
            else
            {
                $MountPoints +=($ClientGroup.Group | where{$_.status -ne "Completed"})[0]
            }

        }
        $TotalClientMountPoints = @($MountPoints).Count
        $CompletedClientMountPoints = @($MountPoints| where{$_.status -eq "Completed"}).count
        $Percentage = [math]::Round(($CompletedClientMountPoints / $TotalClientMountPoints)*100)
        $Size = [math]::Round(((($MountPoints | Measure-Object "Size (kB)" -Sum).Sum) / 1mb),2)
    
        $Duration = $null
        Foreach($MountPoint in $MountPoints)
        {
            $DurationSplit = $MountPoint."Duration (hh:mm)" -split ":"
            $Duration += [int](([int]($DurationSplit[0]) * 60) + [int]($DurationSplit[1]))
        }

        $BSRReport         += [pscustomobject] @{
        "Date"              = $MountPoints[0].Date
        "Account"           = $MountPoints[0].Account
        "BkpApp"            = $MountPoints[0].BackupApplication
        "BackupServer"      = $MountPoints[0].BackupServer
        "Clientname"        = $MountPoints[0].client
        "Specification"     = $MountPoints[0].Specification
        "Object Type"       = $MountPoints[0].'Object Type'
        "Mode"              = $MountPoints[0].Mode
        "BSR Object"        = "# $CompletedClientMountPoints / $TotalClientMountPoints"
        "Percentage"        = "$Percentage"
        "Size (GB)"         = $Size
        "Duration (min)"    = $Duration
        }
    }
    $AllGroups = $InputObject | Where-Object {$_."Session Type" -eq "Backup" -and $_."Object Type" -eq "BAR"} | Group-Object 'session type',Specification,Client,mode
    foreach($Group in $AllGroups)
    {
        $ClientGroups = $Group.group | Group-Object SessionId
        $MountPoints = @()
        $AllCompleted = 0 
        foreach($ClientGroup in $ClientGroups)
        {
            $CompletedCount = @(($ClientGroup.group).status | where{$_ -eq "Completed"}).Count
            $ToatalCount = @(($ClientGroup.group).status).Count
            if($CompletedCount -eq $ToatalCount)
            {
                #$MountPoints = $ClientGroup.Group
                $ALLsessionid = $ClientGroup.Group | select sessionid | select -First 1
                #break
            }
            elseif($CompletedCount -gt 0)
            {
                $sessionid = $ClientGroup.Group | select sessionid | select -First 1
            }
            else
            {
                $MountPoints = $ClientGroup.Group
            }
        }
        if($sessionid)
        {
            $MountPoints = $ClientGroups.Group | where{$_.sessionid -eq $sessionid.sessionid}
        }
        if($ALLsessionid)
        {
            $MountPoints = $ClientGroups.Group | where{$_.sessionid -eq $Allsessionid.sessionid}
        }
        $TotalClientMountPoints = @($MountPoints).Count
        $CompletedClientMountPoints = @($MountPoints| where{$_.status -eq "Completed"}).count
        $Percentage = [math]::Round(($CompletedClientMountPoints / $TotalClientMountPoints)*100)
        $Size = [math]::Round(((($MountPoints | Measure-Object "Size (kB)" -Sum).Sum) / 1mb),2)
    
        $Duration = $null
        Foreach($MountPoint in $MountPoints)
        {
            $DurationSplit = $MountPoint."Duration (hh:mm)" -split ":"
            $Duration += [int](([int]($DurationSplit[0]) * 60) + [int]($DurationSplit[1]))
        }

        $BSRReport         += [pscustomobject] @{
        "Date"              = $MountPoints[0].Date
        "Account"           = $MountPoints[0].Account
        "BkpApp"            = $MountPoints[0].BackupApplication
        "BackupServer"      = $MountPoints[0].BackupServer
        "Clientname"        = $MountPoints[0].client
        "Specification"     = $MountPoints[0].Specification
        "Object Type"       = $MountPoints[0].'Object Type'
        "Mode"              = $MountPoints[0].Mode
        "BSR Object"        = "# $CompletedClientMountPoints / $TotalClientMountPoints"
        "Percentage"        = "$Percentage"
        "Size (GB)"         = $Size
        "Duration (min)"    = $Duration
        }
        
    }
    $BSRReport
}

Function Get-DailySummary
{    
    [CmdletBinding()]
    Param(
    $InputObject
    )

    $Summary = @()
    $UnqClientCount = ($InputObject | Select-Object Clientname -Unique).count
    $UnqJobCount    = ($InputObject | Select-Object Specification -Unique).count
    $Summary       = [Pscustomobject]@{
    "Date"         = $InputObject[0].Date
    "YearMonth"    = ([datetime]($InputObject[0].Date)).ToString("yyyy-MM")
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
    $Summary."Successful Object Count" = $SuccessfulObjCount
    $Summary."Total Object Count"      = $TotalObjCount
    $Summary."BSR %"                   = $BSRPercentage
    $Summary."Size (GB)"               = [math]::Round($SumOfSize,2)
    $Summary
}

Function Get-UpdatedDailySummary
{
    [CmdletBinding()]
    Param(
    $OldData
    )
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

Function Get-MonthlySummary
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    $YearMonths = ($InputObject | select -Property "YearMonth" -Unique).yearmonth
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
        "Size (GB)"      = [math]::Round($Size,2)
        }
    }
    $MonthlySummary
}

Function Get-UpdatedMonthlySummary
{
    [CmdletBinding()]
    Param(
    $OldMonthlySummaryData
    )
    if($OldMonthlySummaryData)
    {
        $NewMonthlySummaryDataFinal = @()
        foreach($NewMonthlySummaryDataline in $NewMonthlySummaryData)
        {
            $Found = $OldMonthlySummaryData | where{$_.YearMonth -eq $NewMonthlySummaryDataline.YearMonth}
            if($Found)
            {
                $Found."BSR Object" = ($NewMonthlySummaryData | where{$_.YearMonth -eq $NewMonthlySummaryDataline.YearMonth})."BSR Object"
                $Found."Percentage" = ($NewMonthlySummaryData | where{$_.YearMonth -eq $NewMonthlySummaryDataline.YearMonth})."Percentage"
                $Found."Size (GB)"  = ($NewMonthlySummaryData | where{$_.YearMonth -eq $NewMonthlySummaryDataline.YearMonth})."Size (GB)"
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


###############################################


$config = Get-Config -ConfigFile $ConfigFile
$culture = [CultureInfo]'en-us'
$Reportdate = ([system.datetime]::UtcNow).ToString("dd-MMM-yy")
$date = ([system.datetime]::UtcNow).ToString("ddMMMyy")
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

Check-Access

if($config)
{
    $BkpDevice = $config.BackupServer
    if($BkpDevice -eq "LocalHost")
    {
        $BackupDevice = $env:computername
    }
    else
    {
        $BackupDevice = $BkpDevice
    }

    if($BkpDevice -ne "LocalHost")
    {
        Write-Log -Path $Activitylog -Entry "Checking For Credential!" -Type Information -ShowOnConsole
        $CredentialPath = $config.CredentialFile
        if (!(Test-Path -Path $CredentialPath) )
        {
            $Credential = Get-Credential -Message "Enter Credentials"
            $Credential | Export-Clixml $CredentialPath -Force
        }
        try
        {
            $Credential = Import-Clixml $CredentialPath
        }
        catch
        {
            $comment = $_ | Format-List -Force 
            Write-Log -Path $Activitylog -Entry  "Invalid Credential File!" -Type Error -ShowOnConsole
            Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
            Write-Log -Path $Activitylog -Entry  "Recreate Credential File!" -Type Information -ShowOnConsole
            if ($config.SendEmail -eq "yes")
            {  
                Send-Mail -MailMessage "Invalid Credential File!."
            }        
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Running Locally" -Type Information -ShowOnConsole
    }


    Write-Log -Path $Activitylog -Entry "Fethching details from $BackupDevice" -Type Information -ShowOnConsole
    $OsType = $config.Ostype #Get-OperatingSystemType -computername $BackupDevice
    Write-Log -Path $Activitylog -Entry "Operating System : $ostype" -Type Information -ShowOnConsole

    #####################################################
    $SessionList = @()
    if($Config.EndDate)
    {
        try
        {
            $ConfigEndDate = [datetime]$Config.EndDate
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Please provide EndDate Parameter in config.json file in yyyy-MM-dd format" -Type Warning -ShowOnConsole
            exit
        }
        if($Config.Reportdays)
        {
            $ReportDays = $config.ReportDays
        }
        else
        {
            $ReportDays = 4
        }
    }
    elseif($Config.ReportDays)
    {
        $ReportDays = $Config.ReportDays
    }
    else
    {
        $ReportDays = 4
    }
    ####################################################
    $Attachment = @()
    if($OsType)
    {
        if(!(Test-Path 'OBJ_Reports'))
        {
            try
            {
                New-Item -ItemType directory "OBJ_Reports" -ErrorAction Stop | Out-Null
            }
            catch
            {
                Write-Log -Path $Activitylog -Entry "Unable to create OBJ_Reports Folder" -Type Error -ShowOnConsole
            }
        }
        if(!(Test-Path 'BSR_Reports'))
        {
            try
            {
                New-Item -ItemType directory "BSR_Reports" -ErrorAction Stop | Out-Null
            }
            catch
            {
                Write-Log -Path $Activitylog -Entry "Unable to create BSR_Reports Folder" -Type Error -ShowOnConsole
            }
        }
        if(!((Test-Path 'OBJ_Reports') -and (Test-Path 'BSR_Reports')))
        {
            Write-Log -Path $Activitylog -Entry "Failed to Create BSR_Reports and OBJ_Reports folders in $($config.Reportpath)" -Type Warning -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "Please Create BSR_Reports and OBJ_Reports folders in $($config.Reportpath)" -Type Warning -ShowOnConsole
            exit
        }
        $DailySummaryReportName = $config.Reportpath   + "\" + "BSR_Reports"+ "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "DailySummaryReport" +  ".csv"
        $MonthlySummaryReportName = $config.Reportpath   + "\" + "BSR_Reports"+ "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "MonthlySummaryReport" +  ".csv"
        if($OsType -eq "Windows")
        {
            $DpVersionCommand = $config.DPVersionCommand_Windows
            $DpVersionCommandOutput = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $DpVersionCommand -logFile $Activitylog
            <#
            if($DpVersionCommandOutput.StartsWith("HPE"))
            {
                [int]$DPVersion = $DpVersionCommandOutput.Substring(21,2)
            }
            else
            {
                [int]$DPVersion = $DpVersionCommandOutput.Substring(29,2)
            }
            #>
            [int]$DPVersion = ((($DpVersionCommandOutput -split "omnicheck")[0] -split "\s" | where{$_}).getvalue($split.count-1)).split(".")[1]
            if($ConfigEndDate)
            {
                $ServerDate = $ConfigEndDate
            }
            else
            {
                $DateCommand = "get-date"
                $ServerDate = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $DateCommand -logFile $Activitylog
            }

            $NewData = @()
            for($i=1;$i -le $ReportDays ;$i++)
            {
                $SessionList = @()
                $StartDate = ($ServerDate).AddDays(-$i).ToString("yy/MM/dd")
                $EndDate = ($ServerDate).AddDays(-($i-1)).ToString("yy/MM/dd")
                $ReportEndDate = (($ServerDate).AddDays(-($i-1)).ToString("yyyy-MM-dd")) -replace "/","-"
                $DPReportName  = $config.Reportpath  + "\" + "OBJ_Reports" + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "OBJREP" + "_" + "$ReportEndDate" + ".csv"
                $BSRReportName = $config.Reportpath  + "\" + "BSR_Reports" + "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "BSR-Size" + "_" + "$ReportEndDate" + ".csv"
                #$Attachment += $DPReportName
                #$attachment += $BSRReportName
                $SessionDetailsCommand = $config.SessionDetailsCommand_Windows -replace "StartDate",$StartDate -replace "EndDate",$EndDate

                $SessionDetailsOutput = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $SessionDetailsCommand -logFile $Activitylog
                if(!("# No sessions matching the search criteria found." -in $SessionDetailsOutput))
                {
                    $ListOfSessions,$CellManager = @(Get-ListOfSessions -InputObject $SessionDetailsOutput)
    
                    foreach($session in $ListOfSessions)
                    {
                        $SessionId = $session.'session id'
                        $SessionList_Command = $config.SessionObjectsCommand_Windows -replace "SessionID", $SessionId
                        $SessionList_CommandOutput = Invoke-BackupReportingCommand_Windows -ComputerName $BackupDevice -Credential $Credential -Command $SessionList_Command -logFile $Activitylog
                        if(!("# No objects found." -in $SessionList_CommandOutput))
                        {
                            $SessionList += Get-SessionList -InputObject $SessionList_CommandOutput -CellManager $CellManager -SessionType $session.'Session Type' -Specification $session.Specification -SessionId $SessionId
                        }
                    }                
                    if($DPVersion -le 7)
                    {
                        foreach($line in $SessionList)
                        {
                            if($line.Description -contains "VEagent")
                            {
                                $Client = ($line.Description -split "%")[4].Remove(0,1)
                                $line.Client = $Client
                            }
                        }
                    }
                    $SessionList | Export-Csv -Path $DPReportName -NoTypeInformation
                    $SessionTypeisBackup = $SessionList | Where-Object {$_."Session Type" -eq "Backup"}
                    if($SessionTypeisBackup)
                    {
                        $BSRReport = Get-BSRReport -InputObject $SessionList
                        $BSRReport | Export-Csv -Path $BSRReportName -NoTypeInformation
                        $NewData += Get-DailySummary -InputObject $BSRReport
                        if ($config.SendEmail -eq "yes")
                        {  
                            $attachment = @()
                            $attachment = $BSRReportName
                            Send-Mail -attachments $attachment -MailMessage "Please Check DataProtector Reports."
                        }
                    }
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "No Sessions available from $StartDate 18:00 to $EndDate 17:59" -Type Warning -ShowOnConsole
                }    
            }
        }
        else
        {
            try
            {
                Import-Module ".\Posh-SSH\Posh-SSH.psd1"
            }
            catch
            {
                Write-Log -Path $Activitylog -Entry "Failed to import Posh-SSH module" -Type warning -ShowOnConsole
                exit
            }
            Get-SSHTrustedHost | where{$_.sshhost -eq "$BackupDevice"}| Remove-SSHTrustedHost
            $sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential
            if($sshsessionId.connected -eq "True")
            {
                $DpVersionCommand = $config.DPVersionCommand_NonWindows
                $DpVersionCommandOutput = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $DpVersionCommand
                if($DpVersionCommandOutput.StartsWith("HPE"))
                {
                    [int]$DPVersion = $DpVersionCommandOutput.Substring(21,2)
                }
                else
                {
                    [int]$DPVersion = $DpVersionCommandOutput.Substring(29,2)
                }

                if($ConfigEndDate)
                {
                    $ServerDate = $ConfigEndDate
                }
                else
                {
                    $command = "date +'%D %T'"
                    $CurrentBackupDeviceTimeFromUnix = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
                    $ServerDate = [datetime]$CurrentBackupDeviceTimeFromUnix
                }
                $NewData = @()
                for($i=1;$i -le $ReportDays ;$i++)
                {
                    $SessionList = @()
                    $StartDate = ($ServerDate).AddDays(-$i).ToString("yy/MM/dd")
                    $EndDate = ($ServerDate).AddDays(-($i-1)).ToString("yy/MM/dd")
                    $ReportEndDate = (($ServerDate).AddDays(-($i-1)).ToString("yyyy-MM-dd")) -replace "/","-"
                    $DPReportName = $config.Reportpath   + "\" + "OBJ_Reports"+ "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "OBJREP" + "_" + "$ReportEndDate" + ".csv"
                    $BSRReportName = $config.Reportpath  + "\" + "BSR_Reports"+ "\" +  $config.BackupApplication + "_" + $config.Account + "_" + $Backupdevice + "_" + "BSR-Size" + "_" + "$ReportEndDate" + ".csv"
                    $attachment += $BSRReportName
                    $SessionDetailsCommand = $config.SessionDetailsCommand_NonWindows -replace "StartDate",$StartDate -replace "EndDate",$EndDate

                    $SessionDetailsOutput = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $SessionDetailsCommand
                    if(!("# No sessions matching the search criteria found." -in $SessionDetailsOutput))
                    {
                        $ListOfSessions,$CellManager = @(Get-ListOfSessions -InputObject $SessionDetailsOutput)
    
                        foreach($session in $ListOfSessions)
                        {
                            $SessionId = $session.'session id'
                            $SessionList_Command = $config.SessionObjectsCommand_NonWindows -replace "SessionID", $SessionId
                            $SessionList_CommandOutput = Invoke-BackupReportingCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $SessionList_Command
                            if(!("# No objects found." -in $SessionList_CommandOutput))
                            {
                                $SessionList += Get-SessionList -InputObject $SessionList_CommandOutput -CellManager $CellManager -SessionType $session.'Session Type' -Specification $session.Specification -SessionId $SessionId
                            }
                        }
                    
                        if($DPVersion -le 7)
                        {
                            foreach($line in $SessionList)
                            {
                                if($line.Description -contains "VEagent")
                                {
                                    $Client = ($line.Description -split "%")[4].Remove(0,1)
                                    $line.Client = $Client
                                }
                            }
                        }
                        $SessionList | Export-Csv -Path $DPReportName -NoTypeInformation
                        $SessionTypeisBackup = $SessionList | Where-Object {$_."Session Type" -eq "Backup"}
                        if($SessionTypeisBackup)
                        {
                            $BSRReport = Get-BSRReport -InputObject $SessionList
                            $BSRReport | Export-Csv -Path $BSRReportName -NoTypeInformation
                            $NewData += Get-DailySummary -InputObject $BSRReport

                            $CurrentYearMonth = (Get-Date).ToString("yyyy_MM")

                            if ($config.SendEmail -eq "yes")
                            {  
                                $attachment = @()
                                $attachment = $BSRReportName
                                Send-Mail -attachments $attachment -MailMessage "Please Check DataProtector Reports."
                            }
                        }     
                        #else
                        #{
                        #    Write-Log -Path $Activitylog -Entry "No Session Type of Backup.." -Type Information -ShowOnConsole
                        #}
                    }
                    else
                    {
                        Write-Log -Path $Activitylog -Entry "No Sessions available from $StartDate 18:00 to $EndDate 17:59" -Type Warning -ShowOnConsole
                    }    
                }
                Remove-SSHSession -SessionId $sshsessionId.sessionId
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "Failed to connect to $BackupDevice" -Type Error -ShowOnConsole
            }
        }
        if($NewData)
        {
            if(Test-Path $DailySummaryReportName)
            {
                $Old_Data = Import-Csv -Path $DailySummaryReportName
            }
            $NewFinalData = Get-UpdatedDailySummary -OldData $Old_Data
            $NewFinalData | Export-Csv $DailySummaryReportName -NoTypeInformation
            $NewMonthlySummaryData = Get-MonthlySummary -InputObject $NewFinalData
            if(Test-Path $MonthlySummaryReportName)
            {
                $Old_MonthlySummaryData = Import-Csv -Path $MonthlySummaryReportName
            }
            $NewMonthlySummaryDataFinal = Get-UpdatedMonthlySummary -OldMonthlySummaryData $Old_MonthlySummaryData
            $NewMonthlySummaryDataFinal | Export-Csv $MonthlySummaryReportName -NoTypeInformation
            if ($config.SendEmail -eq "yes")
            {  
                $attachment = @()
                $attachment = $MonthlySummaryReportName
                Send-Mail -attachments $attachment -MailMessage "Please Check DataProtector Reports."
            }
        }
        ######################################
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Operating System : Failed" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole

#Changes in this version
# 1. Check-Access Function added.
# 2. DP Version bug fixed.
# 3. Get-BSRReport updated.
# 4. Added Ojecttype in Get-BSRReport.
# 5. [math]::Round( for $percentage.
# 6. @ for MountPoint count.