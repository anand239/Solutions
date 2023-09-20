<#
.SYNOPSIS
  Get-MountPoint.ps1

.DESCRIPTION
  Operations Performed:
    1. Server MountPoint Details 
    2. Full Backup Dates
    
.INPUTS
  Configfile
  config.json
   
.NOTES
  Script:         Get-MountPoint.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0
  Creation Date:  01/09/2021
  Modified Date:  01/09/2021 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     01/09/2021      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-MountPoint.ps1 -ConfigFile .\config.json
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
        $ShowOnConsole
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
    
    $logEntry | Out-File $Path -Append
}


$config = Get-Config -ConfigFile $ConfigFile
$logfile = "Activity.log"

if($config)
{
    $Servers = Get-Content $config.ServerListFile | where{$_}
    if($servers)
    {
        Write-Log -Path $logfile -Entry "Started" -Type Information -ShowOnConsole
        Write-Log -Path $logfile -Entry "-----------------------------------" -Type Information -ShowOnConsole

        foreach($Server in $Servers)
        {
            '****************************' |  Out-File -FilePath $logFile -Append
            "Running Command : omnirpt -report host -host $server" |  Out-File -FilePath $logFile -Append
            '----------------------------' |  Out-File -FilePath $logFile -Append

            $Result = omnirpt -report host -host $server ###  Running the Command  ####

            $result | Out-File -FilePath $logFile -Append
            '----------------------------'  | Out-File -FilePath $logFile -Append
            '****************************'  | Out-File -FilePath $logFile -Append

            $Report_Path = $config.Reportpath + "\" + $Server+ "_" + "MountPoint" + ".txt"
            $Result | Out-File $Report_Path
        }
    }
    else
    {
        Write-Log -Path $logfile -Entry "ServerList File cannot be Empty" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $logfile -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $logfile -Entry "Completed" -Type Information -ShowOnConsole
