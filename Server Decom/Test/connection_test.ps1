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
#$username = $config.username
$session = New-SSHSession -ComputerName "$ip" -Credential $Credential -AcceptKey:$true -ErrorAction Stop
$output = (Invoke-sshCommand -SessionId $Session.SessionId -Command "ls -ltr" -Verbose).output
$output
$stream = New-SSHShellStream -SessionId $session.SessionId
$stream.WriteLine("sudo su - anusha")
sleep -s 2
$stream.Read()
$stream.WriteLine("pwd")
sleep -s 2
$stream.Read()
$stream.WriteLine("ls -ltr")
sleep -s 2
$stream.Read()
Invoke-SSHStreamExpectSecureAction -ShellStream $stream -Command "ssh cvardhan@$ip" -ExpectString "cvardhan@$ip's password:" -SecureAction $Credential.Password -Verbose
$stream.WriteLine("pwd")
sleep -s 2
$stream.Read()
$stream.WriteLine("ls -ltr")
sleep -s 2
$stream.Read()
$stream.WriteLine("exit")
sleep -s 2
$stream.Read()
$stream.WriteLine("ls -ltr")
sleep -s 2
$stream.Read()
