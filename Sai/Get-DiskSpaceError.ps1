<#
.SYNOPSIS
  Get-DiskSpaceError.ps1

.DESCRIPTION
  Checks the Error logs for Disk Space Errors
	
.INPUTS
  Configfile - config.json
   
.NOTES
  Script:         Get-DiskSpaceError.ps1
  Author:         Chintalapudi Anand Vardhan  
  Requirements:   Powershell v3.0
  Creation Date:  15-Dec-2021
  Modified Date:  15-Dec-2021 
  Remarks      :  

  .History:
        Version Date                       Author                    Description        
        1.0     15-Dec-2021      Chintalapudi Anand Vardhan        Initial Release

.EXAMPLE
  Script Usage 

  .\Get-DiskSpaceError.ps1 -ConfigFile .\config.json
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
    if($Minor_Warning)
    {
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
    }
    else
    {
        $Finaldata = "No Disk Space issue"
        $UniqueClients = $null
    }
    $Finaldata,$UniqueClients
}

function Get-MailBody
{
    [CmdletBinding()]
    param(
    $Clients,
    $Logs
    )
    $Body = ""
    $Body = "<br>"
    $Body += "Hi Wintel Team,"
    $Body += "<br>"
    $Body += "Good day,"
    $Body += "<br></br>"
    $Body += "Kindly check the space issue for the below servers,"
    $Body += "<br></br>"
    foreach($Client in $Clients)
    {
    $Body += "<p style=`"color: Blue`">$($Client.Clientname)"
    $Body += "<br>"
    }
    $Body += "<p style=`"color: red`">Error Log:"
    $Body += "<br><br>"
    foreach($log in $logs)
    {
    $Body += $log
    $Body += "<br></br>"
    }
    $Body += "<p style=`"color: Black`">Thanks & Regards,<br>Backup Team</p>"
    $body
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
        $SessionId = Read-Host "Enter the Session ID"
        $Failed_SessionLogCommand = "omnidb -session $SessionId -report -server $BackupDevice"
        $Failed_SessionLogCommandOutput = Invoke-BackupErrorCommand -ComputerName $BackupDevice -command $Failed_SessionLogCommand -logFile $Activitylog
        if($Failed_SessionLogCommandOutput)
        {
            Write-Log -Path $Activitylog -Entry "Processing..." -Type Information -ShowOnConsole
            $Failed_SessionLog,$Clients = Get-DiskSpaceError -Inputobject $Failed_SessionLogCommandOutput
            if("No Disk Space issue" -in $Failed_SessionLog -and $Clients -eq $null)
            {
                Write-Log -Path $Activitylog -Entry "No Diskspace issue" -Type Information -ShowOnConsole
            }
            else
            {
                $Mailclients=""
                foreach($client in $clients.clientname)
                {
                    $split = ($client.split("."))[0]
                    $Mailclients += $split + ","
                }

                $Mailclients = $Mailclients.substring(0,$Mailclients.Length-1)

                $MailBody = Get-MailBody -Clients $Clients -Logs $Failed_SessionLog
                $sendMailMessageParameters = @{
                    To          = $config.mail.To.Split(";")
                    from        = $config.mail.From 
                    Subject     = "$($config.mail.Subject)" -replace "-",$Mailclients     
                    BodyAsHtml  = $true
                    SMTPServer  = $config.mail.smtpServer             
                    ErrorAction = 'Stop'
                    Port        = $config.mail.port
                } 
                if ($config.mail.Cc)
                {
                    $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";"))
                }

                $sendMailMessageParameters.Add("Body", $MailBody)
                try
                {
                    Write-Log -Path $Activitylog -Entry "Sending Email, Please wait..." -Type Information -ShowOnConsole
                    Send-MailMessage @sendMailMessageParameters
                    Write-Log -Path $Activitylog -Entry "Email Sent!" -Type Information -ShowOnConsole
                }
                catch
                {
                    $comment = $_ | Format-List -Force 
                    Write-Log -Path $Activitylog -Entry  "Failed to send the mail" -Type Error -ShowOnConsole
                    Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
                }
            }
        }
        else
        {
             Write-Log -Path $Activitylog -Entry "Failed to run the command" -Type Error -ShowOnConsole
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






