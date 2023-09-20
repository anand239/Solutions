<#
.SYNOPSIS
  Get-DDCapacityReport.ps1
    
.INPUTS
  config.json
  Servers.txt

   
.NOTES
  Script:         Get-DDCapacityReport.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0 , Posh-SSH Module, Windows 2008 R2 Or Above
  Creation Date:  28/06/2022
  Modified Date:  28/06/2022 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     28/06/2022      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-DDCapacityReport.ps1 -ConfigFile .\config.json
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

function Invoke-AvamarCommand
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

Function Get-DDObject
{
    [CmdletBinding()]
    Param(
    $IPv4,$TotalCapacity,$ServerUti,$FSAvailable,$FSUsed
    )
    $DDCapacity        += [pscustomobject] @{
    Server              = $server
    IPv4Hostname        = $IPv4
    TotalCapacity       = $TotalCapacity
    ServerUtilization   = $ServerUti
    FileSystemAvailable = $FSAvailable
    FileSystemUsed      = $FSUsed
    }
    $DDCapacity
}
Function Get-DDCapacityReport
{
    [CmdletBinding()]
    Param(
    )
    $SSHSession = New-PoshSession -IpAddress $server -Credential  $Credential
    if($SSHSession.connected -eq "True")
    {
        Write-Log -Path $Activitylog -Entry "Connected to $server!" -Type Information -ShowOnConsole
        $DDCapacityOutput_raw = Invoke-AvamarCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $config.command
                
        if($DDCapacityOutput_raw)
        {
            $DDCapacityOutput = $DDCapacityOutput_raw  | select -skip 3 | where{$_}
            if($DDCapacityOutput)
            {
                foreach($line in $DDCapacityOutput)
                {
                    $values = $line  -split "\s\s+" | where{$_}
                            
                    if($values[0] -like "*N/A*")
                    {
                        $DDCapacity = Get-DDObject -IPv4 ($values[0] -split "\s")[0] -TotalCapacity $values[1] -ServerUti $values[2] -FSAvailable $values[4] -FSUsed $values[5]
                    }
                    else
                    {
                        $DDCapacity = Get-DDObject -IPv4 $values[0] -TotalCapacity $values[2] -ServerUti $values[3] -FSAvailable $values[5] -FSUsed $values[6]
                    }
                }
            }
            else
            {
                $Message = "No DataDomain Available"
                $DDCapacity = Get-DDObject -IPv4 $Message -TotalCapacity $Message -ServerUti $Message -FSAvailable $Message -FSUsed $Message
            }
        }
        else
        {
            $Message = "Failed to get data"
            $DDCapacity = Get-DDObject -IPv4 $Message -TotalCapacity $Message -ServerUti $Message -FSAvailable $Message -FSUsed $Message
        }
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "failed to connect to $server" -Type Error -ShowOnConsole
        $Message = "Failed to connect to server"
        $DDCapacity = Get-DDObject -IPv4 $Message -TotalCapacity $Message -ServerUti $Message -FSAvailable $Message -FSUsed $Message
    }
    $DDCapacity
}

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

if($config)
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
    if(Test-Path -Path $config.CredentialFile)
    {
        $Servers = Import-csv $config.CredentialFile | where{$_}
    }
    else
    {
        Write-Host "Invalid $($config.CredentialFile)!" -ForegroundColor Red
        exit
    }

    $DDCapacity = @()
    if($Servers)
    {
        foreach($IP in $servers)
        {
            $Server = $IP.Servername
            Write-Log -Path $Activitylog -Entry "Checking For Credential for $server!" -Type Information -ShowOnConsole
            $CredentialPath = $server + "_cred.xml"
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
                
                $Message = "Invalid Credential file"
                $DDCapacity += Get-DDObject -IPv4 $Message -TotalCapacity $Message -ServerUti $Message -FSAvailable $Message -FSUsed $Message
                
                break
            }
            $DDCapacity += Get-DDCapacityReport
        }
        $datetime = Get-Date -Format g
        $TZone = [System.TimeZoneInfo]::Local.Id
        $precontent1 = "<b> <font size=+1> DataDomain Capacity Report  | $datetime ($TZone) </font> </b>"
        $Body = "<br>"
        $Body += $DDCapacity | ConvertTo-Html -PreContent "<br> $precontent1 </br><br></br>" -Head $css
        $Body += "<br></br>"
        if($config.sendmail -eq "Yes")
        {
            $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
            Send-Mail
        }
        $body | Out-File "DDcapacity.html"
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "No data available in $($config.Serversfile)" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
