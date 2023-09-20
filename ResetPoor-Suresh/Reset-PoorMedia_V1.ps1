<#
.SYNOPSIS
  Reset-PoorMedia.ps1

.DESCRIPTION
  Starts the Opsware Service for the given servers.
	
.INPUTS
  Configfile - config.json
  InputFile.txt
   
.NOTES
  Script:         Reset-PoorMedia.ps1
  Author:         Chintalapudi Anand Vardhan  
  Requirements:   Powershell v3.0
  Creation Date:  06-Jan-2022
  Modified Date:  06-Jan-2022 
  Remarks      :  

  .History:
        Version Date                       Author                    Description        
        1.0     06-Jan-2022      Chintalapudi Anand Vardhan        Initial Release

.EXAMPLE
  Script Usage 

  .\Reset-PoorMedia.ps1 -ConfigFile .\config.json
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

function Invoke-DPCommandNonWindows
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

function Invoke-DPCommandWindows
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

$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole

if($config)
{
    $Pools = Get-Content $config.InputPoolFile
    $PoorMediaReport = @()
    foreach($Pool in $Pools)
    {
        $ListPoolCommand = $config.Command1 -replace "PoolName","$Pool"
        $PoolsCommandOutput = Invoke-DPCommandWindows "$ListPoolCommand"
        $PoorPools = $PoolsCommandOutput | Select-String "Poor" 
        if($PoorPools)
        {
            $PoorLabel = @()
            foreach($PoorPool in $PoorPools)
            {
                $PoorLabelSplit = $PoorPool -split "\s" | where{$_}
                if($PoorLabelSplit.count -eq 4)
                {
                    $PoorLabel   = $PoorLabelSplit[1]
                    $PoorLabels += $PoorLabel
                }
                else
                {
                    $PoorLabel   = $PoorLabelSplit[2]
                    $PoorLabels += $PoorLabel
                }
                $ResetCommand = $config.Command2 -replace "Label","$PoorLabel"
                $Reset = Invoke-DPCommandWindows
            }
            $PoolsCommandOutput = Invoke-DPCommandWindows "$ListPoolCommand"
            foreach($PoorLabel in $PoorLabels)
            {
                $PoorPoolAfterReset  = $PoolsCommandOutput | Select-String "$PoorLabel"
                $SplitAfterReset     = $PoorPoolAfterReset -split "\s" | where{$_}

                $PoorMediaReport    += [PsCustomobject] @{
                "Date"               = (Get-Date).ToString("dd MM yy hh:mm")
                "PoolName"           = $Pool
                "Medium Label"       = $PoorLabel
                "Status After Reset" = $SplitAfterReset[0]
                }
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "No Poor Labels availablr for $Pool" -Type Information -ShowOnConsole
            $PoorMediaReport    += [PsCustomobject] @{
            "Date"               = (Get-Date).ToString("dd MM yy hh:mm")
            "PoolName"           = $Pool
            "Medium Label"       = "No Poor Labels"
            "Status After Reset" = "No Poor Labels"
            }
        }
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile!" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole