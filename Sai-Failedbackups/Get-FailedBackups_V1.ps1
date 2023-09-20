<#
.SYNOPSIS
  Get-FailedBackups.ps1

.DESCRIPTION
  Checks the Error logs for the failed backups and generate a report
	
.INPUTS
  Configfile - config.json
   
.NOTES
  Script:         Get-FailedBackups.ps1
  Author:         Chintalapudi Anand Vardhan  
  Requirements:   Powershell v3.0
  Creation Date:  28-Feb-2022
  Modified Date:  28-Feb-2022 
  Remarks      :  

  .History:
        Version Date                       Author                    Description        
        1.0     28-Feb-2022      Chintalapudi Anand Vardhan        Initial Release

.EXAMPLE
  Script Usage 

  .\Get-FailedBackups.ps1 -ConfigFile .\config.json
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String]$ConfigFile = "config.json"
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

Function Invoke-DPCommandWindows
{
    [CmdletBinding()]
    param(
        #[Parameter(Mandatory = $true)]
        $ComputerName,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        #[Parameter(Mandatory = $true)]
        #[PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [String]$command

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $Result = ""
        $Result = Invoke-Expression $Command
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

Function Get-ListOfSessions
{
    [CmdletBinding()]
    Param(
    $InputObject
    )
    $ListOfSessions_converted = $InputObject -replace "`t","," | Convertfrom-Csv -Header 'Session Type','Specification','Status','Mode','Start Time','Start Time_t','End Time','End Time_t','Queuing', 'Duration','GB Written','Media','Errors','Warnings','Pending DA','Running DA','Failed DA','Completed DA','Object','Files','Success','Session Owner','Session ID'
    $ListOfSessions_Result = $ListOfSessions_converted
    $ListOfSessions_Result
}


$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

if($config)
{
    $Servers =  $config.BackupServer.Split(";") #(gc ".\server.txt").Split(";")
    $FinalReport = @()
    if($Servers)
    {
        foreach($Server in $Servers)
        {
            $StartDate = Read-Host "Enter start time in yy/mm/dd HH:MM format"
            $EndDate = Read-Host "Enter End time in yy/mm/dd HH:MM format"
            $Command = "omnirpt -report list_sessions -timeframe StartDate EndDate -tab -server servername"
            $ListofSessionsCommand = $command -replace "Servername",$server -replace "Startdate",$StartDate -replace "Enddate",$EndDate
            $ListofSessionsOutput = Invoke-DPCommandWindows -command $ListofSessionsCommand -logFile $Activitylog
            $ListOfSessions = @(Get-ListOfSessions -InputObject $ListofSessionsOutput)
            $FailedSessions = $ListOfSessions | where{(($_.status -eq "Failed") -or ($_.status -like "*Failures*"))}
            if($FailedSessions)
            {
                foreach($failedSession in $FailedSessions)
                {
                    $Failed_SessionId = $failedSession.'session id'
                    $command2 = "omnidb -session SessionId -report"
                    $Failed_SessionLogCommand = $command2 -replace "Sessionid","$Failed_SessionId"
                    $Failed_SessionLog = Invoke-DPCommandWindows -command $Failed_SessionLogCommand -logFile $Activitylog
                    if($Failed_SessionLog)
                    {
                        $Garbage = ($Failed_SessionLog | Select-String "Backup Statistics:").LineNumber
                        $out = @()
                        for($i=0; $i -lt $Garbage-1; $i++)
                        {
                            $out += $Failed_SessionLog[$i]
                        }
                        $Critical_Major = @()
                        $Replace = (($out) -replace '^$','#')
                        $pattern = '#'*1  
                        $content =$Replace | Out-String
                        $Logs = $content.Split($pattern,[System.StringSplitOptions]::RemoveEmptyEntries)
                        foreach($log in $Logs)
                        {
                            if($Log -like "*Major*" -or $Log -like "*Critical*")
                            {
                                $Critical_Major += $Log
                            }
                        }
                        if($Critical_Major)
                        {
                            $Error_Log = $Critical_Major.Split([Environment]::NewLine)|where{$_} |select -Skip 1| select -First 5
                            $FinalReport    += [pscustomobject] @{
                            "BackupServer"   = $Server
                            "Specification"  = $failedSession.Specification
                            "SessionId"      = $Failed_SessionId
                            "Errorlog"       = "$Error_Log"
                            }
                        }
                    }
                    else
                    {
                        $FinalReport    += [pscustomobject] @{
                        "BackupServer"   = $Server
                        "Specification"  = $failedSession.Specification
                        "SessionId"      = $Failed_SessionId
                        "Errorlog"       = "Unable to fetch error logs"
                        }
                        #Write-Log -Path $Activitylog -Entry "Unable to fetch error logs for $Failed_SessionId"
                    }
                }
            }
            else
            {
                $FinalReport    += [pscustomobject] @{
                "BackupServer"   = $Server
                "Specification"  = "No Failed Sessions"
                "SessionId"      = "No Failed Sessions"
                "Errorlog"       = "No Failed Sessions"
                }
                #Write-Log -Path $Activitylog -Entry "No failed sessions for $server"
            }
        }
        $FinalReport |Export-Csv ".\Finalreport.csv" -NoTypeInformation
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Unable to fetch servers" -Type warning -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole


