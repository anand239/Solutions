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

function Invoke-ServerDecomCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SshSessionId,
        [Parameter(Mandatory = $true)]
        [String]$logFile,
        [Parameter(Mandatory = $true)]
        [String]$command

    )
    try
    {
        '****************************' |  Out-File -FilePath $logFile -Append
        "Running Command : $command" |  Out-File -FilePath $logFile -Append
        '----------------------------' |  Out-File -FilePath $logFile -Append
        $result = ""
        $Stream.WriteLine($command)
        Start-Sleep -Milliseconds 2000
        do
        {
            $result += $Stream.read()
            Start-Sleep -Milliseconds 500
        }
        While($Stream.DataAvailable)

        $result | Out-File -FilePath $logFile -Append    
        '----------------------------'  | Out-File -FilePath $logFile -Append
        '****************************'  | Out-File -FilePath $logFile -Append
        Write-Output $result
    }
    catch
    {
        Write-Output $null
    }
}


function Get-MailBody
{
    [CmdletBinding()]
    param(
    $hostnames
    )
    $Body = ""
    $Body = "<br>"
    $Body += "Hello,"
    $Body += "<br>"
    $Body += "Good day,"
    $Body += "<br></br>"
    $Body += "As per the change we will shut down the server on the Planned start date. The server will be in Shutdown state for 30 days (Cooling Period).Once the cooling period is over, we will proceed with the decommissioning procedures."
    $Body += "<br></br>"
    $Body += "Planned Start Date : $($hostnames.'Planned start date'[0])"
    $Body += "<br></br>"
    $Body += "Change Number : $($hostnames.'change number'[0])"
    $Body += "<br></br>"
    $Body += "Servers : "
    $Body += "<br>"
    foreach($h in $hostnames.Hostname)
    {
        $Body += $h
        $Body += "<br>"
    }
    $Body += "<br></br>"
    $Body += "Note: We will shut down the server on the Planned start date. The server will be in Shutdown state for 30 days (Cooling Period)."
    $Body += "Once the cooling period is over, we will proceed with the decommissioning procedures."
    $Body += "<br></br>"
    $body
}
$css = @"
<style>
h1, h5, th { font-size: 11px;text-align: center; font-family: Segoe UI; }
table { margin: auto; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: black; color: #fff; max-width: 100px; padding: 5px 10px; }
td { border: 1px solid black;font-size: 11px;text-align: center; padding: 2px 15px; color: #000; }
tr:nth-child(even) {background: #dae5f4;}
tr:nth-child(odd) {background: #b8d1f3;}
</style>
"@

$config = Get-Config -ConfigFile $ConfigFile
$Activitylog = "Activity.log"
    Write-Log -Path $Activitylog -Entry "Started" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "Host: $($env:COMPUTERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "User: $($env:USERNAME)" -Type Information -ShowOnConsole
    Write-Log -Path $Activitylog -Entry "-----------------------------------" -Type Information -ShowOnConsole
if($config)
{
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
    #Mail
    $sendMailMessageParameters = @{
        from        = $config.mail.From
        Subject     = "$($config.mail.Subject) $(Get-Date -Format 'dd-MMM-yyyy - dddd - HH:mm')"
        SMTPServer  = $config.mail.smtpServer
        BodyAsHtml  = $true
        ErrorAction = 'Stop'
    }
    if ($config.mail.Cc)
    {
        $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";"))
    }
    $body = $null
    $ToEmail = $null
    $sendMailMessageParameters.Add("Body", $body)
    $sendMailMessageParameters.Add("TO", $ToEmail)
    $ip = $config.server
    Import-Module ".\Posh-SSH\Posh-SSH.psd1"
    $session = New-SSHSession -ComputerName "$ip" -Credential $Credential -AcceptKey:$true -ErrorAction Stop
    if($session.connected -eq "true")
    {
        $stream = New-SSHShellStream -SessionId $session.SessionId
        $stream.WriteLine("sudo su - gabagool")
        Start-Sleep -Milliseconds 5000
        $hostnames = Import-Csv $config.HostnamesFile | where{$_}
        if($hostnames)
        {
            if($config.SendMail -eq "Yes")
            {
                $FirstHost    = $hostnames | select -First 1
                $Hostname     = $FirstHost.hostname
                $ToEmail = $FirstHost.PrimaryCustomer
                $body = Get-MailBody -hostnames $hostnames
                $sendMailMessageParameters.Body = $body
                $sendMailMessageParameters.to = $ToEmail
                try
                {
                    Send-MailMessage @sendMailMessageParameters
                }
                catch
                {
                    $comment = $_ | Format-List -Force
                    Write-Log -Path $Activitylog -Entry  "Failed to send the mail" -Type Error -ShowOnConsole
                    Write-Log -Path $Activitylog -Entry  $comment -Type Exception
                    Write-Log -Path $Activitylog -Entry  "Please Check PulseSecure Connection and SMTP Details" -Type Information -ShowOnConsole
                    Exit
                }
                Start-Sleep -Milliseconds 1500
            }
            foreach($Line in $hostnames)
            {
                $hostname = $Line.hostname
                Write-Log -Path $Activitylog -Entry "Connecting to $hostname" -Type Information -ShowOnConsole
                #Deleting the host
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo sh /usr/local/zabbix-scripts/z-delete-host $hostname"
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "ssh $hostname"
                #Stopping the services
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo /sbin/service zabbix-agent stop"
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo /sbin/chkconfig zabbix-agent off"
                $File = Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "ls -ld /IMH_Internal_Share"
                if($File.Contains("file"))
                {
                    Write-Log -Path $Activitylog -Entry "Creating /IMH_Internal_Share" -Type Information -ShowOnConsole
                    Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo mkdir -p /IMH_Internal_Share"
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "/IMH_Internal_Share available....Continuing" -Type Information -ShowOnConsole
                }
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo mount -t nfs lps-nfs01:/IMH_Internal_Share   /IMH_Internal_Share"
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "cd /IMH_Internal_Share/scripts/"
                $uname = Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "uname"
                if($uname -like "*AIX*")
                {
                    Write-Log -Path $Activitylog -Entry "Running aixprecheck.ksh" -Type Information -ShowOnConsole
                    Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo sh /IMH_Internal_Share/scripts/aixprecheck.ksh"
                }
                else
                {
                    Write-Log -Path $Activitylog -Entry "Running linuxprecheck.ksh" -Type Information -ShowOnConsole
                    Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo sh /IMH_Internal_Share/scripts/linuxprecheck.ksh"
                }
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "cd"
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "sudo umount /IMH_Internal_Share"
                Invoke-ServerDecomCommand -SshSessionId $sshsessionId.sessionId -logFile $Activitylog -command "logout"
                sleep -s 2
            }
        }
        else
        {
            Write-Log -Path $Activitylog -Entry "Invalid File Hostnames.CSV" -Type Error -ShowOnConsole
        }
        Remove-SSHSession -SessionId $session.SessionId
    }
    else
    {
        Write-Log -Path $Activitylog -Entry "Failed To Establish Connection with $ip" -Type Error -ShowOnConsole
    }
}
else
{
    Write-Log -Path $Activitylog -Entry "Invalid $ConfigFile" -Type Error -ShowOnConsole
}

