<#
.SYNOPSIS
  Get-DataDomainStatus.ps1
    
.INPUTS
  config.json
  credentialfile.csv

   
.NOTES
  Script:         Get-DataDomainStatus.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0 , Posh-SSH Module, Windows 2008 R2 Or Above
  Creation Date:  06/07/2022
  Modified Date:  06/07/2022
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     06/07/2022      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Get-DataDomainStatus.ps1 -ConfigFile .\config.json
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

function Invoke-DDCommand
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

Function Get-FilesysObject
{
    [CmdletBinding()]
    param(
    $Command,$Result
    )
    $Filesys_Status = [pscustomobject] @{
    Command         = $Command
    Result          = $Result
    }
    $Filesys_Status
}

Function Get-FailedObject
{
    [CmdletBinding()]
    param(
    $Command,$Output
    )
    $FailedObject = [Pscustomobject] @{
    Command       = $command
    Output        = $Output
    }
    $FailedObject
}

Function Get-DDOutputs
{

    $SSHSession = New-PoshSession -IpAddress $Server -Credential $Credential
    $DiskShowStatus_Raw = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command "disk show state"
    $DF_h_Raw           = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command "df -h"
    $AlertsShow_Raw     = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command "alerts show current"
    $FilesysStatus      = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command "filesys clean status"
    $FilesysSched       = Invoke-DDCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command "filesys clean show sched"

    $DiskShow_Status   = @()
    $DF_h_Status       = @()
    $AlertsShow_Status = @()
    $Filesys_Status    = @()

    if($FilesysStatus)
    {
        $FilesysStatus_updated  = $FilesysStatus | where{$_}
        foreach($FilesysStatusLine in $FilesysStatus_updated)
        {
            $Filesys_Status += Get-FilesysObject -Command "Clean Status" -Result $FilesysStatusLine
        }
    }
    else
    {
        $Filesys_Status += Get-FilesysObject -Command "Clean Status" -Result "Failed to get data"
    }

    if($FilesysSched)
    {
        $FilesysSched_Updated   = $FilesysSched | where{$_}
        foreach($FilesysSchedLine in $FilesysSched_Updated)
        {
            $Filesys_Status += Get-FilesysObject -Command "Clean Schedule" -Result $FilesysSchedLine
        }
    }
    else
    {
        $Filesys_Status += Get-FilesysObject -Command "Clean Status" -Result "Failed to get data"
    }

    if($AlertsShow_Raw)
    {
        $AlertsShow_updated     = $AlertsShow_Raw | select -Skip 2 | select -SkipLast 2
        if($AlertsShow_updated)
        {
            foreach($AlertsShowLine in $AlertsShow_updated)
            {
                $AlertsShow_Split   = $AlertsShowLine -split "\s\s+" | where{$_}
                $AlertsShow_Status += [pscustomobject] @{
                Id                  = $AlertsShow_Split[0]
                'Post Time'         = $AlertsShow_Split[1]
                Severity            = $AlertsShow_Split[2]
                Class               = $AlertsShow_Split[3]
                Object              = $AlertsShow_Split[4]
                Message             = $AlertsShow_Split[5]
                }    
            }
        }
        else
        {
            $AlertsShow_Status = Get-FailedObject -Command "alerts show current" -Output "No Alerts available"
        }
    }
    else
    {
        $AlertsShow_Status = Get-FailedObject -Command "alerts show current" -Output "Failed to get data"
    }

    if($DF_h_Raw)
    {
        try{
            $DF_h_updated = $DF_h_Raw | Select-String "post" | where{$_}
            foreach($DF_h in $DF_h_updated)
            {
                $DF_h_Split     = $DF_h -split "\s\s+" | where{$_}
                $DF_h_Status   += [pscustomobject] @{
                Resource        = $DF_h_Split[0]
                'Size GiB'      = $DF_h_Split[1]
                'Used GiB'      = $DF_h_Split[2]
                'Avail GiB'     = $DF_h_Split[3]
                'Use %'         = $DF_h_Split[4]
                'Cleanable GiB' = $DF_h_Split[5]
                }
            }
        }
        catch
        {
            $DF_h_Status = Get-FailedObject -Command "df -h" -Output "Parsing Error"
        }
    }
    else
    {
        $DF_h_Status = Get-FailedObject -Command "df -h" -Output "Failed to get data"
    }

    if($DiskShowStatus_Raw)
    {
        try
        {
            $Legendlinenumber       = ($DiskShowStatus_Raw | Select-String -Pattern "Legend").LineNumber
            $DiskShowStatus_updated = $DiskShowStatus_Raw | select -Skip ($Legendlinenumber+1) | where{$_} | select -SkipLast 2
            foreach($DiskShowStatusLine in $DiskShowStatus_updated)
            {
                $DiskShow_Split   = $DiskShowStatusLine -split "\s\s+" | where{$_}
                $DiskShow_Status += [pscustomobject] @{
                Legend            = $DiskShow_Split[0]
                State             = $DiskShow_Split[1]
                Count             = $DiskShow_Split[2]
                }
            }
        }
        catch
        {
            $DiskShow_Status = Get-FailedObject -Command "disk show state" -Output "Parsing Error"
        }
    }
    else
    {
        $DiskShow_Status = Get-FailedObject -Command "disk show state" -Output "Failed to get data"
    }

    $DiskShow_Status,$DF_h_Status,$AlertsShow_Status,$Filesys_Status   

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
$culture = [CultureInfo]'en-us'
$Reportdate = ([system.datetime]::UtcNow).ToString("dd-MMM-yy")
$date = ([system.datetime]::UtcNow).ToString("ddMMMyy")
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
        Import-Module ".\Posh-SSH\Posh-SSH.psd1"
    }
    catch
    {
        Write-Log -Path $Activitylog -Entry "Failed to import Posh-SSH module" -Type warning -ShowOnConsole
        exit
    }
    #if(Test-Path -Path $config.CredentialFile)
    #{
    #    $Servers = Import-csv $config.CredentialFile | where{$_}
    #}
    #else
    #{
    #    Write-Host "Invalid $($config.CredentialFile)!" -ForegroundColor Red
    #    exit
    #}
    #$Final = @()
    #$datetime = Get-Date -Format g
    #$TZone = [System.TimeZoneInfo]::Local.Id
    ##if($Servers)
    #{
        #foreach($IP in $servers)
        #{
            #$precontent1 = "<p style=`"color: darkred; font-size: 24px`"> DataDomain Status for $Server | $datetime ($TZone) </p>"
            #$Server = $IP.Servername
            $server = $config.Servername
            Write-Log -Path $Activitylog -Entry "Checking For Credential for $server!" -Type Information -ShowOnConsole
            #$CredentialPath = $server + "_cred.xml"
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
                
                $Message = "Failed to get Credential"
                $final += Get-FailedObject -Command $Message -Output $Message   | ConvertTo-Html -Head $css -PreContent $precontent1                                
                exit
            }

            #$DiskShow_Status,$DF_h_Status,$AlertsShow_Status,$Filesys_Status = Get-DDOutputs  

            #$final += $DiskShow_Status   | ConvertTo-Html -Head $css -PreContent $precontent1
            #$final += $AlertsShow_Status | ConvertTo-Html -Head $css
            #$final += $DF_h_Status       | ConvertTo-Html -Head $css
            #$final += $Filesys_Status    | ConvertTo-Html -Head $css
        #}
        if($config.sendmail -eq "Yes")
        {
            $Final += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
            Send-Mail
        }
        $Final | Out-File "AvamarReport.html"
    #}
    #else
    #{
        #Write-Log -Path $Activitylog -Entry "No data available in $($config.CredentialFile)" -Type Error -ShowOnConsole
    #}
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
