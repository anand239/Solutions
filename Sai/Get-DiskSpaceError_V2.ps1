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

Function Invoke-BackupErrorCommand
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
        Write-Log -Path $Activitylog -Entry "Getting data from $BackupDevice" -Type Information -ShowOnConsole
        $Failed_SessionLogCommand = "omnidb -session $SessionId -report -server $BackupDevice"
        $SessionId = Read-Host "Enter the Session ID"
        $Failed_SessionLogCommandOutput = Invoke-BackupErrorCommand -ComputerName $BackupDevice -command $Failed_SessionLogCommand -logFile $Activitylog
        if($Failed_SessionLogCommandOutput)
        {
            $Failed_SessionLog = Get-DiskSpaceError -Inputobject $Failed_SessionLogCommandOutput
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






