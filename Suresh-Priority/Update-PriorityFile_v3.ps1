<#
.SYNOPSIS
  Update-PriorityFile.ps1
    
.INPUTS
  config.json

   
.NOTES
  Script:         Update-PriorityFile.ps1
  Author:         Chintalapudi Anand Vardhan
  Requirements :  Powershell v3.0 , Posh-SSH Module, Windows 2008 R2 Or Above
  Creation Date:  04/07/2022
  Modified Date:  04/07/2022 
  Remarks      :  

  .History:
        Version Date            Author                       Description        
        1.0     04/07/2022      Chintalapudi Anand Vardhan   Initial Release
.EXAMPLE
  Script Usage 

  .\Update-PriorityFile.ps1 -ConfigFile .\config.json
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

Function Get-UpdatedPriorityFile
{
    [cmdletbinding()]
    Param(
    $DaystobeAdded,
    $Todaydate
    )

    $array = @()
    $FilteredLines = @()
    $UpdatedLines = @()
    $SSHSession = New-PoshSession -IpAddress $server -Credential  $Credential
    if($SSHSession.connected -eq "True")
    {
        Write-Log -Path $Activitylog -Entry "Connected to $server!" -Type Information -ShowOnConsole
        $InputData = Invoke-NonWindowsCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $command
        if($InputData)
        {
            foreach($line in $InputData)
            {
                if(!($line.StartsWith("#") -or ($line.Length -eq 0)))
                {        
                    if($line -like "*_Monthly*" -or $line -like "*_Yearly*" -or $line -like "*_Adhoc*")
                    {
                        $FilteredLines += $line
                        $words = $line -split "\s" | where{$_}
                        $Linedate = $words[8]            
                        if($Linedate -eq 0)
                        {
                            $words[8]      = $Todaydate.AddDays($DaystobeAdded).tostring("dd.MM.yy")
                            $Updatedline   = $words -join "     "
                            $array        += $Updatedline
                            $Updatedlines += $Updatedline                
                        }
                        else
                        {                                
                            $words[8]      = $Todaydate.AddDays($DaystobeAdded).tostring("dd.MM.yy") #(([datetime]::parseexact($Linedate, 'dd.MM.yy', $Null)).adddays($DaystobeAdded)).tostring("dd.MM.yy")
                            $Updatedline   = $words -join "     "
                            $array        += $Updatedline
                            $Updatedlines += $Updatedline
                        }
                    }
                    else
                    {
                        $array += $line
                    }              
                }
                else
                {
                    $array += $line
                }
            }
            if($FilteredLines)
            {
                Write-Log -Path $Activitylog -Entry "Filtered lines are: `n " -Type Information -ShowOnConsole
                $FilteredLines
                $FilteredLines | Out-File $Activitylog -Append
                Write-Log -Path $Activitylog -Entry "Updated  lines are: `n "  -Type Information -ShowOnConsole
                $UpdatedLines
                $UpdatedLines | Out-File $Activitylog -Append
                $UserInput = Read-Host "Do You want to continue? (Y / N)"
                if($UserInput -eq "Y")
                {
                    Write-Log -Path $Activitylog -Entry "Proceeding to update file.."  -Type Information -ShowOnConsole
                    $array | Out-File "priority1" -Encoding ascii
                    $sedcommand = "sed -i `"s/\r//g`" $configpath"
                    #Set-SCPItem -ComputerName "192.168.247.143" -Credential $cred -Path "priority1" -Destination $config.configpath
                    $SedData = Invoke-NonWindowsCommand -SshSessionId $sshsession.sessionId -logFile $Activitylog -command $sedcommand
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "Stopping the process.."  -Type warning -ShowOnConsole
                }
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "No Monthly,Yearly or Adhoc backups" -Type warning -ShowOnConsole
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "Failed to get data from $configpath" -Type Error -ShowOnConsole
        }
        Remove-SSHSession -SessionId $SSHSession.sessionid
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "failed to connect to $server" -Type Error -ShowOnConsole
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
    try
    {
        Import-Module ".\Posh-SSH\Posh-SSH.psd1"
    }
    catch
    {
        Write-Log -Path $Activitylog -Entry "Failed to import Posh-SSH module" -Type warning -ShowOnConsole
        exit
    }
    $Server = ""
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
        exit
    }

    $server         = $config.server
    $configpath     = $config.Configpath + "/" + $config.configfilename
    $command        = "cat $configpath"
    $Days           = $config.DaystobeAdded
    $Date           = Get-Date
    if(!($days))
    {
        Write-Log -Path $Activitylog -Entry "Days to be added is empty" -Type Error -ShowOnConsole   
        exit
    }
    if($Days -lt 1)
    {
        Write-Log -Path $Activitylog -Entry "Days to be added should not be lessthan 1" -Type Error -ShowOnConsole   
        exit
    }

    Get-UpdatedPriorityFile -DaystobeAdded $Days -Todaydate $Date

}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole

