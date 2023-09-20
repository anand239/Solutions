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

function Invoke-DPErrorCommand
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

Function Get-DiskSpaceError
{
    [CmdletBinding()]
    Param(
    $Inputobject
    )
    $data = $Inputobject
        $Garbage = ($data | Select-String "Backup Statistics:").LineNumber
    $out = @()
    for($i=0; $i -lt $Garbage-1; $i++)
    {
        $out += $data[$i]
    }
    $Minor_Warning = @()
    $Replace = (($out) -replace '^$','#')
    $pattern = '#'*1  
    $content =$Replace | Out-String
    $Logs = $content.Split($pattern,[System.StringSplitOptions]::RemoveEmptyEntries)
    foreach($log in $Logs)
    {
        if($Log -like "*Minor*" -or $Log -like "*Warning*")
        {
            $Minor_Warning += $Log
        }
    }
    $clients=@()
    $pattern = '(?<=\").+?(?=\")'
    foreach($line in $Minor_Warning)
    {
        $client_data = [regex]::Matches($line,$pattern).value
        $split = ($client_data -split "\s" | ?{$_})[0].trim()
        $clients += [pscustomobject] @{
        "ClientName" = $split
        }
    }

    $Groups = $clients | Group-Object -Property Clientname
    $UniqueClients = @()
    foreach($group in $Groups)
    {
        $UniqueClients += $group.Group | select -First 1
    }

    $Finaldata = @()

    foreach($client in $UniqueClients)
    {
        $finaldata += $Minor_Warning | Select-String -Pattern "$($client.clientname)" | select -First 1
    }
    $Finaldata

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
        exit
    }
    Import-Module ".\Posh-SSH\Posh-SSH.psd1"
    $Servers = $config.BackupServer.Split(";")
    if($Servers.Count -gt 1)
    {
        $BackupServers = @()
        for($i=0; $i -lt $Servers.count; $i++)
        {
            $BackupServers += [pscustomobject] @{
            "BackupServer"  = $Servers[$i]
            "Index"         = $i 
            }
        }
        Write-output $BackupServers|Out-String
        $Index = Read-Host "Enter the Index of BackupServer "
        $BackupDevice = ($BackupServers | where{$_.index -eq $Index}).BackupServer
    }
    else
    {
        $BackupDevice = $config.BackupServer
    }
    if($BackupDevice)
    {
        $Sshsession = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential
        if($Sshsession.connected -eq "True")
        {
            $SessionId = Read-Host "Enter the Session ID"
            $Failed_SessionLogCommand = "omnidb -session $SessionId -report"

            $Failed_SessionLogCommandOutput = Invoke-DPErrorCommand -SshSessionId $Sshsession.sessionid -logFile $Activitylog -command $Failed_SessionLogCommand
            if($Failed_SessionLogCommandOutput)
            {
                $Failed_SessionLog = Get-DiskSpaceError -Inputobject $Failed_SessionLogCommandOutput
            }
            Remove-SSHSession $Sshsession.sessionid
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "Failed to Connect to Server" -Type Error -ShowOnConsole
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Not Selected any BackupServer" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole






