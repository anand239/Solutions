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


$config = Get-Config -ConfigFile $ConfigFile
$CredentialPath = $config.CredentialFile
if (!(Test-Path -Path $CredentialPath) )
{
    $Credential = Get-Credential -Message "Enter Credentials"
    $Credential | Export-Clixml $CredentialPath -Force
}
$Credential = Import-Clixml $CredentialPath

#Mail
$sendMailMessageParameters = @{
    from        = $config.mail.From 
    Subject     = "$($config.mail.Subject) $(Get-Date -Format 'dd-MMM-yyyy - dddd - HH:mm')"      
    SMTPServer  = $config.mail.smtpServer             
}
if ($config.mail.Cc) 
{ 
    $sendMailMessageParameters.Add("CC", $config.mail.Cc.Split(";"))
}
$body = "Hi Team this Server is being Decommisioned"
$sendMailMessageParameters.Add("Body", $body)

$ip = $config.server
$session = New-SSHSession -ComputerName "$ip" -Credential $Credential -AcceptKey:$true -ErrorAction Stop
$stream = New-SSHShellStream -SessionId $session.SessionId

$stream.WriteLine("sudo su - gabagool")
Start-Sleep -Milliseconds 5000

$hostnames = Get-Content $config.HostnamesFile

foreach($hostname in $hostnames)
{
    Write-Host "Connecting to $hostname" -BackgroundColor Green
    $stream.WriteLine("ssh $hostname")
    Start-Sleep -Milliseconds 5000
    $stream.WriteLine("cat /etc/motd | grep -i @")
    Start-Sleep -Milliseconds 5000
    $motd = ""
    do
    {
        $motd += $stream.Read()
    }
    while($stream.DataAvailable)

    $customer = $motd | Select-String -Pattern "customer"
    $ToEmail = ($customer -split "\s")[4].Trim()
    #send mail
    $sendMailMessageParameters.Add("To", $ToEmail)
    Send-MailMessage @sendMailMessageParameters

    $stream.WriteLine("logout")
    Start-Sleep -Milliseconds 1500

    #Deleting the host
    $stream.WriteLine("sudo sh /usr/local/zabbix-scripts/z-delete-host $hostname")
    Start-Sleep -Milliseconds 1500
    $stream.WriteLine("ssh $hostname")
    Start-Sleep -Milliseconds 1500

    #Stopping the services
    $stream.WriteLine("sudo /sbin/service zabbix-agent stop")
    Start-Sleep -Milliseconds 1500
    $stream.WriteLine("sudo /sbin/chkconfig zabbix-agent off")
    Start-Sleep -Milliseconds 1500
    $stream.WriteLine("ls -ld /IMH_Internal_Share")
    $File = $stream.Read()
    if($File.Contains("file"))
    {
        $stream.WriteLine("sudo mkdir -p /IMH_Internal_Share")
        Start-Sleep -Milliseconds 1500
    }
    $stream.WriteLine("sudo mount -t nfs lps-nfs01:/IMH_Internal_Share   /IMH_Internal_Share")
    Start-Sleep -Milliseconds 1500
    $stream.WriteLine("cd /IMH_Internal_Share/scripts/")
    Start-Sleep -Milliseconds 1500
    $stream.WriteLine("uname")
    Start-Sleep -Milliseconds 1500
    $uname = $stream.Read()
    if($uname -eq "AIX")
    {
        $stream.WriteLine("sudo sh /IMH_Internal_Share/scripts/aixprecheck.ksh")
    }
    else
    {
        $stream.WriteLine("sudo sh /IMH_Internal_Share/scripts/linuxprecheck.ksh")
    }
    Start-Sleep -Milliseconds 1500
    $stream.WriteLine("cd")
    $stream.WriteLine("sudo unmount /IMH_Internal_Share")
    $stream.WriteLine("logout")
    sleep -s 2
    $sendMailMessageParameters.Remove("To")
}
