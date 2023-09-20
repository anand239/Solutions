<#
.SYNOPSIS
  Get-EnvironmentData.ps1

.DESCRIPTION
  Generates the report with the given input files.
	
.INPUTS
  Configfile - config.json
  Cell_info
  Hosts
  SCC_BackupReport
   
.NOTES
  Script:         Get-EnvironmentData.ps1
  Author:         Chintalapudi Anand Vardhan  
  Requirements:   Powershell v3.0
  Creation Date:  04-Feb-2022
  Modified Date:  04-Feb-2022 
  Remarks      :  

  .History:
        Version   UCMS       Date                   Author                   Description        
        1.0       58630   06-Jan-2022      Chintalapudi Anand Vardhan      Initial Release

.EXAMPLE
  Script Usage 

  .\Get-EnvironmentData.ps1 -ConfigFile .\config.json
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

$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

if($config)
{

    if(Test-Path $config.CellInfoFile)
    {
        try
        {
            $RawClients   = Get-Content $config.CellInfoFile | where{$_}
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Failed to get data from $($config.CellInfoFile)" -Type Error -ShowOnConsole
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "CellInfoFile not found" -Type Warning -ShowOnConsole
        exit
    }
    if(Test-Path $config.HostsFile)
    {
        try
        {
            $RawIpAddress = Get-Content $config.HostsFile
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Failed to get data from $($config.HostsFile)" -Type Error -ShowOnConsole
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "HostsFile not found" -Type Warning -ShowOnConsole
        exit
    }
    if(Test-Path $config.BackupReportFile)
    {
        try
        {
            $BackupReport = Import-Csv $config.BackupReportFile
        }
        catch
        {
            Write-Log -Path $Activitylog -Entry "Failed to get data from $($config.BackupReportFile)" -Type Error -ShowOnConsole
            exit
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "BackupReportFile not found" -Type Warning -ShowOnConsole
        exit
    }

    if($RawClients -and $RawIpAddress -and $BackupReport)
    {
        $Clients = @()
        foreach($RawClient in $RawClients)
        {
            $Clients += ((($RawClient -split "\s") | where{$_})[1] -replace "`"").Split(".")[0]
        }

        $FinalReport = @()

        foreach($Client in $Clients)
        {
            $found = $RawIpAddress | Select-String -Pattern "$Client"
            if($found)
            {
                $Available = $found | where{$_ -notlike "*#*"}
                if($Available)
                {
                    $IpAddress = ($Available -split "\s")[0].Trim()
                }
                else
                {
                    $IpAddress = "Commented"
                }
            }
            else
            {
                $IpAddress = "Not Found"
            }
            $FinalReport += [pscustomobject] @{
            "Client Name"   = $Client
            "Ip Address"    = $IpAddress
            }

        }

        $FinalReport | Add-Member NoteProperty "Status" ""

        foreach($Client in $FinalReport)
        {
            $BackupFound = $BackupReport | where{$_.Client -like "*$($client."Client Name")*"}
            if($BackupFound)
            {
                $NotCompleted = $BackupFound | where{$_.Status -ne "Completed"}
                if($NotCompleted)
                {
                    $Client.Status = "Failed"
                }
                else
                {
                    $Client.Status = "Completed"
                }
            }
            else
            {
                $Client.Status = "Not Found"
            }
        }

        $ReportName = $config.ReportPath + "\" + "Report" + ".csv"
        $FinalReport | Export-Csv -Path $ReportName -NoTypeInformation
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "One of the three files is empty" -Type Warning -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile!" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole