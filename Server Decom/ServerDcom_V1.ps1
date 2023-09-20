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


$ip = $config.server
$session = New-SSHSession -ComputerName "$ip" -Credential $Credential -AcceptKey:$true -ErrorAction Stop
$stream = New-SSHShellStream -SessionId $session.SessionId
$stream.WriteLine("sudo su - gabagool")
sleep -s 2
$hostnames = Get-Content $config.HostnamesFile
foreach($hostname in $hostnames)
{
    $stream.WriteLine("/usr/local/zabbix-scripts/z-delete-host $hostname")
    sleep -s 2
}
