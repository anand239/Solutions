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
    $body = "Hi Team this Server is being Decommisioned"
    $sendMailMessageParameters.Add("Body", $body)

    $ip = $config.server
    Import-Module ".\Posh-SSH\Posh-SSH.psd1"
    $session = New-SSHSession -ComputerName "$ip" -Credential $Credential -AcceptKey:$true -ErrorAction Stop
    if($session.connected -eq "true")
    {
        $stream = New-SSHShellStream -SessionId $session.SessionId

        $stream.WriteLine("sudo su - gabagool")
        Start-Sleep -Milliseconds 5000

        $hostnames = Import-Csv $config.HostnamesFile

        if($hostnames)
        {
            foreach($Line in $hostnames)
            {
                $hostname = $Line.hostname
                $ChangeNumber = $Line.'Change Number'
                $StartDate = $Line.'Planned Start Date'
                Write-Host "Connecting to $hostname" -BackgroundColor Green
                $stream.WriteLine("ssh $hostname")
                $stream.WriteLine("cat /etc/motd | grep -i @")
                Start-Sleep -Milliseconds 5000
                $motd = ""
                do
                {
                    $motd += $stream.Read()
                }
                while($stream.DataAvailable)
                $customerstream = $motd | where{$_}
                $ToEmail = (($customerstream -split "=")[1] -split "\n")[0]
                #send mail
                $Body = 
                $sendMailMessageParameters.Add("To", $ToEmail)
                Send-MailMessage @sendMailMessageParameters

                $stream.WriteLine("logout")
                Start-Sleep -Milliseconds 1500

                #Deleting the host
                $stream.WriteLine("sudo sh /usr/local/zabbix-scripts/z-delete-host $hostname")
                Start-Sleep -Milliseconds 1500
                $stream.WriteLine("ssh $hostname")

                #Stopping the services
                $stream.WriteLine("sudo /sbin/service zabbix-agent stop")
                Start-Sleep -Milliseconds 1500
                $stream.WriteLine("sudo /sbin/chkconfig zabbix-agent off")
                Start-Sleep -Milliseconds 1500
                $stream.WriteLine("ls -ld /IMH_Internal_Share")
                Start-Sleep -Milliseconds 1500
                $File = $stream.Read()
                if($File.Contains("file"))
                {
                    Write-Host "Creating /IMH_Internal_Share" -BackgroundColor Cyan
                    $stream.WriteLine("sudo mkdir -p /IMH_Internal_Share")
                    Start-Sleep -Milliseconds 1500
                }
                else
                {
                    Write-Host "/IMH_Internal_Share available....Continuing" -BackgroundColor Cyan
                }
                $stream.WriteLine("sudo mount -t nfs lps-nfs01:/IMH_Internal_Share   /IMH_Internal_Share")
                $stream.WriteLine("cd /IMH_Internal_Share/scripts/")
                $stream.WriteLine("uname")
                Start-Sleep -Milliseconds 1500
                $uname = $stream.Read()
                if($uname -like "*AIX*")
                {
                    Write-Host "Running aixprecheck.ksh" -BackgroundColor Yellow -ForegroundColor Black
                    $stream.WriteLine("sudo sh /IMH_Internal_Share/scripts/aixprecheck.ksh")
                }
                else
                {
                    Write-Host "Running linuxprecheck.ksh" -BackgroundColor Yellow -ForegroundColor Black
                    $stream.WriteLine("sudo sh /IMH_Internal_Share/scripts/linuxprecheck.ksh")
                }
                Start-Sleep -Milliseconds 1500
                $stream.WriteLine("cd")
                $stream.WriteLine("sudo umount /IMH_Internal_Share")
                $stream.WriteLine("logout")
                sleep -s 2
                $sendMailMessageParameters.Remove("To")
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
