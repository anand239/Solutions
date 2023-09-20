<#
.SYNOPSIS
  Get-StorageNodeOfflineReport.ps1
    
.INPUTS
  config.json
   
.NOTES
  Script:         Get-StorageNodeOfflineReport.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0 , Posh-SSH Module, Windows 2008 R2 Or Above
  Creation Date:  02/02/2023
  Modified Date:  02/02/2023 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     02/02/2023      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-StorageNodeOfflineReport.ps1 -ConfigFile .\config.json
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
    $sendMailMessageParameters.Add("Body", $MailMessage)
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

function Invoke-NonWindowsCommand
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
        Write-Output $result
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

Function Get-NBUServices
{
    $SSHSession = New-PoshSession -IpAddress $server -Credential $Credential
    $NBUServiceStatus = @()
    if($SSHSession.Connected -eq "True")
    {
        Write-Log -Path $Activitylog -Entry "Connected to $server!" -Type Information -ShowOnConsole
        $NBUServicesData = Invoke-NonWindowsCommand -SshSessionId $SSHSession.Sessionid -command "/usr/openv/netbackup/bin/bpps -x" -logFile $Activitylog
        if($NBUServicesData.output)
        {
            foreach($Service in $Services)
            {
                if(!($NBUServicesData -like "*$Service*"))
                {
                    $NBUServiceStatus += [PsCustomobject]@{
                    ServerName         = $Server
                    ServiceName        = $Service
                    Status             = "Not Running"
                    }
                }
                else
                {
                    $NBUServiceStatus += [PsCustomobject]@{
                    ServerName         = $Server
                    ServiceName        = $Service
                    Status             = "Running"
                    }
                }
            }
            <#
            if(!($NBUServiceStatus))
            {
                $NBUServiceStatus += [PsCustomobject]@{
                ServerName         = $Server
                ServiceName        = "All Services"
                Status             = "Running"
                }
            }#>
        }
        else
        {
            if
            $NBUServiceStatus += [PsCustomobject]@{
            ServerName         = $Server
            ServiceName        = ""
            Status             = "Failed to get the Services data"
            }
            Write-Log -Path $Activitylog -Entry "Unable to get Services output from $server" -Type Error -ShowOnConsole
        }
        Remove-SSHSession -SessionId $SSHSession.Sessionid | Out-Null
    }
    else
    {
        $NBUServiceStatus  += [PsCustomobject]@{
        ServerName          = $Server
        ServiceName         = ""
        Status              = "Failed to Connect to server"
        }
        Write-Log -Path $Activitylog -Entry "failed to connect to $server" -Type Error -ShowOnConsole
    }
    $NBUServiceStatus
}



$css = @"
<style>
h1, h5, th { font-size: 11px;text-align: center; font-family: Segoe UI; }
table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: black; color: #fff; max-width: 200px; padding: 5px 10px; }
td { border: 1px solid black;font-size: 11px;text-align: center; padding: 5px 20px; color: #000; }
tr:nth-child(even) {background: #dae5f4;}
tr:nth-child(odd) {background: #b8d1f3;}
</style>
"@


$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole -OverWrite
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole


if($config)
{
    try
    {
        Import-Module ".\Posh-SSH\Posh-SSH.psd1" -ErrorAction Stop
    }
    catch
    {
        Write-Log -Path $Activitylog -Entry "Failed to import Posh-SSH module" -Type warning -ShowOnConsole
        exit
    }
    $Server = $config.Server
    Write-Log -Path $Activitylog -Entry "Checking For Credential for $server!" -Type Information -ShowOnConsole
    $CredentialPath = "cred.xml"
    if (!(Test-Path -Path $CredentialPath) )
    {
        $Credential = Get-Credential -Message "Enter Credentials for $server"
        $Credential | Export-Clixml $CredentialPath -Force
    }
    try
    {
        $Credential = Import-Clixml $CredentialPath
    }
    catch
    {
        $comment = $_ | Format-List -Force 
        Write-Log -Path $Activitylog -Entry  "Invalid Credential File for $server!" -Type Error -ShowOnConsole
        Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
        Write-Log -Path $Activitylog -Entry  "Recreate Credential File!" -Type Information -ShowOnConsole                
        Exit
    }

    $SSHSession = New-PoshSession -IpAddress $server -Credential $Credential

    if($SSHSession.Connected -eq "True")
    {
        Write-Log -Path $Activitylog -Entry "Connected to $server!" -Type Information -ShowOnConsole

        $Command = "nsradmin -i storage_node_file" -replace "storage_node_file", $Config.StorageNodeCommandFilePath
        $StorageNodeData = Invoke-NonWindowsCommand -SshSessionId $SSHSession.Sessionid -command "" -logFile $Activitylog
        if($StorageNodeData.output)
        {
            $Skiplines = $StorageNodeData.output | select -Skip 1 | where{$_}
            $FinalResult = @()
            for($i=0; $i -lt $Skiplines.Count; $i+=5)
            {
                $Name    = $Skiplines[$i]
                $Version = $Skiplines[$i+1]
                $Node    = $Skiplines[$i+2]
                $Enabled = $Skiplines[$i+3]
                $Ready   = $Skiplines[$i+4]

                $StorageNodeStatus += [Pscustomobject] @{
                Name                =  ($Name   -split ":")[1].Trim() -replace ";"
                Version             = ($Version -split ":")[1].Trim() -replace ";"
                Node                = ($Node    -split ":")[1].Trim() -replace ";"
                Enabled             = ($Enabled -split ":")[1].Trim() -replace ";"
                Ready               = ($Ready   -split ":")[1].Trim() -replace ";"
                }
            }
            $No = $FinalResult | where{$_.Ready -eq "No"}  
            if($No)
            {
                $body = ""
                $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease find Storage Node Offline  Report.</p>"
                $body += $No | ConvertTo-Html -Head $css
                $body += "<br>Thanks,<br>Automation Team<br>"
                $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
                Send-Mail -MailMessage $Body
            }
        }
        else
        {
            $StorageNodeStatus = [PsCustomobject]@{
            ServerName         = $Server
            Status             = "Failed to get the Storage Node data"
            }
            Write-Log -Path $Activitylog -Entry "Unable to get Storage Node data from $server" -Type Error -ShowOnConsole
            Write-Log -Path $Activitylog -Entry "$($StorageNodeData.output)" -Type Error -ShowOnConsole
        }
        Remove-SSHSession -SessionId $SSHSession.Sessionid | Out-Null
    }
    else
    {
        $StorageNodeStatus = [PsCustomobject]@{
        ServerName         = $Server
        Status             = "Failed to Connect to server"
        }
        Write-Log -Path $Activitylog -Entry "failed to connect to $server" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole

