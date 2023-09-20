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

function Invoke-NBUErrorCommand
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
    $BackupDevice = $config.BackupServer
    Import-Module ".\Posh-SSH\Posh-SSH.psd1"
    $sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential

    if($sshsessionId.connected -eq "True")
    {
        $ErrordataCommand = $config.NBUErrorCommand
        $Errordata = Invoke-NBUErrorCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command $command
        if($Errordata)
        {
            $ErrorObject = @()
            $pattern = '(?<=\().+?(?=\))'
            try
            {
                foreach($line in $Errordata)
                {
                    $split = $line -split "\s" | where{$_}
                    $Description = [regex]::Matches($line, $pattern).Value
                    $ErrorObject += [Pscustomobject] @{
                    "JobId"      = $split[5]
                    "ClientName" = $split[11]
                    "Ploicy"     = $split[13]
                    "ParentJob"  = $split[6]
                    "Schedule"   = $split[15]
                    "Status"     = $split[18]
                    "MediaServer"= $split[4]
                    "Description"= $Description
                    }
                }
            }
            catch
            {
                $ErrorObject = $null
                $comment = $_ | Format-List -Force 
                Write-Log -Path $Activitylog -Entry  "Parsing Error" -Type Error -ShowOnConsole
                Write-Log -Path $Activitylog -Entry  $comment -Type Exception 
            }

            if($ErrorObject)
            {
                $filtered = $ErrorObject | where{$_.status -notin $config.ErrorCodes -and $_.ClientName -ne "None"}

                $Groups = $filtered | Group-Object -Property Clientname,status

                $Finaldata = @()

                Foreach($Group in $Groups)
                {
                    <#if($Group.count -ge 50)
                    {
                        $one = $Group.group | select -First 1
                        $one | Add-Member NoteProperty "Priority" "P2"
                        $Finaldata += $one
                    }
                    else
                    {
                        $one = $Group.group | select -First 1
                        $one | Add-Member NoteProperty "Priority" "P4"
                        $Finaldata += $one
                    }#>
                    $Finaldata += $Group.group | select -First 1

                }
                $ReportName = $config.Reportpath + "\" + "NBU_ErrorReport" + ".csv"
                $Finaldata | Export-Csv -Path $ReportName -NoTypeInformation
                $body = ""
                $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspPlease find the attached error data report.<br><br>Thanks,<br>Automation Team<br></p>"
            }
            else
            {
                Write-Log -Path $Activitylog -Entry "Parsing Error" -Type Information -ShowOnConsole
                $body = ""
                $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspParsing Error.<br><br>Thanks,<br>Automation Team<br></p>"
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "No error logs available" -Type Information -ShowOnConsole
            $body = ""
            $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspNo error logs available.<br><br>Thanks,<br>Automation Team<br></p>"
        }
        Remove-SSHSession $Sshsession.sessionid
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Failed to connect to $BackupDevice" -Type Error -ShowOnConsole
        $body = ""
        $body += "<p>Hi, <br><br>&nbsp&nbsp&nbsp&nbspFailed to connect to $BackupDevice.<br><br>Thanks,<br>Automation Team<br></p>"
    }
    if($config.SendEmail -eq "Yes")
    {
        $attachment = @()
        $attachment += $ReportName
        $sendMailMessageParameters = @{
            To          = $config.mail.To.Split(";")
            from        = $config.mail.From 
            Subject     = "$($config.mail.Subject)"    
            BodyAsHtml  = $true
            SMTPServer  = $config.mail.smtpServer             
            ErrorAction = 'Stop'
            Port        = $config.mail.port
        } 
        if ($config.mail.Cc)
        {
            $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";"))
        }
        if ($attachment.Count -gt 0)
        {
            $sendMailMessageParameters.Add("Attachments", $attachment )
        }

        $body += "<p style=`"color: red; font-size: 12px`">***This is an auto generated mail. Please do not reply.***</p>"
        $sendMailMessageParameters.Add("Body", $Body)
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
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}
Write-Log -Path $Activitylog -Entry "Completed" -Type Information -ShowOnConsole
