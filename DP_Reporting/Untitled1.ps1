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



function Invoke-BackupHealthCheckCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SshSessionId,
        #[Parameter(Mandatory = $true)]
        [String]$logFile,
        [Parameter(Mandatory = $true)]
        [String]$command,
        [Switch] $UseSSHStream

    )
    try
    {
        $result = ""
        $result = Invoke-SSHCommand -Command $command -SessionId $SshSessionId -EnsureConnection -TimeOut 300 
        $output = $result.output
        if ($result.error)
        {
            Write-Host "Error occured"
        }
        $output,$result.error
    }
    catch
    {
        $null,$null
    }
}


$BackupDevice = "192.168.223.212"

#$Credential = Get-Credential

#$sshsessionId = New-PoshSession -IpAddress $BackupDevice -Credential  $Credential

$command = "dat '+%Z'"
$TimeZone,$Err = Invoke-BackupHealthCheckCommand -SshSessionId $sshsessionId.sessionId -command $command
